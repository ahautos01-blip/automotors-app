# Build 41 — visible chat offers

Version 1.0.3+41. Leaves the current App Store review unchanged.

- Full-width labeled offer action inside each vehicle conversation, below its header.
- Buyers open the amount dialog directly after server-confirmed participant access. Sellers open the proposals history.
- Initial dialog opens once; refresh/polling does not reopen it. A tap never submits an offer automatically.
- Buyer/seller quick replies and viewing text differ in Spanish, English and Catalan.
- Diagnostics records build 41. Server accepts builds 40 and 41 with unchanged session checks, access and aggregate-only fields.

Validation: 19 targeted Flutter tests pass, including authenticated buyer direct entry, confirmation before writes, no repeat on refresh, and seller cannot open a buyer form. Isolated Postgres integration passes participant access, proposal states, reminders, diagnostics and revoked sessions. Analysis has no errors; existing style warnings remain.

Physical TestFlight check still required with buyer and seller accounts.
