import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulmo_ai/services/radiograph_decoder.dart';

/// What the app does with files a user can realistically hand it: a PDF, a text
/// file renamed to .png, half a download, an empty file, a screenshot.
///
/// Every one of these has to end in a typed [RadiographDecodeException] the UI
/// can turn into a sentence — never in a raw crash, and never in a silent
/// "analysis" of garbage, which would be far worse than an error.
void main() {
  const decoder = RadiographDecoder();

  group('files that are not radiographs', () {
    test('an empty file', () {
      expect(
        () => decoder.decode(Uint8List(0)),
        throwsA(
          isA<RadiographDecodeException>()
              .having((e) => e.error, 'error', RadiographDecodeError.empty),
        ),
      );
    });

    test('a text file', () {
      final bytes = Uint8List.fromList(
        'This is a referral letter, not a radiograph.'.codeUnits,
      );
      expect(
        () => decoder.decode(bytes),
        throwsA(isA<RadiographDecodeException>()),
      );
    });

    test('a PDF', () {
      final bytes = Uint8List.fromList([
        ...'%PDF-1.7\n'.codeUnits,
        ...List<int>.filled(512, 0x20),
      ]);
      expect(
        () => decoder.decode(bytes),
        throwsA(isA<RadiographDecodeException>()),
      );
    });

    test('random bytes', () {
      final random = Random(7);
      final bytes = Uint8List.fromList(
        List<int>.generate(4096, (_) => random.nextInt(256)),
      );
      expect(
        () => decoder.decode(bytes),
        throwsA(isA<RadiographDecodeException>()),
      );
    });
  });

  group('damaged images', () {
    test('a PNG cut in half is reported, not half-decoded', () {
      final png = _png(64, 64);
      final half = Uint8List.sublistView(png, 0, png.length ~/ 2);
      expect(
        () => decoder.decode(half),
        throwsA(isA<RadiographDecodeException>()),
      );
    });

    test('a PNG with a valid header but no pixel data', () {
      final png = _png(32, 32);
      // Keep the signature and the IHDR chunk, drop everything after it.
      final truncated = Uint8List.sublistView(png, 0, 33);
      expect(
        () => decoder.decode(truncated),
        throwsA(isA<RadiographDecodeException>()),
      );
    });
  });

  group('images the app accepts', () {
    test('an 8-bit grayscale PNG', () {
      final decoded = decoder.decode(_png(40, 30));
      expect(decoded.isDicom, isFalse);
      expect(decoded.width, 40);
      expect(decoded.height, 30);
      expect(decoded.plane, hasLength(40 * 30));
      expect(decoded.plane.every((v) => v >= 0 && v <= 1), isTrue);
    });

    test('a JPEG photograph of a film', () {
      final image = img.Image(width: 24, height: 24);
      for (var y = 0; y < 24; y++) {
        for (var x = 0; x < 24; x++) {
          image.setPixelRgb(x, y, x * 10, x * 10, x * 10);
        }
      }
      final decoded = decoder.decode(
        Uint8List.fromList(img.encodeJpg(image, quality: 90)),
      );
      expect(decoded.width, 24);
      expect(decoded.plane.first, lessThan(decoded.plane[23]));
    });

    test('a colour screenshot is converted to one luminance channel', () {
      final image = img.Image(width: 4, height: 1);
      image.setPixelRgb(0, 0, 255, 0, 0);
      image.setPixelRgb(1, 0, 0, 255, 0);
      image.setPixelRgb(2, 0, 0, 0, 255);
      image.setPixelRgb(3, 0, 255, 255, 255);

      final decoded = decoder.decode(Uint8List.fromList(img.encodePng(image)));
      expect(decoded.plane, hasLength(4));
      expect(decoded.plane[0], closeTo(0.299, 1e-3));
      expect(decoded.plane[1], closeTo(0.587, 1e-3));
      expect(decoded.plane[2], closeTo(0.114, 1e-3));
      expect(decoded.plane[3], closeTo(1.0, 1e-3));
    });

    test('a 1x1 image is accepted rather than treated as damaged', () {
      final decoded = decoder.decode(_png(1, 1));
      expect(decoded.plane, hasLength(1));
    });
  });

  test('every failure carries a message the UI can show as-is', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList('not an image'.codeUnits),
    ]) {
      try {
        decoder.decode(bytes);
        fail('should have thrown');
      } on RadiographDecodeException catch (error) {
        expect(error.message, isNotEmpty);
        expect(error.message.trim(), endsWith('.'));
      }
    }
  });
}

Uint8List _png(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 1);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final v = ((x + y) * 3) % 256;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
