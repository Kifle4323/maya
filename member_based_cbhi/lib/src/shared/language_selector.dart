import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cbhi_state.dart';
import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, this.isLight = false});

  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final appCubit = context.read<AppCubit>();
    final currentLocale = context.watch<AppCubit>().state.locale;
    final strings = CbhiLocalizations.of(context);
    // Language codes paired with their display abbreviations (no emoji flags)
    const languages = [('en', 'EN'), ('am', 'AM'), ('om', 'OM')];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLight 
            ? AppTheme.primary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(
          color: isLight 
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.25)
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const ValueKey('lang_selector'),
          value: currentLocale.languageCode,
          dropdownColor: isLight ? Colors.white : AppTheme.primaryDark,
          icon: Icon(
            Icons.language, 
            color: isLight ? AppTheme.primary : Colors.white, 
            size: 16
          ),
          isDense: true,
          style: TextStyle(
            color: isLight ? AppTheme.primary : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: languages
              .map(
                (lang) => DropdownMenuItem(
                  value: lang.$1,
                  child: Text(
                    '${lang.$2}  ${strings.t(switch (lang.$1) {
                      'am' => 'amharic',
                      'om' => 'afaanOromo',
                      _ => 'english',
                    })}',
                  ),
                ),
              )
              .toList(),
          onChanged: (code) {
            if (code != null) {
              appCubit.setLocale(Locale(code));
            }
          },
        ),
      ),
    );
  }
}
