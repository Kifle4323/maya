import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../cbhi_state.dart';
import '../theme/app_theme.dart';
import '../shared/premium_widgets.dart';

/// Digital CBHI card screen — shows QR-coded membership cards for all
/// household members (or just the current beneficiary for family logins).
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
          backgroundColor: AppTheme.darkSurface0,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text(strings.t('digitalCbhiCards'), 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            children: [
              Text(
                strings.t('yourActiveMemberships'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              ...cards.toList().asMap().entries.map(
                (entry) {
                  final card = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _FlippableCard(
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

// ── F5: Coverage status badge color helper ────────────────────────────────────

Color _coverageStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
      return AppTheme.success;
    case 'EXPIRED':
      return AppTheme.error;
    case 'PENDING_RENEWAL':
    case 'PENDING':
      return AppTheme.warning;
    default:
      return AppTheme.textSecondary;
  }
}

// ── F3: Flippable card ────────────────────────────────────────────────────────

class _FlippableCard extends StatefulWidget {
  const _FlippableCard({required this.card, required this.snapshot});
  final Map<String, dynamic> card;
  final CbhiSnapshot snapshot;

  @override
  State<_FlippableCard> createState() => _FlippableCardState();
}

class _FlippableCardState extends State<_FlippableCard>
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
    return GestureDetector(
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
                    card: widget.card,
                    snapshot: widget.snapshot,
                    onFlip: _flip,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardBack(
                      card: widget.card,
                      snapshot: widget.snapshot,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// ── Card front face ───────────────────────────────────────────────────────────

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.card,
    required this.snapshot,
    required this.onFlip,
  });
  final Map<String, dynamic> card;
  final CbhiSnapshot snapshot;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final coverageStatus =
        card['coverageStatus']?.toString() ?? snapshot.coverageStatus;
    final statusColor = _coverageStatusColor(coverageStatus);

    // F4: Expiry date
    final endDateRaw = snapshot.coverage?['endDate']?.toString() ??
        card['validUntil']?.toString();
    final endDate = endDateRaw != null ? DateTime.tryParse(endDateRaw) : null;
    Color expiryColor = Colors.white;
    if (endDate != null) {
      final now = DateTime.now();
      if (endDate.isBefore(now)) {
        expiryColor = AppTheme.error;
      } else if (endDate.difference(now).inDays <= 30) {
        expiryColor = AppTheme.warning;
      }
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      color: colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.health_and_safety, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      strings.t('appTitle'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const Spacer(),
                    StatusPill(
                      label: coverageStatus,
                      color: statusColor,
                      compact: true,
                    ),
                    const SizedBox(width: 8),
                    // Flip hint
                    SpringTap(
                      onTap: onFlip,
                      child: Icon(
                        Icons.rotate_right,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
            Text(
              card['memberName']?.toString() ?? snapshot.viewerName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _CardInfoChip(
                  label: strings.t('household'),
                  value: snapshot.householdCode.isEmpty ? '—' : snapshot.householdCode,
                ),
                const SizedBox(width: 16),
                if ((card['membershipId']?.toString() ?? '').isNotEmpty)
                  _CardInfoChip(
                    label: strings.t('idLabel'),
                    value: card['membershipId'].toString(),
                  ),
              ],
            ),
            if (snapshot.coverageNumber.isNotEmpty) ...[
              const SizedBox(height: 6),
              _CardInfoChip(label: strings.t('coverage'), value: snapshot.coverageNumber),
            ],
            // F4: Expiry date
            if (endDate != null) ...[
              const SizedBox(height: 6),
              Text(
                '${strings.t('validUntil')}: ${_formatDate(endDate)}',
                style: TextStyle(
                  color: expiryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final info = [
                      strings.t('appTitle'),
                      '${strings.t('fullName')}: ${card['memberName'] ?? snapshot.viewerName}',
                      '${strings.t('household')}: ${snapshot.householdCode}',
                      '${strings.t('idLabel')}: ${card['membershipId'] ?? snapshot.viewerMembershipId}',
                      '${strings.t('coverage')}: $coverageStatus',
                      'Coverage #: ${snapshot.coverageNumber}',
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: Text(strings.t('shareCardInfo')),
                ),
              ],
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
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Card back face (QR + Show at Facility) ────────────────────────────────────

class _CardBack extends StatelessWidget {
  const _CardBack({required this.card, required this.snapshot});
  final Map<String, dynamic> card;
  final CbhiSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final hasToken = (card['token']?.toString() ?? '').isNotEmpty;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      color: colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  card['memberName']?.toString() ?? snapshot.viewerName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
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
                            size: 180,
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
                            width: 180,
                            height: 180,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  strings.t('noDigitalCardCached'),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  hasToken ? strings.t('encryptedQrToken') : strings.t('completeSyncForQr'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                if (hasToken) ...[
                  const SizedBox(height: 8),
                  Text(
                    strings.t('showAtFacilityHint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                // F2: Show at Facility button
                if (hasToken)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _ShowAtFacilityScreen(
                          token: card['token']!.toString(),
                          memberName: card['memberName']?.toString() ?? snapshot.viewerName,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.local_hospital_outlined),
                    label: Text(strings.t('showAtFacility')),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── F2: Full-screen "Show at Facility" screen ─────────────────────────────────

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
                strings.t('appTitle'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.memberName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(data: widget.token, size: 320),
              ),
              const SizedBox(height: 24),
              Text(
                strings.t('tapToDismiss'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white38,
                    ),
              ),            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _CardInfoChip extends StatelessWidget {
  const _CardInfoChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
