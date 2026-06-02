#!/usr/bin/env Rscript
# Mirrors app.R observeEvent(input$calc) + UI outputs for each scenario
options(encoding = "UTF-8")
suppressPackageStartupMessages(library(PPCSexRx))

fuse_tripped_pcss <- function(current_pcss, previous_pcss) {
  if (is.null(current_pcss) || is.null(previous_pcss)) return(FALSE)
  curr <- suppressWarnings(as.numeric(current_pcss))
  prev <- suppressWarnings(as.numeric(previous_pcss))
  if (is.na(curr) || is.na(prev)) return(FALSE)
  (curr - prev) >= 2
}

run_scenario <- function(name, role, age, days_post_injury,
                         hrst = NA, vestibular = FALSE, cervical = FALSE, vision = FALSE,
                         sessions_completed = 0, last_session_worse = FALSE,
                         current_pcss = NA, previous_pcss = NA,
                         current_hr = NA, current_duration = NA) {
  log <- NULL
  screen <- PPCSexRx::screen_ppcs(
    age = age,
    days_post_injury = days_post_injury,
    vestibular_symptoms = vestibular,
    cervical_symptoms = cervical,
    vision_symptoms = vision
  )

  rx <- NULL
  track <- NULL
  fuse_tripped <- FALSE
  fuse_message <- ""
  errors <- character(0)

  if (identical(screen$status, "eligible")) {
    hrst_val <- suppressWarnings(as.numeric(hrst))
    if (length(hrst_val) == 0L || is.na(hrst_val)) hrst_val <- NULL
    rx <- PPCSexRx::prescribe_ppcs(
      age = age,
      days_post_injury = days_post_injury,
      hrst = hrst_val,
      vestibular_symptoms = vestibular,
      cervical_symptoms = cervical,
      sessions_completed = as.integer(sessions_completed),
      last_session_worse = last_session_worse
    )
    fuse_tripped <- fuse_tripped_pcss(current_pcss, previous_pcss)
    if (fuse_tripped) {
      delta <- as.numeric(current_pcss) - as.numeric(previous_pcss)
      fuse_message <- sprintf(
        "PCSS increased by %s (>= 2). Next session prescription locked.",
        format(delta, trim = TRUE)
      )
    }
    track <- tryCatch(
      PPCSexRx::track_progress(
        log = log,
        current_pcss = current_pcss,
        current_hr = current_hr,
        current_duration = current_duration,
        prescription = rx
      ),
      error = function(e) {
        errors <<- c(errors, conditionMessage(e))
        NULL
      }
    )
    if (!is.null(track)) log <- track$updated_log
  }

  session_ready <- !is.null(rx) &&
    identical(screen$status, "eligible") &&
    !isTRUE(fuse_tripped)

  list(
    name = name,
    role = role,
    screen_status = screen$status,
    screen_reason = screen$reason,
    screen_referral = if (!is.null(screen$referral)) screen$referral else NA,
    screen_next_step = screen$next_step,
    target_hr = if (!is.null(rx)) as.integer(rx$target_hr) else NA,
    rx_method = if (!is.null(rx)) rx$method else NA,
    fuse_tripped = fuse_tripped,
    fuse_ui = if (fuse_tripped) "TRIPPED" else if (!is.null(rx) || !is.null(screen)) "OK" else "N/A",
    fuse_message = fuse_message,
    prescription_shown = !is.null(rx),
    rx_locked = fuse_tripped,
    track_phase = if (!is.null(track)) track$phase else NA,
    track_recommendation = if (!is.null(track)) track$recommendation else NA,
    simple_ready = if (role == "simple") session_ready else NA,
    simple_status_label = if (role == "simple") {
      if (session_ready) "Ready" else "Not today"
    } else NA,
    errors = errors
  )
}

scenarios <- list(
  list(
    name = "Scenario 1: Standard eligible AT (BCTT)",
    role = "clinical",
    age = 16, days_post_injury = 35, hrst = 160,
    current_pcss = 23, previous_pcss = 25,
    current_hr = 128, current_duration = 20
  ),
  list(
    name = "Scenario 2: No BCTT (age-predicted fallback)",
    role = "clinical",
    age = 16, days_post_injury = 35, hrst = NA,
    current_pcss = 18, previous_pcss = 20,
    current_hr = 115, current_duration = 20
  ),
  list(
    name = "Scenario 3: Safety fuse triggered",
    role = "clinical",
    age = 16, days_post_injury = 35, hrst = 160,
    current_pcss = 23, previous_pcss = 20,
    current_hr = 128, current_duration = 15
  ),
  list(
    name = "Scenario 4: Vestibular contraindication",
    role = "clinical",
    age = 16, days_post_injury = 35, vestibular = TRUE
  ),
  list(
    name = "Scenario 5: Too early (days < 28)",
    role = "clinical",
    age = 16, days_post_injury = 20
  ),
  list(
    name = "Scenario 6: Simple mode (Parent)",
    role = "simple",
    age = 15, days_post_injury = 30, hrst = NA,
    current_pcss = 9, previous_pcss = 10,
    current_hr = NA, current_duration = NA
  )
)

results <- lapply(scenarios, function(s) {
  do.call(run_scenario, s)
})

for (r in results) {
  cat("\n", strrep("=", 72), "\n", r$name, "\n", strrep("=", 72), "\n", sep = "")
  cat("Role:", r$role, "\n")
  cat("Screen status:", r$screen_status, "\n")
  cat("Screen reason:", r$screen_reason, "\n")
  if (!is.na(r$screen_referral)) cat("Referral:", r$screen_referral, "\n")
  cat("Next step:", r$screen_next_step, "\n")
  cat("Target HR:", if (is.na(r$target_hr)) "(none)" else paste(r$target_hr, "bpm"), "\n")
  cat("Prescription issued:", r$prescription_shown, "\n")
  if (!is.na(r$rx_method)) cat("Method:", r$rx_method, "\n")
  cat("Fuse UI:", r$fuse_ui, "\n")
  if (nzchar(r$fuse_message)) cat("Fuse detail:", r$fuse_message, "\n")
  cat("Rx locked (track):", r$rx_locked, "\n")
  if (!is.na(r$track_phase)) {
    cat("Track phase:", r$track_phase, "\n")
    cat("Track recommendation:", r$track_recommendation, "\n")
  }
  if (r$role == "simple") {
    cat("Simple status:", r$simple_status_label, "\n")
    cat("Simple session_ready:", r$simple_ready, "\n")
  }
  if (length(r$errors)) cat("Errors:", paste(r$errors, collapse = "; "), "\n")
}
