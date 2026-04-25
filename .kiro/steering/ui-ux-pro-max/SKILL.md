---
inclusion: manual
name: ui-ux-pro-max
description: >
  Elite UI/UX design system for Maya City CBHI. Covers design tokens, component
  patterns, motion, dark mode, multilingual (en/am/om), accessibility, and
  Flutter implementation blueprints. Searchable database with 80+ styles,
  200+ palettes, 60+ font pairings, 120+ UX rules, and 30 chart types.
---

# ui-ux-pro-max — Elite Design System

Production-grade UI/UX guidance for the **Maya City CBHI** platform. This skill
covers every layer of the design stack: tokens → components → patterns →
motion → accessibility → localization → delivery.

---

## Prerequisites

```bash
python --version   # Python 3.8+ required
```

---

## Quick-Start Workflow

| Scenario | Entry Point |
|----------|-------------|
| New screen / page | Step 1 → Step 2 → Step 3 |
| New component | Step 3 (domain: `style`, `ux`) |
| Choose palette / font | Step 2 (design system) |
| Review existing UI | Section: **Audit Checklist** |
| Fix a visual bug | Section: **Common Fixes** |
| Add data visualization | Step 3 (domain: `chart`) |
| Flutter-specific patterns | Step 4 (stack: `flutter`) |
| Dark mode audit | Section: **Dark Mode Rules** |
| Localization / RTL | Section: **Multilingual & RTL** |

---

## Step 1 — Analyze Requirements

Extract before writing any code:

- **Product type**: Healthcare / Insurance / Government / Mobile
- **Audience**: Ethiopian household members, CBHI officers, facility staff
- **Constraints**: Offline-first, low-bandwidth, multilingual (en/am/om)
- **Platform**: Android (primary), Flutter Web / Vercel (secondary)
- **Tone**: Trustworthy, accessible, calm — NOT flashy or decorative

---

## Step 2 — Generate Design System

```bash
python .kiro/steering/ui-ux-pro-max/scripts/search.py \
  "health insurance government mobile Ethiopia" \
  --design-system -p "Maya City CBHI"
```

### Persist (Master + Page Overrides)

```bash
python .kiro/steering/ui-ux-pro-max/scripts/search.py \
  "health insurance government mobile Ethiopia" \
  --design-system --persist -p "Maya City CBHI"
```

Creates:
- `design-system/MASTER.md` — global source of truth
- `design-system/pages/<screen>.md` — per-screen overrides

---

## Step 3 — Domain Searches

```bash
python .kiro/steering/ui-ux-pro-max/scripts/search.py "<keyword>" \
  --domain <domain> [-n <max_results>]
```

| Need | Domain | Example Query |
|------|--------|---------------|
| Product patterns | `product` | `"healthcare insurance government"` |
| Visual style | `style` | `"accessible minimal trustworthy"` |
| Color palettes | `color` | `"healthcare teal green government"` |
| Typography | `typography` | `"professional readable multilingual"` |
| Charts / data viz | `chart` | `"dashboard analytics bar line"` |
| UX rules | `ux` | `"animation accessibility forms"` |
| App / mobile | `web` | `"touch safe-areas bottom-nav"` |

---

## Step 4 — Flutter Stack Guidelines

```bash
python .kiro/steering/ui-ux-pro-max/scripts/search.py \
  "<keyword>" --stack flutter
```

---

## Maya City CBHI — Design Token Reference

These are the canonical tokens defined in `AppTheme`. Always use tokens,
never hardcode hex values or pixel sizes.

### Color Tokens

```dart
// Brand
AppTheme.primary        // #0D7A5F  — teal green, all interactive elements
AppTheme.accent         // #1A9E7A  — lighter teal, secondary actions
AppTheme.heroGradient   // primary → accent diagonal gradient

// Semantic
AppTheme.success        // #2E7D52  — confirmed, active coverage
AppTheme.warning        // #FF8F00  — pending, expiring soon, offline
AppTheme.error          // #C62828  — errors, destructive actions
AppTheme.info           // #1565C0  — informational banners

// Surface
AppTheme.surfaceCard    // white / dark-surface — card backgrounds
AppTheme.surfaceLight   // #F5F7FA / #1E1E2E — page backgrounds
AppTheme.textDark       // #1A1A2E — primary text
AppTheme.textSecondary  // #6B7280 — secondary / hint text
```

### Spacing Tokens

```dart
AppTheme.spacingXS   //  4px — icon gaps, tight rows
AppTheme.spacingS    //  8px — between related elements
AppTheme.spacingM    // 16px — standard page padding (list screens)
AppTheme.spacingL    // 24px — form screen padding
AppTheme.spacingXL   // 32px — section separators
AppTheme.spacingXXL  // 48px — hero sections
```

### Radius Tokens

```dart
AppTheme.radiusS   //  8px — chips, badges, small containers
AppTheme.radiusM   // 12px — cards, inputs, buttons
AppTheme.radiusL   // 20px — bottom sheets, large cards
AppTheme.radiusXL  // 32px — hero containers, full-bleed cards
```

### Elevation / Shadow

```dart
AppTheme.cardShadow    // subtle 4dp shadow for GlassCard
AppTheme.heroShadow    // 8dp shadow for hero containers
AppTheme.floatShadow   // 12dp for FABs and floating elements
```

---

## Component Patterns

### GlassCard (Standard Card)

Use for all card-like containers. Never use raw `Container` with manual
decoration when `GlassCard` applies.

```dart
GlassCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Section header row
      Row(children: [
        _IconContainer(icon: Icons.health_and_safety, color: AppTheme.primary),
        const SizedBox(width: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ]),
      const SizedBox(height: 16),
      // Content
    ],
  ),
)
```

### Icon Container (Header Pattern)

Consistent icon treatment across all section headers:

```dart
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: AppTheme.primary.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Icon(icon, color: AppTheme.primary, size: 20),
)
```

### Primary Button

```dart
FilledButton(
  onPressed: onPressed,
  style: FilledButton.styleFrom(
    minimumSize: const Size(double.infinity, 52),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
    ),
  ),
  child: Text(label),
)
```

### Secondary Button

```dart
OutlinedButton(
  onPressed: onPressed,
  style: OutlinedButton.styleFrom(
    minimumSize: const Size(double.infinity, 52),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
    ),
    side: const BorderSide(color: AppTheme.primary),
  ),
  child: Text(label),
)
```

### Input Field

```dart
TextField(
  decoration: InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppTheme.spacingM,
      vertical: AppTheme.spacingS + 4,
    ),
  ),
)
```

### StatusBadge

```dart
StatusBadge(label: strings.t('active'), color: AppTheme.success)
StatusBadge(label: strings.t('pending'), color: AppTheme.warning)
StatusBadge(label: strings.t('expired'), color: AppTheme.error)
```

### EmptyState

```dart
EmptyState(
  icon: Icons.inbox_outlined,
  title: strings.t('noClaimsYet'),
  subtitle: strings.t('claimsWillAppearHere'),
)
```

---

## Layout Patterns

### Page Scaffold (List Screen)

```dart
Scaffold(
  appBar: AppBar(title: Text(strings.t('screenTitle'))),
  body: ListView.separated(
    padding: const EdgeInsets.all(AppTheme.spacingM),
    itemCount: items.length,
    separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingS),
    itemBuilder: (context, i) => GlassCard(child: _ItemRow(items[i])),
  ),
)
```

### Page Scaffold (Form Screen)

```dart
Scaffold(
  appBar: AppBar(
    title: Text(strings.t('formTitle')),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new),
      onPressed: () => Navigator.pop(context),
    ),
  ),
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(AppTheme.spacingL),
    child: Column(children: [/* fields */]),
  ),
  bottomNavigationBar: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: FilledButton(onPressed: _submit, child: Text(strings.t('save'))),
    ),
  ),
)
```

### Hero Header

```dart
Container(
  decoration: BoxDecoration(
    gradient: AppTheme.heroGradient,
    borderRadius: BorderRadius.circular(AppTheme.radiusL),
  ),
  padding: const EdgeInsets.all(AppTheme.spacingL),
  child: Row(children: [/* avatar + info */]),
)
```

---

## Motion & Animation

### Principles

- **Duration**: 150–300ms for micro-interactions, 300–500ms for page transitions
- **Easing**: `Curves.easeOutCubic` for enter, `Curves.easeInCubic` for exit
- **Reduced motion**: Always check `MediaQuery.of(context).disableAnimations`
- **No layout jank**: Reserve space before async content loads

### Standard Entrance Animation

```dart
Widget build(BuildContext context) {
  return MyWidget()
    .animate()
    .fadeIn(duration: 400.ms, delay: 100.ms)
    .slideY(begin: 0.06, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
}
```

### Staggered List

```dart
ListView.builder(
  itemBuilder: (context, i) => ItemCard()
    .animate(delay: (i * 50).ms)
    .fadeIn(duration: 300.ms)
    .slideX(begin: 0.04, end: 0),
)
```

### Page Transition (Slide Right-to-Left)

```dart
Route<T> _slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 300),
  transitionsBuilder: (_, animation, __, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  ),
);
```

### Loading Shimmer

```dart
Container(
  width: double.infinity,
  height: 80,
  decoration: BoxDecoration(
    color: AppTheme.surfaceLight,
    borderRadius: BorderRadius.circular(AppTheme.radiusM),
  ),
).animate(onPlay: (c) => c.repeat())
 .shimmer(duration: 1200.ms, color: AppTheme.primary.withValues(alpha: 0.08));
```

---

## Dark Mode Rules

### Mandatory Checks

1. **Never hardcode** `Colors.white`, `Colors.black`, or hex colors in widgets
2. Use `Theme.of(context).colorScheme.surface` for backgrounds
3. Use `Theme.of(context).textTheme.bodyMedium` for text — never `TextStyle(color: Colors.black)`
4. Use `AppTheme.surfaceCard` for card backgrounds (adapts to dark)
5. Use `withValues(alpha: x)` for overlays — never `withOpacity()` (deprecated)

### Dark Mode Token Mapping

| Light | Dark |
|-------|------|
| `#FFFFFF` surface | `#1E1E2E` surface |
| `#F5F7FA` background | `#12121F` background |
| `#1A1A2E` text | `#E8E8F0` text |
| `#6B7280` secondary | `#9CA3AF` secondary |
| `AppTheme.primary` | same (teal works on both) |

### NavigationBar Dark Mode

```dart
// In AppTheme.navigationBarTheme:
NavigationBarThemeData(
  indicatorColor: isDark ? AppTheme.accent : AppTheme.primary,
  backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
)
```

---

## Accessibility Rules

### WCAG 2.1 AA Requirements

| Element | Minimum Contrast | Target |
|---------|-----------------|--------|
| Body text | 4.5:1 | 7:1 |
| Large text (18px+) | 3:1 | 4.5:1 |
| UI components | 3:1 | 4.5:1 |
| Focus indicators | 3:1 | — |

### Touch Targets

```dart
// Minimum sizes — enforce with SizedBox or minimumSize
// Android: 48×48dp
// iOS: 44×44pt
// Web: 44×44px

// Correct:
IconButton(
  iconSize: 24,
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  onPressed: onPressed,
  icon: const Icon(Icons.delete_outline),
)
```

### Semantics

```dart
// Decorative images
Image.asset('...', excludeFromSemantics: true)

// Interactive elements
Semantics(
  label: strings.t('deletePasskey'),
  button: true,
  child: IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
)

// Live regions (connectivity banner, status updates)
Semantics(
  liveRegion: true,
  child: ConnectivityBanner(),
)

// Form fields
TextField(
  decoration: InputDecoration(
    labelText: strings.t('phoneNumber'),
    // labelText IS the accessible label — no extra Semantics needed
  ),
)
```

### Focus Management

```dart
// After async navigation, restore focus
WidgetsBinding.instance.addPostFrameCallback((_) {
  FocusScope.of(context).requestFocus(_firstFieldFocus);
});

// Skip-to-content for web
// Add a FocusTraversalGroup at the top of each screen
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: screenContent,
)
```

---

## Multilingual & RTL

### Localization Rules

1. **Every** user-facing string must have entries in `app_en.arb`, `app_am.arb`, `app_om.arb`
2. Never use string literals in widgets — always `strings.t('key')`
3. Amharic (`am`) and Afaan Oromo (`om`) values must be actual translations, not English copies
4. Use `CbhiLocalizations.of(context)` — never `AppLocalizations.of(context)` directly in screens

### Text Overflow for Long Translations

Amharic and Oromo strings are often longer than English. Always handle overflow:

```dart
Text(
  strings.t('someKey'),
  overflow: TextOverflow.ellipsis,
  maxLines: 2,
)

// For buttons — allow wrapping
FilledButton(
  child: FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(strings.t('confirmAndContinue')),
  ),
)
```

### Number & Date Formatting

```dart
// Use locale-aware formatting
import 'package:intl/intl.dart';

final formatted = NumberFormat.currency(
  locale: strings.locale.toString(),
  symbol: 'ETB ',
  decimalDigits: 0,
).format(amount);

final date = DateFormat.yMMMd(strings.locale.toString()).format(dateTime);
```

### Ethiopic Script Considerations

- Amharic uses Ethiopic script — ensure the `Outfit` font has fallback to system Ethiopic font
- Minimum font size for Ethiopic: 14sp (smaller is illegible)
- Line height for Ethiopic: 1.6× (tighter than Latin)

```dart
// In AppTheme — ensure Ethiopic fallback
TextStyle(
  fontFamily: 'Outfit',
  fontFamilyFallback: const ['NotoSansEthiopic', 'sans-serif'],
)
```

---

## Forms & Validation

### Inline Error Pattern

Errors appear immediately below the relevant field, never in a dialog:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        labelText: strings.t('phoneNumber'),
        errorText: _phoneError,  // null = no error shown
        errorStyle: const TextStyle(color: AppTheme.error),
      ),
    ),
    if (_phoneError != null) ...[
      const SizedBox(height: 4),
      Row(children: [
        const Icon(Icons.error_outline, size: 14, color: AppTheme.error),
        const SizedBox(width: 4),
        Text(_phoneError!, style: const TextStyle(
          color: AppTheme.error, fontSize: 12,
        )),
      ]),
    ],
  ],
)
```

### Validation Timing

- **On blur** (field loses focus): validate format
- **On submit**: validate all fields, focus first error
- **On change**: only clear existing errors (never show new ones while typing)

### Loading State on Submit

```dart
FilledButton(
  onPressed: _isLoading ? null : _submit,
  child: _isLoading
    ? const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      )
    : Text(strings.t('submit')),
)
```

---

## Navigation Patterns

### Bottom NavigationBar Rules

- Maximum 5 destinations
- Always show labels (no icon-only nav)
- Use `AppTheme.primary` as indicator color in light mode
- Use `AppTheme.accent` as indicator color in dark mode
- Active icon: filled variant; inactive: outlined variant

### Back Navigation

| Context | Behavior |
|---------|----------|
| Form screen | `PopScope(canPop: false)` + confirm dialog if dirty |
| Registration flow | `PopScope(canPop: false)` + abandon confirmation |
| Home shell (non-home tab) | Switch to Home tab (index 0) |
| Home shell (home tab) | Exit confirmation dialog |
| Login screen | Allow pop freely (no confirmation) |

### Deep Link / Route Guards

```dart
// In _BootstrapScreen — route based on auth state
if (authState.status == AuthStatus.authenticated) return const _HomeShell();
if (authState.status == AuthStatus.guest) return const RegistrationFlow();
return WelcomeScreen(authCubit: context.read<AuthCubit>());
```

---

## Data Visualization

### Chart Selection Guide

| Data Type | Recommended Chart | Flutter Widget |
|-----------|------------------|----------------|
| Coverage status distribution | Donut / Pie | `fl_chart` PieChart |
| Claims over time | Line chart | `fl_chart` LineChart |
| Claims by status | Horizontal bar | `fl_chart` BarChart |
| Benefit utilization | Progress bar | `LinearProgressIndicator` |
| Premium vs claims | Grouped bar | `fl_chart` BarChart |
| Geographic distribution | Choropleth | Custom `CustomPainter` |

### Chart Accessibility

```dart
// Always provide a data table alternative
Semantics(
  label: 'Claims by status chart. Approved: 45%, Pending: 30%, Rejected: 25%',
  child: PieChart(data: chartData),
)
```

### Color-Safe Palette for Charts

Use these in order — all pass WCAG AA against white and dark backgrounds:

```dart
const chartColors = [
  Color(0xFF0D7A5F),  // primary teal
  Color(0xFF1565C0),  // blue
  Color(0xFFFF8F00),  // amber
  Color(0xFFC62828),  // red
  Color(0xFF6A1B9A),  // purple
  Color(0xFF00838F),  // cyan
  Color(0xFF2E7D32),  // green
  Color(0xFF4E342E),  // brown
];
```

---

## Performance Patterns

### Image Loading

```dart
// Always use cached_network_image for remote images
CachedNetworkImage(
  imageUrl: url,
  placeholder: (_, __) => const ShimmerBox(width: 60, height: 60),
  errorWidget: (_, __, ___) => const Icon(Icons.person_outline),
)

// Local assets — use const where possible
const Image(image: AssetImage('assets/images/logo.png'))
```

### List Performance

```dart
// Use ListView.builder for lists > 10 items
ListView.builder(
  itemCount: items.length,
  itemExtent: 72,  // fixed height = better performance
  itemBuilder: (context, i) => ItemRow(items[i]),
)

// Separate heavy widgets into const constructors
class ItemRow extends StatelessWidget {
  const ItemRow(this.item, {super.key});
  // ...
}
```

### Avoid Rebuilds

```dart
// Use BlocSelector to subscribe to only the slice you need
BlocSelector<AppCubit, AppState, bool>(
  selector: (state) => state.isPendingSync,
  builder: (context, isPendingSync) => OfflineBadge(visible: isPendingSync),
)
```

---

## Audit Checklist

Run this before every PR that touches UI:

### Visual Consistency
- [ ] All colors use `AppTheme` tokens — no hardcoded hex
- [ ] All spacing uses `AppTheme.spacingX` constants
- [ ] All radii use `AppTheme.radiusX` constants
- [ ] Cards use `GlassCard` or `AppTheme.cardShadow` decoration
- [ ] Buttons use `FilledButton` (primary) or `OutlinedButton` (secondary)
- [ ] Empty states use `EmptyState` widget
- [ ] **Zero emoji characters** in any widget, string, or ARB file — use Material icons only

### Accessibility
- [ ] Touch targets ≥ 48×48dp on Android, ≥ 44×44pt on iOS
- [ ] Text contrast ≥ 4.5:1 in both light and dark mode
- [ ] All images have `excludeFromSemantics: true` or meaningful `semanticLabel`
- [ ] Interactive elements have `Semantics` labels if icon-only
- [ ] Live regions wrapped in `Semantics(liveRegion: true)`
- [ ] Focus order is logical (top-to-bottom, left-to-right)

### Localization
- [ ] Zero hardcoded English strings in widget files
- [ ] All new keys added to `app_en.arb`, `app_am.arb`, `app_om.arb`
- [ ] Amharic and Oromo values are actual translations (not English copies)
- [ ] Long text handles overflow with `ellipsis` or `FittedBox`

### Dark Mode
- [ ] No hardcoded `Colors.white` or `Colors.black`
- [ ] All `withOpacity()` replaced with `withValues(alpha: x)`
- [ ] Tested in both `ThemeMode.light` and `ThemeMode.dark`

### Performance
- [ ] Lists with > 10 items use `ListView.builder`
- [ ] No `setState` in `build()` method
- [ ] Heavy widgets are `const` where possible
- [ ] No `print()` statements left in production code

### Navigation
- [ ] Back button behavior is correct for each screen type
- [ ] Registration flow has abandon confirmation
- [ ] Home shell has exit confirmation on home tab

### Web / Vercel Compatibility
- [ ] No `dart:io` imports in any file that runs on web
- [ ] No `Platform.isX` without `kIsWeb` guard
- [ ] Native-only plugins use conditional imports
- [ ] `flutter analyze` passes with no errors

---

## Common Fixes

### Fix: Hardcoded color in dark mode

```dart
// ❌ Wrong
Container(color: Colors.white, ...)

// ✅ Correct
Container(color: Theme.of(context).colorScheme.surface, ...)
// or
Container(color: AppTheme.surfaceCard, ...)
```

### Fix: Missing touch target size

```dart
// ❌ Wrong — icon button too small
IconButton(iconSize: 16, onPressed: onTap, icon: const Icon(Icons.close))

// ✅ Correct
IconButton(
  iconSize: 20,
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  onPressed: onTap,
  icon: const Icon(Icons.close),
)
```

### Fix: Error shown while typing

```dart
// ❌ Wrong — validates on every keystroke
TextField(
  onChanged: (v) => setState(() => _error = _validate(v)),
)

// ✅ Correct — validate on blur, clear on change
TextField(
  onChanged: (v) {
    if (_error != null) setState(() => _error = null);
  },
  onEditingComplete: () => setState(() => _error = _validate(_ctrl.text)),
)
```

### Fix: Overflow on Amharic text

```dart
// ❌ Wrong
Text(strings.t('longAmharicKey'))

// ✅ Correct
Text(
  strings.t('longAmharicKey'),
  overflow: TextOverflow.ellipsis,
  maxLines: 2,
)
```

### Fix: withOpacity deprecation

```dart
// ❌ Deprecated
AppTheme.primary.withOpacity(0.10)

// ✅ Correct
AppTheme.primary.withValues(alpha: 0.10)
```

---

## No-Emoji Policy — Professional, AI-Feel Design

This app targets a government health service. Emoji make interfaces feel
casual, inconsistent across platforms, and inaccessible to screen readers.
**Zero emoji are permitted anywhere in the codebase.**

### Rule

```
NEVER use emoji characters in:
- Widget text or labels
- ARB localization strings (app_en.arb, app_am.arb, app_om.arb)
- SnackBar / dialog messages
- Notification titles or bodies
- Comments that render in UI (tooltips, semantics labels)
```

### Replacement Map

| Emoji | Replace with |
|-------|-------------|
| Flag emoji (🇬🇧 🇪🇹) | Text abbreviation: `EN`, `AM`, `OM` |
| Test tube (🧪) | `Icons.science_outlined` |
| Check mark (✅ ✓) | `Icons.check_circle_outline` or `Icons.done` |
| Warning (⚠️) | `Icons.warning_amber_outlined` |
| Info (ℹ️) | `Icons.info_outline` |
| Error (❌) | `Icons.error_outline` |
| Lock (🔒) | `Icons.lock_outline` |
| Person (👤) | `Icons.person_outline` |
| Family (👨‍👩‍👧) | `Icons.family_restroom_outlined` |
| Phone (📱) | `Icons.phone_android_outlined` |
| Document (📄) | `Icons.description_outlined` |
| Calendar (📅) | `Icons.calendar_today_outlined` |
| Money (💰) | `Icons.payments_outlined` |
| Hospital (🏥) | `Icons.local_hospital_outlined` |
| Star (⭐) | `Icons.star_outline` |
| Arrow (→ ←) | `Icons.arrow_forward` / `Icons.arrow_back_ios_new` |
| Fingerprint (👆) | `Icons.fingerprint` |
| Key (🔑) | `Icons.key_outlined` |
| Shield (🛡️) | `Icons.shield_outlined` |
| Globe (🌍) | `Icons.language` |
| Clock (⏰) | `Icons.access_time_outlined` |
| Sync (🔄) | `Icons.sync` |
| Cloud (☁️) | `Icons.cloud_outlined` |
| Offline (📵) | `Icons.cloud_off_outlined` |

### Language Selector — No Flag Emoji

```dart
// WRONG — flag emoji are inconsistent across platforms
const languages = [('en', '🇬🇧'), ('am', '🇪🇹'), ('om', '🇪🇹')];

// CORRECT — text abbreviations, clean and accessible
const languages = [('en', 'EN'), ('am', 'AM'), ('om', 'OM')];

// Dropdown item renders as: "EN  English" / "AM  Amharic" / "OM  Afaan Oromoo"
```

### Demo Mode Indicator — No Emoji

```dart
// WRONG
const Text('🧪', style: TextStyle(fontSize: 16))

// CORRECT
const Icon(Icons.science_outlined, size: 16, color: Color(0xFF856404))
```

### Why This Matters

- **Consistency**: Material icons render identically on all Android versions,
  iOS, and web. Emoji rendering varies by OS version and font.
- **Accessibility**: Screen readers announce emoji as their Unicode name
  ("flag: United Kingdom") which is confusing in a health app context.
  Material icons get proper `semanticLabel` strings.
- **Professional feel**: Government health services use icons, not emoji.
  Emoji signal "consumer app" — this is an institutional platform.
- **Localization**: Emoji have cultural connotations that may not translate.
  The Ethiopian flag emoji means nothing to a user selecting Afaan Oromo.

---

Three Flutter apps, one backend:

| App | Primary Users | Key Screens |
|-----|--------------|-------------|
| `member_based_cbhi` | Household members | Dashboard, Registration, Digital Card, Claims, Profile |
| `cbhi_admin_desktop` | CBHI officers, admins | Claims management, Indigent approvals, Reports, Audit log |
| `cbhi_facility_desktop` | Facility staff | QR scanner, Claim submission, Eligibility check |

### Design Priorities (in order)

1. **Accessibility** — government health service, users may have low literacy
2. **Offline-first** — rural areas with unreliable connectivity
3. **Multilingual** — en/am/om with equal quality
4. **Trust** — conservative, institutional feel; no gamification
5. **Performance** — low-end Android devices (2GB RAM)
6. **Web parity** — member app deploys to Vercel; must work in browser

### AppTheme Location

`member_based_cbhi/lib/src/theme/app_theme.dart`

All three apps share the same design language. When adding tokens, update
`AppTheme` and reference it from all three apps.


---

## Behavioral UX — Leading Users Through the System

These patterns guide users toward correct actions without requiring them to
already know what to do. Apply them whenever a user might be confused,
stuck, or about to make an irreversible decision.

### Progressive Disclosure

Reveal complexity only when the user is ready for it. Never show all options
at once.

```
Level 1 — What the user needs right now
Level 2 — Revealed on tap / scroll / "more options"
Level 3 — Advanced settings, accessible from profile
```

**CBHI examples:**
- Registration: show one step at a time, never the full 7-step form
- Membership selection: show tier cards first, expand details on tap
- Claim submission: show required fields first, optional fields collapsed
- Indigent proof: show document types, expand accepted formats on tap

### Contextual Guidance (Inline Help)

Place help text exactly where the user needs it — not in a separate FAQ:

```dart
// Inline hint below a field
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TextField(
      decoration: InputDecoration(labelText: strings.t('fanNumber')),
    ),
    const SizedBox(height: 4),
    Row(children: [
      const Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          strings.t('fanNumberHint'),  // "Your 12-digit Fayda Authentication Number"
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    ]),
  ],
)
```

### Smart Defaults

Pre-fill fields with the most likely value to reduce cognitive load:

```dart
// Phone field — pre-fill country code
TextEditingController(text: '+251')

// Date of birth — default to 30 years ago (most common adult age)
DateTime.now().subtract(const Duration(days: 365 * 30))

// Language — use device locale if supported, else English
final deviceLang = PlatformDispatcher.instance.locale.languageCode;
final defaultLang = ['en', 'am', 'om'].contains(deviceLang) ? deviceLang : 'en';
```

### Confirmation Before Irreversible Actions

Any action that cannot be undone requires explicit confirmation with a
clear description of consequences:

```dart
Future<bool?> _confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) => showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx, false),
        child: Text(strings.t('cancel')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(ctx, true),
        style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
        child: Text(confirmLabel),
      ),
    ],
  ),
);

// Usage
final confirmed = await _confirmDestructive(
  context,
  title: strings.t('deleteAccountTitle'),
  message: strings.t('deleteAccountMessage'),
  confirmLabel: strings.t('deleteAccount'),
);
if (confirmed == true) _deleteAccount();
```

**Irreversible actions in CBHI that require confirmation:**
- Delete account
- Abandon registration (lose all progress)
- Remove a beneficiary
- Remove a passkey credential
- Exit app from home tab

### Undo Pattern (Non-Destructive Alternative)

For actions that can be reversed within a short window, prefer undo over
confirmation dialogs — less friction, same safety:

```dart
// Show SnackBar with undo action instead of a dialog
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(strings.t('beneficiaryRemoved')),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(
      label: strings.t('undo'),
      onPressed: () => _restoreBeneficiary(removed),
    ),
  ),
);
```

Use undo for: removing beneficiaries, dismissing banners, clearing filters.
Use confirmation for: account deletion, registration abandonment, passkey removal.

---

## Onboarding & First-Run Experience

### First Login Guidance

After a user's first successful login, guide them to the most important
next action — don't leave them on an empty dashboard:

```dart
// In _HomeShell._checkFirstLogin()
// Show SnackBar (not AlertDialog) — non-blocking
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(strings.t('onboardingBody1')),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(
      label: strings.t('goToFamily'),
      onPressed: () => setState(() => _index = 1),
    ),
  ),
);
```

### Empty State Guidance

Empty states are teaching moments. Always explain what the section is for
and what the user should do next:

```dart
EmptyState(
  icon: Icons.family_restroom_outlined,
  title: strings.t('noBeneficiariesAvailable'),
  subtitle: strings.t('addFamilyMembersOnceActive'),
  // Optional CTA
  action: FilledButton.icon(
    onPressed: _addBeneficiary,
    icon: const Icon(Icons.add),
    label: Text(strings.t('addBeneficiary')),
  ),
)
```

**Empty state rules:**
- Icon: outlined variant, `AppTheme.textSecondary` color, 48px
- Title: what is missing (noun phrase)
- Subtitle: why it's empty + what to do (action phrase)
- CTA: only if the user can take action from this screen

### Step Progress Indicators

For multi-step flows, always show where the user is and how far they have
to go. Never show a spinner without context:

```dart
// RegistrationStepIndicator pattern
Column(
  children: [
    LinearProgressIndicator(
      value: step.stepNumber! / RegistrationStepX.totalSteps,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
      valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
      minHeight: 4,
    ),
    const SizedBox(height: 8),
    Text(
      'Step ${step.stepNumber} of ${RegistrationStepX.totalSteps}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppTheme.textSecondary,
      ),
    ),
  ],
)
```

### Offline Awareness

Users in rural Ethiopia frequently lose connectivity. The app must
communicate offline status clearly and reassure users their data is safe:

```dart
// ConnectivityBanner — always visible at top of HomeShell body
// Offline: warning color + cloud_off icon + "You are offline" message
// Back online: success color + cloud_done icon + "Back online. Syncing..." → auto-dismiss after 2s

// Offline queue badge in AppBar
if (isPendingSync)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.cloud_off_outlined, color: AppTheme.warning, size: 14),
      const SizedBox(width: 4),
      Text(strings.t('offlineBadge'), style: const TextStyle(
        color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w700,
      )),
    ]),
  )
```

**Offline UX rules:**
- Never block the user from viewing cached data when offline
- Show what data is stale vs. fresh (timestamp on last sync)
- Queue all write operations silently — never show "you must be online" errors
- Auto-sync when connectivity restores — show brief success confirmation

---

## Error Recovery UX

### Error Message Hierarchy

| Severity | Component | Example |
|----------|-----------|---------|
| Field validation | Inline below field | "Enter a valid Ethiopian phone number" |
| Form-level error | Banner above submit button | "Please fix the errors above" |
| Network error | SnackBar (auto-dismiss 4s) | "Could not connect. Changes saved offline." |
| Session expired | Full-screen redirect | "Your session has expired. Please sign in again." |
| Critical system error | Error screen with retry | "Something went wrong. Tap to retry." |

### Retry Pattern

```dart
class _RetryView extends StatelessWidget {
  const _RetryView({required this.onRetry, this.message});
  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            message ?? strings.t('unknownError'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(strings.t('retry')),
          ),
        ],
      ),
    );
  }
}
```

### Error Message Writing Rules

- **Be specific**: "Enter a valid Ethiopian mobile number (+2519XXXXXXXX)" not "Invalid input"
- **Be actionable**: Tell the user what to do, not just what went wrong
- **Be calm**: No exclamation marks, no ALL CAPS, no blame
- **Be brief**: One sentence maximum for inline errors
- **Localize**: All error messages must be in `app_en.arb`, `app_am.arb`, `app_om.arb`

---

## Security UX — Communicating Security Without Friction

Security features must be visible enough to build trust but not so
intrusive that they block legitimate users.

### Auth Method Priority Display

Show the most secure available method first. Never hide biometric/passkey
behind a "more options" menu:

```
Mobile (Android):
  1. Biometric (auto-trigger on launch if enrolled)
  2. PIN (custom numeric keypad)
  3. OTP (recovery — "Forgot PIN / Can't sign in?")

Web (Vercel):
  1. Passkey (if registered)
  2. PIN (if set)
  3. OTP (recovery)
```

### Security Indicators

Show users that their data is protected without technical jargon:

```dart
// Security note at bottom of login screen
Padding(
  padding: const EdgeInsets.only(top: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.lock_outline, size: 14, color: AppTheme.textSecondary),
      const SizedBox(width: 4),
      Text(
        strings.t('authSecurityNote'),  // "Your data is protected with end-to-end encryption"
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textSecondary,
        ),
      ),
    ],
  ),
)
```

### Session Expiry UX

When a session expires, redirect gracefully — never show a raw 401 error:

```dart
// In AuthCubit — listen for 401 responses
if (response.statusCode == 401) {
  await logout();
  // _BootstrapScreen will automatically show WelcomeScreen
  // Show a brief explanation via SnackBar before redirect
}

// In _BootstrapScreen BlocListener
if (state.status == AuthStatus.unauthenticated && _wasAuthenticated) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.t('sessionExpired'))),
    );
  });
}
```

### Biometric Enrollment Nudge

After a successful OTP login, offer biometric enrollment as a non-blocking
banner — never as a modal that blocks the user:

```dart
// _EnrollBiometricBanner — shown at top of UnifiedLoginScreen
// after successful OTP login when biometric is available but not enrolled
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  child: GlassCard(
    child: Row(children: [
      const Icon(Icons.fingerprint, color: AppTheme.accent),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.t('enrollBiometricTitle'),
            style: Theme.of(context).textTheme.titleSmall),
          Text(strings.t('enrollBiometricMessage'),
            style: Theme.of(context).textTheme.bodySmall),
        ],
      )),
      TextButton(
        onPressed: _navigateToProfileBiometric,
        child: Text(strings.t('enable')),
      ),
      IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: _dismissBannerPermanently,
        tooltip: strings.t('dontAskAgain'),
      ),
    ]),
  ),
)
```

### PIN Security UX

The PIN keypad must never use the system keyboard (prevents shoulder surfing
and keyboard loggers):

```dart
// Custom numeric keypad — no system keyboard
class _PinKeypad extends StatelessWidget {
  // Digits 1-9, then [biometric/passkey], 0, [backspace]
  // Each key: 72×72dp, rounded, haptic feedback on tap
  // PIN dots: filled circle for entered, empty circle for remaining
  // Auto-submit when PIN length reached (no confirm button needed)
}

// PIN dot indicator
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: List.generate(PinService.pinLength, (i) => Container(
    width: 14, height: 14,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: i < _pinInput.length
        ? AppTheme.primary
        : AppTheme.primary.withValues(alpha: 0.20),
    ),
  )),
)
```

### OTP Rate Limit UX

When the user hits the OTP rate limit, show a countdown timer — not just
an error message:

```dart
// Show remaining time until next OTP can be sent
if (_rateLimitedUntil != null) {
  StreamBuilder<int>(
    stream: Stream.periodic(
      const Duration(seconds: 1),
      (i) => _rateLimitedUntil!.difference(DateTime.now()).inSeconds,
    ).takeWhile((s) => s > 0),
    builder: (context, snapshot) {
      final seconds = snapshot.data ?? 0;
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return Text(
        'Try again in ${minutes}:${secs.toString().padLeft(2, '0')}',
        style: const TextStyle(color: AppTheme.warning),
      );
    },
  )
}
```

### Sensitive Data Masking

Never display full sensitive values in the UI:

```dart
// Phone number — mask middle digits
String _maskPhone(String phone) {
  if (phone.length < 8) return phone;
  return '${phone.substring(0, 4)}****${phone.substring(phone.length - 2)}';
}

// Membership ID — show last 4 only
String _maskId(String id) => '****${id.substring(id.length.clamp(4, id.length) - 4)}';

// Temp password — show once, then clear from SharedPreferences
// Never log, never send in API responses
```

### Passkey Trust Indicators

On web, show which passkeys are registered and when they were last used,
so users can identify and remove compromised credentials:

```dart
// In _PasskeysSection credential row
Row(children: [
  const Icon(Icons.security_outlined, size: 18, color: AppTheme.primary),
  const SizedBox(width: 10),
  Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(deviceName ?? strings.t('passkeyDevice'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600)),
      if (lastUsedAt != null)
        Text(
          'Last used: ${_formatDateLabel(lastUsedAt)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary),
        ),
    ],
  )),
  IconButton(
    icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
    tooltip: strings.t('deletePasskey'),
    onPressed: () => _deletePasskey(credentialId),
  ),
])
```

---

## Micro-Interaction Patterns

### Haptic Feedback

Use haptic feedback to confirm important actions — especially on mobile:

```dart
import 'package:flutter/services.dart';

// Light — button taps, selection changes
HapticFeedback.lightImpact();

// Medium — form submission, successful action
HapticFeedback.mediumImpact();

// Heavy — errors, destructive confirmations
HapticFeedback.heavyImpact();

// Selection — PIN keypad digit entry
HapticFeedback.selectionClick();
```

### Button Press Feedback

```dart
// FilledButton already has ink splash — ensure it's visible
// For custom tap areas, use InkWell with explicit splash color
InkWell(
  onTap: onTap,
  borderRadius: BorderRadius.circular(AppTheme.radiusM),
  splashColor: AppTheme.primary.withValues(alpha: 0.12),
  highlightColor: AppTheme.primary.withValues(alpha: 0.06),
  child: content,
)
```

### Success Confirmation

After a successful action, always confirm it visually before navigating away:

```dart
// Brief success animation before navigation
await Future.wait([
  _performAction(),
  Future.delayed(const Duration(milliseconds: 300)),
]);

if (mounted) {
  // Show success SnackBar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(strings.t('success')),
      ]),
      backgroundColor: AppTheme.success,
      duration: const Duration(seconds: 2),
    ),
  );
  // Then navigate
  Navigator.pop(context);
}
```

### Loading State Hierarchy

Show the right loading indicator for the context:

| Context | Indicator | Duration |
|---------|-----------|----------|
| Full page load | Centered `CircularProgressIndicator` | Until data arrives |
| Button action | Inline spinner replaces button label | Until action completes |
| List refresh | `RefreshIndicator` (pull-to-refresh) | Until refresh completes |
| Background sync | AppBar sync icon spins | Until sync completes |
| Image loading | Shimmer placeholder | Until image loads |
| Document validation | Linear progress + status text | Until AI returns result |

---

## Trust-Building UX Patterns

### Transparency About Data Usage

Show users what data is collected and why, at the point of collection:

```dart
// Before capturing a photo
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: AppTheme.info.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(AppTheme.radiusS),
    border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
  ),
  child: Row(children: [
    const Icon(Icons.info_outline, color: AppTheme.info, size: 16),
    const SizedBox(width: 8),
    Expanded(child: Text(
      strings.t('photoUsageExplanation'),
      // "Your photo is used to verify your identity at health facilities."
      style: Theme.of(context).textTheme.bodySmall,
    )),
  ]),
)
```

### Status Transparency

Always show the current state of coverage, claims, and payments — never
leave users guessing:

```dart
// Coverage status with clear visual hierarchy
StatusBadge(
  label: switch (coverageStatus) {
    'ACTIVE'           => strings.t('active'),
    'PENDING_RENEWAL'  => strings.t('pendingRenewal'),
    'WAITING_PERIOD'   => strings.t('waitingPeriod'),
    'EXPIRED'          => strings.t('coverageExpired'),
    'SUSPENDED'        => strings.t('suspended'),
    _                  => strings.t('inactive'),
  },
  color: switch (coverageStatus) {
    'ACTIVE'           => AppTheme.success,
    'PENDING_RENEWAL'  => AppTheme.warning,
    'WAITING_PERIOD'   => AppTheme.info,
    'EXPIRED'          => AppTheme.error,
    _                  => AppTheme.textSecondary,
  },
)
```

### Proactive Notifications

Notify users before problems occur, not after:

| Trigger | Notification | Timing |
|---------|-------------|--------|
| Coverage expiring | "Your coverage expires in 30 days. Renew now." | 30 days before |
| Coverage expiring | "Your coverage expires in 7 days. Renew now." | 7 days before |
| Payment due | "Premium payment due in 14 days." | 14 days before |
| Claim status change | "Your claim #XXXX has been approved." | Immediately |
| Indigent decision | "Your indigent application has been reviewed." | Immediately |
| Sync complete | "Your data is up to date." | After first sync |

---

## Admin & Facility App UX Patterns

### Data Table Patterns (Admin Desktop)

```dart
// Always show: total count, current filter, export option
Row(children: [
  Text('${items.length} ${strings.t('records')}',
    style: Theme.of(context).textTheme.bodySmall),
  const Spacer(),
  if (_hasActiveFilter)
    Chip(
      label: Text(strings.t('filterActive')),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: _clearFilter,
    ),
  const SizedBox(width: 8),
  OutlinedButton.icon(
    onPressed: _export,
    icon: const Icon(Icons.download_outlined, size: 18),
    label: Text(strings.t('exportCsv')),
  ),
])
```

### QR Scanner UX (Facility App)

```dart
// Clear viewfinder with corner guides
// Torch toggle always visible
// Manual entry fallback always visible (not hidden in menu)
// Scan result: immediate visual + haptic feedback
// Error: clear message + retry button

Stack(children: [
  MobileScanner(onDetect: _onDetect),
  // Corner guides
  _QrViewfinder(),
  // Controls
  Positioned(
    bottom: 32, left: 0, right: 0,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          onPressed: _toggleTorch,
          tooltip: strings.t('toggleFlash'),
        ),
        TextButton.icon(
          onPressed: _showManualEntry,
          icon: const Icon(Icons.keyboard_outlined),
          label: Text(strings.t('enterManually')),
        ),
      ],
    ),
  ),
])
```

### Claim Submission Confidence (Facility App)

Show real-time totals as the facility staff adds service items — never
make them calculate manually:

```dart
// Running total at bottom of claim form
Container(
  padding: const EdgeInsets.all(AppTheme.spacingM),
  decoration: BoxDecoration(
    color: AppTheme.primary.withValues(alpha: 0.06),
    border: Border(top: BorderSide(
      color: AppTheme.primary.withValues(alpha: 0.15),
    )),
  ),
  child: Row(children: [
    Text(strings.t('totalClaimed'),
      style: Theme.of(context).textTheme.titleSmall),
    const Spacer(),
    Text(
      'ETB ${_totalAmount.toStringAsFixed(2)}',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppTheme.primary, fontWeight: FontWeight.w700,
      ),
    ),
  ]),
)
```
