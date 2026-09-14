import 'package:image_picker/image_picker.dart';

import '../models/xray_image.dart';

/// Thin wrapper over `image_picker` so screens never talk to the plugin
/// directly (keeps them testable and the plugin swappable).
class ImageSourceService {
  ImageSourceService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Returns null when the user cancels the picker.
  Future<XRayImage?> pickFromGallery() =>
      _pick(ImageSource.gallery);

  Future<XRayImage?> captureWithCamera() => _pick(ImageSource.camera);

  Future<XRayImage?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 100);
    if (file == null) return null;
    return XRayImage(name: file.name, path: file.path);
  }
}
