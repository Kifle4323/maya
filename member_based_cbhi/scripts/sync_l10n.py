import json
import os

def run_sync():
    base_path = r"c:\Users\hp\Desktop\Member_Based_CBHI\member_based_cbhi"
    l10n_dir = os.path.join(base_path, "lib", "l10n")
    target_file = os.path.join(base_path, "lib", "src", "i18n", "app_localizations.dart")
    
    langs = ['en', 'am', 'om']
    data = {}
    all_keys = set()
    
    for lang in langs:
        path = os.path.join(l10n_dir, f"app_{lang}.arb")
        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = json.load(f)
                # Filter out metadata keys
                content = {k: v for k, v in content.items() if not k.startswith('@')}
                data[lang] = content
                all_keys.update(content.keys())
        except Exception as e:
            print(f"Error reading {lang}: {e}")
            data[lang] = {}
    
    sorted_keys = sorted(list(all_keys))
    
    def get_map_content(lang):
        lines = []
        for k in sorted_keys:
            # Fallback chain: Requested -> English -> Key
            val = data[lang].get(k)
            if val is None:
                val = data['en'].get(k, k)
            
            if not isinstance(val, str):
                val = str(val)
                
            # Escape for Dart string
            escaped_val = val.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n').replace('$', '\\$')
            lines.append(f"  '{k}': '{escaped_val}',")
        return "\n".join(lines)

    header = """import 'package:flutter/material.dart';

/// Localization wrapper for the member app.
/// Exposes .t(key) and .f(key, params) for all screens.
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

  static Locale resolveFrameworkLocale(Locale locale) {
    return switch (locale.languageCode) {
      'am' => const Locale('am'),
      'om' || 'orm' => const Locale('om'),
      _ => const Locale('en'),
    };
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static LocalizationsDelegate<AppLocalizations> delegateFor(Locale locale) =>
      _AppLocalizationsDelegate(preferredLocale: locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  String t(String key) {
    final lang = locale.languageCode;
    return _strings[lang]?[key] ?? _strings['en']?[key] ?? key;
  }

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
  const _AppLocalizationsDelegate({this.preferredLocale});
  final Locale? preferredLocale;

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) =>
      old.preferredLocale?.languageCode != preferredLocale?.languageCode;

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(preferredLocale ?? locale);
}
"""

    en_map = f"const _en = <String, String>{{\n{get_map_content('en')}\n}};"
    am_map = f"const _am = <String, String>{{\n{get_map_content('am')}\n}};"
    om_map = f"const _om = <String, String>{{\n{get_map_content('om')}\n}};"

    strings_map = """
final _strings = <String, Map<String, String>>{
  'en': _en,
  'am': _am,
  'om': _om,
};
"""

    full_output = header + "\n" + en_map + "\n\n" + am_map + "\n\n" + om_map + "\n" + strings_map
    
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(full_output)
    
    print(f"Successfully synced {len(sorted_keys)} keys to {target_file}")

if __name__ == "__main__":
    run_sync()
