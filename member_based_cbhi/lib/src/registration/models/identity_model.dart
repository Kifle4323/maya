/// Maps UI / legacy codes to backend [IndigentEmploymentStatus] string values.
const Map<String, String> kEmploymentStatusForApi = {
  'farmer': 'farmer',
  'merchant': 'merchant',
  'daily_laborer': 'daily_laborer',
  'employed': 'employed',
  'unemployed': 'unemployed',
  'student': 'student',
  'homemaker': 'homemaker',
  'pensioner': 'pensioner',
  // Legacy uppercase keys (older builds)
  'FARMER': 'farmer',
  'MERCHANT': 'merchant',
  'DAILY_LABORER': 'daily_laborer',
  'EMPLOYED': 'employed',
  'UNEMPLOYED': 'unemployed',
  'STUDENT': 'student',
  'HOUSEWIFE': 'homemaker',
  'HOMEMAKER': 'homemaker',
  'PENSIONER': 'pensioner',
  'OTHER': 'unemployed',
};

class IdentityModel {
  const IdentityModel({
    required this.identityType,
    required this.identityNumber,
    this.identityPhotoPath,
    this.idFrontPath,
    this.idBackPath,
    this.verificationId,
    this.verificationStatus,
    required this.employmentStatus,
  });

  final String identityType;
  final String identityNumber;
  final String? identityPhotoPath;
  final String? idFrontPath;
  final String? idBackPath;
  final String? verificationId;
  final String? verificationStatus; // 'approved', 'rejected', 'manual_review'
  final String employmentStatus;

  /// Backend `/cbhi/registration/step-2` expects lowercase snake_case.
  String get employmentStatusForApi =>
      kEmploymentStatusForApi[employmentStatus] ?? 'unemployed';

  Map<String, dynamic> toJson() {
    return {
      'identityType': identityType,
      'identityNumber': identityNumber,
      'employmentStatus': employmentStatus,
      if (idFrontPath != null) 'idFrontPath': idFrontPath,
      if (idBackPath != null) 'idBackPath': idBackPath,
      if (verificationId != null) 'verificationId': verificationId,
      if (verificationStatus != null) 'verificationStatus': verificationStatus,
    };
  }

  factory IdentityModel.fromJson(Map<String, dynamic> json) {
    return IdentityModel(
      identityType: json['identityType']?.toString() ?? 'NATIONAL_ID',
      identityNumber: json['identityNumber']?.toString() ?? '',
      identityPhotoPath: json['identityPhotoPath']?.toString(),
      idFrontPath: json['idFrontPath']?.toString(),
      idBackPath: json['idBackPath']?.toString(),
      verificationId: json['verificationId']?.toString(),
      verificationStatus: json['verificationStatus']?.toString(),
      employmentStatus: json['employmentStatus']?.toString() ?? 'unemployed',
    );
  }
}
