import 'package:flutter/foundation.dart';

import '../models/analysis_record.dart';

/// Store of past analyses.
///
/// Screens listen to this and never touch storage themselves, so the in-memory
/// implementation used by tests and the SQLite one used by the app are
/// interchangeable.
///
/// [load] must be awaited once before the first read; until then [records] is
/// empty and [isLoaded] is false.
abstract class HistoryRepository extends ChangeNotifier {
  /// Newest first.
  List<AnalysisRecord> get records;

  bool get isEmpty => records.isEmpty;

  /// False until [load] has finished, so the UI can tell "no history yet" from
  /// "not read from disk yet" and show a spinner instead of an empty state.
  bool get isLoaded;

  Future<void> load();

  Future<void> add(AnalysisRecord record);

  Future<void> remove(String id);

  Future<void> clear();
}

/// Volatile implementation, for tests and for running the UI without a device
/// database. Holds nothing across a restart by design.
class InMemoryHistoryRepository extends ChangeNotifier
    implements HistoryRepository {
  InMemoryHistoryRepository({List<AnalysisRecord> seed = const []}) {
    _records.addAll(seed);
  }

  final List<AnalysisRecord> _records = [];
  bool _loaded = false;

  @override
  List<AnalysisRecord> get records => List.unmodifiable(_records);

  @override
  bool get isEmpty => _records.isEmpty;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load() async {
    _loaded = true;
    notifyListeners();
  }

  @override
  Future<void> add(AnalysisRecord record) async {
    _records.removeWhere((r) => r.id == record.id);
    var index = 0;
    while (index < _records.length &&
        _records[index].createdAt.isAfter(record.createdAt)) {
      index++;
    }
    _records.insert(index, record);
    notifyListeners();
  }

  @override
  Future<void> remove(String id) async {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  @override
  Future<void> clear() async {
    _records.clear();
    notifyListeners();
  }
}
