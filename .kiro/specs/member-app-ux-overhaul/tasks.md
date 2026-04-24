# Implementation Plan: Member App UX Overhaul

## Overview

Implement the four-pillar UX overhaul for `member_based_cbhi`: (1) design-token consistency across all screens, (2) navigation workflow clarity with a unified auth entry point, (3) real-time connectivity detection with `ConnectivityCubit` and `ConnectivityBanner`, and (4) adaptive authentication (biometric on Android, passkey on web) with security hardening in the NestJS backend.

All Flutter code must compile cleanly for both Android and Flutter Web (dart2js / Vercel). All new user-facing strings must be localized in `en`, `am`, and `om`.

---

## Tasks

- [x] 1. Add localization keys for all new UI strings
  - Add all 25 new keys to `member_based_cbhi/lib/l10n/app_en.arb`: `youAreOffline`, `backOnline`, `goToFamily`, `familyMemberSession`, `signInHint`, `familyLoginHint`, `registerHint`, `abandonRegistrationTitle`, `abandonRegistrationMessage`, `exitAppTitle`, `exitAppMessage`, `signInWithBiometric`, `signInWithPasskey`, `signInWithOtp`, `signInWithPassword`, `biometricPromptReason`, `passkeyNotSupported`, `biometricNotAvailable`, `authMethodTitle`, `switchAuthMethod`, `enrollBiometricTitle`, `enrollBiometricMessage`, `enrollPasskeyTitle`, `enrollPasskeyMessage`, `passkeyRegistered`, `biometricEnabled`, `authSecurityNote`
  - Add corresponding Amharic translations to `app_am.arb` (non-empty, non-English values)
  - Add corresponding Afaan Oromo translations to `app_om.arb` (non-empty, non-English values)
  - Verify `CbhiLocalizations.t(key)` resolves all new keys without signature changes
  - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [x] 2. Implement `ConnectivityCubit` and simplify `BackgroundSyncService`
  - [x] 2.1 Create `lib/src/shared/connectivity_cubit.dart` with `ConnectivityStatus` enum, `ConnectivityState` (Equatable), and `ConnectivityCubit`
    - Implement `initialize()`: call `Connectivity().checkConnectivity()` for initial state, then subscribe to `onConnectivityChanged`
    - Implement `_emitFromResults()`: `isOnline = results.any((r) => r != ConnectivityResult.none)`
    - On offline→online transition, call `BackgroundSyncService.instance.notifyOnline()`
    - No `dart:io`, no `Platform` references — web-safe
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.7, 9.1, 9.2, 9.4_
  - [ ]* 2.2 Write property test for `ConnectivityCubit` result mapping
    - **Property 1: ConnectivityResult maps correctly to isOnline**
    - Generate random lists of `ConnectivityResult` values; assert `isOnline == results.any((r) => r != ConnectivityResult.none)`
    - **Validates: Requirements 6.1, 6.3, 6.4, 9.1, 9.2**
  - [x] 2.3 Simplify `BackgroundSyncService`: remove internal `Connectivity()` stream subscription; add `notifyOnline()` method that fires all registered callbacks
    - Keep `addListener`, `removeListener`, `start` (no-op or removed), `stop` (no-op or removed)
    - _Requirements: 6.6, 8.3_
  - [x] 2.4 Register `ConnectivityCubit` in `CbhiApp.MultiBlocProvider` above `AppCubit` and `AuthCubit`; call `cubit.initialize()` in `_BootstrapScreenState.initState`
    - _Requirements: 6.5_

- [x] 3. Implement `ConnectivityBanner` widget
  - [x] 3.1 Create `lib/src/shared/connectivity_banner.dart`
    - Use `BlocConsumer<ConnectivityCubit, ConnectivityState>` to react to state changes
    - Offline: slide-down 300 ms (`flutter_animate`), `AppTheme.warning` background, `Icons.cloud_off_outlined`, `strings.t('youAreOffline')`
    - Online-after-offline: switch to `AppTheme.success` bar, `Icons.cloud_done_outlined`, `strings.t('backOnline')`, hold 2 s, then slide-up 300 ms
    - Online (no prior offline): return `SizedBox.shrink()`
    - Wrap in `Semantics(liveRegion: true)`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.6, 7.7, 7.8_
  - [x] 3.2 Insert `ConnectivityBanner` into `_HomeShell.body` as first child of a `Column`, with `Expanded` wrapping the existing `AnimatedSwitcher`
    - _Requirements: 7.5_
  - [x] 3.3 Add `BlocListener<ConnectivityCubit, ConnectivityState>` in `_HomeShell` (inside `MultiBlocListener`) that calls `context.read<AppCubit>().sync()` when `!prev.isOnline && curr.isOnline`
    - Remove `BackgroundSyncService.instance.addListener(_backgroundSync)` from `AppCubit` constructor; remove `removeListener` from `AppCubit.close()`
    - _Requirements: 8.3, 8.4, 8.5_

- [x] 4. Checkpoint — Ensure connectivity layer compiles and tests pass
  - Run `flutter analyze` in `member_based_cbhi`; fix any dart2js-incompatible imports
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Apply `AppTheme` design-token consistency to existing screens
  - [ ] 5.1 Audit and fix `FamilyMemberLoginScreen`: apply header info-card pattern (icon container + title + subtitle), `AppTheme.spacingL` padding, `AppTheme.radiusM` input borders, `AppTheme.primary` focus borders, full-width `FilledButton`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.6, 1.7_
  - [ ] 5.2 Audit and fix `MyFamilyScreen` and `AddBeneficiaryScreen`: replace hardcoded colors/spacing with `AppTheme` tokens; use `GlassCard` for card containers; use `EmptyState` widget for empty states
    - _Requirements: 1.1, 1.2, 1.3, 1.10_
  - [ ] 5.3 Audit and fix `GrievanceScreen` and `IndigentApplicationScreen`: replace hardcoded values with `AppTheme` tokens; ensure dark-mode compatibility
    - _Requirements: 1.1, 1.7, 1.8_
  - [ ] 5.4 Audit and fix `PaymentScreen` and `DigitalCardScreen`: apply `AppTheme.spacingM`/`spacingL` padding, `AppTheme.radiusM` containers, `AppTheme.primary` interactive elements
    - _Requirements: 1.1, 1.3, 1.7_
  - [ ] 5.5 Verify `NavigationBar` uses `AppTheme.primary` as indicator color in light mode and `AppTheme.accent` in dark mode via `AppTheme.navigationBarTheme`
    - _Requirements: 4.5_

- [ ] 6. Implement `RegistrationStepIndicator` and apply to all registration steps
  - [ ] 6.1 Create `lib/src/registration/registration_step_indicator.dart`
    - Define `RegistrationStep` enum with `stepNumber` extension and `totalSteps = 7`
    - Implement `RegistrationStepIndicator` widget: `LinearProgressIndicator` (value = `stepNumber / totalSteps`) + `"Step N of 7"` label using `AppTheme.primary`
    - _Requirements: 2.1_
  - [ ]* 6.2 Write property test for `RegistrationStepIndicator`
    - **Property 2: Registration step indicator is present for every non-terminal step**
    - Enumerate all `RegistrationStep` values except `completed`; pump each step screen; assert `RegistrationStepIndicator` found with correct `stepNumber`
    - **Validates: Requirements 2.1**
  - [ ] 6.3 Insert `RegistrationStepIndicator` at the top of each step screen body in `RegistrationFlow`: `PersonalInfoForm`, `IdentityVerificationScreen`, `MembershipSelectionScreen`, indigent proof step, payment step, `SetupAccountScreen`
    - _Requirements: 2.1_
  - [ ] 6.4 Apply `AppTheme` tokens to `PersonalInfoForm`: `spacingL` padding, `radiusM` input borders, `primary`-colored focus borders
    - _Requirements: 2.2_
  - [ ] 6.5 Style `IdentityVerificationScreen` document upload areas as dashed-border containers with `AppTheme.primary.withValues(alpha: 0.15)` border and `AppTheme.radiusM` radius
    - _Requirements: 2.3_
  - [ ] 6.6 Style `MembershipSelectionScreen` tiers as `GlassCard` with `AppTheme.primary` selection indicator
    - _Requirements: 2.4_
  - [ ] 6.7 Pin "Next"/"Continue" buttons as full-width `FilledButton` at bottom with `AppTheme.spacingM` padding; add `Icons.arrow_back_ios_new` back button to each step `AppBar`
    - _Requirements: 2.5, 2.6_
  - [ ] 6.8 Verify `_RegistrationCompletedView` uses `AppTheme.success` for success icon and `AppTheme.warning` for temp-password card
    - _Requirements: 2.7_

- [ ] 7. Update `WelcomeScreen` navigation and add descriptive hints
  - [ ] 7.1 Add descriptive subtitle text beneath each action button: `strings.t('signInHint')` under Sign In, `strings.t('familyLoginHint')` under Family Login, `strings.t('registerHint')` under Register
    - Show hint text only when `MediaQuery.of(context).size.width > 360`
    - _Requirements: 3.1, 3.5_
  - [ ] 7.2 Update "Sign In" button `onPressed` to navigate to `UnifiedLoginScreen(loginMode: LoginMode.householdHead)` with a right-to-left slide transition (300 ms)
    - _Requirements: 3.2_
  - [ ] 7.3 Update "Family Login" button `onPressed` to navigate to `UnifiedLoginScreen(loginMode: LoginMode.familyMember)` with the same 300 ms slide transition
    - _Requirements: 3.3_
  - [ ] 7.4 Verify "Register" button calls `AuthCubit.continueAsGuest()` (no route push — `_BootstrapScreen` handles the transition via `AuthStatus.guest`)
    - _Requirements: 3.4_

- [ ] 8. Implement `UnifiedLoginScreen`
  - [ ] 8.1 Create `lib/src/auth/unified_login_screen.dart`
    - Define `LoginMode` enum (`householdHead`, `familyMember`) and `AdaptiveAuthMethod` enum (`biometric`, `passkey`, `otp`, `password`)
    - Scaffold with `AppBar` (back → `WelcomeScreen`, clears all `TextEditingController`s via `PopScope`)
    - `SingleChildScrollView` body with `AppTheme.spacingL` padding
    - `_AuthMethodHeader` widget (icon container + title + subtitle)
    - `GlassCard` wrapping the active auth input area (`_AuthMethodContainer`)
    - Full-width `FilledButton` with adaptive label
    - `TextButton` "Use a different method" that toggles `_MethodPicker` via `AnimatedSize`
    - Inline `_InlineError` widget using `AppTheme.error` color
    - Security note text using `AppTheme.textSecondary` / `bodySmall`
    - _Requirements: 11.1, 11.2, 11.5, 11.6, 11.7, 11.8, 11.9, 14.9_
  - [ ] 8.2 Implement `householdHead` mode: show only phone/identifier field and adaptive primary auth button; hide family lookup fields
    - _Requirements: 11.3_
  - [ ] 8.3 Implement `familyMember` mode: show family lookup section (phone, membership ID, household code, full name) above the auth method selector
    - _Requirements: 11.4, 11.7_
  - [ ]* 8.4 Write property test for `UnifiedLoginScreen` mode controlling field visibility
    - **Property 3: UnifiedLoginScreen mode controls family lookup field visibility**
    - For each `LoginMode`, pump `UnifiedLoginScreen` and assert family lookup fields present iff `mode == familyMember`
    - **Validates: Requirements 11.2, 11.3, 11.4**
  - [ ]* 8.5 Write property test for adaptive auth method button label
    - **Property 4: Adaptive auth method determines primary button label**
    - For each `AdaptiveAuthMethod`, pump `UnifiedLoginScreen` and assert `FilledButton` label matches expected localization key
    - **Validates: Requirements 11.5**
  - [ ] 8.6 Implement `_MethodPicker`: inline expandable list of all available methods for the current platform; selecting a method calls `setState(() => _activeMethod = method)` without navigation
    - Hide biometric option on web (`kIsWeb`); hide passkey option on mobile (`!kIsWeb`)
    - _Requirements: 11.6, 11.7, 12.9, 13.10_
  - [ ] 8.7 Wire `UnifiedLoginScreen` auth success to `AuthCubit`: OTP path calls `authCubit.verifyOtp()`; password path calls `authCubit.loginWithPassword()` or `authCubit.loginFamilyMemberWithPassword()`; biometric path calls `authCubit.loginWithStoredToken(token)`
    - _Requirements: 11.10_

- [ ] 9. Implement biometric auto-trigger and retry logic in `UnifiedLoginScreen`
  - [ ] 9.1 In `UnifiedLoginScreen.initState`, schedule a 500 ms delayed call to `_triggerBiometric()` when `!kIsWeb && await BiometricService.isBiometricEnabled()`
    - _Requirements: 12.1_
  - [ ] 9.2 Implement `_triggerBiometric()`: call `BiometricService.authenticateAndGetToken()`; on success call `authCubit.loginWithStoredToken(token)`; on failure increment `_biometricAttempts`; retry up to 3 times; on 3rd failure `setState(() => _activeMethod = AdaptiveAuthMethod.otp)`; on user cancel (null token, attempts == 0) switch to OTP without retry
    - _Requirements: 12.2, 12.3, 12.4_
  - [ ]* 9.3 Write property test for biometric retry counter
    - **Property 5: Biometric retry counter falls back to OTP at exactly 3 failures**
    - Simulate `n` biometric failures (1 ≤ n ≤ 3); assert active method is `biometric` for `n < 3` and `otp` for `n == 3`
    - **Validates: Requirements 12.3**
  - [ ] 9.4 When biometric is available but not enrolled, show OTP as primary method and display a non-intrusive enrollment banner offering to enable biometric after successful OTP login; banner navigates to `ProfileScreen` biometric section; banner is permanently dismissible
    - _Requirements: 12.6, 12.7_
  - [ ] 9.5 Render biometric primary button with `Icons.fingerprint` / `Icons.face` icon and `strings.t('signInWithBiometric')` label when biometric is the active method
    - _Requirements: 12.5, 12.10_

- [ ] 10. Enhance `BiometricService` with token expiry validation
  - Update `BiometricService.authenticateAndGetToken()` to read `cbhi_biometric_token_expiry` from `SecureStorageService`; if expiry is in the past, call `disableBiometric()` and return `null`
  - Update `BiometricService.enableBiometric()` to accept `tokenExpiry: DateTime` and store it under `cbhi_biometric_token_expiry`
  - Update callers in `ProfileScreen` biometric enable flow to pass the token expiry from the session
  - _Requirements: 12.8, 14.8_
  - [ ]* 10.1 Write property test for `BiometricService` expired token
    - **Property 10: BiometricService returns null for expired stored tokens**
    - Generate random past `DateTime` values; store as token expiry; assert `authenticateAndGetToken()` returns null without triggering biometric prompt
    - **Validates: Requirements 14.8**

- [ ] 11. Checkpoint — Ensure Flutter auth layer compiles and tests pass
  - Run `flutter analyze`; verify no dart2js-incompatible imports in any new file
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Implement `PasskeyService` with conditional imports (web only)
  - [ ] 12.1 Create `lib/src/shared/passkey_stub.dart`: stub implementations returning `false`/`null` for all methods; no `dart:io` or `Platform` references
    - _Requirements: 13.9, 13.10_
  - [ ] 12.2 Create `lib/src/shared/passkey_web.dart`: web implementation using `dart:js_interop` and `package:web` to call `navigator.credentials.get()` and `navigator.credentials.create()`; define `PasskeyAssertion` and `PasskeyAttestation` data classes
    - No `dart:io`, no `Platform` references
    - _Requirements: 13.2, 13.3, 13.9_
  - [ ] 12.3 Create `lib/src/shared/passkey_service.dart`: conditional import dispatcher (`passkey_stub.dart` if `dart.library.js_interop` is absent, `passkey_web.dart` otherwise); expose `isAvailable()`, `authenticate()`, `register()` static methods
    - _Requirements: 13.2_
  - [ ] 12.4 Add passkey authentication flow to `UnifiedLoginScreen` (web only): on init call `PasskeyService.isAvailable()`; if available and user has credentials, set `_activeMethod = AdaptiveAuthMethod.passkey`; primary button calls `PasskeyService.authenticate()` then `CbhiRepository.authenticateWithPasskey()`; on failure/cancel fall back to OTP with inline error
    - _Requirements: 13.1, 13.7, 13.8_
  - [ ] 12.5 Add `CbhiRepository` methods: `getPasskeyAuthenticateOptions(identifier)`, `authenticateWithPasskey(dto)`, `getPasskeyRegisterOptions()`, `registerPasskey(dto)`, `removePasskey(credentialId)`
    - _Requirements: 13.3, 13.7, 13.12_

- [ ] 13. Add Passkeys section to `ProfileScreen` (web only)
  - Add a "Passkeys" section visible only when `kIsWeb`; list registered passkeys fetched from backend; provide "Add passkey" button that calls `PasskeyService.register()` then `CbhiRepository.registerPasskey()`; provide delete button per credential that calls `CbhiRepository.removePasskey(credentialId)`
  - _Requirements: 13.11, 13.12, 13.13_

- [ ] 14. Backend: add security-hardening columns to `User` entity and create migration
  - [ ] 14.1 Add columns to `backend/src/users/user.entity.ts`: `tokenVersion: number` (default 0), `otpFailCount: number` (default 0, select: false), `otpRateLimitCount: number` (default 0, select: false), `otpRateLimitWindowStart: Date | null` (select: false)
    - _Requirements: 14.1, 14.2, 14.7_
  - [ ] 14.2 Create TypeORM migration `backend/src/database/migrations/<timestamp>-PasskeyAndSecurityHardening.ts`
    - `ALTER TABLE users ADD COLUMN token_version INT NOT NULL DEFAULT 0`
    - `ALTER TABLE users ADD COLUMN otp_fail_count INT NOT NULL DEFAULT 0`
    - `ALTER TABLE users ADD COLUMN otp_rate_limit_count INT NOT NULL DEFAULT 0`
    - `ALTER TABLE users ADD COLUMN otp_rate_limit_window_start TIMESTAMPTZ`
    - `CREATE TABLE passkey_credentials (...)` per `PasskeyCredential` entity schema
    - _Requirements: 14.1, 14.2_

- [ ] 15. Backend: create `PasskeyCredential` entity and `PasskeyService`
  - [ ] 15.1 Create `backend/src/auth/passkey-credential.entity.ts`: `PasskeyCredential` entity with `credentialId`, `publicKey`, `signCount`, `rpId`, `deviceName`, `lastUsedAt`, `ManyToOne` to `User`
    - _Requirements: 13.13_
  - [ ] 15.2 Create `backend/src/auth/passkey.service.ts`: implement `getRegisterOptions()`, `verifyAndStoreAttestation()`, `getAuthenticateOptions()`, `verifyAssertion()`
    - Security validation: verify `clientDataJSON.origin` vs `PASSKEY_RP_ORIGIN` env var; verify `rpIdHash` vs `SHA-256(PASSKEY_RP_ID)`; verify `signCount > credential.signCount` (replay prevention); verify ECDSA P-256 signature; update `signCount` and `lastUsedAt` on success
    - _Requirements: 13.4, 13.5, 13.13, 14.10_

- [ ] 16. Backend: create `PasskeyController` and wire into `AuthModule`
  - [ ] 16.1 Create `backend/src/auth/passkey.controller.ts` with endpoints: `POST register-options`, `POST register`, `POST authenticate-options` (`@Public()`), `POST authenticate` (`@Public()`), `DELETE :credentialId`
    - Define DTOs: `PasskeyRegisterDto`, `PasskeyAuthOptionsDto`, `PasskeyAuthenticateDto`
    - _Requirements: 13.4, 13.5, 13.6_
  - [ ] 16.2 Add `PasskeyCredential` to `TypeOrmModule.forFeature` in `AuthModule`; add `PasskeyController` and `PasskeyService` to `AuthModule` providers/controllers
    - _Requirements: 13.4, 13.5_

- [ ] 17. Backend: harden `AuthService` — OTP rate limiting, fail counter, token expiry, and `tokenVersion`
  - [ ] 17.1 Implement OTP rate limiting in `AuthService.sendOtp()`: check `otpRateLimitWindowStart`; if within 10-minute window and `otpRateLimitCount >= 3`, throw `TooManyRequestsException` (HTTP 429); otherwise increment counter or reset window
    - _Requirements: 14.1_
  - [ ] 17.2 Write property test for OTP rate limiting
    - **Property 6: OTP rate limiting rejects requests beyond the threshold**
    - For random phone numbers, call `sendOtp` 3 times (should succeed), then 4th call asserts HTTP 429
    - **Validates: Requirements 14.1**
  - [ ] 17.3 Implement OTP fail counter in `AuthService.verifyOtp()`: on wrong code increment `otpFailCount`; when `otpFailCount >= 5` call `clearOtp()` and throw `UnauthorizedException` with "Too many failed attempts" message; reset counter on successful verification
    - _Requirements: 14.2_
  - [ ]* 17.4 Write property test for OTP invalidation after 5 failures
    - **Property 7: OTP token is invalidated after 5 failed verification attempts**
    - Simulate 5 wrong-code verifications; assert 6th attempt with correct code also fails
    - **Validates: Requirements 14.2**
  - [ ] 17.5 Extend OTP expiry from 5 minutes to 10 minutes in `AuthService.sendOtp()` (`Date.now() + 10 * 60 * 1000`); verify `assertOtp()` rejects expired tokens with HTTP 400
    - _Requirements: 14.4_
  - [ ]* 17.6 Write property test for OTP hash storage
    - **Property 8: OTP codes are stored as SHA-256 hashes, never as plaintext**
    - Generate random OTP codes and purposes; assert `hashValue(purpose + ":" + code) !== code` and stored hash equals `SHA-256(purpose + ":" + code)`
    - **Validates: Requirements 14.3**
  - [ ] 17.7 Implement `tokenVersion` invalidation in `AuthService`: increment `user.tokenVersion` in `resetPassword()` and `setPassword()`; add `tokenVersion` claim to JWT payload in `issueSession()`; validate `tokenVersion` in `requireUserFromAuthorization()` by comparing JWT claim to current DB value
    - _Requirements: 14.7_
  - [ ] 17.8 Write property test for `tokenVersion` session invalidation
    - **Property 9: Password change invalidates all prior sessions via tokenVersion**
    - For random users with active JWTs, after `resetPassword`, assert `tokenVersion` incremented and old JWT fails `requireUserFromAuthorization`
    - **Validates: Requirements 14.7**

- [ ] 18. Backend: configure RS256 JWT signing for production
  - Update `AuthModule` `JwtModule.registerAsync` to use `RS256` algorithm and load RSA private/public key from `AUTH_JWT_PRIVATE_KEY` / `AUTH_JWT_PUBLIC_KEY` env vars when `NODE_ENV === 'production'`; fall back to HS256 + `AUTH_JWT_SECRET` in development/test
  - Update `AuthService.requireUserFromAuthorization()` to use the correct verification key based on environment
  - Document required env vars in `backend/.env.example`
  - _Requirements: 14.5_

- [ ] 19. Checkpoint — Ensure backend compiles and all backend tests pass
  - Run `npm run build` in `backend`; run `npm test`
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 20. Update `_HomeShell` first-login experience and back-navigation semantics
  - [ ] 20.1 Replace `_showOnboarding()` `AlertDialog` with a `SnackBar`: navigate to Dashboard tab (index 0) on first login; show `SnackBar` with `strings.t('goToFamily')` action button that sets `_index = 1`
    - _Requirements: 4.1, 4.2_
  - [ ] 20.2 Add `StatusBadge` to `_HomeShell` `AppBar` when the authenticated user has role `BENEFICIARY`: display `strings.t('familyMemberSession')` text
    - _Requirements: 4.4_
  - [ ] 20.3 Wrap `_HomeShell` in `PopScope(canPop: false, onPopInvokedWithResult: ...)`: if `_index != 0`, switch to index 0; if `_index == 0`, show exit confirmation dialog using `strings.t('exitAppTitle')` / `strings.t('exitAppMessage')`
    - _Requirements: 5.4, 5.5_
  - [ ] 20.4 Wrap `RegistrationFlow` in `PopScope(canPop: false, onPopInvokedWithResult: ...)`: show confirmation dialog using `strings.t('abandonRegistrationTitle')` / `strings.t('abandonRegistrationMessage')`; on confirm call `RegistrationCubit.reset()` and `AuthCubit.leaveGuest()`
    - _Requirements: 5.1, 5.2_

- [ ] 21. Final integration wiring and cleanup
  - [ ] 21.1 Remove `LoginScreen` and `FamilyMemberLoginScreen` files (or mark as deprecated); update all navigation references to use `UnifiedLoginScreen`
    - _Requirements: 11.1_
  - [ ] 21.2 Verify `WelcomeScreen` back navigation from `UnifiedLoginScreen` clears all `TextEditingController`s (handled by `PopScope` in `UnifiedLoginScreen`)
    - _Requirements: 3.8_
  - [ ] 21.3 Verify `ConnectivityBanner` renders and animates identically on web (Vercel) and mobile; run `flutter build web --release` to confirm no dart2js compilation errors
    - _Requirements: 9.3, 9.5_
  - [ ] 21.4 Run localization smoke test: assert all 25 new ARB keys exist in `app_en.arb`, `app_am.arb`, and `app_om.arb` with non-empty values in `am` and `om`
    - _Requirements: 10.1, 10.2_

- [ ] 22. Final checkpoint — Ensure all tests pass
  - Run `flutter analyze` and `flutter test` in `member_based_cbhi`
  - Run `npm run build` and `npm test` in `backend`
  - Ensure all tests pass, ask the user if questions arise.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- All Flutter files must use conditional imports for any native-only API (follow `vercel-web-compat.md`)
- `ConnectivityCubit` must be provided above `AppCubit` in `MultiBlocProvider` so `_HomeShell` can listen to both
- The `passkey_web.dart` implementation requires `dart:js_interop` — ensure `package:web` is added to `pubspec.yaml` if not already present
- Backend RS256 keys must be generated and stored as env vars before deploying to production; HS256 remains valid for local development
- Property tests are tagged with `// Feature: member-app-ux-overhaul, Property N: ...` comments for traceability
