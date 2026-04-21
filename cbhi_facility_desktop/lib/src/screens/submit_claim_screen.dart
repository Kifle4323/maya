import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app.dart';
import '../data/facility_repository.dart';
import '../i18n/app_localizations.dart';
import 'qr_scanner_screen.dart';

class SubmitClaimScreen extends StatefulWidget {
  const SubmitClaimScreen({super.key, required this.repository});
  final FacilityRepository repository;

  @override
  State<SubmitClaimScreen> createState() => _SubmitClaimScreenState();
}

class _SubmitClaimScreenState extends State<SubmitClaimScreen> {
  final _membershipIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+2519');
  final _householdCodeCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();

  DateTime _serviceDate = DateTime.now();
  final List<_ServiceItem> _items = [_ServiceItem()];

  // Supporting document attachment
  String? _attachmentName;
  String? _attachmentMime;
  List<int>? _attachmentBytes; // bytes from FilePicker (withData: true)

  bool _submitting = false;
  String? _message;
  bool _isSuccess = false;

  double get _totalAmount =>
      _items.fold(0, (sum, item) => sum + item.quantity * item.unitPrice);

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<QrScanResult>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result == null) return;
    setState(() {
      if (result.membershipId != null) {
        _membershipIdCtrl.text = result.membershipId!;
      } else if (result.householdCode != null) {
        _householdCodeCtrl.text = result.householdCode!;
      }
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true, // always load bytes — works on web and native
    );
    if (result?.files.single == null) return;
    final file = result!.files.single;
    setState(() {
      _attachmentName = file.name;
      _attachmentMime = file.extension == 'pdf'
          ? 'application/pdf'
          : 'image/${file.extension ?? 'jpeg'}';
      // Store bytes for web
      _attachmentBytes = file.bytes;
    });
  }

  Future<void> _confirmAndSubmit() async {
    final strings = AppLocalizations.of(context);
    final items = _items
        .where((item) =>
            item.name.isNotEmpty && item.quantity > 0 && item.unitPrice > 0)
        .toList();
    if (items.isEmpty) {
      setState(() {
        _message = strings.t('addValidServiceItem');
        _isSuccess = false;
      });
      return;
    }

    // F12: Show preview dialog before submitting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('submitClaim')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_membershipIdCtrl.text.trim().isNotEmpty)
                Text('${strings.t('membershipId')}: ${_membershipIdCtrl.text.trim()}'),
              if (_fullNameCtrl.text.trim().isNotEmpty)
                Text('${strings.t('fullName')}: ${_fullNameCtrl.text.trim()}'),
              Text('${strings.t('serviceDate')}: ${DateFormat('dd MMM yyyy').format(_serviceDate)}'),
              const Divider(),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13))),
                        Text('${item.quantity} × ETB ${item.unitPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(strings.t('totalClaimed'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('ETB ${_totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: kPrimary)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _submit();
  }

  Future<void> _submit() async {
    final strings = AppLocalizations.of(context);
    final items = _items
        .where((item) =>
            item.name.isNotEmpty && item.quantity > 0 && item.unitPrice > 0)
        .toList();
    if (items.isEmpty) {
      setState(() {
        _message = strings.t('addValidServiceItem');
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      // Encode attachment as base64 if present
      Map<String, dynamic>? attachmentUpload;
      if (_attachmentName != null && _attachmentBytes != null) {
        attachmentUpload = {
          'fileName': _attachmentName,
          'contentBase64': base64Encode(_attachmentBytes!),
          'mimeType': _attachmentMime ?? 'application/octet-stream',
        };
      }

      final response = await widget.repository.submitClaim(
        membershipId: _membershipIdCtrl.text.trim().isEmpty
            ? null
            : _membershipIdCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim() == '+2519'
            ? null
            : _phoneCtrl.text.trim(),
        householdCode: _householdCodeCtrl.text.trim().isEmpty
            ? null
            : _householdCodeCtrl.text.trim(),
        fullName: _fullNameCtrl.text.trim().isEmpty
            ? null
            : _fullNameCtrl.text.trim(),
        serviceDate: DateFormat('yyyy-MM-dd').format(_serviceDate),
        items: items
            .map((item) => {
                  'serviceName': item.name,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  if (item.notes.isNotEmpty) 'notes': item.notes,
                })
            .toList(),
        supportingDocumentUpload: attachmentUpload,
      );
      setState(() {
        _isSuccess = true;
        _message = strings.t('claimSubmitted', {
          'claimNumber': response['claimNumber']?.toString() ?? '',
        });
        _items.clear();
        _items.add(_ServiceItem());
        _membershipIdCtrl.clear();
        _phoneCtrl.text = '+2519';
        _householdCodeCtrl.clear();
        _fullNameCtrl.clear();
        _attachmentName = null;
        _attachmentMime = null;
        _attachmentBytes = null;
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Beneficiary panel
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          strings.t('beneficiary'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: kTextDark,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _scanQr,
                          icon: const Icon(Icons.qr_code_scanner, size: 16, color: kPrimary),
                          label: Text(strings.t('scanQrCard'),
                              style: const TextStyle(color: kPrimary, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kPrimary),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _membershipIdCtrl,
                      decoration: InputDecoration(
                        labelText: strings.t('membershipId'),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: strings.t('phoneNumber'),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _householdCodeCtrl,
                      decoration: InputDecoration(
                        labelText: strings.t('householdCode'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fullNameCtrl,
                      decoration: InputDecoration(
                        labelText: strings.t('fullName'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Service date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _serviceDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _serviceDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined, color: kPrimary, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(strings.t('serviceDate'),
                                    style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                Text(DateFormat('dd MMM yyyy').format(_serviceDate),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, color: kTextDark)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Supporting document attachment
                    Text(strings.t('supportingDocument'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: kTextDark, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (_attachmentName != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kSuccess.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kSuccess.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, color: kSuccess, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_attachmentName!,
                                  style: const TextStyle(color: kSuccess, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: kError),
                              onPressed: () => setState(() {
                                _attachmentName = null;
                                _attachmentMime = null;
                                _attachmentBytes = null;
                              }),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _pickAttachment,
                        icon: const Icon(Icons.upload_file_outlined, size: 16),
                        label: Text(strings.t('attachDocument')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimary,
                          side: const BorderSide(color: kPrimary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Services panel
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              strings.t('serviceItems'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: kTextDark,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _items.add(_ServiceItem())),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(strings.t('addItem')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._items.asMap().entries.map(
                          (entry) => _ServiceItemRow(
                            item: entry.value,
                            index: entry.key,
                            canRemove: _items.length > 1,
                            onRemove: () =>
                                setState(() => _items.removeAt(entry.key)),
                            onChanged: () => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Real-time total
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        strings.t('totalClaimed'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'ETB ${_totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                if (_message != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_isSuccess ? kSuccess : kError).withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: _isSuccess ? kSuccess : kError,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: _isSuccess ? kSuccess : kError,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _confirmAndSubmit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(strings.t('submitClaim')),
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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

class _ServiceItem {
  String name = '';
  int quantity = 1;
  double unitPrice = 0;
  String notes = '';
}

class _ServiceItemRow extends StatelessWidget {
  const _ServiceItemRow({
    required this.item,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });
  final _ServiceItem item;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: item.name,
              decoration: InputDecoration(
                labelText: strings.t('service', {'index': '${index + 1}'}),
                prefixIcon: const Icon(
                  Icons.medical_services_outlined,
                  size: 18,
                ),
              ),
              onChanged: (v) {
                item.name = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: item.quantity.toString(),
              decoration: InputDecoration(
                labelText: strings.t('quantityShort'),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                item.quantity = int.tryParse(v) ?? 1;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextFormField(
              initialValue: item.unitPrice > 0 ? item.unitPrice.toString() : '',
              decoration: InputDecoration(labelText: strings.t('unitPrice')),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) {
                item.unitPrice = double.tryParse(v) ?? 0;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          if (canRemove)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: kError),
              onPressed: onRemove,
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}
