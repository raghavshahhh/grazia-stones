# Design System — Grazia Stones "StoneVerse"

## 1. Color Palette

### Primary Colors
| Token            | Hex       | RGB              | Usage                          |
|------------------|-----------|------------------|--------------------------------|
| `stone.black`    | `#0D0D0D` | 13, 13, 13       | Background primary             |
| `stone.charcoal` | `#1A1A1A` | 26, 26, 26       | Card/surface background        |
| `stone.graphite` | `#2D2D2D` | 45, 45, 45       | Elevated surfaces              |
| `stone.slate`    | `#3D3D3D` | 61, 61, 61       | Borders, dividers              |

### Neutral Colors
| Token            | Hex       | RGB              | Usage                          |
|------------------|-----------|------------------|--------------------------------|
| `silver.dark`    | `#8A8A8A` | 138, 138, 138    | Secondary text                 |
| `silver.medium`  | `#B0B0B0` | 176, 176, 176    | Placeholder text               |
| `silver.light`   | `#D4D4D4` | 212, 212, 212    | Body text                      |
| `silver.bright`  | `#E8E8E8` | 232, 232, 232    | Headings, primary text         |
| `white.pure`     | `#FFFFFF` | 255, 255, 255    | Titles, emphasis               |

### Accent Colors
| Token            | Hex       | RGB              | Usage                          |
|------------------|-----------|------------------|--------------------------------|
| `gold.warm`      | `#C9A96E` | 201, 169, 110    | CTAs, premium highlights       |
| `gold.light`     | `#D4B97A` | 212, 185, 122    | Hover states, secondary accent |
| `gold.dark`      | `#B8944F` | 184, 148, 79     | Active/pressed states          |

### Semantic Colors
| Token            | Hex       | Usage                          |
|------------------|-----------|--------------------------------|
| `status.success` | `#4CAF50` | Order confirmed, success       |
| `status.error`   | `#EF5350` | Validation errors, failures    |
| `status.warning` | `#FFA726` | Low stock, pending states      |
| `status.info`    | `#42A5F5` | Informational messages         |

### Stone Palette (for AR/AI overlays)
| Token            | Hex       | Stone Type                       |
|------------------|-----------|----------------------------------|
| `stone.marble`   | `#F5F0E8` | Carrara / white marble           |
| `stone.granite`  | `#8B7D6B` | Dark granite                     |
| `stone.slate`    | `#4A5568` | Natural slate                    |
| `stone.sandstone`| `#D2B48C` | Warm sandstone                   |
| `stone.limestone`| `#E8DCC8` | Cream limestone                  |

---

## 2. Typography

### Font Family
- **Primary:** `Inter` — clean, modern, luxury feel
- **Display:** `Playfair Display` — editorial headings (optional accent)
- **Monospace:** `JetBrains Mono` — codes, measurements

### Type Scale
| Token           | Size  | Weight    | Line Height | Letter Spacing | Usage                |
|-----------------|-------|-----------|-------------|----------------|----------------------|
| `display.large` | 40px  | Bold 700  | 48px        | -1.0px         | Hero headlines       |
| `display.medium`| 32px  | Bold 700  | 40px        | -0.5px         | Section headings     |
| `display.small` | 28px  | SemiBold  | 36px        | -0.3px         | Screen titles        |
| `heading.large` | 24px  | SemiBold  | 32px        | 0px            | Card titles          |
| `heading.medium`| 20px  | SemiBold  | 28px        | 0px            | Subsection titles    |
| `heading.small` | 18px  | Medium    | 24px        | 0px            | List item titles     |
| `body.large`    | 16px  | Regular   | 24px        | 0.1px          | Body text            |
| `body.medium`   | 14px  | Regular   | 20px        | 0.1px          | Secondary text       |
| `body.small`    | 12px  | Regular   | 16px        | 0.2px          | Captions, labels     |
| `label.large`   | 14px  | SemiBold  | 20px        | 0.5px          | Button text          |
| `label.medium`  | 12px  | SemiBold  | 16px        | 0.5px          | Chip / tab text      |
| `label.small`   | 10px  | Medium    | 14px        | 0.5px          | Badge text           |

---

## 3. Spacing System

Base unit: **4px**

| Token   | Value | Usage                              |
|---------|-------|------------------------------------|
| `xxs`   | 4px   | Inline icon gaps                   |
| `xs`    | 8px   | Tight padding, chip gaps           |
| `sm`    | 12px  | Card internal padding              |
| `md`    | 16px  | Standard section padding           |
| `lg`    | 24px  | Section gaps, screen margins       |
| `xl`    | 32px  | Major section separators           |
| `xxl`   | 48px  | Hero section padding               |
| `xxxl`  | 64px  | Full-screen section gaps           |

---

## 4. Border Radius

| Token     | Value | Usage                          |
|-----------|-------|--------------------------------|
| `none`    | 0px   | Sharp edges (rare)             |
| `xs`      | 4px   | Chips, badges                  |
| `sm`      | 8px   | Text fields, small cards       |
| `md`      | 12px  | Standard cards, buttons        |
| `lg`      | 16px  | Feature cards, bottom sheets   |
| `xl`      | 24px  | Hero cards, modals             |
| `full`    | 999px | Avatars, pills, FABs           |

---

## 5. Shadows

```dart
// Card shadow (subtle luxury)
BoxShadow(
  color: Colors.black.withOpacity(0.08),
  blurRadius: 16,
  offset: Offset(0, 4),
)

// Elevated element
BoxShadow(
  color: Colors.black.withOpacity(0.12),
  blurRadius: 24,
  offset: Offset(0, 8),
)

// Gold glow (CTA emphasis)
BoxShadow(
  color: Color(0xFFC9A96E).withOpacity(0.3),
  blurRadius: 20,
  offset: Offset(0, 0),
)
```

---

## 6. Elevation Levels

| Level | Use Case               | Shadow     | Surface Opacity |
|-------|------------------------|------------|-----------------|
| 0     | Background             | None       | 100% `#0D0D0D`  |
| 1     | Cards, Bottom Nav      | Subtle     | 100% `#1A1A1A`  |
| 2     | FAB, Floating elements | Medium     | 100% `#2D2D2D`  |
| 3     | Dialogs, Bottom Sheets | Strong     | 100% `#1A1A1A`  |
| 4     | App Bar                | Subtle     | 95% `#0D0D0D` + blur |

---

## 7. Glassmorphism Recipe

```dart
// Primary glass surface
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.white.withOpacity(0.08),
      width: 1,
    ),
  ),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: child,
  ),
)

// Gold-accented glass (premium CTAs)
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color(0xFFC9A96E).withOpacity(0.15),
        Color(0xFFC9A96E).withOpacity(0.05),
      ],
    ),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Color(0xFFC9A96E).withOpacity(0.2),
    ),
  ),
)
```

---

## 8. Motion & Animation

### Duration Tokens
| Token      | Value  | Usage                            |
|------------|--------|----------------------------------|
| `instant`  | 100ms  | Button press feedback            |
| `fast`     | 200ms  | Toggle, switch, micro-interactions |
| `normal`   | 300ms  | Screen transitions, card expand  |
| `slow`     | 500ms  | Hero animations, page enter      |
| `cinematic`| 800ms  | Splash reveal, onboarding        |

### Easing Curves
| Name         | Curve                        | Usage                    |
|--------------|------------------------------|--------------------------|
| `easeIn`     | `Curves.easeIn`              | Elements exiting         |
| `easeOut`    | `Curves.easeOut`             | Elements entering        |
| `easeInOut`  | `Curves.easeInOut`           | Smooth transitions       |
| `spring`     | `Curves.elasticOut`          | Playful bounces          |
| `luxury`     | `Curves.decelerate`          | Premium fade-ins         |

### Animation Catalog
| Animation           | Duration | Curve     | Trigger              |
|---------------------|----------|-----------|----------------------|
| Card hover lift     | 200ms    | easeOut   | Pointer enter        |
| Stone tile scale    | 300ms    | spring    | Tap                  |
| Page slide up       | 400ms    | decelerate| Navigation           |
| Hero image zoom     | 500ms    | decelerate| Detail screen enter  |
| Skeleton shimmer    | 1500ms   | linear    | Loading state        |
| Gold glow pulse     | 2000ms   | easeInOut | CTA emphasis (loop)  |
| AR plane detect     | 300ms    | easeOut   | Surface found        |
| AI result reveal    | 800ms    | decelerate| Processing complete  |
| Bottom sheet drag   | 300ms    | spring    | Swipe gesture        |
| Tab indicator slide | 250ms    | easeInOut | Tab switch           |

---

## 9. Component Specifications

### Primary CTA Button
```
Height: 56px
Horizontal padding: 32px
Border radius: 12px
Background: Linear gradient (gold.dark → gold.warm → gold.light)
Text: white, 16px, SemiBold, 0.5px letter spacing
Shadow: gold glow (blur 20, opacity 0.3)
Pressed state: scale 0.97, darken 10%
Loading: circular spinner 24px, white
```

### Secondary Button
```
Height: 56px
Horizontal padding: 32px
Border radius: 12px
Background: transparent
Border: 1.5px silver.dark
Text: silver.light, 16px, SemiBold
Hover: border silver.light, background white 5%
Pressed: scale 0.97
```

### Glass Card
```
Border radius: 16px
Padding: 16px
Background: white 5% opacity
Border: 1px white 8% opacity
Blur: 20px
Shadow: subtle (blur 16, opacity 0.08)
```

### Stone Grid Tile
```
Aspect ratio: 1:1 (square) or 4:5
Border radius: 12px
Image: cover fill
Overlay: gradient bottom 40% (transparent → black 60%)
Title: white, 16px SemiBold, bottom-left 12px
Price: gold.warm, 14px Medium, bottom-right 12px
Pressed: scale 0.95, 200ms
```

### Search Bar
```
Height: 52px
Border radius: 26px (pill)
Background: stone.charcoal
Border: 1px slate
Prefix icon: search, silver.dark
Placeholder: silver.medium, 14px
Focus: border gold.warm, background stone.graphite
```

### Bottom Navigation
```
Height: 64px + safe area
Background: stone.black 95% + blur 20
Border top: 1px slate
Active icon: gold.warm
Active label: gold.warm, 10px SemiBold
Inactive icon: silver.dark
Inactive label: silver.dark, 10px Medium
Indicator: gold.warm, 3px height, 24px width, rounded, above icon
```

### App Bar
```
Height: 56px + status bar
Background: stone.black 95% + blur 20
Title: white.pure, 18px SemiBold, center
Leading: silver.light icon, 24px
Actions: silver.light icons, 24px
Elevation: subtle shadow
```

---

## 10. Iconography

- **Style:** Outlined (Feather or Phosphor icons)
- **Default size:** 24px
- **Small:** 16px (inline)
- **Large:** 32px (feature highlights)
- **Color:** Inherits from text color context
- **Stroke width:** 1.5px (consistent weight)

### Custom Icons (SVG)
| Icon                | Usage                    |
|---------------------|--------------------------|
| `ic_stone_wall`     | Collections nav          |
| `ic_ai_viz`         | AI Visualization feature |
| `ic_ar_camera`      | Live AR feature          |
| `ic_measure`        | Measurement tool         |
| `ic_quote`          | Request quote            |
| `ic_sample`         | Order sample             |
| `ic_dealer`         | Dealer locator           |
| `ic_grazia_logo`    | App icon / splash logo   |

---

## 11. Dark Theme Specification

```
System bar:           #0D0D0D, light icons
Splash screen:        #0D0D0D, centered Grazia logo
Onboarding:           Full-screen stone images, overlay text
Main background:      #0D0D0D
Card background:      #1A1A1A
Elevated surface:     #2D2D2D
Divider/border:       #3D3D3D
Primary text:         #FFFFFF
Secondary text:       #B0B0B0
Disabled text:        #5A5A5A
Primary accent:       #C9A96E (gold)
Icon default:         #B0B0B0
Icon active:          #C9A96E
FAB:                  Gold gradient, white icon
Bottom sheet:         #1A1A1A, top rounded 24px
Dialog:               #1A1A1A, centered, rounded 16px
Toast/Snackbar:       #2D2D2D, gold accent left border
```

---

## 12. Responsive Breakpoints

| Breakpoint   | Width     | Layout                     |
|--------------|-----------|----------------------------|
| Mobile S     | 320px     | Single column, compact     |
| Mobile M     | 375px     | Standard mobile (design at)|
| Mobile L     | 425px     | Wider cards                |
| Tablet       | 768px     | 2-column grid              |
| Desktop      | 1024px    | 3-column, sidebar nav      |
| Wide         | 1440px    | 4-column, full dashboard   |

> **Design at 375px (iPhone 14)** — scale up from there. Use `flutter_screenutil` for adaptive sizing.
