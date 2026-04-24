import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app.dart';
import '../data/facility_repository.dart';
import '../i18n/app_localizations.dart';
import 'qr_scanner_screen.dart';

// ── Benefit catalog categories with icons ─────────────────────────────────
const _kCatalog = [
  _CatalogCategory(
    id: 'OPD',
    label: 'Outpatient Services (OPD)',
    icon: Icons.local_hospital_outlined,
    color: Color(0xFF1A73E8),
    services: [
      _CatalogService('Medical Consultation', 'OPD-001', 150),
      _CatalogService('Specialist Consultation', 'OPD-002', 300),
      _CatalogService('Essential Medicines', 'OPD-003', 200),
      _CatalogService('Minor Procedure', 'OPD-004', 500),
    ],
  ),
  _CatalogCategory(
    id: 'IPD',
    label: 'Inpatient Services (IPD)',
    icon: Icons.bed_outlined,
    color: Color(0xFF7B1FA2),
    services: [
      _CatalogService('Hospitalization (per day)', 'IPD-001', 800),
      _CatalogService('Major Surgery', 'IPD-002', 5000),
      _CatalogService('Minor Surgery', 'IPD-003', 1500),
      _CatalogService('Intensive Care (ICU, per day)', 'IPD-004', 2000),
    ],
  ),
  _CatalogCategory(
    id: 'MNCH',
    label: 'Maternal, Neonatal & Child Health',
    icon: Icons.child_care_outlined,
    color: Color(0xFFE91E63),
    services: [
      _CatalogService('Antenatal Care (ANC)', 'MNCH-001', 200),
      _CatalogService('Normal Delivery', 'MNCH-002', 1000),
      _CatalogService('Caesarean Section (C-Section)', 'MNCH-003', 4000),
      _CatalogService('Postnatal Care (PNC)', 'MNCH-004', 200),
      _CatalogService('IMNCI / Child Illness Treatment', 'MNCH-005', 300),
      _CatalogService('Immunization', 'MNCH-006', 100),
    ],
  ),
  _CatalogCategory(
    id: 'LAB',
    label: 'Diagnostic & Laboratory',
    icon: Icons.biotech_outlined,
    color: Color(0xFF00897B),
    services: [
      _CatalogService('Blood Chemistry (Hgb, Glucose)', 'LAB-001', 120),
      _CatalogService('Microbiology (Stool, Urine)', 'LAB-002', 100),
      _CatalogService('HIV Screening', 'LAB-003', 80),
      _CatalogService('Malaria Test (RDT/Smear)', 'LAB-004', 60),
      _CatalogService('TB Sputum Test', 'LAB-005', 80),
      _CatalogService('X-Ray', 'LAB-006', 300),
      _CatalogService('Ultrasound', 'LAB-007', 500),
      _CatalogService('CT Scan', 'LAB-008', 2500),
      _CatalogService('MRI', 'LAB-009', 4000),
    ],
  ),
];

class _CatalogCategory {
  const _CatalogCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.services,
  });
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<_CatalogService> services;
}

class _CatalogService {
  const _CatalogService(this.name, this.code, this.defaultPrice);
  final String name;
  final String code;
  final double defaultPrice;
}

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

  // Catalog loaded from backend (falls back to _kCatalog if unavailable)
  List<Map<String, dynamic>> _catalogItems = [];
  bool _catalogLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final items = await widget.repository.getBenefitPackageItems();
      if (mounted) setState(() { _catalogItems = items; _catalogLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _catalogLoaded = true);
    }
  }

  /// Opens the service catalog picker dialog and adds selected services to items list.
  Future<void> _openCatalogPicker() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ServiceCatalogDialog(
        catalogItems: _catalogItems,
        onSelected: (name, code, price) {
          setState(() {
            // If last item is empty, fill it; otherwise add new
            final last = _items.last;
            if (last.name.isEmpty) {
              last.name = name;
              last.serviceCode = code;
              last.unitPrice = price;
            } else {
              _items.add(_ServiceItem()
                ..name = name
                ..serviceCode = code
                ..unitPrice = price);
            }
          });
        },
      ),
    );
  }

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
                  if (item.serviceCode.isNotEmpty) 'serviceCode': item.serviceCode,
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
                            // Catalog picker button
                            FilledButton.icon(
                              onPressed: _openCatalogPicker,
                              icon: const Icon(Icons.library_books_outlined, size: 16),
                              label: const Text('Browse Catalog'),
                              style: FilledButton.styleFrom(
                                backgroundColor: kPrimary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
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
  String serviceCode = '';
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
                suffixText: item.serviceCode.isNotEmpty ? item.serviceCode : null,
                suffixStyle: const TextStyle(
                  fontSize: 11,
                  color: kPrimary,
                  fontWeight: FontWeight.w600,
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

// ── Service Catalog Dialog ────────────────────────────────────────────────

class _ServiceCatalogDialog extends StatefulWidget {
  const _ServiceCatalogDialog({
    required this.catalogItems,
    required this.onSelected,
  });

  /// Items from backend (may be empty — falls back to built-in catalog)
  final List<Map<String, dynamic>> catalogItems;
  final void Function(String name, String code, double price) onSelected;

  @override
  State<_ServiceCatalogDialog> createState() => _ServiceCatalogDialogState();
}

class _ServiceCatalogDialogState extends State<_ServiceCatalogDialog> {
  String _search = '';
  String? _selectedCategory;

  List<_CatalogCategory> get _categories => _kCatalog;

  List<_CatalogService> get _filteredServices {
    final q = _search.toLowerCase();
    final services = <_CatalogService>[];
    for (final cat in _categories) {
      if (_selectedCategory != null && cat.id != _selectedCategory) continue;
      for (final svc in cat.services) {
        if (q.isEmpty ||
            svc.name.toLowerCase().contains(q) ||
            svc.code.toLowerCase().contains(q)) {
          services.add(svc);
        }
      }
    }
    return services;
  }

  Color _colorForCategory(String id) {
    return _kCatalog
        .firstWhere((c) => c.id == id,
            orElse: () => _kCatalog.first)
        .color;
  }

  String _labelForCategory(String id) {
    return _kCatalog
        .firstWhere((c) => c.id == id,
            orElse: () => _kCatalog.first)
        .label;
  }

  String _categoryForService(String code) {
    for (final cat in _kCatalog) {
      if (cat.services.any((s) => s.code == code)) return cat.id;
    }
    return 'OPD';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 720,
        height: 580,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.library_books_outlined,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CBHI Benefit Package Catalog',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Select a covered service to add to the claim',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search + category filter
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setState(() => _search = v),
                      decoration: const InputDecoration(
                        hintText: 'Search services...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: _selectedCategory,
                    hint: const Text('All categories',
                        style: TextStyle(fontSize: 13)),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All categories',
                            style: TextStyle(fontSize: 13)),
                      ),
                      ..._kCatalog.map((cat) => DropdownMenuItem<String?>(
                            value: cat.id,
                            child: Row(
                              children: [
                                Icon(cat.icon, size: 16, color: cat.color),
                                const SizedBox(width: 6),
                                Text(cat.id,
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedCategory = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // Service list
            Expanded(
              child: _filteredServices.isEmpty
                  ? const Center(
                      child: Text('No services found',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _filteredServices.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 56),
                      itemBuilder: (ctx, i) {
                        final svc = _filteredServices[i];
                        final catId = _categoryForService(svc.code);
                        final color = _colorForCategory(catId);
                        final catLabel = _labelForCategory(catId);
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _kCatalog
                                  .firstWhere((c) => c.id == catId)
                                  .icon,
                              color: color,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            svc.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  catLabel.split('(').first.trim(),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                svc.code,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ETB ${svc.defaultPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: () {
                                  widget.onSelected(
                                      svc.name, svc.code, svc.defaultPrice);
                                  Navigator.pop(context);
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: color,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Add',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          onTap: () {
                            widget.onSelected(
                                svc.name, svc.code, svc.defaultPrice);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),

            // Footer hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Text(
                    'Unit prices are default estimates — adjust as needed after adding.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
