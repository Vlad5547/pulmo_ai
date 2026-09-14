import 'package:flutter/foundation.dart';

import '../models/analysis_record.dart';
import '../models/analysis_result.dart';

/// In-memory store of past analyses.
///
/// Deliberately kept behind a small interface-shaped class so it can be backed
/// by sqflite / Isar / a REST API later without touching the screens.
class HistoryRepository extends ChangeNotifier {
  HistoryRepository({bool seedDemoData = true}) {
    if (seedDemoData) _records.addAll(_demoRecords());
  }

  final List<AnalysisRecord> _records = [];

  /// Newest first.
  List<AnalysisRecord> get records => List.unmodifiable(_records);

  bool get isEmpty => _records.isEmpty;

  void add(AnalysisRecord record) {
    _records.insert(0, record);
    notifyListeners();
  }

  void remove(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void clear() {
    _records.clear();
    notifyListeners();
  }

  static List<AnalysisRecord> _demoRecords() {
    final now = DateTime.now();
    return [
      AnalysisRecord(
        id: 'demo-1',
        imageName: 'rsna_0a1b2c3d.dcm.png',
        createdAt: now.subtract(const Duration(hours: 5, minutes: 12)),
        result: const AnalysisResult(
          verdict: PneumoniaVerdict.pneumonia,
          confidence: 0.913,
          processingTime: Duration(milliseconds: 1840),
          boxes: [
            DetectionBox(
              left: 0.18,
              top: 0.38,
              width: 0.24,
              height: 0.26,
              score: 0.913,
            ),
          ],
        ),
      ),
      AnalysisRecord(
        id: 'demo-2',
        imageName: 'rsna_7f4e91aa.dcm.png',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        result: const AnalysisResult(
          verdict: PneumoniaVerdict.normal,
          confidence: 0.967,
          processingTime: Duration(milliseconds: 1720),
        ),
      ),
      AnalysisRecord(
        id: 'demo-3',
        imageName: 'rsna_31c0de55.dcm.png',
        createdAt: now.subtract(const Duration(days: 3, hours: 7)),
        result: const AnalysisResult(
          verdict: PneumoniaVerdict.normal,
          confidence: 0.884,
          processingTime: Duration(milliseconds: 1955),
        ),
      ),
    ];
  }
}
