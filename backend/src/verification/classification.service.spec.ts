import { Test } from '@nestjs/testing';
import { ClassificationService } from './classification.service';
import { ParsingService } from './parsing.service';

describe('ClassificationService', () => {
  let service: ClassificationService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [ClassificationService, ParsingService],
    }).compile();
    service = module.get(ClassificationService);
  });

  it('classifies income certificate', () => {
    const r = service.classifyIndigentDocument(
      'KEBELE ADMINISTRATION OFFICE\nINCOME CERTIFICATE\nMonthly earnings below 1000 ETB',
    );
    expect(r.documentType).toBe('INCOME_CERTIFICATE');
    expect(r.confidence).toBeGreaterThan(0);
    expect(r.keywords.length).toBeGreaterThan(0);
  });

  it('classifies poverty certificate', () => {
    const r = service.classifyIndigentDocument(
      'SOCIAL WELFARE OFFICE\nPOVERTY CERTIFICATE\nThis certifies the bearer is indigent and needy',
    );
    expect(r.documentType).toBe('POVERTY_CERTIFICATE');
  });

  it('classifies kebele ID', () => {
    const r = service.classifyIndigentDocument(
      'KEBELE WOREDA RESIDENT IDENTIFICATION\nResidence certificate',
    );
    expect(r.documentType).toBe('KEBELE_ID');
  });

  it('classifies disability certificate', () => {
    const r = service.classifyIndigentDocument(
      'DISABILITY CERTIFICATE\nThe bearer has a physical impairment',
    );
    expect(r.documentType).toBe('DISABILITY_CERTIFICATE');
  });

  it('returns UNKNOWN for unrecognized document', () => {
    const r = service.classifyIndigentDocument('BANK STATEMENT\nAccount balance: 5000 ETB');
    expect(r.documentType).toBe('UNKNOWN');
    expect(r.confidence).toBe(0);
  });

  it('detects official stamp keywords', () => {
    const r = service.classifyIndigentDocument(
      'INCOME CERTIFICATE\nAuthorized by Director\nOfficial Stamp',
    );
    expect(r.hasOfficialStamp).toBe(true);
  });

  it('detects issuing authority', () => {
    const r = service.classifyIndigentDocument(
      'Kebele Administration Office\nINCOME CERTIFICATE\nMonthly salary below 1000 ETB',
    );
    expect(r.issuingAuthority).not.toBeNull();
  });

  it('detects Amharic keywords', () => {
    const r = service.classifyIndigentDocument('ቀበሌ ወረዳ RESIDENT IDENTIFICATION');
    expect(r.documentType).toBe('KEBELE_ID');
  });
});
