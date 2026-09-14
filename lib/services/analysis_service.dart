import '../models/analysis_result.dart';
import '../models/xray_image.dart';

/// Contract every inference backend has to satisfy.
///
/// Today the app is wired to [MockAnalysisService]. A real backend (TFLite
/// interpreter, ONNX runtime or a remote endpoint serving the RSNA-trained
/// model) only has to implement this interface and be injected in
/// `lib/app/service_locator.dart` — no screen has to change.
abstract class AnalysisService {
  /// Human readable name of the backend, shown on the result screen.
  String get modelName;

  /// Loads weights / opens a session. Cheap and idempotent for the mock.
  Future<void> warmUp();

  /// Runs inference on [image].
  Future<AnalysisResult> analyze(XRayImage image);
}
