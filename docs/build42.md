# Build 42 — offers received inside the conversation

- An inline chat card shows the pending offer (or latest offer status), authoritative amount and status. Only the other participant sees accept/reject, with confirmation and server validation.
- Refreshes every 10 seconds while active, and after returning from proposal creation. Clears proposals on access failure or restriction. The card scrolls for large text and yields space to the keyboard.
- New offer/state events create a normal chat message in the same transaction. This uses existing unread badges, conversation update and chat notification delivery, including devices without the new market capability. It avoids duplicate market push notifications for offers; visit notifications remain unchanged.
- Existing proposals remain available; no historical messages are synthesized or offers accepted on deployment.
- Build diagnostics accepts 40, 41 and 42 with unchanged access controls.

Validation: 22 targeted Flutter tests pass. Isolated Postgres checks create, recipient visibility, accept/reject, ordinary unread messages, notification queue for an older device, no duplicate market push, and existing access/state/reminder checks. No real offer is submitted or answered by automated tests. Physical seller/buyer TestFlight validation remains required.
