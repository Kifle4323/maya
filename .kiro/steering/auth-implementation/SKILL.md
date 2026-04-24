---
inclusion: manual
name: auth-implementation
description: Expert guidance for implementing secure authentication systems including OAuth 2.0, SAML, OIDC, JWT, passwordless authentication, passkeys, and biometrics. Covers protocol selection, security best practices, common pitfalls at scale, and enterprise patterns. Use when implementing login flows, SSO, API authentication, machine identity, or any identity management features.
---

# Auth Implementation

Expert guidance for implementing production-grade authentication systems based on patterns proven at billion-user scale. This skill helps you choose the right authentication approach, implement it securely, and avoid common pitfalls that cause security vulnerabilities or scale issues.

## When to Use This Skill

Use this skill when you need to:
- Implement user authentication (login, signup, password reset)
- Add Single Sign-On (SSO) capabilities
- Secure APIs with proper authentication
- Migrate from passwords to passwordless authentication
- Implement machine identity for AI agents or services
- Design multi-tenant authentication architecture
- Handle session management and token lifecycle
- Meet enterprise security and compliance requirements

## Protocol Selection Framework

### Decision Matrix

Choose your authentication protocol based on these factors:

**OAuth 2.0 + OIDC (OpenID Connect)**
- **Use when**: Third-party integrations, social login, mobile apps, microservices
- **Best for**: Consumer applications, delegated authorization, API access
- **Complexity**: Medium to High
- **Scale characteristics**: Excellent (stateless with JWT)
- **Common flows**: Authorization Code, PKCE, Client Credentials

**SAML 2.0**
- **Use when**: Enterprise B2B integrations, existing IdP infrastructure
- **Best for**: Enterprise SSO, compliance requirements, legacy systems
- **Complexity**: High
- **Scale characteristics**: Good (but XML parsing overhead)
- **Common patterns**: SP-initiated, IdP-initiated flows

**JWT (JSON Web Tokens)**
- **Use when**: Stateless authentication, microservices, mobile/SPA apps
- **Best for**: API authentication, distributed systems
- **Complexity**: Low to Medium
- **Scale characteristics**: Excellent (no database lookups)
- **Critical**: Proper signing, validation, and expiration handling

**Passwordless (Magic Links, OTP)**
- **Use when**: Improving UX, reducing password fatigue
- **Best for**: Consumer apps, low-friction experiences
- **Complexity**: Medium
- **Scale characteristics**: Very Good (fewer credential databases)
- **Consider**: Email/SMS delivery reliability

**Passkeys (WebAuthn/FIDO2)**
- **Use when**: Maximum security with great UX
- **Best for**: High-security applications, modern browsers
- **Complexity**: Medium to High
- **Scale characteristics**: Excellent (public-key cryptography)
- **Adoption**: Growing rapidly, becoming standard

**API Keys**
- **Use when**: Simple service-to-service authentication
- **Best for**: Internal services, development tools
- **Complexity**: Low
- **Scale characteristics**: Good (but rotation challenges)
- **Warning**: NOT suitable for user authentication or long-term secrets

### Anti-Pattern Alert: Wrong Protocol Choices

**DON'T use Basic Auth for production APIs** - Credentials in every request, no rotation, poor security posture

**DON'T use API keys for user authentication** - No scope control, difficult rotation, creates exponential security debt at scale

**DON'T force human identity patterns on machine identities** - AI agents need service accounts, not user accounts with passwords

**DON'T implement custom crypto** - Use battle-tested libraries and protocols

## CBHI Project Context

This skill is installed for the **Maya City CBHI** platform. The relevant auth patterns for this project are:

### Current Auth Stack
- **Flutter** frontend (mobile + web) using `flutter_bloc` Cubit pattern
- **NestJS** backend with JWT (`@nestjs/jwt`), OTP via SMS (Africa's Talking), TOTP (2FA)
- **Auth flows**: OTP login, password login, family member login, biometric login
- **Session**: JWT access tokens stored via `flutter_secure_storage`

### Applicable Patterns for CBHI
1. **OTP/Passwordless** — already in use via SMS OTP; apply rate limiting and token hashing best practices
2. **JWT** — already in use; ensure RS256, short expiry, proper validation
3. **Session Management** — sliding expiration, revoke-all on password change
4. **Biometric** — local_auth v2 with stored token; follow secure storage patterns
5. **Registration Flow** — multi-step wizard; apply progressive disclosure and inline validation

### Key Security Gaps to Address
- OTP tokens should be hashed in storage (not plaintext)
- Rate limiting on OTP send and verify endpoints
- JWT should use RS256 (not HS256) in production
- Session revocation on password change
- Temp password flow needs secure delivery and forced rotation

## Common Security Pitfalls

### Pitfall #1: Insecure Token Storage
Store tokens in `flutter_secure_storage` (already done) — never in SharedPreferences or local storage.

### Pitfall #2: No Token Expiration or Rotation
- Access tokens: 1 hour max
- Refresh tokens: 30 days with rotation on each use
- OTP tokens: 10-15 minutes, one-time use, hashed in DB

### Pitfall #3: Missing Rate Limiting
- Login: 5 attempts per minute per IP
- OTP send: 3 per 10 minutes per phone number
- OTP verify: 5 attempts per OTP token before invalidation

### Pitfall #4: Weak Session Management
- Use cryptographically secure session IDs (`secrets.token_urlsafe(32)`)
- Sliding expiration with activity tracking
- Revoke all sessions on password change or suspicious activity

### Pitfall #5: No CSRF Protection
- For web (Vercel): use SameSite=Strict cookies or CSRF tokens on state-changing operations

## Password Security

**CRITICAL**: Never use MD5, SHA1, or plain SHA256 for passwords. Use bcrypt (cost factor 12+), scrypt, or Argon2.

For the CBHI temp password flow:
- Generate with `secrets.token_urlsafe()` or similar CSPRNG
- Force change on first login
- Hash with bcrypt before storage
- Never log or expose in API responses

## JWT Best Practices for NestJS Backend

1. **Use RS256** — asymmetric signing, public key can be shared safely
2. **Short access token TTL** — 1 hour maximum
3. **Validate all claims** — `exp`, `nbf`, `iss`, `aud`
4. **Implement token blacklist** — Redis-based for logout/revocation
5. **Rotate refresh tokens** — invalidate old token on each refresh

## OTP Security for SMS Auth

1. **Hash OTP in database** — store `SHA256(otp)`, not plaintext
2. **Short TTL** — 10 minutes maximum
3. **One-time use** — mark as used immediately on verification
4. **Rate limit** — 3 sends per 10 minutes per phone number
5. **Constant-time comparison** — prevent timing attacks

## Biometric Auth (Flutter)

The existing `BiometricService` stores the access token and retrieves it after biometric verification. Ensure:
1. Token stored in `flutter_secure_storage` (already done)
2. Token is a valid, non-expired JWT (validate before use)
3. Biometric prompt uses `localizedReason` for accessibility
4. Fallback to password if biometric fails 3 times

## Registration Security

For the multi-step CBHI registration flow:
1. **Validate each step server-side** — don't trust client-only validation
2. **Rate limit registration** — prevent bulk fake registrations
3. **Phone verification** — OTP before account creation
4. **Temp password delivery** — show once, force change, never re-send in plaintext
5. **Audit log** — record registration events with IP and timestamp

## Testing Authentication

Key test cases to implement:
- Expired tokens are rejected
- Tampered tokens are rejected
- Rate limiting triggers after threshold
- OTP cannot be reused after verification
- Session invalidated after password change
- Biometric fallback works when biometric fails

## Summary: Auth Decision Tree for CBHI

```
User Type?
├─ Household Head → OTP (SMS) or Password login → JWT session
├─ Family Member (Beneficiary) → OTP or Password + membership lookup → JWT session
├─ Returning user with biometric → Stored token retrieval → JWT session
└─ New user → Registration flow → Temp password → Force change → JWT session
```
