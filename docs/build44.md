# Build 44 — launch improvements

Version 1.0.3+44. Keep the existing public App Store submission unchanged.

1. Offer expiry reminders: one event per pending offer and recipient device during the final two hours. Requires capability registered by build 44, an active session and notification permission. Claims discard answered, countered, cancelled, expired, blocked or unavailable proposals. Creator and older installations are excluded. Existing counteroffer conversation messages continue to notify normally.
2. Accepted offer summary: agreed amount, explicit no-payment/no-sale status, direct visit picker and editable chat message. Sending and accepting a proposal still do not charge or reserve the vehicle.
3. Listing completeness: aligned five-photo/eighty-character recommendations, equipment and maintenance checks, live progress while editing. Suggestions remain optional and do not verify the car.
4. Photo shot checklist: eight named views, manual and optional, stored in the existing account-scoped local draft. It is not image analysis.
5. Sharing: a locally rendered 1080-square PNG with listing photo, model, price and public link, attached to the native share sheet. No VIN, plate or private contact fields are provided to the renderer. Corrupt/unavailable photos fall back to a text card. Web retains explicit share options.
6. Validation: 250 Flutter tests passed; post-adjustment targeted tests also passed. Seven APNs payload/retry/JWT tests and isolated Postgres offer/reminder, account deletion, moderation and profile-authority scenarios passed. No real accounts deleted, no purchases performed, no test listings published and no synthetic notifications sent to real devices.

Server migration 20261115114825 and send-ios-push v7 were deployed after explicit owner authorization. Reminder capability and anonymous access denial verified; security advisor counts are unchanged. Device validation is recorded separately in launch-validation-44.md; real APNs delivery and Apple's purchase sheet still require the owner's iPhones.

Follow-up 20261115115150 queues due reminders before the idle dispatcher checks pending deliveries. Isolated regression starts with no delivery jobs, advances an offer into its reminder window and verifies a single queued reminder and network dispatch. This avoids relying on another chat message to wake the worker.
