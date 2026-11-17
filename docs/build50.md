# Build 50 — Estudio design

The user approved the six-screen Estudio proposal and asked to apply it. Version 1.0.3+50 transfers the composition to the native app, preserving the existing App Store review submission.

- Home has an unboxed typographic introduction, an underlined search field and category shortcuts. A dedicated first-listing composition replaces an empty search result when inventory is absent. Real filters, error/retry states, radius and saved searches remain.
- Vehicle cards use flatter chrome, quiet typography and original photos. Detail keeps photos first, then announced price, seller and essential facts; public identity visibility, full-screen gallery, price history and favourite count are unchanged.
- Professional profiles have the smaller overlapping rounded identity, a single legal/business name, quiet statistics, disclosure as a text action and underlined tabs. Uploaded cover/avatar and real counters remain; no stock vehicles or ratings are injected.
- Inbox headings and conversation rows follow the restrained shared styling. Existing messages, offers/counteroffers, 24-hour deadlines, visits, report/block and personal deletion are unchanged.
- Publication retains its validated three steps, mounted inputs, drafts, preview, eligibility and moderation. The stepper now uses numbered text actions.
- Plans use a dark introduction, underlined capacity selector, one focused unboxed price/benefit view, full comparison and the existing free publication route. StoreKit prices, IDs, native payment callbacks, restoration and entitlements are unchanged.

The shared theme reduces border radius, replaces boxed inputs with underlined fields, and uses lighter heading weights. The gold text tone is darker to pass contrast checks on tinted surfaces. All new text has ES/EN/CA translations. Accessibility text scaling, reduced motion and touch targets remain supported.

Validation: 293 Flutter tests passed; after the final profile polish, 10 affected profile/editorial tests passed and a native profile image was inspected. Static analysis has no errors; existing warnings/style notices remain. PGlite confirms diagnostic/optional metric build 50 support, next-build rejection and anonymous denial. Production migration 20261117094115 only extends the existing two build allowlists; auth guards/grants are preserved and security advisory counts are unchanged. No real purchases, messages or notifications were sent.

The independent web shared-profile fallback remains subject to the earlier blocked publication step and is not changed in this release.
