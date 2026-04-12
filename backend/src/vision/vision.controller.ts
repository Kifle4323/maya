import { Body, Controller, Post } from '@nestjs/common';
import { IsOptional, IsString } from 'class-validator';
import { Public } from '../common/decorators/public.decorator';
import { VisionService } from './vision.service';

class ValidateIdDto {
  @IsString()
  imageBase64!: string;

  @IsOptional()
  @IsString()
  expectedIdNumber?: string;
}

class ValidateIndigentDocDto {
  @IsString()
  imageBase64!: string;
}

@Controller('vision')
export class VisionController {
  constructor(private readonly visionService: VisionService) {}

  @Post('validate-id')
  validateId(@Body() dto: ValidateIdDto) {
    return this.visionService.validateIdDocument(dto.imageBase64, dto.expectedIdNumber);
  }

  @Post('validate-indigent-doc')
  validateIndigentDoc(@Body() dto: ValidateIndigentDocDto) {
    return this.visionService.validateIndigentDocument(dto.imageBase64);
  }
}
