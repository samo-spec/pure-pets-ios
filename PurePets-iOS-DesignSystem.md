# 🐾 Pure Pets — Apple-Level iOS Design System Upgrade

> Transform Pure Pets into a premium App Store-ready product while preserving its gradient identity, Arabic-first RTL design, and soft modern personality.

---

## 🎨 DESIGN PHILOSOPHY

**Aesthetic Direction:** *"Luxury Veterinary Boutique"*

Think: Apple Wallet meets a premium pet care brand. Clean surfaces with strategic gradient accents, generous white space, and an unmistakable warmth. The gradients are the *signature* — they stay, but they're elevated from decorative to functional.

**Core Principles:**
1. **Gradients = Signature, Not Wallpaper** — Use sparingly for maximum impact
2. **Content First** — Every pixel serves the user's task
3. **Thumb-Friendly** — iOS HIG minimum 44pt touch targets, primary actions in bottom 60%
4. **Arabic-Native** — RTL is the default, not an afterthought
5. **Dynamic & Adaptive** — Dark mode, Dynamic Type, safe areas

---

## 📐 SPACING SYSTEM (8pt Grid)

All spacing derives from a base unit of **4pt**, following the **8pt major grid**:

| Token | Value | Usage |
|-------|-------|-------|
| `pp_space_2xs` | 2pt | Hairline gaps, icon-to-label micro |
| `pp_space_xs` | 4pt | Inline element padding |
| `pp_space_sm` | 8pt | Card internal padding (tight), list row vertical |
| `pp_space_md` | 12pt | Section sub-element gaps |
| `pp_space_base` | 16pt | Standard content margin, card padding |
| `pp_space_lg` | 20pt | Section header top margin |
| `pp_space_xl` | 24pt | Section-to-section gap |
| `pp_space_2xl` | 32pt | Major section separators |
| `pp_space_3xl` | 40pt | Hero-to-content gap |
| `pp_space_4xl` | 48pt | Screen top safe area content offset |

**Screen Margins:** 20pt leading/trailing (up from 16pt for luxury feel)

---

## 🎨 COLOR SYSTEM (Upgraded)

### Brand Palette

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `AppPrimaryClr` | `#CF375B` | `#FF9B96` | Brand identity, key CTAs |
| `AppPrimaryClrDarker` | `#9D364B` | `#FFB7B3` | Pressed states, depth |
| `AppPrimaryClrShiner` | `#E83D65` | `#FF4D7B` | Hover/focus rings, highlights |
| `AccentsColor` | `#B21B48` | `#FFFFFF` | Accent strokes, badges |

### Surface Palette

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `AppBackgroundClr` | `#F2F2F2` | `#1C1C1E` | Screen background |
| `AppForgroundColr` | `#FFFFFF` | `#3A3C44` | Card/surface foreground |
| `AppCardClr` | `#FCFCFC` | `#23252D` | Elevated card surface |
| `AppBackgroundClrDarker` | *new* `#E8E8EA` | `#141416` | Recessed areas, grouped bg |

### Text Palette

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `PrimaryTextClr` | `#000000` | `#FEFFFF` | Headings, body |
| `SecondaryTextClr` | `#424242` | `#D5D5D5` | Subtitles, meta |
| `TertiaryTextClr` | *new* `#8E8E93` | `#98989F` | Captions, timestamps |
| `PlaceholderTextClr` | *new* `#C7C7CC` | `#48484A` | Input placeholders |

### Semantic Palette

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `pp_success` | `#34C759` | `#30D158` | Confirmed, in-stock |
| `pp_warning` | `#FF9500` | `#FFD60A` | Low stock, pending |
| `pp_error` | `#FF3B30` | `#FF453A` | Error, out-of-stock |
| `pp_info` | `#007AFF` | `#0A84FF` | Links, informational |

### Gradient Tokens (PRESERVED + REFINED)

```
pp_gradient_hero:     #CF375B → #E83D65 → #FF6B8A  (brand warmth)
pp_gradient_hero_dark:#9D364B → #CF375B → #E83D65  (deeper for dark mode)
pp_gradient_card:     #FFFFFF → #FFF5F7             (subtle blush on cards)
pp_gradient_overlay:  #000000 @0.0 → #000000 @0.65 (text readability on images)
pp_gradient_service:  Per-service palette (vet=blue, groom=teal, food=amber, train=green)
```

**RULE:** Gradients appear ONLY on:
1. ✅ Hero section background
2. ✅ Service card accents (small chips/badges)
3. ✅ Primary CTA button backgrounds
4. ✅ Stories ring border
5. ❌ Never on body text backgrounds
6. ❌ Never on full-width section backgrounds
7. ❌ Never stacked (no gradient-on-gradient)

---

## 🔤 TYPOGRAPHY SYSTEM

**Font Family:** Beiruti (Arabic-optimized) — KEEP

### Type Scale (Apple HIG-aligned)

| Style | Font | Size | Weight | Line Height | Usage |
|-------|------|------|--------|-------------|-------|
| `pp_largeTitle` | Beiruti | 34pt | Bold | 41pt | Screen titles (scrolled up) |
| `pp_title1` | Beiruti | 28pt | Bold | 34pt | Major section headers |
| `pp_title2` | Beiruti | 22pt | Bold | 28pt | Card titles, hero headline |
| `pp_title3` | Beiruti | 20pt | Medium | 25pt | Sub-section headers |
| `pp_headline` | Beiruti | 17pt | Bold | 22pt | List row primary |
| `pp_body` | Beiruti | 17pt | Regular | 22pt | Body text, descriptions |
| `pp_callout` | Beiruti | 16pt | Regular | 21pt | Supporting body |
| `pp_subheadline` | Beiruti | 15pt | Regular | 20pt | Secondary info |
| `pp_footnote` | Beiruti | 13pt | Regular | 18pt | Captions, meta |
| `pp_caption1` | Beiruti | 12pt | Regular | 16pt | Badges, timestamps |
| `pp_caption2` | Beiruti | 11pt | Regular | 13pt | Legal, micro-labels |

**RULES:**
- Minimum body text on gradient = `pp_headline` (17pt Bold) with `pp_gradient_overlay`
- Never use `pp_footnote` or smaller on any gradient
- Arabic text gets +1pt tracking for readability
- All sizes support Dynamic Type scaling

---

## 📦 COMPONENT LIBRARY

### 1. PPCard (Elevated Surface)

```
┌─────────────────────────────────┐
│  corner: 22pt continuous         │
│  background: AppForgroundColr    │
│  shadow: 0,8 / blur 24 / 0.06   │
│  border: 0.33pt separator @0.28  │
│  padding: 16pt all sides         │
│  min-height: 64pt                │
└─────────────────────────────────┘
```

**Variants:**
- `PPCard.standard` — Default elevated card
- `PPCard.gradient` — Subtle blush gradient background
- `PPCard.hero` — Full gradient with overlay for text
- `PPCard.inset` — Recessed into background (no shadow)

### 2. PPButton

| Variant | Height | Corner | Background | Text | Shadow |
|---------|--------|--------|------------|------|--------|
| `primary` | 52pt | 26pt (pill) | `pp_gradient_hero` | White Bold 17pt | ✅ 0.15 |
| `secondary` | 48pt | 24pt | `AppForgroundColr` | `AppPrimaryClr` Bold 16pt | ✅ 0.08 |
| `tertiary` | 44pt | 22pt | Clear | `AppPrimaryClr` Medium 16pt | ❌ |
| `glass` | 48pt | 24pt | `.ultraThinMaterial` | `AppPrimaryClr` Bold 15pt | ❌ |
| `destructive` | 48pt | 24pt | `pp_error @0.12` | `pp_error` Bold 16pt | ❌ |
| `icon` | 44×44pt | 22pt | `AppCardClr` | SF Symbol 20pt | ✅ 0.06 |

**Touch feedback:** Scale to 0.96 + spring(response: 0.3, damping: 0.7)

### 3. PPServiceCard (Home Grid)

```
┌───────────────────────┐
│ ┌──────┐              │  corner: 18pt continuous
│ │ ICON │  Service      │  shadow: 0,10 / blur 18 / 0.08
│ │ chip │  Title ▶      │  gradient: per-service accent
│ └──────┘              │  min-size: 160×90pt
│ [watermark @0.12]     │  chevron: pill shape
└───────────────────────┘
```

**Service Colors (PRESERVED):**
- 🏥 Vet: `#4A90D9 → #6BB3F0`
- ✂️ Grooming: `#2ECDA7 → #5EEDC4`
- 🎓 Training: `#FF9500 → #FFBC57`
- 🍖 Food: `#FF6B6B → #FF9999`

### 4. PPProductCard (Listings)

```
┌─────────────────────────────┐
│ ┌─────────────────────────┐ │
│ │                         │ │  Image: aspect 4:3
│ │      Product Image      │ │  corner: 22pt top
│ │                         │ │
│ │  [♥]           [-20%]   │ │  Fav button: top-left
│ └─────────────────────────┘ │  Discount badge: top-right
│                             │
│  Product Name               │  pp_headline
│  Short description          │  pp_footnote, SecondaryTextClr
│  ⭐ 4.8 (120)              │  pp_caption1
│                             │
│  ┌──────────┐  ┌─────────┐ │
│  │ 120 ر.ق  │  │ 🛒 أضف  │ │  Price + Add-to-cart
│  └──────────┘  └─────────┘ │  min 44pt height
└─────────────────────────────┘
```

### 5. PPStoryRing

```
Ring: 3pt gradient border (#CF375B → #E83D65 → #FF6B8A)
Size: 68pt outer / 62pt avatar
Unseen: gradient ring
Seen: SecondaryTextClr @0.3 ring
Label: pp_caption2, centered below
```

### 6. PPTabBar (Bottom Navigation)

```
┌─══════════════════════════════════════════┐
│                                            │
│  🏠    🛒    ➕    💬    🔔    🔍        │
│  الرئيسية  السلة   جديد  المحادثات إشعارات بحث   │
│                                            │
│  Height: 83pt (49pt bar + 34pt safe area)  │
│  Active: AppPrimaryClr, filled icon        │
│  Inactive: SecondaryTextClr, outline icon  │
│  Badge: AppPrimaryClr pill, white text     │
└─══════════════════════════════════════════┘
```

**Tab Items (7):**
1. `الرئيسية` (Home) — `house.fill` / `house`
2. `السلة` (Cart) — `cart.fill` / `cart` + badge count
3. `جديد` (New Ad) — `plus.circle.fill` — PROMINENT center (elevated)
4. `المحادثات` (Chats) — `bubble.left.and.bubble.right.fill` / `...`
5. `الإشعارات` (Notifications) — `bell.fill` / `bell` + badge
6. `بحث` (Search) — `magnifyingglass`
7. `الطلبات` (Orders) — `bag.fill` / `bag`

**Center button (New Ad):** 56pt circle, gradient background, elevated -8pt above bar line

---

## 📱 SCREEN-BY-SCREEN UPGRADE

---

### SCREEN 1: HOME (الرئيسية)

#### Section A: Hero Card (`PPHomeHeroCell`)

**Current Issues:**
- Gradient covers too much surface area
- Location control feels disconnected
- Greeting text competes with gradient
- Action button lacks hierarchy

**Improved Version:**

```
┌═══════════════════════════════════════════┐  ← 20pt margin
│                                           │
│  ┌───────────────────────────────────┐    │
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │    │  gradient: pp_gradient_hero
│  │ ░                               ░ │    │  corner: 28pt continuous
│  │ ░  [Brand Logo]    [Status Pill]░ │    │  shadow: 0,14 / blur 24 / 0.12
│  │ ░                               ░ │    │
│  │ ░  مرحباً، محمد ✨             ░ │    │  pp_title2, White
│  │ ░  اكتشف أفضل المنتجات لحيوانك░ │    │  pp_subheadline, White @0.85
│  │ ░                               ░ │    │
│  │ ░  ┌─────────────────────────┐  ░ │    │  Location control
│  │ ░  │ 📍 الدوحة، قطر    ▸    │  ░ │    │  glass material, 44pt height
│  │ ░  └─────────────────────────┘  ░ │    │
│  │ ░                               ░ │    │
│  │ ░  ┌────────────────────────┐   ░ │    │  PRIMARY CTA
│  │ ░  │   🛍️ ابدأ التسوق      │   ░ │    │  52pt, pill, white bg
│  │ ░  └────────────────────────┘   ░ │    │  AppPrimaryClr text
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │    │
│  └───────────────────────────────────┘    │
│                                           │
└═══════════════════════════════════════════┘
```

**Changes:**
- ✅ Keep gradient but add subtle `pp_gradient_overlay` at bottom for text clarity
- ✅ Orbs (A/B) — reduce alpha to 0.15, increase blur
- ✅ Brand label → move to top-leading, reduce to `pp_caption1`
- ✅ Status pill — glass material, more compact
- ✅ Action button → **White background on gradient**, 52pt pill, thumb-reach zone
- ✅ Location control → glass material card, clear tap affordance with chevron
- 🔴 `hidden = yes`: `ambientGlowLayer` (too heavy), `lottieHeaderView` on low-power

#### Section B: Stories Row

**Current Issue:** No visible indicator for new vs. seen stories

**Improved:**
- Gradient ring for unseen (3pt, `pp_gradient_hero`)
- Faded ring for seen (1pt, `SecondaryTextClr @0.3`)
- Ring size: 68pt outer, 62pt avatar
- Label: `pp_caption2` below, single line, truncated
- Horizontal scroll, 12pt gaps
- 🔴 `hidden = yes`: Story title overlay on avatar (too cluttered at this size)

#### Section C: Quick Actions (`PPHomeActionCell`)

**Current Issue:** Glass buttons lack visual hierarchy, all look equal

**Improved:**

```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ 🏥       │  │ ✂️       │  │ 🍖       │
│ أقرب     │  │ حلاقة    │  │ طعام     │
│ بيطري    │  │ حيوانات  │  │ الحيوان  │
│          │  │          │  │          │
│  ▸       │  │  ▸       │  │  ▸       │
└──────────┘  └──────────┘  └──────────┘
 100×120pt     glass material    22pt corners
```

- Size: 100×120pt minimum per card
- Background: `.regularMaterial` (glass) OR `AppCardClr`
- Icon: 28pt SF Symbol, `AppPrimaryClr`
- Title: `pp_footnote` Bold, 2 lines max
- Chevron: bottom-trailing, `pp_caption2` size
- Horizontal scroll with paging feel
- 🔴 `hidden = yes`: `eyebrowLabel` (redundant "SERVICES" text above title)

#### Section D: Category Filter (`PPCategoryCardCell` / `PPHomeCell`)

**Current Issue:** Category chips may be too visually heavy with glass + icon

**Improved:**
- Pill chips: height 36pt, horizontal scroll
- Selected: `AppPrimaryClr` bg, white text, scale 1.02 + spring
- Unselected: `AppCardClr` bg, `SecondaryTextClr` text
- Icon: 18pt, leading side
- Font: `pp_footnote` Bold
- Gap: 8pt between pills
- "الكل" (All) always first

#### Section E: Services Grid (`PPHomeServicesCell`)

**KEEP AS-IS** — Already well-designed with gradient accents, shadow, and proper hierarchy. Minor tweaks:
- Ensure `titleLabel` font is `pp_headline` (17pt Bold)
- Reduce `accentGlowView` alpha from 0.52 → 0.35
- 🔴 `hidden = yes`: `eyebrowLabel` ("SERVICES" text) — redundant

#### Section F: Nearby Ads Carousel (`PPAdsNearByCarouselCell`)

**Upgrade to Product Cards:**
- Use `PPProductCard` component (defined above)
- Add price, rating, and add-to-cart button
- Horizontal scroll with peek (show 10% of next card)
- Section header: "القريبة منك" with "عرض الكل ▸" trailing link

#### Section G: Banners (`PPHomeBannerContainerCell`)

**KEEP AS-IS** — Carousel banners are standard iOS pattern.
- Ensure auto-scroll interval is 5s (not too fast)
- Page indicator: `AppPrimaryClr` active, `SecondaryTextClr @0.3` inactive
- Corner radius: 22pt to match card system

---

### 🆕 NEW SECTIONS TO ADD

#### Section H: "طلباتك الحالية" (Your Current Orders)

```
┌═══════════════════════════════════════┐
│  طلباتك الحالية              عرض الكل ▸│  pp_title3 + link
│                                       │
│  ┌─────────────────────────────────┐  │
│  │ 🟢 قيد التوصيل                 │  │
│  │ طلب #4521 • 3 منتجات           │  │  PPCard.standard
│  │ ████████████░░░░  75%           │  │  progress bar
│  │ الوصول المتوقع: ٢:٣٠ م         │  │
│  │                   [تتبع الطلب ▸]│  │  Secondary CTA
│  └─────────────────────────────────┘  │
└═══════════════════════════════════════┘
```

- Show only if user has active orders (otherwise hidden)
- Max 2 cards visible, horizontal scroll
- Progress bar: gradient accent
- CTA: "تتبع الطلب" secondary button

#### Section I: "الأكثر طلباً" (Most Popular)

```
┌═══════════════════════════════════════┐
│  🔥 الأكثر طلباً             عرض الكل ▸│
│                                       │
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐     │
│  │    │  │    │  │    │  │    │     │  Horizontal scroll
│  │ 🐱 │  │ 🐶 │  │ 🐠 │  │ 🦜 │     │  PPProductCard mini
│  │    │  │    │  │    │  │    │     │
│  │ 45 │  │ 78 │  │ 30 │  │ 55 │     │  Price
│  │ ر.ق│  │ ر.ق│  │ ر.ق│  │ ر.ق│     │
│  └────┘  └────┘  └────┘  └────┘     │
└═══════════════════════════════════════┘
```

#### Section J: "عروض خاصة" (Special Offers)

```
┌═══════════════════════════════════════┐
│  🏷️ عروض خاصة               عرض الكل ▸│
│                                       │
│  ┌─────────────────────────────────┐  │
│  │ ░░░ GRADIENT BANNER ░░░░░░░░░░ │  │  PPCard.hero
│  │ ░                             ░ │  │  Gradient background
│  │ ░  خصم 30% على طعام القطط    ░ │  │
│  │ ░  العرض ينتهي خلال ٤٨ ساعة  ░ │  │
│  │ ░       [تسوق الآن]          ░ │  │  Primary CTA
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  │
│  └─────────────────────────────────┘  │
└═══════════════════════════════════════┘
```

- Full-width gradient card
- Timer/countdown badge
- CTA: "تسوق الآن" primary button

---

### SCREEN 2: PRODUCT DETAIL

**Business UX Layer (CRITICAL additions):**

```
┌═══════════════════════════════════════┐
│  [◁]                    [♥] [↗]      │  Nav: back, fav, share
│                                       │
│  ┌─────────────────────────────────┐  │
│  │         Product Image           │  │  Paged carousel
│  │         with zoom               │  │  Page dots
│  │                   [-20% OFF]    │  │  Discount badge
│  └─────────────────────────────────┘  │
│                                       │
│  طعام قطط رويال كانين                │  pp_title2
│  ⭐ 4.8 (120 تقييم)                  │  Rating row
│  ₿ متوفر  •  🚚 توصيل مجاني         │  Stock + delivery badges
│                                       │
│  ┌─────────┐  ┌──────────────────┐   │
│  │  85     │  │                  │   │  Price (large) + Stepper
│  │  ر.ق   │  │  [−] 1 [+]      │   │
│  └─────────┘  └──────────────────┘   │
│                                       │
│  ━━━ التفاصيل ━━━━━━━━━━━━━━━━━━━━  │  Expandable section
│  Description text...                  │
│                                       │
│  ━━━ التقييمات ━━━━━━━━━━━━━━━━━━━━  │
│  Review cards...                      │
│                                       │
│ ┌═══════════════════════════════════┐ │  STICKY BOTTOM BAR
│ │  85 ر.ق     [🛒 أضف إلى السلة] │ │  Primary CTA, 52pt
│ └═══════════════════════════════════┘ │
└═══════════════════════════════════════┘
```

---

### SCREEN 3: CART (السلة)

**Upgrade:**
- Swipe-to-delete with red destructive action
- Quantity stepper inline (no separate screen)
- Running total sticky at bottom
- Empty state: Lottie animation + "ابدأ التسوق" CTA

---

## 🫳 CTA IMPROVEMENTS

### Before → After

| Location | Before | After | Size | Style |
|----------|--------|-------|------|-------|
| Hero | Small text link | **"ابدأ التسوق"** | 52pt pill | White on gradient |
| Product | Weak add button | **"🛒 أضف إلى السلة"** | 52pt pill | Gradient primary |
| Cart | Generic checkout | **"إتمام الطلب • 85 ر.ق"** | 52pt full-width | Gradient primary |
| Empty states | No action | **"عرض المنتجات"** | 48pt pill | Secondary |
| Location | Chevron only | **"📍 تغيير الموقع"** | 44pt glass | Glass material |
| Service card | Just navigates | **"حجز موعد ▸"** | 36pt | Tertiary inline |
| Offers | No CTA | **"تسوق الآن"** | 48pt pill | White on gradient |

### CTA Priority Rules:
1. **ONE primary CTA per screen** — gradient background, 52pt
2. **Max 2 secondary CTAs** — outlined or filled subtle
3. **Tertiary = text links** with chevron, no background
4. **All CTAs ≥ 44pt height** (Apple HIG minimum)
5. **Primary CTAs in bottom 40%** of screen (thumb zone)

---

## 🔴 HIDDEN ELEMENTS (`hidden = yes`)

| Element | Location | Reason |
|---------|----------|--------|
| `ambientGlowLayer` | PPHomeHeroCell | Visual noise, gradient already provides atmosphere |
| `eyebrowLabel` ("SERVICES") | PPHomeServicesCell | Redundant — title is self-explanatory |
| `lottieHeaderView` | PPHomeHeroCell | Only show on first launch / special events, hide by default on low-power mode |
| `iconChipView` + `iconView` | PPHomeServicesCell (compact) | Hidden in compact layout, redundant with watermark |
| `watermarkView` @0.12 alpha | PPHomeServicesCell | Barely visible, adds rendering cost without benefit → set hidden in compact mode |
| `orbViewA` / `orbViewB` | PPHomeHeroCell | Reduce to single subtle orb OR hide entirely — gradient alone is sufficient |
| `brandLabel` (top of hero) | PPHomeHeroCell | Move to nav bar or remove — hero headline carries brand |
| Stacked gradient overlays | Any screen with gradient-on-gradient | Never stack two gradient views — pick one |
| Decorative separators | Between home sections | Use spacing (24pt gap) instead of visible lines |
| "عرض المزيد" in empty lists | Home sections with 0 items | Hide entire section when empty, don't show empty + link |

---

## ✨ MICRO-INTERACTIONS

### 1. Tap Feedback
```
All interactive elements:
  onTouchDown:  scale(0.96), duration: 0.1s, ease: .easeOut
  onTouchUp:    scale(1.0),  spring(response: 0.3, damping: 0.7)
```

### 2. Card Press
```
PPCard tap:
  scale(0.98) + shadow shrinks (radius 24→16, opacity 0.06→0.03)
  Spring back on release
```

### 3. Add to Cart
```
1. Button → checkmark morph (0.3s)
2. Cart tab badge bounces (spring scale 1.0 → 1.3 → 1.0)
3. Product image "flies" to cart icon (bezier path, 0.5s)
4. Haptic: .medium impact
```

### 4. Pull-to-Refresh
```
Custom: Paw print icon rotates while refreshing
Spring overshoot on completion
```

### 5. Section Loading
```
Skeleton shimmer: left-to-right sweep
  gradient: [#E8E8E8, #F5F5F5, #E8E8E8]
  duration: 1.2s, linear repeat
  Corner radius matches target component
```

### 6. Tab Switch
```
Active tab icon: scale(1.0 → 1.15 → 1.0) spring
Inactive tabs: opacity 1.0 → 0.6 crossfade
Haptic: .light selection
```

### 7. Story Ring
```
Unseen ring: slow rotation gradient (8s per revolution)
Tap: scale(0.95) spring → full-screen transition
```

### 8. Page Transitions
```
Push: slide from trailing (RTL-aware)
Present: sheet with .medium detent first, pull to .large
Dismiss: interactive edge swipe with velocity tracking
```

---

## 🔄 RTL / LTR EXCELLENCE

### Layout Rules
1. **Semantic leading/trailing** — NEVER use left/right in constraints
2. **`NSDirectionalEdgeInsets`** everywhere, not `UIEdgeInsets`
3. **`textAlignment = .natural`** for all text (follows layout direction)
4. **Chevrons flip automatically** — use `chevron.forward` not `chevron.right`
5. **Gradient directions flip** — `startPoint` and `endPoint` swap in RTL
6. **Swipe gestures respect direction** — swipe-to-delete from leading edge

### Arabic Typography Adjustments
- Line height multiplier: 1.4× (vs 1.3× for Latin)
- Letter spacing: +0.5pt for body text
- Never truncate Arabic with "..." mid-word — truncate at word boundary
- Numbers remain LTR even in RTL context (price: "85 ر.ق" not "ر.ق 85")

### Testing Checklist
- [ ] All screens mirrored correctly in RTL
- [ ] No hardcoded left/right constraints
- [ ] Gradients flow naturally in both directions
- [ ] Tab bar icons don't flip (symmetric icons stay)
- [ ] Back button and navigation respects direction
- [ ] Text alignment is natural in mixed content

---

## 📱 SWIFTUI DESIGN SYSTEM

See companion file: `PurePets-DesignSystem.swift`

---

## 🏁 IMPLEMENTATION PRIORITY

1. **Phase 1 — Foundation:** Color tokens, typography scale, spacing system
2. **Phase 2 — Components:** PPCard, PPButton, PPProductCard
3. **Phase 3 — Home Screen:** Hero upgrade, new sections, CTA improvements
4. **Phase 4 — Business UX:** Prices, ratings, add-to-cart, discount badges
5. **Phase 5 — Polish:** Micro-interactions, transitions, skeleton states
6. **Phase 6 — Audit:** RTL testing, Dynamic Type, VoiceOver, dark mode
