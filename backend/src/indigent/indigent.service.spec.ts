import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  IndigentApplicationStatus,
  IndigentEmploymentStatus,
} from '../common/enums/cbhi.enums';
import { IndigentApplication } from './indigent.entity';
import { IndigentService } from './indigent.service';

describe('IndigentService', () => {
  let service: IndigentService;
  const repositoryMock = {
    create: jest.fn((value: Partial<IndigentApplication>) => value as IndigentApplication),
    save: jest.fn((value: Partial<IndigentApplication>) =>
      Promise.resolve(value as IndigentApplication),
    ),
    findOne: jest.fn(),
  };

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        IndigentService,
        {
          provide: getRepositoryToken(IndigentApplication),
          useValue: repositoryMock as unknown as Partial<
            Repository<IndigentApplication>
          >,
        },
      ],
    }).compile();

    service = moduleRef.get(IndigentService);
    jest.clearAllMocks();
  });

  it('approves applications that reach the threshold', () => {
    const decision = service.evaluateIndigentApplication({
      userId: 'user-1',
      income: 500,
      employmentStatus: IndigentEmploymentStatus.UNEMPLOYED,
      familySize: 6,
      hasProperty: false,
      disabilityStatus: true,
      documents: ['https://example.com/doc1.pdf'],
    });

    expect(decision).toEqual({
      score: 110,
      status: IndigentApplicationStatus.APPROVED,
      reason:
        'Approved: low income, unemployed, high family size, no property, disability',
    });
  });

  it('rejects applications below the threshold', () => {
    const decision = service.evaluateIndigentApplication({
      userId: 'user-2',
      income: 2000,
      employmentStatus: IndigentEmploymentStatus.EMPLOYED,
      familySize: 3,
      hasProperty: true,
      disabilityStatus: false,
      documents: ['https://example.com/doc2.pdf'],
    });

    expect(decision).toEqual({
      score: 0,
      status: IndigentApplicationStatus.REJECTED,
      reason: 'Does not meet indigent criteria',
    });
  });
});
