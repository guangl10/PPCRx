# PPCSexRx Shiny App v0.2.1 - Athletic Trainer clinical tool
options(encoding = "UTF-8")

local({
  ulib <- Sys.getenv("R_LIBS_USER", file.path(Sys.getenv("HOME"), "R", "library"))
  if (dir.exists(ulib)) .libPaths(c(ulib, .libPaths()))
})

library(shiny)
library(bslib)
library(PPCSexRx)
library(jsonlite)

# AL_HOOK_v02: returns NA - activate only after IRB approval

for (helper_file in c(
  "pdf_log.R", "plots.R", "bayes.R", "messages.R", "pcss_picker.R",
  "clinical_note_pdf.R", "draft_storage.R"
)) {
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

workflow_section <- function(step, title, subtitle = NULL) {
  tags$div(
    class = "workflow-section mb-2",
    tags$span(class = "workflow-step", step),
    tags$h5(class = "workflow-title", title),
    if (!is.null(subtitle) && nzchar(subtitle)) {
      tags$p(class = "workflow-subtitle text-muted", subtitle)
    }
  )
}

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
      textInput(
        "athlete_id",
        "Athlete ID (optional, for PDF export):",
        value = "",
        placeholder = "e.g. JS-2026"
      ),
      textInput(
        "at_name",
        "Clinician name (for PDF and messages):",
        value = "",
        placeholder = "e.g. Jane Smith, AT"
      ),
      selectInput(
        "age",
        L[["lbl_age"]],
        choices = setNames(13:18, paste(13:18, "years")),
        selected = 16
      ),
      numericInput("days_post_injury", L[["lbl_days_post_injury"]], value = 35, min = 0, step = 1),
      checkboxInput("vestibular_symptoms", L[["lbl_vestibular"]], value = FALSE),
      checkboxInput("cervical_symptoms", L[["lbl_cervical"]], value = FALSE),
      checkboxInput("vision_symptoms", L[["lbl_vision"]], value = FALSE)
    ),
    nav_panel(
      value = "prescription",
      title = tagList(icon("file-prescription"), L[["nav_prescription"]]),
      numericInput("hrst", L[["lbl_hrst"]], value = NA, min = 0, step = 1),
      helpText(
        "Measured during Buffalo Concussion Treadmill Test (BCTT). ",
        "No BCTT available? Leave blank - the app will calculate ",
        "a safe starting HR using the age-predicted method ",
        "(Li, 2026). BCTT gives a more precise target."
      ),
      selectInput(
        "sessions_completed",
        "Sessions completed without worsening",
        choices = list(
          "0 (first session or reset)" = 0,
          "1" = 1,
          "2" = 2,
          "3" = 3,
          "4" = 4,
          "5 or more" = 5
        ),
        selected = 0
      ),
      checkboxInput("last_session_worse", L[["lbl_last_session_worse"]], value = FALSE)
    ),
    nav_panel(
      value = "progress",
      title = tagList(icon("chart-line"), L[["nav_progress"]]),
      uiOutput("target_hr_sticky"),
      textInput(
        "chief_complaint",
        "Athlete's main complaint today (optional):",
        value = "",
        placeholder = "e.g. headache better, still foggy"
      ),
      dateInput(
        "session_date",
        label = "Session date:",
        value = Sys.Date(),
        format = "yyyy-mm-dd"
      ),
      tags$details(
        class = "pcss-today-details mb-2",
        open = NA,
        tags$summary(
          class = "pcss-today-summary",
          tags$span("PCSS Today  "),
          tags$span(
            textOutput("current_pcss_total_inline", inline = TRUE),
            class = "text-muted"
          ),
          pcss_score_help_icon()
        ),
        pcss_picker_ui("current_pcss", "")
      ),
      uiOutput("pcss_previous_help"),
      numericInput(
        "current_hr",
        "Heart rate during exercise (bpm)",
        value = NA,
        min = 0,
        step = 1
      ),
      helpText(
        "Average HR from watch or HR monitor. ",
        "e.g. if watch showed 125-132 bpm, enter 128."
      ),
      numericInput(
        "current_duration",
        "How long did they exercise? (min)",
        value = NA,
        min = 0,
        max = 20,
        step = 1
      ),
      helpText("Active exercise time only. Maximum recommended: 20 min."),
      sliderInput(
        "rpe",
        "Perceived exertion (Borg RPE 6-20)",
        min = 6,
        max = 20,
        value = 13,
        step = 1
      ),
      radioButtons(
        "symptom_onset_range",
        "When did symptoms appear?",
        choices = list(
          "No symptoms (full session)" = 20,
          "After 15-19 min" = 17,
          "After 10-14 min" = 12,
          "After 5-9 min" = 7,
          "Within first 5 min" = 3
        ),
        selected = 20
      ),
      helpText(L[["fuse_hint"]]),
      tags$hr(),
      tags$p(
        class = "text-muted small mb-2",
        tags$strong("Local save: "),
        "Session data is saved on this device only. Do not use a shared device. Clear data after export."
      ),
      actionButton(
        "end_session",
        tagList(icon("flag-checkered"), " End session (CSV, then message)"),
        class = "btn-success w-100"
      ),
      tags$p(
        class = "text-muted small mt-2 mb-0",
        "Export CSV to your records system to complete the session."
      )
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
  fillable = FALSE,
  tags$head(
    tags$meta(charset = "UTF-8"),
    tags$meta(name = "robots", content = "noindex, nofollow"),
    tags$meta(
      name = "description",
      content = "PPCSexRx research prototype for athletic trainers. Not for public indexing."
    ),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$script(src = "ppcrx_client.js"),
    tags$style(HTML("
      .workflow-section {
        display: flex;
        align-items: flex-start;
        gap: 0.75rem;
        margin-top: 1.5rem;
        padding-top: 1rem;
        border-top: 1px solid #e9ecef;
      }
      .workflow-section:first-of-type { border-top: none; margin-top: 0; padding-top: 0; }
      .workflow-step {
        flex-shrink: 0;
        width: 1.75rem;
        height: 1.75rem;
        border-radius: 50%;
        background: #0d6efd;
        color: #fff;
        font-size: 0.85rem;
        font-weight: 700;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        margin-top: 0.1rem;
      }
      .workflow-title { margin: 0; font-size: 1.1rem; font-weight: 600; }
      .workflow-subtitle { margin: 0.15rem 0 0; font-size: 0.85rem; }
      .card-clinical {
        border: 1px solid #e9ecef;
        box-shadow: 0 1px 2px rgba(0,0,0,.04);
      }
      .card-clinical > .card-header {
        background: #f8f9fa;
        color: #212529;
        font-weight: 600;
        font-size: 0.95rem;
        border-bottom: 1px solid #e9ecef;
        padding: 0.6rem 1rem;
      }
      .quickstart-bar { font-size: 0.875rem; }
      .quickstart-bar ol { margin-bottom: 0; padding-left: 1.25rem; }
      @media (min-width: 992px) {
        .quickstart-bar ol { display: flex; gap: 1.5rem; list-style: none; padding-left: 0; }
        .quickstart-bar li::before { content: counter(step) '. '; counter-increment: step; font-weight: 600; color: #0d6efd; }
        .quickstart-bar ol { counter-reset: step; }
      }
      .pcss-total-value { font-size: 1.4rem; font-weight: bold; }
      .pcss-picker-more summary { cursor: pointer; }
      .pcss-today-details summary { cursor: pointer; list-style: disclosure-closed; }
      .pcss-today-summary { font-weight: 600; }
      .pcss-symptom-row .shiny-input-radiogroup { margin-bottom: 0; }
      .pcss-symptom-row .shiny-options-group label {
        font-size: 0.72rem;
        margin-right: 0.35rem;
      }
      .pcss-symptom-new {
        background: #f8d7da;
        border-radius: 0.35rem;
        padding: 0.25rem 0.35rem;
        border: 1px solid #f1aeb5;
      }
      .target-hr-sticky {
        position: sticky;
        top: 0;
        z-index: 20;
        background: #cfe2ff;
        border: 1px solid #9ec5fe;
        border-radius: 0.375rem;
        padding: 0.5rem 0.75rem;
        margin-bottom: 0.75rem;
        font-weight: 600;
        font-size: 1rem;
      }
      .shiny-input-container input[type='checkbox'] {
        min-width: 1.25rem;
        min-height: 1.25rem;
      }
      /* Mobile: AT on sideline iPhone (portrait) */
      @media (max-width: 768px) {
        .bslib-page-fill .bslib-sidebar-layout {
          flex-direction: column !important;
        }
        .bslib-page-fill .bslib-sidebar-layout > .sidebar,
        .bslib-page-fill .bslib-sidebar-layout > .main {
          width: 100% !important;
          max-width: 100% !important;
          min-width: 0 !important;
        }
        .bslib-page-fill .bslib-sidebar-layout > .sidebar {
          border-right: none !important;
          border-bottom: 1px solid #dee2e6;
          max-height: none !important;
        }
        .bslib-page-fill .bslib-sidebar-layout > .main {
          padding-left: 0.75rem !important;
          padding-right: 0.75rem !important;
        }
        .workflow-section { flex-wrap: wrap; }
        .pcss-symptom-row .col-sm-6 { width: 100% !important; }
        .pcss-symptom-row .shiny-options-group label {
          display: inline-block;
          margin-bottom: 0.25rem;
        }
        input.form-control, select.form-select, .shiny-input-container {
          font-size: 16px;
        }
        .pcss-symptom-row .shiny-options-group label {
          margin-right: 0.5rem;
          padding: 0.35rem 0.15rem;
        }
        #rpe .irs { margin-top: 0.5rem; margin-bottom: 1.75rem; }
        #rpe .irs-handle {
          width: 28px;
          height: 28px;
          top: 18px;
        }
      }
    ")),
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
  card(
    class = "border-info mb-3",
    fill = FALSE,
    full_screen = FALSE,
    card_body(
      class = "py-3",
      layout_columns(
        col_widths = c(8, 4),
        fill = FALSE,
        tags$div(
          tags$strong(icon("route"), " Workflow"),
          tags$ol(
            class = "small mb-0 mt-1 ps-3",
            tags$li(L[["guide_step1"]]),
            tags$li(L[["guide_step2"]]),
            tags$li(L[["guide_step3"]])
          )
        ),
        tags$div(
          tags$label(class = "form-label small fw-semibold", icon("flask"), " Quick demo (testing)"),
          tags$div(
            class = "d-flex flex-wrap gap-2 align-items-start",
            tags$div(
              class = "flex-grow-1",
              style = "min-width: 12rem;",
              selectInput(
                "demo_dataset",
                label = NULL,
                choices = c(
                  "Select demo..." = "",
                  "Fast recovery" = "dataset1_fast",
                  "Plateau + RPE rise" = "dataset2_plateau",
                  "HR adjusted (S5)" = "dataset3_breakthrough"
                ),
                selected = "",
                width = "100%"
              )
            ),
            tags$div(
              class = "flex-shrink-0 pt-1",
              actionButton(
                "load_demo",
                tagList(icon("database"), " Load demo"),
                class = "btn-info"
              )
            )
          ),
          uiOutput("demo_load_status")
        )
      )
    )
  ),

  navset_card_tab(
    id = "main_clinical_tabs",
    height = "auto",
    nav_panel(
      title = tagList(icon("clipboard-check"), " Screening & Rx"),
      value = "tab_rx",
      layout_columns(
        col_widths = c(5, 7),
        fill = FALSE,
        card(
          class = "card-clinical",
          fill = FALSE,
          full_screen = FALSE,
          card_header(L[["card_screen"]]),
          card_body(uiOutput("screen_display"))
        ),
        card(
          class = "card-clinical",
          fill = FALSE,
          full_screen = FALSE,
          card_header(L[["card_target_hr"]]),
          card_body(uiOutput("target_hr_display"))
        )
      ),
      card(
        class = "card-clinical mt-3",
        fill = FALSE,
        full_screen = FALSE,
        card_header(L[["card_prescription"]]),
        card_body(tableOutput("prescription_table"))
      ),
      card(
        class = "card-clinical mt-3",
        fill = FALSE,
        full_screen = FALSE,
        card_header(L[["fuse_title"]]),
        card_body(
          uiOutput("fuse_status"),
          verbatimTextOutput("fuse_detail", placeholder = TRUE)
        )
      )
    ),
    nav_panel(
      title = tagList(icon("table"), " Session log"),
      value = "tab_log",
      card(
        class = "card-clinical",
        fill = FALSE,
        full_screen = FALSE,
        card_header(L[["card_track"]]),
        card_body(
          tags$p(
            class = "text-muted small",
            "Sidebar ",
            tags$strong("Progress"),
            " tab: enter today's session, then ",
            tags$strong("Run screen / prescribe / track"),
            " to append a row."
          ),
          uiOutput("track_display"),
          hr(),
          tags$h6(class = "text-muted small text-uppercase mb-2", "Session history"),
          div(class = "table-responsive", tableOutput("progress_log_table")),
          tags$small(class = "text-muted d-block mt-2", L[["disclaimer"]])
        )
      )
    ),
    nav_panel(
      title = tagList(icon("chart-line"), " Analytics"),
      value = "tab_analytics",
      uiOutput("analytics_panel")
    ),
    nav_panel(
      title = tagList(icon("paper-plane"), " Messages"),
      value = "tab_messages",
      card(
        class = "card-clinical",
        fill = FALSE,
        full_screen = FALSE,
        card_header("Send to parent / athlete"),
        card_body(uiOutput("send_to_ui"))
      ),
      card(
        class = "card-clinical mt-3",
        fill = FALSE,
        full_screen = FALSE,
        card_header(icon("file-export"), " Export / import"),
        card_body(uiOutput("clinical_exports_ui"))
      )
    )
  )
)

server <- function(input, output, session) {
  has_calculated <- reactiveVal(FALSE)
  copy_note <- reactiveVal("")
  calculating <- reactiveVal(FALSE)

  state <- reactiveValues(
    screen       = NULL,
    rx           = NULL,
    track        = NULL,
    log          = NULL,
    fuse_tripped = FALSE,
    fuse_message = "",
    pcss_baseline = rep(0L, PCSS_SYMPTOM_COUNT),
    last_pcss_scores = rep(0L, PCSS_SYMPTOM_COUNT)
  )

  pcss_new_acknowledged <- reactiveVal(FALSE)

  save_draft <- function() {
    payload <- build_draft_payload(input, state, has_calculated())
    session$sendCustomMessage("ppcrxSaveDraft", payload)
  }

  pcss_delta_blocked <- function() {
    baseline <- state$pcss_baseline
    current <- pcss_read_scores(input, "current_pcss")
    idx <- pcss_new_symptom_indices(baseline, current)
    if (length(idx) == 0L) {
      return(FALSE)
    }
    session$sendCustomMessage("ppcrxHighlightPcss", as.list(idx))
    !isTRUE(input$pcss_new_symptoms_ack)
  }

  perform_calculate <- function() {
    if (pcss_delta_blocked()) {
      showNotification(
        "New symptoms detected. Review with the athlete and check the confirmation box.",
        type = "error",
        duration = 8
      )
      return(invisible(FALSE))
    }

    has_calculated(TRUE)
    state$fuse_tripped <- FALSE
    state$fuse_message <- ""

    state$screen <- PPCSexRx::screen_ppcs(
      age                 = as.integer(input$age),
      days_post_injury    = input$days_post_injury,
      vestibular_symptoms = isTRUE(input$vestibular_symptoms),
      cervical_symptoms   = isTRUE(input$cervical_symptoms),
      vision_symptoms     = isTRUE(input$vision_symptoms)
    )

    if (!identical(state$screen$status, "eligible")) {
      state$rx    <- NULL
      state$track <- NULL
      save_draft()
      return(invisible(FALSE))
    }

    hrst_val <- suppressWarnings(as.numeric(input$hrst))
    if (length(hrst_val) == 0L || is.na(hrst_val)) hrst_val <- NULL

    state$rx <- PPCSexRx::prescribe_ppcs(
      age                 = as.integer(input$age),
      days_post_injury    = input$days_post_injury,
      hrst                = hrst_val,
      vestibular_symptoms = isTRUE(input$vestibular_symptoms),
      cervical_symptoms   = isTRUE(input$cervical_symptoms),
      sessions_completed  = as.integer(input$sessions_completed),
      last_session_worse  = isTRUE(input$last_session_worse)
    )

    state$fuse_tripped <- fuse_tripped_pcss(
      current_pcss_total(),
      previous_pcss()
    )
    if (state$fuse_tripped) {
      delta <- current_pcss_total() - previous_pcss()
      state$fuse_message <- sprintf(
        "PCSS increased by %s (>= 2). Next session prescription locked.",
        format(delta, trim = TRUE)
      )
    }

    if (progress_inputs_valid(input$current_hr, input$current_duration)) {
      pkg_log <- NULL
      if (!is.null(state$log) && is.data.frame(state$log) && nrow(state$log) > 0L) {
        log_for_track <- ensure_log_schema(state$log)
        sess_date <- format_session_date(input$session_date)
        if (nrow(log_for_track) > 0L && tail(log_for_track$date, 1L) == sess_date) {
          log_for_track <- log_for_track[-nrow(log_for_track), , drop = FALSE]
        }
        if (nrow(log_for_track) > 0L) {
          pkg_log <- log_for_track[, LOG_COLS_REQUIRED, drop = FALSE]
        }
      }
      state$track <- PPCSexRx::track_progress(
        log              = pkg_log,
        current_pcss     = current_pcss_total(),
        current_hr       = input$current_hr,
        current_duration = input$current_duration,
        prescription     = state$rx
      )
      onset_min <- resolve_symptom_onset_min(input$symptom_onset_range)
      state$log <- append_v02_fields(
        state$track$updated_log,
        rpe = input$rpe,
        symptom_onset_min = onset_min
      )
      state$log <- apply_session_date_to_last_row(state$log, input$session_date)
    } else {
      state$track <- NULL
    }

    scores <- pcss_read_scores(input, "current_pcss")
    state$last_pcss_scores <- scores
    state$pcss_baseline <- scores
    pcss_new_acknowledged(FALSE)
    save_draft()
    invisible(TRUE)
  }

  show_analytics <- reactive({
    log_df <- state$log
    !is.null(log_df) && is.data.frame(log_df) && nrow(log_df) >= 2L
  })

  bayes_result <- reactive({
    req(show_analytics())
    generate_bayes_recommendation(
      ensure_log_schema(state$log),
      rx_has_bctt(state$rx)
    )
  })

  current_pcss_total <- reactive({
    pcss_compute_total(input, "current_pcss")
  })

  previous_pcss <- reactive({
    log <- state$log
    if (is.null(log) || !is.data.frame(log) || nrow(log) == 0L) {
      return(NA_real_)
    }
    as.numeric(tail(log$pcss, 1))
  })

  pcss_picker_output(
    output,
    input,
    "current_pcss",
    reactive(state$pcss_baseline),
    pcss_new_acknowledged
  )

  output$target_hr_sticky <- renderUI({
    if (!has_calculated() || is.null(state$rx)) {
      return(NULL)
    }
    tags$div(
      class = "target-hr-sticky",
      icon("heart-pulse"),
      " Target HR: ",
      tags$span(as.integer(state$rx$target_hr), class = "text-primary"),
      " bpm"
    )
  })

  output$current_pcss_total_inline <- renderText({
    current_pcss_total()
  })

  pdf_template <- reactive({
    pdf_template_type(state$log)
  })

  pdf_button_label <- reactive({
    if (identical(pdf_template(), "soap")) {
      " Download SOAP Note (Initial)"
    } else {
      n <- if (is.null(state$log) || !is.data.frame(state$log)) {
        1L
      } else {
        nrow(state$log)
      }
      paste0(" Download DAP Progress Note (Session ", n, ")")
    }
  })

  output$pcss_previous_help <- renderUI({
    prev <- previous_pcss()
    if (is.null(state$log) || !is.data.frame(state$log) || nrow(state$log) == 0L ||
        is.na(prev)) {
      helpText(
        "First session: safety fuse comparison activates from session 2 onwards."
      )
    } else {
      helpText(paste0(
        "Last session PCSS: ",
        prev,
        " (auto-loaded from session log)"
      ))
    }
  })

  observeEvent(input$reset, {
    has_calculated(FALSE)
    copy_note("")
    state$screen       <- NULL
    state$rx           <- NULL
    state$track        <- NULL
    state$log          <- NULL
    state$fuse_tripped <- FALSE
    state$fuse_message <- ""
    state$pcss_baseline <- rep(0L, PCSS_SYMPTOM_COUNT)
    state$last_pcss_scores <- rep(0L, PCSS_SYMPTOM_COUNT)
    pcss_new_acknowledged(FALSE)
    session$sendCustomMessage("ppcrxClearDraft", list())
    updateSelectInput(session, "age", selected = 16)
    updateNumericInput(session, "days_post_injury", value = 35)
    updateNumericInput(session, "hrst", value = NA)
    updateSelectInput(session, "sessions_completed", selected = 0)
    pcss_reset_picker(session, "current_pcss")
    updateNumericInput(session, "current_hr", value = NA)
    updateNumericInput(session, "current_duration", value = NA)
    updateSliderInput(session, "rpe", value = 13)
    updateRadioButtons(session, "symptom_onset_range", selected = 20)
    updateCheckboxInput(session, "vestibular_symptoms", value = FALSE)
    updateCheckboxInput(session, "cervical_symptoms", value = FALSE)
    updateCheckboxInput(session, "vision_symptoms", value = FALSE)
    updateCheckboxInput(session, "last_session_worse", value = FALSE)
    updateDateInput(session, "session_date", value = Sys.Date())
    updateTextInput(session, "chief_complaint", value = "")
    updateTextInput(session, "athlete_id", value = "")
    updateTextInput(session, "at_name", value = "")
  })

  observeEvent(input$calc, {
    if (calculating()) {
      return()
    }
    calculating(TRUE)
    on.exit(calculating(FALSE))
    perform_calculate()
  })

  observeEvent(input$current_pcss_same_as_last, {
    scores <- state$last_pcss_scores
    if (all(scores == 0L)) {
      showNotification(
        "No previous PCSS item scores on this device. Enter symptoms or restore a saved session.",
        type = "warning",
        duration = 6
      )
      return()
    }
    pcss_apply_scores(session, "current_pcss", scores)
    pcss_new_acknowledged(FALSE)
  }, ignoreInit = TRUE)

  observeEvent(input$pcss_new_symptoms_ack, {
    pcss_new_acknowledged(isTRUE(input$pcss_new_symptoms_ack))
  }, ignoreInit = TRUE)

  observeEvent(input$ppcrx_restore_draft, {
    draft <- input$ppcrx_restore_draft
    req(is.list(draft))
    restore_draft_to_session(session, draft, state, has_calculated)
    if (isTRUE(draft$hasCalculated)) {
      ensure_screen_and_rx()
      if (isTRUE(draft$fuseTripped)) {
        state$fuse_tripped <- TRUE
      }
    }
    showNotification("Restored session draft from this device.", type = "message", duration = 4)
  }, ignoreInit = TRUE)

  observeEvent(input$end_session, {
    if (calculating()) {
      return()
    }
    calculating(TRUE)
    on.exit(calculating(FALSE))

    if (!has_calculated()) {
      if (!isTRUE(perform_calculate())) {
        return()
      }
    } else if (pcss_delta_blocked()) {
      showNotification(
        "New symptoms detected. Review with the athlete and check the confirmation box.",
        type = "error",
        duration = 8
      )
      return()
    }
    if (!has_calculated() || is.null(state$rx)) {
      showNotification("Complete screening and progress fields before ending session.", type = "error")
      return()
    }
    if (is.null(state$log) || !is.data.frame(state$log) || nrow(state$log) == 0L) {
      showNotification("Enter HR and duration, then Calculate, before ending session.", type = "error")
      return()
    }
    session$sendCustomMessage("ppcrxEndSession", list(delayMs = 700))
  }, ignoreInit = TRUE)

  observeEvent(input$end_session_after_csv, {
    req(state$rx)
    at_name <- if (is.null(input$at_name)) "" else input$at_name
    msg <- generate_parent_message(state$rx, at_name, fuse_tripped = state$fuse_tripped)
    session$sendCustomMessage("copyToClipboard", msg)
    copy_note(
      if (isTRUE(state$fuse_tripped)) {
        "CSV download triggered. Parent safety notice copied."
      } else {
        "CSV download triggered. Parent message copied."
      }
    )
    showNotification(
      "Session exported to CSV. Optional: download SOAP/DAP PDF from Export tab.",
      type = "message",
      duration = 8
    )
  }, ignoreInit = TRUE)

  ensure_screen_and_rx <- function() {
    state$screen <- PPCSexRx::screen_ppcs(
      age                 = as.integer(input$age),
      days_post_injury    = input$days_post_injury,
      vestibular_symptoms = isTRUE(input$vestibular_symptoms),
      cervical_symptoms   = isTRUE(input$cervical_symptoms),
      vision_symptoms     = isTRUE(input$vision_symptoms)
    )
    if (!identical(state$screen$status, "eligible")) {
      state$rx <- NULL
      return(invisible(FALSE))
    }
    hrst_val <- suppressWarnings(as.numeric(input$hrst))
    if (length(hrst_val) == 0L || is.na(hrst_val)) hrst_val <- NULL
    state$rx <- PPCSexRx::prescribe_ppcs(
      age                 = as.integer(input$age),
      days_post_injury    = input$days_post_injury,
      hrst                = hrst_val,
      vestibular_symptoms = isTRUE(input$vestibular_symptoms),
      cervical_symptoms   = isTRUE(input$cervical_symptoms),
      sessions_completed  = as.integer(input$sessions_completed),
      last_session_worse  = isTRUE(input$last_session_worse)
    )
    invisible(TRUE)
  }

  output$clinical_exports_ui <- renderUI({
    if (!has_calculated() || is.null(state$rx)) {
      return(tags$p(
        class = "text-muted small mb-0",
        "PDF/CSV export and CSV upload appear after ",
        tags$strong("Run screen / prescribe / track"),
        " (or load demo above — screening fills automatically)."
      ))
    }
    cols_help <- paste(LOG_COLS, collapse = ", ")
    tagList(
      div(
        class = "d-grid gap-2 mb-3",
        downloadButton(
          "download_pdf",
          tagList(icon("file-pdf"), pdf_button_label()),
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

  output$demo_load_status <- renderUI({
    log_df <- state$log
    if (is.null(log_df) || !is.data.frame(log_df) || nrow(log_df) == 0L) {
      return(NULL)
    }
    tags$p(
      class = "text-success small mb-0",
      icon("circle-check"),
        sprintf(
        " Demo log active: %d session(s). Open the Analytics tab.",
        nrow(log_df)
      )
    )
  })

  output$send_to_ui <- renderUI({
    if (!has_calculated()) {
      return(tags$p(class = "text-muted", L[["placeholder"]]))
    }
    screen <- state$screen
    if (!is.null(screen) && identical(screen$status, "needs_referral")) {
      return(tagList(
        tags$p(class = "text-muted small", "Clinician name: set in Profile tab."),
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
      tags$p(class = "text-muted small mb-2", "Clinician name: set in Profile tab."),
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
      tmpl <- pdf_template()
      date_str <- format_session_date(input$session_date)
      sn <- if (is.null(state$log) || !is.data.frame(state$log)) {
        1L
      } else {
        nrow(state$log)
      }
      pdf_download_filename(
        tmpl,
        input$athlete_id,
        date_str,
        session_n = sn
      )
    },
    content = function(file) {
      req(state$rx)
      tmpl <- pdf_template()
      ctx <- build_clinical_note_context(input, state, tmpl)
      tmp <- render_clinical_note_pdf(tmpl, ctx)
      file.copy(tmp, file, overwrite = TRUE)
      unlink(tmp)
    }
  )

  output$download_csv <- downloadHandler(
    filename = function() {
      csv_session_filename(input$athlete_id, input$session_date)
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

  demo_data_path <- function() {
    path <- file.path(getwd(), "www", "demo_data.json")
    if (!file.exists(path)) {
      stop("Demo data file not found: ", path, call. = FALSE)
    }
    path
  }

  observeEvent(input$load_demo, {
    req(nzchar(input$demo_dataset))

    demo_json <- tryCatch(
      jsonlite::fromJSON(demo_data_path(), simplifyDataFrame = TRUE),
      error = function(e) {
        showNotification(paste("Demo load error:", e$message), type = "error")
        NULL
      }
    )
    if (is.null(demo_json)) return()

    selected <- demo_json[[input$demo_dataset]]$data
    if (is.null(selected) || nrow(selected) == 0L) {
      showNotification("Demo dataset is empty.", type = "error")
      return()
    }

    df <- as.data.frame(selected, stringsAsFactors = FALSE)
    df$symptoms_worsened <- as.logical(df$symptoms_worsened)
    state$log <- ensure_log_schema(df)

    has_calculated(TRUE)
    ensure_screen_and_rx()
    bslib::nav_select("main_clinical_tabs", "tab_analytics")

    label <- demo_json[[input$demo_dataset]]$label
    showNotification(
      paste0(
        "Demo loaded: ", nrow(state$log), " sessions (", label, "). ",
        "Open the Analytics tab to view charts."
      ),
      type = "message",
      duration = 5
    )
  }, ignoreInit = TRUE)

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
    draft_age <- NULL
    if (!is.null(input$ppcrx_restore_draft) && is.list(input$ppcrx_restore_draft)) {
      prof <- input$ppcrx_restore_draft$profile
      if (is.list(prof) && !is.null(prof$age) && !is.na(prof$age)) {
        draft_age <- as.integer(prof$age)
      }
    }
    if (!is.null(draft_age)) {
      updateSelectInput(session, "age", selected = as.character(draft_age))
    }
    showNotification(
      paste0(
        "Loaded ", nrow(df), " session(s) from CSV. ",
        "Confirm age and days post-injury in Profile; sessions append on Calculate."
      ),
      type = "message",
      duration = 6
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
      return(
        card(
          class = "card-clinical",
          fill = FALSE,
          card_body(
            class = "py-4",
            tags$p(
              class = "text-muted mb-0",
              icon("chart-area"),
              " Use ",
              tags$strong("Load demo"),
              " at the top of the page, or enter sessions in the Progress sidebar tab and click ",
              tags$strong("Run screen / prescribe / track"),
              "."
            )
          )
        )
      )
    }
    log_df <- state$log
    n_sess <- nrow(log_df)
    layout_columns(
      col_widths = c(8, 4),
      fill = FALSE,
      card(
        class = "card-clinical",
        fill = FALSE,
        full_screen = FALSE,
        card_header(icon("chart-line"), "Recovery trends"),
        card_body(
          plotly::plotlyOutput("pcss_trend_plot", height = "340px"),
          hr(),
          plotly::plotlyOutput("onset_trend_plot", height = "300px")
        )
      ),
      card(
        class = "card-clinical",
        fill = FALSE,
        full_screen = FALSE,
        card_header(icon("lightbulb"), "Prescription guidance"),
        card_body(
          uiOutput("bayes_recommendation"),
          uiOutput("bayes_method_details")
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
    rec <- bayes_result()
    alert_class <- switch(
      rec$level,
      info    = "alert-info",
      warning = "alert-warning",
      success = "alert-success",
      "alert-secondary"
    )
    tags$div(class = paste("alert", alert_class), rec$text)
  })

  output$bayes_method_details <- renderUI({
    req(show_analytics())
    rec <- bayes_result()
    if (is.null(rec$method_text) || !nzchar(rec$method_text)) {
      return(
        tags$details(
          class = "mt-3",
          tags$summary(class = "small", "View evidence basis"),
          tags$p(
            class = "small text-muted mb-0",
            "Statistical method details appear after 3 or more sessions with valid dates."
          )
        )
      )
    }
    tags$details(
      class = "mt-3",
      tags$summary(class = "small", "View evidence basis"),
      tags$pre(
        class = "small bg-light border rounded p-2 mb-2",
        style = "white-space: pre-wrap; font-size: 0.8rem; max-height: 320px; overflow-y: auto;",
        rec$method_text
      ),
      tags$p(
        class = "text-muted small mb-0",
        "If exercise intensity was adjusted mid-program, interpret with clinical context."
      )
    )
  })

  empty_hint <- function(text) {
    tags$div(
      class = "text-muted py-3",
      icon("circle-info"),
      " ",
      text
    )
  }

  output$screen_display <- renderUI({
    screen <- state$screen
    if (is.null(screen)) {
      return(empty_hint("Click Run screen / prescribe / track, or Load demo above."))
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
      return(empty_hint("Target HR appears after screening."))
    }
    age_pred <- grepl("age-predicted", rx$method, ignore.case = TRUE)
    tags$div(
      class = "display-4 text-primary",
      sprintf("%d %s", as.integer(rx$target_hr), L[["unit_bpm"]]),
      if (age_pred) {
        tags$p(
          class = "small text-muted mt-3 mb-0",
          "When BCTT is unavailable, the app uses age-predicted HRmax x 65% (package default). ",
          "Li (2026) CAT recommends starting at 50% HRmax; ",
          "this discrepancy will be resolved in PPCSexRx v0.2.0."
        )
      }
    )
  })

  output$prescription_table <- renderTable({
    if (is.null(state$rx)) {
      return(data.frame(
        Field = "Waiting for prescription",
        Value = "Run screen / prescribe / track",
        stringsAsFactors = FALSE
      ))
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
      return(empty_hint("PCSS fuse activates when you log sessions in Progress."))
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
        return(empty_hint("Latest session summary appears after Calculate with Progress data."))
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
        check.names = FALSE
      ))
    }
    ensure_log_schema(log_df)
  }, bordered = TRUE)
}

shinyApp(ui = ui, server = server)
