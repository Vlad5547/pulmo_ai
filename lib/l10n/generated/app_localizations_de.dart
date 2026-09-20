// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppL10nDe extends AppL10n {
  AppL10nDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'PulmoAI';

  @override
  String get appTagline => 'Thorax-Röntgen-Screening';

  @override
  String get navHome => 'Start';

  @override
  String get navHistory => 'Verlauf';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageSystem => 'Systemsprache';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get aboutTooltip => 'Über PulmoAI';

  @override
  String get aboutText =>
      'KI-gestützte Erkennung von Pneumonie-Zeichen auf Thorax-Röntgenaufnahmen. Die Analyse läuft vollständig auf diesem Gerät mit PulmoNet-7M, einem von Grund auf trainierten Faltungsnetz auf dem Datensatz der RSNA Pneumonia Detection Challenge. Kein Bild verlässt das Gerät.';

  @override
  String get heroBadge => 'KI-GESTÜTZTES SCREENING';

  @override
  String get heroTitle =>
      'Pneumonie-Zeichen auf dem\nThorax-Röntgenbild erkennen';

  @override
  String get heroSubtitle =>
      'PulmoAI analysiert eine Thoraxaufnahme und hebt die Lungenregionen hervor, die zur Entscheidung beigetragen haben.';

  @override
  String get heroAnalyze => 'Aufnahme analysieren';

  @override
  String get heroGallery => 'Aus der Galerie wählen';

  @override
  String get homeHowItWorks => 'So funktioniert es';

  @override
  String get homeRecentAnalyses => 'Letzte Analysen';

  @override
  String get homeSeeAll => 'Alle ansehen';

  @override
  String get homeStudiesAnalysed => 'Analysierte Aufnahmen';

  @override
  String get homeFindingsFlagged => 'Auffällige Befunde';

  @override
  String get homeAvgConfidence => 'Ø Konfidenz';

  @override
  String get homePrototypeTitle => 'Forschungsprototyp';

  @override
  String get homePrototypeText =>
      'PulmoAI ist ein Prototyp zur Entscheidungsunterstützung, entwickelt im Rahmen einer Masterarbeit auf dem Datensatz der RSNA Pneumonia Detection Challenge. Es ist kein Medizinprodukt und darf nicht zur Diagnose verwendet werden.';

  @override
  String get stepAddTitle => 'Aufnahme hinzufügen';

  @override
  String get stepAddText =>
      'Öffnen Sie die originale DICOM-Datei, wählen Sie ein Röntgenbild aus der Galerie oder nehmen Sie es mit der Kamera auf.';

  @override
  String get stepRunTitle => 'Modell ausführen';

  @override
  String get stepRunText =>
      'Das Bild wird normalisiert und an das auf diesem Gerät laufende Netz zur Pneumonie-Erkennung übergeben.';

  @override
  String get stepReviewTitle => 'Ergebnis prüfen';

  @override
  String get stepReviewText =>
      'Sie erhalten ein Votum, eine Wahrscheinlichkeit und die Regionen, die dazu geführt haben.';

  @override
  String get analyzeTitle => 'Aufnahme analysieren';

  @override
  String get analyzeReplace => 'Ersetzen';

  @override
  String get analyzeSelectedStudy => 'Ausgewählte Aufnahme';

  @override
  String get analyzeStatusAnalysing => 'Analyse läuft';

  @override
  String get analyzeStatusReady => 'Bereit';

  @override
  String get analyzeRun => 'Analysieren';

  @override
  String get analyzeSelectImage => 'Bild auswählen';

  @override
  String get analyzeReplaceImage => 'Bild ersetzen';

  @override
  String get analyzeErrorTitle => 'Analyse konnte nicht abgeschlossen werden';

  @override
  String get analyzeTipsTitle => 'Für das zuverlässigste Ergebnis';

  @override
  String get analyzeTipsText =>
      'Verwenden Sie eine frontale Thoraxaufnahme (PA oder AP), halten Sie das gesamte Lungenfeld im Bild und vermeiden Sie Reflexionen beim Abfotografieren eines Films. Seitliche Aufnahmen werden nicht unterstützt.';

  @override
  String get analyzeNoImageTitle => 'Kein Bild ausgewählt';

  @override
  String get analyzeNoImageText =>
      'Wählen Sie eine Thoraxaufnahme, um fortzufahren';

  @override
  String get analyzeBrowse => 'Bilder durchsuchen';

  @override
  String get progressPreparing => 'Bild wird vorbereitet';

  @override
  String get progressNormalising => 'Intensitäten werden normalisiert';

  @override
  String get progressInference => 'Inferenz läuft';

  @override
  String get progressReport => 'Bericht wird erstellt';

  @override
  String get progressRunning => 'Aufnahme wird analysiert …';

  @override
  String get historyTitle => 'Verlauf';

  @override
  String get historyClearTooltip => 'Verlauf löschen';

  @override
  String get historyClearQuestion => 'Verlauf löschen?';

  @override
  String get historyClearBody =>
      'Alle gespeicherten Analysen werden von diesem Gerät entfernt.';

  @override
  String historyRemoved(String name) {
    return '$name entfernt';
  }

  @override
  String get historyEmptyTitle => 'Noch keine Analysen';

  @override
  String get historyEmptyText =>
      'Jede analysierte Aufnahme wird hier mit Votum, Wahrscheinlichkeit und Datum gespeichert.';

  @override
  String get historyFilterEmptyTitle => 'Nichts in diesem Filter';

  @override
  String get historyFilterEmptyText =>
      'Wählen Sie einen anderen Filter, um Ihre übrigen Aufnahmen zu sehen.';

  @override
  String get filterAll => 'Alle';

  @override
  String get filterFindings => 'Befunde';

  @override
  String get filterClear => 'Ohne Befund';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionClear => 'Löschen';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get resultTitle => 'Analyseergebnis';

  @override
  String get resultBackHome => 'Zurück zum Start';

  @override
  String get resultWhatThisMeans => 'Was das bedeutet';

  @override
  String get resultStudyDetails => 'Details zur Aufnahme';

  @override
  String get resultAnalyzeAnother => 'Weitere Aufnahme analysieren';

  @override
  String get resultShareReport => 'PDF-Bericht teilen';

  @override
  String resultReportFailed(String error) {
    return 'Der Bericht konnte nicht erstellt werden: $error';
  }

  @override
  String get resultHeatmapText =>
      'Die Heatmap markiert die Regionen, auf die die Entscheidung des Modells reagiert hat. Sie wird aus der letzten Faltungsschicht auf einem 7x7-Raster berechnet und vergrößert; sie zeigt also einen Bereich, keine Grenze, und ist keine Lokalisierung der Erkrankung.';

  @override
  String get resultNoHeatmapText =>
      'Für diese Aufnahme ist keine Visualisierungsebene verfügbar; Votum und Wahrscheinlichkeit darunter gelten unabhängig davon.';

  @override
  String get resultDisclaimerTitle => 'Keine Diagnose';

  @override
  String get resultDisclaimerText =>
      'Dies ist die Ausgabe eines Forschungsprototyps, der auf diesem Gerät läuft. Sie ist keine Diagnose und muss vor jeder klinischen Maßnahme von einer qualifizierten Radiologin oder einem qualifizierten Radiologen bestätigt werden.';

  @override
  String get overlayOriginal => 'Original';

  @override
  String get overlayHeatmap => 'Heatmap';

  @override
  String get verdictPneumonia => 'Pneumonie-Zeichen erkannt';

  @override
  String get verdictNormal => 'Keine Pneumonie-Zeichen';

  @override
  String get verdictPneumoniaDescription =>
      'Verschattung vereinbar mit einer Pneumonie';

  @override
  String get verdictNormalDescription =>
      'Keine mit einer Pneumonie vereinbare Verschattung';

  @override
  String get interpretationFinding => 'Befund';

  @override
  String get interpretationNextStep => 'Empfohlener nächster Schritt';

  @override
  String get interpretationLimitations => 'Einschränkungen';

  @override
  String get positiveFinding =>
      'Das Modell hat einen Bereich erhöhter Verschattung gefunden, der einem pneumonischen Infiltrat ähnelt.';

  @override
  String get positiveNextStep =>
      'Mit Symptomen, Auskultation und Entzündungsparametern abgleichen und den Befund radiologisch bestätigen lassen.';

  @override
  String get positiveLimitations =>
      'Auch andere Zustände (Ödem, Atelektase, Tumoren) können eine ähnliche Verschattung erzeugen; das Modell unterscheidet sie nicht.';

  @override
  String get negativeFinding =>
      'Auf dieser Aufnahme wurde keine für eine Pneumonie typische Verschattung erkannt.';

  @override
  String get negativeNextStep =>
      'Ein negatives Screening schließt eine Infektion nicht aus. Bei anhaltenden Symptomen können eine Verlaufsaufnahme oder ein CT sinnvoll sein.';

  @override
  String get negativeLimitations =>
      'Frühe oder diskrete Infiltrate sowie Befunde hinter Herz oder Zwerchfell können übersehen werden.';

  @override
  String get confidenceLabel => 'Konfidenz des Modells';

  @override
  String get confidenceHigh =>
      'Das Modell ist sich dieses Ergebnisses sehr sicher. Es sollte dennoch radiologisch bestätigt werden.';

  @override
  String get confidenceMedium =>
      'Mittlere bis hohe Konfidenz. Prüfen Sie den hervorgehobenen Bereich sorgfältig.';

  @override
  String get confidenceLow =>
      'Geringe Konfidenz. Bildqualität oder Projektion könnten das Modell einschränken; eine Wiederholungsaufnahme kann helfen.';

  @override
  String get detailsStudy => 'Aufnahme';

  @override
  String get detailsAnalysed => 'Analysiert';

  @override
  String get detailsModel => 'Modell';

  @override
  String get detailsInferenceTime => 'Inferenzzeit';

  @override
  String get detailsHeatmap => 'Heatmap';

  @override
  String get detailsSource => 'Quelle';

  @override
  String get detailsAvailable => 'Verfügbar';

  @override
  String get detailsNotAvailable => 'Nicht verfügbar';

  @override
  String get sheetTitle => 'Thoraxaufnahme hinzufügen';

  @override
  String get sheetSubtitle =>
      'Verwenden Sie für das zuverlässigste Ergebnis eine PA- oder AP-Projektion. DICOM wird genau so gelesen, wie das Modell trainiert wurde.';

  @override
  String get sheetDicomTitle => 'DICOM-Datei öffnen';

  @override
  String get sheetDicomSubtitle =>
      'Die originale .dcm-Aufnahme, verlustfrei gelesen';

  @override
  String get sheetGalleryTitle => 'Aus der Galerie wählen';

  @override
  String get sheetGallerySubtitle => 'PNG- oder JPEG-Export der Aufnahme';

  @override
  String get sheetCameraTitle => 'Mit der Kamera aufnehmen';

  @override
  String get sheetCameraSubtitle =>
      'Einen Film oder einen Monitor abfotografieren';

  @override
  String sheetOpenError(String error) {
    return 'Die Bildquelle konnte nicht geöffnet werden: $error';
  }

  @override
  String get viewerUnavailable => 'Bild auf diesem Gerät nicht verfügbar';

  @override
  String get errorEmptyFile =>
      'Die ausgewählte Datei ist leer. Wählen Sie die Aufnahme erneut.';

  @override
  String errorUnsupported(String message) {
    return '$message Öffnen Sie die originale DICOM-Datei oder einen PNG-/JPEG-Export der Aufnahme.';
  }

  @override
  String errorCorrupt(String message) {
    return '$message Die Datei scheint beschädigt zu sein — kopieren Sie sie erneut von der Quelle.';
  }

  @override
  String errorModelUnavailable(String message) {
    return '$message Versuchen Sie es erneut; falls der Fehler bestehen bleibt, muss die App neu installiert werden, damit das mitgelieferte Modell wiederhergestellt wird.';
  }

  @override
  String errorAnalysisFailed(String error) {
    return 'Analyse fehlgeschlagen: $error';
  }

  @override
  String get reportTitle => 'Bericht zum Thorax-Röntgen-Screening';

  @override
  String get reportSubtitle =>
      'Auf diesem Gerät von PulmoAI erstellt. Keine Diagnose.';

  @override
  String get reportStudy => 'Aufnahme';

  @override
  String get reportAnalysed => 'Analysiert';

  @override
  String get reportVerdict => 'Votum';

  @override
  String get reportProbability => 'Wahrscheinlichkeit einer Verschattung';

  @override
  String get reportThreshold => 'Entscheidungsschwelle';

  @override
  String get reportModel => 'Modell';

  @override
  String get reportInferenceTime => 'Inferenzzeit';

  @override
  String get reportHeatmapCaption =>
      'Class Activation Map — der Bereich, auf den die Entscheidung reagiert hat, keine Krankheitsgrenze';

  @override
  String get reportNoImages =>
      'Die Bilder dieser Aufnahme sind auf dem Gerät nicht mehr verfügbar.';

  @override
  String get reportDisclaimer =>
      'Dieser Bericht ist die Ausgabe eines Forschungsprototyps und keine Diagnose. Er muss vor jeder klinischen Maßnahme von einer qualifizierten Radiologin oder einem qualifizierten Radiologen bestätigt werden.';

  @override
  String get reportGeneratedBy =>
      'PulmoAI · PulmoNet-7M · Inferenz auf dem Gerät, offline';

  @override
  String get timeJustNow => 'Gerade eben';

  @override
  String timeMinutesAgo(int count) {
    return 'vor $count Min.';
  }

  @override
  String timeHoursAgo(int count) {
    return 'vor $count Std.';
  }

  @override
  String timeDaysAgo(int count) {
    return 'vor $count Tagen';
  }

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get actionClose => 'Schließen';
}
