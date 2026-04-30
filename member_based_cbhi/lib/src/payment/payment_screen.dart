import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
    this.accessToken,
  });

  final CbhiRepository repository;
  final CbhiSnapshot snapshot;
  final VoidCallback onPaymentComplete;
  /// Optional access token from registration — used when secure storage hasn't persisted yet
  final String? accessToken;

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
  int _currentStep = 0;
  bool _isOnline = true;

  // Auto-polling
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPollCount = 60; // 5 min at 5s interval
  static const Duration _pollInterval = Duration(seconds: 5);

  // Deep link listener
  late final AppLinks _appLinks;
  StreamSubscription? _linkSub;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _appLinks = AppLinks();
    _linkSub = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host == 'payment-callback' ||
        uri.queryParameters.containsKey('tx_ref')) {
      final txRef = uri.queryParameters['tx_ref'];
      if (txRef != null && txRef == _txRef && mounted) {
        _pollTimer?.cancel();
        _verifyPayment();
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOnline = !result.contains(ConnectivityResult.none));
    }
  }
  double get _premiumAmount {
    final fromSnapshot = widget.snapshot.premiumAmount;
    if (fromSnapshot > 0) return fromSnapshot;
    // Fallback: base 1200 ETB + 120 per additional beneficiary (same as dashboard)
    final memberCount =
        double.tryParse(widget.snapshot.household['memberCount']?.toString() ?? '1')?.toInt() ?? 1;
    return 1200.0 + (memberCount - 1).clamp(0, 999) * 120.0;
  }

  // ── Auto-polling ──────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      _pollCount++;
      if (_pollCount > _maxPollCount || !mounted) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() => _waitingForCallback = false);
        }
        return;
      }
      await _verifyPaymentSilent();
    });
  }

  /// Silent verify — doesn't show loading indicator or errors, just checks
  Future<void> _verifyPaymentSilent() async {
    if (_txRef == null || !mounted) return;
    try {
      final result = await widget.repository.verifyPayment(_txRef!);
      if (result['status'] == 'success' && mounted) {
        _pollTimer?.cancel();
        setState(() {
          _verifyResult = result;
          _verifying = false;
          _waitingForCallback = false;
          _currentStep = 2;
        });
        _showReceiptDialog(result);
      }
    } catch (_) {
      // Silent — don't show errors during polling
    }
  }

  // ── Payment actions ───────────────────────────────────────────────────────

  Future<void> _initiatePayment() async {
    final strings = CbhiLocalizations.of(context);
    await _checkConnectivity();
    if (!_isOnline) {
      setState(() => _error = strings.t('noInternetConnection'));
      return;
    }
    if (_premiumAmount <= 0) {
      setState(() => _error = strings.t('noPremiumAmount'));
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.repository.initiatePayment(
        amount: _premiumAmount,
        description: 'CBHI premium for household ${widget.snapshot.householdCode}',
        accessToken: widget.accessToken,
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

  Future<void> _openCheckoutAndPoll() async {
    if (_checkoutUrl == null) return;
    final uri = Uri.tryParse(_checkoutUrl!);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() => _waitingForCallback = true);
      _startPolling();
    }
  }

  Future<void> _verifyPayment() async {
    if (_txRef == null) return;
    setState(() => _verifying = true);

    try {
      final result = await widget.repository.verifyPayment(_txRef!);
      if (result['status'] == 'success' && mounted) {
        _pollTimer?.cancel();
        setState(() {
          _verifyResult = result;
          _verifying = false;
          _waitingForCallback = false;
          _currentStep = 2;
        });
        _showReceiptDialog(result);
      } else {
        setState(() {
          _verifyResult = result;
          _verifying = false;
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

  void _showReceiptDialog(Map<String, dynamic> result) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceiptDialog(
        result: result,
        txRef: _txRef ?? '',
        onDone: widget.onPaymentComplete,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
            _PaymentStepIndicator(currentStep: _currentStep),
            SizedBox(height: 16),

            // Connectivity warning
            if (!_isOnline) ...[
              _OfflineBanner(onRetry: _checkConnectivity),
              SizedBox(height: 12),
            ],

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
                  SizedBox(height: 8),
                  Text(
                    '${_premiumAmount.toStringAsFixed(2)} ETB',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${strings.t('householdLabel')}: ${widget.snapshot.householdCode}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            SizedBox(height: 24),

            // Payment methods info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7DC242).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: const Color(0xFF7DC242).withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7DC242).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.payment, color: Color(0xFF7DC242), size: 20),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.t('acceptedPaymentMethods'),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF7DC242),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Powered by Chapa',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _PaymentChip(label: 'Telebirr', icon: Icons.phone_android),
                      _PaymentChip(label: 'CBE Birr', icon: Icons.account_balance),
                      _PaymentChip(label: 'Amole', icon: Icons.wallet),
                      _PaymentChip(label: 'M-Pesa', icon: Icons.money),
                      _PaymentChip(label: 'Bank Transfer', icon: Icons.swap_horiz),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

            SizedBox(height: 24),

            // Error display
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                  ],
                ),
              ),

            // Step 1: Initiate button
            if (!_paymentInitiated) ...[
              SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (_isLoading || !_isOnline) ? null : _initiatePayment,
                icon: _isLoading
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cardBgFor(Theme.of(context).brightness)),
                      )
                    : Icon(Icons.open_in_new),
                label: Text(strings.f('payViaChapa', {'amount': _premiumAmount.toStringAsFixed(2)})),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7DC242)),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
            ],

            // Step 2: Checkout initiated
            if (_paymentInitiated && _checkoutUrl != null) ...[
              _CheckoutSection(
                strings: strings,
                txRef: _txRef ?? '',
                waitingForCallback: _waitingForCallback,
                pollCount: _pollCount,
                maxPollCount: _maxPollCount,
                onOpenCheckout: _openCheckoutAndPoll,
              ),

              SizedBox(height: 16),

              // Manual verify button
              FilledButton.icon(
                onPressed: _verifying ? null : _verifyPayment,
                icon: _verifying
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cardBgFor(Theme.of(context).brightness)),
                      )
                    : Icon(Icons.verified_outlined),
                label: Text(strings.t('verifyPayment')),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
              ),
            ],

            // Verify result (non-success)
            if (_verifyResult != null && _verifyResult!['status'] != 'success') ...[
              SizedBox(height: 16),
              _VerifyResultCard(result: _verifyResult!, strings: strings),
            ],

            SizedBox(height: 32),
            const Divider(),
            SizedBox(height: 16),
            
            // Manual proof section
            Text(
              strings.t('offlinePaymentTitle'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              strings.t('offlinePaymentSubtitle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 16),
            
            OutlinedButton.icon(
              onPressed: () => _showManualProofDialog(context),
              icon: Icon(Icons.upload_file_outlined),
              label: Text(strings.t('submitBankReceipt')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showManualProofDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _ManualProofDialog(
        repository: widget.repository,
        onDone: widget.onPaymentComplete,
      ),
    );
  }
}

class _ManualProofDialog extends StatefulWidget {
  const _ManualProofDialog({required this.repository, required this.onDone});
  final CbhiRepository repository;
  final VoidCallback onDone;

  @override
  State<_ManualProofDialog> createState() => _ManualProofDialogState();
}

class _ManualProofDialogState extends State<_ManualProofDialog> {
  final _receiptController = TextEditingController();
  final _bankController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _receiptController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return AlertDialog(
      title: Text(strings.t('submitBankReceipt')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _bankController,
            decoration: InputDecoration(
              labelText: strings.t('bankName'),
              hintText: 'e.g. CBE, Dashen, Awash',
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _receiptController,
            decoration: InputDecoration(
              labelText: strings.t('receiptNumber'),
              hintText: strings.t('receiptNumberHint'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.t('cancel')),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cardBgFor(Theme.of(context).brightness)))
              : Text(strings.t('submit')),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_receiptController.text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.repository.renewCoverage(
        paymentMethod: 'bank_transfer',
        providerName: _bankController.text,
        receiptNumber: _receiptController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
        setState(() => _submitting = false);
      }
    }
  }
}

// ── Offline Banner ──────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: AppTheme.warning, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.t('noInternetConnection'),
              style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(strings.t('retryConnection')),
          ),
        ],
      ),
    );
  }
}

// ── Checkout section (after initiate) ───────────────────────────────────────

class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({
    required this.strings,
    required this.txRef,
    required this.waitingForCallback,
    required this.pollCount,
    required this.maxPollCount,
    required this.onOpenCheckout,
  });

  final dynamic strings;
  final String txRef;
  final bool waitingForCallback;
  final int pollCount;
  final int maxPollCount;
  final VoidCallback onOpenCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.success),
              SizedBox(width: 8),
              Text(
                strings.t('paymentInitiated'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.success),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '${strings.t('transactionLabel')}: $txRef',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: 12),
          Text(strings.t('completePaymentOnChapa')),
          SizedBox(height: 16),

          // Open Chapa checkout
          FilledButton.icon(
            onPressed: onOpenCheckout,
            icon: Icon(Icons.open_in_new),
            label: Text(strings.t('openChapaCheckout')),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7DC242)),
          ).animate().fadeIn(duration: 300.ms),

          // Auto-polling indicator
          if (waitingForCallback) ...[
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.t('waitingForPayment'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          strings.t('autoCheckingPayment'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress ring
                  SizedBox(
                    width: 32, height: 32,
                    child: CircularProgressIndicator(
                      value: pollCount / maxPollCount,
                      strokeWidth: 3,
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Verify result card (pending/failed) ─────────────────────────────────────

String _parseAmt(dynamic v) {
  if (v == null) return '';
  if (v is num) return v.toStringAsFixed(2);
  final parsed = double.tryParse(v.toString());
  return parsed != null ? parsed.toStringAsFixed(2) : v.toString();
}

class _VerifyResultCard extends StatelessWidget {
  const _VerifyResultCard({required this.result, required this.strings});
  final Map<String, dynamic> result;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    final isPending = result['status'] == 'pending';
    final color = isPending ? AppTheme.warning : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isPending ? Icons.schedule : Icons.cancel_outlined, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                '${strings.t('statusLabel')}: ${result['status']?.toString().toUpperCase()}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          if (result['amount'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${strings.t('amountLabel')}: ${_parseAmt(result['amount'])} ${strings.t('etb')}'),
            ),
          if (result['message'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(result['message'].toString(), style: Theme.of(context).textTheme.bodySmall),
            ),
          if (isPending) ...[
            SizedBox(height: 8),
            Text(
              strings.t('paymentStillProcessing'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryFor(Theme.of(context).brightness)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Payment chip ────────────────────────────────────────────────────────────

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7DC242).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: const Color(0xFF7DC242).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7DC242)),
          SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7DC242), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Step indicator ──────────────────────────────────────────────────────────

class _PaymentStepIndicator extends StatelessWidget {
  const _PaymentStepIndicator({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final steps = [
      strings.t('paymentStepAmount'),
      strings.t('paymentStepPay'),
      strings.t('paymentStepDone'),
    ];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: i ~/ 2 < currentStep ? AppTheme.primary : Colors.grey.shade200,
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
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone || isActive ? AppTheme.primary : Colors.grey.shade200,
              ),
              child: Center(
                child: isDone
                    ? Icon(Icons.check, size: 14, color: AppTheme.cardBgFor(Theme.of(context).brightness))
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : AppTheme.textSecondaryFor(Theme.of(context).brightness),
                        ),
                      ),
              ),
            ),
            SizedBox(height: 4),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppTheme.primary : AppTheme.textSecondaryFor(Theme.of(context).brightness),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Receipt dialog ──────────────────────────────────────────────────────────

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
    final strings = CbhiLocalizations.of(context);
    final endDate = result['coverageEndDate']?.toString() ?? result['endDate']?.toString();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, color: AppTheme.success, size: 48),
          ),
          SizedBox(height: 12),
          Text(
            strings.t('paymentSuccessTitle'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
          SizedBox(height: 4),
          Text(
            strings.t('paymentSuccessBody'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: 16),
          const Divider(),
          SizedBox(height: 8),
          _ReceiptRow(label: strings.t('receiptAmount'), value: '${_safeParseAmount(result['amount'])} ETB'),
          _ReceiptRow(label: strings.t('receiptReference'), value: txRef),
          if (result['paymentMethod'] != null)
            _ReceiptRow(label: strings.t('receiptMethod'), value: result['paymentMethod'].toString()),
          if (result['paidAt'] != null)
            _ReceiptRow(label: strings.t('receiptPaidAt'), value: _formatDate(result['paidAt'].toString())),
          if (endDate != null)
            _ReceiptRow(label: strings.t('receiptCoverageUntil'), value: _formatDate(endDate)),
          SizedBox(height: 8),
          const Divider(),
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.success),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.t('receiptConfirmationNote'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
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
          child: Text(strings.t('done')),
        ),
      ],
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _safeParseAmount(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toStringAsFixed(2);
    final parsed = double.tryParse(v.toString());
    return parsed != null ? parsed.toStringAsFixed(2) : v.toString();
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
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
