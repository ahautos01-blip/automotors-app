# 1.0.4 (52): searchable vehicle reference catalogue

All four categories have searchable make/model selectors in publication and catalogue filters. The homepage category selector precedes the editorial header, displays all four categories without horizontal scrolling, and uses prominent selected states. Compact catalogue headers retain a two-by-two selector on narrow screens.

## Reference data

The bundled catalogue contains 76,550 model/version names across category-specific make lists: cars 344 makes / 58,018 model and version references; motorcycles 1,722 / 10,792; trucks 233 / 2,137; boats 388 / 5,603. Makes overlap categories. These are reference suggestions, not a guarantee of exhaustive worldwide coverage or current availability.

Sources:

- US NHTSA vPIC manufacturer-submitted reference names: <https://vpic.nhtsa.dot.gov/api/>. Imported by vehicle type; 2,215 cached make/type model requests completed without failures.
- Spain's official 2026 reference, Order HAC/1501/2025: <https://www.boe.es/eli/es/o/2025/12/17/hac1501/dof/spa/html>. Passenger car model/version names and recreational boat make/model names only; no tax values, year ranges or technical claims imported. Motorhome and generic engine/capacity tables excluded.
- Existing AUTOMOTORS catalogue: all 52 makes and 1,500 model names retained. Runtime server records take precedence, preserving their foreign keys.
- Maintained European, historic and marine supplements in `assets/vehicle_catalogue_seed.json`. Manufacturer range references include Honda España, Mercedes-Benz Trucks España, OMODA/JAECOO España, Beneteau, Saxdor, Prestige and Belliure.

`tool/import_vehicle_catalogue.py` refreshes vPIC with a bounded cache and retry policy. `tool/import_spain_catalogue.py` imports the downloaded official 2026 HTML with assertions for that edition's table boundaries. Raw downloads stay in ignored `tool/catalog-cache/`. Only the reviewed compiled JSON is bundled; the app performs no external reference-data requests.

## Publication and compatibility

Local suggestion IDs never become database foreign keys. Existing car references retain real IDs; added references and “Other make/model” use the existing declared-name fields. The migration allows complete free-name pairs for cars too, with the same length limits. Owner access, blocking, suspension and mandatory moderation remain unchanged. Declared names are covered by moderation text and content fingerprints.

Drafts restore category and names, rather than relying on transient suggestion IDs. Server reference queries paginate in batches of 500, avoiding the previous 1,000-row truncation. Bundled data remains available if reference requests fail.

## Validation

- Full Flutter suite: 307 tests passed before the final official Spanish data enrichment.
- After official Spanish enrichment: 19 targeted catalogue, category, homepage and narrow-screen tests passed. Earlier publication/draft tests also passed.
- SQL integration: existing car fingerprint preserved; custom car insertion allowed for its owner; partial/negative IDs and blank names rejected; another user cannot edit it.
- Actual homepage widget preview inspected at 430 × 932; no fabricated inventory displayed.
- Build 52 diagnostic and optional usage allowlists retain existing access/session checks.

Release handling: preserve the pending App Store review of 1.0.3 (49). Build 52 is a separate TestFlight build.
