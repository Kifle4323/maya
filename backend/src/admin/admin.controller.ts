import { Body, Controller, Get, Headers, Param, Patch, Post, Put, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { AuthService } from '../auth/auth.service';
import {
  ExportQueryDto,
  ReportsQueryDto,
  ReviewClaimDto,
  ReviewIndigentApplicationDto,
  UpdateSystemSettingDto,
} from './admin.dto';
import { AdminService } from './admin.service';

@Controller('admin')
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly authService: AuthService,
  ) {}

  @Get('indigent/pending')
  async getPendingIndigent(@Headers('authorization') authorization: string | undefined) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.adminService.getPendingIndigentApplications(user.id);
  }

  @Patch('indigent/:applicationId/review')
  async reviewIndigent(
    @Headers('authorization') authorization: string | undefined,
    @Param('applicationId') applicationId: string,
    @Body() dto: ReviewIndigentApplicationDto,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.adminService.reviewIndigentApplication(
      user.id,
      applicationId,
      dto,
    );
  }

  @Patch('claims/:claimId/decision')
  async reviewClaim(
    @Headers('authorization') authorization: string | undefined,
    @Param('claimId') claimId: string,
    @Body() dto: ReviewClaimDto,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.adminService.reviewClaim(user.id, claimId, dto);
  }

  @Get('claims')
  async listClaims(
    @Headers('authorization') authorization: string | undefined,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.adminService.listClaimsForReview(user.id);
  }

  @Get('configuration')
  async getConfiguration(
    @Headers('authorization') authorization: string | undefined,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.adminService.getSystemConfiguration(user.id);
  }

  @Put('configuration/:key')
  async updateConfiguration(
    @Headers('authorization') authorization: string | undefined,
    @Param('key') key: string,
    @Body() dto: UpdateSystemSettingDto,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.adminService.updateSystemConfiguration(user.id, key, dto);
  }

  @Get('reports/summary')
  async getSummaryReport(
    @Headers('authorization') authorization: string | undefined,
    @Query() query: ReportsQueryDto,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    return this.adminService.generateSummaryReport(user.id, query);
  }

  @Get('export')
  async exportData(
    @Headers('authorization') authorization: string | undefined,
    @Query() query: ExportQueryDto,
    @Res() res: Response,
  ) {
    const user =
      await this.authService.requireUserFromAuthorization(authorization);
    const csv = await this.adminService.exportToCsv(user.id, query);
    const filename = `cbhi_${query.type ?? 'export'}_${new Date().toISOString().split('T')[0]}.csv`;
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csv);
  }
}
