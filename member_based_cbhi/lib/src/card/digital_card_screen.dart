import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../cbhi_state.dart';
import '../theme/app_theme.dart';

/// Digital CBHI card screen — M3 HealthShield redesign.
/// Shows the membership card (blue gradient) + QR section below.
class DigitalCardScreen extends StatelessWidget {
  const DigitalCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        final strings = CbhiLocalizations.of(context);
        final snapshot = state.snapshot ?? CbhiSnapshot.empty();
        final cards = snapshot.digitalCards.isEmpty
            ? [
                {
                  'memberName': snapshot.viewerName,
                  'membershipId': snapshot.viewerMembershipId,
                  'coverageStatus': snapshot.coverageStatus,
                  'token': snapshot.cardToken,
                },
              ]
            : snapshot.digitalCards;

        return Scaffold(
          backgroundColor: AppTheme.surfaceBgFor(Theme.of(context).brightness),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Page header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t('idCard'),
                    style: TextStyle(
                      color: AppTheme.textPrimaryFor(Theme.of(context).brightness),
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.t('presentCardForServices'),
                    style: TextStyle(
                      color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...cards.toList().asMap().entries.map(
                (entry) {
                  final card = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _M3CardLayout(
                      card: card,
                      snapshot: snapshot,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── M3 Card Layout — card + QR section stacked ────────────────────────────────

class _M3CardLayout extends StatefulWidget {
  const _M3CardLayout({required this.card, required this.snapshot});
  final Map<String, dynamic> card;
  final CbhiSnapshot snapshot;

  @override
  State<_M3CardLayout> createState() => _M3CardLayoutState();
}

class _M3CardLayoutState extends State<_M3CardLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _showBack = !_showBack);
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final card = widget.card;
    final snapshot = widget.snapshot;
    final hasToken = (card['token']?.toString() ?? '').isNotEmpty;

    // Coverage status
    final coverageStatus = card['coverageStatus']?.toString() ?? snapshot.coverageStatus;
    final endDateRaw = snapshot.coverage?['endDate']?.toString() ?? card['validUntil']?.toString();
    final endDate = endDateRaw != null ? DateTime.tryParse(endDateRaw) : null;

    return Column(
      children: [
        // ── Blue gradient membership card ──
        GestureDetector(
          onTap: _flip,
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value;
              final isFront = angle <= math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: isFront
                    ? _CardFront(
                        card: card,
                        snapshot: snapshot,
                        coverageStatus: coverageStatus,
                        endDate: endDate,
                        onFlip: _flip,
                      )
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _CardBack(
                          card: card,
                          snapshot: snapshot,
                          hasToken: hasToken,
                        ),
                      ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // ── QR section (always visible below card) ──
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceBgFor(Theme.of(context).brightness),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                strings.t('scanToVerify'),
                style: TextStyle(
                  color: AppTheme.textPrimaryFor(Theme.of(context).brightness),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              // QR code
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBgFor(Theme.of(context).brightness),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.m3OutlineVariant.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: hasToken
                    ? QrImageView(
                        data: card['token']!.toString(),
                        size: 192,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.circle,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: Colors.black,
                        ),
                      )
                    : SizedBox(
                        width: 192,
                        height: 192,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              strings.t('noDigitalCardCached'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                hasToken
                    ? strings.t('showAtFacilityHint')
                    : strings.t('completeSyncForQr'),
                style: TextStyle(
                  color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _PillButton(
                      label: strings.t('syncData'),
                      icon: Icons.sync_outlined,
                      backgroundColor: AppTheme.m3SecondaryContainer,
                      foregroundColor: AppTheme.m3OnSecondaryContainer,
                      onTap: () => context.read<AppCubit>().sync(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (hasToken)
                    Expanded(
                      child: _PillButton(
                        label: strings.t('showAtFacility'),
                        icon: Icons.local_hospital_outlined,
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppTheme.textPrimaryFor(Theme.of(context).brightness),
                        borderColor: AppTheme.m3Outline,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _ShowAtFacilityScreen(
                              token: card['token']!.toString(),
                              memberName: card['memberName']?.toString() ?? snapshot.viewerName,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Card front face ───────────────────────────────────────────────────────────

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.card,
    required this.snapshot,
    required this.coverageStatus,
    required this.endDate,
    required this.onFlip,
  });
  final Map<String, dynamic> card;
  final CbhiSnapshot snapshot;
  final String coverageStatus;
  final DateTime? endDate;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.m3PrimaryContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.m3Primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -64,
            top: -64,
            child: Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.m3Primary.withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned(
            left: -32,
            bottom: -32,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.m3Primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maya City CBHI',
                          style: TextStyle(
                            color: AppTheme.m3OnPrimaryContainer.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          strings.t('communityHealthPlan'),
                          style: TextStyle(
                            color: AppTheme.m3OnPrimaryContainer,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.m3TertiaryContainer,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.m3OnTertiaryContainer),
                          const SizedBox(width: 4),
                          Text(
                            coverageStatus.toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.m3OnTertiaryContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Flip hint
                    GestureDetector(
                      onTap: onFlip,
                      child: Icon(
                        Icons.rotate_right,
                        color: AppTheme.m3OnPrimaryContainer.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Member name
                Text(
                  strings.t('memberName').toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.m3OnPrimaryContainer.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card['memberName']?.toString() ?? snapshot.viewerName,
                  style: TextStyle(
                    color: AppTheme.m3OnPrimaryContainer,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 20),
                // ID + Valid Until
                Row(
                  children: [
                    Expanded(
                      child: _CardField(
                        label: strings.t('idLabel'),
                        value: card['membershipId']?.toString() ?? snapshot.viewerMembershipId,
                      ),
                    ),
                    if (endDate != null)
                      Expanded(
                        child: _CardField(
                          label: strings.t('validUntil'),
                          value: _formatDate(endDate!),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Share button
                GestureDetector(
                  onTap: () async {
                    final info = [
                      'Maya City CBHI',
                      '${strings.t('fullName')}: ${card['memberName'] ?? snapshot.viewerName}',
                      '${strings.t('household')}: ${snapshot.householdCode}',
                      '${strings.t('idLabel')}: ${card['membershipId'] ?? snapshot.viewerMembershipId}',
                      '${strings.t('coverage')}: $coverageStatus',
                    ].join('\n');
                    await Clipboard.setData(ClipboardData(text: info));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(strings.t('cardDetailsCopied')),
                        action: SnackBarAction(label: strings.t('ok'), onPressed: () {}),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_outlined,
                        size: 14,
                        color: AppTheme.m3OnPrimaryContainer.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.t('shareCardInfo'),
                        style: TextStyle(
                          color: AppTheme.m3OnPrimaryContainer.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Card back face ────────────────────────────────────────────────────────────

class _CardBack extends StatelessWidget {
  const _CardBack({required this.card, required this.snapshot, required this.hasToken});
  final Map<String, dynamic> card;
  final CbhiSnapshot snapshot;
  final bool hasToken;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.m3PrimaryContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.m3Primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            card['memberName']?.toString() ?? snapshot.viewerName,
            style: TextStyle(
              color: AppTheme.m3OnPrimaryContainer,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardBgFor(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: hasToken
                ? QrImageView(
                    data: card['token']!.toString(),
                    size: 160,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Colors.black,
                    ),
                  )
                : SizedBox(
                    width: 160,
                    height: 160,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          strings.t('noDigitalCardCached'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            hasToken ? strings.t('encryptedQrToken') : strings.t('completeSyncForQr'),
            style: TextStyle(
              color: AppTheme.m3OnPrimaryContainer.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          if (hasToken) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _ShowAtFacilityScreen(
                    token: card['token']!.toString(),
                    memberName: card['memberName']?.toString() ?? snapshot.viewerName,
                  ),
                ),
              ),
              icon: const Icon(Icons.local_hospital_outlined, size: 16),
              label: Text(strings.t('showAtFacility')),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.m3Primary,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Full-screen "Show at Facility" screen ─────────────────────────────────────

class _ShowAtFacilityScreen extends StatefulWidget {
  const _ShowAtFacilityScreen({required this.token, required this.memberName});
  final String token;
  final String memberName;

  @override
  State<_ShowAtFacilityScreen> createState() => _ShowAtFacilityScreenState();
}

class _ShowAtFacilityScreenState extends State<_ShowAtFacilityScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Maya City CBHI',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.memberName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBgFor(Theme.of(context).brightness),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(data: widget.token, size: 320),
              ),
              const SizedBox(height: 24),
              Text(
                strings.t('tapToDismiss'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _CardField extends StatelessWidget {
  const _CardField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppTheme.m3OnPrimaryContainer.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            color: AppTheme.m3OnPrimaryContainer,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: borderColor != null
              ? Border.all(color: borderColor!)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
