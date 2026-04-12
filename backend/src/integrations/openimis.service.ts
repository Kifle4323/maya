import { Injectable, Logger } from '@nestjs/common';

/**
 * openIMIS Integration Service
 *
 * openIMIS is the national CBHI information system used by FMOH/EHIA.
 * This service syncs household registrations, coverage, and claims.
 *
 * Setup:
 *   1. Contact EHIA for openIMIS API credentials
 *   2. Set OPENIMIS_BASE_URL and OPENIMIS_API_KEY in .env
 *
 * Docs: https://openimis.atlassian.net/wiki/spaces/OP/pages/
 */
@Injectable()
export class OpenImisService {
  private readonly logger = new Logger(OpenImisService.name);
  private readonly baseUrl = process.env.OPENIMIS_BASE_URL ?? '';
  private readonly apiKey = process.env.OPENIMIS_API_KEY ?? '';

  get isConfigured(): boolean {
    return this.baseUrl.length > 0 && this.apiKey.length > 0;
  }

  /**
   * Sync a household registration to openIMIS
   */
  async syncHousehold(household: {
    householdCode: string;
    region: string;
    zone: string;
    woreda: string;
    kebele: string;
    memberCount: number;
    headName: string;
    phoneNumber?: string;
  }): Promise<boolean> {
    if (!this.isConfigured) {
      this.logger.warn('openIMIS not configured — skipping household sync');
      return false;
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/insuree/`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          chfId: household.householdCode,
          lastName: household.headName.split(' ').pop() ?? household.headName,
          otherNames: household.headName.split(' ').slice(0, -1).join(' '),
          phone: household.phoneNumber,
          currentVillage: {
            name: household.kebele,
            parent: {
              name: household.woreda,
              parent: {
                name: household.zone,
                parent: { name: household.region },
              },
            },
          },
          family: { members: household.memberCount },
        }),
      });

      if (!response.ok) {
        this.logger.error(`openIMIS household sync failed: ${response.status}`);
        return false;
      }

      this.logger.log(`Synced household ${household.householdCode} to openIMIS`);
      return true;
    } catch (error) {
      this.logger.error(`openIMIS sync exception: ${(error as Error).message}`);
      return false;
    }
  }

  /**
   * Sync a claim to openIMIS
   */
  async syncClaim(claim: {
    claimNumber: string;
    householdCode: string;
    facilityCode: string;
    serviceDate: string;
    items: Array<{ serviceName: string; quantity: number; unitPrice: number }>;
    claimedAmount: number;
  }): Promise<boolean> {
    if (!this.isConfigured) {
      this.logger.warn('openIMIS not configured — skipping claim sync');
      return false;
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/claim/`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          code: claim.claimNumber,
          insuree: { chfId: claim.householdCode },
          healthFacility: { code: claim.facilityCode },
          dateFrom: claim.serviceDate,
          dateTo: claim.serviceDate,
          claimed: claim.claimedAmount,
          items: claim.items.map((item) => ({
            item: { code: item.serviceName },
            qtyProvided: item.quantity,
            priceAsked: item.unitPrice,
          })),
        }),
      });

      if (!response.ok) {
        this.logger.error(`openIMIS claim sync failed: ${response.status}`);
        return false;
      }

      this.logger.log(`Synced claim ${claim.claimNumber} to openIMIS`);
      return true;
    } catch (error) {
      this.logger.error(`openIMIS claim sync exception: ${(error as Error).message}`);
      return false;
    }
  }
}
