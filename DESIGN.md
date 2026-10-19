---
name: kwall
description: Warm native Material surfaces with a growing pixel companion.
colors:
  forest: "#466539"
  forest-dark: "#B2D39C"
  plum: "#735085"
  plum-dark: "#D9B7ED"
  rose: "#A14665"
  rose-dark: "#F1B3C7"
  gold: "#806015"
  gold-dark: "#E9CB81"
  background: "#F5F5EE"
  background-dark: "#1D211E"
  surface: "#FFFEF9"
  surface-dark: "#272D28"
  container: "#E9EBDF"
  container-dark: "#353E36"
  border: "#555E50"
  border-dark: "#8D9C8F"
  text: "#292E27"
  text-dark: "#F1F3E9"
  secondary-text: "#565F50"
  secondary-text-dark: "#C4CDBF"
  on-accent: "#FFFFFF"
  on-accent-dark: "#20231E"
  income: "#39613E"
  income-dark: "#B5D49F"
  expense: "#A42C39"
  expense-dark: "#FFB4AC"
  warning: "#7C590A"
  warning-dark: "#E7C879"
typography:
  display:
    fontFamily: "Roboto"
    fontWeight: 800
    letterSpacing: "-0.5px"
  welcome-headline:
    fontFamily: "Roboto"
    fontSize: "32px"
    fontWeight: 800
    lineHeight: 1.16
    letterSpacing: "-0.5px"
  app-bar-title:
    fontFamily: "Roboto"
    fontSize: "23px"
    fontWeight: 700
  balance:
    fontFamily: "Roboto"
    fontSize: "34px"
    fontWeight: 800
    letterSpacing: "-0.5px"
  title:
    fontFamily: "Roboto"
    fontWeight: 700
  body:
    fontFamily: "Roboto"
rounded:
  chip: "12px"
  input-button: "14px"
  panel: "18px"
  sheet-top: "24px"
spacing:
  compact: "4px"
  small: "8px"
  medium: "12px"
  panel: "16px"
  sheet: "20px"
  welcome: "24px"
components:
  button-primary:
    backgroundColor: "{colors.forest}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.input-button}"
  ledger-panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.panel}"
    padding: "16px"
  text-field:
    backgroundColor: "{colors.container}"
    textColor: "{colors.text}"
    rounded: "{rounded.input-button}"
    padding: "16px"
  chip:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.chip}"
---

# Design System: kwall

## Overview

**Creative North Star: "Una adopción cálida y tranquila"**

kwall's existing visual world combines warm cream surfaces, a forest accent, rounded Material controls, and a pixel companion. Financial information stays clear and compact; the companion brings warmth through its actual sprites and small interactions. Extend this world when adding screens.

The welcome makes the pet feel like the user's own companion. Its short Spanish phrases, generous breathing room, shapes, and Material icons support that relationship. The adoption composition belongs to the welcome surface; it does not require every financial or journal screen to use a centered illustration.

**Key Characteristics:**

- Warm tonal surfaces with visible, restrained outlines.
- One Roboto family, with strong titles and quieter supporting text.
- Native Material feedback and familiar forms.
- Existing pixel sprites as the character imagery.
- Matching light and dark modes, with selectable accent palettes.

The implementation authority is `lib/core/theme/kwall_theme.dart`. Shared patterns live in `lib/core/widgets/finance_widgets.dart` and `juice_widgets.dart`; the welcome implementation lives in `lib/features/welcome/presentation/`. Frontmatter lengths use `px` for portability and represent Flutter logical pixels before text scaling. Component color references show the default light forest palette; runtime colors follow `KwallTheme`, including the selected palette and brightness.

## Colors

The palette pairs earthy accents with cream neutrals in light mode and green-tinted charcoal neutrals in dark mode.

### Primary

- **Forest:** the default action and selection accent; use its dark counterpart on dark surfaces.
- **Plum, Rose, and Gold:** user-selectable alternatives to Forest, each with a corresponding dark-mode value. They replace the accent rather than adding simultaneous competing action colors.
- **On accent:** white in light mode and dark ink in dark mode, paired with the active accent.

### Secondary

- **Income:** semantic positive financial amounts and the theme's secondary color.
- **Expense:** expenses, errors, and destructive meaning.
- **Warning:** caution where a warning role is needed.

### Neutral

- **Background:** the warm page canvas.
- **Surface:** cards, dialogs, sheets, and navigation surfaces.
- **Container:** filled inputs and quieter inset regions. `surfaceElevated` currently aliases this role.
- **Border:** outlines and dividers, often softened through opacity.
- **Text:** primary reading and important amounts.
- **Secondary text:** supporting descriptions; `textMuted` currently aliases this role.

**The Theme Role Rule.** Read colors through `KwallTheme`; preserve palette changes and light/dark behavior in every new surface.

`accentLight` is derived, not a separate fixed swatch: Flutter alpha-blends the active accent over `surface`, at 14% opacity in light mode and 20% in dark mode. It marks selected chips, navigation indicators, and companion stages. Dividers use the border at 25% opacity; enabled input borders use it at 50%.

## Typography

**Display and Body Font:** Roboto, declared by the Flutter theme. The app does not bundle a custom font family in `pubspec.yaml`; platform fallback remains available. Do not infer a separate display font from the pixel artwork.

The hierarchy uses weight and scale within one family. Strong, slightly tight display text anchors important amounts and welcome headlines; ordinary labels and body text inherit Material typography unless a component explicitly sets its size.

- **Display:** the reusable `fontDisplay` style supplies weight and tracking, while each surface supplies its size.
- **Welcome headline:** centered, multiline display text using `welcome-headline`; allow wrapping and scrolling when text grows.
- **App bar title:** the `app-bar-title` role.
- **Balance:** the large amount role used by `FinancialBalanceCard`.
- **Title:** reusable bold text; sheet and name-field headings currently apply a size of 22 logical pixels.
- **Body:** the theme's native Material scale. Welcome captions use a line-height multiplier of 1.4 and secondary text color.
- **Navigation labels:** the current bottom app bar uses 10 logical pixels, regular for inactive destinations and bold for the active destination.

## Layout

`ContentWidth` centers content and caps its width at 800 logical pixels by default. Forms, modal sheet contents, and the welcome use a 560 logical-pixel cap. These are maximum widths, not fixed device widths or CSS breakpoints; small displays use the available width.

Use the observed spacing steps in the frontmatter. Ledger panels have uniform panel padding. `SheetBody` uses sheet padding, a scrollable body, `SafeArea`, and keyboard-inset padding. Native rows use flexible children or wrapping where labels can grow.

The welcome uses a safe-area column: progress and Back above, a scrollable current page in the middle, and one full-width primary action below. Each page has welcome-sized horizontal padding and remains vertically scrollable when space is limited. Its fixed bottom action remains separate from the page scroll. The scene caps its width at 320 logical pixels and scales proportionally below that cap. Preserve text scaling instead of shrinking copy to force it into a fixed height.

## Elevation & Depth

The system primarily conveys depth through surface tones and outlines. The shared card theme has zero elevation; app bars also have zero elevation, including when scrolled. Cards and dialogs share a rounded outlined shape. The floating action button is a restrained exception with Material elevation 2. The welcome's arch and oval ground are flat color shapes, not blurred drop shadows.

**The Quiet Surface Rule.** Use the existing surface roles and border treatment before adding shadows to establish hierarchy.

## Shapes

Corners are gently rounded rather than uniformly pill-shaped. The frontmatter names the recurring chip, input/button, panel, and sheet-top radii. Cards and dialogs use the panel radius with a one-logical-pixel outline; sheets round their top corners and retain a themed outline. Filled and outlined buttons use the input/button radius. Chips have no default border.

The welcome scene adds a soft arch with a rounded lower edge and an oval ground. Species choices use a capsule-like radius of 24 logical pixels; style choices use the input/button radius. Both keep the sprite visible inside the control. These are welcome component shapes, not replacements for the standard panel geometry.

## Components

### Buttons

Filled buttons carry the active accent and its paired on-accent color, with a minimum size of 48 by 50 logical pixels. Outlined buttons have a minimum size of 48 by 48 logical pixels, a themed outline, and the same corner radius. Text buttons carry secondary actions without a filled panel. Use native Material disabled, focus, ink, and press states rather than introducing web-specific hover treatments.

`JuiceButton` is the existing icon-over-label quick-action pattern: panel corners, a themed outline, an icon size of 26, and padding of 8 horizontally and 14 vertically. Its optional filled state uses the accent pair. A press scales it to 0.95 over 110 ms with `easeOutCubic`; reduced motion removes the scale animation. It provides selection haptics.

### Chips

Chips use surface backgrounds, primary text, accent icons, no default border, and the chip radius. Selection uses `accentLight`; the shared theme hides the checkmark. Preserve semantics when a chip adds or removes a choice.

### Cards / Containers

`LedgerPanel` is the shared quiet container: a surface fill, panel radius, border at 65% opacity, antialiased clipping, and uniform panel padding. The global card theme uses the same radius, the full border color, and zero elevation. Use these existing containers for related financial information.

### Inputs / Fields

Inputs are filled with the container role and use the input/button radius. Padding is uniform at 16 logical pixels. The enabled outline uses half-opacity border; focus changes it to the accent at width 2. Supporting hints use secondary text. The welcome name field centers its bold text and offers a Material dice icon to suggest a name, with a tooltip describing the action.

### Navigation

The app's current primary navigation is a `BottomAppBar`, not the generic themed `NavigationBar`. It has four icon-and-label destinations around a centered, docked floating action button. The selected icon sits on `accentLight` with an accent foreground; inactive icons use secondary text. All labels remain visible, with active weight increasing to bold. Destination tooltips name the action. Keep this incumbent structure when extending the shell.

### Companion and adoption controls

Use the supplied adult and baby atlases from `assets/pets/`, resolved through `PetSpeciesCatalog`. `KittyCompanionWidget` renders pixels with `FilterQuality.none`; preserve those crisp edges. Its animation responds to `TickerMode` and the platform's reduced-motion preference.

`AdoptionScene` keeps the selected baby companion in the foreground of a tonal arch, with small Material leaf icons and an oval ground. The first arrival moves toward the center over 1400 ms with `easeOutCubic`. A greeting triggers a short celebration, light haptics, and a heart icon; the reaction resets after 1600 ms. Scene swaps use 240 ms; the heart scales over 280 ms. Reduced motion removes the scene's entrance, swap, and scale animations.

`AdoptionPicker` presents sprite-based species buttons that wrap and style buttons that scroll horizontally. Choices are 48 by 56 logical pixels, with a 44-logical-pixel sprite. Selected choices use `accentLight` and a 1.5-logical-pixel accent outline; unselected choices use the container tone. Previews remain still via `TickerMode`. Each choice has a tooltip, button semantics, and selected semantics.

Welcome page transitions use 400 ms with `easeOutCubic` and jump directly when animations are disabled. The five progress marks use the accent for completed/current steps, extending the current mark rather than relying only on color. The exact welcome narrative and page composition remain in `.impeccable/surfaces/welcome.md`.

## Do's and Don'ts

### Do:

- **Do** extend the cream/forest Material world and support the selected palette in both brightness modes.
- **Do** use existing sprite assets, native Material icons, and actual interaction states to carry meaning.
- **Do** keep welcome Spanish short, warm, and simple, with the companion as the protagonist.
- **Do** allow text to wrap, controls to scroll, and content to respect safe areas and keyboard insets.
- **Do** preserve accessible names, tooltips, selected states, and reduced-motion behavior when adding custom controls.

### Don't:

- **Don't** replace the incumbent system with a new type pairing, unrelated accent, or ornamental shadow vocabulary for an ordinary feature extension.
- **Don't** substitute emoji or technical explanations for the welcome's pictures, shapes, and Material icons.
- **Don't** smooth the pixel sprites or replace their supplied variants with newly invented character artwork.
- **Don't** promote the welcome's centered adoption scene into a mandatory layout for the rest of the app.
- **Don't** hard-code the light forest values in new widgets; the frontmatter records tokens, while `KwallTheme` resolves runtime roles.
