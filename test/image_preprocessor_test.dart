import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulmo_ai/services/image_preprocessor.dart';
import 'package:pulmo_ai/services/radiograph_decoder.dart';

const mean = 0.4932;
const std = 0.2458;
const size = 224;

const preprocessor = ImagePreprocessor(imageSize: size, mean: mean, std: std);

Uint8List encodedSolid(int value, {int width = 512, int height = 512}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return img.encodePng(image);
}

void main() {
  group('preprocessing', () {
    test('produces exactly 1 x 1 x 224 x 224 values', () {
      final tensor = preprocessor.toModelInput(encodedSolid(128));

      expect(preprocessor.inputShape, [1, 1, size, size]);
      expect(tensor, isA<Float32List>());
      expect(tensor.length, size * size);
    });

    test('non-square input is resized to the square model input', () {
      final tensor = preprocessor.toModelInput(
        encodedSolid(200, width: 1024, height: 768),
      );
      expect(tensor.length, size * size);
    });

    test('converts colour to a single grayscale channel', () {
      // A pure red image: grayscale must collapse it to one luminance value,
      // far from the red channel value itself.
      final image = img.Image(width: 256, height: 256);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final plane = preprocessor.toGrayscaleUnitRange(img.encodePng(image));

      expect(plane.length, size * size);
      final first = plane.first;
      expect(plane.every((value) => (value - first).abs() < 1e-6), isTrue,
          reason: 'a uniform image must give a uniform plane');
      expect(first, greaterThan(0.0));
      expect(first, closeTo(0.299, 0.01),
          reason: 'luminance of pure red is 0.299');
    });

    test('scales pixels into [0, 1] before normalisation', () {
      for (final value in [0, 64, 128, 255]) {
        final plane = preprocessor.toGrayscaleUnitRange(encodedSolid(value));
        expect(plane.first, closeTo(value / 255.0, 1e-6),
            reason: 'pixel $value should map to ${value / 255.0}');
        expect(plane.every((v) => v >= 0.0 && v <= 1.0), isTrue);
      }
    });

    test('normalises with the training mean and std', () {
      final plane = preprocessor.toGrayscaleUnitRange(encodedSolid(128));
      final unit = plane.first;
      final normalised = preprocessor.normalise(Float32List.fromList(plane));

      expect(normalised.first, closeTo((unit - mean) / std, 1e-6));
      // 0..1 maps to roughly -2.0 .. +2.1 with these statistics
      final black = preprocessor.toModelInput(encodedSolid(0)).first;
      final white = preprocessor.toModelInput(encodedSolid(255)).first;
      expect(black, closeTo((0.0 - mean) / std, 1e-3));
      expect(white, closeTo((1.0 - mean) / std, 1e-3));
      expect(black, lessThan(0));
      expect(white, greaterThan(0));
    });

    test('downscaling averages the source area instead of point sampling', () {
      // Half black, half white in a fine checkerboard: point sampling would
      // return 0 or 1, area averaging returns the mid grey the model was
      // trained on.
      final image = img.Image(width: 448, height: 448);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final value = (x + y).isEven ? 255 : 0;
          image.setPixelRgb(x, y, value, value, value);
        }
      }
      final plane = preprocessor.toGrayscaleUnitRange(img.encodePng(image));
      expect(plane.first, closeTo(0.5, 0.05),
          reason: 'a checkerboard must average to mid grey');
    });

    test('rejects data that is not an image', () {
      expect(
        () => preprocessor.toModelInput(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<RadiographDecodeException>()),
      );
    });
  });
}
