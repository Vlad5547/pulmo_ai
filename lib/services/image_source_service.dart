import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/xray_image.dart';
import 'radiograph_decoder.dart';

/// Where a radiograph can come from.
enum XRaySource { gallery, camera, file }

/// The two things this app needs about a picked file. Deliberately not
/// `PlatformFile`: that type is sealed by the plugin and cannot be constructed
/// in a test, and nothing here needs the rest of it.
typedef PickedFile = ({String name, String? path});

/// Opens the platform file browser and returns the chosen file, or null when
/// the user backs out.
typedef PickFile = Future<PickedFile?> Function();

/// Thin wrapper over the pickers so screens never talk to a plugin directly
/// (keeps them testable and the plugins swappable).
///
/// The file picker exists because `image_picker` only sees what the gallery
/// indexes as an image, and a `.dcm` is not that. Picking a file is therefore
/// the only way to open the format the model was actually trained on.
class ImageSourceService {
  ImageSourceService({
    ImagePicker? picker,
    PickFile? filePicker,
    this._decoder = const RadiographDecoder(),
    Future<Directory> Function()? cacheDirectory,
  })  : _picker = picker ?? ImagePicker(),
        _filePicker = filePicker ?? _openPlatformPicker,
        _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  final ImagePicker _picker;

  /// Injected as a function rather than an object: `FilePicker` is a static
  /// facade, and a test has to be able to hand back a file without a platform
  /// channel being up.
  final PickFile _filePicker;
  final RadiographDecoder _decoder;
  final Future<Directory> Function() _cacheDirectory;

  static Future<PickedFile?> _openPlatformPicker() async {
    // FileType.any is the default and is also the only filter that works
    // here: `custom` with an extension list hides everything else on Android,
    // and DICOM has no registered MIME type on that platform.
    final picked = await FilePicker.pickFile();
    if (picked == null) return null;
    return (name: picked.name, path: picked.path);
  }

  /// Returns null when the user cancels the picker.
  Future<XRayImage?> pickFromGallery() => _pickImage(ImageSource.gallery);

  Future<XRayImage?> captureWithCamera() => _pickImage(ImageSource.camera);

  /// Any file the user can reach, including DICOM.
  ///
  /// A DICOM is decoded here and written out as an 8-bit PNG next to the
  /// original, so everything downstream — preview, history, PDF report — deals
  /// with an ordinary image. The pixel values the model sees still come from
  /// the DICOM itself, through the same decoder.
  Future<XRayImage?> pickFile() async {
    final picked = await _filePicker();
    final path = picked?.path;
    if (picked == null || path == null) return null;

    final bytes = await File(path).readAsBytes();
    return prepare(bytes: bytes, name: picked.name, path: path);
  }

  /// Turns raw picked bytes into an [XRayImage] the UI can display.
  ///
  /// Exposed so the analyze screen can reuse it for files that arrive by other
  /// routes, and so tests can drive it without a picker.
  Future<XRayImage> prepare({
    required Uint8List bytes,
    required String name,
    required String path,
  }) async {
    // Throws RadiographDecodeException for anything unreadable; the caller
    // turns that into a message instead of letting it reach the user as a
    // stack trace.
    final decoded = _decoder.decode(bytes);
    if (!decoded.isDicom) {
      return XRayImage(name: name, path: path);
    }

    final dicom = decoded.dicom!;
    final cache = await _cacheDirectory();
    final preview = File(
      p.join(cache.path, '${p.basenameWithoutExtension(name)}_preview.png'),
    );
    await preview.writeAsBytes(dicom.toPng(), flush: true);

    return XRayImage(
      name: name,
      path: path,
      displayPath: preview.path,
      isDicom: true,
      patientId: dicom.patientId,
      studyDate: dicom.studyDate,
      viewPosition: dicom.viewPosition,
      modality: dicom.modality,
    );
  }

  Future<XRayImage?> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 100);
    if (file == null) return null;
    return XRayImage(name: file.name, path: file.path);
  }
}
