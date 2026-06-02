# PPCSexRx Shiny App

## Mission

Provide athletic trainers a browser-based tool to screen adolescents with persistent post-concussion symptoms (PPCS), prescribe sub-symptom threshold aerobic exercise (SSTAE), track sessions, and communicate plans to parents and athletes—without storing patient data on the server.

## Clinical Background

- **PPCS (persistent post-concussion symptoms):** Concussion symptoms lasting at least 28 days post-injury in adolescents; affects school, sport, and daily function.
- **SSTAE (sub-symptom threshold aerobic exercise):** Structured aerobic exercise at a heart rate below symptom exacerbation, progressed as tolerance improves.
- **Evidence base:** Li (2026) critically appraised topic synthesizing seven studies (~1,132 participants). Overall **GRADE: LOW** certainty for SSTAE in PPCS.
- **NATA 2024 Bridge Statement:** Progression should be individualized based on symptom response, not fixed timelines alone.

## Target User

- **Primary:** Athletic trainers in low-resource settings (including sites without formal BCTT equipment).
- **Communication recipients:** Parents and athletes receive plain-text plans via the AT’s own SMS, email, or WeChat (copy-to-clipboard)—not via separate app logins.

## Architecture Decisions and Why

| Decision | Rationale |
|----------|-----------|
| **AT-only (no parent/athlete login)** | Prescription and screening are clinical decisions; removing Simple mode avoids unsupervised misinterpretation. |
| **Zero server persistence (no database)** | Session state lives in the browser session only; supports HIPAA-minimal deployment. |
| **Copy-to-clipboard vs built-in email** | ATs use varied channels (SMS, WeChat, school email); plain text avoids encoding and deliverability issues. |
| **Bayesian guidance (not ML)** | Typical logs have small *n* per athlete; literature provides defensible priors. |
| **Conjugate Normal-Normal (not MCMC)** | Real-time updates on each Calculate; no Stan/brms server load. |
| **3-session moving average (not control charts)** | Easier for ATs to interpret at the bedside. |
| **Rejected:** control charts, ERI index, Spanish UI in v0.2 | Complexity, validation gap, or deferred i18n scope. |

## Algorithm

All clinical calculations delegate to the **PPCSexRx** R package. The Shiny layer does not duplicate prescription math.

### `screen_ppcs()`

| Input | Role |
|-------|------|
| `age` (13–18) | Eligibility |
| `days_post_injury` | Must be ≥ 28 for PPCS |
| `vestibular_symptoms`, `cervical_symptoms`, `vision_symptoms` | Contraindications / referral |

**Output:** `status` (`eligible`, `contraindicated`, `needs_referral`), `reason`, `next_step`, optional `referral`.

### `prescribe_ppcs()`

| Input | Role |
|-------|------|
| `hrst` | BCTT symptom-threshold HR; if empty → age-predicted fallback |
| `sessions_completed`, `last_session_worse` | Progression context |

**Output:** `target_hr`, `duration_min`, `frequency_per_week`, `method`, `clinical_note`, `safety_warning`, `evidence_grade`, `citation`.

- **BCTT path:** 80% of HRST when HRST provided.
- **No BCTT:** Age-predicted 60–70% HRmax per package (Li 2026).

### `track_progress()`

Appends one row to the session log when current HR and duration are provided.

**Package log fields:** `date`, `pcss`, `target_hr`, `achieved_hr`, `duration_min`, `symptoms_worsened`.

**App-extended fields (v0.2):** `rpe`, `symptom_onset_min`, `post_symptom_severity`.

### Safety fuse

If `current_pcss - previous_pcss >= 2`, fuse trips: next prescription locked; track UI shows lock message. Prescription values may still display for reference.

### Bayesian update (Shiny-only)

- **Prior:** `get_prior(has_bctt)` from Li (2026) CAT extrapolation (BCTT vs non-BCTT rates).
- **Update:** `bayes_update()` Normal-Normal conjugate on PCSS improvement per session (`-diff(pcss)`).
- **Output:** `generate_bayes_recommendation()` one-sentence AT guidance (info / warning / success).

## Data Schema

### Session Log CSV (v0.2)

| Column | Type | Range | Meaning |
|--------|------|-------|---------|
| `date` | character | ISO-like date | Session date |
| `pcss` | integer | 0–132 | Post-concussion symptom score |
| `target_hr` | integer | bpm | Prescribed target |
| `achieved_hr` | integer | bpm | Achieved exercise HR |
| `duration_min` | integer | minutes | Session duration |
| `symptoms_worsened` | logical | TRUE/FALSE | Worse vs prior session |
| `rpe` | numeric | 6–20 | Borg RPE (optional) |
| `symptom_onset_min` | numeric | 0–20 | Minute symptoms began; 20 = full session |
| `post_symptom_severity` | integer | 0/1/2 | 0 none; 1 resolved ≤30 min; 2 persisted >30 min |

### Backward compatibility

v0.1 CSVs with only the six required columns load successfully. Missing optional columns are added as `NA`. Export always writes all nine columns.

## File Structure

| Path | Description |
|------|-------------|
| `app.R` | Shiny UI/server entry (v0.2 AT-only) |
| `i18n/en.csv` | English UI strings |
| `i18n/es.csv` | Spanish placeholder (future) |
| `R/pdf_log.R` | CSV schema, PDF render, progress validation |
| `R/plots.R` | Plotly PCSS and onset trend charts |
| `R/bayes.R` | Conjugate Bayesian guidance |
| `R/messages.R` | Plain-text parent/athlete messages |
| `templates/prescription.Rmd` | rmarkdown PDF prescription template |
| `samples/` | Example PDF/CSV for testing |
| `test_v02.R` | Automated v0.2 checks |
| `README.md` | Project memory (this file) |

## Version History

### v0.1

- Three-role landing page (AT / Parent / Athlete)
- `screen_ppcs`, `prescribe_ppcs`, `track_progress`
- PDF download, CSV export/import
- Safety fuse (PCSS delta ≥ 2)
- Simple mode for parents/athletes

### v0.2

- Removed landing page; **AT-only** clinical UI
- Session log: `rpe`, `symptom_onset_min`, `post_symptom_severity`
- Analytics panel (≥2 log rows): PCSS + onset plotly charts
- Bayesian prescription guidance (conjugate prior)
- Copy-to-clipboard parent/athlete messages
- **Safety fuse:** copy buttons stay enabled; message switches to rest-day safety notice (not prescription)
- **Quick start** three-step guide at top of main panel
- Backward compatible with v0.1 CSVs

## Deployment

- **Server:** Oracle Cloud ARM
- **URL:** http://132.226.153.186:3838/
- **App directory:** `/srv/shiny-server/PPCSexRx`
- **Run (manual):**

```bash
cd /srv/shiny-server/PPCSexRx
R -e "setwd('/srv/shiny-server/PPCSexRx'); shiny::runApp(host='0.0.0.0', port=3838)"
```

- **systemd:**

```bash
sudo systemctl restart ppcsexrx-shiny.service
sudo systemctl status ppcsexrx-shiny.service
```

- **guanglab.org:** Research page card “Launch PPCSexRx App →” and navbar “Clinical Tool” → same Shiny URL.

## Known Limitations

- Bayesian priors extrapolated from adult/mixed-age literature to ages 13–18.
- Age-predicted fallback uses package defaults (60–70% HRmax), not a fixed 65% formula.
- `symptom_onset_min` depends on self-report accuracy.
- Bayesian guidance not prospectively validated.
- Plotly requires user R library `~/R/library` on this server if system library is not writable.

## What NOT to do (lessons learned)

- Do **not** add female HRmax −5 bpm adjustment (no validated adolescent formula).
- Do **not** implement Karvonen method (no PPCS-specific evidence).
- Do **not** show recovery time predictions (CDC: individual recovery unpredictable).
- Do **not** activate `AL_HOOK` without IRB approval.
- Do **not** duplicate PPCSexRx algorithm code in Shiny.
- Do **not** use emoji, HTML, or Unicode bullets in parent/athlete messages (SMS/WeChat safety).

## Future Roadmap

### v0.3 (requires IRB)

- `AL_HOOK` activation for active learning
- Multi-patient CSV aggregation

### Later

- Spanish UI (`i18n/es.csv`)
- `shiny.guanglab.org` domain mapping

## Citation

Li G. (2026). PPCSexRx Shiny App. Based on:

Li G. (2026). Sub-symptom Threshold Aerobic Exercise for Adolescents with PPCS: A Critically Appraised Topic. OSF: https://doi.org/10.17605/OSF.IO/KVUF6

## License

MIT
