import '../models/analysis_result.dart';
import '../models/xray_image.dart';

/// Contract every inference backend has to satisfy.
///
/// The app is wired to [OnnxAnalysisService], which runs the exported
/// PulmoNet-7M locally. [MockAnalysisService] implements the same contract and
/// is kept for tests and for running the UI without the model. Swapping the
/// backend is one line in `lib/main.dart` — no screen has to change.
abstract class AnalysisService {
  /// Human readable name of the backend, shown on the result screen.
  String get modelName;

  /// Loads weights / opens a session. Cheap and idempotent for the mock.
  Future<void> warmUp();

  /// Runs inference on [image].
  Future<AnalysisResult> analyze(XRayImage image);

  /// Releases the runtime session, if the backend holds one.
  Future<void> dispose();
}
