import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Claim } from './claim.entity';
import { ClaimAppeal, AppealStatus } from './claim-appeal.entity';
import { User } from '../users/user.entity';
import { UserRole } from '../common/enums/cbhi.enums';

@Injectable()
export class ClaimAppealService {
  constructor(
    @InjectRepository(Claim)
    private readonly claimRepository: Repository<Claim>,
    @InjectRepository(ClaimAppeal)
    private readonly appealRepository: Repository<ClaimAppeal>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  /** Member submits an appeal for a rejected claim */
  async submitAppeal(userId: string, claimId: string, reason: string) {
    const claim = await this.claimRepository.findOne({
      where: { id: claimId },
      relations: ['beneficiary', 'beneficiary.userAccount', 'household', 'household.headUser'],
    });
    if (!claim) throw new NotFoundException('Claim not found.');

    // Verify the user owns this claim
    const isOwner =
      claim.household?.headUser?.id === userId ||
      claim.beneficiary?.userAccount?.id === userId;
    if (!isOwner) throw new ForbiddenException('You can only appeal your own claims.');

    const existing = await this.appealRepository.findOne({
      where: { claim: { id: claimId }, appellant: { id: userId } },
    });
    if (existing) throw new BadRequestException('An appeal for this claim already exists.');

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found.');

    const appeal = await this.appealRepository.save(
      this.appealRepository.create({
        claim,
        appellant: user,
        reason: reason.trim(),
        status: AppealStatus.PENDING,
      }),
    );
    return this.toSummary(appeal);
  }

  /** Member views their own appeals */
  async getMyAppeals(userId: string) {
    const appeals = await this.appealRepository.find({
      where: { appellant: { id: userId } },
      relations: ['claim', 'appellant', 'reviewedBy'],
      order: { createdAt: 'DESC' },
    });
    return { appeals: appeals.map((a) => this.toSummary(a)) };
  }

  /** Admin lists all appeals */
  async getAllAppeals(adminId: string) {
    await this.assertAdminAccess(adminId);
    const appeals = await this.appealRepository.find({
      relations: ['claim', 'appellant', 'reviewedBy'],
      order: { createdAt: 'DESC' },
      take: 200,
    });
    return { appeals: appeals.map((a) => this.toSummary(a)) };
  }

  /** Admin reviews (resolves) an appeal */
  async reviewAppeal(
    adminId: string,
    appealId: string,
    dto: { status: AppealStatus; reviewNote?: string },
  ) {
    await this.assertAdminAccess(adminId);
    const appeal = await this.appealRepository.findOne({
      where: { id: appealId },
      relations: ['claim', 'appellant', 'reviewedBy'],
    });
    if (!appeal) throw new NotFoundException('Appeal not found.');

    const reviewer = await this.userRepository.findOne({ where: { id: adminId } });
    appeal.status = dto.status;
    appeal.reviewNote = dto.reviewNote?.trim() ?? null;
    appeal.reviewedBy = reviewer ?? null;
    appeal.reviewedAt = new Date();
    await this.appealRepository.save(appeal);
    return this.toSummary(appeal);
  }

  private async assertAdminAccess(userId: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user || (user.role !== UserRole.CBHI_OFFICER && user.role !== UserRole.SYSTEM_ADMIN)) {
      throw new ForbiddenException('Admin access required.');
    }
  }

  private toSummary(appeal: ClaimAppeal) {
    return {
      id: appeal.id,
      status: appeal.status,
      reason: appeal.reason,
      reviewNote: appeal.reviewNote ?? null,
      reviewedAt: appeal.reviewedAt instanceof Date
        ? appeal.reviewedAt.toISOString()
        : ((appeal.reviewedAt as unknown as string)?.toString() ?? null),
      claimId: appeal.claim?.id ?? null,
      claimNumber: (appeal.claim as Claim & { claimNumber?: string })?.claimNumber ?? null,
      appellantId: appeal.appellant?.id ?? null,
      reviewedById: appeal.reviewedBy?.id ?? null,
      createdAt: appeal.createdAt instanceof Date
        ? appeal.createdAt.toISOString()
        : ((appeal.createdAt as unknown as string)?.toString() ?? null),
    };
  }
}
