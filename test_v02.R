#!/usr/bin/env Rscript
options(encoding = "UTF-8")
local({
  ulib <- Sys.getenv("R_LIBS_USER", file.path(Sys.getenv("HOME"), "R", "library"))
  if (dir.exists(ulib)) .libPaths(c(ulib, .libPaths()))
})

source("/home/ubuntu/ppc_rx_app/R/pdf_log.R")
source("/home/ubuntu/ppc_rx_app/R/bayes.R")
source("/home/ubuntu/ppc_rx_app/R/messages.R")
source("/home/ubuntu/ppc_rx_app/R/plots.R")
library(PPCSexRx)

ok <- TRUE
fail <- function(...) {
  ok <<- FALSE
  cat("FAIL:", ..., "\n")
}

cat("=== v0.1 CSV backward compatibility ===\n")
old <- read.csv("/home/ubuntu/ppc_rx_app/samples/session_log_2sessions.csv", stringsAsFactors = FALSE)
norm <- normalize_session_log(old)
if (!all(LOG_COLS %in% names(norm))) fail("missing cols after normalize")
if (!all(is.na(norm$rpe))) fail("rpe should be NA for old csv")
cat("PASS: old CSV loads with", ncol(norm), "columns\n\n")

cat("=== Scenario 1 (AT clinical path) ===\n")
screen <- screen_ppcs(16, 35, FALSE, FALSE, FALSE)
rx <- prescribe_ppcs(16, 35, 160, FALSE, FALSE, 0L, FALSE)
if (screen$status != "eligible" || rx$target_hr != 128L) fail("scenario 1 rx")
cat("PASS: eligible, HR", rx$target_hr, "\n\n")

cat("=== Messages plain text ===\n")
pm <- generate_parent_message(rx, "Coach Li")
am <- generate_athlete_message(rx, "Coach Li")
if (grepl("[^\x01-\x7F]", pm) && !grepl("Li", pm)) fail("unexpected encoding")
if (grepl("\u2022|\u2014|\u2605", pm)) fail("unicode bullets in parent msg")
cat("PASS: parent", nchar(pm), "chars, athlete", nchar(am), "chars\n\n")

cat("=== Analytics 5-row CSV ===\n")
log5 <- data.frame(
  date = rep("2026-06-01", 5),
  pcss = c(28L, 26L, 24L, 22L, 20L),
  target_hr = rep(128L, 5),
  achieved_hr = rep(128L, 5),
  duration_min = rep(20L, 5),
  symptoms_worsened = rep(FALSE, 5),
  rpe = c(11, 12, 13, 14, 15),
  symptom_onset_min = c(15, 16, 18, 19, 20),
  post_symptom_severity = c(1L, 1L, 0L, 0L, 0L),
  stringsAsFactors = FALSE
)
log5 <- ensure_log_schema(log5)
p1 <- plot_pcss_trend(log5)
p2 <- plot_onset_trend(log5)
rec <- generate_bayes_recommendation(log5, TRUE)
if (is.null(p1)) fail("pcss plot null")
if (is.null(p2)) fail("onset plot null")
if (is.null(rec$text)) fail("bayes rec null")
write.csv(log5, "/home/ubuntu/ppc_rx_app/samples/test_log_v02_5sessions.csv", row.names = FALSE)
cat("PASS: plots + bayes, CSV written\n\n")

cat("=== App loads ===\n")
tryCatch({
  env <- new.env()
  sys.source("/home/ubuntu/ppc_rx_app/app.R", envir = env, chdir = TRUE)
  if (!exists("shinyApp", envir = env)) fail("no shinyApp")
  cat("PASS: app.R sources without error\n")
}, error = function(e) {
  fail(conditionMessage(e))
})

if (ok) {
  cat("\nAll v0.2 tests passed.\n")
} else {
  quit(status = 1)
}
