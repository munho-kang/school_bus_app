---
name: 제주대 순환버스
description: A campus-life utility that opens on a colour hero card with the next shuttle departures.
colors:
  bg: "#F7F8FA"
  card: "#FFFFFF"
  text: "#191F28"
  text-sub: "#6B7684"
  text-muted: "#8B95A1"
  hairline: "#F2F4F6"
  border: "#E5E8EB"
  primary: "#0E9F6E"
  primary-light: "#14B98A"
  primary-tint: "#E3F6EE"
  on-primary-tint: "#0A7A55"
  danger: "#E5323F"
  danger-light: "#F25A66"
  muted-hero: "#6B7684 → #4E5968"
  course-a: "#0066FF"
  course-b: "#00CC66"
typography:
  font: "Pretendard (400 / 600 / 700, bundled)"
  page-title: "26 / 700 (home), 22 / 700 (app bar)"
  hero-time: "26 / 700, tabular figures"
  section: "17 / 700"
  row-title: "17 / 700 (home), 16 / 600 (lists)"
  body: "15 / 400"
  meta: "13–14 / 400, tabular figures"
  chip: "13 / 700"
rounded:
  pill: "999px"
  button: "14px"
  inner-row: "14px"
  card: "18px"
  hero: "22px"
spacing:
  gutter: "20px"
  card-inset: "16px"
  hero-inset: "20px"
  stack: "10–12px"
  section: "24–28px"
---

# Design System: 제주대 순환버스

## Overview

**North star: "Colour Hero"**, taken from the fall-detection guardian app (`fall-detection/docs/superpowers/specs/2026-08-29-app-visual-redesign-design.md`).
A light grey page, white cards with a soft shadow, and one gradient hero card whose colour tells you the state at a glance.
All tokens and shared widgets live in `bus_tracker/lib/ui/theme.dart`. Light theme only.

## Colours

- **Hero tone** says the shuttle state: green = running (`live`), red = a course leaves in 2 minutes or less (`soon`), grey = both courses finished (`off`). Red appears nowhere else except the red hero.
- **Primary green** is the accent: selected chip, current month, "진행 중" outline, icon tiles (primary on primary-tint).
- **Course colours** A #0066FF / B #00CC66 appear only on the course badge and map markers (must match `assets/web/map.html`). The badge has a white 1.5px ring so it separates from the gradient; B uses dark text (white on green is 2.1:1).

## Components

- **HeroCard** — gradient (top-left → bottom-right), 22px corners, two white bubbles (120px 12%, 90px 8%), white text. It is Hero `'board'`: the home card flies up and becomes the map's top panel (bottom corners only).
- **AppCard** — white, 18px corners, shadow `0 2 10 #0000000D`. `highlight` swaps in a 1.5px primary border (today's menu, ongoing schedule).
- **Pill** — status chip: 'D-n' (tint), '진행 중' / 'D-day' / '오늘' (solid primary).
- **Chips** — stadium, white with border; selected = primary fill, white 700 text.
- **Buttons** — outlined, 52px, 14px corners, 17/700. Map buttons are white circles with elevation 3.
- **Schedule calendar** — month grid in an AppCard (Sunday first). Today = primary filled circle; selected day = 1.5px primary outline. A schedule's short name shows only on its start day (one-day = primary-tint chip, period = hairline chip); days inside a period get a thin grey bar. Tapping a day lists that day's items below.
- **Notice list** — a non-flying HeroCard (`fly: false`) on top counts notices from the last 3 days (green; grey when none). Each row: a 52px date box (big day + small month; primary-tint when new, hairline otherwise), a category tag (primary-tint) and a solid primary '새 글' tag, title 16/600, department 13 text-sub. The pinned group's header row is primary-tint.
- **Past schedule items** lose their card, not their contrast.

## Motion

- **Every tappable thing is wrapped in `Pressable`**: it shrinks (0.90–0.98 depending on size) in 90ms and springs back in 220ms with a slight overshoot (`Curves.easeInBack` on reverse). A quick tap still plays the full press. Reduced-motion turns it off.
- Sub-screen back buttons and app-bar actions get it via `pageBar()`.
- The pinned-notice group opens with `AnimatedSize` + a rotating chevron.
- **Rule:** a new button must be wrapped in `Pressable` (or built from `AppCard`/`HeroCard` with `onTap`, which already are).

## Don'ts

- Don't use red for anything but the "곧 출발" hero.
- Don't put course colours anywhere but the badge and map markers.
- Don't fade past or inactive content with opacity.
