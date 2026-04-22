import { IsEnum, IsNotEmpty, IsString } from 'class-validator';

export class VerifyDocumentDto {
  @IsString()
  @IsNotEmpty()
  userName!: string;

  @IsString()
  @IsNotEmpty()
  userIdNumber!: string;

  @IsEnum(['ID_CARD', 'INDIGENT_PROOF'])
  documentType!: 'ID_CARD' | 'INDIGENT_PROOF';
}

export interface ExtractedDocumentData {
  name: string | null;
  idNumber: string | null;
  expiryDate: string | null;
  documentType: string | null;
}

export class VerificationResultDto {
  status!: 'approved' | 'rejected' | 'manual_review';
  confidence!: number;
  extracted!: ExtractedDocumentData;
  reasons!: string[];
  verificationId!: string;
  isDemo!: boolean;
}
