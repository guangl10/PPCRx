# PPC-Rx v0.2.1 — Usability sprint (locked decisions)

Source: external review (Claude) + product alignment, June 2026.  
Goal: ease of use 3/5 → 4/5; practicality (no data loss on refresh).

---

## Priority order

1. End session bundle (+ disclaimers, fuse hard block)
2. localStorage draft save/restore (7-day expiry)
3. PCSS delta mode (no Quick 6-item mode)
4. Mobile CSS (Progress tab + sticky target HR banner)
5. CSV import: minimal Profile auto-fill

---

## A. localStorage

**Disclaimer** (visible above End session, always):

> Session data is saved on this device only. Do not use a shared device. Clear data after export.

**IT/clinical one-liner** (pilot-info / SOP):

> No data is sent to or stored on any server. Session data is saved locally in your browser to prevent accidental loss; export CSV to your records system.

**Expiry:** 7 days. On load if draft age ≥1d: prompt *You have unsaved session data from X days ago. Export now?*

**Role:** Emergency draft only. **CSV is primary workflow** — End session UX must reinforce *export CSV = session complete*.

**Implementation notes:**
- Save after each successful Calculate (inputs + log + rx/screen snapshot)
- Optional: clear draft after successful CSV download from End session
- No shinyjs required; vanilla JS + `localStorage` key e.g. `ppcrx_draft_v1`

---

## B. PCSS delta mode

**No Quick mode** (6 common only) — misses concentrating / slowed down.

**"No change" copy** — documents **AT verified no change**, not patient self-report:

> Confirm only if you have verbally reviewed symptoms with the athlete today. Selecting 'No change' documents AT-verified symptom status.

**New symptoms:** If last=0 and current>0 (or any increase from stored baseline), **red highlight** + message:

> New symptom detected: [item]. Please review before confirming.

Block Calculate until acknowledged (checkbox or explicit confirm per changed/new items).

**Delta UX:** Show last session's 22 values; AT edits deltas; one-click "Same as last session" pre-fills all (still requires verbal review per helpText).

---

## C. End session bundle

**Order (hard):**

1. Calculate (if stale)
2. **Download CSV**
3. Copy parent message
4. Optional PDF

**Fuse tripped:** Hard block prescription parent/athlete copy. Only safety notice copy enabled. Disabled buttons + tooltip: *Safety fuse active — use safety notice above.*

---

## D. Mobile (minimal v0.2.1)

- Optimize **Progress tab** first; Profile/Prescription stay in sidebar.
- **Sticky banner** on Progress (and/or top of main): `Target HR: XXX bpm` after rx available.
- **Portrait one-hand:** RPE slider min touch height **44px**; PCSS control spacing **40px** min.
- Ensure `viewport` meta on main Shiny app (match public-info.html).
- Single-column scroll on Progress @ ≤768px (extend existing CSS).

---

## E. CSV return-visit

**Auto-fill on CSV import:**

| Field | Auto-fill? |
|-------|------------|
| athlete_id | Yes (if stored in session / future profile sidecar) |
| age | Yes |
| days_post_injury | **No** — must enter each visit |
| sessions_completed | **No** — AT must confirm |
| last_session_worse | **No** — clinical judgment |
| target_hr / prescription | **No** — MD may have changed plan |

**Principle:** Only fields that do not change with elapsed time.

**localStorage vs CSV:** Both; CSV is master record, localStorage is crash/weekend gap insurance.

---

## F. Karla walkthrough (when v0.2.1 ready)

**Tasks (timed):**
1. New athlete — first session end-to-end
2. Import CSV — return visit Progress + export
3. Fuse scenario (ΔPCSS ≥2) — find safety notice, copy

**Questions:**
1. Which step felt most like real workflow vs most foreign?
2. Friday afternoon, three athletes waiting — what would you skip?
3. What would you need to show AD/district coordinator for one-athlete try?

**Tier framing:**

| Tier | Materials |
|------|-----------|
| Demo | De-identified demo; verbal "research prototype" |
| Supervised single-case | 1-page SOP + MD aware (email OK) + parent verbal consent documented |
| District pilot | Full SOP + MD written + parent written + IT one-pager + IRB/QI |

**Pitch (workflow, not research):**

> PPC-Rx gives high school ATs a structured, evidence-aligned workflow for PPCS aerobic prescription — screening, target HR, session tracking, and parent communication — in one free browser tool, with no data leaving the device.

---

## Out of scope (v0.2.1)

- Quick PCSS (6 items only)
- EMR / HL7 integration
- Parent/athlete login
- Server-side persistence
- Full single-page app rewrite

---

## Acceptance checks

- [ ] Refresh after Calculate restores draft (same device)
- [ ] Draft expires at 7 days; prompt if ≥1 day old
- [ ] End session: CSV before message; fuse blocks rx copy
- [ ] New PCSS symptom blocks Calculate until reviewed
- [ ] Mobile: sticky target HR visible on Progress without tab switch
- [ ] CSV import fills age (+ athlete_id when available), not days_post_injury
