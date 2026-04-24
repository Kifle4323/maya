---
inclusion: manual
name: ui-ux-pro-max
description: Comprehensive design guide for web and mobile applications. Contains 67 styles, 161 color palettes, 57 font pairings, 99 UX guidelines, and 25 chart types across 16 technology stacks.
---

# ui-ux-pro-max

Comprehensive design guide for web and mobile applications. Contains 67 styles, 161 color palettes, 57 font pairings, 99 UX guidelines, and 25 chart types across 16 technology stacks. Searchable database with priority-based recommendations.

# Prerequisites

Check if Python is installed:

```bash
python --version
```

---

## How to Use This Skill

Use this skill when the user requests any of the following:

| Scenario | Trigger Examples | Start From |
|----------|-----------------|------------|
| **New project / page** | "Build a dashboard" | Step 1 → Step 2 (design system) |
| **New component** | "Create a card", "Add a modal" | Step 3 (domain search: style, ux) |
| **Choose style / color / font** | "What style fits a healthcare app?" | Step 2 (design system) |
| **Review existing UI** | "Review this page for UX issues" | Quick Reference checklist |
| **Fix a UI bug** | "Button hover is broken" | Quick Reference → relevant section |
| **Improve / optimize** | "Make this more accessible" | Step 3 (domain search: ux) |
| **Add charts / data viz** | "Add an analytics dashboard chart" | Step 3 (domain: chart) |
| **Stack best practices** | "Flutter navigation tips" | Step 4 (stack search) |

Follow this workflow:

### Step 1: Analyze User Requirements

Extract key information from user request:
- **Product type**: Healthcare/Insurance (CBHI), Government service, Mobile app
- **Target audience**: Ethiopian household members, CBHI officers, facility staff
- **Style keywords**: accessible, trustworthy, clean, government, mobile-first
- **Stack**: Flutter (this project's primary tech stack)

### Step 2: Generate Design System (REQUIRED)

**Always start with `--design-system`** to get comprehensive recommendations:

```bash
python .kiro/steering/ui-ux-pro-max/scripts/search.py "<product_type> <industry> <keywords>" --design-system [-p "Project Name"]
```

**Example for this project:**
```bash
python .kiro/steering/ui-ux-pro-max/scripts/search.py "health insurance government mobile Ethiopia" --design-system -p "Maya City CBHI"
```

### Step 2b: Persist Design System (Master + Overrides Pattern)

```bash
python .kiro/steering/ui-ux-pro-max/scripts/search.py "<query>" --design-system --persist -p "Maya City CBHI"
```

This creates:
- `design-system/MASTER.md` — Global Source of Truth
- `design-system/pages/` — Page-specific overrides

### Step 3: Supplement with Detailed Searches

```bash
python .kiro/steering/ui-ux-pro-max/scripts/search.py "<keyword>" --domain <domain> [-n <max_results>]
```

| Need | Domain | Example |
|------|--------|---------|
| Product type patterns | `product` | `--domain product "healthcare insurance"` |
| Style options | `style` | `--domain style "accessible minimal"` |
| Color palettes | `color` | `--domain color "healthcare government"` |
| Font pairings | `typography` | `--domain typography "professional readable"` |
| Chart recommendations | `chart` | `--domain chart "dashboard analytics"` |
| UX best practices | `ux` | `--domain ux "animation accessibility"` |
| App interface | `web` | `--domain web "accessibilityLabel touch safe-areas"` |

### Step 4: Stack Guidelines (Flutter)

```bash
python .kiro/steering/ui-ux-pro-max/scripts/search.py "<keyword>" --stack flutter
```

---

## Project Context: Maya City CBHI

This skill is configured for the **Maya City CBHI** platform — an Ethiopian Community-Based Health Insurance system with three Flutter apps:

- `member_based_cbhi` — Member mobile/web app (household registration, coverage, payments, digital card)
- `cbhi_admin_desktop` — Admin web app (claims, indigent approvals, reports)
- `cbhi_facility_desktop` — Facility web app (eligibility verification, claim submission)

**Design priorities for this project:**
- Accessibility-first (government health service)
- Support for Amharic, Afaan Oromo, and English
- Mobile-first (member app targets Android/web)
- Trust and clarity over decoration
- Consistent with Ethiopian government digital service standards

---

## Rule Categories by Priority

| Priority | Category | Impact | Domain | Key Checks |
|----------|----------|--------|--------|------------|
| 1 | Accessibility | CRITICAL | `ux` | Contrast 4.5:1, Alt text, Keyboard nav, Aria-labels |
| 2 | Touch & Interaction | CRITICAL | `ux` | Min size 44×44px, Loading feedback |
| 3 | Performance | HIGH | `ux` | Lazy loading, Reserve space |
| 4 | Style Selection | HIGH | `style`, `product` | Match product type, Consistency |
| 5 | Layout & Responsive | HIGH | `ux` | Mobile-first, No horizontal scroll |
| 6 | Typography & Color | MEDIUM | `typography`, `color` | Base 16px, Semantic color tokens |
| 7 | Animation | MEDIUM | `ux` | Duration 150–300ms, Reduced motion |
| 8 | Forms & Feedback | MEDIUM | `ux` | Visible labels, Error near field |
| 9 | Navigation Patterns | HIGH | `ux` | Predictable back, Bottom nav ≤5 |
| 10 | Charts & Data | LOW | `chart` | Legends, Tooltips, Accessible colors |

## Pre-Delivery Checklist (Flutter / App UI)

- [ ] No emojis used as icons (use Flutter icon packages instead)
- [ ] All tappable elements provide clear pressed feedback
- [ ] Touch targets meet minimum size (≥44×44pt iOS, ≥48×48dp Android)
- [ ] Primary text contrast ≥4.5:1 in both light and dark mode
- [ ] Safe areas respected for headers, tab bars, and bottom CTA bars
- [ ] Scroll content not hidden behind fixed/sticky bars
- [ ] Verified on small phone, large phone, and tablet
- [ ] All user-facing strings have entries in en/am/om ARB files
- [ ] Reduced motion and dynamic text size supported
