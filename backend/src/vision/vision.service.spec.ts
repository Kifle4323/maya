import { Test } from '@nestjs/testing';
import { VisionService } from './vision.service';

describe('VisionService', () => {
  let service: VisionService;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [VisionService],
    }).compile();

    service = moduleRef.get(VisionService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('returns empty result when API key is not configured', async () => {
    const result = await service.extractText('base64data');
    expect(result.fullText).toBe('');
    expect(result.confidence).toBe(0);
  });

  it('validateIdDocument returns invalid when no text extracted', async () => {
    const result = await service.validateIdDocument('base64data');
    expect(result.isValid).toBe(false);
    expect(result.issues.length).toBeGreaterThan(0);
  });

  it('validateIndigentDocument returns invalid when no text extracted', async () => {
    const result = await service.validateIndigentDocument('base64data');
    expect(result.isValid).toBe(false);
    expect(result.documentType).toBe('unknown');
  });
});
