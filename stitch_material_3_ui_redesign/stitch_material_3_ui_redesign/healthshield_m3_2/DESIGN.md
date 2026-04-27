---
name: HealthShield M3
colors:
  surface: '#f7fafd'
  surface-dim: '#d7dadd'
  surface-bright: '#f7fafd'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f4f7'
  surface-container: '#ebeef1'
  surface-container-high: '#e5e8eb'
  surface-container-highest: '#e0e3e6'
  on-surface: '#181c1e'
  on-surface-variant: '#414752'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eef1f4'
  outline: '#717783'
  outline-variant: '#c1c6d4'
  surface-tint: '#005faf'
  primary: '#005dac'
  on-primary: '#ffffff'
  primary-container: '#1976d2'
  on-primary-container: '#fffdff'
  inverse-primary: '#a5c8ff'
  secondary: '#456080'
  on-secondary: '#ffffff'
  secondary-container: '#bed9ff'
  on-secondary-container: '#445f7f'
  tertiary: '#006868'
  on-tertiary: '#ffffff'
  tertiary-container: '#2b8181'
  on-tertiary-container: '#f8fffe'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d4e3ff'
  primary-fixed-dim: '#a5c8ff'
  on-primary-fixed: '#001c3a'
  on-primary-fixed-variant: '#004786'
  secondary-fixed: '#d1e4ff'
  secondary-fixed-dim: '#adc9ed'
  on-secondary-fixed: '#001d36'
  on-secondary-fixed-variant: '#2d4867'
  tertiary-fixed: '#a0f0f0'
  tertiary-fixed-dim: '#84d4d3'
  on-tertiary-fixed: '#002020'
  on-tertiary-fixed-variant: '#004f4f'
  background: '#f7fafd'
  on-background: '#181c1e'
  surface-variant: '#e0e3e6'
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
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: 0.15px
  body-lg:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-lg:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: Manrope
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
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The brand personality focuses on **High-Reliability and Clinical Precision**. It is designed to evoke feelings of institutional trust, calm under pressure, and effortless efficiency. The target audience includes healthcare practitioners, hospital administrators, and patients who require clarity without cognitive load.

The design style follows a **Corporate / Modern** approach, heavily influenced by Material 3 principles but refined for a medical context. It utilizes a "Clinical Minimalism" aesthetic—prioritizing heavy whitespace, purposeful color application to indicate state, and a highly structured information hierarchy that reduces medical errors.

## Colors

This design system utilizes a structured tonal palette to ensure accessibility and hierarchy in a healthcare environment. 

- **Primary Blue (#1976D2):** Used for primary actions and signifying high-trust touchpoints.
- **Secondary Blue-Grey (#476282):** Applied to less prominent UI elements and supporting navigation.
- **Tertiary Teal (#006A6A):** Used for health-related metrics, positive states, or specialized clinical workflows.
- **Surface Colors:** A range of "Cool Neutrals" is used for backgrounds to reduce eye strain during long clinical shifts. Surfaces are layered using Material 3's tonal elevation logic.
- **Functional Colors:** Error (#BA1A1A) is used sparingly for critical alerts; Warning (#7D5800) for cautious patient data; Success (#2E7D32) for completed medical records.

## Typography

**Manrope** is the sole typeface, chosen for its modern geometric structure and exceptional legibility in dense data environments. 

- **Hierarchy:** Bold weights are reserved for high-level navigation and critical patient names. Medium weights are used for form labels and interactive UI elements. Regular weights are used for clinical notes and long-form body text.
- **Legibility:** Line heights are slightly increased (+4px over standard defaults) to ensure that medical terminology is easily scannable and to prevent visual crowding in multi-column layouts.
- **Numerical Data:** Manrope’s balanced numerals ensure that dosages and vitals are distinct and unambiguous.

## Layout & Spacing

The design system employs a **12-column Fluid Grid** for desktop and a **4-column grid** for mobile. 

- **Base Rhythm:** All spacing is based on a 4px baseline grid to ensure mathematical alignment across all Material 3 components.
- **Information Density:** While the system is "Modern and Clinical," it allows for higher density in data-heavy views (like EHR dashboards) by reducing the standard 16px padding to 12px where necessary, provided the overall layout maintains its 24px margins to prevent edge-clutter.
- **Grouping:** Related medical data should be grouped with 8px or 16px spacing, while distinct sections (e.g., Patient History vs. Active Meds) should be separated by 32px or greater.

## Elevation & Depth

This system follows the **Tonal Layering** model of Material 3. Depth is conveyed primarily through color shifts (Surface Containers) rather than heavy shadows, ensuring the UI remains clean and professional.

- **Surface Levels:** The background uses the lowest tonal value. Cards and containers use slightly lighter tones (Surface Container Low, Medium, High) to indicate hierarchy.
- **Shadows:** When used for modal dialogs or floating action buttons, shadows are highly diffused (ambient) with a low-opacity neutral-blue tint (#1976D2 at 8% opacity) to maintain clinical softness.
- **Interactivity:** Elements "lift" slightly on hover through tonal brightness rather than increased shadow distance, maintaining a flat, professional profile.

## Shapes

The shape language is **Rounded**, striking a balance between the friendliness of a consumer app and the rigor of a professional tool.

- **Small Components:** Buttons, text fields, and chips use a 0.5rem (8px) corner radius.
- **Medium Components:** Cards and modals utilize a 1rem (16px) corner radius to soften the large clinical data blocks.
- **Large Components:** Sidebars and bottom sheets use a 1.5rem (24px) radius on leading edges.
- **Pill Shapes:** Exclusively reserved for status indicators (e.g., "Active," "Pending") and search bars to differentiate them from actionable buttons.

## Components

- **Buttons:** Use "Filled" for primary clinical actions (Save, Prescribe) and "Outlined" for secondary actions (Cancel, Back). Buttons have 8px rounding and 16px internal horizontal padding.
- **Input Fields:** Utilize Material 3 "Outlined" text fields with a 1px border. On focus, the border increases to 2px in the Primary Blue. Labels must always be visible (no disappearing placeholders).
- **Cards:** Clinical cards use a subtle "Surface Container" fill instead of a border to group patient data. They should not have shadows unless they are interactive or draggable.
- **Chips:** Used for medical tags or quick-filters. Use the secondary color palette with low-opacity backgrounds (12%).
- **Data Tables:** High-reliability tables require sticky headers and alternating row "ghost" fills (2% Primary Blue) for readability.
- **Vitals Monitors:** A custom component specific to this design system, using the Tertiary Teal for stable readings and Functional Error Red for critical alerts, paired with Manrope Bold for numerical values.
- **Lists:** Standardized with 56px minimum touch targets and 16px padding, utilizing thin dividers only when necessary to separate distinct patient records.