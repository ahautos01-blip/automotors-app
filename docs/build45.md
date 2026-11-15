# Build 45 — Editorial profile

Version 1.0.3+45. Preserve the current public App Store submission.

- Taller professional cover, centered overlapping avatar and one business legal name.
- Account-type badge, location, statistics cards, green/gold profile tabs and styled empty inventory.
- “Perfil profesional” opens the limitations and seller-provided-information explanation on demand; no identity/document verification is claimed. No visible disclaimer paragraphs below the badge. Spanish, English and Catalan supported.
- Preview renders the actual public profile with isolated fictional data, no production accounts. PROFILE_PREVIEW_PATH optionally exports the Flutter widget capture on the owner's Windows machine; CI runs the behavior assertions without local fonts.
- 260 Flutter tests passed after integrating the complete release. Isolated Postgres offers/reminders/diagnostics tests passed. Diagnostics build allow-list extended to 45 with existing authorization, ACLs and retention unchanged; deployed as 20261115130030. Optional usage counters are off by default; the new disclosure is included in ES/EN/CA.

Device check after installing: profile photos and cover, badge opens/closes explanation, business name once, tabs and chat continue working. These checks do not establish real APNs delivery or purchase behavior.

## Five market improvements

1. Existing three-car comparator now includes version, maintenance, ITV, warranty and municipality alongside engine/equipment details and differences-only mode.
2. Explicit official IGN CartoCiudad municipality picker on home/catalogue and listing create/edit. No GPS permissions; municipality reference rounded to two decimals. Radius 10–500 km is approximate straight-line distance. Missing locations are excluded only when a radius is selected. Saved criteria, restoration and server alerts use the same distance rule. Live provider checked with Mataró, including the provider’s actual capitalized Municipio response.
3. Seller overview totals real registered views, favorites and conversations from existing metrics; pending incoming offers exclude expired, blocked, held or unavailable vehicles. Unavailable counts are shown as dashes, never invented zero activity.
4. Optional market_facts flows through local account-scoped draft, preview, create, edit, full listing and comparison. Constrained maintenance/ITV/warranty values, validated ITV date, defects ≤1000 chars and approximate location. Unknown fields stay “No informado”. Existing full-row moderation snapshots automatically include these facts. Absent facts preserve the prior publication fingerprint so existing approvals remain valid.
5. Voluntary usage preference defaults off. Only five fixed stages and build 45; no identity, messages, searches or coordinates in the stored table. Client sends at most once per stage/process; server coalesces fast repeats, retains ≤30 days. Moderator-only summary covers 7 days and explicitly does not represent users or conversion rates. Public privacy page updated separately on main, without merging the native branch.

Server activation 20261115132750 authorized by the owner and applied. Isolated SQL tests cover legacy fingerprint compatibility, changed facts, invalid data, western longitudes, missing positions, usage permissions/coalescing and live-session guards. Security advisory warnings unchanged; one new intentionally inaccessible private aggregate table has RLS without a client policy. Device confirmation of the new flows remains pending installation.

Follow-up 20261115133339 schedules daily aggregate retention independently of new activity. The isolated cron fixture checks the scheduled command removes only old counters. Native build 45 compiles commit 92d95d3; the follow-up changes server SQL and documentation only.
