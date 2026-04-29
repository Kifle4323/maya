import 'package:flutter/foundation.dart';

@immutable
class PersonalInfoModel {
  const PersonalInfoModel({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.age,
    this.phone,
    this.email,
    required this.gender,
    required this.dateOfBirth,
    this.birthCertificateRef,
    this.birthCertificatePath,
    this.idDocumentPath,
    this.photoPath,
    required this.region,
    required this.zone,
    this.woreda,
    this.kebele,
    required this.householdSize,
    this.preferredLanguage = 'en',
  });

  final String firstName;
  final String? middleName;
  final String lastName;
  final int age;
  final String? phone;
  final String? email;
  final String gender;
  final DateTime dateOfBirth;
  final String? birthCertificateRef;
  final String? birthCertificatePath;   // Path to uploaded file/image
  final String? idDocumentPath;         // Path to ID photo
  final String? photoPath;              // Path to profile photo

  final String region;
  final String zone;
  final String? woreda;
  final String? kebele;
  final int householdSize;

  /// BCP-47 language code: en, am, om
  final String preferredLanguage;

  String get fullName => [firstName, middleName, lastName]
      .where((e) => e != null && e.trim().isNotEmpty)
      .join(' ');

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'age': age,
        'phone': phone,
        'email': email,
        'gender': gender,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'birthCertificateRef': birthCertificateRef,
        'birthCertificatePath': birthCertificatePath,
        'idDocumentPath': idDocumentPath,
        'beneficiaryPhotoPath': photoPath,
        'address': {
          'region': region,
          'zone': zone,
          if (woreda != null && woreda!.isNotEmpty) 'woreda': woreda,
          if (kebele != null && kebele!.isNotEmpty) 'kebele': kebele,
        },
        'householdSize': householdSize,
        'preferredLanguage': preferredLanguage,
      };

  factory PersonalInfoModel.fromJson(Map<String, dynamic> json) {
    final address = (json['address'] as Map? ?? {}).cast<String, dynamic>();
    return PersonalInfoModel(
      firstName: json['firstName']?.toString() ?? '',
      middleName: json['middleName']?.toString(),
      lastName: json['lastName']?.toString() ?? '',
      age: int.tryParse(json['age']?.toString() ?? '0') ?? 0,
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      gender: json['gender']?.toString() ?? 'OTHER',
      dateOfBirth: DateTime.parse(json['dateOfBirth']?.toString() ?? '1990-01-01'),
      birthCertificateRef: json['birthCertificateRef']?.toString(),
      birthCertificatePath: json['birthCertificatePath']?.toString(),
      idDocumentPath: json['idDocumentPath']?.toString(),
      photoPath: json['beneficiaryPhotoPath']?.toString() ?? json['photoPath']?.toString(),
      region: address['region']?.toString() ?? '',
      zone: address['zone']?.toString() ?? '',
      woreda: address['woreda']?.toString(),
      kebele: address['kebele']?.toString(),
      householdSize: int.tryParse(json['householdSize']?.toString() ?? '1') ?? 1,
      preferredLanguage: json['preferredLanguage']?.toString() ?? 'en',
    );
  }
}