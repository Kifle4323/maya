import {
  BadRequestException,
  Body,
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import type { File as MulterFile } from 'multer';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';
import { VerificationResultDto, VerifyDocumentDto } from './verification.dto';
import { VerificationService } from './verification.service';

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'application/pdf'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

@Controller('verification')
export class VerificationController {
  constructor(private readonly verificationService: VerificationService) {}

  @Post('verify-document')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_FILE_SIZE },
      fileFilter: (_req, file, cb) => {
        if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
          cb(
            new BadRequestException(
              'Invalid file type. Allowed: JPG, PNG, PDF',
            ),
            false,
          );
        } else {
          cb(null, true);
        }
      },
    }),
  )
  async verifyDocument(
    @UploadedFile() file: MulterFile,
    @Body() dto: VerifyDocumentDto,
    @CurrentUser() user?: User,
  ): Promise<VerificationResultDto> {
    if (!file) {
      throw new BadRequestException('File is required');
    }

    return this.verificationService.verifyDocument(
      file.buffer,
      file.mimetype,
      dto,
      user?.id,
    );
  }
}
