# Browser localStorage draft helpers (v0.2.1) — no server persistence

DRAFT_VERSION <- 1L

build_draft_payload <- function(input, state, has_calculated) {
  log_df <- state$log
  log_list <- if (is.null(log_df) || !is.data.frame(log_df) || nrow(log_df) == 0L) {
    list()
  } else {
    jsonlite::fromJSON(
      jsonlite::toJSON(ensure_log_schema(log_df), dataframe = "rows"),
      simplifyVector = FALSE
    )
  }

  list(
    version = DRAFT_VERSION,
    athleteId = if (is.null(input$athlete_id)) "" else as.character(input$athlete_id),
    profile = list(
      athlete_id = if (is.null(input$athlete_id)) "" else input$athlete_id,
      at_name = if (is.null(input$at_name)) "" else input$at_name,
      age = if (is.null(input$age)) NA_integer_ else as.integer(input$age),
      days_post_injury = if (is.null(input$days_post_injury)) NA_real_ else input$days_post_injury,
      vestibular_symptoms = isTRUE(input$vestibular_symptoms),
      cervical_symptoms = isTRUE(input$cervical_symptoms),
      vision_symptoms = isTRUE(input$vision_symptoms)
    ),
    prescription = list(
      hrst = suppressWarnings(as.numeric(input$hrst)),
      sessions_completed = if (is.null(input$sessions_completed)) 0L else as.integer(input$sessions_completed),
      last_session_worse = isTRUE(input$last_session_worse)
    ),
    progress = list(
      chief_complaint = if (is.null(input$chief_complaint)) "" else input$chief_complaint,
      session_date = if (is.null(input$session_date)) NA_character_ else as.character(input$session_date),
      current_hr = suppressWarnings(as.numeric(input$current_hr)),
      current_duration = suppressWarnings(as.numeric(input$current_duration)),
      rpe = if (is.null(input$rpe)) NA_integer_ else as.integer(input$rpe),
      symptom_onset_range = if (is.null(input$symptom_onset_range)) NA_integer_ else as.integer(input$symptom_onset_range)
    ),
    pcssScores = as.list(pcss_read_scores(input, "current_pcss")),
    pcssBaseline = as.list(as.integer(state$pcss_baseline)),
    log = log_list,
    hasCalculated = isTRUE(has_calculated),
    fuseTripped = isTRUE(state$fuse_tripped),
    targetHr = if (is.null(state$rx)) NA_integer_ else as.integer(state$rx$target_hr)
  )
}

restore_draft_to_session <- function(session, draft, state, has_calculated) {
  if (!is.list(draft)) {
    return(invisible(FALSE))
  }

  prof <- draft$profile
  if (is.list(prof)) {
    if (!is.null(prof$athlete_id)) {
      updateTextInput(session, "athlete_id", value = prof$athlete_id)
    }
    if (!is.null(prof$at_name)) {
      updateTextInput(session, "at_name", value = prof$at_name)
    }
    if (!is.null(prof$age) && !is.na(prof$age)) {
      updateSelectInput(session, "age", selected = as.character(as.integer(prof$age)))
    }
    if (!is.null(prof$days_post_injury) && !is.na(prof$days_post_injury)) {
      updateNumericInput(session, "days_post_injury", value = prof$days_post_injury)
    }
    if (!is.null(prof$vestibular_symptoms)) {
      updateCheckboxInput(session, "vestibular_symptoms", value = isTRUE(prof$vestibular_symptoms))
    }
    if (!is.null(prof$cervical_symptoms)) {
      updateCheckboxInput(session, "cervical_symptoms", value = isTRUE(prof$cervical_symptoms))
    }
    if (!is.null(prof$vision_symptoms)) {
      updateCheckboxInput(session, "vision_symptoms", value = isTRUE(prof$vision_symptoms))
    }
  }

  rx_in <- draft$prescription
  if (is.list(rx_in)) {
    if (!is.null(rx_in$hrst) && length(rx_in$hrst) > 0L && !is.na(rx_in$hrst)) {
      updateNumericInput(session, "hrst", value = rx_in$hrst)
    }
    if (!is.null(rx_in$sessions_completed)) {
      updateSelectInput(session, "sessions_completed", selected = as.character(as.integer(rx_in$sessions_completed)))
    }
    if (!is.null(rx_in$last_session_worse)) {
      updateCheckboxInput(session, "last_session_worse", value = isTRUE(rx_in$last_session_worse))
    }
  }

  prog <- draft$progress
  if (is.list(prog)) {
    if (!is.null(prog$chief_complaint)) {
      updateTextInput(session, "chief_complaint", value = prog$chief_complaint)
    }
    if (!is.null(prog$session_date) && !is.na(prog$session_date)) {
      updateDateInput(session, "session_date", value = as.Date(prog$session_date))
    }
    if (!is.null(prog$current_hr) && !is.na(prog$current_hr)) {
      updateNumericInput(session, "current_hr", value = prog$current_hr)
    }
    if (!is.null(prog$current_duration) && !is.na(prog$current_duration)) {
      updateNumericInput(session, "current_duration", value = prog$current_duration)
    }
    if (!is.null(prog$rpe) && !is.na(prog$rpe)) {
      updateSliderInput(session, "rpe", value = prog$rpe)
    }
    if (!is.null(prog$symptom_onset_range) && !is.na(prog$symptom_onset_range)) {
      updateRadioButtons(session, "symptom_onset_range", selected = prog$symptom_onset_range)
    }
  }

  scores <- draft$pcssScores
  if (!is.null(scores)) {
    pcss_apply_scores(session, "current_pcss", scores)
  }

  baseline <- draft$pcssBaseline
  if (!is.null(baseline)) {
    state$pcss_baseline <- as.integer(unlist(baseline, use.names = FALSE))
  } else if (!is.null(scores)) {
    state$pcss_baseline <- as.integer(unlist(scores, use.names = FALSE))
  }

  if (!is.null(scores)) {
    state$last_pcss_scores <- as.integer(unlist(scores, use.names = FALSE))
  }

  log_rows <- draft$log
  if (is.list(log_rows) && length(log_rows) > 0L) {
    log_df <- tryCatch(
      jsonlite::fromJSON(jsonlite::toJSON(log_rows, auto_unbox = TRUE), simplifyDataFrame = TRUE),
      error = function(e) NULL
    )
    if (!is.null(log_df) && is.data.frame(log_df) && nrow(log_df) > 0L) {
      state$log <- ensure_log_schema(log_df)
    }
  }

  has_calculated(isTRUE(draft$hasCalculated))
  invisible(TRUE)
}

csv_session_filename <- function(athlete_id, session_date = Sys.Date()) {
  id_part <- athlete_id
  if (is.null(id_part) || !nzchar(trimws(id_part))) {
    id_part <- "athlete"
  } else {
    id_part <- gsub("[^A-Za-z0-9_-]+", "_", trimws(id_part))
  }
  sprintf(
    "PPCRx_%s_%s.csv",
    id_part,
    format(as.Date(session_date), "%Y%m%d")
  )
}
