import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cbhi_localizations.dart';
import '../../theme/app_theme.dart';
import '../../shared/language_selector.dart';
import '../registration_cubit.dart';
import 'identity_cubit.dart';
import '../models/identity_model.dart';

/// Step 2 of 4 — Identity Verification
/// M3 HealthShield redesign: camera viewfinder cards, selfie circle, fraud policy box.
class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();

  String? selectedIdentityType;
  String? selectedEmploymentStatus;

  bool _idScanned = false;
  bool _selfieCapured = false;

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

  bool get _canContinue =>
      _idScanned &&
      _selfieCapured &&
      selectedIdentityType != null &&
      selectedEmploymentStatus != null &&
      _idError == null &&
      !_checkingId;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

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
      backgroundColor: AppTheme.m3SurfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppTheme.m3Surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppTheme.m3OnSurface,
          onPressed: () =>
              context.read<RegistrationCubit>().goBackToConfirmation(),
        ),
        title: Row(
          children: [
            const Icon(Icons.health_and_safety,
                color: AppTheme.m3Primary, size: 20),
            const SizedBox(width: 8),
            Text(
              strings.t('appTitle'),
              style: const TextStyle(
                color: AppTheme.m3OnSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                context.read<RegistrationCubit>().goBackToConfirmation(),
            child: Text(
              strings.t('cancel'),
              style: const TextStyle(color: AppTheme.m3OnSurfaceVariant),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
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

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 24),
                      child: Column(
                        children: [
                          // ── Progress & Title ──────────────────────────
                          Column(
                            children: [
                              Text(
                                strings.t('step2of4').toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.m3Primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.t('identityVerification'),
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.m3OnSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strings.t('identityVerificationSubtitle'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.m3OnSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ).animate().fadeIn(duration: 400.ms),

                          const SizedBox(height: 24),

                          // ── Scan Official ID Card ─────────────────────
                          _M3SectionCard(
                            icon: Icons.badge,
                            iconColor: AppTheme.m3Primary,
                            iconBg: AppTheme.m3PrimaryContainer
                                .withValues(alpha: 0.2),
                            title: strings.t('scanOfficialId'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.t('scanOfficialIdHint'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.m3OnSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // ID type dropdown
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: strings.t('identityType'),
                                    prefixIcon: const Icon(
                                        Icons.category_outlined,
                                        color: AppTheme.m3OnSurfaceVariant),
                                  ),
                                  value: selectedIdentityType,
                                  items: [
                                    DropdownMenuItem(
                                        value: 'NATIONAL_ID',
                                        child: Text(strings.t('nationalId'))),
                                    DropdownMenuItem(
                                        value: 'PASSPORT',
                                        child: Text(strings.t('passport'))),
                                    DropdownMenuItem(
                                        value: 'LOCAL_ID',
                                        child: Text(strings.t('localId'))),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => selectedIdentityType = value),
                                  validator: (v) =>
                                      v == null ? strings.t('required') : null,
                                ),

                                const SizedBox(height: 16),

                                // ID number field
                                TextFormField(
                                  controller: _idNumberController,
                                  decoration: InputDecoration(
                                    labelText: strings.t('identityNumber'),
                                    prefixIcon: const Icon(
                                        Icons.numbers_outlined,
                                        color: AppTheme.m3OnSurfaceVariant),
                                    errorText: _idError,
                                    suffixIcon: _checkingId
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: Padding(
                                              padding: EdgeInsets.all(12),
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            ),
                                          )
                                        : _idError != null
                                            ? const Icon(Icons.error_outline,
                                                color: AppTheme.error)
                                            : null,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return strings.t('required');
                                    if (_idError != null) return _idError;
                                    return null;
                                  },
                                  onChanged: (v) {
                                    identityCubit.updateIdentityNumber(v);
                                    _checkId(v);
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Camera viewfinder
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _idScanned = true),
                                  child: Container(
                                    width: double.infinity,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      color: AppTheme.m3SurfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Center content
                                        Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _idScanned
                                                    ? Icons.check_circle
                                                    : Icons.document_scanner,
                                                size: 40,
                                                color: _idScanned
                                                    ? AppTheme.m3Tertiary
                                                    : AppTheme.m3Outline,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _idScanned
                                                    ? strings.t('idScanned')
                                                    : strings.t('tapToActivateCamera'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: _idScanned
                                                      ? AppTheme.m3Tertiary
                                                      : AppTheme.m3Outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Corner guides
                                        Positioned(
                                          top: 12,
                                          left: 12,
                                          child: _CornerGuide(
                                              top: true, left: true),
                                        ),
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: _CornerGuide(
                                              top: true, left: false),
                                        ),
                                        Positioned(
                                          bottom: 12,
                                          left: 12,
                                          child: _CornerGuide(
                                              top: false, left: true),
                                        ),
                                        Positioned(
                                          bottom: 12,
                                          right: 12,
                                          child: _CornerGuide(
                                              top: false, left: false),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Start Scan button
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: () =>
                                        setState(() => _idScanned = true),
                                    icon: const Icon(Icons.photo_camera,
                                        size: 18),
                                    label: Text(strings.t('startScan')),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.m3Primary,
                                      foregroundColor: AppTheme.m3OnPrimary,
                                      shape: const StadiumBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                          const SizedBox(height: 16),

                          // ── Live Selfie Check Card ────────────────────
                          _M3SectionCard(
                            icon: Icons.face_retouching_natural,
                            iconColor: AppTheme.m3Tertiary,
                            iconBg: AppTheme.m3TertiaryContainer
                                .withValues(alpha: 0.2),
                            title: strings.t('liveSelfieCheck'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.t('liveSelfieHint'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.m3OnSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Circular selfie viewfinder
                                Center(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _selfieCapured = true),
                                    child: Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: AppTheme.m3SurfaceVariant,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _selfieCapured
                                              ? AppTheme.m3Tertiary
                                              : AppTheme.m3OutlineVariant,
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _selfieCapured
                                                ? Icons.check_circle
                                                : Icons.photo_camera_front,
                                            size: 40,
                                            color: _selfieCapured
                                                ? AppTheme.m3Tertiary
                                                : AppTheme.m3Outline,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _selfieCapured
                                                ? strings.t('selfieCapured')
                                                : strings.t('tapToOpen'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: _selfieCapured
                                                  ? AppTheme.m3Tertiary
                                                  : AppTheme.m3Outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Take Selfie button
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _selfieCapured = true),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.m3OnSurface,
                                      side: BorderSide(
                                          color: AppTheme.m3OutlineVariant),
                                      backgroundColor:
                                          AppTheme.m3SurfaceContainerHigh,
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Text(strings.t('takeSelfie')),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                          const SizedBox(height: 16),

                          // ── Employment section ────────────────────────
                          _M3SectionCard(
                            icon: Icons.work_outline,
                            iconColor: AppTheme.m3Primary,
                            iconBg: AppTheme.m3PrimaryFixed
                                .withValues(alpha: 0.4),
                            title: strings.t('employmentOccupationStatus'),
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: strings.t('mainOccupation'),
                                prefixIcon: const Icon(
                                    Icons.work_history_outlined,
                                    color: AppTheme.m3OnSurfaceVariant),
                              ),
                              value: selectedEmploymentStatus,
                              items: employmentOptions
                                  .map((option) => DropdownMenuItem(
                                        value: option['value'],
                                        child: Text(option['label']!),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(
                                    () => selectedEmploymentStatus = value);
                                identityCubit
                                    .updateEmploymentStatus(value ?? '');
                              },
                              validator: (v) =>
                                  v == null ? strings.t('required') : null,
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                          const SizedBox(height: 16),

                          // ── Fraud Prevention Policy ───────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.m3SecondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.security,
                                    color: AppTheme.m3OnSecondaryContainer,
                                    size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        strings.t('fraudPreventionPolicy'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              AppTheme.m3OnSecondaryContainer,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        strings.t('fraudPreventionBody'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.m3OnSecondaryContainer
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 350.ms),

                          const SizedBox(height: 24),

                          // ── Continue button ───────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: _canContinue
                                  ? () {
                                      if (_formKey.currentState!.validate()) {
                                        final identityModel = IdentityModel(
                                          identityType: selectedIdentityType!,
                                          identityNumber:
                                              _idNumberController.text.trim(),
                                          employmentStatus:
                                              selectedEmploymentStatus!,
                                        );
                                        regCubit.submitIdentity(identityModel);
                                      }
                                    }
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _canContinue
                                    ? AppTheme.m3Primary
                                    : AppTheme.m3SurfaceVariant,
                                foregroundColor: _canContinue
                                    ? AppTheme.m3OnPrimary
                                    : AppTheme.m3OnSurfaceVariant,
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                strings.t('continueToStep3'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

                          if (!_canContinue) ...[
                            const SizedBox(height: 8),
                            Text(
                              strings.t('completeBothVerifications'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.m3OnSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 40),
                        ],
                      ),
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

// ── M3 Section Card ───────────────────────────────────────────────────────────

class _M3SectionCard extends StatelessWidget {
  const _M3SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.m3SurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.m3SurfaceContainerHighest,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.m3OnSurface,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
            ],
          ),
          Divider(
            height: 24,
            color: AppTheme.m3SurfaceVariant,
          ),
          child,
        ],
      ),
    );
  }
}

// ── Corner Guide ──────────────────────────────────────────────────────────────

class _CornerGuide extends StatelessWidget {
  const _CornerGuide({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _CornerPainter(top: top, left: left),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.m3Primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? size.width : -size.width;
    final dy = top ? size.height : -size.height;

    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
