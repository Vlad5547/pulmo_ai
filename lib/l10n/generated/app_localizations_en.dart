// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PulmoAI';

  @override
  String get appTagline => 'Chest X-ray screening';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get aboutTooltip => 'About PulmoAI';

  @override
  String get aboutText =>
      'AI-based pneumonia detection from chest X-ray images. Analysis runs entirely on this device with PulmoNet-7M, a convolutional network trained from scratch on the RSNA Pneumonia Detection Challenge dataset. No image leaves the device.';

  @override
  String get heroBadge => 'AI-ASSISTED SCREENING';

  @override
  String get heroTitle => 'Detect signs of pneumonia\non a chest X-ray';

  @override
  String get heroSubtitle =>
      'PulmoAI analyses a chest radiograph and highlights lung regions associated with its decision.';

  @override
  String get heroAnalyze => 'Analyze X-ray';

  @override
  String get heroGallery => 'Choose from gallery';

  @override
  String get homeHowItWorks => 'How it works';

  @override
  String get homeRecentAnalyses => 'Recent analyses';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeStudiesAnalysed => 'Studies analysed';

  @override
  String get homeFindingsFlagged => 'Findings flagged';

  @override
  String get homeAvgConfidence => 'Avg. confidence';

  @override
  String get homePrototypeTitle => 'Research prototype';

  @override
  String get homePrototypeText =>
      'PulmoAI is a decision-support prototype built for a master\'s thesis on the RSNA Pneumonia Detection Challenge dataset. It is not a medical device and must not be used for diagnosis.';

  @override
  String get stepAddTitle => 'Add the study';

  @override
  String get stepAddText =>
      'Open the original DICOM, pick a chest X-ray from the gallery, or capture it with the camera.';

  @override
  String get stepRunTitle => 'Run the model';

  @override
  String get stepRunText =>
      'The image is normalised and passed to the pneumonia detection network running on this device.';

  @override
  String get stepReviewTitle => 'Review the result';

  @override
  String get stepReviewText =>
      'Get a verdict, a probability and the regions that drove it.';

  @override
  String get analyzeTitle => 'Analyze X-ray';

  @override
  String get analyzeReplace => 'Replace';

  @override
  String get analyzeSelectedStudy => 'Selected study';

  @override
  String get analyzeStatusAnalysing => 'Analysing';

  @override
  String get analyzeStatusReady => 'Ready';

  @override
  String get analyzeRun => 'Analyze';

  @override
  String get analyzeSelectImage => 'Select image';

  @override
  String get analyzeReplaceImage => 'Replace image';

  @override
  String get analyzeErrorTitle => 'Analysis could not be completed';

  @override
  String get analyzeTipsTitle => 'For the most reliable result';

  @override
  String get analyzeTipsText =>
      'Use a frontal (PA or AP) chest radiograph, keep the whole lung field in frame and avoid glare when photographing a film. Lateral views are not supported.';

  @override
  String get analyzeNoImageTitle => 'No image selected';

  @override
  String get analyzeNoImageText => 'Pick a chest X-ray to continue';

  @override
  String get analyzeBrowse => 'Browse images';

  @override
  String get progressPreparing => 'Preparing image';

  @override
  String get progressNormalising => 'Normalising intensities';

  @override
  String get progressInference => 'Running inference';

  @override
  String get progressReport => 'Building the report';

  @override
  String get progressRunning => 'Analysing the study…';

  @override
  String get historyTitle => 'History';

  @override
  String get historyClearTooltip => 'Clear history';

  @override
  String get historyClearQuestion => 'Clear history?';

  @override
  String get historyClearBody =>
      'All stored analyses will be removed from this device.';

  @override
  String historyRemoved(String name) {
    return 'Removed $name';
  }

  @override
  String get historyEmptyTitle => 'No analyses yet';

  @override
  String get historyEmptyText =>
      'Every X-ray you analyse is saved here with its verdict, probability and date.';

  @override
  String get historyFilterEmptyTitle => 'Nothing in this filter';

  @override
  String get historyFilterEmptyText =>
      'Try a different filter to see your other studies.';

  @override
  String get filterAll => 'All';

  @override
  String get filterFindings => 'Findings';

  @override
  String get filterClear => 'Clear';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionDelete => 'Delete';

  @override
  String get resultTitle => 'Analysis result';

  @override
  String get resultBackHome => 'Back to home';

  @override
  String get resultWhatThisMeans => 'What this means';

  @override
  String get resultStudyDetails => 'Study details';

  @override
  String get resultAnalyzeAnother => 'Analyze another X-ray';

  @override
  String get resultShareReport => 'Share PDF report';

  @override
  String resultReportFailed(String error) {
    return 'The report could not be created: $error';
  }

  @override
  String get resultHeatmapText =>
      'The model heatmap marks the regions associated with the model\'s decision. It is computed from the last convolutional layer on a 7x7 grid and enlarged, so it indicates an area, not a boundary — and it is not a localisation of disease.';

  @override
  String get resultNoHeatmapText =>
      'No visualization layer is available for this study; the verdict and the probability below still stand on their own.';

  @override
  String get resultDisclaimerTitle => 'Not a diagnosis';

  @override
  String get resultDisclaimerText =>
      'This is the output of a research prototype running on this device. It is not a diagnosis and must be confirmed by a qualified radiologist before any clinical action.';

  @override
  String get overlayOriginal => 'Original';

  @override
  String get overlayHeatmap => 'Model heatmap';

  @override
  String get verdictPneumonia => 'Pneumonia detected';

  @override
  String get verdictNormal => 'No signs of pneumonia';

  @override
  String get verdictPneumoniaDescription => 'Opacity consistent with pneumonia';

  @override
  String get verdictNormalDescription => 'No opacity consistent with pneumonia';

  @override
  String get interpretationFinding => 'Finding';

  @override
  String get interpretationNextStep => 'Suggested next step';

  @override
  String get interpretationLimitations => 'Limitations';

  @override
  String get positiveFinding =>
      'The model found an area of increased opacity that resembles a pneumonic infiltrate.';

  @override
  String get positiveNextStep =>
      'Correlate with symptoms, auscultation and inflammatory markers, and have a radiologist confirm the reading.';

  @override
  String get positiveLimitations =>
      'Other conditions (oedema, atelectasis, tumours) can produce a similar opacity; the model does not tell them apart.';

  @override
  String get negativeFinding =>
      'No opacity typical of pneumonia was detected on this radiograph.';

  @override
  String get negativeNextStep =>
      'A negative screen does not rule out infection. If symptoms persist, repeat imaging or a CT scan may be warranted.';

  @override
  String get negativeLimitations =>
      'Early or subtle infiltrates, and findings hidden behind the heart or the diaphragm, can be missed.';

  @override
  String get confidenceLabel => 'Model confidence';

  @override
  String get confidenceHigh =>
      'The model is highly confident in this outcome. A radiologist should still confirm it.';

  @override
  String get confidenceMedium =>
      'Moderate to high confidence. Consider reviewing the highlighted region carefully.';

  @override
  String get confidenceLow =>
      'Low confidence. The image quality or projection may be limiting the model; a repeat study may help.';

  @override
  String get detailsStudy => 'Study';

  @override
  String get detailsAnalysed => 'Analysed';

  @override
  String get detailsModel => 'Model';

  @override
  String get detailsInferenceTime => 'Inference time';

  @override
  String get detailsHeatmap => 'Model heatmap';

  @override
  String get detailsSource => 'Source';

  @override
  String get detailsAvailable => 'Available';

  @override
  String get detailsNotAvailable => 'Not available';

  @override
  String get sheetTitle => 'Add chest X-ray';

  @override
  String get sheetSubtitle =>
      'Use a PA or AP projection for the most reliable result. DICOM is read exactly as the model was trained on.';

  @override
  String get sheetDicomTitle => 'Open a DICOM file';

  @override
  String get sheetDicomSubtitle => 'The original .dcm study, read losslessly';

  @override
  String get sheetGalleryTitle => 'Choose from gallery';

  @override
  String get sheetGallerySubtitle => 'PNG or JPEG export of the study';

  @override
  String get sheetCameraTitle => 'Capture with camera';

  @override
  String get sheetCameraSubtitle => 'Photograph a printed film or a monitor';

  @override
  String sheetOpenError(String error) {
    return 'Could not open the image source: $error';
  }

  @override
  String get viewerUnavailable => 'Image not available on this device';

  @override
  String get errorEmptyFile =>
      'The selected file is empty. Pick the study again.';

  @override
  String errorUnsupported(String message) {
    return '$message Open the original DICOM, or a PNG/JPEG export of the study.';
  }

  @override
  String errorCorrupt(String message) {
    return '$message The file looks damaged — try copying it from the source again.';
  }

  @override
  String errorModelUnavailable(String message) {
    return '$message You can try again; if it keeps failing, the app has to be reinstalled so the bundled model is restored.';
  }

  @override
  String errorAnalysisFailed(String error) {
    return 'Analysis failed: $error';
  }

  @override
  String get reportTitle => 'Chest X-ray screening report';

  @override
  String get reportSubtitle =>
      'Generated on this device by PulmoAI. Not a diagnosis.';

  @override
  String get reportStudy => 'Study';

  @override
  String get reportAnalysed => 'Analysed';

  @override
  String get reportVerdict => 'Verdict';

  @override
  String get reportProbability => 'Probability of opacity';

  @override
  String get reportThreshold => 'Decision threshold';

  @override
  String get reportModel => 'Model';

  @override
  String get reportInferenceTime => 'Inference time';

  @override
  String get reportHeatmapCaption =>
      'Class activation map — the region the decision responded to, not a boundary of disease';

  @override
  String get reportNoImages =>
      'The images of this study are no longer available on the device.';

  @override
  String get reportDisclaimer =>
      'This report is the output of a research prototype and is not a diagnosis. It must be confirmed by a qualified radiologist before any clinical action.';

  @override
  String get reportGeneratedBy =>
      'PulmoAI · PulmoNet-7M · on-device inference, offline';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count d ago';
  }

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get actionClose => 'Close';
}
