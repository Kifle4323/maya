import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cbhi_localizations.dart';
import '../../theme/app_theme.dart';
import '../../shared/language_selector.dart';
import '../registration_cubit.dart';

class PersonalInfoConfirmation extends StatelessWidget {
  const PersonalInfoConfirmation({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final regCubit = context.read<RegistrationCubit>();
    final personalInfo = regCubit.state.personalInfo!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('reviewYourInformation')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => regCubit.goBackToPersonalInfo(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageSelector(isLight: true),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.t('reviewYourInformation'),
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.t('reviewBeforeContinuing'),
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondaryFor(Theme.of(context).brightness)),
                ),
                const SizedBox(height: 24),

                _buildInfoCard(context, strings.t('personalDetails'), [
                  _InfoRow(strings.t('fullName'), '${personalInfo.firstName} ${personalInfo.middleName ?? ''} ${personalInfo.lastName}'),
                  _InfoRow(strings.t('phoneNumber'), personalInfo.phone ?? ''),
                  _InfoRow(strings.t('age'), personalInfo.age.toString()),
                  if (personalInfo.email != null && personalInfo.email!.isNotEmpty)
                    _InfoRow(strings.t('emailAddress'), personalInfo.email!),
                  _InfoRow(strings.t('gender'), strings.t(personalInfo.gender.toLowerCase())),
                  _InfoRow(strings.t('dateOfBirth'), personalInfo.dateOfBirth.toString().split(' ')[0]),
                ]),

                const SizedBox(height: 20),

                _buildInfoCard(context, strings.t('addressAndHousehold'), [
                  _InfoRow(strings.t('region'), personalInfo.region),
                  _InfoRow(strings.t('zone'), personalInfo.zone),
                  if (personalInfo.woreda != null) _InfoRow(strings.t('woreda'), personalInfo.woreda!),
                  if (personalInfo.kebele != null) _InfoRow(strings.t('kebele'), personalInfo.kebele!),
                  _InfoRow(strings.t('householdSize'), personalInfo.householdSize.toString()),
                ]),

                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => regCubit.goBackToPersonalInfo(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(strings.t('editInformation')),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => regCubit.confirmPersonalInfo(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(strings.t('continueToIdentity')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, List<_InfoRow> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          row.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.value,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  _InfoRow(this.label, this.value);
}
