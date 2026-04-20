import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';


import '../models/personal_info_model.dart';
import '../../cbhi_data.dart';
import '../../cbhi_localizations.dart';
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
  late final TextEditingController _householdSize;
  String _gender = 'FEMALE';
  String? _birthCertificatePath;

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
      // Restore previously selected location if editing
      if (restoreFrom != null && restoreFrom.region.isNotEmpty) {
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
    _householdSize.dispose();
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
      });
    }
  }

  Future<void> _pickBirthCertificate() async {
    await Permission.camera.request();
    await Permission.photos.request();
    if (!mounted) return;
    final strings = CbhiLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
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
      final file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (file?.files.single.path != null) {
        final persisted = await LocalAttachmentStore.persist(
          file!.files.single.path!,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.t('personalInformation'), style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(strings.t('captureHouseholdDetails'), style: textTheme.bodyMedium),
              const SizedBox(height: 24),

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
                    child: _buildTextField(
                      _phone,
                      strings.t('phoneNumber'),
                      required: true,
                      keyboardType: TextInputType.phone,
                      hintText: '+2519XXXXXXXX',
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
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? strings.t('required') : null,
                      onTap: _selectDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Household address section
              Text(strings.t('householdAddress'), style: textTheme.titleMedium),
              const SizedBox(height: 12),

              if (_loadingLocations)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ))
              else if (_locationError != null)
                // Fallback to free-text fields when API is unavailable
                _buildFallbackLocationFields(strings)
              else ...[
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
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(strings.t('reviewInformation')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fallback free-text fields when location API is unavailable (offline)
  Widget _buildFallbackLocationFields(dynamic strings) {
    final regionCtrl = TextEditingController(text: _selectedRegion?.name ?? '');
    final zoneCtrl = TextEditingController(text: _selectedZone?.name ?? '');
    final woredaCtrl = TextEditingController(text: _selectedWoreda?.name ?? '');
    final kebeleCtrl = TextEditingController(text: _selectedKebele?.name ?? '');
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildTextField(regionCtrl, strings.t('region'), required: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(zoneCtrl, strings.t('zone'), required: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(woredaCtrl, strings.t('woreda'), required: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(kebeleCtrl, strings.t('kebele'), required: true)),
          ],
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final strings = CbhiLocalizations.of(context);

    // Validate location — either dropdown or fallback text
    final regionName = _selectedRegion?.name ?? '';
    final zoneName = _selectedZone?.name ?? '';
    final woredaName = _selectedWoreda?.name ?? '';
    final kebeleName = _selectedKebele?.name ?? '';

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
        age: _calculateAge(),
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
