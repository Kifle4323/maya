import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('am'),
    Locale('om'),
  ];

  static const frameworkSupportedLocales = <Locale>[Locale('en'), Locale('am')];

  static Locale resolveAppLocale(Locale locale) {
    return switch (locale.languageCode) {
      'am' => const Locale('am'),
      'om' => const Locale('om'),
      _ => const Locale('en'),
    };
  }

  static Locale resolveFrameworkLocale(Locale locale) {
    return switch (locale.languageCode) {
      'am' => const Locale('am'),
      _ => const Locale('en'),
    };
  }

  static const _values = <String, Map<String, String>>{
    'en': {
      'appTitle': 'Maya City CBHI Facility',
      'appWindowTitle': 'Maya City CBHI - Facility',
      'portalTitle': 'Maya City CBHI\nFacility Portal',
      'portalSubtitle':
          'For accredited health facility staff.\nVerify member eligibility and submit service claims.',
      'signIn': 'Sign In',
      'staffAccessOnly': 'Health facility staff access only',
      'identifierRequired': 'Email/phone and password are required.',
      'emailOrPhone': 'Email or phone',
      'password': 'Password',
      'language': 'Language',
      'languageEnglish': 'English',
      'languageAmharic': 'Amharic',
      'languageOromo': 'Afaan Oromo',
      'navVerify': 'Verify Eligibility',
      'navSubmitClaim': 'Submit Claim',
      'navClaimDecisions': 'Claim Decisions',
      'signOut': 'Sign Out',
      'online': 'Online',
      'facilityBrand': 'CBHI Facility',
      'staffPortal': 'Staff Portal',
      'realtimeEligibility': 'Real-time Eligibility Verification',
      'multiItemClaimSubmission': 'Multi-item Claim Submission',
      'claimStatusTracking': 'Claim Status Tracking',
      'qrLookup': 'QR Code Member Lookup',
      'searchMember': 'Search Member',
      'enterMemberDetails': 'Enter membership ID, phone, or household details.',
      'membershipId': 'Membership ID',
      'phoneNumber': 'Phone number',
      'or': 'OR',
      'householdCode': 'Household code',
      'fullName': 'Full name',
      'verify': 'Verify',
      'clear': 'Clear',
      'searchMemberPrompt': 'Search for a member to verify eligibility',
      'eligibleForService': 'ELIGIBLE FOR SERVICE',
      'notEligible': 'NOT ELIGIBLE',
      'memberDetails': 'Member Details',
      'relationship': 'Relationship',
      'coverageStatus': 'Coverage Status',
      'validUntil': 'Valid Until',
      'notAvailable': 'N/A',
      'beneficiary': 'Beneficiary',
      'serviceDate': 'Service Date',
      'serviceItems': 'Service Items',
      'addItem': 'Add Item',
      'submitClaim': 'Submit Claim',
      'service': 'Service {index}',
      'quantityShort': 'Qty',
      'unitPrice': 'Unit Price (ETB)',
      'addValidServiceItem': 'Add at least one valid service item.',
      'claimSubmitted': 'Claim {claimNumber} submitted successfully.',
      'submittedClaims': 'Submitted Claims',
      'refresh': 'Refresh',
      'noClaimsSubmittedYet': 'No claims submitted yet',
      'claimNumber': 'Claim #',
      'beneficiaryColumn': 'Beneficiary',
      'serviceDateColumn': 'Service Date',
      'claimedAmount': 'Claimed (ETB)',
      'approvedAmount': 'Approved (ETB)',
      'status': 'Status',
      'decisionNote': 'Decision Note',
      'statusSubmitted': 'Submitted',
      'statusUnderReview': 'Under Review',
      'statusApproved': 'Approved',
      'statusRejected': 'Rejected',
      'statusPaid': 'Paid',
      // QR scanner
      'scanQrCard': 'Scan QR Card',
      'scanMemberCard': 'Scan Member Card',
      'pointCameraAtCard': 'Point the camera at the member\'s QR code',
      'toggleFlash': 'Toggle flash',
      // Document attachment
      'attachDocument': 'Attach Document',
      'supportingDocument': 'Supporting Document',
      // Connectivity
      'offline': 'Offline',
      // Manual entry fallback
      'enterManually': 'Enter manually',
      'manualEntryHint': 'Enter membership ID or household code',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      // Claim total
      'totalClaimed': 'Total Claimed',
      // Catalog and confirm
      'confirmAndSubmit': 'Confirm & Submit',
      'browseCatalog': 'Browse Catalog',
      'accredited': 'Accredited',
      'category': 'Category',
      'claimedItems': 'Claimed Items',
      'exportCsv': 'Export CSV',
      'exportReady': 'Export ready — copy the CSV from the dialog.',
      'facilityCode': 'Facility Code',
      'facilityName': 'Facility Name',
      'itemCode': 'Item Code',
      'maxClaimAmount': 'Max Claim Amount',
      'noItemsInCatalog': 'No items in catalog',
      'noRecentClaims': 'No recent claims',
      'perMemberPerYear': 'per member / year',
      'serviceCode': 'Service Code',
      'serviceName': 'Service Name',
      'totalApproved': 'Total Approved',
      'allCategories': 'All Categories',
      'noServicesInCategory': 'No services in this category',
      'search': 'Search',
    },
    'am': {
      'appTitle': 'የማያ ከተማ CBHI ተቋም',
      'appWindowTitle': 'የማያ ከተማ CBHI - ተቋም',
      'portalTitle': 'የማያ ከተማ CBHI\nየተቋም ፖርታል',
      'portalSubtitle':
          'ለተፈቀዱ የጤና ተቋም ሰራተኞች።\nየአባል ብቁነትን ያረጋግጡ እና የአገልግሎት ክሌሞችን ያስገቡ።',
      'signIn': 'ግባ',
      'staffAccessOnly': 'ለጤና ተቋም ሰራተኞች ብቻ',
      'identifierRequired': 'ኢሜይል/ስልክ እና የይለፍ ቃል ያስፈልጋሉ።',
      'emailOrPhone': 'ኢሜይል ወይም ስልክ',
      'password': 'የይለፍ ቃል',
      'language': 'ቋንቋ',
      'languageEnglish': 'English',
      'languageAmharic': 'አማርኛ',
      'languageOromo': 'Afaan Oromoo',
      'navVerify': 'ብቁነት አረጋግጥ',
      'navSubmitClaim': 'ክሌም አስገባ',
      'navClaimDecisions': 'የክሌም ውሳኔዎች',
      'signOut': 'ውጣ',
      'online': 'መስመር ላይ',
      'facilityBrand': 'CBHI ተቋም',
      'staffPortal': 'የሰራተኞች ፖርታል',
      'realtimeEligibility': 'በቅጽበት የብቁነት ማረጋገጫ',
      'multiItemClaimSubmission': 'ባለብዙ ንጥል ክሌም ማስገባት',
      'claimStatusTracking': 'የክሌም ሁኔታ ክትትል',
      'qrLookup': 'የQR ኮድ ፍለጋ',
      'searchMember': 'አባል ፈልግ',
      'enterMemberDetails': 'የአባል መለያ፣ ስልክ ወይም የቤተሰብ መረጃ ያስገቡ።',
      'membershipId': 'የአባልነት መለያ',
      'phoneNumber': 'ስልክ ቁጥር',
      'or': 'ወይም',
      'householdCode': 'የቤተሰብ ኮድ',
      'fullName': 'ሙሉ ስም',
      'verify': 'አረጋግጥ',
      'clear': 'አጥፋ',
      'searchMemberPrompt': 'ብቁነት ለማረጋገጥ አባል ፈልግ',
      'eligibleForService': 'ለአገልግሎት ብቁ ነው',
      'notEligible': 'ብቁ አይደለም',
      'memberDetails': 'የአባል ዝርዝሮች',
      'relationship': 'ዝምድና',
      'coverageStatus': 'የሽፋን ሁኔታ',
      'validUntil': 'የሚያበቃበት ቀን',
      'notAvailable': 'የለም',
      'beneficiary': 'ተጠቃሚ',
      'serviceDate': 'የአገልግሎት ቀን',
      'serviceItems': 'የአገልግሎት ንጥሎች',
      'addItem': 'ንጥል ጨምር',
      'submitClaim': 'ክሌም አስገባ',
      'service': 'አገልግሎት {index}',
      'quantityShort': 'ብዛት',
      'unitPrice': 'የአንዱ ዋጋ (ብር)',
      'addValidServiceItem': 'ቢያንስ አንድ ትክክለኛ ንጥል ጨምር።',
      'claimSubmitted': 'ክሌም {claimNumber} በተሳካ ሁኔታ ተልኳል።',
      'submittedClaims': 'የተላኩ ክሌሞች',
      'refresh': 'አድስ',
      'noClaimsSubmittedYet': 'እስካሁን የተላከ ክሌም የለም',
      'claimNumber': 'ክሌም #',
      'beneficiaryColumn': 'ተጠቃሚ',
      'serviceDateColumn': 'የአገልግሎት ቀን',
      'claimedAmount': 'የተጠየቀ (ብር)',
      'approvedAmount': 'የጸደቀ (ብር)',
      'status': 'ሁኔታ',
      'decisionNote': 'የውሳኔ ማስታወሻ',
      'statusSubmitted': 'ቀርቧል',
      'statusUnderReview': 'በግምገማ ላይ',
      'statusApproved': 'ጸድቋል',
      'statusRejected': 'ተቀባይነት አላገኘም',
      'statusPaid': 'ተከፍሏል',
      // QR scanner
      'scanQrCard': 'QR ካርድ ቃኝ',
      'scanMemberCard': 'የአባል ካርድ ቃኝ',
      'pointCameraAtCard': 'ካሜራውን ወደ QR ኮዱ ያዙሩ',
      'toggleFlash': 'ፍላሽ ቀያይር',
      // Document attachment
      'attachDocument': 'ሰነድ አያይዝ',
      'supportingDocument': 'ድጋፍ ሰጪ ሰነድ',
      // Connectivity
      'offline': 'ኦፍላይን',
      // Manual entry fallback
      'enterManually': 'በእጅ ያስገቡ',
      'manualEntryHint': 'የአባልነት መለያ ወይም የቤተሰብ ኮድ ያስገቡ',
      'cancel': 'ሰርዝ',
      'confirm': 'አረጋግጥ',
      // Claim total
      'totalClaimed': 'ጠቅላላ የተጠየቀ',
      // Catalog and confirm
      'confirmAndSubmit': 'አረጋግጥ እና አስገባ',
      'browseCatalog': 'ካታሎግ ፈልግ',
      'accredited': 'ተፈቅዷል',
      'category': 'ምድብ',
      'claimedItems': 'የተጠየቁ እቃዎች',
      'exportCsv': 'ወደ CSV ላክ',
      'exportReady': 'ወደ ውጭ ለመላክ ተዘጋጅቷል',
      'facilityCode': 'የተቋም ኮድ',
      'facilityName': 'የተቋም ስም',
      'itemCode': 'የንጥል ኮድ',
      'maxClaimAmount': 'ከፍተኛ የጥያቄ መጠን',
      'noItemsInCatalog': 'በካታሎግ ውስጥ ምንም ዕቃ የለም',
      'noRecentClaims': 'ምንም የቅርብ ጊዜ ጥያቄዎች የሉም',
      'perMemberPerYear': 'በአባል / በዓመት',
      'serviceCode': 'የአገልግሎት ኮድ',
      'serviceName': 'የአገልግሎት ስም',
      'totalApproved': 'ጠቅላላ የጸደቀ',
      'allCategories': 'ሁሉም ምድቦች',
      'noServicesInCategory': 'በዚህ ምድብ ውስጥ ምንም አገልግሎቶች የሉም',
      'search': 'ፈልግ',
    },
    'om': {
      'appTitle': 'Dhaabbata CBHI Magaalaa Maya',
      'appWindowTitle': 'CBHI Magaalaa Maya - Dhaabbata',
      'portalTitle': 'CBHI Magaalaa Maya\nPoortaalii Dhaabbataa',
      'portalSubtitle':
          'Hojjettoota dhaabbata fayyaa raggaafamaniif.\nMirkaneessa miseensaa fi galmee klaayimii tajaajilaa raawwadhaa.',
      'signIn': 'Seeni',
      'staffAccessOnly': 'Hojjettoota dhaabbata fayyaa qofaaf',
      'identifierRequired': 'Imeelii/bilbila fi jecha darbii guuti.',
      'emailOrPhone': 'Imeelii yookaan bilbila',
      'password': 'Jecha darbii',
      'language': 'Afaan',
      'languageEnglish': 'English',
      'languageAmharic': 'Afaan Amaaraa',
      'languageOromo': 'Afaan Oromoo',
      'navVerify': 'Mirkaneessa eeyyama',
      'navSubmitClaim': 'Klaayimii ergi',
      'navClaimDecisions': 'Murtii klaayimii',
      'signOut': 'Ba\'i',
      'online': 'Toora irratti',
      'facilityBrand': 'Dhaabbata CBHI',
      'staffPortal': 'Poortaalii hojjettootaa',
      'realtimeEligibility': 'Mirkaneessa eeyyama yeroo dhugaa',
      'multiItemClaimSubmission': 'Ergaa klaayimii wantoota hedduu',
      'claimStatusTracking': 'Hordoffii haala klaayimii',
      'qrLookup': 'Barbaacha miseensaa QR',
      'searchMember': 'Miseensa barbaadi',
      'enterMemberDetails':
          'ID miseensaa, bilbila, yookaan odeeffannoo maatii galchi.',
      'membershipId': 'ID miseensaa',
      'phoneNumber': 'Lakkoofsa bilbilaa',
      'or': 'Yookaan',
      'householdCode': 'Koodii maatii',
      'fullName': 'Maqaa guutuu',
      'verify': 'Mirkaneessi',
      'clear': 'Haqi',
      'searchMemberPrompt': 'Eeyyama mirkaneessuuf miseensa barbaadi',
      'eligibleForService': 'TAJAAJILA FUDHACHUUF DANDA\'A',
      'notEligible': 'HIN DANDA\'U',
      'memberDetails': 'Odeeffannoo miseensaa',
      'relationship': 'Hariiroo',
      'coverageStatus': 'Haala tajaajilaa',
      'validUntil': 'Hanga',
      'notAvailable': 'Hin jiru',
      'beneficiary': 'Fayyadamaa',
      'serviceDate': 'Guyyaa tajaajilaa',
      'serviceItems': 'Wantoota tajaajilaa',
      'addItem': 'Wanta dabali',
      'submitClaim': 'Klaayimii ergi',
      'service': 'Tajaajila {index}',
      'quantityShort': 'Baay\'ina',
      'unitPrice': 'Gatii tokkoon (ETB)',
      'addValidServiceItem': 'Yoo xiqqaate tajaajila tokko sirrii dabali.',
      'claimSubmitted': 'Klaayimiin {claimNumber} milkaa\'inaan ergameera.',
      'submittedClaims': 'Klaayimiiwwan ergame',
      'refresh': 'Haaromsi',
      'noClaimsSubmittedYet': 'Amma iyyuu klaayimiin hin ergamne',
      'claimNumber': 'Klaayimii #',
      'beneficiaryColumn': 'Fayyadamaa',
      'serviceDateColumn': 'Guyyaa tajaajilaa',
      'claimedAmount': 'Kan gaafatame (ETB)',
      'approvedAmount': 'Kan raggaafame (ETB)',
      'status': 'Haala',
      'decisionNote': 'Yaada murtii',
      'statusSubmitted': 'Galfameera',
      'statusUnderReview': 'Sakatta\'iinsa keessa jira',
      'statusApproved': 'Raggaafameera',
      'statusRejected': 'Didameera',
      'statusPaid': 'Kaffalameera',
      // QR scanner
      'scanQrCard': 'Kaardii QR Qori',
      'scanMemberCard': 'Kaardii Miseensaa Qori',
      'pointCameraAtCard': 'Kaameraa gara koodii QR qajeelchi',
      'toggleFlash': 'Ifaa jijjiiri',
      // Document attachment
      'attachDocument': 'Galmee makami',
      'supportingDocument': 'Galmee deeggarsa',
      // Connectivity
      'offline': 'Toora ala',
      // Manual entry fallback
      'enterManually': 'Harkaan galchi',
      'manualEntryHint': 'ID miseensaa yookaan koodii maatii galchi',
      'cancel': 'Dhiisi',
      'confirm': 'Mirkaneessi',
      // Claim total
      'totalClaimed': 'Walitti qabama gaafatame',
      // Catalog and confirm
      'confirmAndSubmit': 'Mirkaneessi fi Ergi',
      'browseCatalog': 'Kataaloogii Barbaadi',
      'accredited': 'Raggaafameera',
      'category': 'Gosa',
      'claimedItems': 'Wantoota Gaafataman',
      'exportCsv': 'CSV Ergi',
      'exportReady': 'Erguuf Qophii dha',
      'facilityCode': 'Koodii Dhaabbataa',
      'facilityName': 'Maqaa Dhaabbataa',
      'itemCode': 'Koodii Meeshaa',
      'maxClaimAmount': 'Ol\'aanaa Klaayimii',
      'noItemsInCatalog': 'Kataaloogii keessa meeshaan hin jiru',
      'noRecentClaims': 'Klaayimiin dhiyoo hin jiru',
      'perMemberPerYear': 'miseensa / waggaa',
      'serviceCode': 'Koodii Tajaajilaa',
      'serviceName': 'Maqaa Tajaajilaa',
      'totalApproved': 'Walitti qabama raggaafame',
      'allCategories': 'Gosa Hunda',
      'noServicesInCategory': 'Gosuma kana keessatti tajaajila hin jiru',
      'search': 'Barbaadi',
    },
  };

  static AppLocalizations of(BuildContext context) {
    final localization = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localization ?? const AppLocalizations(Locale('en'));
  }

  String t(String key, [Map<String, String> params = const {}]) {
    var value =
        _values[locale.languageCode]?[key] ?? _values['en']?[key] ?? key;
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

  String languageLabel(String code) {
    return switch (code) {
      'am' => t('languageAmharic'),
      'om' => t('languageOromo'),
      _ => t('languageEnglish'),
    };
  }

  String statusLabel(String status) {
    return switch (status.toUpperCase()) {
      'SUBMITTED' => t('statusSubmitted'),
      'UNDER_REVIEW' => t('statusUnderReview'),
      'APPROVED' => t('statusApproved'),
      'REJECTED' => t('statusRejected'),
      'PAID' => t('statusPaid'),
      _ => status.replaceAll('_', ' '),
    };
  }

  static LocalizationsDelegate<AppLocalizations> delegateFor(Locale locale) =>
      _AppLocalizationsDelegate(locale);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate(this.selectedLocale);

  final Locale selectedLocale;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(selectedLocale);

  @override
  bool shouldReload(covariant _AppLocalizationsDelegate old) =>
      old.selectedLocale.languageCode != selectedLocale.languageCode;
}
