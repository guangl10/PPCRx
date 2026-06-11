# Plotly analytics charts (v0.2) - date-based x-axis

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
      rpe <= 13,
      "green",
      ifelse(rpe <= 16, "gold", "red")
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

plot_date_axis <- function() {
  list(
    type = "date",
    title = "Date",
    tickformat = "%b %d"
  )
}

onset_trend <- function(log_df) {
  if (is.null(log_df) || !"symptom_onset_min" %in% names(log_df)) {
    return(list(first = NA_real_, last = NA_real_))
  }
  onset <- suppressWarnings(as.numeric(log_df$symptom_onset_min))
  valid <- onset[is.finite(onset)]
  if (length(valid) == 0L) {
    return(list(first = NA_real_, last = NA_real_))
  }
  list(first = valid[1], last = valid[length(valid)])
}

prepare_log_for_plots <- function(log_df) {
  log_df <- ensure_log_schema(log_df)
  if (is.null(log_df) || nrow(log_df) < 2L) {
    return(NULL)
  }
  dates <- as.Date(log_df$date)
  if (any(is.na(dates))) {
    return(NULL)
  }
  list(log_df = log_df, dates = dates)
}

plot_pcss_trend <- function(log_df) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    return(NULL)
  }
  prep <- prepare_log_for_plots(log_df)
  if (is.null(prep)) {
    return(NULL)
  }

  log_df <- prep$log_df
  dates <- prep$dates
  pcss <- log_df$pcss
  ma <- moving_avg3(pcss)
  colors <- rpe_point_color(log_df$rpe)
  target_hr <- suppressWarnings(as.numeric(log_df$target_hr))
  show_hr <- sum(is.finite(target_hr)) >= 1L
  x_end <- dates[length(dates)]

  p <- plotly::plot_ly() |>
    plotly::add_trace(
      x = dates,
      y = pcss,
      type = "scatter",
      mode = "lines+markers",
      name = "PCSS",
      line = list(color = "#0d6efd", width = 2),
      marker = list(color = colors, size = 10),
      yaxis = "y"
    ) |>
    plotly::add_trace(
      x = dates,
      y = ma,
      type = "scatter",
      mode = "lines",
      name = "3-session moving avg",
      line = list(color = "#6c757d", dash = "dash", width = 2),
      yaxis = "y"
    )

  if (show_hr) {
    hr_vals <- ifelse(is.finite(target_hr), target_hr, NA_real_)
    p <- p |>
      plotly::add_trace(
        x = dates,
        y = hr_vals,
        type = "scatter",
        mode = "lines",
        name = "Prescribed HR target",
        line = list(color = "#AAAAAA", dash = "dash", width = 2),
        connectgaps = TRUE,
        yaxis = "y2"
      )
  }

  hr_axis <- if (show_hr) {
    hr_finite <- target_hr[is.finite(target_hr)]
    hr_lo <- min(100, floor(min(hr_finite) / 5) * 5 - 5)
    hr_hi <- max(150, ceiling(max(hr_finite) / 5) * 5 + 5)
    if (hr_hi - hr_lo < 25) {
      hr_hi <- hr_lo + 25
    }
    tick_step <- if ((hr_hi - hr_lo) <= 30) 5 else 10
    tickvals <- seq(hr_lo, hr_hi, by = tick_step)
    list(
      range = c(hr_lo, hr_hi),
      tickvals = tickvals,
      ticktext = as.character(tickvals)
    )
  } else {
    NULL
  }

  p <- plotly::layout(
    p,
    title = "PCSS trend (RPE color-coded)",
    margin = list(l = 56, r = if (show_hr) 88 else 40, t = 48, b = 56),
    xaxis = plot_date_axis(),
    yaxis = list(
      title = "PCSS",
      range = c(0, 132),
      autorange = FALSE
    ),
    shapes = list(
      list(
        type = "line",
        x0 = dates[1],
        x1 = x_end,
        y0 = 10,
        y1 = 10,
        line = list(color = "#dc3545", dash = "dot")
      )
    ),
    annotations = list(
      list(
        x = x_end,
        y = 10,
        text = "Clinically meaningful change threshold (Li, 2026)",
        showarrow = FALSE,
        yshift = 12,
        font = list(size = 10, color = "#dc3545")
      )
    ),
    legend = list(orientation = "h")
  )

  if (show_hr && !is.null(hr_axis)) {
    p <- plotly::layout(
      p,
      yaxis2 = list(
        title = list(text = "HR (bpm)", standoff = 12),
        overlaying = "y",
        side = "right",
        range = hr_axis$range,
        autorange = FALSE,
        tickmode = "array",
        tickvals = hr_axis$tickvals,
        ticktext = hr_axis$ticktext,
        ticks = "outside",
        ticklen = 4,
        showgrid = FALSE,
        zeroline = FALSE
      )
    )
  }

  p
}

plot_onset_trend <- function(log_df) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    return(NULL)
  }
  prep <- prepare_log_for_plots(log_df)
  if (is.null(prep)) {
    return(NULL)
  }

  log_df <- prep$log_df
  dates <- prep$dates
  onset <- suppressWarnings(as.numeric(log_df$symptom_onset_min))
  valid_n <- sum(is.finite(onset))
  if (valid_n < 2L) {
    return(NULL)
  }

  ma <- moving_avg3(onset)
  colors <- onset_point_color(onset)
  hovertext <- ifelse(
    is.finite(onset) & onset >= 20,
    "No symptoms",
    paste0("Symptoms at ~", onset, " min")
  )
  x_end <- dates[length(dates)]
  y_tickvals <- c(0, 5, 10, 15, 20)
  y_ticktext <- c("0", "5", "10", "15", "No symptoms")

  plotly::plot_ly() |>
    plotly::add_trace(
      x = dates,
      y = onset,
      type = "scatter",
      mode = "lines+markers",
      name = "Symptom onset (min)",
      line = list(color = "#198754", width = 2),
      marker = list(color = colors, size = 10),
      text = hovertext,
      hoverinfo = "text"
    ) |>
    plotly::add_trace(
      x = dates,
      y = ma,
      type = "scatter",
      mode = "lines",
      name = "3-session moving avg",
      line = list(color = "#6c757d", dash = "dash", width = 2)
    ) |>
    plotly::layout(
      title = "Symptom onset time",
      xaxis = plot_date_axis(),
      yaxis = list(
        title = "Symptom onset",
        range = c(0, 20),
        tickmode = "array",
        tickvals = y_tickvals,
        ticktext = y_ticktext
      ),
      shapes = list(
        list(
          type = "line",
          x0 = dates[1],
          x1 = x_end,
          y0 = 20,
          y1 = 20,
          line = list(color = "#198754", dash = "dot")
        )
      ),
      annotations = list(
        list(
          x = x_end,
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
