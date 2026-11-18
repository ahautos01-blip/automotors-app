# AUTOMOTORS 1.0.4 (51): multiple vehicle categories

The native interface returns to the approved build49 design. Build50's visual experiment is intentionally excluded. The App Store submission of 1.0.3 (49) remains independent.

## Scope

- Catalogue and publication selector: cars, motorcycles, trucks, boats.
- Cars retain the existing make/model catalogue; other categories accept seller-entered make/model, validated and moderated with the listing.
- Motorcycle displacement and seat height; truck gross weight, payload and axles; boat length, beam, engine hours and cabins.
- Category-specific search bounds, saved criteria, comparisons, technical details and photographic checklists.
- Boats use engine hours and omit road registration/VIN, mileage, automotive transmission/bodywork and ITV.
- Existing accounts, subscriptions, chat, offers, photos, favourites, reviews and aggregate publication quotas share the same listing identifiers and authorization rules.
- Categories are immutable after creation. Existing listings remain cars. Legacy saved searches default to cars.

## Server

`multi_vehicle_catalogue` was deployed with explicit owner authorization on 18 November 2026. No announcement or account was deleted. Existing moderation approvals retain their fingerprints when optional new fields are absent; every new category-specific fact contributes to moderation fingerprints.

No production test announcements, messages, purchases or external notifications were created. Synthetic PGlite tests cover schema validation, invalid payloads, automotive data rejection on boats, fingerprint compatibility and category-isolated alerts.

Post-deployment security advisors match the prior baseline: sixteen informational private-table policy notices, the two existing seller-member-since function warnings, and the existing leaked-password-protection setting warning. No additional warnings.

## Validation and release

The existing Flutter suite plus initial category tests passed (300 cases). Subsequent focused acceptance tests exercise boat draft recovery and expensive-boat catalogue isolation, purchases and saved searches. Final build results belong in the handoff rather than assuming a successful cloud build.

TestFlight acceptance: publish a draft in each category, inspect from a second account, edit its technical facts, save a matching search, compare listings, contact the seller and verify shared plan limits. Use synthetic data in a test environment; do not send real offers or buy plans merely to test the release.

The submitted build49 and installed older builds do not acquire these native UI changes remotely. Distribution of build51 and real-device acceptance are separate release steps. Update App Store descriptions/screenshots for this broader catalogue with a future submission, without withdrawing the current review. The separate website profile fallback publication remains outside this native release.
