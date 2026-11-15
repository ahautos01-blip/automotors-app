# Validation before public launch — build 44

Automated checks use fake accounts and isolated data. They are not a substitute for physical iPhone and Apple transaction verification.

| Flow | Automated evidence | Device check still required |
| --- | --- | --- |
| Registration/email verification | email_confirmation_service_test, email_confirmation_login_test, full localization suite | Register a disposable account, open the real verification email and check return to the app. |
| Password recovery | password_recovery_test, market_recovery_test | Request a recovery email and finish from the iPhone. |
| Publish/photo draft | content_publication_test, vehicle_design_layout_test, content_moderation.integration | Check saved photo checklist, preview and moderation with your own authorized car. |
| Chat/offers/counteroffers | chat_offer_entry_test, chat_offer_panel_test, chat_market_actions.integration | Buyer sends, seller counters, buyer accepts; both see the agreement and history. |
| Visits/reminders | isolated proposal/reminder queue and APNs payload tests | Agree a visit and check actual notification permissions and delivery. |
| Expiry reminder | duplicate, recipient, old-device and cancelled-proposal exclusions in isolated SQL | Receive one alert in the final two hours of a still-pending test offer; no alert after responding. |
| Sharing | PNG dimensions, correct photo pixels, invalid-photo fallback tests | Open share sheet and inspect photo, price and link in a chosen destination. Sharing remains the user's action. |
| Purchases/restoration | app_store_readiness_test, verified_store_plans_test, Spanish price and verifier-error tests | Use Apple's test purchase flow; compare the displayed price/period and restore the entitlement. |
| Account deletion | confirmation/cancellation UI and account_deletion.integration | Only a disposable non-administrator account: confirm deletion and check sign-in is denied. |
| Privacy/report/block | readiness, chat safety, moderation and authority tests | Check public support/privacy links and report/block from two test accounts. |

Do not use an administrator or the Apple review account for deletion. Preserve the current App Store review while build 44 is tested internally.
