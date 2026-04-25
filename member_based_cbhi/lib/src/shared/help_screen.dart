import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    // FAQ data using localized strings
    final faqs = [
      _FaqItem(
        questionKey: 'faqQ1',
        answerKey: 'faqA1',
      ),
      _FaqItem(questionKey: 'faqQ2', answerKey: 'faqA2'),
      _FaqItem(questionKey: 'faqQ3', answerKey: 'faqA3'),
      _FaqItem(questionKey: 'faqQ4', answerKey: 'faqA4'),
      _FaqItem(questionKey: 'faqQ5', answerKey: 'faqA5'),
      _FaqItem(questionKey: 'faqQ6', answerKey: 'faqA6'),
      _FaqItem(questionKey: 'faqQ7', answerKey: 'faqA7'),
      _FaqItem(questionKey: 'faqQ8', answerKey: 'faqA8'),
      _FaqItem(questionKey: 'faqQ9', answerKey: 'faqA9'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('helpAndFaq'))),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.t('helpAndFaq'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.t('helpScreenSubtitle'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // Contact card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.support_agent_outlined,
                  color: AppTheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.t('ehiaHelpline'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      Text(
                        strings.t('ehiaContact'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 20),

          // FAQ list
          ...faqs.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FaqCard(faq: entry.value)
                  .animate()
                  .fadeIn(duration: 350.ms, delay: (150 + entry.key * 50).ms)
                  .slideY(
                    begin: 0.05,
                    end: 0,
                    duration: 350.ms,
                    delay: (150 + entry.key * 50).ms,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.questionKey, required this.answerKey});
  final String questionKey;
  final String answerKey;
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.faq});
  final _FaqItem faq;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.help_outline,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
          title: Text(
            strings.t(faq.questionKey),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textDark,
            ),
          ),
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Text(
              strings.t(faq.answerKey),
              style: const TextStyle(
                color: AppTheme.textDark,
                height: 1.6,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
