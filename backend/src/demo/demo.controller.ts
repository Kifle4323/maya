import { Controller, Get, Post, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Public } from '../common/decorators/public.decorator';
import { Payment } from '../payments/payment.entity';
import { Coverage } from '../coverages/coverage.entity';
import { Household } from '../households/household.entity';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { PaymentStatus, CoverageStatus } from '../common/enums/cbhi.enums';

/**
 * Demo controller — provides a visual payment page and demo utilities.
 * Only active when DEMO_MODE=true or NODE_ENV=development.
 */
@Controller('demo')
export class DemoController {
  constructor(
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(Coverage)
    private readonly coverageRepository: Repository<Coverage>,
    @InjectRepository(Household)
    private readonly householdRepository: Repository<Household>,
    @InjectRepository(Beneficiary)
    private readonly beneficiaryRepository: Repository<Beneficiary>,
  ) {}

  /**
   * Visual demo payment page — simulates the Chapa checkout experience.
   * Accessible at: http://localhost:3000/api/v1/demo/payment-page?txRef=xxx&amount=xxx
   */
  @Public()
  @Get('payment-page')
  async paymentPage(
    @Query('txRef') txRef: string,
    @Query('amount') amount: string,
    @Res() res: Response,
  ) {
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Maya City CBHI — Demo Payment</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #0D7A5F, #00BFA5);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .card {
      background: white;
      border-radius: 24px;
      padding: 40px;
      max-width: 420px;
      width: 100%;
      box-shadow: 0 20px 60px rgba(0,0,0,0.15);
    }
    .logo {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 32px;
    }
    .logo-icon {
      width: 48px;
      height: 48px;
      background: #0D7A5F;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-size: 24px;
    }
    .logo-text { font-size: 18px; font-weight: 700; color: #1A2E35; }
    .logo-sub { font-size: 12px; color: #5A7A84; }
    .demo-badge {
      background: #FFF3CD;
      border: 1px solid #F9A825;
      color: #856404;
      padding: 8px 16px;
      border-radius: 8px;
      font-size: 13px;
      margin-bottom: 24px;
      text-align: center;
    }
    .amount-display {
      background: #F6F9F8;
      border-radius: 16px;
      padding: 24px;
      text-align: center;
      margin-bottom: 24px;
    }
    .amount-label { font-size: 13px; color: #5A7A84; margin-bottom: 8px; }
    .amount-value { font-size: 36px; font-weight: 800; color: #0D7A5F; }
    .amount-currency { font-size: 16px; color: #5A7A84; }
    .txref { font-size: 12px; color: #5A7A84; margin-top: 8px; }
    .methods {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 24px;
    }
    .method {
      border: 2px solid #E8F0EE;
      border-radius: 12px;
      padding: 16px 12px;
      text-align: center;
      cursor: pointer;
      transition: all 0.2s;
      font-size: 13px;
      font-weight: 600;
      color: #1A2E35;
    }
    .method:hover, .method.selected {
      border-color: #0D7A5F;
      background: #F0FAF7;
      color: #0D7A5F;
    }
    .method-icon { font-size: 24px; margin-bottom: 6px; }
    .pay-btn {
      width: 100%;
      padding: 18px;
      background: #0D7A5F;
      color: white;
      border: none;
      border-radius: 16px;
      font-size: 16px;
      font-weight: 700;
      cursor: pointer;
      transition: background 0.2s;
    }
    .pay-btn:hover { background: #065A45; }
    .pay-btn:disabled { background: #ccc; cursor: not-allowed; }
    .success-state {
      display: none;
      text-align: center;
      padding: 20px 0;
    }
    .success-icon { font-size: 64px; margin-bottom: 16px; }
    .success-title { font-size: 22px; font-weight: 700; color: #2E7D52; margin-bottom: 8px; }
    .success-sub { color: #5A7A84; font-size: 14px; margin-bottom: 24px; }
    .back-btn {
      display: inline-block;
      padding: 12px 24px;
      background: #0D7A5F;
      color: white;
      border-radius: 12px;
      text-decoration: none;
      font-weight: 600;
      font-size: 14px;
    }
    .spinner { display: none; }
    .loading .spinner { display: inline-block; }
    .loading .btn-text { display: none; }
    @keyframes spin { to { transform: rotate(360deg); } }
    .spinner { width: 20px; height: 20px; border: 3px solid rgba(255,255,255,0.3); border-top-color: white; border-radius: 50%; animation: spin 0.8s linear infinite; display: inline-block; vertical-align: middle; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">
      <div class="logo-icon">🏥</div>
      <div>
        <div class="logo-text">Maya City CBHI</div>
        <div class="logo-sub">Community Health Insurance</div>
      </div>
    </div>

    <div class="demo-badge">
      🧪 Demo Sandbox — No real money charged
    </div>

    <div id="payment-form">
      <div class="amount-display">
        <div class="amount-label">Premium Amount</div>
        <div class="amount-value">${amount || '120'} <span class="amount-currency">ETB</span></div>
        <div class="txref">Ref: ${txRef || 'DEMO-TXN'}</div>
      </div>

      <div style="font-size: 13px; font-weight: 600; color: #1A2E35; margin-bottom: 12px;">
        Select Payment Method
      </div>

      <div class="methods">
        <div class="method selected" onclick="selectMethod(this, 'telebirr')">
          <div class="method-icon">📱</div>
          Telebirr
        </div>
        <div class="method" onclick="selectMethod(this, 'cbe_birr')">
          <div class="method-icon">🏦</div>
          CBE Birr
        </div>
        <div class="method" onclick="selectMethod(this, 'amole')">
          <div class="method-icon">💳</div>
          Amole
        </div>
        <div class="method" onclick="selectMethod(this, 'hellocash')">
          <div class="method-icon">💰</div>
          HelloCash
        </div>
      </div>

      <button class="pay-btn" id="pay-btn" onclick="processPayment()">
        <span class="spinner"></span>
        <span class="btn-text">Pay ${amount || '120'} ETB</span>
      </button>
    </div>

    <div class="success-state" id="success-state">
      <div class="success-icon">✅</div>
      <div class="success-title">Payment Successful!</div>
      <div class="success-sub">
        Your CBHI coverage has been renewed.<br>
        Transaction: ${txRef || 'DEMO-TXN'}
      </div>
      <a href="javascript:window.close()" class="back-btn">Return to App</a>
    </div>
  </div>

  <script>
    let selectedMethod = 'telebirr';

    function selectMethod(el, method) {
      document.querySelectorAll('.method').forEach(m => m.classList.remove('selected'));
      el.classList.add('selected');
      selectedMethod = method;
    }

    async function processPayment() {
      const btn = document.getElementById('pay-btn');
      btn.disabled = true;
      btn.classList.add('loading');

      // Simulate payment processing delay
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Call verify endpoint to activate coverage
      try {
        await fetch('/api/v1/payments/verify/${txRef}', {
          headers: { 'Content-Type': 'application/json' }
        });
      } catch(e) {
        // Ignore — demo mode auto-succeeds
      }

      document.getElementById('payment-form').style.display = 'none';
      document.getElementById('success-state').style.display = 'block';
    }
  </script>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  }

  /**
   * Demo status endpoint — shows what's configured vs demo mode
   */
  @Public()
  @Get('status')
  demoStatus() {
    const isDemoMode =
      process.env.DEMO_MODE === 'true' ||
      process.env.NODE_ENV === 'development';

    return {
      demoMode: isDemoMode,
      environment: process.env.NODE_ENV ?? 'development',
      services: {
        sms: process.env.AT_API_KEY ? 'live (Africa\'s Talking)' : 'demo (console log)',
        payment: process.env.CHAPA_SECRET_KEY ? 'live (Chapa)' : 'demo (auto-success)',
        vision: process.env.GOOGLE_VISION_API_KEY ? 'live (Google Vision)' : 'demo (simulated)',
        storage: process.env.GCS_BUCKET ? 'live (Google Cloud Storage)' : 'demo (local disk)',
        fcm: process.env.FCM_PROJECT_ID ? 'live (Firebase FCM)' : 'demo (console log)',
        fayda: process.env.NATIONAL_ID_API_KEY ? 'live (Fayda)' : 'demo (simulated)',
        openimis: process.env.OPENIMIS_BASE_URL ? 'live (openIMIS)' : 'demo (simulated)',
      },
      demoCredentials: isDemoMode ? {
        testPhone: '+251912345678',
        testEmail: 'demo@cbhi.et',
        note: 'OTP codes are shown in server console and returned as debugCode in API responses',
        paymentNote: 'Payments auto-succeed in demo mode. Visit the checkout URL to see the demo payment page.',
      } : null,
    };
  }
}
