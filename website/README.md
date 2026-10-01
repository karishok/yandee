# Yandee public site — design

## Purpose

Create a small public website for the Yandee iOS game. The site provides an App Store-ready public description and a stable privacy-policy URL.

## Audience and success criteria

- Primary audience: parents choosing a calm learning game for young children.
- The home page should explain the product in seconds on a phone.
- The legal page must clearly state the app's data practices.
- The site must be responsive, accessible, and suitable for hosting at `yandee.eu.org` once the domain delegation completes.

## Scope

### Routes

| Route | Purpose |
| --- | --- |
| `/` | Product introduction for Yandee. |
| `/terms` | Combined Terms of Use and Privacy Policy. |

### Home page

- Lightweight header: Yandee wordmark and a link to the conditions page.
- First section with the headline: "Yandee — маленькая игра для больших открытий".
- A concise parent-facing description: the child gets acquainted with everyday objects and hears their names through play.
- Three benefits: learning objects, listening to words, and a calm experience without advertising or unnecessary distractions.
- A warm, child-friendly visual based on softly illustrated object cards; no screenshots or invented App Store link until supplied.
- Footer with a link to `/terms`.

### Conditions and privacy page

- Introductory scope: the game is intended for young children and is used with parental supervision.
- Usage terms: ordinary personal, non-commercial use; no reverse engineering or misuse of the app.
- Privacy section: no accounts, advertising, in-app purchases, analytics, server-side data collection, or personal-data transmission.
- Contact section with a placeholder for a support email to be added later.
- A visible last-updated date: 1 October 2026.

## Visual direction

"Warm child-friendly discovery": clean light background, deep blue text, bright but restrained mint and yellow accents, soft rounded cards, generous mobile spacing, and large readable text. Use one original illustration asset for the home page and a small custom favicon; avoid unnecessary animation or interactive features.

## Technical approach

- Static two-route site with no server, analytics, storage, authentication, or forms.
- Semantic HTML and responsive CSS.
- Metadata and favicon included from the first implementation.
- The site will be published through Sites and subsequently pointed to the registered `yandee.eu.org` domain.

## Acceptance checks

1. Both routes render on mobile and desktop without horizontal scrolling.
2. The home page communicates the game's audience and three key benefits without relying on images.
3. `/terms` states all confirmed privacy facts exactly: no personal-data collection, ads, accounts, purchases, analytics, or server transmission.
4. Navigation between the two pages works with keyboard and touch.
5. The production build succeeds and a deployed URL is available.

