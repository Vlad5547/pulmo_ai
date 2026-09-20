import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// The language the UI is drawn in.
///
/// Defaults to the device language; the picker in the app bar overrides it for
/// the session. A thesis demo has to be shown in Ukrainian on a phone set to
/// English, so relying on the system locale alone is not enough.
class LocaleController extends ChangeNotifier {
  LocaleController([this._locale]);

  Locale? _locale;

  /// Null means "follow the device".
  Locale? get locale => _locale;

  /// The locales the app ships translations for.
  static List<Locale> get supported => AppL10n.supportedLocales;

  void setLocale(Locale? locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}
