#!/usr/bin/env Rscript
# Quick SOAP/DAP note generation tests (no Shiny)

options(encoding = "UTF-8")
setwd("/home/ubuntu/ppc_rx_app")

for (f in c("pdf_log.R", "bayes.R", "pcss_picker.R", "clinical_note_pdf.R")) {
  source(file.path("R", f), local = FALSE)
}

mock_input <- function(...) {
  x <- list(...)
  structure(x, class = "list")
}

mock_state <- function(...) {
  x <- list(...)
  structure(x, class = "list")
}

rx <- list(
  target_hr = 128L,
  duration_min = 20L,
  frequency_per_week = 5L,
  method = "BCTT-derived HRST",
  clinical_note = "Sub-symptom threshold aerobic exercise.",
  safety_warning = "Stop if symptoms worsen.",
  evidence_grade = "LOW",
  citation = "Li (2026)"
)

screen <- list(status = "eligible", reason = "OK", next_step = "Prescribe")

track <- list(
  phase = "Progression",
  recommendation = "Continue SSTAE",
  adjust_hr = 130L,
  sessions_total = 1L,
  pcss_change = -2L,
  updated_log = data.frame(
    date = "2026-06-01",
    pcss = 7L,
    target_hr = 128L,
    achieved_hr = 120L,
    duration_min = 15L,
    symptoms_worsened = FALSE,
    rpe = 13,
    symptom_onset_min = 20L,
    stringsAsFactors = FALSE
  )
)

inp <- mock_input(
  session_date = Sys.Date(),
  chief_complaint = "headache better, still foggy",
  athlete_id = "TEST01",
  at_name = "Coach Li",
  age = 16L,
  days_post_injury = 35L,
  current_hr = 120,
  current_duration = 15,
  rpe = 13,
  symptom_onset_range = 20L
)
inp$current_pcss_check_1 <- TRUE
inp$current_pcss_score_1 <- 3L
inp$current_pcss_check_2 <- TRUE
inp$current_pcss_score_2 <- 2L

st <- mock_state(
  screen = screen,
  rx = rx,
  track = track,
  log = track$updated_log,
  fuse_tripped = FALSE
)

soap_lines <- build_clinical_note_lines("soap", build_clinical_note_context(inp, st, "soap"))
stopifnot(grepl("SOAP NOTE", soap_lines[1]))
stopifnot(any(grepl("headache better", soap_lines, fixed = TRUE)))
stopifnot(any(grepl("Headache: 3/6", soap_lines, fixed = TRUE)))

log2 <- rbind(
  track$updated_log,
  transform(
    track$updated_log,
    date = "2026-06-02",
    pcss = 5L,
    achieved_hr = 122L
  )
)
st2 <- mock_state(
  screen = screen,
  rx = rx,
  track = track,
  log = log2,
  fuse_tripped = FALSE
)
inp2 <- inp
inp2$chief_complaint <- "feeling much better today"

dap_lines <- build_clinical_note_lines("dap", build_clinical_note_context(inp2, st2, "dap"))
stopifnot(grepl("DAP PROGRESS", dap_lines[1]))
stopifnot(any(grepl("feeling much better", dap_lines, fixed = TRUE)))
stopifnot(any(grepl("Session: 2", dap_lines, fixed = TRUE)))

soap_pdf <- render_clinical_note_pdf("soap", build_clinical_note_context(inp, st, "soap"))
dap_pdf <- render_clinical_note_pdf("dap", build_clinical_note_context(inp2, st2, "dap"))
cat("SOAP PDF:", soap_pdf, file.size(soap_pdf), "bytes\n")
cat("DAP PDF:", dap_pdf, file.size(dap_pdf), "bytes\n")

cat("\n=== SOAP NOTE (exact text) ===\n")
cat(paste(soap_lines, collapse = "\n"), "\n")
cat("\n=== DAP PROGRESS NOTE (exact text) ===\n")
cat(paste(dap_lines, collapse = "\n"), "\n")

unlink(c(soap_pdf, dap_pdf))

cat("\nAll clinical note tests passed.\n")
