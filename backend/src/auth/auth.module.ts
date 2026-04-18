import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Beneficiary } from '../beneficiaries/beneficiary.entity';
import { SmsModule } from '../sms/sms.module';
import { User } from '../users/user.entity';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Beneficiary]),
    SmsModule,
    JwtModule.registerAsync({
      useFactory: () => ({
        secret: process.env.AUTH_JWT_SECRET ?? 'maya-city-cbhi-secret',
        signOptions: {
          expiresIn: Number(process.env.AUTH_ACCESS_TOKEN_TTL_SECONDS ?? 86400),
        },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService],
  exports: [AuthService, JwtModule],
})
export class AuthModule {}
