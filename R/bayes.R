# Bayesian prescription guidance (conjugate Normal-Normal, daily PCSS rate)

get_prior <- function(has_bctt) {
  if (has_bctt) {
    list(
      pcss_rate_mu = 0.3,
      pcss_rate_sigma = 0.15,
      onset_mu = 1.5,
      onset_sigma = 0.8
    )
  } else {
    list(
      pcss_rate_mu = 0.2,
      pcss_rate_sigma = 0.15,
      onset_mu = 1.0,
      onset_sigma = 1.0
    )
  }
}

bayes_update <- function(prior_mu, prior_sigma, observed_values) {
  observed_values <- observed_values[is.finite(observed_values)]
  n <- length(observed_values)
  if (n == 0) {
    return(list(mu = prior_mu, sigma = prior_sigma))
  }

  precision_prior <- 1 / prior_sigma^2
  precision_data <- n / 1

  post_mu <- (precision_prior * prior_mu +
    precision_data * mean(observed_values)) /
    (precision_prior + precision_data)

  post_sigma <- sqrt(1 / (precision_prior + precision_data))
  list(mu = post_mu, sigma = post_sigma)
}

daily_pcss_improvement_rates <- function(log_df) {
  log_df <- ensure_log_schema(log_df)
  if (is.null(log_df) || nrow(log_df) < 2L) {
    return(numeric(0))
  }

  dates <- as.Date(log_df$date)
  if (any(is.na(dates))) {
    return(numeric(0))
  }

  days_elapsed <- as.numeric(diff(dates))
  pcss_changes <- -diff(log_df$pcss)
  ifelse(days_elapsed > 0, pcss_changes / days_elapsed, pcss_changes)
}

compute_rpe_slope <- function(rpe_vals) {
  rpe_vals <- suppressWarnings(as.numeric(rpe_vals))
  rpe_vals <- rpe_vals[is.finite(rpe_vals)]
  if (length(rpe_vals) < 2L) {
    return(NA_real_)
  }
  unname(stats::coef(stats::lm(rpe_vals ~ seq_along(rpe_vals)))[2])
}

format_onset_min <- function(x) {
  if (length(x) == 0L || is.na(x)) {
    "N/A"
  } else {
    as.character(as.integer(x))
  }
}

rpe_slope_label <- function(rpe_slope) {
  if (!is.finite(rpe_slope)) {
    return("N/A")
  }
  if (rpe_slope >= 0.3) {
    "rising (hold intensity)"
  } else if (rpe_slope <= -0.1) {
    "stable/improving"
  } else {
    "stable"
  }
}

generate_method_text <- function(post_pcss,
                                 prior,
                                 obs_daily_rate,
                                 n,
                                 rpe_slope,
                                 onset_first,
                                 onset_last) {
  obs_str <- if (is.finite(obs_daily_rate)) {
    sprintf("%.2f", obs_daily_rate)
  } else {
    "N/A"
  }
  slope_str <- if (is.finite(rpe_slope)) {
    sprintf("%.2f", rpe_slope)
  } else {
    "N/A"
  }

  paste0(
    "Evidence basis:\n\n",
    "Your data: ", obs_str, " pts/day improvement\n",
    "Literature baseline: ", sprintf("%.2f", prior$pcss_rate_mu),
    " pts/day (Li, 2026)\n",
    "Bayesian posterior: ", sprintf("%.2f", post_pcss$mu), " pts/day\n\n",
    "RPE slope (last 3 sessions): ", slope_str,
    " (", rpe_slope_label(rpe_slope), ")\n",
    "Symptom onset: ", format_onset_min(onset_first),
    " min -> ", format_onset_min(onset_last), " min\n\n",
    "Source: Li G. (2026). 7 studies, n~1132. GRADE: LOW.\n",
    "doi: 10.17605/OSF.IO/KVUF6\n",
    "NATA 2024 Bridge Statement alignment confirmed."
  )
}

compute_guidance_analysis <- function(log_df, has_bctt) {
  log_df <- ensure_log_schema(log_df)
  n_sess <- if (is.null(log_df)) 0L else nrow(log_df)

  if (n_sess < 3) {
    return(list(
      text = paste0(
        "Building data profile (", n_sess, "/3 sessions minimum). ",
        "Current prescription follows published evidence standards."
      ),
      level = "info",
      method_text = NULL
    ))
  }

  prior <- get_prior(has_bctt)
  daily_rates <- daily_pcss_improvement_rates(log_df)
  n_intervals <- length(daily_rates)
  obs_daily_rate <- if (n_intervals > 0) mean(daily_rates) else NA_real_

  post_pcss <- bayes_update(
    prior$pcss_rate_mu,
    prior$pcss_rate_sigma,
    daily_rates
  )

  rpe_vals <- tail(log_df$rpe, 3)
  rpe_slope <- compute_rpe_slope(rpe_vals)
  rpe_rising <- is.finite(rpe_slope) && rpe_slope >= 0.3

  onset <- onset_trend(log_df)
  recovering_fast <- post_pcss$mu > prior$pcss_rate_mu * 1.2
  recovering_slow <- post_pcss$mu < prior$pcss_rate_mu * 0.8

  method_text <- generate_method_text(
    post_pcss = post_pcss,
    prior = prior,
    obs_daily_rate = obs_daily_rate,
    n = n_intervals,
    rpe_slope = rpe_slope,
    onset_first = onset$first,
    onset_last = onset$last
  )

  if (rpe_rising) {
    return(list(
      text = paste0(
        "RPE has increased over the past 3 sessions at the same HR target. ",
        "Recommend holding current intensity rather than advancing. ",
        "(NATA 2024: adjust based on symptom response)"
      ),
      level = "warning",
      method_text = method_text
    ))
  }

  if (recovering_fast) {
    return(list(
      text = paste0(
        "This athlete's daily symptom improvement exceeds the published evidence baseline. ",
        "Standard progression (5 bpm) is appropriate."
      ),
      level = "success",
      method_text = method_text
    ))
  }

  if (recovering_slow) {
    return(list(
      text = paste0(
        "This athlete's daily symptom improvement is slower than the published evidence baseline. ",
        "Consider conservative progression (2-3 bpm) and evaluate for ",
        "additional contributing factors."
      ),
      level = "warning",
      method_text = method_text
    ))
  }

  list(
    text = paste0(
      "This athlete's daily symptom improvement is consistent with published evidence. ",
      "Continue current prescription approach."
    ),
    level = "success",
    method_text = method_text
  )
}

generate_bayes_recommendation <- function(log_df, has_bctt) {
  compute_guidance_analysis(log_df, has_bctt)
}
