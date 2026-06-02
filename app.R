# PPCSexRx Shiny App v0.2 - Athletic Trainer clinical tool
options(encoding = "UTF-8")

local({
  ulib <- Sys.getenv("R_LIBS_USER", file.path(Sys.getenv("HOME"), "R", "library"))
  if (dir.exists(ulib)) .libPaths(c(ulib, .libPaths()))
})

library(shiny)
library(bslib)
library(PPCSexRx)

# AL_HOOK_v02: returns NA - activate only after IRB approval

for (helper_file in c("pdf_log.R", "plots.R", "bayes.R", "messages.R")) {
  helper_path <- file.path(getwd(), "R", helper_file)
  if (file.exists(helper_path)) {
    source(helper_path, local = FALSE)
  }
}

load_i18n_en <- function(path = "i18n/en.csv") {
  if (!file.exists(path)) {
    stop("Missing i18n placeholder: ", path, call. = FALSE)
  }
  df <- read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  setNames(df$value, df$key)
}

fuse_tripped_pcss <- function(current_pcss, previous_pcss) {
  if (is.null(current_pcss) || is.null(previous_pcss)) return(FALSE)
  curr <- suppressWarnings(as.numeric(current_pcss))
  prev <- suppressWarnings(as.numeric(previous_pcss))
  if (is.na(curr) || is.na(prev)) return(FALSE)
  (curr - prev) >= 2
}

L <- load_i18n_en()

minty_theme <- bs_theme(
  version = 5,
  preset  = "minty",
  "font-scale" = 0.95
)

clinical_sidebar <- sidebar(
  width = 340,
  navset_pill(
    id = "sidebar_panel",
    selected = "profile",
    nav_panel(
      value = "profile",
      title = tagList(icon("user"), L[["nav_profile"]]),
      numericInput("age", L[["lbl_age"]], value = 16, min = 13, max = 18, step = 1),
      numericInput("days_post_injury", L[["lbl_days_post_injury"]], value = 35, min = 0, step = 1),
      checkboxInput("vestibular_symptoms", L[["lbl_vestibular"]], value = FALSE),
      checkboxInput("cervical_symptoms", L[["lbl_cervical"]], value = FALSE),
      checkboxInput("vision_symptoms", L[["lbl_vision"]], value = FALSE)
    ),
    nav_panel(
      value = "prescription",
      title = tagList(icon("file-prescription"), L[["nav_prescription"]]),
      numericInput("hrst", L[["lbl_hrst"]], value = NA, min = 0, step = 1),
      numericInput("sessions_completed", L[["lbl_sessions_completed"]], value = 0, min = 0, step = 1),
      checkboxInput("last_session_worse", L[["lbl_last_session_worse"]], value = FALSE)
    ),
    nav_panel(
      value = "progress",
      title = tagList(icon("chart-line"), L[["nav_progress"]]),
      numericInput("current_pcss", L[["lbl_current_pcss"]], value = NA, min = 0, max = 132, step = 1),
      numericInput("previous_pcss", L[["lbl_previous_pcss"]], value = NA, min = 0, max = 132, step = 1),
      numericInput("current_hr", L[["lbl_current_hr"]], value = NA, min = 0, step = 1),
      numericInput("current_duration", L[["lbl_current_duration"]], value = NA, min = 0, step = 1),
      sliderInput(
        "rpe",
        "Perceived exertion (Borg RPE 6-20)",
        min = 6,
        max = 20,
        value = 13,
        step = 1
      ),
      checkboxInput(
        "full_session",
        "Completed full 20 min without symptoms",
        value = FALSE
      ),
      numericInput(
        "symptom_onset_min",
        "If symptoms occurred, at what minute?",
        value = NA,
        min = 0,
        max = 20,
        step = 1
      ),
      radioButtons(
        "post_symptom_severity",
        "Symptoms after exercise:",
        choices = c(
          "No symptoms" = 0,
          "Symptoms, resolved within 30 min" = 1,
          "Symptoms persisted more than 30 min" = 2
        ),
        selected = 0
      ),
      helpText(L[["fuse_hint"]])
    )
  ),
  hr(),
  div(
    class = "d-grid gap-2",
    actionButton("calc", tagList(icon("calculator"), L[["btn_calculate"]]), class = "btn-primary"),
    actionButton("reset", tagList(icon("rotate-left"), L[["btn_reset"]]), class = "btn-outline-secondary")
  )
)

ui <- page_sidebar(
  title = tags$span(icon("heart-pulse"), L[["app_title"]]),
  theme = minty_theme,
  sidebar = clinical_sidebar,
  tags$head(
    tags$meta(charset = "UTF-8"),
    tags$script(HTML("
      Shiny.addCustomMessageHandler('copyToClipboard', function(text) {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(function() {
            Shiny.setInputValue('clipboard_copied', Date.now());
          }).catch(function() {
            var el = document.createElement('textarea');
            el.value = text;
            document.body.appendChild(el);
            el.select();
            document.execCommand('copy');
            document.body.removeChild(el);
            Shiny.setInputValue('clipboard_copied', Date.now());
          });
        } else {
          var el = document.createElement('textarea');
          el.value = text;
          document.body.appendChild(el);
          el.select();
          document.execCommand('copy');
          document.body.removeChild(el);
          Shiny.setInputValue('clipboard_copied', Date.now());
        }
      });
    "))
  ),
  layout_columns(
    col_widths = c(12, 6, 6),
    card(
      class = "border-info",
      full_screen = FALSE,
      card_body(
        tags$h6(class = "text-info mb-2", icon("list-ol"), " Quick start"),
        tags$ol(
          class = "mb-0 small",
          tags$li(L[["guide_step1"]]),
          tags$li(L[["guide_step2"]]),
          tags$li(L[["guide_step3"]])
        )
      )
    ),
    card(
      full_screen = TRUE,
      card_header(class = "bg-secondary text-white", tags$span(icon("clipboard-check"), L[["card_screen"]])),
      card_body(uiOutput("screen_display"))
    ),
    card(
      full_screen = TRUE,
      card_header(class = "bg-primary text-white", tags$span(icon("gauge-high"), L[["card_target_hr"]])),
      card_body(uiOutput("target_hr_display"))
    ),
    card(
      full_screen = TRUE,
      card_header(class = "bg-success text-white", tags$span(icon("list-ol"), L[["card_prescription"]])),
      card_body(tableOutput("prescription_table"))
    ),
    card(
      class = "border-warning",
      full_screen = FALSE,
      card_header(class = "bg-warning text-dark", tags$span(icon("bolt"), L[["fuse_title"]])),
      card_body(
        uiOutput("fuse_status"),
        verbatimTextOutput("fuse_detail", placeholder = TRUE)
      )
    ),
    card(
      full_screen = FALSE,
      card_header(tags$span(icon("chart-line"), L[["card_track"]])),
      card_body(
        uiOutput("track_display"),
        hr(),
        tableOutput("progress_log_table"),
        tags$small(class = "text-muted", L[["disclaimer"]])
      )
    ),
    card(
      full_screen = FALSE,
      card_header(tags$span(icon("file-export"), "Export / import")),
      card_body(uiOutput("clinical_exports_ui"))
    ),
    card(
      full_screen = FALSE,
      card_header(tags$span(icon("comment"), "Send to")),
      card_body(uiOutput("send_to_ui"))
    ),
    uiOutput("analytics_panel")
  )
)

server <- function(input, output, session) {
  has_calculated <- reactiveVal(FALSE)
  copy_note <- reactiveVal("")

  state <- reactiveValues(
    screen       = NULL,
    rx           = NULL,
    track        = NULL,
    log          = NULL,
    fuse_tripped = FALSE,
    fuse_message = ""
  )

  show_analytics <- reactive({
    log_df <- state$log
    !is.null(log_df) && is.data.frame(log_df) && nrow(log_df) >= 2L
  })

  observeEvent(input$full_session, {
    if (isTRUE(input$full_session)) {
      updateNumericInput(session, "symptom_onset_min", value = 20)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$reset, {
    has_calculated(FALSE)
    copy_note("")
    state$screen       <- NULL
    state$rx           <- NULL
    state$track        <- NULL
    state$log          <- NULL
    state$fuse_tripped <- FALSE
    state$fuse_message <- ""
    updateNumericInput(session, "age", value = 16)
    updateNumericInput(session, "days_post_injury", value = 35)
    updateNumericInput(session, "hrst", value = NA)
    updateNumericInput(session, "sessions_completed", value = 0)
    updateNumericInput(session, "current_pcss", value = NA)
    updateNumericInput(session, "previous_pcss", value = NA)
    updateNumericInput(session, "current_hr", value = NA)
    updateNumericInput(session, "current_duration", value = NA)
    updateSliderInput(session, "rpe", value = 13)
    updateCheckboxInput(session, "full_session", value = FALSE)
    updateNumericInput(session, "symptom_onset_min", value = NA)
    updateRadioButtons(session, "post_symptom_severity", selected = 0)
    updateCheckboxInput(session, "vestibular_symptoms", value = FALSE)
    updateCheckboxInput(session, "cervical_symptoms", value = FALSE)
    updateCheckboxInput(session, "vision_symptoms", value = FALSE)
    updateCheckboxInput(session, "last_session_worse", value = FALSE)
  })

  observeEvent(input$calc, {
    has_calculated(TRUE)
    state$fuse_tripped <- FALSE
    state$fuse_message <- ""

    state$screen <- PPCSexRx::screen_ppcs(
      age                 = input$age,
      days_post_injury    = input$days_post_injury,
      vestibular_symptoms = isTRUE(input$vestibular_symptoms),
      cervical_symptoms   = isTRUE(input$cervical_symptoms),
      vision_symptoms     = isTRUE(input$vision_symptoms)
    )

    if (!identical(state$screen$status, "eligible")) {
      state$rx    <- NULL
      state$track <- NULL
      return()
    }

    hrst_val <- suppressWarnings(as.numeric(input$hrst))
    if (length(hrst_val) == 0L || is.na(hrst_val)) hrst_val <- NULL

    state$rx <- PPCSexRx::prescribe_ppcs(
      age                 = input$age,
      days_post_injury    = input$days_post_injury,
      hrst                = hrst_val,
      vestibular_symptoms = isTRUE(input$vestibular_symptoms),
      cervical_symptoms   = isTRUE(input$cervical_symptoms),
      sessions_completed  = as.integer(input$sessions_completed),
      last_session_worse  = isTRUE(input$last_session_worse)
    )

    state$fuse_tripped <- fuse_tripped_pcss(input$current_pcss, input$previous_pcss)
    if (state$fuse_tripped) {
      delta <- as.numeric(input$current_pcss) - as.numeric(input$previous_pcss)
      state$fuse_message <- sprintf(
        "PCSS increased by %s (>= 2). Next session prescription locked.",
        format(delta, trim = TRUE)
      )
    }

    if (progress_inputs_valid(input$current_hr, input$current_duration)) {
      pkg_log <- NULL
      if (!is.null(state$log) && is.data.frame(state$log) && nrow(state$log) > 0L) {
        pkg_log <- state$log[, LOG_COLS_REQUIRED, drop = FALSE]
      }
      state$track <- PPCSexRx::track_progress(
        log              = pkg_log,
        current_pcss     = input$current_pcss,
        current_hr       = input$current_hr,
        current_duration = input$current_duration,
        prescription     = state$rx
      )
      onset_min <- resolve_symptom_onset_min(
        input$full_session,
        input$symptom_onset_min
      )
      state$log <- append_v02_fields(
        state$track$updated_log,
        rpe = input$rpe,
        symptom_onset_min = onset_min,
        post_symptom_severity = input$post_symptom_severity
      )
    } else {
      state$track <- NULL
    }
  })

  output$clinical_exports_ui <- renderUI({
    if (!has_calculated() || is.null(state$rx)) {
      return(tags$p(class = "text-muted", L[["placeholder"]]))
    }
    cols_help <- paste(LOG_COLS, collapse = ", ")
    tagList(
      div(
        class = "d-grid gap-2 mb-3",
        downloadButton(
          "download_pdf",
          tagList(icon("file-pdf"), " Download Prescription PDF"),
          class = "btn-success"
        ),
        downloadButton(
          "download_csv",
          tagList(icon("file-csv"), " Download Session Log (CSV)"),
          class = "btn-outline-primary"
        )
      ),
      fileInput(
        "upload_log",
        "Upload Previous Log (CSV)",
        accept = c("text/csv", ".csv"),
        buttonLabel = "Browse...",
        placeholder = "No file selected"
      ),
      tags$p(class = "text-muted small mb-2", "Columns: ", cols_help),
      uiOutput("upload_log_status"),
      tableOutput("uploaded_log_preview")
    )
  })

  output$send_to_ui <- renderUI({
    if (!has_calculated()) {
      return(tags$p(class = "text-muted", L[["placeholder"]]))
    }
    screen <- state$screen
    if (!is.null(screen) && identical(screen$status, "needs_referral")) {
      return(tagList(
        textInput("at_name", "Your name (for messages):", value = ""),
        div(
          class = "d-grid gap-2",
          actionButton(
            "copy_referral_msg",
            "Copy Referral Notice",
            class = "btn-warning"
          )
        ),
        textOutput("copy_confirmation")
      ))
    }
    if (is.null(state$rx)) {
      return(tags$p(class = "text-muted", L[["placeholder"]]))
    }
    fused <- isTRUE(state$fuse_tripped)
    parent_lbl <- if (fused) L[["btn_copy_parent_safety"]] else L[["btn_copy_parent_rx"]]
    athlete_lbl <- if (fused) L[["btn_copy_athlete_safety"]] else L[["btn_copy_athlete_rx"]]
    tagList(
      if (fused) {
        tags$div(
          class = "alert alert-warning small py-2",
          icon("triangle-exclamation"),
          " ",
          L[["send_to_fuse_hint"]]
        )
      },
      textInput("at_name", "Your name (for messages):", value = ""),
      div(
        class = "d-grid gap-2",
        actionButton(
          "copy_parent_msg",
          parent_lbl,
          class = if (fused) "btn-warning" else "btn-outline-success"
        ),
        actionButton(
          "copy_athlete_msg",
          athlete_lbl,
          class = if (fused) "btn-warning" else "btn-outline-info"
        )
      ),
      textOutput("copy_confirmation")
    )
  })

  observeEvent(input$copy_referral_msg, {
    screen <- state$screen
    req(screen, identical(screen$status, "needs_referral"))
    at_name <- if (is.null(input$at_name)) "" else input$at_name
    session$sendCustomMessage(
      "copyToClipboard",
      generate_referral_message(screen, at_name)
    )
    copy_note("Referral notice copied to clipboard.")
  }, ignoreInit = TRUE)

  observeEvent(input$copy_parent_msg, {
    req(state$rx)
    at_name <- if (is.null(input$at_name)) "" else input$at_name
    session$sendCustomMessage(
      "copyToClipboard",
      generate_parent_message(state$rx, at_name, fuse_tripped = state$fuse_tripped)
    )
    copy_note(
      if (isTRUE(state$fuse_tripped)) {
        "Parent safety notice copied to clipboard."
      } else {
        "Parent message copied to clipboard."
      }
    )
  }, ignoreInit = TRUE)

  observeEvent(input$copy_athlete_msg, {
    req(state$rx)
    at_name <- if (is.null(input$at_name)) "" else input$at_name
    session$sendCustomMessage(
      "copyToClipboard",
      generate_athlete_message(state$rx, at_name, fuse_tripped = state$fuse_tripped)
    )
    copy_note(
      if (isTRUE(state$fuse_tripped)) {
        "Athlete safety notice copied to clipboard."
      } else {
        "Athlete message copied to clipboard."
      }
    )
  }, ignoreInit = TRUE)

  observeEvent(input$clipboard_copied, {
    copy_note("Copied to clipboard.")
  }, ignoreInit = TRUE)

  output$copy_confirmation <- renderText({
    copy_note()
  })

  output$download_pdf <- downloadHandler(
    filename = function() {
      sprintf("PPCSexRx_prescription_%s.pdf", format(Sys.Date(), "%Y%m%d"))
    },
    content = function(file) {
      req(state$rx)
      tmp <- render_prescription_pdf(state$rx)
      file.copy(tmp, file, overwrite = TRUE)
      unlink(tmp)
    }
  )

  output$download_csv <- downloadHandler(
    filename = function() {
      sprintf("PPCSexRx_session_log_%s.csv", format(Sys.Date(), "%Y%m%d"))
    },
    content = function(file) {
      log_df <- state$log
      if (is.null(log_df) || !is.data.frame(log_df) || nrow(log_df) == 0L) {
        write.csv(empty_log_template(), file, row.names = FALSE)
      } else {
        write.csv(ensure_log_schema(log_df), file, row.names = FALSE)
      }
    }
  )

  observeEvent(input$upload_log, {
    req(input$upload_log$datapath)
    df <- tryCatch(
      read.csv(
        input$upload_log$datapath,
        stringsAsFactors = FALSE,
        fileEncoding = "UTF-8"
      ),
      error = function(e) {
        showNotification(paste("CSV read error:", e$message), type = "error")
        NULL
      }
    )
    if (is.null(df)) return()
    df <- tryCatch(
      normalize_session_log(df),
      error = function(e) {
        showNotification(e$message, type = "error")
        NULL
      }
    )
    if (is.null(df)) return()
    state$log <- df
    showNotification(
      sprintf("Loaded %d session(s) from CSV.", nrow(df)),
      type = "message"
    )
  }, ignoreInit = TRUE)

  output$upload_log_status <- renderUI({
    log_df <- state$log
    if (is.null(log_df) || !is.data.frame(log_df) || nrow(log_df) == 0L) {
      return(NULL)
    }
    tags$p(
      class = "text-success small",
      icon("circle-check"),
      sprintf(" Session log active: %d row(s). New sessions append on Calculate.", nrow(log_df))
    )
  })

  output$uploaded_log_preview <- renderTable({
    log_df <- state$log
    if (is.null(log_df) || !is.data.frame(log_df) || nrow(log_df) == 0L) {
      return(NULL)
    }
    head(ensure_log_schema(log_df), 10L)
  }, bordered = TRUE)

  output$analytics_panel <- renderUI({
    if (!show_analytics()) {
      return(NULL)
    }
    log_df <- state$log
    n_sess <- nrow(log_df)
    layout_columns(
      col_widths = 12,
      card(
        full_screen = TRUE,
        card_header("Analytics"),
        card_body(
          card(
            card_header("Recovery Trend"),
            card_body(
              plotly::plotlyOutput("pcss_trend_plot", height = "360px"),
              hr(),
              plotly::plotlyOutput("onset_trend_plot", height = "360px")
            )
          ),
          card(
            card_header("Prescription Guidance"),
            card_body(
              uiOutput("bayes_recommendation"),
              tags$details(
                tags$summary("View evidence basis"),
                tags$p(paste0("Based on ", n_sess, " sessions + published evidence prior")),
                tags$p("Prior source: Li G. (2026). 7 studies, n~1132. GRADE: LOW certainty."),
                tags$p("NATA 2024 Bridge Statement: individualize based on symptom response.")
              )
            )
          )
        )
      )
    )
  })

  output$pcss_trend_plot <- plotly::renderPlotly({
    req(show_analytics())
    plot_pcss_trend(ensure_log_schema(state$log))
  })

  output$onset_trend_plot <- plotly::renderPlotly({
    req(show_analytics())
    p <- plot_onset_trend(ensure_log_schema(state$log))
    if (is.null(p)) {
      plotly::plotly_empty() |>
        plotly::layout(
          title = "Symptom onset chart requires 2+ sessions with onset time recorded"
        )
    } else {
      p
    }
  })

  output$bayes_recommendation <- renderUI({
    req(show_analytics())
    rec <- generate_bayes_recommendation(
      ensure_log_schema(state$log),
      rx_has_bctt(state$rx)
    )
    alert_class <- switch(
      rec$level,
      info    = "alert-info",
      warning = "alert-warning",
      success = "alert-success",
      "alert-secondary"
    )
    tags$div(class = paste("alert", alert_class), rec$text)
  })

  output$screen_display <- renderUI({
    screen <- state$screen
    if (is.null(screen)) {
      return(tags$p(class = "text-muted", L[["placeholder"]]))
    }
    status_class <- switch(
      screen$status,
      eligible        = "success",
      contraindicated = "danger",
      needs_referral  = "warning",
      "secondary"
    )
    tags$div(
      tags$p(tags$strong("Status: "), screen$status, class = paste0("text-", status_class)),
      tags$p(tags$strong("Reason: "), screen$reason),
      if (!is.null(screen$referral) && !is.na(screen$referral)) {
        tags$p(tags$strong("Referral: "), screen$referral)
      },
      tags$p(tags$strong("Next step: "), screen$next_step)
    )
  })

  output$target_hr_display <- renderUI({
    rx <- state$rx
    if (is.null(rx)) {
      return(tags$p(class = "text-muted", L[["placeholder"]]))
    }
    age_pred <- grepl("age-predicted", rx$method, ignore.case = TRUE)
    tags$div(
      class = "display-4 text-primary",
      sprintf("%d %s", as.integer(rx$target_hr), L[["unit_bpm"]]),
      if (age_pred) {
        tags$p(
          class = "small text-muted mt-3 mb-0",
          "Note: Li (2026) recommends starting at 50% HRmax when BCTT is unavailable. ",
          "Current value uses package default (60-70% HRmax)."
        )
      }
    )
  })

  output$prescription_table <- renderTable({
    if (is.null(state$rx)) {
      return(data.frame(Field = L[["placeholder"]], Value = L[["placeholder"]]))
    }
    rx <- state$rx
    data.frame(
      Field = c(
        "Duration (min)",
        "Frequency (/week)",
        "Method",
        "Clinical note",
        "Safety warning",
        "Evidence grade",
        "Citation"
      ),
      Value = c(
        rx$duration_min,
        rx$frequency_per_week,
        rx$method,
        rx$clinical_note,
        rx$safety_warning,
        rx$evidence_grade,
        rx$citation
      ),
      stringsAsFactors = FALSE
    )
  }, bordered = TRUE, align = "lr")

  output$fuse_status <- renderUI({
    if (is.null(state$screen) && is.null(state$rx)) {
      return(tags$p(class = "text-muted", L[["placeholder"]]))
    }
    if (isTRUE(state$fuse_tripped)) {
      return(tags$div(
        class = "alert alert-danger mb-0",
        tags$strong(icon("triangle-exclamation"), L[["fuse_tripped"]])
      ))
    }
    tags$div(
      class = "alert alert-success mb-0",
      tags$strong(icon("circle-check"), L[["fuse_ok"]])
    )
  })

  output$fuse_detail <- renderText({
    if (isTRUE(state$fuse_tripped)) state$fuse_message else ""
  })

  output$track_display <- renderUI({
    if (!is.null(state$screen) && !identical(state$screen$status, "eligible")) {
      return(tags$p(class = "text-danger", icon("ban"), L[["screen_fail"]]))
    }
    if (isTRUE(state$fuse_tripped)) {
      return(tags$p(class = "text-warning", icon("lock"), L[["rx_locked"]]))
    }
    track <- state$track
    if (is.null(track)) {
      return(tags$p(class = "text-muted", L[["placeholder"]]))
    }
    tags$div(
      tags$p(tags$strong("Phase: "), track$phase),
      tags$p(tags$strong("Recommendation: "), track$recommendation),
      tags$p(tags$strong("Adjust HR: "), track$adjust_hr, " ", L[["unit_bpm"]]),
      tags$p(tags$strong("Sessions total: "), track$sessions_total),
      tags$p(tags$strong("PCSS change: "), track$pcss_change)
    )
  })

  output$progress_log_table <- renderTable({
    log_df <- state$log
    ph <- L[["placeholder"]]
    if (is.null(log_df) || !is.data.frame(log_df) || nrow(log_df) == 0L) {
      return(data.frame(
        date = ph,
        pcss = ph,
        target_hr = ph,
        achieved_hr = ph,
        duration_min = ph,
        symptoms_worsened = ph,
        rpe = ph,
        symptom_onset_min = ph,
        post_symptom_severity = ph,
        check.names = FALSE
      ))
    }
    ensure_log_schema(log_df)
  }, bordered = TRUE)
}

shinyApp(ui = ui, server = server)
