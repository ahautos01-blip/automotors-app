# Build 46 — responsive subscription checkout

Version 1.0.3+46; keep the public App Store submission unchanged.

Packs and subscription on the home page now opens the plan catalogue directly. It no longer runs the free-publication eligibility check or opens AddCarPage instead. The catalogue-only header is “Packs y suscripción”.

“Elegir” previously had a null callback while store products or period/currency metadata were unavailable. Its explicit yellow style could still make it look active. It now always routes through an authenticated purchase action, reloads a missing product, exposes loading/opening states and offers a catalogue refresh. Actual checkout still requires a known store product, valid period and acceptable Spanish pricing metadata. The actual release workflow already has AUTOMOTORS_ENABLE_STORE_CHECKOUT=true; no payment or entitlement protection was disabled.

Store availability/product exceptions are caught and explained. A concurrent load is shared; repeated taps during the native start produce at most one request. A user/account change during loading aborts the request, and late catalogue responses after disposal cannot write to closed UI streams. A native false return or thrown error produces a message instead of silence. Server transaction verification remains the sole source of entitlements. No real purchases performed.

Regression coverage uses an injected fake Apple store for query failure/retry, late disposal, lazy product fetch, duplicate taps, missing billing metadata, unknown IDs and rejected native starts. The home navigation test exercises catalogue access even when the publication RPC permits free listing. The fixture closes its own WebSocket transport explicitly. Production build arguments are used for the purchase tests.

Migration 20261115141556 adds build 46 only to the existing diagnostic and voluntary usage allow-lists. Auth checks, grants, retention and the disabled-by-default usage preference are unchanged. Isolated SQL tests and deployed-function/anonymous-denial metadata checks passed.

Device verification: update from TestFlight, open Packs y suscripción, choose a plan and confirm that Apple's sheet appears. Cancel the sheet; a real purchase is not required for this check.

Validation: 266 Flutter tests passed with checkout enabled, plus isolated SQL coverage. Analysis has no compiler errors; pre-existing warnings remain. The purchase-start spinner is shown inside each disabled purchase button as well as the page status, so feedback remains visible next to the tapped plan.
