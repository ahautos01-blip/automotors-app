# iPhone interaction polish

This change builds on release 54's editorial design. It does not claim to reproduce a particular iOS release or guarantee a frame rate without device profiling.

- Floating, clipped navigation surface with a single bounded backdrop blur. The body extends behind it; Scaffold's inherited bottom padding keeps the final content reachable.
- Opaque navigation when increased contrast, accessible navigation or reduced motion is requested. Text and actions retain the existing contrasting brand palette and padded tap targets.
- Explicit Cupertino page transitions for iOS/macOS, retaining interactive back navigation, and shared brand colors for Cupertino controls.
- Catalogue metadata becomes visible before cover downloads complete. Cover downloads use batches of three, retain listing order, tolerate failed images and discard obsolete results after navigation or a new load.
- Existing session-scoped photo cache, Storage reads and access policies remain unchanged. No database deployment is required.

Validation: widget checks cover ordered bounded downloads, obsolete loads, accessible navigation, catalogue layout and existing gallery/cache behaviour. The catalogue preview is rendered from actual Flutter widgets with test data and a Windows preview font; it is not a physical iPhone capture.

Before distribution: profile scrolling and gestures on a physical iPhone in profile/release mode, including weak connectivity, enlarged text, reduced motion and an inventory with many photos. Local tests do not establish 120 fps or the final appearance on an iOS device.
