# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

(One Flutter/Material codebase that ships the same design to Android, iOS, and the web build on GitHub Pages. Users are spread evenly across all three.)

## Users

All Jeju National University (제주대학교) students. Most open it on a phone, often while walking between buildings or waiting for the campus shuttle, and need an answer in seconds. First-time users must understand it without explanation.

## Product Purpose

A single student app for campus life at 제주대: where the campus shuttle is right now, the school portal, the academic calendar, school notices, and today's cafeteria menu. Success means a student opens it, gets what they needed at a glance, and closes it.

## Positioning

Pulls live shuttle positions (bus.jejunu.ac.kr), notices, and cafeteria menus from the school's own sources into one fast, readable place, instead of the school's scattered desktop-first pages.

## Operating Context

- Campus shuttle: two courses, A (blue #0066FF) and B (green #00CC66), shown on a Kakao map with stations and a live status panel. Off-hours show the next departure from 정문 or 운행 종료.
- Notices are fetched live and open the original page on the school site; menus come from 5 cafeterias (백두관, 사라캠퍼스, 생활관 6호관, 생활관 1호관, 교수회관), each updating its week at different times.
- The academic calendar is hard-coded per year (lib/data/academic_schedule.dart).
- The web build fetches through a Cloudflare relay (bus_relay).

## Capabilities and Constraints

- Screens: home, live map (MapView + assets/web/map.html), 학사일정, 공지사항, 학식 메뉴; portal opens jnuclass.jejunu.ac.kr.
- Map polling runs only while the map is open.
- Korean-only UI.
- Unofficial student project; not an official school app.

## Brand Commitments

- Shuttle course colors A = #0066FF and B = #00CC66 are used on the map markers and status panel and must stay consistent everywhere the courses appear.

## Evidence on Hand

- Real live data only (shuttle, notices, menus, calendar). No logo or brand assets exist; do not invent official school branding.

## Product Principles

1. Glanceable first: the most time-sensitive answer (next shuttle, today's menu, upcoming deadline) should be visible without digging.
2. Honest about data: say clearly when data is loading, stale, missing, or failed.
3. One consistent app across Android, iOS, and web.
4. Stay a lightweight student utility; don't pose as an official school product.

## Accessibility & Inclusion

Readable Korean text at phone sizes, sufficient contrast outdoors, touch targets sized for one-handed use while walking.
