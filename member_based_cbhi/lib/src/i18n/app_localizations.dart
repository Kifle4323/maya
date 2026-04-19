import 'package:flutter/material.dart';

/// Hand-written localization class for the member app.
/// Supports en (English), am (Amharic), om (Afaan Oromo).
/// Use CbhiLocalizations.of(context).t('key') in UI code.
class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('am'),
    Locale('om'),
  ];

  static const frameworkSupportedLocales = <Locale>[
    Locale('en'),
    Locale('am'),
    Locale('om'),
  ];

  static Locale resolveFrameworkLocale(Locale locale) =>
      switch (locale.languageCode) {
        'am' => const Locale('am'),
        'om' => const Locale('om'),
        _ => const Locale('en'),
      };

  static LocalizationsDelegate<AppLocalizations> get delegate =>
      const _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  /// Look up a translation by key. Falls back to English, then the key itself.
  String t(String key) {
    final lang = locale.languageCode;
    return _strings[lang]?[key] ?? _strings['en']?[key] ?? key;
  }

  /// Look up a translation with named placeholder substitution.
  String f(String key, Map<String, dynamic> params) {
    var result = t(key);
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// String tables — populated from ARB files
// ─────────────────────────────────────────────────────────────────────────────

final _strings = <String, Map<String, String>>{
  'en': _en,
  'am': _am,
  'om': _om,
};

