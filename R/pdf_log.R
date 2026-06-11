# Session log, PDF export, and progress validation (v0.2)

LOG_COLS_REQUIRED <- c(
  "date", "pcss", "target_hr", "achieved_hr",
  "duration_min", "symptoms_worsened"
)

LOG_COLS_OPTIONAL <- c(
  "rpe",
  "symptom_onset_min"
)

LOG_COLS <- c(LOG_COLS_REQUIRED, LOG_COLS_OPTIONAL)

strip_pdf_metadata <- function(pdf_path) {
  if (!file.exists(pdf_path)) return(invisible(FALSE))
  exiftool <- Sys.which("exiftool")
  if (nzchar(exiftool)) {
    system2(
      exiftool,
      c(
        "-overwrite_original",
        "-Author=",
        "-Creator=",
        "-Producer=",
        "-CreationDate=",
        "-ModDate=",
        pdf_path
      ),
      stdout = FALSE,
      stderr = FALSE
    )
    return(invisible(TRUE))
  }
  invisible(TRUE)
}

render_prescription_pdf <- function(rx, date_str = format(Sys.Date(), "%Y-%m-%d")) {
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    stop("Package 'rmarkdown' is required for PDF export.", call. = FALSE)
  }
  template <- file.path(
    Sys.getenv("PPC_RX_APP_ROOT", "/home/ubuntu/ppc_rx_app"),
    "templates", "prescription.Rmd"
  )
  if (!file.exists(template)) {
    template <- file.path(getwd(), "templates", "prescription.Rmd")
  }
  if (!file.exists(template)) {
    stop("Prescription template not found: ", template, call. = FALSE)
  }

  out_dir <- tempfile("ppc_rx_pdf_")
  dir.create(out_dir, showWarnings = FALSE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  params <- list(
    date_str = date_str,
    target_hr = as.integer(rx$target_hr),
    method = rx$method,
    duration_min = rx$duration_min,
    frequency_per_week = rx$frequency_per_week,
    clinical_note = rx$clinical_note,
    safety_warning = rx$safety_warning,
    evidence_grade = rx$evidence_grade
  )

  rmd_copy <- file.path(out_dir, "prescription.Rmd")
  file.copy(template, rmd_copy, overwrite = TRUE)

  pdf_path <- normalizePath(
    rmarkdown::render(
      rmd_copy,
      output_dir = out_dir,
      output_file = "PPCSexRx_prescription.pdf",
      params = params,
      quiet = TRUE,
      envir = new.env(parent = globalenv())
    ),
    mustWork = TRUE
  )

  dest <- tempfile(fileext = ".pdf")
  file.copy(pdf_path, dest, overwrite = TRUE)
  strip_pdf_metadata(dest)
  dest
}

ensure_log_schema <- function(df) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
    return(NULL)
  }
  for (col in LOG_COLS) {
    if (!col %in% names(df)) {
      df[[col]] <- NA
    }
  }
  df <- df[, LOG_COLS, drop = FALSE]
  df$date <- as.character(df$date)
  df$pcss <- as.integer(df$pcss)
  df$target_hr <- as.integer(df$target_hr)
  df$achieved_hr <- as.integer(df$achieved_hr)
  df$duration_min <- as.integer(df$duration_min)
  if (!is.logical(df$symptoms_worsened)) {
    df$symptoms_worsened <- as.logical(
      tolower(as.character(df$symptoms_worsened)) %in%
        c("true", "1", "yes", "y")
    )
  }
  df$rpe <- suppressWarnings(as.numeric(df$rpe))
  df$symptom_onset_min <- suppressWarnings(as.numeric(df$symptom_onset_min))
  sort_log_by_date(df)
}

sort_log_by_date <- function(df) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) < 2L) {
    return(df)
  }
  ord <- order(as.Date(df$date))
  df[ord, , drop = FALSE]
}

format_session_date <- function(session_date) {
  format(as.Date(session_date), "%Y-%m-%d")
}

apply_session_date_to_last_row <- function(log_df, session_date) {
  log_df <- ensure_log_schema(log_df)
  if (is.null(log_df) || nrow(log_df) == 0L) {
    return(log_df)
  }
  log_df$date[nrow(log_df)] <- format_session_date(session_date)
  sort_log_by_date(log_df)
}

normalize_session_log <- function(df) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
    return(NULL)
  }
  miss <- setdiff(LOG_COLS_REQUIRED, names(df))
  if (length(miss)) {
    stop("CSV missing required columns: ", paste(miss, collapse = ", "), call. = FALSE)
  }
  df <- ensure_log_schema(df)
  if (any(!nzchar(df$date)) || any(is.na(as.Date(df$date)))) {
    stop("Session log requires a valid date (yyyy-mm-dd) on every row.", call. = FALSE)
  }
  df
}

progress_inputs_valid <- function(current_hr, current_duration) {
  hr <- suppressWarnings(as.numeric(current_hr))
  dur <- suppressWarnings(as.numeric(current_duration))
  length(hr) > 0L && length(dur) > 0L &&
    !is.na(hr) && !is.na(dur) && hr > 0 && dur > 0
}

resolve_symptom_onset_min <- function(symptom_onset_range) {
  v <- suppressWarnings(as.numeric(symptom_onset_range))
  if (length(v) == 0L || is.na(v)) {
    return(NA_integer_)
  }
  as.integer(v)
}

append_v02_fields <- function(log_df, rpe, symptom_onset_min) {
  log_df <- ensure_log_schema(log_df)
  n <- nrow(log_df)
  if (n == 0L) {
    return(log_df)
  }
  log_df$rpe[n] <- suppressWarnings(as.numeric(rpe))
  log_df$symptom_onset_min[n] <- symptom_onset_min
  log_df
}

empty_log_template <- function() {
  data.frame(
    date = character(0),
    pcss = integer(0),
    target_hr = integer(0),
    achieved_hr = integer(0),
    duration_min = integer(0),
    symptoms_worsened = logical(0),
    rpe = numeric(0),
    symptom_onset_min = numeric(0),
    stringsAsFactors = FALSE
  )
}

rx_has_bctt <- function(rx) {
  if (is.null(rx) || is.null(rx$method)) {
    return(FALSE)
  }
  grepl("BCTT", rx$method, ignore.case = TRUE)
}
