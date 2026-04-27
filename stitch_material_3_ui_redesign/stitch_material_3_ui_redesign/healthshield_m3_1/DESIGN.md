---
name: HealthShield M3
colors:
  surface: '#fbf8fe'
  surface-dim: '#dcd9de'
  surface-bright: '#fbf8fe'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f2f8'
  surface-container: '#f0edf2'
  surface-container-high: '#eae7ed'
  surface-container-highest: '#e4e1e7'
  on-surface: '#1b1b1f'
  on-surface-variant: '#414752'
  inverse-surface: '#303034'
  inverse-on-surface: '#f3f0f5'
  outline: '#717783'
  outline-variant: '#c1c6d4'
  surface-tint: '#005faf'
  primary: '#005dac'
  on-primary: '#ffffff'
  primary-container: '#1976d2'
  on-primary-container: '#fffdff'
  inverse-primary: '#a5c8ff'
  secondary: '#5d5f5f'
  on-secondary: '#ffffff'
  secondary-container: '#dcdddd'
  on-secondary-container: '#5f6161'
  tertiary: '#00695c'
  on-tertiary: '#ffffff'
  tertiary-container: '#2d8274'
  on-tertiary-container: '#f8fffc'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d4e3ff'
  primary-fixed-dim: '#a5c8ff'
  on-primary-fixed: '#001c3a'
  on-primary-fixed-variant: '#004786'
  secondary-fixed: '#e2e2e2'
  secondary-fixed-dim: '#c6c6c7'
  on-secondary-fixed: '#1a1c1c'
  on-secondary-fixed-variant: '#454747'
  tertiary-fixed: '#a0f2e1'
  tertiary-fixed-dim: '#84d5c5'
  on-tertiary-fixed: '#00201b'
  on-tertiary-fixed-variant: '#005046'
  background: '#fbf8fe'
  on-background: '#1b1b1f'
  surface-variant: '#e4e1e7'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 57px
    fontWeight: '700'
    lineHeight: 64px
    letterSpacing: -0.25px
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-md:
    fontFamily: Manrope
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  title-lg:
    fontFamily: Manrope
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0.15px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 24px
---

## Brand & Style

The design system is centered on the **Corporate / Modern** aesthetic, specifically leveraging the Material 3 (M3) framework to establish a sense of institutional trust and functional efficiency. The target audience includes citizens and healthcare providers participating in Community-Based Health Insurance (CBHI). 

The visual narrative prioritizes reliability and clarity. It moves away from the high-saturation, generic layouts of the reference images toward a structured, "data-first" approach. By utilizing M3’s tonal surface system, the UI distinguishes between informative content and interactive controls, ensuring that users can navigate their health coverage with zero friction. The emotional response is one of security and official standing, achieved through a balanced use of whitespace and a refined color palette.

## Colors

The color palette is anchored by a professional **Primary Blue (#1976D2)**, representing stability and healthcare authority. This design system utilizes the Material 3 Tonal Palette logic to generate accessible color pairings.

- **Primary:** Used for key actions, active states in the navigation rail, and critical branding elements.
- **Secondary:** A neutral Light Grey used primarily for background surfaces to provide a soft, low-fatigue viewing experience.
- **Tertiary:** A deep teal introduced for specialized health-related indicators (e.g., "Active" status or "Benefit Utilization").
- **Surface Variations:** Following M3 guidelines, surfaces use subtle tonal shifts rather than heavy shadows to denote hierarchy. The background is a clean white/off-white, while containers use increasingly darker tints of the secondary color to create depth.

## Typography

This design system uses a dual-font approach to balance personality with extreme legibility. **Manrope** is used for Headlines and Titles to provide a modern, refined feel. **Inter** is used for Body and Label text because of its exceptional performance in data-heavy environments.

Emphasis is placed on a clear hierarchy for health data:
- **Membership IDs and Names** use `title-md` or `title-lg`.
- **Status indicators** (e.g., "Pending Renewal") use `label-lg` in all-caps with increased letter spacing.
- **Body text** for descriptions uses `body-md` for high information density without sacrificing readability.

## Layout & Spacing

The layout utilizes a **fluid grid system** following M3 responsive guidelines. For handheld devices, a 4-column grid is used; for tablets and desktop views (as seen in the reference), a 12-column grid is employed with a permanent **Navigation Rail** on the left.

The spacing rhythm is built on a 4px baseline. Components like cards and list items are separated by `md` (16px) or `lg` (24px) spacing to prevent the interface from feeling cluttered. Alignment is strictly anchored to the grid, ensuring that data points like "Date of Birth" and "Gender" are perfectly vertically aligned across different list items.

## Elevation & Depth

This design system moves away from the heavy, blurry shadows seen in the reference "Card" navigation and adopts **Tonal Layers**. 

Depth is primarily communicated through surface color rather than shadow intensity. 
- **Level 0 (Background):** Surface color.
- **Level 1 (Cards):** Surface-container-low with a very soft, ambient shadow (4px blur, 5% opacity).
- **Level 2 (Active/Hover):** Surface-container-high with a crisp 1px primary-colored outline for accessibility.
- **Navigation Rail:** A flat, distinct container using `surface-container` to separate it from the content area without needing a physical shadow line.

## Shapes

The design system employs **Rounded (Level 2)** geometry. This provides a professional yet accessible character that feels modern but remains grounded.

- **Buttons & Chips:** Use `rounded-full` (pill-shaped) to maximize tap target clarity.
- **Cards:** Use `rounded-lg` (16px) to house grouped health data comfortably.
- **Search Inputs:** Use `rounded-md` (8px) to distinguish interactive text entry from static cards.
- **Digital CBHI Cards:** Use a specialized `rounded-xl` (24px) to mimic the physical form factor of a credit or insurance card.

## Components

### Buttons
M3 Standardized Buttons are used throughout:
- **Elevated Button:** Primary action for card-based workflows (e.g., "Edit").
- **Tonal Button:** Secondary actions like "Sync" or "View Details."
- **Outlined Button:** Tertiary or cancel actions.

### Cards
Cards are the primary container for the CBHI app. Each card should have a clear `title-md` header and use `label-md` for field descriptions. "Benefit Utilization" and "Household" cards should include a leading icon to aid quick scanning.

### Navigation
- **Navigation Rail (Desktop/Tablet):** Icons with labels. Active states use a primary-colored pill background.
- **Bottom Navigation (Mobile):** Used for the 3-5 core destinations (Home, Family, Card, Claims).

### Chips
Used for status indicators like "Pending Renewal" or "Head of Household." Chips use the tertiary color palette for high visibility without the aggression of pure red/orange warnings.

### Input Fields
Filled text fields with bottom-line indicators for better visibility on the light grey background. Every field must have a clearly defined label and optional helper text.