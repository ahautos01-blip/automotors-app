# AUTOMOTORS 1.0.3 (39)

- The empty catalogue offers publication and saved searches. A failed catalogue load has a separate retry state.
- Publication opens the form directly when the account has capacity; optional plans remain available separately. Viewing plans from a draft cannot start a second publication form.
- A buyer-facing preview precedes every new listing submission. It supports explicit confirmation or return to editing and respects registration/VIN visibility. No listing is inserted before confirmation. Double preview taps are guarded.
- Contextual help explains identifier visibility, phone privacy, account limits, subscription renewals and the limits of paid visibility.
- Moderator overview groups open reports, server drafts/paused listings and pending/failed publication checks. Only existing moderators with live sessions can access the read-only RPC. Up to 100 recent checks link to existing reports where available; no automatic approval or suspension is introduced.
- Accessibility improvements include explicit password and photo action labels, wider minimum button targets, readable status colours and wrapping status labels. New flows pass 320px layout checks at 200% text in Spanish, English and Catalan, plus touch-target, label and contrast guidelines for launch actions.

Validation: 229 Flutter tests, isolated Postgres overview access tests, focused static analysis, production function guard and unchanged advisory counts. Physical VoiceOver testing of the whole application remains a device check; automated checks do not replace it.
Public App Store submission build 36 remains separate.
