export enum UserRole {
  HOUSEHOLD_HEAD = 'HOUSEHOLD_HEAD',
  BENEFICIARY = 'BENEFICIARY',
  HEALTH_FACILITY_STAFF = 'HEALTH_FACILITY_STAFF',
  CBHI_OFFICER = 'CBHI_OFFICER',
  SYSTEM_ADMIN = 'SYSTEM_ADMIN',
}

export enum IdentityDocumentType {
  NATIONAL_ID = 'NATIONAL_ID',
  PASSPORT = 'PASSPORT',
  LOCAL_ID = 'LOCAL_ID',
}

export enum IdentityVerificationStatus {
  PENDING = 'PENDING',
  VERIFIED = 'VERIFIED',
  FAILED = 'FAILED',
}

export enum PreferredLanguage {
  AMHARIC = 'am',
  AFAAN_OROMO = 'om',
  ENGLISH = 'en',
}

export enum MembershipType {
  INDIGENT = 'indigent',
  PAYING = 'paying',
}

export enum Gender {
  MALE = 'MALE',
  FEMALE = 'FEMALE',
  OTHER = 'OTHER',
  UNSPECIFIED = 'UNSPECIFIED',
}

export enum RelationshipToHouseholdHead {
  HEAD = 'HEAD',
  SPOUSE = 'SPOUSE',
  CHILD = 'CHILD',
  PARENT = 'PARENT',
  SIBLING = 'SIBLING',
  OTHER = 'OTHER',
}

export enum CoverageStatus {
  ACTIVE = 'ACTIVE',
  PENDING_RENEWAL = 'PENDING_RENEWAL',
  EXPIRED = 'EXPIRED',
  SUSPENDED = 'SUSPENDED',
  REJECTED = 'REJECTED',
}

export enum PaymentMethod {
  MOBILE_MONEY = 'MOBILE_MONEY',
  BANK_CARD = 'BANK_CARD',
  EWALLET = 'EWALLET',
  BANK_TRANSFER = 'BANK_TRANSFER',
}

export enum PaymentStatus {
  PENDING = 'PENDING',
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED',
  REFUNDED = 'REFUNDED',
}

export enum ClaimStatus {
  DRAFT = 'DRAFT',
  SUBMITTED = 'SUBMITTED',
  UNDER_REVIEW = 'UNDER_REVIEW',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  PAID = 'PAID',
}

export enum DocumentType {
  IDENTITY_DOCUMENT = 'IDENTITY_DOCUMENT',
  BIRTH_CERTIFICATE = 'BIRTH_CERTIFICATE',
  BENEFICIARY_PHOTO = 'BENEFICIARY_PHOTO',
  NATIONAL_ID = 'NATIONAL_ID',
  MEMBERSHIP_CARD = 'MEMBERSHIP_CARD',
  CLAIM_SUPPORTING = 'CLAIM_SUPPORTING',
  RECEIPT = 'RECEIPT',
  OTHER = 'OTHER',
}

export enum NotificationType {
  RENEWAL_REMINDER = 'RENEWAL_REMINDER',
  CLAIM_UPDATE = 'CLAIM_UPDATE',
  HEALTH_PROMOTION = 'HEALTH_PROMOTION',
  SYSTEM_ALERT = 'SYSTEM_ALERT',
}

export enum FacilityUserRole {
  REGISTRAR = 'REGISTRAR',
  VERIFIER = 'VERIFIER',
  CLAIMS_OFFICER = 'CLAIMS_OFFICER',
  ADMIN = 'ADMIN',
}

export enum IndigentEmploymentStatus {
  FARMER = 'farmer',
  MERCHANT = 'merchant',
  DAILY_LABORER = 'daily_laborer',
  EMPLOYED = 'employed',
  UNEMPLOYED = 'unemployed',
  STUDENT = 'student',
  HOMEMAKER = 'homemaker',
  PENSIONER = 'pensioner',
}

export enum IndigentApplicationStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
}
