import 'package:flutter/material.dart';

import '../models/analysis_record.dart';
import '../models/xray_image.dart';
import '../screens/analyze/analyze_screen.dart';
import '../screens/result/result_screen.dart';
import '../screens/root_shell.dart';

abstract final class AppRoutes {
  static const root = '/';
  static const analyze = '/analyze';
  static const result = '/result';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
        return _page(const RootShell(), settings);
      case analyze:
        final image = settings.arguments as XRayImage?;
        return _page(AnalyzeScreen(initialImage: image), settings);
      case result:
        final record = settings.arguments as AnalysisRecord;
        return _page(ResultScreen(record: record), settings);
      default:
        return null;
    }
  }

  static Route<T> _page<T>(Widget child, RouteSettings settings) =>
      MaterialPageRoute<T>(builder: (_) => child, settings: settings);
}
