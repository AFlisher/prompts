# Store Compliance — Google Play & App Store

**Sprint 1.** Companion to `RELEASE.md`. Scope is deliberately narrow: the
legal and account-deletion requirements that block submission. It is not a
general launch checklist.

> **How to read this.** §1 is done and in git. §2 cannot be done from a
> repository — it needs a console, a domain, or a decision — and is the actual
> remaining work. §3 is what is still blocking, honestly stated.

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
| B-3 | **Simulated in-app purchases.** The paywall shows a fake Apple/Google purchase sheet and grants credits that exist only in device memory. | Violates App Store 3.1.1 and Google Play Payments policy. Imitating the stores' own purchase UI risks account termination, not just rejection. **The paywall must be hidden or the flow replaced with real IAP before any submission.** |
| B-6 | **iOS ships Google's test AdMob IDs.** `Info.plist` `GADApplicationIdentifier` and the iOS rewarded unit in `ad_service.dart` are both Google's public sample IDs. | Zero iOS ad revenue, and test ads in production. iOS-only. |
| H-10 | **Brand split.** `applicationId` is `com.prombt.prombt_app` and the iOS bundle is `com.prombt.prombtApp`, while everything user-facing says StyliAI. | `applicationId` is **immutable once published**. This must be decided before first submission, not after. Permission strings were corrected in this sprint; the identifiers deliberately were not, because changing them is a product decision. |

Sprint 1 removed the legal and deletion blockers. These three remain, and B-3
is the one that would turn a rejection into an account-level problem.
