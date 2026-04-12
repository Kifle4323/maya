import { Body, Controller, Get, Headers, Post, Query } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import {
  SubmitServiceClaimDto,
  VerifyEligibilityQueryDto,
} from './facility.dto';
import { FacilityService } from './facility.service';

@Controller('facility')
export class FacilityController {
  constructor(
    private readonly facilityService: FacilityService,
    private readonly authService: AuthService,
  ) {}

  @Get('eligibility')
  async verifyEligibility(
    @Headers('authorization') authorization: string | undefined,
    @Query() query: VerifyEligibilityQueryDto,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.facilityService.verifyBeneficiaryEligibility(user.id, query);
  }

  @Post('claims')
  async submitClaim(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: SubmitServiceClaimDto,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.facilityService.submitServiceClaim(user.id, dto);
  }

  @Get('claims')
  async listClaims(@Headers('authorization') authorization: string | undefined) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.facilityService.listFacilityClaims(user.id);
  }
}
