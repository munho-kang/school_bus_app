---
name: 제주대 순환버스
description: A campus-life utility that opens on a bus-stop LED departure board.
colors:
  board-face: "#0B0D0F"
  board-seam: "#23282D"
  led-amber: "#FFB000"
  led-amber-dim: "#B88A2E"
  departing-red: "#FF5A4A"
  course-a: "#0066FF"
  course-b: "#00CC66"
  amber-ink: "#1A1200"
  amber-on-light: "#7E570E"
  amber-on-dark: "#F2BE6E"
  frame-light: "#E8EBEE"
  frame-dark: "#121518"
  plate-light: "#FFFFFF"
  plate-dark: "#181C20"
  hairline-light: "#D3D8DD"
  hairline-dark: "#2E343A"
typography:
  board-display:
    fontFamily: "Galmuri"
    fontSize: "24px"
    lineHeight: 1.2
    letterSpacing: "0"
  board-label:
    fontFamily: "Galmuri"
    fontSize: "12px"
    lineHeight: 1.2
    letterSpacing: "0"
  headline:
    fontFamily: "Roboto, system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 700
  title:
    fontFamily: "Roboto, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 700
  body:
    fontFamily: "Roboto, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
  meta:
    fontFamily: "Roboto, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    fontFeature: "tnum"
rounded:
  tag: "4px"
  plate: "6px"
  card: "8px"
  board: "10px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  gutter: "16px"
  board-inset: "18px"
  section: "24px"
components:
  app-bar:
    backgroundColor: "{colors.board-face}"
    textColor: "{colors.led-amber}"
    typography: "{typography.board-display}"
  board-face:
    backgroundColor: "{colors.board-face}"
    textColor: "{colors.led-amber}"
    rounded: "{rounded.board}"
    padding: "{spacing.board-inset}"
  course-badge-a:
    backgroundColor: "{colors.course-a}"
    textColor: "#FFFFFF"
    rounded: "{rounded.tag}"
    size: "34px"
  course-badge-b:
    backgroundColor: "{colors.course-b}"
    textColor: "#FFFFFF"
    rounded: "{rounded.tag}"
    size: "34px"
  led-tag:
    backgroundColor: "{colors.board-face}"
    textColor: "{colors.led-amber}"
    typography: "{typography.board-label}"
    rounded: "{rounded.tag}"
    padding: "5px 8px"
  icon-tile:
    backgroundColor: "{colors.board-face}"
    textColor: "{colors.led-amber}"
    rounded: "{rounded.plate}"
    size: "36px"
  card:
    backgroundColor: "{colors.plate-light}"
    rounded: "{rounded.card}"
    padding: "16px"
  chip:
    backgroundColor: "{colors.plate-light}"
    rounded: "{rounded.plate}"
  chip-selected:
    backgroundColor: "{colors.led-amber}"
    textColor: "{colors.amber-ink}"
    rounded: "{rounded.plate}"
  button-outlined:
    rounded: "{rounded.plate}"
    height: "48px"
  map-button:
    backgroundColor: "{colors.board-face}"
    textColor: "{colors.led-amber}"
    size: "56px"
---

# Design System: 제주대 순환버스

## Overview

**Creative North Star: "The Stop Sign Board"**

The app is a bus-stop arrival board (BIS) before it is anything else. The first screen is a black acrylic face with amber LEDs showing the next A and B departure from 정문. Everything around it is the board's grey metal housing. White plates hold the everyday lists (portal, 학사일정, 공지, 학식). The board appears only where something is live or time-sensitive. It is a sign you glance at, not a dashboard.

Density is low and one-handed: a 440px column on home, a 600px column on list screens, 48px touch rows. The one theatrical beat is continuity. The home board is a Hero (`'board'`) that flies up and becomes the map's top status panel, so the sign you tapped is the sign you land on.

**Key Characteristics:**
- Black board face, amber LEDs, grey housing; white plates for ordinary content.
- Two type materials on the board: square-pixel Hangul (Galmuri) for words, round-dot LEDs (LedDigits) for times and numbers.
- Flat. Depth comes from 1px seams, not shadows.
- Course colors appear only as number plates (A blue, B green).
- LEDs light column by column from the left when a value changes.

## Colors

A near-black board lit in one amber, set in cool grey housing. Red and the two course colors are signals, not decoration.

### Primary
- **LED Amber** (led-amber): every lit character on the board, app-bar titles, board icons, the selected chip, the progress spinner, and the 1.5px outline on "today" and "ongoing" items.
- **Dimmed LED** (led-amber-dim): secondary board text such as the '정문 출발' header, the header clock, '다음 출발', '운행 종료', and a course with no departures left.
- **Amber on Light / Amber on Dark** (amber-on-light, amber-on-dark): the Material seed-derived primary (from `ColorScheme.fromSeed(led-amber)`, sampled from the build). This is the amber voice for text on plates, where raw amber would be illegible: the current-month heading and meal-slot names. Do not hand-set these values. They come from the seed.

### Secondary
- **Course A Blue** (course-a) and **Course B Green** (course-b): the course number plates on the board, on the map panel, and on the map markers. These are a brand commitment and must be identical wherever a course appears.

### Tertiary
- **Departing Red** (departing-red): only the '곧 출발' text (a departure 2 minutes away or less).

### Neutral
- **Board Face** (board-face): the board, app bars, LED tags, icon tiles, map buttons. It is the same in both themes.
- **Board Seam** (board-seam): dividers inside the board, the board's 1px outline, and the unlit status LED.
- **Housing** (frame-light / frame-dark): scaffold background.
- **Plate** (plate-light / plate-dark): menu list, cards, schedule items, chips.
- **Hairline** (hairline-light / hairline-dark): plate outlines and dividers.
- **Amber Ink** (amber-ink): text on an amber fill.

**The One Red Rule.** Red means "go now" and nothing else. No errors, badges, or emphasis in red.

**The Plate Is the Course Rule.** Course color lives on a square number plate with a letter, never as a text color, tint, or background wash.

## Typography

**Board Font:** Galmuri (Galmuri11-Bold, OFL), subset, bold only
**UI Font:** platform default (Roboto on Android and web)
**Board Numerals:** LedDigits, a custom-painted 5×7 round-dot matrix, not a font

**Character:** Blocky pixel Hangul next to glowing dot numerals reads as a real stop sign. Plain system sans handles everything off the board.

### Hierarchy
- **Board Display** (Galmuri 24, lh 1.2): app-bar titles and the board's wait text ('n분 후', '첫차', '곧 출발').
- **Board Label** (Galmuri 12, lh 1.2): board header and footer, LED tags ('D-3', '진행 중', '오늘'). Galmuri is sharpest at multiples of 12.
- **LED numerals**: departure times (4.4 dot), header clock and map panel times (2.4 dot). Dot pitch is 1.4× the diameter. Unlit dots show at low alpha so the matrix reads as one panel.
- **Headline** (700, 20): month headings on 학사일정. Day-card labels on 학식 sit at 17/700.
- **Title** (700, 16): home menu row titles. List titles use 600, at 15 or the ListTile default.
- **Body** (400, 14, lh 1.4): menus and notice text.
- **Meta** (400, 13, tabular figures): dates, subtitles, map station names.

**The Two Materials Rule.** Words on the board are square pixels (Galmuri). Times and numbers are round LED dots (LedDigits). Dot-matrix Hangul was considered and not built; this split is the shipped decision, and closing it is an open item.

**The Subset Rule.** The Galmuri file contains only the fixed board strings plus printable ASCII (17KB). New board text needs the font re-subset with the `pyftsubset` command in `lib/ui/board.dart`, or its missing glyphs fall back to the system font. Variable text such as station names deliberately uses the system font in amber (600, 13).

## Layout

- Single column, 16px outer gutter. Home is capped at 440px and top-aligned under 600px width, centred above it. List screens are capped at 600px.
- Board rows use an 18px inner inset (14–18px vertical). Plates use 12–16px padding. Stack gaps are 8px, and section breaks are 24px.
- Filter chips scroll horizontally in a 12px-inset row under the app bar.
- The map is full-bleed, with the board panel pinned to the top (drawn behind the status bar, content from the safe area) and two round buttons 24px from the bottom corners.

## Elevation & Depth

Flat by default. The board is set off by its black face and a 1px seam outline. Plates are set off by a 1px hairline. Cards have elevation 0.

Two lights are native to the world, not shadows. Lit LED dots carry a soft glow (blur 0.6× the dot diameter at ~35% alpha). The map's "online" status LED has an 8px dot with a 6px amber glow.

The only true shadow is Material elevation 3 on the round map buttons, which float over a live map.

**The Seam Not Shadow Rule.** Separate surfaces with a 1px line (seam on the board, hairline on plates). Never with a drop shadow.

## Shapes

Small, hardware-like corners from 4 to 10px:
- 4px: course plates and LED tags.
- 6px: chips, buttons, icon tiles.
- 8px: cards and schedule items.
- 10px: the board and the home menu plate.

The map panel is the board with only its bottom corners rounded (14px). The map buttons are the one circle.

## Components

### Departure Board (signature)
- A black face with a seam outline. The top row is '정문 출발' plus the clock (both dimmed). Then comes one row per course: plate, LED time, wait text right-aligned (scaled down to fit on narrow phones). The footer is '실시간 버스 보기' with map and chevron icons.
- The whole board is one tap target. Its ink is amber at low alpha.
- It is a Hero `'board'` with a plain-face flight shuttle, and it becomes the map's top panel.

### LedDigits
- Supports 0–9, ':', '-', and space. A new value sweeps on from the left in 320ms, or appears instantly under reduced motion. The semantics label is the plain text.

### Course Badge
- A square plate in the course color with its letter at 800 weight and 0.6× size: white on A blue, board-face black (#0B0D0F) on B green, since white on #00CC66 only reaches 2.1:1. It is 34px on the board and 26px on the map panel.

### LED Tag
- A small board fragment set on a plate: board-face fill, 4px corners, Board Label amber text. It carries status only: 'D-n' / 'D-day' / '진행 중' on schedule items and '오늘' on the menu day card.

### Menu Row (home)
- A 36px black icon tile with an amber icon, a Title plus a one-line Meta subtitle, and a trailing chevron (or an open-in-new icon for external links). Rows sit on one 10px plate with dividers inset 64px.

### Cards / Schedule Items
- A plate with a hairline border, 8px corners, and 16px padding (12–14px on schedule items).
- "Today" and "ongoing" swap the hairline for a 1.5px amber outline.
- Past schedule items lose their plate and border entirely and keep full-contrast text. They step back without fading.

### Chips
- Plates with 6px corners, a hairline border, 600-weight text, and no checkmark. The selected chip fills with amber and uses amber-ink 700 text.

### Buttons
- Outlined buttons are 48px tall with 6px corners, used for '다시 시도' and '더 보기'. The round map buttons are board-face with amber icons, 56px, and have tooltips.

### App Bar
- A board-face bar with an amber Galmuri 24 title, left-aligned, with light status-bar icons. Every sub-screen wears a strip of the board.

## Do's and Don'ts

### Do:
- **Do** put live, time-sensitive answers on the board face and everything else on white/dark plates.
- **Do** draw times and counts with LedDigits and board words with Galmuri at 12 or 24.
- **Do** re-subset Galmuri whenever a new fixed board string is added.
- **Do** mark "today"/"current" with the 1.5px amber outline or an LED tag.
- **Do** retire past items by removing their plate, not by lowering opacity.
- **Do** honour reduced motion: LEDs appear lit, with no sweep.

### Don't:
- **Don't** use red for anything but '곧 출발'.
- **Don't** change or approximate the course colors, or apply them outside the number plate and map markers.
- **Don't** add drop shadows to plates or the board. Use the 1px seam or hairline.
- **Don't** set amber text directly on white plates. Use the seed-derived amber-on-light.
- **Don't** fade past or inactive content with opacity.
