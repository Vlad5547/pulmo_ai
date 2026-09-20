import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/analysis_record.dart';

/// Strings the report needs, passed in so the PDF follows the app's language
/// instead of hard-coding English.
class ReportLabels {
  const ReportLabels({
    required this.title,
    required this.subtitle,
    required this.study,
    required this.analysed,
    required this.verdict,
    required this.verdictText,
    required this.probability,
    required this.threshold,
    required this.model,
    required this.inferenceTime,
    required this.heatmapCaption,
    required this.disclaimer,
    required this.generatedBy,
    required this.noImages,
  });

  final String title;
  final String subtitle;
  final String study;
  final String analysed;
  final String verdict;

  /// The verdict itself, already localised by the caller.
  final String verdictText;
  final String probability;
  final String threshold;
  final String model;
  final String inferenceTime;
  final String heatmapCaption;
  final String disclaimer;
  final String generatedBy;
  final String noImages;
}

/// Renders one analysis as a single-page PDF.
///
/// The report is built entirely on the device from data already in the record —
/// nothing is uploaded, and no template is fetched. It is a summary a clinician
/// can file or hand over, and it repeats the disclaimer, because a printed
/// sheet outlives the screen that explained what the number means.
class ReportService {
  const ReportService();

  Future<Uint8List> build({
    required AnalysisRecord record,
    required ReportLabels labels,
    required String formattedDate,
    required String formattedDuration,
    required double threshold,
  }) async {
    final document = pw.Document(title: labels.title);
    final result = record.result;

    final radiograph = _imageFrom(record.imagePath);
    final heatmap = _imageFrom(record.heatmapPath) ??
        (result.heatmapPng != null
            ? pw.MemoryImage(result.heatmapPng!)
            : null);

    final accent =
        result.isPositive ? PdfColors.red700 : PdfColors.green700;

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              labels.title,
              style: const pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              labels.subtitle,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: accent, width: 1.2),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    labels.verdictText,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  pw.Text(
                    '${(result.confidence * 100).toStringAsFixed(1)} %',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            _table(labels, record, formattedDate, formattedDuration, threshold),
            pw.SizedBox(height: 14),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (radiograph != null)
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Image(radiograph),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            record.imageName,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (radiograph != null && heatmap != null)
                    pw.SizedBox(width: 12),
                  if (heatmap != null)
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          // The overlay is a translucent PNG: stacking it over
                          // the radiograph reproduces what the app shows.
                          pw.Stack(
                            children: [
                              if (radiograph != null)
                                pw.Image(radiograph),
                              pw.Image(heatmap),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            labels.heatmapCaption,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (radiograph == null && heatmap == null)
                    pw.Text(
                      labels.noImages,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Text(
                labels.disclaimer,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              labels.generatedBy,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );

    return document.save();
  }

  pw.Widget _table(
    ReportLabels labels,
    AnalysisRecord record,
    String formattedDate,
    String formattedDuration,
    double threshold,
  ) {
    final result = record.result;
    final rows = <(String, String)>[
      (labels.study, record.imageName),
      (labels.analysed, formattedDate),
      (labels.verdict, labels.verdictText),
      (
        labels.probability,
        '${(result.confidence * 100).toStringAsFixed(1)} %'
      ),
      (labels.threshold, threshold.toStringAsFixed(2)),
      (labels.model, '${result.modelName} v${result.modelVersion}'),
      (labels.inferenceTime, formattedDuration),
    ];

    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: const pw.BorderSide(color: PdfColors.grey300),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  row.$1,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  row.$2,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  pw.MemoryImage? _imageFrom(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return pw.MemoryImage(file.readAsBytesSync());
    } on FileSystemException {
      // A report without the picture is still worth producing.
      return null;
    }
  }
}
