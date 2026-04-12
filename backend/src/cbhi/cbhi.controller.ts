import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import {
  CreateFamilyMemberDto,
  RegistrationStepOneDto,
  RegistrationStepTwoDto,
  RenewCoverageDto,
  UpdateFamilyMemberDto,
} from './cbhi.dto';
import { CbhiService } from './cbhi.service';

@Controller('cbhi')
export class CbhiController {
  constructor(
    private readonly cbhiService: CbhiService,
    private readonly authService: AuthService,
  ) {}

  @Post('registration/step-1')
  registerStepOne(@Body() dto: RegistrationStepOneDto) {
    return this.cbhiService.registerStepOne(dto);
  }

  @Post('registration/step-2')
  registerStepTwo(@Body() dto: RegistrationStepTwoDto) {
    return this.cbhiService.registerStepTwo(dto);
  }

  @Get('me')
  async getSnapshot(@Headers('authorization') authorization?: string) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.getMemberSnapshot(user.id);
  }

  @Get('family')
  async getFamily(@Headers('authorization') authorization?: string) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.getFamily(user.id);
  }

  @Get('profile')
  async getProfile(@Headers('authorization') authorization?: string) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.getProfile(user.id);
  }

  @Get('eligibility')
  async getEligibility(@Headers('authorization') authorization?: string) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.getViewerEligibility(user.id);
  }

  @Get('payments')
  async getPayments(@Headers('authorization') authorization?: string) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.getPaymentHistory(user.id);
  }

  @Post('coverage/renew')
  async renewCoverage(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: RenewCoverageDto,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.renewCoverage(user.id, dto);
  }

  @Get('cards')
  async getDigitalCards(@Headers('authorization') authorization?: string) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.getDigitalCards(user.id);
  }

  @Get('notifications')
  async getNotifications(@Headers('authorization') authorization?: string) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.getNotifications(user.id);
  }

  @Post('notifications/:notificationId/read')
  async markNotificationRead(
    @Headers('authorization') authorization: string | undefined,
    @Param('notificationId') notificationId: string,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.markNotificationRead(user.id, notificationId);
  }

  @Post('family')
  async addFamilyMember(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: CreateFamilyMemberDto,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.addFamilyMember(user.id, dto);
  }

  @Patch('family/:memberId')
  async updateFamilyMember(
    @Headers('authorization') authorization: string | undefined,
    @Param('memberId') memberId: string,
    @Body() dto: UpdateFamilyMemberDto,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.updateFamilyMember(user.id, memberId, dto);
  }

  @Delete('family/:memberId')
  async removeFamilyMember(
    @Headers('authorization') authorization: string | undefined,
    @Param('memberId') memberId: string,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.cbhiService.removeFamilyMember(user.id, memberId);
  }
}
