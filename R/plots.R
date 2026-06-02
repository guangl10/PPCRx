# Plotly analytics charts (v0.2)

moving_avg3 <- function(x) {
  if (length(x) < 2L) {
    return(rep(NA_real_, length(x)))
  }
  vapply(seq_along(x), function(i) {
    idx <- max(1L, i - 2L):i
    mean(x[idx], na.rm = TRUE)
  }, numeric(1))
}

rpe_point_color <- function(rpe) {
  ifelse(
    is.na(rpe),
    "grey",
    ifelse(
      rpe <= 11,
      "green",
      ifelse(rpe <= 15, "gold", "red")
    )
  )
}

onset_point_color <- function(onset) {
  ifelse(
    is.na(onset),
    "grey",
    ifelse(
      onset >= 20,
      "green",
      ifelse(onset >= 10, "gold", "red")
    )
  )
}

plot_pcss_trend <- function(log_df) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    return(NULL)
  }
  if (is.null(log_df) || nrow(log_df) < 2L) {
    return(NULL)
  }

  sess <- seq_len(nrow(log_df))
  pcss <- log_df$pcss
  ma <- moving_avg3(pcss)
  colors <- rpe_point_color(log_df$rpe)

  plotly::plot_ly() |>
    plotly::add_trace(
      x = sess,
      y = pcss,
      type = "scatter",
      mode = "lines+markers",
      name = "PCSS",
      line = list(color = "#0d6efd", width = 2),
      marker = list(color = colors, size = 10)
    ) |>
    plotly::add_trace(
      x = sess,
      y = ma,
      type = "scatter",
      mode = "lines",
      name = "3-session moving avg",
      line = list(color = "#6c757d", dash = "dash", width = 2)
    ) |>
    plotly::layout(
      title = "PCSS trend (RPE color-coded)",
      xaxis = list(title = "Session"),
      yaxis = list(title = "PCSS", range = c(0, 132)),
      shapes = list(
        list(
          type = "line",
          x0 = min(sess),
          x1 = max(sess),
          y0 = 10,
          y1 = 10,
          line = list(color = "#dc3545", dash = "dot")
        )
      ),
      annotations = list(
        list(
          x = max(sess),
          y = 10,
          text = "Clinically meaningful change threshold (Li, 2026)",
          showarrow = FALSE,
          yshift = 12,
          font = list(size = 10, color = "#dc3545")
        )
      ),
      legend = list(orientation = "h")
    )
}

plot_onset_trend <- function(log_df) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    return(NULL)
  }
  if (is.null(log_df) || nrow(log_df) < 2L) {
    return(NULL)
  }

  onset <- log_df$symptom_onset_min
  valid_n <- sum(is.finite(onset))
  if (valid_n < 2L) {
    return(NULL)
  }

  sess <- seq_len(nrow(log_df))
  ma <- moving_avg3(onset)
  colors <- onset_point_color(onset)

  plotly::plot_ly() |>
    plotly::add_trace(
      x = sess,
      y = onset,
      type = "scatter",
      mode = "lines+markers",
      name = "Symptom onset (min)",
      line = list(color = "#198754", width = 2),
      marker = list(color = colors, size = 10)
    ) |>
    plotly::add_trace(
      x = sess,
      y = ma,
      type = "scatter",
      mode = "lines",
      name = "3-session moving avg",
      line = list(color = "#6c757d", dash = "dash", width = 2)
    ) |>
    plotly::layout(
      title = "Symptom onset time",
      xaxis = list(title = "Session"),
      yaxis = list(title = "Minute of onset (20 = full session)", range = c(0, 20)),
      shapes = list(
        list(
          type = "line",
          x0 = min(sess),
          x1 = max(sess),
          y0 = 20,
          y1 = 20,
          line = list(color = "#198754", dash = "dot")
        )
      ),
      annotations = list(
        list(
          x = max(sess),
          y = 20,
          text = "Goal: full session",
          showarrow = FALSE,
          yshift = -12,
          font = list(size = 10, color = "#198754")
        )
      ),
      legend = list(orientation = "h")
    )
}
