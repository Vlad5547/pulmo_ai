// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppL10nUk extends AppL10n {
  AppL10nUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'PulmoAI';

  @override
  String get appTagline => 'Скринінг рентгенограм ОГК';

  @override
  String get navHome => 'Головна';

  @override
  String get navHistory => 'Історія';

  @override
  String get languageTitle => 'Мова';

  @override
  String get languageSystem => 'Як у системі';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get aboutTooltip => 'Про PulmoAI';

  @override
  String get aboutText =>
      'Виявлення ознак пневмонії на рентгенограмах органів грудної клітки. Аналіз виконується повністю на цьому пристрої мережею PulmoNet-7M, навченою з нуля на наборі RSNA Pneumonia Detection Challenge. Жодне зображення не залишає пристрій.';

  @override
  String get heroBadge => 'СКРИНІНГ ІЗ ШТУЧНИМ ІНТЕЛЕКТОМ';

  @override
  String get heroTitle => 'Виявлення ознак пневмонії\nна рентгенограмі ОГК';

  @override
  String get heroSubtitle =>
      'PulmoAI аналізує рентгенограму та підсвічує ділянки легень, які вплинули на рішення моделі.';

  @override
  String get heroAnalyze => 'Аналізувати знімок';

  @override
  String get heroGallery => 'Вибрати з галереї';

  @override
  String get homeHowItWorks => 'Як це працює';

  @override
  String get homeRecentAnalyses => 'Останні аналізи';

  @override
  String get homeSeeAll => 'Усі';

  @override
  String get homeStudiesAnalysed => 'Проаналізовано';

  @override
  String get homeFindingsFlagged => 'Зі знахідками';

  @override
  String get homeAvgConfidence => 'Середня впевненість';

  @override
  String get homePrototypeTitle => 'Дослідницький прототип';

  @override
  String get homePrototypeText =>
      'PulmoAI — прототип системи підтримки прийняття рішень, створений у межах магістерської роботи на наборі даних RSNA Pneumonia Detection Challenge. Це не медичний виріб, і його не можна використовувати для встановлення діагнозу.';

  @override
  String get stepAddTitle => 'Додайте дослідження';

  @override
  String get stepAddText =>
      'Відкрийте оригінальний DICOM, виберіть знімок із галереї або зробіть фото камерою.';

  @override
  String get stepRunTitle => 'Запустіть модель';

  @override
  String get stepRunText =>
      'Зображення нормалізується та подається до нейронної мережі, що працює на цьому пристрої.';

  @override
  String get stepReviewTitle => 'Перегляньте результат';

  @override
  String get stepReviewText =>
      'Ви отримаєте вердикт, ймовірність і ділянки, які визначили рішення.';

  @override
  String get analyzeTitle => 'Аналіз знімка';

  @override
  String get analyzeReplace => 'Замінити';

  @override
  String get analyzeSelectedStudy => 'Обране дослідження';

  @override
  String get analyzeStatusAnalysing => 'Аналіз';

  @override
  String get analyzeStatusReady => 'Готово';

  @override
  String get analyzeRun => 'Аналізувати';

  @override
  String get analyzeSelectImage => 'Вибрати зображення';

  @override
  String get analyzeReplaceImage => 'Замінити зображення';

  @override
  String get analyzeErrorTitle => 'Не вдалося виконати аналіз';

  @override
  String get analyzeTipsTitle => 'Для найнадійнішого результату';

  @override
  String get analyzeTipsText =>
      'Використовуйте пряму (PA або AP) рентгенограму ОГК, тримайте в кадрі всі легеневі поля та уникайте відблисків під час фотографування плівки. Бічні проєкції не підтримуються.';

  @override
  String get analyzeNoImageTitle => 'Зображення не вибрано';

  @override
  String get analyzeNoImageText => 'Виберіть рентгенограму, щоб продовжити';

  @override
  String get analyzeBrowse => 'Огляд зображень';

  @override
  String get progressPreparing => 'Підготовка зображення';

  @override
  String get progressNormalising => 'Нормалізація інтенсивностей';

  @override
  String get progressInference => 'Виконання інференсу';

  @override
  String get progressReport => 'Формування звіту';

  @override
  String get progressRunning => 'Аналізуємо дослідження…';

  @override
  String get historyTitle => 'Історія';

  @override
  String get historyClearTooltip => 'Очистити історію';

  @override
  String get historyClearQuestion => 'Очистити історію?';

  @override
  String get historyClearBody =>
      'Усі збережені аналізи буде видалено з цього пристрою.';

  @override
  String historyRemoved(String name) {
    return 'Видалено $name';
  }

  @override
  String get historyEmptyTitle => 'Аналізів ще немає';

  @override
  String get historyEmptyText =>
      'Кожен проаналізований знімок зберігається тут разом із вердиктом, ймовірністю та датою.';

  @override
  String get historyFilterEmptyTitle => 'За цим фільтром нічого немає';

  @override
  String get historyFilterEmptyText =>
      'Спробуйте інший фільтр, щоб побачити інші дослідження.';

  @override
  String get filterAll => 'Усі';

  @override
  String get filterFindings => 'Знахідки';

  @override
  String get filterClear => 'Без знахідок';

  @override
  String get actionCancel => 'Скасувати';

  @override
  String get actionClear => 'Очистити';

  @override
  String get actionDelete => 'Видалити';

  @override
  String get resultTitle => 'Результат аналізу';

  @override
  String get resultBackHome => 'На головну';

  @override
  String get resultWhatThisMeans => 'Що це означає';

  @override
  String get resultStudyDetails => 'Деталі дослідження';

  @override
  String get resultAnalyzeAnother => 'Аналізувати інший знімок';

  @override
  String get resultShareReport => 'Надіслати PDF-звіт';

  @override
  String resultReportFailed(String error) {
    return 'Не вдалося створити звіт: $error';
  }

  @override
  String get resultHeatmapText =>
      'Теплова карта позначає ділянки, на які відреагувало рішення моделі. Вона обчислюється з останнього згорткового шару на сітці 7x7 і збільшується, тому вказує на область, а не на межу, і не є локалізацією захворювання.';

  @override
  String get resultNoHeatmapText =>
      'Для цього дослідження шар візуалізації недоступний; вердикт і ймовірність нижче залишаються чинними.';

  @override
  String get resultDisclaimerTitle => 'Це не діагноз';

  @override
  String get resultDisclaimerText =>
      'Це результат роботи дослідницького прототипу на цьому пристрої. Він не є діагнозом і має бути підтверджений кваліфікованим лікарем-рентгенологом перед будь-якими клінічними діями.';

  @override
  String get overlayOriginal => 'Оригінал';

  @override
  String get overlayHeatmap => 'Теплова карта';

  @override
  String get verdictPneumonia => 'Виявлено ознаки пневмонії';

  @override
  String get verdictNormal => 'Ознак пневмонії не виявлено';

  @override
  String get verdictPneumoniaDescription => 'Затемнення, сумісне з пневмонією';

  @override
  String get verdictNormalDescription =>
      'Затемнення, сумісного з пневмонією, немає';

  @override
  String get interpretationFinding => 'Знахідка';

  @override
  String get interpretationNextStep => 'Рекомендований наступний крок';

  @override
  String get interpretationLimitations => 'Обмеження';

  @override
  String get positiveFinding =>
      'Модель виявила ділянку підвищеної щільності, схожу на пневмонічний інфільтрат.';

  @override
  String get positiveNextStep =>
      'Зіставте з симптомами, даними аускультації та маркерами запалення; висновок має підтвердити рентгенолог.';

  @override
  String get positiveLimitations =>
      'Подібне затемнення дають й інші стани (набряк легень, ателектаз, пухлини); модель їх не розрізняє.';

  @override
  String get negativeFinding =>
      'Затемнення, типового для пневмонії, на цій рентгенограмі не виявлено.';

  @override
  String get negativeNextStep =>
      'Негативний результат скринінгу не виключає інфекції. Якщо симптоми зберігаються, може знадобитися повторне дослідження або КТ.';

  @override
  String get negativeLimitations =>
      'Ранні чи слабко виражені інфільтрати, а також зміни за тінню серця чи діафрагми можуть бути пропущені.';

  @override
  String get confidenceLabel => 'Впевненість моделі';

  @override
  String get confidenceHigh =>
      'Модель дуже впевнена в цьому результаті. Його все одно має підтвердити рентгенолог.';

  @override
  String get confidenceMedium =>
      'Помірна або висока впевненість. Варто уважно переглянути підсвічену ділянку.';

  @override
  String get confidenceLow =>
      'Низька впевненість. Якість або проєкція знімка можуть обмежувати модель; варто повторити дослідження.';

  @override
  String get detailsStudy => 'Дослідження';

  @override
  String get detailsAnalysed => 'Проаналізовано';

  @override
  String get detailsModel => 'Модель';

  @override
  String get detailsInferenceTime => 'Час інференсу';

  @override
  String get detailsHeatmap => 'Теплова карта';

  @override
  String get detailsSource => 'Джерело';

  @override
  String get detailsAvailable => 'Доступна';

  @override
  String get detailsNotAvailable => 'Недоступна';

  @override
  String get sheetTitle => 'Додати рентгенограму';

  @override
  String get sheetSubtitle =>
      'Для найнадійнішого результату використовуйте проєкцію PA або AP. DICOM читається саме так, як модель навчалася.';

  @override
  String get sheetDicomTitle => 'Відкрити файл DICOM';

  @override
  String get sheetDicomSubtitle => 'Оригінальне дослідження .dcm, без втрат';

  @override
  String get sheetGalleryTitle => 'Вибрати з галереї';

  @override
  String get sheetGallerySubtitle => 'Експорт дослідження у PNG або JPEG';

  @override
  String get sheetCameraTitle => 'Зняти камерою';

  @override
  String get sheetCameraSubtitle => 'Сфотографувати плівку або екран';

  @override
  String sheetOpenError(String error) {
    return 'Не вдалося відкрити джерело зображення: $error';
  }

  @override
  String get viewerUnavailable => 'Зображення недоступне на цьому пристрої';

  @override
  String get errorEmptyFile =>
      'Вибраний файл порожній. Виберіть дослідження ще раз.';

  @override
  String errorUnsupported(String message) {
    return '$message Відкрийте оригінальний DICOM або експорт дослідження у PNG/JPEG.';
  }

  @override
  String errorCorrupt(String message) {
    return '$message Файл виглядає пошкодженим — спробуйте скопіювати його з джерела ще раз.';
  }

  @override
  String errorModelUnavailable(String message) {
    return '$message Спробуйте ще раз; якщо помилка повторюється, застосунок потрібно перевстановити, щоб відновити вбудовану модель.';
  }

  @override
  String errorAnalysisFailed(String error) {
    return 'Аналіз не вдався: $error';
  }

  @override
  String get reportTitle => 'Звіт скринінгу рентгенограми ОГК';

  @override
  String get reportSubtitle =>
      'Сформовано на цьому пристрої застосунком PulmoAI. Не є діагнозом.';

  @override
  String get reportStudy => 'Дослідження';

  @override
  String get reportAnalysed => 'Проаналізовано';

  @override
  String get reportVerdict => 'Вердикт';

  @override
  String get reportProbability => 'Ймовірність затемнення';

  @override
  String get reportThreshold => 'Поріг рішення';

  @override
  String get reportModel => 'Модель';

  @override
  String get reportInferenceTime => 'Час інференсу';

  @override
  String get reportHeatmapCaption =>
      'Карта активації класу — ділянка, на яку відреагувало рішення, а не межа патології';

  @override
  String get reportNoImages =>
      'Зображення цього дослідження більше недоступні на пристрої.';

  @override
  String get reportDisclaimer =>
      'Цей звіт є результатом роботи дослідницького прототипу і не є діагнозом. Він має бути підтверджений кваліфікованим лікарем-рентгенологом перед будь-якими клінічними діями.';

  @override
  String get reportGeneratedBy =>
      'PulmoAI · PulmoNet-7M · інференс на пристрої, офлайн';

  @override
  String get timeJustNow => 'Щойно';

  @override
  String timeMinutesAgo(int count) {
    return '$count хв тому';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count год тому';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count дн тому';
  }

  @override
  String aboutVersion(String version) {
    return 'Версія $version';
  }

  @override
  String get actionClose => 'Закрити';
}
