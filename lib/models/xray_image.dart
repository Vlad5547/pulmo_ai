import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A chest X-ray selected by the user.
///
/// [path] is the file the model reads — a DICOM stays a DICOM here, so the
/// pixels reaching the network come from the medical container itself.
/// [displayPath] is what the UI shows; for a DICOM it is a PNG rendered from
/// the same pixels, because no Flutter widget can draw a DICOM.
@immutable
class XRayImage {
  const XRayImage({
    required this.name,
    required this.path,
    this.bytes,
    this.displayPath,
    this.isDicom = false,
    this.patientId,
    this.studyDate,
    this.viewPosition,
    this.modality,
  });

  final String name;
  final String path;
  final Uint8List? bytes;

  /// Displayable copy, when [path] is not something a widget can decode.
  final String? displayPath;

  final bool isDicom;

  /// Header fields worth showing, read from the DICOM. Null for other formats.
  final String? patientId;
  final String? studyDate;
  final String? viewPosition;
  final String? modality;

  /// The path the UI should render.
  String get previewPath => displayPath ?? path;

  ImageProvider get provider {
    final data = bytes;
    if (data != null && displayPath == null) return MemoryImage(data);
    return FileImage(File(previewPath));
  }
}
