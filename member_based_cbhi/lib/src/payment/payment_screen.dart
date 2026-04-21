import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';

/// Payment screen for CBHI premium renewal via Chapa
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.repository,
    required this.snapshot,
    required this.onPaymentComplete,
  });

  final CbhiRepository repository;
  final CbhiSnapshot snapshot;
  final VoidCallback onPaymentComplete;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  String? _error;
  String? _checkoutUrl;
  String? _txRef;
  bool _paymentInitiated = false;
  bool _verifying = false;
  bool _waitingForCallback = false;
  Map<String, dynamic>? _verifyResult;
  // F7: Step indicator
  int _currentStep = 0;

  // FIX ME-5: Deep link listener for automatic payment verification
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) {
      // Chapa redirects to cbhi://payment-callback?tx_ref=CBHI-xxx
      if (uri.path.contains('payment-callback') || uri.queryParameters.containsKey('tx_ref')) {
        final txRef = uri.queryParameters['tx_ref'];
        if (txRef != null && txRef == _txRef && mounted) {
          _verifyPayment();
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  double get _premiumAmount => widget.snapshot.premiumAmount;

  Future<void> _initiatePayment() async {
    if (_premiumAmount <= 0) {
      setState(() => _error = 'No premium amount set for this household.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.repository.initiatePayment(
        amount: _premiumAmount,
        description:
            'CBHI premium for household ${widget.snapshot.householdCode}',
      );

      setState(() {
        _txRef = result['txRef']?.toString();
        _checkoutUrl = result['checkoutUrl']?.toString();
        _paymentInitiated = true;
        _isLoading = false;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyPayment() async {
    if (_txRef == null) return;
    setState(() => _verifying = true);

    try {
      final result = await widget.repository.verifyPayment(_txRef!);
      setState(() {
        _verifyResult = result;
        _verifying = false;
      });

    if (result['status'] == 'success' && mounted) {
        setState(() {
          _verifyResult = result;
          _verifying = false;
          _waitingForCallback = false;
          _currentStep = 2;
        });
        // F8: Show receipt screen instead of snackbar
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ReceiptDialog(
            result: result,
            txRef: _txRef ?? '',
            onDone: widget.onPaymentComplete,
          ),
        );
      } else {
        setState(() {
          _verifyResult = result;
          _verifying = false;
          _waitingForCallback = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _verifying = false;
        _waitingForCallback = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('payPremium'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // F7: Step indicator
            _PaymentStepIndicator(currentStep: _currentStep),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Amount card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t('premiumAmount'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_premiumAmount.toStringAsFixed(2)} ETB',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${strings.t('householdLabel')}: ${widget.snapshot.householdCode}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // Payment methods info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payment, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        strings.t('acceptedPaymentMethods'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PaymentChip(
                        label: 'Telebirr',
                        icon: Icons.phone_android,
                      ),
                      _PaymentChip(
                        label: 'CBE Birr',
                        icon: Icons.account_balance,
                      ),
                      _PaymentChip(label: 'Amole', icon: Icons.wallet),
                      _PaymentChip(label: 'HelloCash', icon: Icons.money),
                      _PaymentChip(
                        label: 'Bank Transfer',
                        icon: Icons.swap_horiz,
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

            const SizedBox(height: 24),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),

            if (!_paymentInitiated) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _isLoading ? null : _initiatePayment,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  strings.f('payViaChapa', {
                    'amount': _premiumAmount.toStringAsFixed(2),
                  }),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
            ],

            if (_paymentInitiated && _checkoutUrl != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.t('paymentInitiated'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppTheme.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${strings.t('transactionLabel')}: $_txRef',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(strings.t('completePaymentOnChapa')),
                    const SizedBox(height: 16),
                    // Open Chapa in external browser
                    FilledButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(_checkoutUrl!);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          setState(() => _waitingForCallback = true);
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(strings.t('openChapaCheckout')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                    ).animate().fadeIn(duration: 300.ms),

                    // F6: Waiting for callback indicator
                    if (_waitingForCallback) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Listening for payment callback...',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _verifying ? null : _verifyPayment,
                icon: _verifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(strings.t('verifyPayment')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.success,
                ),
              ),
            ],

            if (_verifyResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      (_verifyResult!['status'] == 'success'
                              ? AppTheme.success
                              : AppTheme.warning)
                          .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${strings.t('statusLabel')}: ${_verifyResult!['status']?.toString().toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _verifyResult!['status'] == 'success'
                            ? AppTheme.success
                            : AppTheme.warning,
                      ),
                    ),
                    if (_verifyResult!['amount'] != null)
                      Text(
                        '${strings.t('amountLabel')}: ${_verifyResult!['amount']} ${strings.t('etb')}',
                      ),
                    if (_verifyResult!['paymentMethod'] != null)
                      Text(
                        '${strings.t('methodLabel')}: ${_verifyResult!['paymentMethod']}',
                      ),
                    Text(_verifyResult!['message']?.toString() ?? ''),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── F7: Payment step indicator ────────────────────────────────────────────────

class _PaymentStepIndicator extends StatelessWidget {
  const _PaymentStepIndicator({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const steps = ['Amount', 'Pay', 'Done'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: i ~/ 2 < currentStep
                  ? AppTheme.primary
                  : Colors.grey.shade200,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final isActive = stepIndex == currentStep;
        final isDone = stepIndex < currentStep;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone || isActive ? AppTheme.primary : Colors.grey.shade200,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── F8: Receipt dialog ────────────────────────────────────────────────────────

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({
    required this.result,
    required this.txRef,
    required this.onDone,
  });
  final Map<String, dynamic> result;
  final String txRef;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final endDate = result['endDate']?.toString() ?? result['coverageEndDate']?.toString();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
          const SizedBox(height: 12),
          Text(
            'Payment Successful',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
          ),
          const SizedBox(height: 16),
          _ReceiptRow(label: 'Amount', value: '${result['amount'] ?? ''} ETB'),
          _ReceiptRow(label: 'Reference', value: txRef),
          if (result['paymentMethod'] != null)
            _ReceiptRow(label: 'Method', value: result['paymentMethod'].toString()),
          if (endDate != null)
            _ReceiptRow(
              label: 'Coverage active until',
              value: endDate.split('T').first,
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDone();
          },
          style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
