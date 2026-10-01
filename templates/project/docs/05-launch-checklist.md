Status: TEMPLATE
<!-- Template v2.4. Release gate. Claude PROPOSES project additions and removals; the user approves each change. -->

# <Product name> - Launch Checklist

Mark each item **Pass / Fail / N/A** with evidence: test output, tool output, file:line or a screenshot.
An item with no evidence counts as Fail.
Sections A and B are blocking: a release cannot ship with a Fail in them.
Record each run in the audit log at the bottom and a line in MEMORY.md.

## A. Correctness and traceability (blocking)
- [ ] A1. The full test suite is green on main, and CI is green on main.
- [ ] A2. The regression gate (CLAUDE.md section 2) passes.
- [ ] A3. Every REQ-ID has at least one passing test (traceability audit).
- [ ] A4. Every acceptance criterion in 01-prd.md section 9 is demonstrated.
- [ ] A5. No skipped, disabled or quarantined tests without an open Issue.
- [ ] A6. No open Critical or High BUG Issues.
- [ ] A7. Every merged REQ-ID and BUG-ID has `docs/reviews/<ID>.md` with `Verdict: APPROVE`. Tool: `bash scripts/req_status.sh` (Review column).

## B. Security and privacy (blocking)
- [ ] B1. No secrets in code, history or frontend bundles. Tool: gitleaks / grep.
- [ ] B2. Every external call, CDN and service matches the list in 02-architecture.md section 6. Tool: grep for `http`.
- [ ] B3. HTTPS enforced, HSTS on, no mixed content.
- [ ] B4. All user input validated on the server, and output escaped (no XSS or injection).
- [ ] B5. Auth and authorisation: each role sees only what it should.
- [ ] B6. Dependencies have no known high or critical vulnerabilities. Tool: `npm audit` / `pip-audit`.
- [ ] B7. Privacy: the data collected is listed, a privacy notice exists if personal data is stored, and consent is in place if cookies or tracking are used.
- [ ] B8. Logging contains no passwords, tokens or personal data.

## C. Input validation and error handling
- [ ] C1. Forms validate on the client and the server, with clear messages.
- [ ] C2. Spam or abuse protection on public forms (rate limit, captcha or honeypot).
- [ ] C3. External service failure shows a helpful fallback, never a blank screen.
- [ ] C4. A custom 404 and error page exist.
- [ ] C5. The app still works when browser storage is blocked or cleared.

## D. Accessibility
- [ ] D1. Colour contrast meets WCAG AA in light and dark. Tool: axe-core / Lighthouse.
- [ ] D2. Colour is never the only signal.
- [ ] D3. Fully keyboard usable, with visible focus.
- [ ] D4. Images have alt text; icon buttons have `aria-label`.
- [ ] D5. `prefers-reduced-motion` respected; dialogs trap focus and close with Esc.

## E. Performance
- [ ] E1. Lighthouse performance score at least 90 on mobile.
- [ ] E2. Images compressed and sized; modern formats where possible.
- [ ] E3. No unused libraries; bundle size recorded.
- [ ] E4. Load tested at the expected scale from 01-prd.md.

## F. Responsiveness and layout
- [ ] F1. No horizontal scroll at 375, 768 and 1280 px. Tool: Playwright screenshots.
- [ ] F2. Touch targets at least 44 px on mobile.
- [ ] F3. Print view readable where users will print.

## G. Usability and content
- [ ] G1. One clear primary action per screen.
- [ ] G2. Every screen has empty, loading and error states (03-ui-design.md section 6).
- [ ] G3. No broken links. Tool: link checker.
- [ ] G4. Copy reviewed for spelling and plain language.
- [ ] G5. Tested with at least one real user.

## H. Discoverability and housekeeping
- [ ] H1. Page titles, meta descriptions and a favicon set.
- [ ] H2. Social preview image (public sites only).
- [ ] H3. `sitemap.xml` and `robots.txt` (public sites) or `noindex` (internal tools).
- [ ] H4. Analytics set up and disclosed (public sites), or confirmed absent (internal or air-gapped).
- [ ] H5. Terms and conditions (public products).
- [ ] H6. Version and build date visible; CHANGELOG generated.
- [ ] H7. TASKS.md and MEMORY.md updated for the release.

## Not applicable for this project
<!-- List items removed, with the reason, so the decision is visible. -->
| Item | Reason |
|---|---|

## Audit log
| Date | Version | Auditor | Blocking fails | Other fails | Notes |
|---|---|---|---|---|---|
