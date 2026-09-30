# Play Store launch runbook

App id: `com.graziastones.grazia_stones` · Launch mode: **quote enquiry only (no payments)**

## A. One-time signing setup (on your own machine)
1. `./scripts/generate_upload_keystore.sh` → creates `~/grazia-stones-upload.jks` (+ a local, gitignored `android/key.properties`).
2. **Back up the `.jks` and its password** (password manager + offline copy). Never commit or share them in chat.
3. `base64 -w0 ~/grazia-stones-upload.jks` (macOS: `base64 -i ~/grazia-stones-upload.jks`) → copy the output.
4. GitHub repo → Settings → Secrets and variables → Actions → add:
   | Secret | Value |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | the base64 text from step 3 |
   | `ANDROID_KEYSTORE_PASSWORD` | keystore password |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `ANDROID_KEY_PASSWORD` | key password (same as keystore password if you used the script) |
   | `PLAY_SERVICE_ACCOUNT_JSON` | *(optional, only for auto-upload)* Play API service-account JSON |

## B. Build the signed bundle
GitHub → Actions → **Android Release** → *Run workflow* → download the `grazia-stones-release-aab` artifact (`app-release.aab`).
Each Play upload needs a higher `build_number` (defaults to the workflow run number).

## C. Play Console (only you can do these)
1. Create app → name "Grazia Stones", default language, App (not game), Free.
2. **First upload is manual**: Testing → Internal testing → Create release → upload the `.aab`. (Enrol in *Play App Signing* when asked — recommended.)
3. Add testers (an email list) and share the opt-in link.
4. App content: privacy policy URL, Data safety form (collects: name, phone, email, location for dealer search, photos for AI Room Studio, account deletion supported in-app), content rating questionnaire, target audience (18+), ads = No, permissions declaration for Camera/Location.
5. Store listing: short + full description, 512×512 icon, 1024×500 feature graphic, ≥2 phone screenshots.
6. **New personal developer accounts** must run a closed test with 12+ testers for 14 days before Production. Organisation accounts are exempt.

## D. Before you go to Production
- Smoke-test on a real Android phone: launch, browse, stone → quote request submit, cart → quote, AR (camera permission), account delete.
- Confirm real values still placeholders: quote-PDF GSTIN, and the cart's 18% GST / ₹500 shipping rules with the client.
