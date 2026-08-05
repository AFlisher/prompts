# Store Compliance — Google Play & App Store

**Sprints 1–2.** Companion to `RELEASE.md`. Scope is deliberately narrow: the
legal, account-deletion, purchase and advertising requirements that block
submission. It is not a general launch checklist.

> **How to read this.** §1 is done and in git. §2 and §4 cannot be done from a
> repository — they need a console, a domain, or a decision — and are the
> actual remaining work. §3 is what is still blocking, honestly stated.

---

## 1. Repository changes (complete)

| Requirement | Where it lives | Status |
|---|---|---|
| In-app account deletion (Play data-deletion policy; Apple 5.1.1(v)) | `lib/screens/delete_account_screen.dart`, reached from Profile → Danger Zone | ✅ |
| Backend deletion endpoint | `POST /api/auth/delete-account` (backend repo) | ✅ |
| Public account-deletion URL (Play requirement) | `/legal/account-deletion.html` | ✅ served |
| Privacy Policy URL (both stores) | `/legal/privacy-policy.html` | ✅ served |
| Terms of Service URL | `/legal/terms-of-service.html` | ✅ served |
| App links to the hosted documents, not bundled text | `lib/services/legal_urls.dart`; Privacy screen and paywall footer | ✅ |
| Paywall legal links functional | previously "not available yet" | ✅ |
| iOS permission strings name the app correctly | `ios/Runner/Info.plist` — said "Prombt", now "StyliAI" | ✅ |
| Real Google Play Billing (Sprint 2) | `lib/services/purchase_service.dart`; backend `POST /api/purchases/verify` | ✅ |
| Simulated purchase flow removed (Sprint 2) | `simulated_store_pay.dart` deleted; `CreditManager.addCredits`/`useCredit` deleted | ✅ |
| Purchase restoration (Sprint 2) | paywall footer → `InAppPurchase.restorePurchases()` → server verification | ✅ |
| No Google test ad units in release (Sprint 2) | `lib/services/ad_config.dart` | ✅ mechanism |

**Deletion behaviour, as implemented** — this is what the Data Safety form must
be made to match:

- Erased: profile, name, email, avatar (record and file), every generated image
  and thumbnail (records and files), credits and full transaction history,
  favourites, notifications, feedback, generation history, all sessions.
- Retained: a PII-free record that the deletion happened (`account_deletions`),
  and a short-lived anti-replay ledger entry with the user link removed.
- Immediate, irreversible, no grace period. All devices signed out at once.

---

## 2. Manual console steps (not possible from this repository)

### 2.1 Before anything else — resolve the legal placeholders

The hosted documents ship as **drafts**. Twenty distinct values are marked
`[[PLACEHOLDER: …]]` and must be replaced by the operator:

```bash
grep -rn "\[\[PLACEHOLDER" backend/public/legal/
```

Company facts needed: legal entity name, registered address, privacy contact
email, support email, minimum age, governing law and jurisdiction, liability
terms, applicable privacy regimes and supervisory authority, international
transfer mechanism, backup retention window, personalised-ads answer, and the
production AI provider's name and retention policy.

**Nothing below can be completed until this is done** — every store form asks
for answers these documents are supposed to already contain.

### 2.2 Set effective dates

Each document carries `Effective date: [[PLACEHOLDER: …]]`. Set all three to the
first public release date, and remove the drafting-note blocks.

### 2.3 Google Play Console

- [ ] **App content → Privacy policy** — enter the live `/legal/privacy-policy.html` URL.
- [ ] **App content → Data safety** — declare, at minimum: email, name, photos, app activity, approximate location (country, derived from IP), device identifiers for advertising. Declare that photos are **shared with a third-party processor** for generation. Must match the Privacy Policy exactly; a mismatch is a common rejection.
- [ ] **App content → Data deletion** — choose "app offers both in-app and web deletion" and enter the live `/legal/account-deletion.html` URL.
- [ ] **App content → Ads** — declare the app contains ads.
- [ ] **Content rating** questionnaire — answer consistently with the minimum age set in the Terms.
- [ ] **Target audience** — confirm not directed at children.

### 2.4 App Store Connect

- [ ] **App Privacy** — complete the nutrition label; it must agree with the Data Safety answers and the Privacy Policy.
- [ ] **App Privacy Policy URL** — the live `/legal/privacy-policy.html`.
- [ ] **License Agreement / EULA** — link the live Terms of Service, or accept Apple's standard EULA.
- [ ] Confirm the account-deletion path is discoverable; reviewers check this against Guideline 5.1.1(v). It is at **Profile → Danger Zone → Delete Account**.

### 2.5 Support channel

`support@styliai.app` appears in the app and in the legal documents.
**Confirm this inbox exists and is monitored** — Play expects emailed deletion
requests to be actioned, and the Account Deletion Policy carries a placeholder
for the response-time commitment.

### 2.6 Verify the live URLs

After the backend deploy, from a signed-out browser:

```
https://<production-backend>/legal/privacy-policy.html
https://<production-backend>/legal/terms-of-service.html
https://<production-backend>/legal/account-deletion.html
```

All three must return 200. They are not exercised by any user flow, so nothing
else will notice if they break.

---

## 3. Still blocking submission (outside this sprint)

Stated plainly so the checklist above is not mistaken for "ready to submit".

| # | Blocker | Why it blocks |
|---|---|---|
| H-10 | **Brand split.** `applicationId` is `com.prombt.prombt_app` and the iOS bundle is `com.prombt.prombtApp`, while everything user-facing says StyliAI. | `applicationId` is **immutable once published**. This must be decided before first submission, not after. Permission strings were corrected in Sprint 1; the identifiers deliberately were not, because changing them is a product decision. |

**B-3 (simulated purchases) and B-6 (iOS test ad units) were closed in Sprint 2**
— but both carry console work before they are live. See §4.

---

## 4. Sprint 2 console work (the code is done; these are not)

### 4.1 Google Play — products and verification

The billing integration is complete and refuses to credit anything the Play
API has not confirmed. It cannot work until:

- [ ] **Create the in-app products** in Play Console → Monetise → In-app products. They must be **consumable** (credit packs are re-purchasable).
- [ ] **Set `credit_packs.product_id`** for each pack to the SKU you created. Until then a purchase is refused with `unknown_product` (HTTP 422) rather than granted a guessed amount — deliberately, since guessing would credit the wrong number.
- [ ] **Create a service account** with the *View financial data* and *Manage orders and subscriptions* permissions, link it to the app, and set `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (the whole JSON) and `ANDROID_PACKAGE_NAME` in Railway.
- [ ] **Verify with a licence tester** before release: Play Console → Setup → Licence testing.
- [ ] Confirm `GET /api/purchases/config` reports `{"platforms":{"google":true}}`.

> **The three-day rule.** Google auto-refunds any purchase not acknowledged
> within 72 hours. The backend acknowledges after crediting and records the
> outcome; find anything outstanding with
> `SELECT * FROM processed_purchases WHERE NOT acknowledged;`

### 4.2 Apple — prepared, not active

`src/services/purchases/appleVerifier.js` implements the interface, the error
taxonomy and the claim contract, and **refuses every purchase** until the
signature-chain verification is finished. That refusal is deliberate: a
verifier that decodes a JWS payload without checking its chain accepts anything
an attacker types.

- [ ] Create an App Store Connect API key with the **In-App Purchase** role.
- [ ] Set `APPLE_IAP_KEY_ID`, `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_PRIVATE_KEY`, `APPLE_BUNDLE_ID`.
- [ ] Implement steps 2–4 in that file's header (sign the ES256 JWT, fetch the transaction, **verify the JWS chain against Apple's root CA**).
- [ ] Create the matching consumable products in App Store Connect.

**Setting the four variables alone does not enable iOS purchases** — the
verifier still refuses and logs `apple_verify_not_implemented`.

### 4.3 AdMob — iOS

`AdConfig` refuses to return a Google sample unit in a release build. Android's
production unit is committed; iOS has none, so **iOS release builds have
rewarded ads disabled** rather than serving test ads that earn nothing while
still granting credits.

- [ ] Create the iOS AdMob app and rewarded unit.
- [ ] Build with `--dart-define=ADMOB_IOS_REWARDED_UNIT_ID=ca-app-pub-…/…`.
- [ ] Replace `GADApplicationIdentifier` in `ios/Runner/Info.plist` — it still carries Google's sample App ID. The runtime guard means no test *ad unit* can serve, but the App ID itself is a build-time plist value and must be swapped by hand.
