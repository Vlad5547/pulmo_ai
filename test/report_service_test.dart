import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulmo_ai/models/analysis_record.dart';
import 'package:pulmo_ai/models/analysis_result.dart';
import 'package:pulmo_ai/services/report_service.dart';

/// The PDF is the one artefact that leaves the app, so it has to be produced
/// from the record alone, survive missing images, and always carry the
/// disclaimer.
void main() {
  const service = ReportService();

  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pulmoai_report_test');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<Uint8List> render(AnalysisRecord record) => service.build(
        record: record,
        labels: _labels,
        formattedDate: '20 Sep 2026, 12:30',
        formattedDuration: '0.21 s',
        threshold: 0.5,
      );

  test('produces a valid PDF document', () async {
    final bytes = await render(_record());

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes.skip(bytes.length - 6)), contains('EOF'));
  });

  test('a report can be produced with no images at all', () async {
    // The user cleared their gallery; the numbers are still worth a report.
    final bytes = await render(_record());
    expect(bytes.length, greaterThan(1000));
  });

  test('the radiograph and the heatmap are embedded when present', () async {
    final image = File('${temp.path}/x.png')
      ..writeAsBytesSync(_png(64, 64, 120));
    final heatmap = File('${temp.path}/x_cam.png')
      ..writeAsBytesSync(_png(64, 64, 200));

    final withImages = await render(
      _record(imagePath: image.path, heatmapPath: heatmap.path),
    );
    final withoutImages = await render(_record());

    // Embedding two 64x64 images has to make the document meaningfully bigger.
    expect(withImages.length, greaterThan(withoutImages.length));
  });

  test('a path that no longer exists degrades instead of throwing', () async {
    final bytes = await render(
      _record(
        imagePath: '${temp.path}/gone.png',
        heatmapPath: '${temp.path}/gone_cam.png',
      ),
    );
    expect(bytes.length, greaterThan(1000));
  });

  test('a positive and a negative record both render', () async {
    expect((await render(_record(positive: true))).length, greaterThan(1000));
    expect((await render(_record())).length, greaterThan(1000));
  });
}

const _labels = ReportLabels(
  title: 'Chest X-ray screening report',
  subtitle: 'Generated on this device by PulmoAI. Not a diagnosis.',
  study: 'Study',
  analysed: 'Analysed',
  verdict: 'Verdict',
  verdictText: 'Pneumonia detected',
  probability: 'Probability of opacity',
  threshold: 'Decision threshold',
  model: 'Model',
  inferenceTime: 'Inference time',
  heatmapCaption: 'Class activation map',
  disclaimer: 'Not a diagnosis.',
  generatedBy: 'PulmoAI',
  noImages: 'The images are no longer available.',
);

AnalysisRecord _record({
  bool positive = false,
  String? imagePath,
  String? heatmapPath,
}) =>
    AnalysisRecord(
      id: 'r1',
      imageName: 'study.dcm',
      imagePath: imagePath,
      heatmapPath: heatmapPath,
      createdAt: DateTime(2026, 9, 20, 12, 30),
      result: AnalysisResult(
        verdict:
            positive ? PneumoniaVerdict.pneumonia : PneumoniaVerdict.normal,
        confidence: positive ? 0.91 : 0.12,
        processingTime: const Duration(milliseconds: 214),
        modelName: 'PulmoNet-7M',
        modelVersion: '1.0.0',
      ),
    );

Uint8List _png(int width, int height, int value) {
  final image = img.Image(width: width, height: height, numChannels: 1);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
