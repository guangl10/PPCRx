# Bayesian prescription guidance (conjugate Normal-Normal)

get_prior <- function(has_bctt) {
  if (has_bctt) {
    list(
      pcss_rate_mu = 0.6,
      pcss_rate_sigma = 0.25,
      onset_mu = 1.5,
      onset_sigma = 0.8
    )
  } else {
    list(
      pcss_rate_mu = 0.4,
      pcss_rate_sigma = 0.3,
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

generate_bayes_recommendation <- function(log_df, has_bctt) {
  n <- nrow(log_df)

  if (n < 3) {
    return(list(
      text = paste0(
        "Building data profile (", n, "/3 sessions minimum). ",
        "Current prescription follows published evidence standards."
      ),
      level = "info"
    ))
  }

  prior <- get_prior(has_bctt)

  pcss_changes <- -diff(log_df$pcss)
  post_pcss <- bayes_update(
    prior$pcss_rate_mu,
    prior$pcss_rate_sigma,
    pcss_changes
  )

  rpe_vals <- tail(log_df$rpe, 3)
  rpe_rising <- !all(is.na(rpe_vals)) &&
    length(rpe_vals) >= 2 &&
    !is.na(stats::coef(stats::lm(rpe_vals ~ seq_along(rpe_vals)))[2]) &&
    stats::coef(stats::lm(rpe_vals ~ seq_along(rpe_vals)))[2] >= 0.3

  recovering_fast <- post_pcss$mu > prior$pcss_rate_mu * 1.2
  recovering_slow <- post_pcss$mu < prior$pcss_rate_mu * 0.8

  if (rpe_rising) {
    return(list(
      text = paste0(
        "RPE has increased over the past 3 sessions at the same HR target. ",
        "Recommend holding current intensity rather than advancing. ",
        "(NATA 2024: adjust based on symptom response)"
      ),
      level = "warning"
    ))
  }

  if (recovering_fast) {
    return(list(
      text = paste0(
        "This athlete's response exceeds the published evidence baseline. ",
        "Standard progression (5 bpm) is appropriate."
      ),
      level = "success"
    ))
  }

  if (recovering_slow) {
    return(list(
      text = paste0(
        "This athlete's response is slower than the published evidence baseline. ",
        "Consider conservative progression (2-3 bpm) and evaluate for ",
        "additional contributing factors."
      ),
      level = "warning"
    ))
  }

  list(
    text = paste0(
      "This athlete's response is consistent with published evidence. ",
      "Continue current prescription approach."
    ),
    level = "success"
  )
}
