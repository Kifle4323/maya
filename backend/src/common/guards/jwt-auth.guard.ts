import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { AuthService } from '../../auth/auth.service';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly authService: AuthService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Allow routes decorated with @Public()
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) {
      // Still try to attach user from JWT if present, so @CurrentUser() works
      const request = context.switchToHttp().getRequest<Request>();
      const authorization = request.headers['authorization'];
      if (authorization) {
        try {
          const user = await this.authService.requireUserFromAuthorization(authorization);
          (request as Request & { user: typeof user }).user = user;
        } catch {
          // Invalid token on a public route — just proceed without user
        }
      }
      return true;
    }

    // Always allow health check endpoint (any path prefix)
    const request = context.switchToHttp().getRequest<Request>();
    if (request.path.endsWith('/health')) {
      return true;
    }

    const authorization = request.headers['authorization'];

    if (!authorization) {
      throw new UnauthorizedException('Missing bearer token.');
    }

    // Attach user to request so controllers can access it via @CurrentUser()
    const user = await this.authService.requireUserFromAuthorization(authorization);
    (request as Request & { user: typeof user }).user = user;
    return true;
  }
}
