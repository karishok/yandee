# Yandee public site — design

## Purpose

A small public website for the Yandee game (iOS and Android), hosted at `yandee-app.ru`. The site provides a public product page with App Store and RuStore links and a stable privacy-policy URL (`/terms`).

## Audience and success criteria

- Primary audience: parents choosing a calm learning game for young children.
- The home page should explain the product in seconds on a phone.
- The legal page must clearly state the app's data practices.
- The site must be responsive, accessible, and served from `yandee-app.ru`.

## Scope

### Routes

| Route | Purpose |
| --- | --- |
| `/` | Product introduction for Yandee. |
| `/terms` | Combined Terms of Use and Privacy Policy. |

### Home page

- Header: app icon, Yandee wordmark, section anchors and a link to the conditions page.
- Hero with the headline "Yandee — маленькая игра для больших открытий", a parent-facing description, store buttons and two real app screenshots in phone frames.
- Store links: App Store `https://apps.apple.com/app/yandee/id6817918076` (storefront-neutral) and RuStore `https://www.rustore.ru/catalog/app/com.yandee.yandee`.
- "Два простых режима": the Explore and Find modes, each with a screenshot.
- "Пять знакомых мест": the five scenes, using the in-app illustrations.
- "Родителям": no ads or purchases, no data collection, works offline, app-pinning hint.
- Download band repeating the store buttons; footer with the contact email and a link to `/terms`.

### Conditions and privacy page

- Introductory scope: the game is intended for young children and is used with parental supervision.
- Usage terms: ordinary personal, non-commercial use; no reverse engineering or misuse of the app.
- Privacy section: no accounts, advertising, in-app purchases, analytics, server-side data collection, device permissions, or personal-data transmission.
- Separate sections for children, the app stores' own data processing, and the website itself (static, no cookies or counters; standard server logs).
- Contact email: `babaliants@gmail.com`.
- A visible effective date (update it whenever the text changes) and a short English summary for the App Store listing.

## Visual direction

"Warm child-friendly discovery", matched to the app itself: cream background, warm brown text, the orange of the raccoon icon as the accent, soft mint/sky/yellow cards, rounded shapes, generous mobile spacing, and large readable text. Imagery comes from the app (icon, screenshots, scene illustrations); the favicon is the app icon. No web fonts, scripts or animation beyond hover states.

## Technical approach

- Static two-route site with no server, analytics, storage, authentication, or forms.
- Semantic HTML and responsive CSS.
- Metadata and favicon included from the first implementation.
- `dist/` is served as-is by Nginx on the VPS behind `yandee-app.ru`.

## Acceptance checks

1. Both routes render on mobile and desktop without horizontal scrolling.
2. The home page communicates the game's audience and three key benefits without relying on images.
3. `/terms` states all confirmed privacy facts exactly: no personal-data collection, ads, accounts, purchases, analytics, or server transmission, and gives a working contact email.
4. Navigation between the two pages works with keyboard and touch.
5. `npm test` passes and both store links open the correct listings.

