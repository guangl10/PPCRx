# Plain-text clipboard messages (ASCII-safe for SMS/email)

plain_ascii <- function(x) {
  if (is.null(x) || length(x) == 0L || is.na(x)) {
    return("")
  }
  x <- as.character(x)
  x <- iconv(x, from = "UTF-8", to = "ASCII", sub = "")
  gsub("[[:space:]]+", " ", trimws(x))
}

generate_referral_message <- function(screen, at_name) {
  name_line <- if (nchar(at_name) > 0) {
    paste0("From: ", at_name, "\n\n")
  } else {
    ""
  }
  reason <- plain_ascii(screen$reason)
  referral <- plain_ascii(screen$referral)
  if (!nzchar(referral) && !is.null(screen$next_step)) {
    referral <- plain_ascii(screen$next_step)
  }
  paste0(
    "[Referral Notice]\n",
    name_line,
    "Your child requires evaluation before starting\n",
    "the exercise program.\n\n",
    "Reason: ", reason, "\n\n",
    "Recommended next step:\n",
    referral, "\n\n",
    "Contact me with any questions.\n",
    "Note: Assessed by a certified athletic trainer.\n",
    "Does not replace medical advice."
  )
}

generate_parent_fuse_message <- function(at_name) {
  name_line <- if (nchar(at_name) > 0) {
    paste0("From: ", at_name, "\n\n")
  } else {
    ""
  }
  paste0(
    "[Safety Notice]\n",
    name_line,
    "Today's session has been stopped early.\n",
    "Reason: Symptom threshold exceeded.\n\n",
    "Your child should rest today.\n",
    "No exercise until symptoms return to baseline.\n\n",
    "Contact me with any questions.\n",
    "Note: Prescribed by a certified athletic trainer."
  )
}

generate_athlete_fuse_message <- function(at_name) {
  name_line <- if (nchar(at_name) > 0) {
    paste0("From: ", at_name, "\n\n")
  } else {
    ""
  }
  paste0(
    "[Safety Notice]\n",
    name_line,
    "Today's session is stopped early.\n",
    "Reason: Symptom threshold exceeded.\n\n",
    "Rest today.\n",
    "No exercise until symptoms return to baseline.\n\n",
    "Let me know how you feel.\n",
    "Note: Prescribed by a certified athletic trainer."
  )
}

generate_parent_message <- function(rx, at_name, fuse_tripped = FALSE) {
  if (isTRUE(fuse_tripped)) {
    return(generate_parent_fuse_message(at_name))
  }
  name_line <- if (nchar(at_name) > 0) {
    paste0("From: ", at_name, "\n\n")
  } else {
    ""
  }
  paste0(
    "[Exercise Prescription]\n",
    name_line,
    "Today's plan:\n",
    "- Target heart rate: below ", rx$target_hr, " bpm\n",
    "- Duration: ", rx$duration_min, " minutes\n",
    "- Mode: brisk walk or stationary bike\n\n",
    "Stop immediately if:\n",
    "- Headache gets worse\n",
    "- Dizziness\n",
    "- Feeling worse than at the start\n\n",
    "After exercise, please let me know:\n",
    "- How did it go?\n",
    "- Any symptoms?\n\n",
    "Contact me with any questions.\n\n",
    "Note: Prescribed by a certified athletic trainer. ",
    "Does not replace medical advice."
  )
}

generate_athlete_message <- function(rx, at_name, fuse_tripped = FALSE) {
  if (isTRUE(fuse_tripped)) {
    return(generate_athlete_fuse_message(at_name))
  }
  name_line <- if (nchar(at_name) > 0) {
    paste0("From: ", at_name, "\n\n")
  } else {
    ""
  }
  paste0(
    "[Today's Training Target]\n",
    name_line,
    "Keep heart rate below ", rx$target_hr, " bpm\n",
    "Duration: ", rx$duration_min, " minutes\n\n",
    "Stop if symptoms get worse. That is okay.\n",
    "Let me know how it goes.\n\n",
    "You got this."
  )
}
