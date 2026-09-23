# Account feedback, handles and search collapse

Date: 21 September 2026. Source implemented; app distribution and physical-device acceptance remain separate.

## Account connection

The reported Profile conflated Apple authentication with completed Farm activation: a Farm lookup failure left `signedIn` false, so successful Apple authentication still appeared as Guest with the Apple button. Record verified authentication separately for presentation. Keep Farm activation, ownership fences and completion callbacks behind the existing atomic account connection. A pending connection now replaces sign-in controls with a confirmation, preserved-local-Farm explanation and Retry Farm connection. Sign-out clears the presentation identity. This does not identify the specific hosted failure in the screenshot; retain support details and investigate actual device diagnostics if it recurs.

Credential-only refresh also set the Farm presentation to Checking without restoring its prior state. The shared operation wrapper now restores that prior presentation when the operation has not published a replacement.

## Handle

Handle and username are one identifier, separate from the editable Shepherd display name and immutable account UUID. Profile displays the handle with Copy handle, or a direct Choose a handle entry. Failed metadata lookup offers Load handle rather than implying no handle exists. Apple sign-in does not automatically claim a handle. Existing Apple users choose one in Profile; password registration already collects one.

The deployed database stores one handle per user and a unique normalized username. Names are lowercase ASCII, 3–24 characters, begin with a letter, and otherwise use letters, digits or underscores. Claims are immutable and concurrent duplicate claims are rejected by the database unique constraint. The app now translates taken/already-claimed errors into specific feedback. No migration or production mutation was needed for this repair.

## Ollie's next search

The founder clarified that the expanded card cannot collapse on iPhone 16 Pro. Previously only the text header toggled expansion; the trail was a separate noninteractive sibling and long content could move the header offscreen. Use one native button for the summary and trail, plus a 44-point Show less button after the details. Both call the same state toggle, with Reduce Motion respected. Keep art out of hit testing/accessibility and preserve spoken expanded/collapsed state. No device-specific branching.

See [validation and screenshots](../../output/design/account-search-repair-20260921/README.md).
