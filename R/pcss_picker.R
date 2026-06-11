# PCSS symptom picker (22 items, 0-6 each; exports total only)

PCSS_SYMPTOM_COUNT <- 22L
PCSS_COMMON_COUNT <- 6L

PCSS_SYMPTOMS <- c(
  "Headache",
  "Dizziness",
  "Nausea",
  "Fatigue",
  "Brain fog",
  "Sensitivity to light",
  "Difficulty concentrating",
  "Feeling slowed down",
  "Drowsiness",
  "Sensitivity to noise",
  "Blurred vision",
  "Difficulty remembering",
  "Irritability",
  "Sadness",
  "Nervousness or anxious",
  "Numbness or tingling",
  "Feeling like in slow motion",
  "Sleep more than usual",
  "Sleep less than usual",
  "Trouble falling asleep",
  "Balance problems",
  "Visual problems"
)

stopifnot(length(PCSS_SYMPTOMS) == PCSS_SYMPTOM_COUNT)

PCSS_SCORE_CHOICES <- setNames(
  0:6,
  c(
    "0 None",
    "1 Mild",
    "2 Mild",
    "3 Mod",
    "4 Mod",
    "5 Severe",
    "6 Severe"
  )
)

PCSS_SCORE_TOOLTIP <- paste0(
  "PCSS scoring (SCAT6 / ImPACT standard):\n",
  "0 = None\n",
  "1-2 = Mild\n",
  "3-4 = Moderate\n",
  "5-6 = Severe\n\n",
  "Rate how much this symptom has bothered\n",
  "you over the past 24 hours.\n",
  "Source: PCSS via SCAT6"
)

pcss_score_help_icon <- function() {
  tags$span(
    class = "pcss-score-help ms-1",
    title = PCSS_SCORE_TOOLTIP,
    `aria-label` = "PCSS scoring guide",
    icon("circle-info"),
    style = "cursor: help; color: #6c757d;"
  )
}

pcss_check_id <- function(input_id, i) {
  paste0(input_id, "_check_", i)
}

pcss_score_id <- function(input_id, i) {
  paste0(input_id, "_score_", i)
}

pcss_symptom_row <- function(input_id, i, symptom_name) {
  check_id <- pcss_check_id(input_id, i)
  score_id <- pcss_score_id(input_id, i)
  fluidRow(
    class = "pcss-symptom-row mb-2 align-items-center",
    column(
      width = 1,
      checkboxInput(check_id, label = NULL, value = FALSE)
    ),
    column(
      width = 5,
      tags$span(symptom_name, class = "pcss-symptom-name", style = "line-height: 2.2;")
    ),
    column(
      width = 6,
      conditionalPanel(
        condition = paste0("input.", check_id, " == true"),
        radioButtons(
          score_id,
          label = NULL,
          choices = PCSS_SCORE_CHOICES,
          selected = 1,
          inline = TRUE
        )
      )
    )
  )
}

pcss_picker_ui <- function(input_id, label) {
  common_rows <- lapply(seq_len(PCSS_COMMON_COUNT), function(i) {
    pcss_symptom_row(input_id, i, PCSS_SYMPTOMS[i])
  })

  more_rows <- lapply(seq.int(PCSS_COMMON_COUNT + 1L, PCSS_SYMPTOM_COUNT), function(i) {
    pcss_symptom_row(input_id, i, PCSS_SYMPTOMS[i])
  })

  label_tag <- if (!is.null(label) && nzchar(label)) {
    tags$label(class = "form-label fw-semibold", label)
  } else {
    NULL
  }

  tagList(
    label_tag,
    tags$div(class = "pcss-picker-common", common_rows),
    tags$details(
      class = "pcss-picker-more mt-2 mb-2",
      tags$summary(class = "text-muted small", "More symptoms"),
      tags$div(class = "mt-2", more_rows)
    ),
    tags$div(
      class = "pcss-total border-top pt-2 mt-2",
      tags$span("PCSS Total: "),
      tags$span(
        textOutput(paste0(input_id, "_total_display"), inline = TRUE),
        class = "pcss-total-value text-primary"
      ),
      pcss_score_help_icon(),
      tags$span(class = "text-muted small", " (0-132)")
    )
  )
}

pcss_compute_total <- function(input, input_id) {
  total <- 0L
  for (i in seq_len(PCSS_SYMPTOM_COUNT)) {
    check_id <- pcss_check_id(input_id, i)
    score_id <- pcss_score_id(input_id, i)
    if (isTRUE(input[[check_id]])) {
      score <- suppressWarnings(as.integer(input[[score_id]]))
      if (length(score) > 0L && !is.na(score)) {
        total <- total + score
      }
    }
  }
  total
}

pcss_reset_picker <- function(session, input_id) {
  for (i in seq_len(PCSS_SYMPTOM_COUNT)) {
    updateCheckboxInput(session, pcss_check_id(input_id, i), value = FALSE)
    updateRadioButtons(session, pcss_score_id(input_id, i), selected = "1")
  }
}

pcss_picker_output <- function(output, input, input_id) {
  output[[paste0(input_id, "_total_display")]] <- renderText({
    pcss_compute_total(input, input_id)
  })
}
