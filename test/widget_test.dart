import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulmo_ai/app/app.dart';
import 'package:pulmo_ai/app/locale_controller.dart';
import 'package:pulmo_ai/l10n/generated/app_localizations.dart';
import 'package:pulmo_ai/models/analysis_record.dart';
import 'package:pulmo_ai/models/analysis_result.dart';
import 'package:pulmo_ai/services/history_repository.dart';
import 'package:pulmo_ai/services/image_source_service.dart';
import 'package:pulmo_ai/services/mock_analysis_service.dart';

/// Screen-level tests over the whole app widget, driven by the mock model and
/// an in-memory history, so nothing here touches the device or the ONNX
/// runtime.
void main() {
  Future<InMemoryHistoryRepository> pumpApp(
    WidgetTester tester, {
    List<AnalysisRecord> history = const [],
    Locale? locale,
  }) async {
    final repository = InMemoryHistoryRepository(seed: history);
    await repository.load();
    await tester.pumpWidget(
      PulmoAiApp(
        analysisService: MockAnalysisService(),
        historyRepository: repository,
        imageSourceService: ImageSourceService(),
        localeController: LocaleController(locale),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  group('home screen', () {
    testWidgets('shows the primary call to action', (tester) async {
      await pumpApp(tester);

      expect(find.text('Analyze X-ray'), findsWidgets);
      expect(find.text('How it works'.toUpperCase()), findsOneWidget);
    });

    testWidgets('an empty history shows no "recent analyses" block',
        (tester) async {
      await pumpApp(tester);
      expect(find.text('Recent analyses'.toUpperCase()), findsNothing);
    });

    testWidgets('stored analyses appear in the summary and the recent list',
        (tester) async {
      await pumpApp(tester, history: [
        _record(id: '1', positive: true, confidence: 0.91),
        _record(id: '2', confidence: 0.80),
      ]);

      expect(find.text('Recent analyses'.toUpperCase()), findsOneWidget);
      // two studies, one of them a finding
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Pneumonia detected'), findsWidgets);
    });
  });

  group('history screen', () {
    testWidgets('empty state explains what will be stored', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.history_outlined));
      await tester.pumpAndSettle();

      expect(find.text('No analyses yet'), findsOneWidget);
    });

    testWidgets('a spinner is shown while the history is still being read',
        (tester) async {
      // isLoaded is false until load() completes: the empty state must not be
      // shown in the meantime, or the user is told their history is gone.
      final repository = InMemoryHistoryRepository();
      await tester.pumpWidget(
        PulmoAiApp(
          analysisService: MockAnalysisService(),
          historyRepository: repository,
          imageSourceService: ImageSourceService(),
        ),
      );
      // pump(), not pumpAndSettle(): the progress indicator animates forever,
      // which is exactly the state under test.
      await tester.pump();
      await tester.tap(find.byIcon(Icons.history_outlined));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No analyses yet'), findsNothing);

      // Let the repository finish so the test does not end mid-frame.
      await repository.load();
      await tester.pumpAndSettle();
    });

    testWidgets('filters narrow the list down', (tester) async {
      await pumpApp(tester, history: [
        _record(id: 'p', positive: true),
        _record(id: 'n'),
      ]);
      await tester.tap(find.byIcon(Icons.history_outlined));
      await tester.pumpAndSettle();

      expect(find.text('p.dcm'), findsOneWidget);
      expect(find.text('n.dcm'), findsOneWidget);

      await tester.tap(find.textContaining('Findings ·'));
      await tester.pumpAndSettle();

      expect(find.text('p.dcm'), findsOneWidget);
      expect(find.text('n.dcm'), findsNothing);
    });

    testWidgets('swiping a record away removes it from the repository',
        (tester) async {
      final repository = await pumpApp(tester, history: [_record(id: 'x')]);
      await tester.tap(find.byIcon(Icons.history_outlined));
      await tester.pumpAndSettle();

      await tester.drag(find.text('x.dcm'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(repository.records, isEmpty);
    });

    testWidgets('clearing asks for confirmation first', (tester) async {
      final repository = await pumpApp(tester, history: [_record(id: 'x')]);
      await tester.tap(find.byIcon(Icons.history_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Clear history?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.records, hasLength(1));

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(repository.records, isEmpty);
    });
  });

  group('localisation', () {
    testWidgets('the UI is rendered in Ukrainian', (tester) async {
      await pumpApp(tester, locale: const Locale('uk'));

      expect(find.text('Аналізувати знімок'), findsOneWidget);
      expect(find.text('Як це працює'.toUpperCase()), findsOneWidget);
    });

    testWidgets('the UI is rendered in German', (tester) async {
      await pumpApp(tester, locale: const Locale('de'));

      expect(find.text('Aufnahme analysieren'), findsWidgets);
      expect(find.text('So funktioniert es'.toUpperCase()), findsOneWidget);
    });

    testWidgets('the language can be switched at runtime', (tester) async {
      await pumpApp(tester);
      expect(find.text('How it works'.toUpperCase()), findsOneWidget);

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Українська').last);
      await tester.pumpAndSettle();

      expect(find.text('Як це працює'.toUpperCase()), findsOneWidget);
      expect(find.text('How it works'.toUpperCase()), findsNothing);
    });

    testWidgets('every supported locale has a complete translation',
        (tester) async {
      // A missing key would make the generated class fall back to the template
      // or throw; walking every locale through the same screen catches it.
      for (final locale in AppL10n.supportedLocales) {
        await pumpApp(tester, locale: locale);
        expect(tester.takeException(), isNull,
            reason: 'locale ${locale.languageCode} failed to render');
      }
    });
  });
}

AnalysisRecord _record({
  required String id,
  bool positive = false,
  double confidence = 0.75,
}) =>
    AnalysisRecord(
      id: id,
      imageName: '$id.dcm',
      createdAt: DateTime(2026, 9, 20, 10),
      result: AnalysisResult(
        verdict:
            positive ? PneumoniaVerdict.pneumonia : PneumoniaVerdict.normal,
        confidence: confidence,
        processingTime: const Duration(milliseconds: 214),
        modelName: 'PulmoNet-7M',
        modelVersion: '1.0.0',
      ),
    );
