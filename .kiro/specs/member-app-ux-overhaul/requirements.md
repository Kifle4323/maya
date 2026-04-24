# Requirements Document

## Introduction

This feature covers a comprehensive UX overhaul of the `member_based_cbhi` Flutter app (mobile + web). The overhaul addresses four interconnected problems:

1. **UI inconsistency** — several screens (notably `FamilyMemberLoginScreen`, registration steps, and some inner screens) do not apply the `AppTheme` design tokens consistently, resulting in mismatched spacing, typography, and component styles.
2. **Navigation workflow clarity** — the auth flow (Welcome → Login / Family Login / Register → Dashboard) has ambiguous entry points, unclear back-navigation semantics, and a first-login experience that is confusing for new household heads.
3. **Connectivity detection** — `BackgroundSyncService` fires sync callbacks when the device comes back online, but there is no real-time banner or indicator that tells the user they are currently offline. The `isPendingSync` flag in `AppState` reflects queued data, not live connectivity status. Web (Vercel) and mobile behave differently under `connectivity_plus`.
4. **Fragmented authentication paths** — the app has three separate login screens (household head OTP, household head password, family member login) with no unified entry point, no passkey support on web, and biometric auth that is buried in settings rather than offered proactively at login.

The app supports English (`en`), Amharic (`am`), and Afaan Oromo (`om`) locales and is deployed to both Android and Vercel (Flutter Web).

---

## Glossary

- **App**: The `member_based_cbhi` Flutter application.
- **AppTheme**: The centralized design-token class at `lib/src/theme/app_theme.dart` defining colors, spacing, radii, gradients, and `ThemeData`.
- **AppCubit**: The top-level `Cubit<AppState>` managing snapshot, locale, dark mode, and sync state.
- **AuthCubit**: The `Cubit<AuthState>` managing authentication status (`checking`, `unauthenticated`, `guest`, `authenticated`).
- **BackgroundSyncService**: The singleton at `lib/src/shared/background_sync_service.dart` that listens to `connectivity_plus` and fires callbacks when the device comes back online.
- **ConnectivityCubit**: A new `Cubit<ConnectivityState>` to be introduced by this feature, responsible for tracking real-time online/offline status.
- **ConnectivityBanner**: A persistent, animated UI widget that appears at the top of the app body when the device is offline and dismisses automatically when connectivity is restored.
- **WelcomeScreen**: The unauthenticated landing screen with Sign In and Register actions.
- **LoginScreen**: The legacy household-head login screen (replaced by `UnifiedLoginScreen`).
- **RegistrationFlow**: The multi-step registration wizard (`personalInfo → confirmation → identity → membership → indigentProof → payment → setupAccount → completed`).
- **HomeShell**: The authenticated shell with a 5-tab `NavigationBar` (Home, Family, Card, Claims, Profile).
- **DesignToken**: A named constant in `AppTheme` (color, spacing, radius, shadow, gradient).
- **ARB**: Application Resource Bundle — the localization files (`app_en.arb`, `app_am.arb`, `app_om.arb`).
- **GlassCard**: The shared card widget in `lib/src/shared/animated_widgets.dart`.
- **Household_Head**: A user with role `HOUSEHOLD_HEAD` who manages the household enrollment.
- **Beneficiary**: A family member with role `BENEFICIARY` who logs in via the same `UnifiedLoginScreen` as household heads.
- **UnifiedLoginScreen**: The single login screen for ALL users (household heads and beneficiaries), presenting PIN, passkey (web), or biometric (mobile) as the primary auth methods. No phone/email/password text fields on the main screen.
- **AdaptiveAuthMethod**: The authentication method automatically selected or offered based on platform (web vs mobile) and device capability (biometric hardware). Primary methods: `biometric` (mobile), `passkey` (web), `pin` (all platforms). OTP and password are fallback/recovery methods only.
- **BiometricAuth**: Device-local fingerprint or face authentication using `local_auth` v2, available on Android only (not web).
- **PasskeyAuth**: WebAuthn/FIDO2 passkey authentication using platform authenticators, available on Flutter Web (Vercel) via the `passkeys` package or equivalent web interop.
- **PinAuth**: 4-6 digit PIN entered via a custom numeric keypad widget. The PIN is stored as a bcrypt hash in `flutter_secure_storage` (local only, never sent to the server). Entering the correct PIN unlocks the stored JWT access token.
- **OTPAuth**: SMS one-time password authentication via Africa's Talking, used as a recovery/fallback method (e.g., "Forgot PIN / Can't sign in?" flow).
- **PasswordAuth**: Username/password authentication, available as a fallback/setup method only.
- **AuthMethodPriority**: The ordered preference for presenting auth methods: (1) Biometric (mobile) or Passkey (web) if available and enrolled, (2) PIN if set, (3) OTP as recovery fallback.

---

## Requirements

### Requirement 1: Design Token Consistency Across All Screens

**User Story:** As a member, I want every screen in the app to look and feel consistent, so that I can navigate confidently without being confused by mismatched visual styles.

#### Acceptance Criteria

1. THE App SHALL apply `AppTheme` design tokens (colors, spacing constants, border radii, and text styles) to every screen, replacing any hardcoded pixel values, hex colors, or inline `TextStyle` definitions that duplicate or contradict `AppTheme`.
2. WHEN a screen renders a card-like container, THE App SHALL use `GlassCard` or a container styled with `AppTheme.cardShadow`, `AppTheme.radiusM`, and `AppTheme.surfaceCard` background, consistent with the `DashboardScreen` pattern.
3. THE App SHALL use `AppTheme.spacingM` (16 px) as the standard horizontal and vertical page padding on all list-based screens, and `AppTheme.spacingL` (24 px) on form-based screens.
4. WHEN a screen displays a primary action button, THE App SHALL render it as a `FilledButton` with `minimumSize: Size(double.infinity, 52)` and `borderRadius: AppTheme.radiusM`, consistent with the global `filledButtonTheme`.
5. WHEN a screen displays a secondary action button, THE App SHALL render it as an `OutlinedButton` with the same size and radius constraints as the primary button.
6. THE `UnifiedLoginScreen` SHALL apply the same header info-card pattern (icon container + title + subtitle row) used in the existing `LoginScreen`'s OTP and Password tabs.
7. THE App SHALL use `AppTheme.primary` (`#0D7A5F`) as the sole primary brand color across all interactive elements (tab indicators, focused input borders, filled button backgrounds, selected navigation icons).
8. WHEN the app is in dark mode, THE App SHALL apply `AppTheme.darkTheme` tokens to all screens without any screen retaining hardcoded light-mode colors.
9. THE App SHALL use the `Outfit` font family for all text, with no fallback to system fonts on any supported platform.
10. WHEN a screen displays an empty state, THE App SHALL use the `EmptyState` widget from `animated_widgets.dart` with a relevant icon, title, and subtitle, consistent with `DashboardScreen`.

---

### Requirement 2: Registration Flow Visual Consistency

**User Story:** As a new member completing registration, I want each step of the registration wizard to look like part of the same app, so that I feel guided and confident throughout the process.

#### Acceptance Criteria

1. WHEN the `RegistrationFlow` renders any step screen, THE App SHALL display a step-progress indicator showing the current step number and total steps (e.g., "Step 2 of 7") using `AppTheme` colors.
2. THE `PersonalInfoForm` SHALL use `AppTheme.spacingL` padding, `AppTheme.radiusM` input borders, and `AppTheme.primary`-colored focus borders, consistent with the global `inputDecorationTheme`.
3. THE `IdentityVerificationScreen` SHALL display document upload areas as dashed-border containers styled with `AppTheme.primary.withValues(alpha: 0.15)` border color and `AppTheme.radiusM` radius.
4. THE `MembershipSelectionScreen` SHALL display each membership tier as a `GlassCard` with a selection indicator using `AppTheme.primary` when selected.
5. WHEN a registration step has a "Next" or "Continue" action, THE App SHALL render it as a full-width `FilledButton` pinned to the bottom of the screen with `AppTheme.spacingM` bottom padding.
6. WHEN a registration step has a "Back" action, THE App SHALL render it as a leading `IconButton` in the `AppBar` using `Icons.arrow_back_ios_new`, consistent with Material 3 conventions.
7. THE `_RegistrationCompletedView` SHALL display the success icon using `AppTheme.success` color and the temp-password card using `AppTheme.warning` color, consistent with the existing `_TempPasswordCard` widget.

---

### Requirement 3: Navigation Workflow Clarity — Auth Entry Points

**User Story:** As a first-time user arriving at the Welcome screen, I want to clearly understand which option to choose (Sign In or Register), so that I do not end up in the wrong flow.

#### Acceptance Criteria

1. THE `WelcomeScreen` SHALL display exactly two action buttons: "Sign In" and "Register". There is no "Family Login" button — all users (household heads and beneficiaries) use the same "Sign In" button.
2. THE `WelcomeScreen` SHALL display a short descriptive subtitle beneath each action button: "Sign In" for all returning members, and "Register" for new enrollees.
3. WHEN a user taps "Sign In" on `WelcomeScreen`, THE App SHALL navigate to the `UnifiedLoginScreen` using a right-to-left slide transition with a duration of 300 ms. No `loginMode` parameter is needed — the screen handles all users identically.
4. WHEN a user taps "Register" on `WelcomeScreen`, THE App SHALL call `AuthCubit.continueAsGuest()` and transition to `RegistrationFlow` without pushing a new route (the `_BootstrapScreen` handles this via `AuthStatus.guest`).
5. THE `WelcomeScreen` SHALL display the hint text `strings.t('signInHint')` only when the screen width is greater than 360 logical pixels, preventing overflow on small devices.
6. WHEN the `UnifiedLoginScreen` is displayed, THE App SHALL show the adaptive primary auth method (biometric on mobile, passkey on web, or PIN) as the default visible option for all users.
7. IF a user navigates back from `UnifiedLoginScreen` to `WelcomeScreen`, THEN THE App SHALL clear all state to prevent stale input.

---

### Requirement 4: Navigation Workflow Clarity — First Login Experience

**User Story:** As a household head logging in for the first time after registration, I want to be guided to the right starting point in the app, so that I can immediately understand my coverage status and add family members.

#### Acceptance Criteria

1. WHEN `_HomeShell` detects a first login (via the `cbhi_first_login_done` SharedPreferences key), THE App SHALL navigate to the Dashboard tab (index 0) and display a non-blocking `SnackBar` guiding the user to the Family tab to add beneficiaries, instead of the current `AlertDialog`.
2. THE first-login `SnackBar` SHALL include an action button labeled with `strings.t('goToFamily')` that sets the `NavigationBar` selected index to 1 (Family tab).
3. WHEN `_HomeShell` renders the `AppBar`, THE App SHALL display the app title and logo consistently regardless of which tab is selected.
4. WHEN the user is a `Beneficiary` (family member session), THE `HomeShell` AppBar SHALL display a `StatusBadge` with the text `strings.t('familyMemberSession')` to distinguish the session type.
5. THE `NavigationBar` SHALL use `AppTheme.primary` as the indicator color in light mode and `AppTheme.accent` in dark mode, consistent with `AppTheme.navigationBarTheme`.

---

### Requirement 5: Navigation Workflow Clarity — Back Navigation Semantics

**User Story:** As a user navigating through the app, I want the back button to always take me to a logical previous screen, so that I never feel trapped or lost.

#### Acceptance Criteria

1. WHEN the user is in `RegistrationFlow` and presses the system back button, THE App SHALL display a confirmation dialog asking whether to abandon registration, rather than silently popping the route.
2. WHEN the user confirms abandoning registration, THE App SHALL call `RegistrationCubit.reset()` and `AuthCubit.leaveGuest()` to return to `WelcomeScreen`.
3. WHEN the user is in `UnifiedLoginScreen` and presses the system back button, THE App SHALL navigate back to `WelcomeScreen` without any confirmation dialog.
4. WHEN the user is in `_HomeShell` and presses the system back button while on a non-Home tab, THE App SHALL switch to the Home tab (index 0) instead of exiting the app.
5. WHEN the user is in `_HomeShell` on the Home tab and presses the system back button, THE App SHALL display a confirmation dialog asking whether to exit the app.

---

### Requirement 6: Real-Time Connectivity Detection — ConnectivityCubit

**User Story:** As a member using the app in an area with unreliable internet, I want the app to immediately tell me when I go offline or come back online, so that I know whether my actions are being saved locally or synced to the server.

#### Acceptance Criteria

1. THE App SHALL introduce a `ConnectivityCubit` that subscribes to `Connectivity().onConnectivityChanged` and emits a `ConnectivityState` with an `isOnline` boolean and a `ConnectivityStatus` enum (`online`, `offline`, `unknown`).
2. WHEN the app starts, THE `ConnectivityCubit` SHALL call `Connectivity().checkConnectivity()` to determine the initial connectivity state before emitting any state.
3. WHEN the device transitions from online to offline, THE `ConnectivityCubit` SHALL emit `ConnectivityState(isOnline: false, status: ConnectivityStatus.offline)` within 1 second of the connectivity change event.
4. WHEN the device transitions from offline to online, THE `ConnectivityCubit` SHALL emit `ConnectivityState(isOnline: true, status: ConnectivityStatus.online)` within 1 second of the connectivity change event.
5. THE `ConnectivityCubit` SHALL be provided at the root `MultiBlocProvider` in `CbhiApp`, above `AppCubit` and `AuthCubit`, so that all screens can access it.
6. WHEN `ConnectivityCubit` emits an online state after a previous offline state, THE `ConnectivityCubit` SHALL notify `BackgroundSyncService` to trigger its existing sync listeners, replacing the current direct `Connectivity().onConnectivityChanged` subscription in `BackgroundSyncService`.
7. WHERE the app is running on web (Flutter Web / Vercel), THE `ConnectivityCubit` SHALL use `connectivity_plus` web support without any native-only conditional imports, consistent with the `vercel-web-compat.md` rules.

---

### Requirement 7: Real-Time Connectivity Detection — ConnectivityBanner Widget

**User Story:** As a member, I want to see a clear visual indicator when I am offline, so that I understand why data may not be loading or syncing.

#### Acceptance Criteria

1. THE App SHALL introduce a `ConnectivityBanner` widget that renders a full-width colored bar at the top of the app body (below the `AppBar`) when `ConnectivityCubit` emits an offline state.
2. WHEN the device is offline, THE `ConnectivityBanner` SHALL display with a `AppTheme.warning` (`#FF8F00`) background, a `Icons.cloud_off_outlined` icon, and the localized text `strings.t('youAreOffline')`.
3. WHEN the device transitions from offline to online, THE `ConnectivityBanner` SHALL briefly display a `AppTheme.success` (`#2E7D52`) background with `Icons.cloud_done_outlined` icon and `strings.t('backOnline')` text for 2 seconds before animating out.
4. THE `ConnectivityBanner` SHALL animate in with a vertical slide-down transition of 300 ms duration using `flutter_animate`, and animate out with a vertical slide-up transition of 300 ms duration.
5. THE `ConnectivityBanner` SHALL be inserted into the `_HomeShell` body as a `Column` child above the page content, so that it does not overlap the `AppBar` or `NavigationBar`.
6. THE `ConnectivityBanner` SHALL be accessible: it SHALL have a `Semantics` widget wrapping it with a `liveRegion: true` property so screen readers announce connectivity changes.
7. WHEN the device is online, THE `ConnectivityBanner` SHALL not render any widget (returns `SizedBox.shrink()`), adding zero height to the layout.
8. THE `ConnectivityBanner` text SHALL be localized: `strings.t('youAreOffline')` and `strings.t('backOnline')` SHALL have entries in all three ARB files (`app_en.arb`, `app_am.arb`, `app_om.arb`).

---

### Requirement 8: Connectivity State — AppState Alignment

**User Story:** As a developer maintaining the app, I want the connectivity state and the sync-pending state to be clearly separated, so that the UI can independently communicate "you are offline right now" versus "you have unsynced changes."

#### Acceptance Criteria

1. THE `AppState` SHALL retain the existing `isPendingSync` flag (derived from `CbhiSnapshot`) to indicate queued offline changes, separate from the real-time `ConnectivityCubit` online/offline status.
2. THE `_HomeShell` AppBar offline badge (currently shown when `isPendingSync` is true) SHALL continue to show when `isPendingSync` is true, independent of the `ConnectivityBanner`.
3. WHEN `ConnectivityCubit` emits an online state after a previous offline state, THE `AppCubit` SHALL automatically call `AppCubit.sync()` to flush any pending changes, replacing the current `BackgroundSyncService` listener pattern in `AppCubit`.
4. WHEN `AppCubit.sync()` is triggered by a connectivity restoration event, THE `AppState.isSyncing` flag SHALL be set to `true` during the sync and `false` upon completion, consistent with the existing `sync()` method behavior.
5. IF `AppCubit.sync()` fails during a connectivity-restoration sync, THEN THE `AppCubit` SHALL swallow the error silently (no user-visible error), consistent with the existing `_backgroundSync` behavior.

---

### Requirement 9: Connectivity — Web Platform Behavior

**User Story:** As a member using the app on a web browser (Vercel deployment), I want the offline/online detection to work correctly in the browser, so that I get the same connectivity feedback as on mobile.

#### Acceptance Criteria

1. WHERE the app is running on Flutter Web, THE `ConnectivityCubit` SHALL correctly interpret `ConnectivityResult.wifi` and `ConnectivityResult.ethernet` as online states, since `connectivity_plus` on web reports these results for an active browser connection.
2. WHERE the app is running on Flutter Web, THE `ConnectivityCubit` SHALL correctly interpret `ConnectivityResult.none` as an offline state.
3. WHERE the app is running on Flutter Web, THE `ConnectivityBanner` SHALL render and animate identically to the mobile behavior, using only web-safe Flutter widgets.
4. THE `ConnectivityCubit` SHALL NOT use `dart:io`, `Platform.isAndroid`, `Platform.isIOS`, or any native-only import, ensuring the file compiles cleanly for the web target under `dart2js`.
5. WHEN the app is built for Vercel with `flutter build web --release`, THE connectivity feature SHALL compile without errors and the `ConnectivityBanner` SHALL be visible in the browser when the network is disconnected.

---

### Requirement 10: Localization Coverage for New UI Strings

**User Story:** As a member who uses the app in Amharic or Afaan Oromo, I want all new UI text introduced by this overhaul to be available in my language, so that I am not presented with English fallback strings.

#### Acceptance Criteria

1. THE App SHALL add the following new localization keys to `app_en.arb`, `app_am.arb`, and `app_om.arb`: `youAreOffline`, `backOnline`, `goToFamily`, `familyMemberSession`, `signInHint`, `registerHint`, `abandonRegistrationTitle`, `abandonRegistrationMessage`, `exitAppTitle`, `exitAppMessage`, `signInWithBiometric`, `signInWithPasskey`, `signInWithPin`, `biometricPromptReason`, `passkeyNotSupported`, `biometricNotAvailable`, `authMethodTitle`, `switchAuthMethod`, `enrollBiometricTitle`, `enrollBiometricMessage`, `enrollPasskeyTitle`, `enrollPasskeyMessage`, `passkeyRegistered`, `biometricEnabled`, `authSecurityNote`, `enterPin`, `createPin`, `confirmPin`, `pinMismatch`, `pinTooShort`, `forgotPin`, `pinLocked`, `pinAttemptsRemaining`, `changePin`, `pinChanged`.
2. WHEN a new localization key is added to `app_en.arb`, THE App SHALL add a corresponding entry in `app_am.arb` and `app_om.arb` with a translated or transliterated value, not an empty string or English copy.
3. THE `CbhiLocalizations` wrapper SHALL expose all new keys via the existing `t(key)` method without requiring changes to the method signature.
4. WHEN the app locale is set to `om` (Afaan Oromo), THE `ConnectivityBanner`, `UnifiedLoginScreen`, and all new navigation hint texts SHALL render in Afaan Oromo.

---

### Requirement 11: Unified Login Screen

**User Story:** As a returning member, I want a single login screen that automatically offers me the fastest and most secure sign-in method available on my device, so that I can access my coverage information with minimal taps.

#### Acceptance Criteria

1. THE App SHALL replace `LoginScreen` and `FamilyMemberLoginScreen` with a single `UnifiedLoginScreen` that handles ALL users — both household heads and beneficiaries — identically. There is no `LoginMode` enum and no mode parameter.
2. THE `UnifiedLoginScreen` SHALL NOT display any text fields for phone number, email, password, membership ID, household code, or full name on the main login screen.
3. THE primary auth methods on `UnifiedLoginScreen` are: biometric (auto-triggered on mobile if enrolled), passkey (web), and PIN (all platforms). OTP and password are recovery/fallback methods only, accessible via "Forgot PIN / Can't sign in?".
4. WHEN the app launches on mobile and biometric is enrolled, THE `UnifiedLoginScreen` SHALL automatically trigger the biometric prompt within 500 ms of the screen becoming visible.
5. WHEN the app is on web and the user has a registered passkey, THE `UnifiedLoginScreen` SHALL offer passkey as the primary action.
6. WHEN neither biometric nor passkey is available or enrolled, THE `UnifiedLoginScreen` SHALL display the PIN entry keypad as the primary auth method.
7. THE PIN entry SHALL use a custom numeric keypad widget (no system keyboard) displaying digits 0–9, a backspace key, and a confirm key.
8. THE `UnifiedLoginScreen` SHALL display a "Forgot PIN / Can't sign in?" link at the bottom that opens a recovery flow (OTP sent to the phone number on file).
9. THE `UnifiedLoginScreen` SHALL display a single primary action button whose label adapts to the active auth method (e.g., "Sign in with Fingerprint", "Sign in with Passkey", "Confirm PIN").
10. THE `UnifiedLoginScreen` SHALL display a "Use a different method" text link below the primary button that expands an inline method picker showing all available methods for the current platform.
11. WHEN the user selects a different auth method from the inline picker, THE `UnifiedLoginScreen` SHALL update the primary UI to match the selected method without navigating to a new screen.
12. THE `UnifiedLoginScreen` SHALL apply `AppTheme` design tokens consistently: `AppTheme.spacingL` padding, `GlassCard` for the auth method container, `FilledButton` for the primary action, and `AppTheme.primary` for all interactive elements.
13. THE `UnifiedLoginScreen` SHALL display an error message inline (below the relevant widget) when authentication fails, using `AppTheme.error` color and the localized error string.
14. WHEN authentication succeeds in `UnifiedLoginScreen`, THE App SHALL navigate to `_HomeShell` by updating `AuthCubit` state to `AuthStatus.authenticated`. The app then determines the user's role (`HOUSEHOLD_HEAD` or `BENEFICIARY`) from the JWT session and shows appropriate content.
15. WHEN the user is a `Beneficiary`, THE `HomeShell` AppBar SHALL display a `StatusBadge` with the text `strings.t('familyMemberSession')` to distinguish the session type.

---

### Requirement 12: Adaptive Authentication — Biometric (Mobile)

**User Story:** As a returning member on Android, I want the app to automatically offer fingerprint or face login when I open it, so that I can sign in with a single touch instead of entering my PIN every time.

#### Acceptance Criteria

1. WHEN the app launches on Android and `BiometricService.isBiometricEnabled()` returns `true`, THE `UnifiedLoginScreen` SHALL automatically trigger the biometric prompt within 500 ms of the screen becoming visible, without requiring the user to tap a button.
2. WHEN biometric authentication succeeds, THE App SHALL call `AuthCubit.loginWithStoredToken(token)` with the token retrieved from `flutter_secure_storage`, consistent with the existing `BiometricService.authenticateAndGetToken()` flow.
3. WHEN biometric authentication fails (wrong finger, face not recognized), THE App SHALL display the biometric prompt again up to 3 times before falling back to PIN entry automatically.
4. WHEN biometric authentication is cancelled by the user (system back or cancel button), THE App SHALL dismiss the prompt and display the `UnifiedLoginScreen` with PIN entry as the active method, without auto-triggering biometric again.
5. THE `UnifiedLoginScreen` SHALL display a biometric icon button (`Icons.fingerprint` or `Icons.face`) as the primary action when biometric is available and enabled, with the label `strings.t('signInWithBiometric')`.
6. WHEN biometric is available on the device but not yet enrolled in the app, THE `UnifiedLoginScreen` SHALL NOT auto-trigger biometric; instead it SHALL show PIN entry as the primary method and display a non-intrusive banner offering to enable biometric after successful PIN login.
7. THE biometric enrollment banner SHALL navigate to the existing biometric enable flow in `ProfileScreen` when tapped, and SHALL be dismissible permanently via a "Don't ask again" action.
8. THE `BiometricService` SHALL validate that the stored token has not expired before returning it; IF the token is expired, `BiometricService.authenticateAndGetToken()` SHALL return `null` and the app SHALL fall back to PIN entry.
9. WHERE the app is running on Flutter Web, biometric auth SHALL be completely disabled: `BiometricService.isAvailable()` already returns `false` on web, and THE `UnifiedLoginScreen` SHALL not render any biometric UI elements on web.
10. THE biometric prompt reason string SHALL use `strings.t('biometricPromptReason')` for localization across en/am/om.

---

### Requirement 13: Adaptive Authentication — Passkey (Web)

**User Story:** As a returning member using the app in a web browser, I want to sign in using my device's built-in passkey (fingerprint, face, or PIN) instead of entering my app PIN, so that I can access my coverage information faster and more securely.

#### Acceptance Criteria

1. WHERE the app is running on Flutter Web (Vercel), THE `UnifiedLoginScreen` SHALL offer passkey authentication as the primary method IF the user has a registered passkey credential stored in the browser's credential manager.
2. THE App SHALL introduce a `PasskeyService` class at `lib/src/shared/passkey_service.dart` that uses conditional imports: a web implementation using `dart:js_interop` / `package:web` to call the WebAuthn `navigator.credentials.get()` API, and a stub for non-web platforms that always returns `null`.
3. WHEN the user taps "Sign in with Passkey" on the `UnifiedLoginScreen`, THE `PasskeyService` SHALL call `navigator.credentials.get()` with the user's registered credential IDs retrieved from the backend, and return the assertion response.
4. THE backend (`backend/src/auth/`) SHALL expose a new endpoint `POST /api/v1/auth/passkey/authenticate-options` that returns a WebAuthn `PublicKeyCredentialRequestOptions` JSON for the given phone number or user identifier.
5. THE backend SHALL expose a new endpoint `POST /api/v1/auth/passkey/authenticate` that verifies the WebAuthn assertion response and returns a JWT session, consistent with the existing `loginWithPassword` response shape.
6. THE App SHALL expose a new endpoint `POST /api/v1/auth/passkey/register-options` and `POST /api/v1/auth/passkey/register` for passkey enrollment, called from the `ProfileScreen` passkey management section.
7. WHEN passkey authentication succeeds, THE `CbhiRepository` SHALL call the backend `POST /api/v1/auth/passkey/authenticate` endpoint and store the returned JWT session, then emit `AuthStatus.authenticated` via `AuthCubit`.
8. WHEN passkey authentication fails (user cancels, credential not found, or verification error), THE `UnifiedLoginScreen` SHALL display an inline error and fall back to OTP as the active method.
9. THE `PasskeyService` web implementation SHALL NOT use `dart:io`, `Platform`, or any native-only import, ensuring it compiles cleanly under `dart2js` for the Vercel build, consistent with `vercel-web-compat.md` rules.
10. WHERE the app is running on Android (not web), passkey UI elements SHALL be hidden: the `UnifiedLoginScreen` SHALL not render any passkey button or mention on mobile.
11. THE `ProfileScreen` SHALL include a "Passkeys" section (web only, hidden on mobile) showing registered passkeys with the ability to add a new passkey or remove an existing one.
12. WHEN a user registers a new passkey from `ProfileScreen`, THE App SHALL call `PasskeyService.register()` which invokes `navigator.credentials.create()` with options from the backend, then sends the attestation response to `POST /api/v1/auth/passkey/register`.
13. THE passkey credential IDs SHALL be stored in the backend database associated with the user's account, not in browser local storage, so they persist across devices and browsers.

---

### Requirement 14: Adaptive Authentication — Security Hardening

**User Story:** As a CBHI system administrator, I want the authentication system to follow security best practices so that member accounts are protected against credential theft, brute force, and session hijacking.

#### Acceptance Criteria

1. THE backend `POST /api/v1/auth/otp/send` endpoint SHALL enforce rate limiting of 3 OTP send requests per phone number per 10 minutes, returning HTTP 429 with a localized error message when exceeded.
2. THE backend `POST /api/v1/auth/otp/verify` endpoint SHALL enforce a maximum of 5 failed verification attempts per OTP token; after 5 failures the token SHALL be invalidated and the user must request a new OTP.
3. OTP tokens SHALL be stored in the database as `SHA-256(otp_code)` hashes, not as plaintext, so that a database breach does not expose valid OTP codes.
4. OTP tokens SHALL expire after 10 minutes from generation; the backend SHALL reject any verification attempt against an expired token with HTTP 400.
5. THE backend SHALL use RS256 (asymmetric signing) for JWT access tokens in production (`NODE_ENV=production`); HS256 SHALL only be permitted in development/test environments.
6. JWT access tokens SHALL have a maximum TTL of 3600 seconds (1 hour); refresh tokens SHALL have a maximum TTL of 2592000 seconds (30 days).
7. WHEN a user changes their password via `ProfileScreen`, THE backend SHALL invalidate all existing JWT sessions for that user by incrementing a `tokenVersion` field on the user record, causing all previously issued tokens to fail validation.
8. THE `BiometricService` SHALL check token expiry before returning a stored token: IF `DateTime.now().isAfter(tokenExpiry)`, it SHALL return `null` and the app SHALL prompt the user to re-authenticate via OTP.
9. THE `UnifiedLoginScreen` SHALL display a security note `strings.t('authSecurityNote')` below the auth method selector informing users that their data is protected, using `AppTheme.textSecondary` color and `bodySmall` text style.
10. THE backend passkey endpoints SHALL validate the WebAuthn `rpId` against the configured domain and reject assertions with mismatched origins, preventing cross-origin credential reuse.

---

### Requirement 15: PIN Authentication

**User Story:** As a returning member, I want to sign in with a short PIN so that I can access my account quickly without waiting for an SMS or using biometrics.

#### Acceptance Criteria

1. DURING account setup (after registration completes), THE App SHALL prompt the user to create a 4-6 digit PIN via the custom numeric keypad widget before proceeding to `_HomeShell`.
2. THE PIN SHALL be stored as a bcrypt hash in `flutter_secure_storage` on the device. The raw PIN SHALL never be sent to the server or stored in plaintext.
3. WHEN the user enters their PIN on `UnifiedLoginScreen`, THE App SHALL compare the bcrypt hash of the entered PIN against the stored hash locally; IF they match, THE App SHALL unlock the stored JWT access token and call `AuthCubit.loginWithStoredToken(token)`.
4. THE PIN entry widget SHALL be a custom numeric keypad displaying digits 0–9, a backspace key, and a confirm key. No system keyboard SHALL be shown for PIN entry.
5. THE PIN SHALL be 4-6 digits in length; entering fewer than 4 digits SHALL display the error `strings.t('pinTooShort')` and prevent submission.
6. AFTER 5 consecutive wrong PIN attempts, THE App SHALL lock PIN entry, display `strings.t('pinLocked')`, and require the user to complete OTP recovery via the "Forgot PIN / Can't sign in?" flow before PIN entry is re-enabled.
7. WHILE PIN attempts remain before lockout, THE App SHALL display `strings.t('pinAttemptsRemaining')` with the remaining count after each failed attempt.
8. THE user SHALL be able to change their PIN from `ProfileScreen` by verifying their current PIN first, then entering and confirming a new PIN. On success, THE App SHALL display `strings.t('pinChanged')`.
9. WHEN the user logs out, THE App SHALL clear the stored PIN hash and JWT token from `flutter_secure_storage`, requiring a fresh PIN setup on next login.
10. THE PIN creation flow SHALL require the user to enter the PIN twice for confirmation; IF the two entries do not match, THE App SHALL display `strings.t('pinMismatch')` and clear both entries.
