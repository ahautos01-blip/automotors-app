# AUTOMOTORS 1.0.3 (38)

- Message notification routes wait for sign-in; duplicate route history is bounded.
- Buyer pushes respect saved-search/favorite preferences, visibility, blocks, suspensions, live sessions and read state. Lock-screen copy excludes messages and private searches. New device registration declares route support; older builds retain their original API.
- Account-scoped publication drafts persist photos in application support. Relative photo filenames survive iOS app container moves. Saves are serialized, backgrounding saves immediately, and successful submission clears local copies.
- Photo selection uses native resizing to 1600px at quality 72, with a 6MB/photo ceiling. Galleries show partial results with up to three simultaneous downloads.
- Empty results offer explicit price expansion, query removal, filter reset and saved alerts.
- Seller advice combines real aggregate activity with optional listing-completeness tips and an edit action.

Validation: 222 Flutter tests, isolated Postgres alert integration, five APNs payload/signing tests, focused analysis. Production worker health check returned HTTP 200 with zero jobs; security advisory counts unchanged. Physical iPhone testing of push delivery and terminated-app recovery is still required on the new build.
Public review build 36 remains separate.
