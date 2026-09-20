import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PulmoAI'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Chest X-ray screening'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Українська'**
  String get languageUkrainian;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @aboutTooltip.
  ///
  /// In en, this message translates to:
  /// **'About PulmoAI'**
  String get aboutTooltip;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'AI-based pneumonia detection from chest X-ray images. Analysis runs entirely on this device with PulmoNet-7M, a convolutional network trained from scratch on the RSNA Pneumonia Detection Challenge dataset. No image leaves the device.'**
  String get aboutText;

  /// No description provided for @heroBadge.
  ///
  /// In en, this message translates to:
  /// **'AI-ASSISTED SCREENING'**
  String get heroBadge;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Detect signs of pneumonia\non a chest X-ray'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PulmoAI analyses a chest radiograph and highlights lung regions associated with its decision.'**
  String get heroSubtitle;

  /// No description provided for @heroAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze X-ray'**
  String get heroAnalyze;

  /// No description provided for @heroGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get heroGallery;

  /// No description provided for @homeHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get homeHowItWorks;

  /// No description provided for @homeRecentAnalyses.
  ///
  /// In en, this message translates to:
  /// **'Recent analyses'**
  String get homeRecentAnalyses;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeStudiesAnalysed.
  ///
  /// In en, this message translates to:
  /// **'Studies analysed'**
  String get homeStudiesAnalysed;

  /// No description provided for @homeFindingsFlagged.
  ///
  /// In en, this message translates to:
  /// **'Findings flagged'**
  String get homeFindingsFlagged;

  /// No description provided for @homeAvgConfidence.
  ///
  /// In en, this message translates to:
  /// **'Avg. confidence'**
  String get homeAvgConfidence;

  /// No description provided for @homePrototypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Research prototype'**
  String get homePrototypeTitle;

  /// No description provided for @homePrototypeText.
  ///
  /// In en, this message translates to:
  /// **'PulmoAI is a decision-support prototype built for a master\'s thesis on the RSNA Pneumonia Detection Challenge dataset. It is not a medical device and must not be used for diagnosis.'**
  String get homePrototypeText;

  /// No description provided for @stepAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add the study'**
  String get stepAddTitle;

  /// No description provided for @stepAddText.
  ///
  /// In en, this message translates to:
  /// **'Open the original DICOM, pick a chest X-ray from the gallery, or capture it with the camera.'**
  String get stepAddText;

  /// No description provided for @stepRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Run the model'**
  String get stepRunTitle;

  /// No description provided for @stepRunText.
  ///
  /// In en, this message translates to:
  /// **'The image is normalised and passed to the pneumonia detection network running on this device.'**
  String get stepRunText;

  /// No description provided for @stepReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review the result'**
  String get stepReviewTitle;

  /// No description provided for @stepReviewText.
  ///
  /// In en, this message translates to:
  /// **'Get a verdict, a probability and the regions that drove it.'**
  String get stepReviewText;

  /// No description provided for @analyzeTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyze X-ray'**
  String get analyzeTitle;

  /// No description provided for @analyzeReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get analyzeReplace;

  /// No description provided for @analyzeSelectedStudy.
  ///
  /// In en, this message translates to:
  /// **'Selected study'**
  String get analyzeSelectedStudy;

  /// No description provided for @analyzeStatusAnalysing.
  ///
  /// In en, this message translates to:
  /// **'Analysing'**
  String get analyzeStatusAnalysing;

  /// No description provided for @analyzeStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get analyzeStatusReady;

  /// No description provided for @analyzeRun.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get analyzeRun;

  /// No description provided for @analyzeSelectImage.
  ///
  /// In en, this message translates to:
  /// **'Select image'**
  String get analyzeSelectImage;

  /// No description provided for @analyzeReplaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get analyzeReplaceImage;

  /// No description provided for @analyzeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis could not be completed'**
  String get analyzeErrorTitle;

  /// No description provided for @analyzeTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'For the most reliable result'**
  String get analyzeTipsTitle;

  /// No description provided for @analyzeTipsText.
  ///
  /// In en, this message translates to:
  /// **'Use a frontal (PA or AP) chest radiograph, keep the whole lung field in frame and avoid glare when photographing a film. Lateral views are not supported.'**
  String get analyzeTipsText;

  /// No description provided for @analyzeNoImageTitle.
  ///
  /// In en, this message translates to:
  /// **'No image selected'**
  String get analyzeNoImageTitle;

  /// No description provided for @analyzeNoImageText.
  ///
  /// In en, this message translates to:
  /// **'Pick a chest X-ray to continue'**
  String get analyzeNoImageText;

  /// No description provided for @analyzeBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse images'**
  String get analyzeBrowse;

  /// No description provided for @progressPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing image'**
  String get progressPreparing;

  /// No description provided for @progressNormalising.
  ///
  /// In en, this message translates to:
  /// **'Normalising intensities'**
  String get progressNormalising;

  /// No description provided for @progressInference.
  ///
  /// In en, this message translates to:
  /// **'Running inference'**
  String get progressInference;

  /// No description provided for @progressReport.
  ///
  /// In en, this message translates to:
  /// **'Building the report'**
  String get progressReport;

  /// No description provided for @progressRunning.
  ///
  /// In en, this message translates to:
  /// **'Analysing the study…'**
  String get progressRunning;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClearTooltip;

  /// No description provided for @historyClearQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get historyClearQuestion;

  /// No description provided for @historyClearBody.
  ///
  /// In en, this message translates to:
  /// **'All stored analyses will be removed from this device.'**
  String get historyClearBody;

  /// No description provided for @historyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {name}'**
  String historyRemoved(String name);

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No analyses yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Every X-ray you analyse is saved here with its verdict, probability and date.'**
  String get historyEmptyText;

  /// No description provided for @historyFilterEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this filter'**
  String get historyFilterEmptyTitle;

  /// No description provided for @historyFilterEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Try a different filter to see your other studies.'**
  String get historyFilterEmptyText;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterFindings.
  ///
  /// In en, this message translates to:
  /// **'Findings'**
  String get filterFindings;

  /// No description provided for @filterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get filterClear;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis result'**
  String get resultTitle;

  /// No description provided for @resultBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get resultBackHome;

  /// No description provided for @resultWhatThisMeans.
  ///
  /// In en, this message translates to:
  /// **'What this means'**
  String get resultWhatThisMeans;

  /// No description provided for @resultStudyDetails.
  ///
  /// In en, this message translates to:
  /// **'Study details'**
  String get resultStudyDetails;

  /// No description provided for @resultAnalyzeAnother.
  ///
  /// In en, this message translates to:
  /// **'Analyze another X-ray'**
  String get resultAnalyzeAnother;

  /// No description provided for @resultShareReport.
  ///
  /// In en, this message translates to:
  /// **'Share PDF report'**
  String get resultShareReport;

  /// No description provided for @resultReportFailed.
  ///
  /// In en, this message translates to:
  /// **'The report could not be created: {error}'**
  String resultReportFailed(String error);

  /// No description provided for @resultHeatmapText.
  ///
  /// In en, this message translates to:
  /// **'The model heatmap marks the regions associated with the model\'s decision. It is computed from the last convolutional layer on a 7x7 grid and enlarged, so it indicates an area, not a boundary — and it is not a localisation of disease.'**
  String get resultHeatmapText;

  /// No description provided for @resultNoHeatmapText.
  ///
  /// In en, this message translates to:
  /// **'No visualization layer is available for this study; the verdict and the probability below still stand on their own.'**
  String get resultNoHeatmapText;

  /// No description provided for @resultDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Not a diagnosis'**
  String get resultDisclaimerTitle;

  /// No description provided for @resultDisclaimerText.
  ///
  /// In en, this message translates to:
  /// **'This is the output of a research prototype running on this device. It is not a diagnosis and must be confirmed by a qualified radiologist before any clinical action.'**
  String get resultDisclaimerText;

  /// No description provided for @overlayOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get overlayOriginal;

  /// No description provided for @overlayHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Model heatmap'**
  String get overlayHeatmap;

  /// No description provided for @verdictPneumonia.
  ///
  /// In en, this message translates to:
  /// **'Pneumonia detected'**
  String get verdictPneumonia;

  /// No description provided for @verdictNormal.
  ///
  /// In en, this message translates to:
  /// **'No signs of pneumonia'**
  String get verdictNormal;

  /// No description provided for @verdictPneumoniaDescription.
  ///
  /// In en, this message translates to:
  /// **'Opacity consistent with pneumonia'**
  String get verdictPneumoniaDescription;

  /// No description provided for @verdictNormalDescription.
  ///
  /// In en, this message translates to:
  /// **'No opacity consistent with pneumonia'**
  String get verdictNormalDescription;

  /// No description provided for @interpretationFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding'**
  String get interpretationFinding;

  /// No description provided for @interpretationNextStep.
  ///
  /// In en, this message translates to:
  /// **'Suggested next step'**
  String get interpretationNextStep;

  /// No description provided for @interpretationLimitations.
  ///
  /// In en, this message translates to:
  /// **'Limitations'**
  String get interpretationLimitations;

  /// No description provided for @positiveFinding.
  ///
  /// In en, this message translates to:
  /// **'The model found an area of increased opacity that resembles a pneumonic infiltrate.'**
  String get positiveFinding;

  /// No description provided for @positiveNextStep.
  ///
  /// In en, this message translates to:
  /// **'Correlate with symptoms, auscultation and inflammatory markers, and have a radiologist confirm the reading.'**
  String get positiveNextStep;

  /// No description provided for @positiveLimitations.
  ///
  /// In en, this message translates to:
  /// **'Other conditions (oedema, atelectasis, tumours) can produce a similar opacity; the model does not tell them apart.'**
  String get positiveLimitations;

  /// No description provided for @negativeFinding.
  ///
  /// In en, this message translates to:
  /// **'No opacity typical of pneumonia was detected on this radiograph.'**
  String get negativeFinding;

  /// No description provided for @negativeNextStep.
  ///
  /// In en, this message translates to:
  /// **'A negative screen does not rule out infection. If symptoms persist, repeat imaging or a CT scan may be warranted.'**
  String get negativeNextStep;

  /// No description provided for @negativeLimitations.
  ///
  /// In en, this message translates to:
  /// **'Early or subtle infiltrates, and findings hidden behind the heart or the diaphragm, can be missed.'**
  String get negativeLimitations;

  /// No description provided for @confidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Model confidence'**
  String get confidenceLabel;

  /// No description provided for @confidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'The model is highly confident in this outcome. A radiologist should still confirm it.'**
  String get confidenceHigh;

  /// No description provided for @confidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Moderate to high confidence. Consider reviewing the highlighted region carefully.'**
  String get confidenceMedium;

  /// No description provided for @confidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low confidence. The image quality or projection may be limiting the model; a repeat study may help.'**
  String get confidenceLow;

  /// No description provided for @detailsStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get detailsStudy;

  /// No description provided for @detailsAnalysed.
  ///
  /// In en, this message translates to:
  /// **'Analysed'**
  String get detailsAnalysed;

  /// No description provided for @detailsModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get detailsModel;

  /// No description provided for @detailsInferenceTime.
  ///
  /// In en, this message translates to:
  /// **'Inference time'**
  String get detailsInferenceTime;

  /// No description provided for @detailsHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Model heatmap'**
  String get detailsHeatmap;

  /// No description provided for @detailsSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get detailsSource;

  /// No description provided for @detailsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get detailsAvailable;

  /// No description provided for @detailsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get detailsNotAvailable;

  /// No description provided for @sheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add chest X-ray'**
  String get sheetTitle;

  /// No description provided for @sheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a PA or AP projection for the most reliable result. DICOM is read exactly as the model was trained on.'**
  String get sheetSubtitle;

  /// No description provided for @sheetDicomTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a DICOM file'**
  String get sheetDicomTitle;

  /// No description provided for @sheetDicomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The original .dcm study, read losslessly'**
  String get sheetDicomSubtitle;

  /// No description provided for @sheetGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get sheetGalleryTitle;

  /// No description provided for @sheetGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'PNG or JPEG export of the study'**
  String get sheetGallerySubtitle;

  /// No description provided for @sheetCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Capture with camera'**
  String get sheetCameraTitle;

  /// No description provided for @sheetCameraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photograph a printed film or a monitor'**
  String get sheetCameraSubtitle;

  /// No description provided for @sheetOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the image source: {error}'**
  String sheetOpenError(String error);

  /// No description provided for @viewerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image not available on this device'**
  String get viewerUnavailable;

  /// No description provided for @errorEmptyFile.
  ///
  /// In en, this message translates to:
  /// **'The selected file is empty. Pick the study again.'**
  String get errorEmptyFile;

  /// No description provided for @errorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'{message} Open the original DICOM, or a PNG/JPEG export of the study.'**
  String errorUnsupported(String message);

  /// No description provided for @errorCorrupt.
  ///
  /// In en, this message translates to:
  /// **'{message} The file looks damaged — try copying it from the source again.'**
  String errorCorrupt(String message);

  /// No description provided for @errorModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{message} You can try again; if it keeps failing, the app has to be reinstalled so the bundled model is restored.'**
  String errorModelUnavailable(String message);

  /// No description provided for @errorAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed: {error}'**
  String errorAnalysisFailed(String error);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Chest X-ray screening report'**
  String get reportTitle;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generated on this device by PulmoAI. Not a diagnosis.'**
  String get reportSubtitle;

  /// No description provided for @reportStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get reportStudy;

  /// No description provided for @reportAnalysed.
  ///
  /// In en, this message translates to:
  /// **'Analysed'**
  String get reportAnalysed;

  /// No description provided for @reportVerdict.
  ///
  /// In en, this message translates to:
  /// **'Verdict'**
  String get reportVerdict;

  /// No description provided for @reportProbability.
  ///
  /// In en, this message translates to:
  /// **'Probability of opacity'**
  String get reportProbability;

  /// No description provided for @reportThreshold.
  ///
  /// In en, this message translates to:
  /// **'Decision threshold'**
  String get reportThreshold;

  /// No description provided for @reportModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get reportModel;

  /// No description provided for @reportInferenceTime.
  ///
  /// In en, this message translates to:
  /// **'Inference time'**
  String get reportInferenceTime;

  /// No description provided for @reportHeatmapCaption.
  ///
  /// In en, this message translates to:
  /// **'Class activation map — the region the decision responded to, not a boundary of disease'**
  String get reportHeatmapCaption;

  /// No description provided for @reportNoImages.
  ///
  /// In en, this message translates to:
  /// **'The images of this study are no longer available on the device.'**
  String get reportNoImages;

  /// No description provided for @reportDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This report is the output of a research prototype and is not a diagnosis. It must be confirmed by a qualified radiologist before any clinical action.'**
  String get reportDisclaimer;

  /// No description provided for @reportGeneratedBy.
  ///
  /// In en, this message translates to:
  /// **'PulmoAI · PulmoNet-7M · on-device inference, offline'**
  String get reportGeneratedBy;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String timeDaysAgo(int count);

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppL10nDe();
    case 'en':
      return AppL10nEn();
    case 'uk':
      return AppL10nUk();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
