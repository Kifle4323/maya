import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) '../../shared/permission_handler_stub.dart';


import '../models/personal_info_model.dart';
import '../../cbhi_data.dart';
import '../../cbhi_localizations.dart';
import '../../shared/language_selector.dart';
import '../../theme/app_theme.dart';
import '../../shared/file_image_widget.dart';
import '../../shared/local_attachment_store.dart';
import '../../shared/location_service.dart';
import '../../shared/ethiopic_date_picker.dart';

class PersonalInfoForm extends StatefulWidget {
  const PersonalInfoForm({
    super.key,
    this.initialValue,
    this.onCancel,
    required this.onNext,
    this.repository,
  });

  final PersonalInfoModel? initialValue;
  final VoidCallback? onCancel;
  final ValueChanged<PersonalInfoModel> onNext;
  final CbhiRepository? repository;

  @override
  State<PersonalInfoForm> createState() => _PersonalInfoFormState();
}

class _PersonalInfoFormState extends State<PersonalInfoForm> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late LocationService _locationService;

  late final TextEditingController _firstName;
  late final TextEditingController _middleName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _dateOfBirth;
  late final TextEditingController _age;
  late final TextEditingController _householdSize;
  String _gender = 'FEMALE';
  String? _birthCertificatePath;

  // Real-time duplicate detection
  String? _phoneError;
  bool _checkingPhone = false;
  DateTime? _lastPhoneCheck;

  // Location cascade state
  List<LocationItem> _regions = [];
  List<LocationItem> _zones = [];
  List<LocationItem> _woredas = [];
  List<LocationItem> _kebeles = [];
  LocationItem? _selectedRegion;
  LocationItem? _selectedZone;
  LocationItem? _selectedWoreda;
  LocationItem? _selectedKebele;
  bool _loadingLocations = false;
  String? _locationError;

  // Trackers for fallback controllers to avoid recreating in build
  final _regionCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  final _woredaCtrl = TextEditingController();
  final _kebeleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _locationService = LocationService(
      apiBaseUrl: widget.repository?.apiBaseUrl ?? kDefaultApiBaseUrl,
    );
    final initial = widget.initialValue;
    _firstName = TextEditingController(text: initial?.firstName ?? '');
    _middleName = TextEditingController(text: initial?.middleName ?? '');
    _lastName = TextEditingController(text: initial?.lastName ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '+2519');
    _email = TextEditingController(text: initial?.email ?? '');
    _dateOfBirth = TextEditingController(
      text: initial == null
          ? ''
          : '${initial.dateOfBirth.year.toString().padLeft(4, '0')}-'
              '${initial.dateOfBirth.month.toString().padLeft(2, '0')}-'
              '${initial.dateOfBirth.day.toString().padLeft(2, '0')}',
    );
    _age = TextEditingController(text: initial?.age.toString() ?? '');
    _householdSize = TextEditingController(
      text: (initial?.householdSize ?? 1).toString(),
    );
    _gender = initial?.gender ?? 'FEMALE';
    _birthCertificatePath = initial?.birthCertificatePath;
    _loadRegions(restoreFrom: initial);
  }

  Future<void> _loadRegions({PersonalInfoModel? restoreFrom}) async {
    setState(() {
      _loadingLocations = true;
      _locationError = null;
    });
    try {
      final regions = await _locationService.fetchRegions();
      setState(() {
        _regions = regions;
        _loadingLocations = false;
      });

      // Maya City Restriction Logic
      if (restoreFrom == null) {
        final harari = regions.cast<LocationItem?>().firstWhere(
          (r) => r?.name.toLowerCase().contains('harari') ?? false,
          orElse: () => null,
        );
        if (harari != null) {
          await _onRegionChanged(harari);
          
          // Auto-select Harar zone if exists
          final zone = _zones.cast<LocationItem?>().firstWhere(
            (z) => z?.name.toLowerCase().contains('harar') ?? false,
            orElse: () => null,
          );
          if (zone != null) {
            await _onZoneChanged(zone);
            
            // Auto-select Maya City woreda if exists
            final mayaCity = _woredas.cast<LocationItem?>().firstWhere(
              (w) => w?.name.toLowerCase().contains('maya') ?? false,
              orElse: () => null,
            );
            if (mayaCity != null) {
              await _onWoredaChanged(mayaCity);
            }
          }
        }
      } else if (restoreFrom.region.isNotEmpty) {
        await _restoreLocation(restoreFrom);
      }
    } catch (e) {
      setState(() {
        _loadingLocations = false;
        _locationError = e.toString();
      });
    }
  }

  Future<void> _restoreLocation(PersonalInfoModel info) async {
    final region = _regions.cast<LocationItem?>().firstWhere(
      (r) => r?.name == info.region || r?.code == info.region,
      orElse: () => null,
    );
    if (region == null) return;
    final zones = await _locationService.fetchZones(region.code);
    final zone = zones.cast<LocationItem?>().firstWhere(
      (z) => z?.name == info.zone || z?.code == info.zone,
      orElse: () => null,
    );
    List<LocationItem> woredas = [];
    LocationItem? woreda;
    List<LocationItem> kebeles = [];
    LocationItem? kebele;
    if (zone != null) {
      woredas = await _locationService.fetchWoredas(zone.code);
      woreda = woredas.cast<LocationItem?>().firstWhere(
        (w) => w?.name == info.woreda || w?.code == info.woreda,
        orElse: () => null,
      );
      if (woreda != null) {
        kebeles = await _locationService.fetchKebeles(woreda.code);
        kebele = kebeles.cast<LocationItem?>().firstWhere(
          (k) => k?.name == info.kebele || k?.code == info.kebele,
          orElse: () => null,
        );
      }
    }
    if (mounted) {
      setState(() {
        _selectedRegion = region;
        _zones = zones;
        _selectedZone = zone;
        _woredas = woredas;
        _selectedWoreda = woreda;
        _kebeles = kebeles;
        _selectedKebele = kebele;
      });
    }
  }

  Future<void> _onRegionChanged(LocationItem? region) async {
    setState(() {
      _selectedRegion = region;
      _selectedZone = null;
      _selectedWoreda = null;
      _selectedKebele = null;
      _zones = [];
      _woredas = [];
      _kebeles = [];
    });
    if (region == null) return;
    final zones = await _locationService.fetchZones(region.code);
    if (mounted) setState(() => _zones = zones);
  }

  Future<void> _onZoneChanged(LocationItem? zone) async {
    setState(() {
      _selectedZone = zone;
      _selectedWoreda = null;
      _selectedKebele = null;
      _woredas = [];
      _kebeles = [];
    });
    if (zone == null) return;
    final woredas = await _locationService.fetchWoredas(zone.code);
    if (mounted) setState(() => _woredas = woredas);
  }

  Future<void> _onWoredaChanged(LocationItem? woreda) async {
    setState(() {
      _selectedWoreda = woreda;
      _selectedKebele = null;
      _kebeles = [];
    });
    if (woreda == null) return;
    final kebeles = await _locationService.fetchKebeles(woreda.code);
    if (mounted) setState(() => _kebeles = kebeles);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _dateOfBirth.dispose();
    _age.dispose();
    _householdSize.dispose();
    _regionCtrl.dispose();
    _zoneCtrl.dispose();
    _woredaCtrl.dispose();
    _kebeleCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final parsed = DateTime.tryParse(_dateOfBirth.text) ?? DateTime(now.year - 20);
    final picked = await showEthiopicDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: CbhiLocalizations.of(context).t('dateOfBirth'),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
        _age.text = _calculateAge().toString();
      });
    }
  }

  Future<void> _pickBirthCertificate() async {
    if (!kIsWeb) {
      await Permission.camera.request();
      await Permission.photos.request();
    }
    if (!mounted) return;
    final strings = CbhiLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (!kIsWeb) ...[
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(strings.t('takePhoto')),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(strings.t('chooseFromGallery')),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(strings.t('choosePdfOrImage')),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
        withData: kIsWeb,
      );
      if (result == null) return;
      final file = result.files.single;
      if (kIsWeb) {
        if (file.bytes != null && mounted) {
          setState(() => _birthCertificatePath = 'web:${file.name}');
        }
      } else if (file.path != null) {
        final persisted = await LocalAttachmentStore.persist(
          file.path!,
          category: 'registration_birth_certificate',
        );
        if (mounted) setState(() => _birthCertificatePath = persisted);
      }
      return;
    }
    final picked = choice == 'camera'
        ? await _picker.pickImage(source: ImageSource.camera, imageQuality: 85)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      final persisted = await LocalAttachmentStore.persist(
        picked.path,
        category: 'registration_birth_certificate',
      );
      if (mounted) setState(() => _birthCertificatePath = persisted);
    }
  }

  Future<void> _checkPhone(String value) async {
    final phone = value.trim();
    if (phone.length < 10) {
      if (_phoneError != null) setState(() => _phoneError = null);
      return;
    }
    // Debounce — wait 600ms after last keystroke
    final now = DateTime.now();
    _lastPhoneCheck = now;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (_lastPhoneCheck != now || !mounted) return;

    setState(() => _checkingPhone = true);
    final error = await widget.repository?.checkPhoneAvailability(phone);
    if (!mounted) return;
    setState(() {
      _phoneError = error;
      _checkingPhone = false;
    });
  }

  bool _isImage(String path) {
    final n = path.toLowerCase();
    return n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg');
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('step1PersonalInfo')),
        leading: widget.onCancel == null
            ? null
            : IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
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
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Section
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
                          strings.t('personalInformation'),
                          style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.t('captureHouseholdDetails'),
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name row
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  _firstName,
                                  strings.t('firstName'),
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(_middleName, strings.t('middleName')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(_lastName, strings.t('lastName'), required: true),
                          const SizedBox(height: 12),

                          // Phone + Email
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: strings.t('phoneNumber'),
                                    hintText: '+2519XXXXXXXX',
                                    alignLabelWithHint: true,
                                    errorText: _phoneError,
                                    suffixIcon: _checkingPhone
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: Padding(
                                              padding: EdgeInsets.all(12),
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        : _phoneError != null
                                            ? const Icon(Icons.error_outline, color: Colors.red)
                                            : null,
                                  ),
                                  onChanged: _checkPhone,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return strings.t('required');
                                    if (_phoneError != null) return _phoneError;
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  _email,
                                  strings.t('emailAddress'),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Gender + Date of birth
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _gender,
                                  decoration: InputDecoration(labelText: strings.t('gender')),
                                  items: [
                                    DropdownMenuItem(value: 'FEMALE', child: Text(strings.t('female'))),
                                    DropdownMenuItem(value: 'MALE', child: Text(strings.t('male'))),
                                    DropdownMenuItem(value: 'OTHER', child: Text(strings.t('other'))),
                                  ],
                                  onChanged: (v) => setState(() => _gender = v ?? 'FEMALE'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _dateOfBirth,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: strings.t('dateOfBirth'),
                                    hintText: 'YYYY-MM-DD',
                                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? strings.t('required') : null,
                                  onTap: _selectDate,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  _age,
                                  strings.t('age'),
                                  required: true,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Household address section
                  Text(strings.t('householdAddress'), style: textTheme.titleMedium),
                  const SizedBox(height: 12),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _loadingLocations
                          ? const Center(child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(),
                            ))
                          : _locationError != null
                              ? _buildFallbackLocationFields(strings)
                              : Column(
                                  children: [
                                    // Region + Zone
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<LocationItem>(
                                            initialValue: _selectedRegion,
                                            decoration: InputDecoration(labelText: strings.t('region')),
                                            items: _regions
                                                .map((r) => DropdownMenuItem(
                                                      value: r,
                                                      child: Text(r.displayName(Localizations.localeOf(context).languageCode)),
                                                    ))
                                                .toList(),
                                            onChanged: _onRegionChanged,
                                            validator: (v) => v == null ? strings.t('required') : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: DropdownButtonFormField<LocationItem>(
                                            initialValue: _selectedZone,
                                            decoration: InputDecoration(labelText: strings.t('zone')),
                                            items: _zones
                                                .map((z) => DropdownMenuItem(
                                                      value: z,
                                                      child: Text(z.displayName(Localizations.localeOf(context).languageCode)),
                                                    ))
                                                .toList(),
                                            onChanged: _selectedRegion == null ? null : _onZoneChanged,
                                            validator: (v) => v == null ? strings.t('required') : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Woreda + Kebele
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<LocationItem>(
                                            initialValue: _selectedWoreda,
                                            decoration: InputDecoration(labelText: strings.t('woreda')),
                                            items: _woredas
                                                .map((w) => DropdownMenuItem(
                                                      value: w,
                                                      child: Text(w.displayName(Localizations.localeOf(context).languageCode)),
                                                    ))
                                                .toList(),
                                            onChanged: _selectedZone == null ? null : _onWoredaChanged,
                                            validator: (v) => v == null ? strings.t('required') : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: DropdownButtonFormField<LocationItem>(
                                            initialValue: _selectedKebele,
                                            decoration: InputDecoration(labelText: strings.t('kebele')),
                                            items: _kebeles
                                                .map((k) => DropdownMenuItem(
                                                      value: k,
                                                      child: Text(k.displayName(Localizations.localeOf(context).languageCode)),
                                                    ))
                                                .toList(),
                                            onChanged: _selectedWoreda == null
                                                ? null
                                                : (v) => setState(() => _selectedKebele = v),
                                            validator: (v) => v == null ? strings.t('required') : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Household size
                  _buildTextField(
                    _householdSize,
                    strings.t('householdSize'),
                    required: true,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  // Birth certificate (optional)
                  _DocumentPickerCard(
                    title: strings.t('birthCertificate'),
                    subtitle: strings.t('optionalImageOrPdf'),
                    path: _birthCertificatePath,
                    onPick: _pickBirthCertificate,
                    isImage: _birthCertificatePath != null && _isImage(_birthCertificatePath!),
                    uploadLabel: strings.t('uploadDocument'),
                    replaceLabel: strings.t('replaceDocument'),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: Text(strings.t('reviewInformation')),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fallback free-text fields when location API is unavailable (offline)
  Widget _buildFallbackLocationFields(dynamic strings) {
    if (_regionCtrl.text.isEmpty && _selectedRegion != null) _regionCtrl.text = _selectedRegion!.name;
    if (_zoneCtrl.text.isEmpty && _selectedZone != null) _zoneCtrl.text = _selectedZone!.name;
    if (_woredaCtrl.text.isEmpty && _selectedWoreda != null) _woredaCtrl.text = _selectedWoreda!.name;
    if (_kebeleCtrl.text.isEmpty && _selectedKebele != null) _kebeleCtrl.text = _selectedKebele!.name;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildTextField(_regionCtrl, strings.t('region'), required: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_zoneCtrl, strings.t('zone'), required: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_woredaCtrl, strings.t('woreda'), required: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_kebeleCtrl, strings.t('kebele'), required: true)),
          ],
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_phoneError != null) return; // Block if phone is taken
    if (_checkingPhone) return; // Block if check in progress
    final strings = CbhiLocalizations.of(context);

    // Validate location — either dropdown or fallback text
    final regionName = _selectedRegion?.name ?? _regionCtrl.text.trim();
    final zoneName = _selectedZone?.name ?? _zoneCtrl.text.trim();
    final woredaName = _selectedWoreda?.name ?? _woredaCtrl.text.trim();
    final kebeleName = _selectedKebele?.name ?? _kebeleCtrl.text.trim();

    if (_locationError == null && (regionName.isEmpty || zoneName.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('required'))),
      );
      return;
    }

    widget.onNext(
      PersonalInfoModel(
        firstName: _firstName.text.trim(),
        middleName: _middleName.text.trim().isEmpty ? null : _middleName.text.trim(),
        lastName: _lastName.text.trim(),
        age: int.tryParse(_age.text.trim()) ?? _calculateAge(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        gender: _gender,
        dateOfBirth: DateTime.tryParse(_dateOfBirth.text.trim()) ?? DateTime.now(),
        birthCertificateRef: null,
        birthCertificatePath: _birthCertificatePath,
        idDocumentPath: null,
        region: regionName,
        zone: zoneName,
        woreda: woredaName,
        kebele: kebeleName,
        householdSize: int.tryParse(_householdSize.text.trim()) ?? 1,
        preferredLanguage: 'en',
      ),
    );
  }

  int _calculateAge() {
    final dob = DateTime.tryParse(_dateOfBirth.text.trim());
    if (dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    final strings = CbhiLocalizations.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        alignLabelWithHint: true,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? strings.t('required') : null
          : null,
    );
  }
}

class _DocumentPickerCard extends StatelessWidget {
  const _DocumentPickerCard({
    required this.title,
    required this.subtitle,
    required this.path,
    required this.onPick,
    required this.isImage,
    required this.uploadLabel,
    required this.replaceLabel,
  });

  final String title;
  final String subtitle;
  final String? path;
  final VoidCallback onPick;
  final bool isImage;
  final String uploadLabel;
  final String replaceLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 12),
            if (path != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: kIsWeb
                    ? const Icon(Icons.description_outlined, size: 48) // Web fallback
                    : isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: NativeFileImage(
                              path: path!,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Row(
                            children: [
                              const Icon(Icons.description_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(path!.split('/').last),
                              ),
                            ],
                          ),

              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(path == null ? uploadLabel : replaceLabel),
            ),
          ],
        ),
      ),
    );
  }
}
