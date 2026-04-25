import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cbhi_localizations.dart';
import '../../theme/app_theme.dart';
import '../../shared/language_selector.dart';
import '../registration_cubit.dart';
import 'identity_cubit.dart';
import '../models/identity_model.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();

  String? selectedIdentityType;
  String? selectedEmploymentStatus;

  // Real-time ID duplicate detection
  String? _idError;
  bool _checkingId = false;
  DateTime? _lastIdCheck;

  Future<void> _checkId(String value) async {
    final id = value.trim();
    if (id.length < 4) {
      if (_idError != null) setState(() => _idError = null);
      return;
    }
    final now = DateTime.now();
    _lastIdCheck = now;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_lastIdCheck != now || !mounted) return;

    setState(() => _checkingId = true);
    final regCubit = context.read<RegistrationCubit>();
    final error = await regCubit.repository.checkIdAvailability(id);
    if (!mounted) return;
    setState(() {
      _idError = error;
      _checkingId = false;
    });
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    /// Values match backend [IndigentEmploymentStatus] (snake_case).
    final List<Map<String, String>> employmentOptions = [
      {'value': 'farmer', 'label': strings.t('farmer')},
      {'value': 'merchant', 'label': strings.t('merchant')},
      {'value': 'daily_laborer', 'label': strings.t('dailyLaborer')},
      {'value': 'employed', 'label': strings.t('employed')},
      {'value': 'homemaker', 'label': strings.t('homemaker')},
      {'value': 'student', 'label': strings.t('student')},
      {'value': 'unemployed', 'label': strings.t('unemployed')},
      {'value': 'pensioner', 'label': strings.t('pensioner')},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('identityAndEmployment')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<RegistrationCubit>().goBackToConfirmation(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageSelector(isLight: true),
          ),
        ],
      ),
      body: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => IdentityCubit()),
        ],
        child: BlocBuilder<IdentityCubit, IdentityState>(
          builder: (context, identityState) {
            final identityCubit = context.read<IdentityCubit>();
            final regCubit = context.read<RegistrationCubit>();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.spacingM),
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppTheme.cardGradient,
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.t('identityVerification'),
                                style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strings.t('collectIdForScreening'),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Identity Section
                                Row(
                                  children: [
                                    const Icon(Icons.badge_outlined, color: AppTheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      strings.t('identityDetails'),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),

                                // Identity Type Picker
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: strings.t('identityType'),
                                    prefixIcon: const Icon(Icons.category_outlined),
                                  ),
                                  initialValue: selectedIdentityType,
                                  items: [
                                    DropdownMenuItem(value: 'NATIONAL_ID', child: Text(strings.t('nationalId'))),
                                    DropdownMenuItem(value: 'PASSPORT', child: Text(strings.t('passport'))),
                                    DropdownMenuItem(value: 'LOCAL_ID', child: Text(strings.t('localId'))),
                                  ],
                                  onChanged: (value) {
                                    setState(() => selectedIdentityType = value);
                                  },
                                  validator: (v) => v == null ? strings.t('required') : null,
                                ),

                                const SizedBox(height: 20),

                                // Identity Number
                                TextFormField(
                                  controller: _idNumberController,
                                  decoration: InputDecoration(
                                    labelText: strings.t('identityNumber'),
                                    prefixIcon: const Icon(Icons.numbers_outlined),
                                    errorText: _idError,
                                    suffixIcon: _checkingId
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: Padding(
                                              padding: EdgeInsets.all(12),
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        : _idError != null
                                            ? const Icon(Icons.error_outline, color: Colors.red)
                                            : null,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return strings.t('required');
                                    if (_idError != null) return _idError;
                                    return null;
                                  },
                                  onChanged: (v) {
                                    identityCubit.updateIdentityNumber(v);
                                    _checkId(v);
                                  },
                                ),

                                const SizedBox(height: 40),

                                // Employment Section
                                Row(
                                  children: [
                                    const Icon(Icons.work_outline, color: AppTheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      strings.t('employmentOccupationStatus'),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),

                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: strings.t('mainOccupation'),
                                    prefixIcon: const Icon(Icons.work_history_outlined),
                                  ),
                                  initialValue: selectedEmploymentStatus,
                                  items: employmentOptions
                                      .map((option) => DropdownMenuItem(
                                            value: option['value'],
                                            child: Text(option['label']!),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => selectedEmploymentStatus = value);
                                    identityCubit.updateEmploymentStatus(value ?? '');
                                  },
                                  validator: (v) => v == null ? strings.t('required') : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate() &&
                                  selectedIdentityType != null &&
                                  selectedEmploymentStatus != null &&
                                  _idError == null &&
                                  !_checkingId) {
                                
                                final identityModel = IdentityModel(
                                  identityType: selectedIdentityType!,
                                  identityNumber: _idNumberController.text.trim(),
                                  employmentStatus: selectedEmploymentStatus!,
                                );

                                regCubit.submitIdentity(identityModel);
                              }
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(strings.t('continueToMembership')),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
