# AUTOMOTORS 1.0.4 (57)

Inicio reserves space above the navigation bar so the publication action remains tappable. Seller contact uses the WhatsApp mark.

Listing municipality is server-derived from the owner's profile. Profile municipality changes update all of that seller's listings, retaining statuses and content approvals. Public listing data contains city/province and optional rounded municipality coordinates; it never copies a postal address. Old independent listing coordinates are ignored when the derived profile location is available. Select a municipality in profile settings to enable radius matching; a typed city alone has no invented coordinates.

Search includes an accessible “Usar mi ubicación” action beside manual locality selection. An explanation precedes the native iOS permission. Declining leaves manual search available. CoreLocation requests a single foreground fix at three-kilometre desired accuracy; coordinates are rounded to two decimals before crossing to Dart. It does not update the public profile or listing location. Saving a search explicitly may retain its approximate search origin under existing saved-search permissions. No background tracking or reverse geocoding is added.

Server checks: profile-location integration covers ownership, synchronization, forged location input, private addresses, stale coordinates, moderation enforcement and hash compatibility. Production backfill retained the existing published listing and its fingerprint. Security advisor findings match the prior baseline.

Before App Store submission, review the existing approximate-location privacy disclosure against this optional search use. Physical iPhone acceptance remains necessary: allow/deny location, search radius, profile municipality updates, publication CTA and WhatsApp contact. Flutter tests do not replace native device acceptance.
