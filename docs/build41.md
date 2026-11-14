# Build 41 — visible chat offers

Version 1.0.3+41. Leaves the current App Store review unchanged.

- Full-width labeled offer action inside each vehicle conversation, below its header.
- Buyers open the amount dialog directly after server-confirmed participant access. Sellers open the proposals history.
- Initial dialog opens once; refresh/polling does not reopen it. A tap never submits an offer automatically.
- Buyer/seller quick replies and viewing text differ in Spanish, English and Catalan.
- Diagnostics records build 41. Server accepts builds 40 and 41 with unchanged session checks, access and aggregate-only fields.

Validation: 19 targeted Flutter tests pass, including authenticated buyer direct entry, confirmation before writes, no repeat on refresh, and seller cannot open a buyer form. Isolated Postgres integration passes participant access, proposal states, reminders, diagnostics and revoked sessions. Analysis has no errors; existing style warnings remain.

Physical TestFlight check still required with buyer and seller accounts.

## Server follow-up: history loading

Production logs showed SQLSTATE 42702: `a.*` was ambiguous between a PL/pgSQL record and the history table alias. History loading failed, so the client hid the composer. A server-only replacement uses the unique `history_item` alias and qualifies history columns. Build 41 needs no replacement.

The isolated regression now first verifies that the original authorized list fails with 42702, then applies the follow-up and verifies empty history and populated buyer/seller history. Existing participant, blocked-user and revoked-session tests still pass. Production function and unchanged anonymous/authenticated grants verified. Physical client retest requested.
