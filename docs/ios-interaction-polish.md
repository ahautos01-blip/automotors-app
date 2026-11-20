# iPhone interaction polish

This change builds on release 54's editorial design. It does not claim to reproduce a particular iOS release or guarantee a frame rate without device profiling.

- Floating, clipped navigation surface with a single bounded backdrop blur. The body extends behind it; Scaffold's inherited bottom padding keeps the final content reachable.
- Opaque navigation when increased contrast, accessible navigation or reduced motion is requested. Text and actions retain the existing contrasting brand palette and padded tap targets.
- Explicit Cupertino page transitions for iOS/macOS, retaining interactive back navigation, and shared brand colors for Cupertino controls.
- Catalogue metadata becomes visible before cover downloads complete. Cover downloads use batches of three, retain listing order, tolerate failed images and discard obsolete results after navigation or a new load.
- Existing session-scoped photo cache, Storage reads and access policies remain unchanged. The visual changes need no schema changes; release migrations only register build numbers in the existing diagnostic and voluntary usage counters.

## Whole-app continuation (56)

Release 55 was the navigation/performance foundation. Release 56 extends the visual language across all 30 route app bars: home, catalogue, listing details, publication, plans, chats, offers, profiles, saved items, account recovery/deletion, support and moderation. The dark full-screen photo viewer retains a black background and white controls.

The shared theme now supplies rounded grouped surfaces, subtle card depth, tonal fields, capsule buttons/chips, segmented tabs and rounded menus/dialogs/sheets. Category and plan selections animate with reduced-motion support. Listing contact, chat composition, plan purchase and publication actions share inset action docks. Profile tabs and the empty inbox follow the same surface language. No purchase, moderation, messaging or account permission flow is changed.

Preview assets cover Home, Plans, Publication, Profile, Listing and Inbox using actual widgets and synthetic/empty data. Preview fonts are test-only substitutes. Device validation is still required for optical blur and scrolling performance.

Validation: widget checks cover ordered bounded downloads, obsolete loads, accessible navigation, catalogue layout and existing gallery/cache behaviour. The catalogue preview is rendered from actual Flutter widgets with test data and a Windows preview font; it is not a physical iPhone capture.

Before distribution: profile scrolling and gestures on a physical iPhone in profile/release mode, including weak connectivity, enlarged text, reduced motion and an inventory with many photos. Local tests do not establish 120 fps or the final appearance on an iOS device.
