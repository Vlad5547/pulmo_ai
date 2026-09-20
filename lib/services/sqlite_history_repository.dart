import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/analysis_record.dart';
import '../models/analysis_result.dart';
import 'history_repository.dart';

/// Analysis history kept in a local SQLite database.
///
/// Everything stays on the device: the row carries the numbers, and the two
/// images (the radiograph as displayed and the heatmap overlay) are copied into
/// the app's own directory and referenced by path. The picked file itself is
/// never relied on — a gallery item or a shared DICOM can be moved or deleted,
/// and a history entry must survive that.
///
/// Deleting a record deletes its copied files; there is no other owner.
class SqliteHistoryRepository extends ChangeNotifier
    implements HistoryRepository {
  /// [_storageDirectory] is where the database and the copied images live —
  /// `getApplicationDocumentsDirectory` in the app, a temporary folder in
  /// tests. [factory] defaults to the platform sqflite implementation; tests
  /// pass `databaseFactoryFfi` so they can run without a device.
  SqliteHistoryRepository({
    required this._storageDirectory,
    DatabaseFactory? factory,
    this._fileName = 'pulmoai_history.db',
  })  : _databaseFactory = factory ?? databaseFactory;

  static const int schemaVersion = 1;
  static const String _table = 'analyses';

  final Future<Directory> Function() _storageDirectory;
  final DatabaseFactory _databaseFactory;
  final String _fileName;

  final List<AnalysisRecord> _records = [];
  Database? _db;
  Directory? _mediaDir;
  bool _loaded = false;
  Future<void>? _loadInFlight;

  @override
  List<AnalysisRecord> get records => List.unmodifiable(_records);

  @override
  bool get isEmpty => _records.isEmpty;

  @override
  bool get isLoaded => _loaded;

  // -- lifecycle ----------------------------------------------------------

  @override
  Future<void> load() {
    if (_loaded) return Future.value();
    return _loadInFlight ??= _load().whenComplete(() => _loadInFlight = null);
  }

  Future<void> _load() async {
    final root = await _storageDirectory();
    _mediaDir = Directory(p.join(root.path, 'history'));
    if (!_mediaDir!.existsSync()) {
      await _mediaDir!.create(recursive: true);
    }

    _db = await _databaseFactory.openDatabase(
      p.join(root.path, _fileName),
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => db.execute('''
          CREATE TABLE $_table (
            id             TEXT PRIMARY KEY,
            image_name     TEXT NOT NULL,
            image_path     TEXT,
            heatmap_path   TEXT,
            created_at     INTEGER NOT NULL,
            is_positive    INTEGER NOT NULL,
            confidence     REAL NOT NULL,
            processing_ms  INTEGER NOT NULL,
            model_name     TEXT NOT NULL,
            model_version  TEXT NOT NULL,
            is_dicom       INTEGER NOT NULL DEFAULT 0,
            notes          TEXT
          )
        '''),
      ),
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_${_table}_created_at '
      'ON $_table (created_at DESC)',
    );

    await _refresh();
    _loaded = true;
    notifyListeners();
  }

  /// Keeps the in-memory list in the same order the database returns
  /// (newest first). Inserting at 0 would be right for a fresh analysis but
  /// wrong for a back-dated one, and the list must not depend on how it was
  /// filled.
  void _insertSorted(AnalysisRecord record) {
    var index = 0;
    while (index < _records.length &&
        _records[index].createdAt.isAfter(record.createdAt)) {
      index++;
    }
    _records.insert(index, record);
  }

  Future<void> _refresh() async {
    final rows = await _db!.query(_table, orderBy: 'created_at DESC');
    _records
      ..clear()
      ..addAll(rows.map(_fromRow));
  }

  /// Closes the database. Call from the app's shutdown path; after this the
  /// repository must not be used again.
  ///
  /// Separate from [ChangeNotifier.dispose], which is synchronous.
  Future<void> close() async {
    final db = _db;
    _db = null;
    _loaded = false;
    await db?.close();
  }

  // -- writes -------------------------------------------------------------

  @override
  Future<void> add(AnalysisRecord record) async {
    await load();
    final stored = await _persistMedia(record);
    await _db!.insert(
      _table,
      _toRow(stored),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _records.removeWhere((r) => r.id == stored.id);
    _insertSorted(stored);
    notifyListeners();
  }

  @override
  Future<void> remove(String id) async {
    await load();
    final index = _records.indexWhere((r) => r.id == id);
    if (index >= 0) {
      await _deleteMedia(_records[index]);
      _records.removeAt(index);
    }
    await _db!.delete(_table, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  @override
  Future<void> clear() async {
    await load();
    for (final record in _records) {
      await _deleteMedia(record);
    }
    _records.clear();
    await _db!.delete(_table);
    notifyListeners();
  }

  // -- media ---------------------------------------------------------------

  /// Copies the radiograph and the heatmap into the app directory so the entry
  /// survives the original file being moved or deleted.
  Future<AnalysisRecord> _persistMedia(AnalysisRecord record) async {
    final dir = _mediaDir!;
    var imagePath = record.imagePath;

    final source = record.imagePath;
    if (source != null && source.isNotEmpty && !p.isWithin(dir.path, source)) {
      final file = File(source);
      if (file.existsSync()) {
        final target = p.join(dir.path, '${record.id}${p.extension(source)}');
        await file.copy(target);
        imagePath = target;
      }
    }

    String? heatmapPath;
    final heatmap = record.result.heatmapPng;
    if (heatmap != null) {
      heatmapPath = p.join(dir.path, '${record.id}_cam.png');
      await File(heatmapPath).writeAsBytes(heatmap, flush: true);
    }

    return record.copyWith(
      imagePath: imagePath,
      heatmapPath: heatmapPath,
    );
  }

  Future<void> _deleteMedia(AnalysisRecord record) async {
    for (final path in [record.imagePath, record.heatmapPath]) {
      if (path == null || path.isEmpty) continue;
      if (!p.isWithin(_mediaDir!.path, path)) continue; // never ours to delete
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } on FileSystemException catch (error) {
          // A locked or already-removed file must not block the delete of the
          // row the user asked to remove.
          debugPrint('PulmoAI: could not delete $path: $error');
        }
      }
    }
  }

  // -- mapping -------------------------------------------------------------

  Map<String, Object?> _toRow(AnalysisRecord record) => {
        'id': record.id,
        'image_name': record.imageName,
        'image_path': record.imagePath,
        'heatmap_path': record.heatmapPath,
        'created_at': record.createdAt.millisecondsSinceEpoch,
        'is_positive': record.result.isPositive ? 1 : 0,
        'confidence': record.result.confidence,
        'processing_ms': record.result.processingTime.inMilliseconds,
        'model_name': record.result.modelName,
        'model_version': record.result.modelVersion,
        'is_dicom': record.isDicom ? 1 : 0,
        'notes': record.result.notes,
      };

  AnalysisRecord _fromRow(Map<String, Object?> row) {
    final heatmapPath = row['heatmap_path'] as String?;
    return AnalysisRecord(
      id: row['id']! as String,
      imageName: row['image_name']! as String,
      imagePath: row['image_path'] as String?,
      heatmapPath: heatmapPath,
      isDicom: (row['is_dicom'] as int? ?? 0) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      result: AnalysisResult(
        verdict: (row['is_positive']! as int) == 1
            ? PneumoniaVerdict.pneumonia
            : PneumoniaVerdict.normal,
        confidence: (row['confidence']! as num).toDouble(),
        processingTime:
            Duration(milliseconds: row['processing_ms']! as int),
        modelName: row['model_name']! as String,
        modelVersion: row['model_version']! as String,
        notes: row['notes'] as String?,
        // Read back from the copy this repository owns, so a record opened
        // from the history still shows its heatmap after a restart.
        heatmapPng: _readHeatmap(heatmapPath),
      ),
    );
  }

  Uint8List? _readHeatmap(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return file.readAsBytesSync();
    } on FileSystemException catch (error) {
      debugPrint('PulmoAI: could not read the stored heatmap: $error');
      return null;
    }
  }
}
