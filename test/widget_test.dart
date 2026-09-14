import 'package:flutter_test/flutter_test.dart';
import 'package:pulmo_ai/app/app.dart';
import 'package:pulmo_ai/services/history_repository.dart';
import 'package:pulmo_ai/services/image_source_service.dart';
import 'package:pulmo_ai/services/mock_analysis_service.dart';

void main() {
  testWidgets('home screen shows the primary call to action', (tester) async {
    await tester.pumpWidget(
      PulmoAiApp(
        analysisService: MockAnalysisService(),
        historyRepository: HistoryRepository(seedDemoData: false),
        imageSourceService: ImageSourceService(),
      ),
    );

    expect(find.text('Analyze X-ray'), findsOneWidget);
    expect(find.text('How it works'.toUpperCase()), findsOneWidget);
  });
}
