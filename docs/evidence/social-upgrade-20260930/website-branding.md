# Invitation website branding — 30 September 2026

The founder requested consistency with the Counting Sheep website's logo, typography and copy, and clarification that invitation review and joining belong in the iOS app. The website is the shareable-link fallback; it does not retrieve private group details or join a group.

## Source and package

Updated `invitations.php` and `style.css` in the companion website theme. The page now uses the existing `logo_with_text.png` wordmark, the existing Nunito font loader, shared Georgia heading rules, brand color variables and rounded button/link classes. Page-specific layout is scoped to `.cs-invitation`. It prints the selected shared styles without the site's general plugin/script hooks.

Copy uses the website's “put your phone to bed” language, states that review happens on an iPhone, labels the primary action “Open invitation in app”, and explains that group/sharing review precedes joining. The incomplete-link branch retains a clear recovery instruction. The existing launch-state CTA still chooses TestFlight/App Store/early access from the site's settings.

Theme **3.4.2 is installed on staging**, confirmed by the founder’s WordPress success screenshot (`output/validation/social-upgrade-20260930/staging-3.4.2-installed-user.png`). It is not installed on live. Package: `output/validation/social-upgrade-20260930/counting-sheep-invitations-3.4.2.zip` in the app repository. SHA-256: `f144049c384b9e8d9a3e90d6ab86cb6131106a58dc76ec3de1704725790e2cfc`.

The ZIP contains the same 58 runtime paths as staged 3.4.1. Only the invitation template and stylesheet differ. The original 3.4.1 ZIP remains intact for staging rollback. The separately installed `.well-known/apple-app-site-association` file is outside the theme and is unchanged.

## Validation

- Founder screenshots confirm 3.4.1's incomplete-link message and readable narrow layout. Its Copy action was already confirmed by the pasted sample. Homepage navigation was not confirmed.
- Generated isolated static complete/incomplete render fixtures from the edited PHP markup, using the actual stylesheet and logo. Served only those local files with `python3 -m http.server 8768 --bind 127.0.0.1 --directory /tmp/counting-sheep-invitation-brand-preview`; did not access the blocked staging site.
- Chrome local preview: widths **320, 390, 768 and 1440** had equal viewport/page widths and no measured clipping of links, buttons, headings, paragraphs or the code. Primary/Copy controls measured 51–52 CSS pixels tall. Body and heading computed fonts were Nunito and Georgia respectively; logo loaded successfully.
- Complete-page Copy showed the live status, then pasting into an isolated local textarea produced exactly `ABCDEFGHJKLM`. Keyboard Tab reached Copy with a visible 3px outline. The browser tool's clipboard-read helper returned an empty string, so verification used actual paste rather than that helper.
- Incomplete preview at 390px contains no custom-scheme action, invitation code or Copy control. Both states were visually inspected. Screenshots and layout measurements are in `output/validation/social-upgrade-20260930/`.
- `node --check` passed for the extracted Copy script. Package comparison confirms route validation, response headers and Copy JavaScript are byte-identical to 3.4.1. ZIP integrity and `git diff --check` passed.
- The first local packaging check reused mutable ZIP entry metadata and failed when rereading an entry. Packaging was repaired to copy the metadata, rerun successfully and checked against the unchanged original package hash. No deployment occurred during this repair.

No PHP runtime or local WordPress installation is available. The static fixtures verify the rendered design and browser behavior, not PHP execution or WordPress stylesheet loading. Check the installed staging revision on both routes, logo/font/style loading, Copy, the homepage link and association HTTP headers/status/redirects before live publication. Existing browser-tool permission enforcement still blocks automated staging access.

## App versus website

App source already handles the HTTPS and custom-scheme invitation URLs, preserves the code for onboarding, and opens the app's join/review flow. Handle invitations and membership/sharing decisions remain in the app. After the live association endpoints and updated signed app are deployed, supported link taps on an installed iPhone can open the app directly; the web page handles desktop, app-not-installed and browser fallback cases. Staging is not listed in app entitlements. Physical Universal Links and APNs remain unverified.

Reference: [Apple's Universal Link behavior](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content).

## Theme author display follow-up

Removed Author and Author URI from the theme header at the founder’s request; version 3.4.3 is packaged locally, not uploaded. License fields remain unchanged. Only `style.css` differs from 3.4.2, limited to those metadata fields and the version. All 58 runtime entries match the prior manifest; ZIP integrity passed. Package: `output/validation/social-upgrade-20260930/counting-sheep-invitations-3.4.3.zip`; SHA-256 `bcbdcb564454fe55446df3ba2137be4fc2ce94b99098f9c7f23761ad29cc1ce7`. Upload and page-level staging validation remain pending.

## Author update — 3.4.4 prepared

The founder superseded the blank author choice with `Author: Ngawang Chime`. Theme 3.4.4 is the current upload package; 3.4.3 is superseded. Only the author field and version differ from 3.4.3, with no Author URI added. Package: `output/validation/social-upgrade-20260930/counting-sheep-invitations-3.4.4.zip` in the app repository; SHA-256 `4c5278de55a258b4ef07a8e1e93a478fbd2a96fd587675fd66435faeb8c45092`. All 58 runtime entries and ZIP integrity verified; only style.css changed. Prepared locally, not uploaded. Last confirmed staging installation remains 3.4.2; staging page validation and live publication remain pending.
