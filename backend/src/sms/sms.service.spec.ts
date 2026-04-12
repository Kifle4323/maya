import { Test } from '@nestjs/testing';
import { SmsService } from './sms.service';

describe('SmsService', () => {
  let service: SmsService;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [SmsService],
    }).compile();

    service = moduleRef.get(SmsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('logs to console in dev when API key is not set', async () => {
    const logSpy = jest.spyOn(service['logger'], 'warn');
    // No API key set in test env
    await service.sendOtp('+251912345678', '123456');
    expect(logSpy).toHaveBeenCalledWith(
      expect.stringContaining('[DEV SMS]'),
    );
  });
});
