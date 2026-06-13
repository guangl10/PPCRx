# PPC-Rx: High School Pilot Readiness Brief (for external review)

**Purpose of this document:** Summarize current product assessment, proposed improvements, and open questions. Please review and suggest priorities, risks, missing items, and alternative approaches.

**Author context:** Guang (Jack) Li — developer/researcher; PPCS aerobic exercise systematic review in progress; Li (2026) CAT author; PPCRx Shiny app v0.2 deployed at https://guanglab.org/ppcrx/ ; GitHub https://github.com/guangl10/PPCRx (public); clinical algorithms in CRAN package PPCSexRx.

**Audience for eventual pilot:** High school athletic trainer (AT) supervisor/advisor ("Karla") — BOC AT, likely faculty/preceptor; not yet committed to district rollout.

**Date:** June 2026

**Note for reviewer:** You likely have **no prior context** on this project. Read **Section 0** first for clinical background, architecture, and current UI workflow before evaluating Sections 4–5.

---

## 0. Project background (cold-start for external reviewer)

### 0.1 Clinical problem

**Concussion** is common in adolescent sport. Most athletes recover within weeks, but **~15–30%** develop symptoms lasting **≥28 days** — called **persistent post-concussion symptoms (PPCS)** or PPCS. These athletes may remain out of sport, struggle in school, and need structured rehabilitation.

**Sub-symptom threshold aerobic exercise (SSTAE)** is an emerging approach: light aerobic exercise at a heart rate **below** the level that worsens symptoms, progressed gradually as tolerance improves. It is **not** return-to-play clearance; it is a **rehabilitation prescription** usually managed with physician involvement.

**High school athletic trainers (ATs)** often:
- Cover one school or multiple sports with limited time
- Lack a **Buffalo Concussion Treadmill Test (BCTT)** machine (common in college/clinic, rare in HS)
- Must communicate plans to parents via text/email
- Document in local EMR (e.g., SportsWare) without a dedicated PPCS exercise tool

**Gap:** Literature exists (Li 2026 critically appraised topic, NATA 2024 Bridge Statement on concussion management), but ATs lack a **simple, evidence-aligned workflow tool** for PPCS aerobic prescription in low-resource settings.

### 0.2 What PPC-Rx is

**PPC-Rx** (repo name **PPCRx**; full name PPCSexRx Shiny App) is a **free, browser-based research prototype** that helps **licensed athletic trainers** (not parents, not athletes) manage adolescent PPCS SSTAE workflows.

| Layer | What it is |
|-------|------------|
| **PPCRx** (GitHub: guangl10/PPCRx) | Shiny web UI — forms, charts, PDF/CSV export, messages |
| **PPCSexRx** (GitHub: guangl10/PPCSexRx, R CRAN package) | Clinical algorithms — screening, prescription math, progress rules |
| **Li (2026) CAT** | Evidence synthesis (~7 studies, ~1,132 participants) that informs package rules |
| **Systematic review (in progress)** | Separate research on "subjective measurement trap" in PPCS literature (541-study knowledge graph) |

**Live URL:** https://guanglab.org/ppcrx/  
**Static info page:** https://guanglab.org/ppcrx/public-info.html  
**License:** MIT (public repo)

### 0.3 Design principles (why it was built this way)

| Decision | Rationale |
|----------|-----------|
| AT-only (no parent/athlete login) | Prescription is a clinical act; avoid unsupervised use |
| No server database / no PHI stored | Session data lives in browser only; AT exports CSV/PDF manually |
| Copy-to-clipboard messages | ATs use SMS, email, WeChat — plain ASCII text |
| Algorithms only in R package | Single source of truth; Shiny does not reimplement math |
| Research prototype labels | Not FDA-cleared; GRADE LOW cited openly |

### 0.4 Current version: v0.2 feature list

**Screening**
- Age 13–18, days post-injury (must be ≥28 for PPCS)
- Red-flag symptoms: vestibular, cervical, vision → referral paths
- Output: eligible / contraindicated / needs_referral

**Prescription**
- If **BCTT available:** enter HRST → target = 80% HRST
- If **no BCTT:** leave HRST blank → age-predicted HRmax × 65% (package default; UI notes Li CAT recommends 50% — discrepancy documented until package v0.2.0)
- Session progression inputs: sessions completed without worsening, last session worse flag

**Progress (each exercise session)**
- Optional chief complaint (PDF only, not in CSV)
- **PCSS Today:** 22-symptom picker (6 common + 16 in "More symptoms"), SCAT6-style 0–6 severity each → auto total score
- Previous PCSS auto-loaded from session log (no manual re-entry)
- Exercise HR (bpm), duration (min, max 20), Borg RPE 6–20
- Symptom onset bucket: full session / 15–19 / 10–14 / 5–9 / first 5 min

**Safety fuse**
- If today's PCSS − last session PCSS **≥ 2** → lock next prescription; switch parent/athlete copy to safety/rest notice

**Outputs**
- Plain-text parent and athlete messages (copy to clipboard)
- Session log CSV (8 columns): date, pcss, target_hr, achieved_hr, duration_min, symptoms_worsened, rpe, symptom_onset_min
- CSV import for continuing care across visits
- Clinical note PDF: SOAP (first session) or DAP (follow-up), auto-selected by log length
- Analytics tab (≥2 sessions): PCSS trend + symptom onset charts; Bayesian one-line guidance (exploratory)

**Demo mode**
- Three synthetic datasets for teaching/testing without real PHI

**Recent fixes**
- Double-click Calculate on same date → replaces log row (no duplicate sessions)
- HTTPS public path: guanglab.org/ppcrx/

### 0.5 Typical AT workflow today (why usability scored 3/5)

1. Open browser → guanglab.org/ppcrx/
2. **Sidebar tab Profile:** athlete ID (optional), AT name, age, days post-injury, symptom flags
3. **Sidebar tab Prescription:** HRST if BCTT done, sessions completed, last session worse
4. **Sidebar tab Progress:** chief complaint, date, PCSS picker (22 items), HR, duration, RPE, symptom onset
5. Click **"Run screen / prescribe / track"** (Calculate)
6. **Main tabs:** Screening & Rx | Session log | Analytics | Messages — switch to review results, copy message, export CSV/PDF

**Pain point:** Steps 2–6 repeat largely unchanged on **return visits**; many tabs; sideline/mobile use is cumbersome. Session data lost if browser closed without CSV export.

### 0.6 What PPC-Rx is NOT

- Not a general concussion RTP (return-to-play) tool for acute injury
- Not EMR-integrated (no SportsWare API)
- Not validated in prospective RCT
- Not a HIPAA compliance product
- Not for patient self-use

### 0.7 Evidence stance (important for pilot framing)

Li (2026) CAT conclusion: SSTAE in adolescent PPCS — **GRADE: LOW certainty**.  
Author's ongoing SR argues LOW is **structural** (subjective entry/exit measures, weak adherence measurement in literature) — not fixable by any single app.

**PPC-Rx does not claim to raise evidence grade.** It claims to **translate LOW-grade synthesis into an auditable AT workflow** while SR + future pilots address measurement gaps.

### 0.8 Glossary

| Term | Meaning |
|------|---------|
| AT | Athletic Trainer (BOC-certified clinician in US schools/sport) |
| PPCS | Persistent post-concussion symptoms (≥28 days) |
| SSTAE | Sub-symptom threshold aerobic exercise |
| PCSS | Post-Concussion Symptom Scale (symptom inventory, 0–132 total in app) |
| BCTT | Buffalo Concussion Treadmill Test |
| HRST | Heart rate at symptom threshold during BCTT |
| HRmax | Age-predicted maximum heart rate |
| NATA | National Athletic Trainers' Association |
| Bridge Statement | NATA 2024 updated concussion management guidance |
| CAT | Critically appraised topic (evidence synthesis format) |
| GRADE | Grading of Recommendations Assessment, Development and Evaluation |
| EMR | Electronic medical record |
| SOAP/DAP | Clinical note formats (Subjective-Objective-Assessment-Plan / Data-Assessment-Plan) |

### 0.9 Author & pilot context

- **Guang (Jack) Li:** Researcher/developer; Li (2026) CAT author; SR on PPCS aerobic exercise measurement gaps; not BOC-certified (needs AT Co-PI for NATA grants)
- **Karla (proposed advisor):** AT educator/clinical supervisor; audience for pilot decision; BOC AT likely
- **Immediate goal:** Improve ease-of-use and district pilot readiness before showing Karla — **not** district-wide rollout yet

---

## 1. Product summary (executive)

**PPC-Rx (PPCSexRx Shiny app)** is an AT-only browser tool for adolescents (13–18) with **persistent post-concussion symptoms (PPCS, ≥28 days post-injury)**:

- Screening (`screen_ppcs`) — eligibility, contraindications, referral
- Prescription (`prescribe_ppcs`) — target HR, duration; BCTT path (80% HRST) or age-predicted fallback (package default 65% HRmax when no BCTT)
- Progress tracking — session log: PCSS, HR, duration, RPE, symptom onset bucket
- Safety fuse — if ΔPCSS ≥ 2 vs prior session, lock next prescription; safety messages to parent/athlete
- Outputs — plain-text clipboard messages (SMS-safe), CSV export/import, SOAP/DAP PDF clinical notes
- Analytics (≥2 log rows) — PCSS/onset plotly charts, Bayesian guidance (exploratory, not prospectively validated)

**Explicitly NOT:** parent/athlete login, server-side PHI storage, medical device, HIPAA compliance claim, efficacy claim.

**Evidence stance:** Based on Li (2026) CAT — **GRADE: LOW certainty** for SSTAE in PPCS. App labels this honestly. NATA 2024 Bridge Statement alignment (individualized, symptom-guided progression).

**Research prototype disclaimer:** https://guanglab.org/ppcrx/public-info.html

---

## 2. Practicality assessment (Karla / high school AT perspective)

| Dimension | Score (1–5) | Rationale |
|-----------|-------------|-----------|
| Solves real problem | 4 | PPCS + no-BCTT high school settings; structured SSTAE workflow |
| Clinical safety design | 4 | Fuse, referral paths, disclaimers, AT-only |
| **Ease of use (HS AT)** | **3** | Full features but many steps/tabs; training needed; sideline time pressure |
| **District readiness** | **2** | Prototype; no EMR integration; not prospectively validated |
| Research/teaching tool | 4–5 | Good for demo, grant/pilot framing, student AT education |

**Likely Karla response tiers:**
- Demo / classroom: **High** willingness
- Supervised student AT trial: **Medium-high**
- 1 school, 1–2 PPCS athletes pilot: **Medium** (needs MD + district/QI clearance)
- District-wide daily use: **Low** (without validation, legal, EMR)

---

## 3. Evidence / SR alignment (why GRADE LOW is not a blocker)

**Argument:** LOW certainty reflects **field-level measurement structure**, not necessarily "intervention useless."

Systematic review / knowledge-graph work (541 studies) identifies **"Subjective Measurement Trap"**:
- Intervention → subjective outcome edges dominate objective edges (~22 vs ~9 in strict edge count)
- Adherence/compliance/wearable tracking are rare ("compliance black-box")
- Concussion PPCS entry (screening) and exit (recovery) rely heavily on self-report (PCSS, symptom scales)

Therefore GRADE ceilings are structural. NATA Bridge Statement still supports symptom-guided individualized care **while** better endpoints are developed.

**PPCRx role in research program:**
- **SR:** defines why certainty is limited (measurement trap)
- **CAT / package:** best-available synthesis → prescription rules
- **PPCRx app:** operationalizes CAT for AT workflow under LOW certainty (transparent, auditable)
- **Future:** objective endpoints (e.g., eye-tracking, PaTaKa) as research agenda — not denying current subjective tools

**Pitch to Karla:** Not "proven therapy app" but **CAT-aligned clinical support + pilot/research platform** under MD supervision.

---

## 4. Proposed improvements — Ease of use (target 3 → 4)

### 4.1 Return-visit mode (highest priority)
**Problem:** Every visit requires Profile → Prescription → Progress sidebar tabs; redundant for session 2+ on same athlete.

**Proposal:**
- After first visit, default to **Progress-only** view for return visits
- Profile/Prescription collapsed under "Review / Edit"
- Target HR shown in sticky banner without tab switching

**Success metric:** Return visit workflow ≤4 steps vs ~8 today.

### 4.2 Single-screen "Today's session" layout
**Problem:** Sidebar 3 tabs + main 4 tabs; poor mobile/sideline UX.

**Proposal:**
- **Session mode** (default for returns): one scrollable screen — PCSS (common 6) → HR → duration → symptom onset → Calculate
- Screening/Rx results visible inline

### 4.3 PCSS burden reduction
**Problem:** 22-item SCAT6-aligned picker is thorough but slow (3–5 min).

**Proposal (no schema change):**
- Pre-fill common 6 from last log session; AT edits deltas only
- "Same as last session" one-click for unchanged symptoms
- Optional **Quick PCSS** mode: common 6 only, remainder assumed 0 (with helpText for busy settings)

### 4.4 "End session" bundle
**Problem:** PDF, CSV, parent message scattered across tabs; AT may forget export before browser close (no server persistence).

**Proposal:** One **End session** button:
1. Run Calculate if needed
2. Copy parent message
3. Prompt CSV download
4. Optional SOAP/DAP PDF

### 4.5 Training collateral
- 1-page PDF: First visit vs Return visit
- New demo dataset: "High school return visit" (2–3 sessions)
- In-app toggle: New athlete / Return visit

---

## 5. Proposed improvements — District readiness (target 2 → 3 "pilot-ready")

### 5.1 Pilot SOP document (5–8 pages)
For AT director / Karla / district supervisor:

| Section | Content |
|---------|---------|
| Inclusion | PPCS ≥28d, ages 13–18, MD aware, parent communicated |
| Exclusion | Acute concussion, referral criteria met, unsupervised use |
| Data handling | No server storage; AT exports CSV/PDF to existing records |
| Liability framing | Decision support; AT retains clinical responsibility |
| Evidence | GRADE LOW + CAT; SR measurement-trap context |
| Pilot scope | 1 site, 1–3 athletes, 8–12 weeks |
| Outcomes | Usability, documentation completeness, adherence — **not** efficacy claims |

### 5.2 District one-pager (IT / legal)
- HTTPS, noindex, no persistent cookies/PHI on server
- CSV field dictionary + sample file for EMR attachment workflow
- Explicit: not FDA-cleared, not district-endorsed product without local approval

### 5.3 EMR "good enough" without deep integration
**Current:** 8-column CSV export/import.

**Proposals:**
- Standardized filename: `PPCRx_{AthleteID}_{date}.csv`
- Print-friendly 1-page session summary (HTML/PDF) for EMR paste/attach
- Document: SportsWare / district EMR = manual attach; no HL7/FHIR in v0.2.x

### 5.4 Pilot vs research boundary table

| Use | IRB likely? | Notes |
|-----|-------------|-------|
| Classroom demo | No | De-identified demo data |
| Single-case supervised clinical use | District/QI policy | MD + parent; Karla oversight |
| Multi-athlete outcomes study | Yes | NATA Foundation / institutional IRB |

### 5.5 Lightweight usability validation
- 3–5 ATs complete 10-item questionnaire after one simulated or real session
- Report: time-on-task, SUS or bespoke items, qualitative friction points
- Claim: **workflow feasibility assessed**, not clinical efficacy

---

## 6. Suggested 4–8 week roadmap

**Week 1–2 (product):** Return-visit mode + End session button  
**Week 1 (docs):** Pilot SOP draft + district one-pager  
**Week 2–3 (product):** Session mode single screen + PCSS pre-fill  
**Week 3 (docs):** pilot-info.html, CSV naming, training PDF  
**Week 4:** Karla 30-min walkthrough; iterate  
**Week 5–8 (optional):** 5-AT usability mini-study

**If only two items:** (1) Return-visit + End session, (2) Pilot SOP + one-pager

---

## 7. Explicitly deferred (do NOT do now)

- Full EMR/HL7 integration
- Parent/athlete portals
- Claiming improved recovery outcomes / higher GRADE
- AL_HOOK active learning, multi-patient aggregation (v0.3, IRB)
- Spanish i18n
- Offline PWA

---

## 8. NATA Foundation context (optional strategic layer)

- **Education & Practice Grant** (~$20k, 3 yr): good fit if framed as feasibility/usability pilot, not software product grant
- Requires PI or Co-PI: BOC AT + NATA member + NPI (Karla or site AT as Co-PI if Guang is not BOC-certified)
- Pre-proposal window: ~Aug 1 – Sep 1 annually
- GRADE LOW supports **pilot/process outcomes**, not efficacy RCT at $20k

---

## 9. Questions for reviewer (Claude or other)

1. **Priority ranking:** Are the proposed improvements ordered correctly? What would you cut or add for a high school AT pilot in 2026?

2. **Return-visit mode vs documentation first:** Should we ship Pilot SOP before any code changes to unblock Karla conversations?

3. **PCSS Quick mode:** Does offering a reduced PCSS path undermine clinical rigor / IRB acceptability, or is it defensible for real-world AT time constraints?

4. **District legal:** What minimum items must appear in the one-pager to satisfy typical US high school district IT/legal review for a **non-PHI-storing** external research prototype?

5. **Outcome measures for pilot:** What 3–5 process outcomes are most credible for Karla + district without overclaiming (e.g., time-on-task, export completion rate, AT confidence Likert)?

6. **EMR strategy:** Is CSV + 1-page PDF attach "good enough" for a 1-school pilot, or is lack of EMR integration a hard stop?

7. **GRADE LOW messaging:** Is the "measurement trap → LOW is honest → tool still needed for translation" narrative persuasive to an AT educator, or does it need reframing?

8. **Risks we missed:** What failure modes should we anticipate (liability, scope creep, athlete/parent confusion, MD buy-in)?

9. **Competitive/alternative:** What do HS ATs currently use for PPCS exercise prescription, and how should PPCRx differentiate without overpromising?

10. **Scope for v0.2.1 vs v0.3:** Which items belong in a small patch release vs IRB-gated v0.3?

---

## 10. Technical reference (for reviewer)

- **Live app:** https://guanglab.org/ppcrx/
- **Repo:** https://github.com/guangl10/PPCRx (public MIT; server ops gitignored)
- **Package:** https://github.com/guangl10/PPCSexRx (CRAN algorithms)
- **Session log CSV (8 cols):** date, pcss, target_hr, achieved_hr, duration_min, symptoms_worsened, rpe, symptom_onset_min
- **Key files:** `app.R`, `R/pcss_picker.R`, `R/clinical_note_pdf.R`, `R/bayes.R`, `www/public-info.html`

---

## 11. Requested output format from reviewer

Please respond with:
1. **Agree / disagree / modify** on priority ranking (Section 4 & 5)
2. **Top 3 actions** for next 2 weeks
3. **Top 3 risks** and mitigations
4. Answers to Section 9 questions (brief bullets OK)
5. Suggested **one-paragraph pitch** to Karla (English, AT-educator tone)

Thank you.
