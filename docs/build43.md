# Build 43 — counteroffers and 24-hour validity

- The recipient of a pending offer can propose a different amount directly from the chat or proposal history. The dialog states the replacement and requires explicit submission.
- Server atomically marks the previous offer `countered` and creates one new pending offer linked by `reply_to`, with the responding participant as creator. Buyer and seller may alternate. Old proposals, self-counteroffers, equal/invalid amounts, outsiders, blocked/revoked sessions and expired proposals are rejected.
- New offers and counteroffers expire exactly 24 hours after creation. Existing pending offers are capped at their original creation plus 24 hours; accepted/rejected/cancelled history is unchanged. Visits keep their existing schedule rules.
- Pending proposals show remaining hours/minutes. Expired offers lose accept/reject/counter controls locally; server time remains authoritative.
- Conversation messages and the existing chat notification path cover new counteroffers and responses. No listing is reserved/sold and no payment is performed on acceptance.
- ES/EN/CA copy included. Diagnostic build 43 supported.

Validation: 25 focused Flutter tests pass, including editable counteroffer submission, own-offer controls, exact local expiry boundary and hidden expired actions. Isolated Postgres test covers pending migration cap, 24-hour duration, seller and buyer counter rounds, stale proposal rejection, one pending offer, acceptance, server expiry, blocked users, messages and prior access/reminder regression checks. Physical TestFlight negotiation remains to be checked by the owner.
