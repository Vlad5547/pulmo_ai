import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A chest X-ray selected by the user.
///
/// Keeps a file path (mobile / desktop) and optionally the raw bytes, which is
/// what an on-device model will consume later. The UI only ever asks for
/// [provider], so swapping the source out stays a one-file change.
@immutable
class XRayImage {
  const XRayImage({required this.name, required this.path, this.bytes});

  final String name;
  final String path;
  final Uint8List? bytes;

  ImageProvider get provider {
    final data = bytes;
    return data != null ? MemoryImage(data) : FileImage(File(path));
  }
}
