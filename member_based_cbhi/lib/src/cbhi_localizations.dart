import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'i18n/app_localizations.dart';

/// Public API for member-app strings (en / am / om).
/// All screens call CbhiLocalizations.of(context).t('key').
abstract final class CbhiLocalizations {
  CbhiLocalizations._();

  static AppLocalizations of(BuildContext context) =>
      AppLocalizations.of(context);

  static List<Locale> get supportedLocales => AppLocalizations.supportedLocales;

  static List<LocalizationsDelegate<dynamic>> get delegates => [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static List<LocalizationsDelegate<dynamic>> delegatesFor(Locale locale) => [
    AppLocalizations.delegateFor(locale),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
