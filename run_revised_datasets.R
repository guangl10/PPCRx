#!/usr/bin/env Rscript
# Generate revised synthetic CSVs and report chart/Bayesian analysis

source("R/pdf_log.R")
source("R/plots.R")
source("R/bayes.R")

weekdays_may2026 <- function(n) {
  d <- as.Date("2026-05-01") + 0:20
  d <- d[!weekdays(d) %in% c("Saturday", "Sunday")]
  format(head(d, n), "%Y-%m-%d")
}

write_log_csv <- function(path, df) {
  df <- ensure_log_schema(df)
  write.csv(df, path, row.names = FALSE)
  path
}

describe_pcss_chart <- function(log_df) {
  sess <- seq_len(nrow(log_df))
  pcss <- log_df$pcss
  ma <- moving_avg3(pcss)
  rpe <- log_df$rpe
  cols <- rpe_point_color(rpe)

  total_drop <- pcss[1] - pcss[length(pcss)]
  per_sess <- mean(-diff(pcss), na.rm = TRUE)
  shape <- if (per_sess >= 1.2) {
    "steep downward"
  } else if (per_sess >= 0.4) {
    "moderate downward"
  } else if (per_sess > 0.1) {
    "slight downward / nearly flat"
  } else if (abs(per_sess) <= 0.1) {
    "flat"
  } else {
    "variable or upward"
  }

  n_green <- sum(cols == "green", na.rm = TRUE)
  n_gold <- sum(cols == "gold", na.rm = TRUE)
  n_red <- sum(cols == "red", na.rm = TRUE)
  n_grey <- sum(cols == "grey", na.rm = TRUE)

  ma_diff <- max(abs(ma - pcss), na.rm = TRUE)
  ma_note <- if (is.finite(ma_diff) && ma_diff >= 1.5) {
    sprintf("yes — moving average diverges up to %.1f PCSS points from actual at some sessions", ma_diff)
  } else if (is.finite(ma_diff) && ma_diff >= 0.5) {
    sprintf("subtle — max gap %.1f PCSS; visible on close inspection", ma_diff)
  } else {
    "minimal — nearly overlaps the PCSS line"
  }

  mcid_visible <- min(pcss) > 10 || max(pcss) >= 10
  mcid_note <- if (min(pcss) <= 12 && max(pcss) >= 8) {
    "MCID reference line at y=10 is within y-axis (0–132); labeled 'Clinically meaningful change threshold (Li, 2026)'"
  } else if (all(pcss > 15)) {
    "MCID line at y=10 is visible at bottom of chart but far below data range"
  } else {
    "MCID line at y=10 visible; annotation at right edge"
  }

  list(
    shape = shape,
    total_drop = total_drop,
    per_sess_drop = per_sess,
    rpe_colors = sprintf("%d green, %d gold, %d red, %d grey (of %d sessions)", n_green, n_gold, n_red, n_grey, length(cols)),
    rpe_session_detail = paste0("S", sess, ":RPE", rpe, "=", cols, collapse = "; "),
    ma_vs_actual = ma_note,
    mcid = mcid_note,
    pcss_range = sprintf("%d to %d", min(pcss), max(pcss)),
    target_hr_in_chart = "No — Chart 1 plots PCSS + RPE only; target_hr is not displayed (see session log table)"
  )
}

describe_onset_chart <- function(log_df) {
  onset <- log_df$symptom_onset_min
  if (sum(is.finite(onset)) < 2L) {
    return(list(shape = "N/A", goal_gap = "N/A", goal_line = "N/A"))
  }

  valid <- onset[is.finite(onset)]
  delta <- tail(valid, 1) - head(valid, 1)
  shape <- if (delta >= 5) {
    "clearly improving (upward toward 20 min)"
  } else if (delta >= 2) {
    "mildly improving"
  } else if (abs(delta) <= 1) {
    "flat / plateau"
  } else {
    "declining (worsening onset)"
  }

  gap_goal <- 20 - valid
  list(
    shape = shape,
    onset_range = sprintf("%.0f–%.0f min", min(valid), max(valid)),
    goal_gap = sprintf("last session %.0f min below goal (%.0f min to goal line)", 20 - tail(valid, 1), tail(valid, 1)),
    avg_gap = sprintf("mean %.1f min below goal across sessions", mean(gap_goal)),
    goal_line = "Goal line at y=20 (green dotted) with label 'Goal: full session' — visible within 0–20 y-axis",
    onset_colors = paste0("S", seq_along(onset), ":", onset, "=", onset_point_color(onset), collapse = "; ")
  )
}

at_jane_sentence <- function(log_df, bayes_text, pcss_desc, onset_desc) {
  n <- nrow(log_df)
  last_pcss <- tail(log_df$pcss, 1)
  first_pcss <- log_df$pcss[1]
  rpe_last3 <- tail(log_df$rpe, 3)
  onset_last <- tail(log_df$symptom_onset_min, 1)

  if (grepl("RPE has increased", bayes_text)) {
    return(sprintf(
      "Symptoms are only improving slowly (PCSS %d→%d) while perceived exertion is climbing (RPE %s), so I should hold HR before advancing.",
      first_pcss, last_pcss, paste(rpe_last3, collapse = "/")
    ))
  }
  if (grepl("exceeds the published", bayes_text)) {
    return(sprintf(
      "This athlete is recovering faster than expected (PCSS %d→%d, onset now %s min) and standard HR progression looks appropriate.",
      first_pcss, last_pcss, ifelse(is.finite(onset_last), as.character(onset_last), "?")
    ))
  }
  if (grepl("slower than the published", bayes_text)) {
    return(sprintf(
      "Symptom scores are dropping more slowly than typical evidence (PCSS %d→%d), so I should progress conservatively and look for barriers.",
      first_pcss, last_pcss
    ))
  }
  if (grepl("consistent with published", bayes_text)) {
    if (grepl("flat", pcss_desc$shape, ignore.case = TRUE)) {
      return(sprintf(
        "PCSS is plateauing (%d→%d) with stable symptom onset around %s min — stay the course but watch RPE.",
        first_pcss, last_pcss, onset_desc$onset_range
      ))
    }
    return(sprintf(
      "Recovery is tracking published norms (PCSS %d→%d over %d sessions) with tolerable symptom onset — continue current plan.",
      first_pcss, last_pcss, n
    ))
  }
  sprintf("PCSS %d→%d over %d sessions — review chart and log for next prescription step.", first_pcss, last_pcss, n)
}

analyze_dataset <- function(name, log_df, has_bctt = TRUE) {
  log_df <- ensure_log_schema(log_df)
  pcss_desc <- describe_pcss_chart(log_df)
  onset_desc <- describe_onset_chart(log_df)
  bayes <- generate_bayes_recommendation(log_df, has_bctt)
  prior <- get_prior(has_bctt)
  post <- bayes_update(prior$pcss_rate_mu, prior$pcss_rate_sigma, -diff(log_df$pcss))

  list(
    name = name,
    n = nrow(log_df),
    pcss = pcss_desc,
    onset = onset_desc,
    bayes = bayes,
    post_mu = post$mu,
    prior_mu = prior$pcss_rate_mu,
    jane = at_jane_sentence(log_df, bayes$text, pcss_desc, onset_desc)
  )
}

# Dataset 1
d1 <- data.frame(
  date = weekdays_may2026(10),
  pcss = c(28, 26, 24, 22, 20, 18, 16, 14, 12, 10),
  target_hr = 128,
  achieved_hr = c(126, 127, 128, 128, 127, 128, 128, 127, 128, 128),
  duration_min = c(18, 20, 20, 20, 20, 20, 20, 20, 20, 20),
  symptoms_worsened = FALSE,
  rpe = c(13, 12, 13, 12, 12, 11, 12, 11, 11, 10),
  symptom_onset_min = c(10, 12, 14, 15, 16, 17, 18, 19, 20, 20),
  post_symptom_severity = c(1, 1, 0, 0, 0, 0, 0, 0, 0, 0),
  stringsAsFactors = FALSE
)

dates8 <- weekdays_may2026(8)

# Dataset 2
d2 <- data.frame(
  date = dates8,
  pcss = c(28, 27, 27, 26, 26, 25, 25, 24),
  target_hr = 128,
  achieved_hr = c(125, 126, 127, 126, 127, 126, 127, 126),
  duration_min = 20,
  symptoms_worsened = FALSE,
  rpe = c(13, 13, 14, 14, 15, 15, 16, 16),
  symptom_onset_min = c(10, 10, 11, 10, 11, 10, 10, 11),
  post_symptom_severity = 1,
  stringsAsFactors = FALSE
)

# Dataset 3
d3 <- data.frame(
  date = dates8,
  pcss = c(28, 28, 27, 27, 25, 23, 21, 19),
  target_hr = c(128, 128, 128, 128, 120, 120, 123, 125),
  achieved_hr = c(126, 127, 127, 126, 119, 120, 122, 124),
  duration_min = 20,
  symptoms_worsened = FALSE,
  rpe = c(14, 15, 15, 16, 13, 12, 12, 11),
  symptom_onset_min = c(10, 10, 11, 10, 13, 15, 17, 18),
  post_symptom_severity = c(1, 1, 1, 1, 0, 0, 0, 0),
  stringsAsFactors = FALSE
)

# Dataset 4A
d4a <- data.frame(
  date = dates8,
  pcss = c(28, 25, 22, 19, 16, 13, 11, 9),
  target_hr = c(128, 128, 133, 133, 138, 138, 143, 143),
  achieved_hr = c(127, 128, 132, 133, 137, 138, 142, 143),
  duration_min = 20,
  symptoms_worsened = FALSE,
  rpe = c(13, 12, 12, 11, 11, 11, 10, 10),
  symptom_onset_min = c(12, 14, 16, 18, 19, 20, 20, 20),
  post_symptom_severity = c(1, 0, 0, 0, 0, 0, 0, 0),
  stringsAsFactors = FALSE
)

# Dataset 4B
d4b <- data.frame(
  date = dates8,
  pcss = c(28, 27, 27, 26, 26, 25, 25, 24),
  target_hr = 128,
  achieved_hr = c(126, 127, 126, 127, 126, 127, 126, 127),
  duration_min = 20,
  symptoms_worsened = FALSE,
  rpe = c(13, 14, 14, 15, 15, 16, 16, 17),
  symptom_onset_min = c(10, 10, 11, 10, 10, 11, 10, 10),
  post_symptom_severity = 1,
  stringsAsFactors = FALSE
)

datasets <- list(
  list(file = "samples/revised_dataset1_fast_recovery.csv", df = d1, label = "Dataset 1: Fast recovery (Kurowski-style)"),
  list(file = "samples/revised_dataset2_plateau.csv", df = d2, label = "Dataset 2: Plateau + RPE rise (Gladstone-style)"),
  list(file = "samples/revised_dataset3_breakthrough.csv", df = d3, label = "Dataset 3: Plateau breakthrough (HR reduced S5)"),
  list(file = "samples/revised_dataset4a_fast.csv", df = d4a, label = "Dataset 4A: Fast recovery + HR progression"),
  list(file = "samples/revised_dataset4b_slow.csv", df = d4b, label = "Dataset 4B: Slow recovery + RPE rise")
)

dir.create("samples", showWarnings = FALSE)
dir.create("e2e_reports/revised_charts", showWarnings = FALSE, recursive = TRUE)

for (ds in datasets) {
  write_log_csv(ds$file, ds$df)
}

if (requireNamespace("plotly", quietly = TRUE) && requireNamespace("htmlwidgets", quietly = TRUE)) {
  for (ds in datasets) {
    log_df <- ensure_log_schema(ds$df)
    p1 <- plot_pcss_trend(log_df)
    p2 <- plot_onset_trend(log_df)
    base <- sub("\\.csv$", "", basename(ds$file))
    if (!is.null(p1)) {
      htmlwidgets::saveWidget(plotly::as_widget(p1), file.path("e2e_reports/revised_charts", paste0(base, "_pcss.html")), selfcontained = TRUE)
    }
    if (!is.null(p2)) {
      htmlwidgets::saveWidget(plotly::as_widget(p2), file.path("e2e_reports/revised_charts", paste0(base, "_onset.html")), selfcontained = TRUE)
    }
  }
}

results <- lapply(datasets, function(ds) {
  r <- analyze_dataset(ds$label, ds$df, has_bctt = TRUE)
  r$file <- ds$file
  r
})

for (r in results) {
  cat("\n", strrep("=", 72), "\n", r$name, "\n", strrep("=", 72), "\n", sep = "")
  cat("File:", r$file, "| Sessions:", r$n, "\n")
  cat("Posterior PCSS rate mu:", round(r$post_mu, 3), "| Prior:", r$prior_mu, "\n\n")
  cat("--- Chart 1 (PCSS + RPE) ---\n")
  cat("PCSS shape:", r$pcss$shape, sprintf("(%s, avg %.2f pts/session drop)\n", r$pcss$pcss_range, r$pcss$per_sess_drop))
  cat("RPE dots:", r$pcss$rpe_colors, "\n")
  cat("Detail:", r$pcss$rpe_session_detail, "\n")
  cat("3-session MA vs actual:", r$pcss$ma_vs_actual, "\n")
  cat("MCID line:", r$pcss$mcid, "\n")
  cat("target_hr on chart:", r$pcss$target_hr_in_chart, "\n\n")
  cat("--- Chart 2 (Onset) ---\n")
  cat("Shape:", r$onset$shape, "| Range:", r$onset$onset_range, "\n")
  cat("vs goal:", r$onset$goal_gap, "|", r$onset$avg_gap, "\n")
  cat("Goal line:", r$onset$goal_line, "\n")
  cat("Colors:", r$onset$onset_colors, "\n\n")
  cat("--- Bayesian ---\n")
  cat("[", r$bayes$level, "] ", r$bayes$text, "\n\n", sep = "")
  cat("--- AT Jane (one sentence) ---\n")
  cat(r$jane, "\n\n")
}
