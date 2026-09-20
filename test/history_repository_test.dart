import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pulmo_ai/models/analysis_record.dart';
import 'package:pulmo_ai/models/analysis_result.dart';
import 'package:pulmo_ai/services/history_repository.dart';
import 'package:pulmo_ai/services/sqlite_history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The history is the only part of the app that keeps anything after the
/// process dies, so these tests care about one thing above all: what survives a
/// restart, and what is cleaned up when a record goes away.
void main() {
  sqfliteFfiInit();

  late Directory storage;

  setUp(() {
    storage = Directory.systemTemp.createTempSync('pulmoai_history_test');
  });

  tearDown(() {
    // Best effort: on Windows a database a failing test left open still holds
    // a lock, and that must not mask the real failure.
    try {
      if (storage.existsSync()) storage.deleteSync(recursive: true);
    } on FileSystemException {
      // ignored
    }
  });

  SqliteHistoryRepository open() => SqliteHistoryRepository(
        storageDirectory: () async => storage,
        factory: databaseFactoryFfi,
      );

  test('starts empty — no demo data is ever shown as a real analysis',
      () async {
    final repository = open();
    await repository.load();

    expect(repository.isLoaded, isTrue);
    expect(repository.records, isEmpty);
    await repository.close();
  });

  test('isLoaded is false before load, so the UI can tell empty from unread',
      () async {
    final repository = open();
    expect(repository.isLoaded, isFalse);
    expect(repository.records, isEmpty);
    await repository.load();
    expect(repository.isLoaded, isTrue);
    await repository.close();
  });

  test('a stored analysis survives reopening the database', () async {
    final repository = open();
    await repository.load();
    await repository.add(_record(id: 'a', confidence: 0.83, positive: true));
    await repository.close();

    final reopened = open();
    await reopened.load();

    expect(reopened.records, hasLength(1));
    final restored = reopened.records.single;
    expect(restored.id, 'a');
    expect(restored.result.confidence, closeTo(0.83, 1e-9));
    expect(restored.result.verdict, PneumoniaVerdict.pneumonia);
    expect(restored.result.modelName, 'PulmoNet-7M');
    expect(restored.result.processingTime.inMilliseconds, 214);
    await reopened.close();
  });

  test('records come back newest first', () async {
    final repository = open();
    await repository.load();
    await repository.add(_record(id: 'old', at: DateTime(2026, 9)));
    await repository.add(_record(id: 'new', at: DateTime(2026, 9, 20)));
    await repository.add(_record(id: 'mid', at: DateTime(2026, 9, 10)));

    expect(
      repository.records.map((r) => r.id).toList(),
      ['new', 'mid', 'old'],
    );
    await repository.close();
  });

  test('the radiograph is copied into the app directory, not referenced',
      () async {
    final external = File(p.join(storage.path, 'picked.png'))
      ..writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));

    final repository = open();
    await repository.load();
    await repository.add(_record(id: 'copy', imagePath: external.path));

    final stored = repository.records.single;
    expect(stored.imagePath, isNot(external.path));
    expect(File(stored.imagePath!).existsSync(), isTrue);

    // The original can now go away — a gallery item the user deletes must not
    // empty the history entry.
    external.deleteSync();
    expect(File(stored.imagePath!).existsSync(), isTrue);
    await repository.close();
  });

  test('the heatmap is written next to it and read back after a restart',
      () async {
    final repository = open();
    await repository.load();
    await repository.add(
      _record(id: 'cam', heatmap: Uint8List.fromList([9, 8, 7])),
    );
    await repository.close();

    final reopened = open();
    await reopened.load();
    final restored = reopened.records.single;
    expect(restored.heatmapPath, isNotNull);
    expect(restored.result.heatmapPng, [9, 8, 7]);
    await reopened.close();
  });

  test('removing a record deletes its files too', () async {
    final repository = open();
    await repository.load();
    await repository.add(
      _record(id: 'gone', heatmap: Uint8List.fromList([1, 2])),
    );
    final stored = repository.records.single;
    final heatmap = File(stored.heatmapPath!);
    expect(heatmap.existsSync(), isTrue);

    await repository.remove('gone');

    expect(repository.records, isEmpty);
    expect(heatmap.existsSync(), isFalse);
    await repository.close();
  });

  test('clearing removes every row and every file', () async {
    final repository = open();
    await repository.load();
    for (var i = 0; i < 3; i++) {
      await repository.add(
        _record(id: 'r$i', heatmap: Uint8List.fromList([i])),
      );
    }
    final paths =
        repository.records.map((r) => File(r.heatmapPath!)).toList();

    await repository.clear();

    expect(repository.records, isEmpty);
    expect(paths.every((f) => !f.existsSync()), isTrue);
    await repository.close();
  });

  test('a missing heatmap file degrades to no heatmap, not a crash', () async {
    final repository = open();
    await repository.load();
    await repository.add(
      _record(id: 'lost', heatmap: Uint8List.fromList([1, 2, 3])),
    );
    File(repository.records.single.heatmapPath!).deleteSync();
    await repository.close();

    final reopened = open();
    await reopened.load();
    expect(reopened.records.single.result.heatmapPng, isNull);
    await reopened.close();
  });

  test('adding the same id twice replaces instead of duplicating', () async {
    final repository = open();
    await repository.load();
    await repository.add(_record(id: 'dup', confidence: 0.10));
    await repository.add(_record(id: 'dup', confidence: 0.90));

    expect(repository.records, hasLength(1));
    expect(repository.records.single.result.confidence, closeTo(0.90, 1e-9));
    await repository.close();
  });

  test('listeners fire on every write', () async {
    final repository = open();
    var notifications = 0;
    repository.addListener(() => notifications++);

    await repository.load();
    await repository.add(_record(id: 'x'));
    await repository.remove('x');
    await repository.clear();

    expect(notifications, 4);
    await repository.close();
  });

  group('in-memory implementation', () {
    test('behaves like the real one for the screens that use it', () async {
      final repository = InMemoryHistoryRepository();
      await repository.load();
      await repository.add(_record(id: 'a'));
      await repository.add(_record(id: 'b'));

      expect(repository.records.map((r) => r.id), ['b', 'a']);
      await repository.remove('a');
      expect(repository.isEmpty, isFalse);
      await repository.clear();
      expect(repository.isEmpty, isTrue);
    });
  });
}

AnalysisRecord _record({
  required String id,
  double confidence = 0.5,
  bool positive = false,
  DateTime? at,
  String? imagePath,
  Uint8List? heatmap,
}) =>
    AnalysisRecord(
      id: id,
      imageName: '$id.dcm',
      imagePath: imagePath,
      createdAt: at ?? DateTime(2026, 9, 20, 12),
      result: AnalysisResult(
        verdict:
            positive ? PneumoniaVerdict.pneumonia : PneumoniaVerdict.normal,
        confidence: confidence,
        processingTime: const Duration(milliseconds: 214),
        modelName: 'PulmoNet-7M',
        modelVersion: '1.0.0',
        heatmapPng: heatmap,
      ),
    );
