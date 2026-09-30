# Staging Apple association repair

Staging content verified through the founder's follow-up screenshot: the exact `.well-known` association URL now displays the expected JSON, replacing the earlier 404 page. The app ID and `/invite/*` scope match the prepared file. The founder's File Manager screenshot established `staging3.countingsheepproject.com/public_html` as the staging root. HTTP status, headers, redirect chain and Apple retrieval remain unverified; the agent's browser access is still blocked. Live installation remains pending.

`apple-app-site-association` is an extensionless JSON file matching theme 3.4.1, the app's configured Team ID, bundle ID and `/invite/*` scope. It contains no credentials or party data. A standalone file lets the web server serve the association without reaching WordPress.

## Staging installation

1. Open SiteGround **Site Tools → Site → File Manager**. Identify the document root for **staging3.countingsheepproject.com**; do not assume the selected `public_html` belongs to staging.
2. In that root, open `.well-known`, or create it if absent. Preserve any existing files, especially certificate validation files. If an association file already exists, inspect and preserve it before deciding whether replacement is appropriate.
3. Upload the adjacent `apple-app-site-association` file into `.well-known`. Keep its exact filename, without `.json` or `.txt`. This is a document-root file, not a theme or WordPress Media Library upload.
4. Reload the same staging association URL. It should return the JSON directly. Confirm HTTP 200 and `Content-Type: application/json`, with no redirect. If SiteGround still intercepts the path or returns a different content type, request a change scoped to this file through its hosting configuration/support. Do not replace the site's `.htaccess` or remove staging authentication as a shortcut.

Staging remains protected and is not an app entitlement domain. This check validates hosting, not Apple CDN retrieval or physical Universal Links. No staging database, theme replacement or plugin installation is needed for this file.

## Live gate

After staging passes and live scope is approved, the same file must be directly accessible over HTTPS on **both** `countingsheepproject.com` and `www.countingsheepproject.com`, matching the app entitlements. The site's normal www-to-apex redirect must not redirect the association file. Production must return HTTP 200 and JSON without authentication. Validate the signed app on a physical iPhone separately. No live upload or hosting configuration change has been performed.

Rollback is limited to this file: preserve any previous content, and restore it if necessary. Do not remove the entire `.well-known` folder.

Sources: [Apple associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains), [Apple Universal Link debugging](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links), [SiteGround File Manager](https://www.siteground.com/kb/manage-files-file-manager/).
