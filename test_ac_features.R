#!/usr/bin/env Rscript
options(encoding = "UTF-8")
source("/home/ubuntu/ppc_rx_app/R/pdf_log.R")
library(PPCSexRx)

cat("=== Scenario 6 (Simple, no Current HR) ===\n")
screen <- screen_ppcs(15, 30, FALSE, FALSE, FALSE)
hrst_val <- NULL
rx <- prescribe_ppcs(15, 30, hrst_val, FALSE, FALSE, 0L, FALSE)
fuse <- (9 - 10) >= 2
run_track <- progress_inputs_valid(NA, NA)
track <- if (run_track) NULL else NULL
session_ready <- !is.null(rx) && screen$status == "eligible" && !fuse
cat("Screen:", screen$status, "\n")
cat("Target HR:", rx$target_hr, "bpm\n")
cat("track_progress called:", run_track, "\n")
cat("Simple status:", if (session_ready) "Ready" else "Not today", "\n")
cat("PASS:", session_ready && rx$target_hr == 133L, "\n\n")

cat("=== Scenario 1 PDF ===\n")
rx1 <- prescribe_ppcs(16, 35, 160, FALSE, FALSE, 0L, FALSE)
pdf_out <- "/home/ubuntu/ppc_rx_app/samples/PPCSexRx_prescription_scenario1.pdf"
dir.create(dirname(pdf_out), showWarnings = FALSE)
tmp <- render_prescription_pdf(rx1)
file.copy(tmp, pdf_out, overwrite = TRUE)
unlink(tmp)
cat("PDF written:", pdf_out, "size", file.size(pdf_out), "\n\n")

cat("=== CSV round-trip (2 sessions -> upload -> session 3) ===\n")
rx <- rx1
t1 <- track_progress(NULL, 23, 128, 20, rx)
t2 <- track_progress(t1$updated_log, 22, 128, 20, rx)
log2 <- t2$updated_log
csv_path <- tempfile(fileext = ".csv")
write.csv(log2, csv_path, row.names = FALSE)
cat("After 2 sessions:\n")
print(log2)
uploaded <- normalize_session_log(read.csv(csv_path, stringsAsFactors = FALSE))
t3 <- track_progress(uploaded, 21, 127, 20, rx)
cat("\nAfter session 3 (uploaded log + calc):\n")
print(t3$updated_log)
cat("Rows:", nrow(t3$updated_log), " expected 3\n")
