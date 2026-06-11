# SOAP / DAP clinical note PDF (plain-text layout)

pcss_severity_word <- function(score) {
  score <- as.integer(score)
  if (is.na(score) || score <= 0L) return("none")
  if (score <= 2L) return("mild")
  if (score <= 4L) return("moderate")
  "severe"
}

pcss_checked_symptoms <- function(input, input_id) {
  if (is.null(input)) {
    return(list())
  }
  out <- list()
  for (i in seq_len(PCSS_SYMPTOM_COUNT)) {
    check_id <- pcss_check_id(input_id, i)
    score_id <- pcss_score_id(input_id, i)
    if (isTRUE(input[[check_id]])) {
      sc <- suppressWarnings(as.integer(input[[score_id]]))
      if (length(sc) > 0L && !is.na(sc) && sc > 0L) {
        out[[length(out) + 1L]] <- list(name = PCSS_SYMPTOMS[i], score = sc)
      }
    }
  }
  out
}

format_pcss_symptom_lines <- function(symptoms) {
  if (length(symptoms) == 0L) {
    return("  No individual symptoms reported above threshold.")
  }
  vapply(
    symptoms,
    function(s) {
      sprintf(
        "  %s: %d/6 (%s)",
        s$name,
        s$score,
        pcss_severity_word(s$score)
      )
    },
    character(1)
  )
}

describe_symptom_onset <- function(onset_min) {
  onset_min <- suppressWarnings(as.integer(onset_min))
  if (length(onset_min) == 0L || is.na(onset_min)) {
    return("Not recorded")
  }
  switch(
    as.character(onset_min),
    "20" = "No symptoms (full session)",
    "17" = "After 15-19 min",
    "12" = "After 10-14 min",
    "7"  = "After 5-9 min",
    "3"  = "Within first 5 min",
    paste0("Symptoms at ~", onset_min, " min")
  )
}

pcss_change_word <- function(delta) {
  delta <- suppressWarnings(as.numeric(delta))
  if (length(delta) == 0L || is.na(delta)) return("unchanged")
  if (delta < 0) return("improved")
  if (delta > 0) return("worsened")
  "unchanged"
}

safe_athlete_id <- function(athlete_id) {
  id <- trimws(as.character(athlete_id))
  if (!nzchar(id)) {
    return("athlete")
  }
  gsub("[^A-Za-z0-9_-]", "_", id)
}

pdf_template_type <- function(log_df) {
  if (is.null(log_df) || !is.data.frame(log_df) || nrow(log_df) <= 1L) {
    "soap"
  } else {
    "dap"
  }
}

pdf_download_filename <- function(template, athlete_id, date_str, session_n = NULL) {
  aid <- safe_athlete_id(athlete_id)
  d <- gsub("-", "", date_str)
  if (identical(template, "soap")) {
    sprintf("PPCSexRx_SOAP_%s_%s.pdf", aid, d)
  } else {
    sn <- if (is.null(session_n) || is.na(session_n)) 1L else as.integer(session_n)
    sprintf("PPCSexRx_DAP_%s_S%d_%s.pdf", aid, sn, d)
  }
}

note_footer_lines <- function() {
  c(
    "",
    "======================================",
    "Evidence: Li G. (2026)",
    "  doi: 10.17605/OSF.IO/KVUF6",
    "NATA 2024 Bridge Statement aligned.",
    "This note does not replace",
    "clinical judgment.",
    "======================================"
  )
}

fuse_status_text <- function(fuse_tripped) {
  if (isTRUE(fuse_tripped)) {
    "TRIPPED - prescription locked"
  } else {
    "OK"
  }
}

build_soap_note <- function(ctx) {
  lines <- c(
    "SOAP NOTE - Concussion Rehabilitation",
    "PPCSexRx Clinical Record",
    "======================================",
    sprintf(
      "Athlete: %s | Date: %s",
      ctx$athlete_id,
      ctx$date_str
    ),
    sprintf("Clinician: %s", ctx$at_name),
    "======================================",
    "",
    "S (Subjective):"
  )

  if (nzchar(ctx$chief_complaint)) {
    lines <- c(lines, sprintf('  Athlete reports: "%s"', ctx$chief_complaint))
  }

  lines <- c(
    lines,
    sprintf("  Symptom burden (PCSS): %s/132", ctx$pcss_total),
    format_pcss_symptom_lines(ctx$symptoms),
    "  Symptom onset during exercise:",
    paste0("  ", ctx$onset_desc),
    sprintf("  Perceived exertion: %s/20 (Borg scale)", ctx$rpe),
    "",
    "O (Objective):",
    sprintf("  Eligibility screening: %s", ctx$screen_status),
    sprintf(
      "  Age: %s yrs | Days post-injury: %s",
      ctx$age,
      ctx$days_post_injury
    ),
    sprintf("  Prescription method: %s", ctx$method),
    sprintf("  Target HR: %s bpm", ctx$target_hr),
    sprintf("  Achieved HR: %s bpm", ctx$achieved_hr),
    sprintf("  Session duration: %s min", ctx$duration_min),
    sprintf("  Safety fuse: %s", ctx$fuse_status),
    "",
    "A (Assessment):",
    sprintf("  Rehabilitation phase: %s", ctx$phase),
    "  Consistent with PPCS protocol criteria",
    "  per Li (2026). GRADE: LOW certainty.",
    "  Conditional recommendation FOR SSTAE.",
    "",
    "P (Plan):",
    sprintf("  Target HR: %s bpm", ctx$target_hr),
    sprintf("  Duration: %s min", ctx$duration_min),
    "  Frequency: 5 sessions/week",
    sprintf("  Next session target: %s bpm", ctx$next_hr),
    "  Re-assess every 2-3 sessions.",
    if (nzchar(ctx$safety_warning)) {
      paste0("  ", ctx$safety_warning)
    } else {
      character(0)
    },
    note_footer_lines()
  )
  lines
}

build_dap_note <- function(ctx) {
  delta <- ctx$pcss_delta
  delta_str <- if (is.finite(delta)) {
    sprintf("%+g", delta)
  } else {
    "N/A"
  }

  lines <- c(
    "DAP PROGRESS NOTE - Concussion Rehabilitation",
    "PPCSexRx Clinical Record",
    "======================================",
    sprintf(
      "Athlete: %s | Date: %s",
      ctx$athlete_id,
      ctx$date_str
    ),
    sprintf("Session: %s", ctx$session_number),
    sprintf("Clinician: %s", ctx$at_name),
    "======================================",
    "",
    "D (Data):"
  )

  if (nzchar(ctx$chief_complaint)) {
    lines <- c(lines, sprintf('  Athlete reports: "%s"', ctx$chief_complaint))
  }

  lines <- c(
    lines,
    sprintf("  Symptom burden (PCSS): %s/132", ctx$pcss_current),
    sprintf("  Previous session: %s/132", ctx$pcss_previous),
    sprintf(
      "  Change: %s pts (%s)",
      delta_str,
      pcss_change_word(delta)
    ),
    format_pcss_symptom_lines(ctx$symptoms),
    paste0("  Symptom onset: ", ctx$onset_desc),
    sprintf("  Perceived exertion: %s/20 (Borg scale)", ctx$rpe),
    sprintf(
      "  Achieved HR: %s bpm / Target: %s bpm",
      ctx$achieved_hr,
      ctx$target_hr
    ),
    sprintf("  Duration: %s min", ctx$duration_min),
    sprintf("  Safety fuse: %s", ctx$fuse_status),
    "",
    "A (Assessment):",
    sprintf("  Session %s of ongoing SSTAE protocol.", ctx$session_number),
    sprintf("  Phase: %s", ctx$phase),
    if (nzchar(ctx$bayes_text)) {
      paste0("  ", gsub("\n", "\n  ", ctx$bayes_text))
    } else {
      "  (Bayesian guidance pending - 3+ sessions with dates required.)"
    },
    "  GRADE: LOW certainty (Li, 2026).",
    "",
    "P (Plan):",
    sprintf(
      "  Next session: %s bpm x %s min",
      ctx$next_hr,
      ctx$duration_min
    ),
    "  Frequency: 5 sessions/week",
    "  Re-assess every 2-3 sessions.",
    if (nzchar(ctx$safety_warning)) {
      paste0("  ", ctx$safety_warning)
    } else {
      character(0)
    },
    note_footer_lines()
  )
  lines
}

build_clinical_note_lines <- function(template, ctx) {
  if (identical(template, "dap")) {
    build_dap_note(ctx)
  } else {
    build_soap_note(ctx)
  }
}

write_clinical_note_pdf <- function(note_lines, output_path) {
  n <- length(note_lines)
  page_h <- max(11, min(50, n * 0.22 + 1))
  grDevices::pdf(output_path, width = 8.5, height = page_h, family = "mono")
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(0.4, 0.4, 0.4, 0.4))
  graphics::plot.new()
  y <- seq(1, 0, length.out = n)
  for (i in seq_len(n)) {
    graphics::text(
      0,
      y[i],
      note_lines[i],
      adj = c(0, 1),
      cex = 0.72,
      family = "mono"
    )
  }
  invisible(output_path)
}

render_clinical_note_pdf <- function(template, ctx) {
  lines <- build_clinical_note_lines(template, ctx)
  dest <- tempfile(fileext = ".pdf")
  write_clinical_note_pdf(lines, dest)
  strip_pdf_metadata(dest)
  dest
}

build_clinical_note_context <- function(input, state, template) {
  rx <- state$rx
  screen <- state$screen
  track <- state$track
  log_df <- state$log

  date_str <- format_session_date(input$session_date)
  at_name <- trimws(as.character(input$at_name %||% ""))
  if (!nzchar(at_name)) {
    at_name <- "(not recorded)"
  }

  athlete_id <- safe_athlete_id(input$athlete_id %||% "")
  chief <- trimws(as.character(input$chief_complaint %||% ""))

  symptoms <- pcss_checked_symptoms(input, "current_pcss")
  pcss_total <- pcss_compute_total(input, "current_pcss")
  onset_desc <- describe_symptom_onset(
    resolve_symptom_onset_min(input$symptom_onset_range)
  )

  achieved_hr <- suppressWarnings(as.numeric(input$current_hr))
  if (length(achieved_hr) == 0L || is.na(achieved_hr)) {
    if (!is.null(log_df) && nrow(log_df) > 0L) {
      achieved_hr <- log_df$achieved_hr[nrow(log_df)]
    } else {
      achieved_hr <- "N/A"
    }
  }

  duration_min <- suppressWarnings(as.numeric(input$current_duration))
  if (length(duration_min) == 0L || is.na(duration_min)) {
    if (!is.null(track) && !is.null(rx)) {
      duration_min <- rx$duration_min
    } else {
      duration_min <- "N/A"
    }
  }

  target_hr <- if (!is.null(rx)) as.integer(rx$target_hr) else "N/A"
  next_hr <- if (!is.null(track) && !is.null(track$adjust_hr)) {
    as.integer(track$adjust_hr)
  } else if (!is.null(rx)) {
    as.integer(rx$target_hr)
  } else {
    "N/A"
  }

  phase <- if (!is.null(track) && !is.null(track$phase)) {
    track$phase
  } else {
    "Initial"
  }

  screen_status <- if (!is.null(screen) && !is.null(screen$status)) {
    screen$status
  } else {
    "not screened"
  }

  bayes_text <- ""
  if (identical(template, "dap") && !is.null(log_df) && nrow(log_df) >= 2L) {
    rec <- tryCatch(
      generate_bayes_recommendation(log_df, rx_has_bctt(rx)),
      error = function(e) NULL
    )
    if (!is.null(rec) && !is.null(rec$text)) {
      bayes_text <- rec$text
    }
  }

  pcss_current <- pcss_total
  pcss_previous <- NA_real_
  pcss_delta <- NA_real_
  session_number <- 1L

  if (!is.null(log_df) && is.data.frame(log_df) && nrow(log_df) > 0L) {
    session_number <- nrow(log_df)
    if (nrow(log_df) >= 1L) {
      pcss_current <- log_df$pcss[nrow(log_df)]
    }
    if (nrow(log_df) >= 2L) {
      pcss_previous <- log_df$pcss[nrow(log_df) - 1L]
      pcss_delta <- pcss_current - pcss_previous
    }
  }

  list(
    athlete_id = athlete_id,
    date_str = date_str,
    at_name = at_name,
    chief_complaint = chief,
    pcss_total = pcss_total,
    pcss_current = pcss_current,
    pcss_previous = if (is.finite(pcss_previous)) pcss_previous else "N/A",
    pcss_delta = pcss_delta,
    symptoms = symptoms,
    onset_desc = onset_desc,
    rpe = suppressWarnings(as.numeric(input$rpe)),
    screen_status = screen_status,
    age = input$age,
    days_post_injury = input$days_post_injury,
    method = if (!is.null(rx)) rx$method else "N/A",
    target_hr = target_hr,
    achieved_hr = achieved_hr,
    duration_min = duration_min,
    fuse_status = fuse_status_text(state$fuse_tripped),
    phase = phase,
    next_hr = next_hr,
    safety_warning = if (!is.null(rx)) as.character(rx$safety_warning) else "",
    bayes_text = bayes_text,
    session_number = session_number
  )
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
