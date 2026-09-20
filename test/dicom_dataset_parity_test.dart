import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulmo_ai/services/dicom/dicom_decoder.dart';
import 'package:pulmo_ai/services/image_preprocessor.dart';
import 'package:pulmo_ai/services/radiograph_decoder.dart';

/// Reads the *original* RSNA DICOM files with the Dart decoder and checks that
/// the tensor they produce is the one the Python pipeline produced for the same
/// studies.
///
/// This is the end-to-end proof that opening a `.dcm` in the app feeds the
/// model exactly what training fed it: the reference tensors in
/// `test/fixtures/tensors/` come from `ai/src/data/preprocessing.py`.
///
/// The dataset is not part of the repository, so the test skips itself when the
/// files are not there (CI, a fresh clone). Point `PULMOAI_DATASET_ROOT` at the
/// `images/` directory to run it elsewhere.
void main() {
  const preprocessor = ImagePreprocessor(
    imageSize: 224,
    mean: 0.4932,
    std: 0.2458,
  );

  final datasetRoot = Directory(
    Platform.environment['PULMOAI_DATASET_ROOT'] ??
        r'D:\datasets\pneumonia_dataset_2018\images',
  );
  final mapping = File('ai/data/processed/dataset_mapping.csv');

  test('DICOM decoding reproduces the Python tensors', () async {
    final fixtures = Directory('test/fixtures');
    final expected = jsonDecode(
      File('${fixtures.path}/expected.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final images = (expected['images'] as List).cast<Map<String, dynamic>>();

    final paths = _dicomPathsByUid(mapping);
    var checked = 0;
    var worst = 0.0;

    for (final item in images) {
      final uid = item['sop_instance_uid'] as String;
      final relative = paths[uid];
      if (relative == null) continue;
      final file = File('${datasetRoot.path}${Platform.pathSeparator}$relative');
      if (!file.existsSync()) continue;

      final bytes = file.readAsBytesSync();
      expect(DicomDecoder.looksLikeDicom(bytes), isTrue,
          reason: '$uid should carry the DICM marker');

      final decoded = const RadiographDecoder().decode(bytes);
      expect(decoded.isDicom, isTrue);
      expect(decoded.dicom!.transferSyntaxUid, '1.2.840.10008.1.2.4.50');
      expect(decoded.dicom!.photometricInterpretation, 'MONOCHROME2');
      expect(decoded.width, 1024);
      expect(decoded.height, 1024);

      final tensor =
          preprocessor.normalise(preprocessor.resizeDecoded(decoded));

      // Dumped so the Python side can measure what the difference does to the
      // probability, which is the number that actually matters.
      final dump = Directory('build/dart_dicom_tensors')
        ..createSync(recursive: true);
      File('${dump.path}/${(item['file'] as String)
          .replaceAll('.png', '')}.f32')
          .writeAsBytesSync(tensor.buffer.asUint8List());

      final name = (item['file'] as String).replaceAll('.png', '');
      final reference = Float32List.view(
        Uint8List.fromList(
          File('${fixtures.path}/tensors/$name.f32').readAsBytesSync(),
        ).buffer,
      );
      expect(tensor.length, reference.length);

      var maxDifference = 0.0;
      for (var i = 0; i < tensor.length; i++) {
        final difference = (tensor[i] - reference[i]).abs();
        if (difference > maxDifference) maxDifference = difference;
      }
      if (maxDifference > worst) worst = maxDifference;
      debugPrint('$name.dcm  max |Δ| ${maxDifference.toStringAsExponential(3)}');
      checked++;
    }

    if (checked == 0) {
      markTestSkipped(
        'the RSNA dataset is not available at ${datasetRoot.path}',
      );
      return;
    }

    debugPrint('DICOM parity: $checked files, worst element difference '
        '${worst.toStringAsExponential(3)}');
    // The bound is looser than the PNG parity test (5e-05) on purpose. The
    // DICOM path adds one step the PNG path does not have: decoding the
    // embedded baseline JPEG. The `image` package and libjpeg (which pydicom
    // uses) round the IDCT differently and disagree by at most one LSB on
    // about 4 % of pixels — measured, and inherent to 8-bit stored data.
    // After the antialiased downscale that comes out as ~5e-03 per element.
    //
    // What it does to the output is measured separately by
    // `ai/src/export/check_dicom_parity.py`: worst |Δp| = 1.3e-03 over the six
    // fixtures, no verdict changed. Anything beyond the bound below would mean
    // the container itself is being read wrong (bit depth, photometric
    // interpretation, row order), which is what this test exists to catch.
    expect(worst, lessThan(1e-2));
  });
}

/// SOP instance UID -> path relative to the dataset's `images/` directory.
Map<String, String> _dicomPathsByUid(File mapping) {
  if (!mapping.existsSync()) return const {};
  final lines = mapping.readAsLinesSync();
  if (lines.isEmpty) return const {};
  final header = lines.first.split(',');
  final uidColumn = header.indexOf('sop_instance_uid');
  final pathColumn = header.indexOf('relative_path');
  if (uidColumn < 0 || pathColumn < 0) return const {};

  final result = <String, String>{};
  for (final line in lines.skip(1)) {
    final cells = line.split(',');
    if (cells.length <= pathColumn) continue;
    result[cells[uidColumn]] = cells[pathColumn];
  }
  return result;
}
