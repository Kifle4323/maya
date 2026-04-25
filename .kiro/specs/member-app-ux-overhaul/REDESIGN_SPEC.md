# Maya City CBHI — Full UI/UX Redesign Specification v2.0

## Executive Summary

The current platform is **functionally complete but visually inconsistent**. The member app has strong bones — AppTheme tokens, flutter_animate, BLoC/Cubit — but suffers from three systemic problems:

1. **Surface hierarchy collapse**: GlassCard, MetricCard, and raw Containers are used interchangeably with no elevation logic. Cards look identical regardless of importance.
2. **State coverage gaps**: Loading/empty/error states exist but are inconsistent — some screens show CircularProgressIndicator inline, others show nothing. The dashboard has no skeleton loading.
3. **Information density mismatch**: The dashboard hero card is visually strong but the 2×2 MetricCard grid below it is flat and low-contrast. The most important data (coverage status, expiry) is not the most visually prominent.

Benchmarked against **Oscar Health** (insurance card UX), **Monzo** (transaction feeds, status communication), and **M-Pesa** (offline resilience, low-literacy patterns), the platform is at ~60% of premium standard. This spec closes that gap.

---

## Constraint Matrix

### Member App — Dashboard

| Issue | Widget/Location | Severity |
|-------|----------------|----------|
| MetricCard grid is visually flat — no elevation differentiation | `_QuickStatsRow` | High |
| `annualCeiling=0` hardcoded in BenefitUtilizationWidget | `_BenefitUtilizationSection` | Critical |
| No skeleton loading — raw CircularProgressIndicator | `DashboardSkeleton` | High |
| Payment method label is generic ("method") | `_PaymentHistorySection` | Medium |
| Notification dot is 7×7px — below 48dp touch target | `_NotificationBell` | High |
| Renewal button conditional logic is complex and fragile | `_RenewalSection` | Medium |
| No pull-to-refresh visual feedback during sync | `RefreshIndicator` | Medium |
| `_SyncStatusCard` duplicates renewal button from `_RenewalSection` | Both sections | Medium |
| Hardcoded English strings in `_OfflineBanner` | `payment_screen.dart` | High |
| No haptic feedback on any interaction | All screens | Low |

### Member App — Login/Auth

| Issue | Widget/Location | Severity |
|-------|----------------|----------|
| `_pinRemainingAttempts` field declared but never used in UI | `unified_login_screen.dart:L37` | Medium |
| `_pinSet` field declared but never used | `unified_login_screen.dart:L36` | Medium |
| TODO: OTP recovery flow not implemented | `_showForgotPinDialog` | Critical |
| PIN keypad uses `⌫` character (emoji-adjacent) | `_NumericKeypad` | High |
| Biometric circle tap target is 64px icon in 112px container — fine, but no ripple | `_BiometricContent` | Low |
| `WelcomeScreen` feature chips use hardcoded English labels | `_FeatureChip` | High |

### Member App — Registration

| Issue | Widget/Location | Severity |
|-------|----------------|----------|
| `RegistrationStepIndicator` API mismatch — `currentStep`/`totalSteps` params don't exist | `identity_verification_screen.dart` | Critical |
| Location cascade has no graceful error state — shows raw exception | `_loadRegions` | High |
| Document upload cards are side-by-side on small screens | `PersonalInfoForm` | Medium |
| No preview before submit on PersonalInfoForm | `_submit()` | Medium |
| `_DocumentPickerCard` not defined in the file — imported from elsewhere | Unclear dependency | Medium |

### Member App — Claims

| Issue | Widget/Location | Severity |
|-------|----------------|----------|
| No filter by status (APPROVED/REJECTED/PENDING) | `MemberClaimsScreen` | High |
| No search by claim number or facility | `MemberClaimsScreen` | Medium |
| Appeal dialog textarea has no character limit shown | `_submitAppeal` | Low |
| `AnimatedHeroCard` used with generic "Claims" value — not meaningful | `build()` | Medium |

### Member App — Profile

| Issue | Widget/Location | Severity |
|-------|----------------|----------|
| Sign Out button is `FilledButton` with error color — too destructive-looking for primary action | `ProfileScreen` | High |
| Delete Account is `TextButton` — insufficient visual weight for destructive action | `ProfileScreen` | Medium |
| Profile header uses hardcoded `Icons.person` — no initials fallback | `ProfileScreen` | Low |
| Settings items are `ListTile` inside `GlassCard` — inconsistent with rest of app | Multiple | Medium |

### Admin Desktop — Login

| Issue | Widget/Location | Severity |
|-------|----------------|----------|
| Left panel feature list uses hardcoded English strings | `LoginScreen` | High |
| No TOTP/2FA step shown in login flow | `_login()` | High |
| Demo mode banner uses `strings.t('demoMode')` but the key may not exist in all locales | `LoginScreen` | Medium |

### Facility Desktop — Submit Claim

| Issue | Widget/Location | Severity |
|-------|----------------|----------|
| Service catalog uses hardcoded English labels | `_kCatalog` | High |
| `_ServiceCatalogDialog` build method truncated — incomplete | `submit_claim_screen.dart` | Critical |
| No real-time total update animation | `_totalAmount` getter | Low |
| Confirm dialog uses hardcoded "Confirm & Submit" string | `_confirmAndSubmit` | High |

---

## Benchmark Gap Analysis

### Dashboard vs. Google Health Dashboard
- **Google Health**: Hero metric (steps/heart rate) is 40px+ display text, immediately scannable. Secondary metrics are in a 2-column card grid with color-coded icons.
- **Current**: Hero card is strong. MetricCard grid is weak — same visual weight as the hero, no hierarchy.
- **Fix**: Increase MetricTile value text to `titleLarge` (18sp Outfit SemiBold). Add left-border accent color per metric type.

### Digital Card vs. Monzo Card Screen
- **Monzo**: Card flip is instant, satisfying. Card number is masked by default, tap to reveal. Status is a colored pill in the top-right corner.
- **Current**: Flip animation exists (good). Status badge color logic is correct. Missing: card download/screenshot, no "show at facility" prominent CTA on front face.
- **Fix**: Add "Show at Facility" as a primary button on the front face (not just back). Add screenshot/share via `RenderRepaintBoundary`.

### Claims vs. Oscar Health Claims Tracker
- **Oscar Health**: Claims have a timeline view showing submission → review → decision. Each claim card shows the facility name prominently, not just the claim number.
- **Current**: Claim cards show claim number first, facility name as subtitle. No timeline. No filter.
- **Fix**: Swap hierarchy — facility name as title, claim number as subtitle. Add `FilterBar` with status filters.

### Payment vs. M-Pesa Checkout
- **M-Pesa**: Single-screen flow. Amount is shown in large display text. One primary CTA. No manual "verify" step — auto-confirms.
- **Current**: Two-step manual flow (initiate → verify). Auto-polling exists but is not communicated clearly. Step indicator is good.
- **Fix**: The auto-polling is already implemented. Make it more prominent — show a pulsing "Checking payment..." state that auto-resolves.

---

## Design Token Updates

The existing `AppTheme` is well-structured. These additions close the gaps:

```dart
// Add to AppTheme — missing tokens

// Surface hierarchy (for elevation system)
static const Color surface0 = Color(0xFFF6F9F8);  // page background (= surfaceLight)
static const Color surface1 = Color(0xFFFFFFFF);  // card background (= surfaceCard)
static const Color surface2 = Color(0xFFEDF4F2);  // subtle section bg
static const Color surface3 = Color(0xFFE0EDE9);  // pressed/hover state

// Dark mode surfaces
static const Color darkSurface0 = Color(0xFF0F1A17);
static const Color darkSurface1 = Color(0xFF1A2E28);
static const Color darkSurface2 = Color(0xFF243D35);

// Motion tokens
static const Duration durationFast = Duration(milliseconds: 150);
static const Duration durationMedium = Duration(milliseconds: 300);
static const Duration durationSlow = Duration(milliseconds: 500);

// Missing radius
static const double radiusXS = 6;  // tight chips, small badges

// Info color (missing from current theme)
static const Color info = Color(0xFF1565C0);
```

---

## Screen-by-Screen Redesign Blueprint

### 1. Member App — Dashboard

**Layout (top → bottom):**
1. `_CoverageHeroCard` — keep gradient, add expiry countdown chip when ≤30 days
2. `_QuickStatsRow` — upgrade to `MetricTile` with left-border accent, 2-column grid
3. `_RenewalSection` — consolidate with `_SyncStatusCard` (they overlap)
4. `_PaymentHistorySection` — add "View all" action, improve payment method labels
5. `_BenefitUtilizationSection` — replace with `ProgressDonut` + ETB amounts
6. `_RecentNotificationsSection` — add unread count badge on section title

**Key changes:**
- Remove duplicate renewal button from `_SyncStatusCard` (it already appears in `_RenewalSection`)
- `MetricCard` → `MetricTile` with `PremiumCard` wrapper
- `EmptyState` → `EmptyView` with contextual CTA
- Add `DashboardSkeleton` with `ShimmerBox` placeholders

### 2. Member App — Login (WelcomeScreen + UnifiedLoginScreen)

**WelcomeScreen:**
- Feature chips: use `strings.t()` for all labels (currently hardcoded English)
- Add subtle pattern/texture to gradient background for depth
- Sign In button: keep white FilledButton — correct
- Register button: keep outlined — correct

**UnifiedLoginScreen:**
- Fix: use `_pinRemainingAttempts` in the PIN content UI (show "X attempts remaining" below dots)
- Fix: replace `⌫` character with `Icons.backspace_outlined` icon
- Fix: implement OTP recovery flow (navigate to phone OTP screen)
- Add: show `_pinSet` state — if PIN not set, show "Set up PIN" flow instead of PIN entry

### 3. Member App — Registration Flow

**Step indicator:** Fix the `RegistrationStepIndicator` API — the `identity_verification_screen.dart` passes `currentStep`/`totalSteps` but the widget expects `step: RegistrationStep.identity`. This is a compile error that must be fixed.

**PersonalInfoForm:**
- Stack document upload cards vertically on screens < 400px wide
- Add inline location error state with retry button
- Add "Review before continuing" summary sheet

**IdentityVerificationScreen:**
- Fix compile error: use `RegistrationStepIndicator(step: RegistrationStep.identity)`
- Add ID type → format hint (e.g., "National ID: 12 digits")

### 4. Member App — Claims

**FilterBar** at top with: All | Submitted | Under Review | Approved | Rejected
**Search** field for claim number / facility name
**Claim cards**: facility name as primary title, claim number as secondary
**Timeline chip** showing days since submission

### 5. Member App — Profile

**Header**: Replace `Icons.person` with `ProfileAvatar` (initials)
**Sign Out**: Change to `OutlinedButton` with error color — less alarming than FilledButton
**Delete Account**: Keep as TextButton but add warning icon
**Settings sections**: Group into `PremiumCard` sections with `SectionTitle` headers

### 6. Admin Desktop — Login

**TOTP step**: After password validation, if user has TOTP enabled, show a second step with 6-digit code entry. The `totp_setup_screen.dart` already exists — wire it into the login flow.

**Left panel**: All feature labels must use `strings.t()` keys.

### 7. Facility Desktop — Submit Claim

**Fix**: Complete the `_ServiceCatalogDialog` build method (it was truncated in the file).
**Improvement**: Add real-time total with animation using `AnimatedSwitcher`.
**Improvement**: Show claim tracking number prominently in success state.

---

## Implementation Priority Roadmap

| Priority | Change | Impact | Effort | File |
|----------|--------|--------|--------|------|
| P0 | Fix `RegistrationStepIndicator` compile error | Blocks registration | XS | `identity_verification_screen.dart` |
| P0 | Fix unused `_pinSet`/`_pinRemainingAttempts` warnings | Code quality | XS | `unified_login_screen.dart` |
| P1 | Replace `MetricCard` with `MetricTile` on dashboard | Visual quality | S | `dashboard_screen.dart` |
| P1 | Add `FilterBar` to claims screen | UX | S | `member_claims_screen.dart` |
| P1 | Fix hardcoded English strings in WelcomeScreen chips | i18n | S | `welcome_screen.dart` |
| P1 | Consolidate `_RenewalSection` + `_SyncStatusCard` | UX clarity | M | `dashboard_screen.dart` |
| P2 | Add `DashboardSkeleton` with shimmer | Loading UX | M | `dashboard_screen.dart` |
| P2 | Replace `EmptyState` with `EmptyView` + CTA | UX | S | Multiple |
| P2 | Profile: `ProfileAvatar` initials, fix button hierarchy | Visual | S | `profile_screen.dart` |
| P2 | Admin login: TOTP second step | Security UX | M | `login_screen.dart` |
| P3 | `ProgressDonut` for benefit utilization | Data viz | M | `dashboard_screen.dart` |
| P3 | Claims: facility name as primary title | Information hierarchy | S | `member_claims_screen.dart` |
| P3 | Payment: make auto-polling state more prominent | UX | S | `payment_screen.dart` |
| P3 | OTP recovery flow in UnifiedLoginScreen | Feature | L | `unified_login_screen.dart` |
