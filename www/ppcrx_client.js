(function () {
  "use strict";

  var STORAGE_KEY = "ppcrx_draft_v1";
  var MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

  function getDraft() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      return JSON.parse(raw);
    } catch (e) {
      return null;
    }
  }

  function saveDraft(payload) {
    payload.savedAt = new Date().toISOString();
    localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
  }

  function clearDraft() {
    localStorage.removeItem(STORAGE_KEY);
  }

  function draftAgeDays(draft) {
    if (!draft || !draft.savedAt) return 0;
    return (Date.now() - new Date(draft.savedAt).getTime()) / 86400000;
  }

  function highlightNewSymptoms(indices) {
    document.querySelectorAll(".pcss-symptom-row").forEach(function (row) {
      row.classList.remove("pcss-symptom-new");
    });
    if (!indices || !indices.length) return;
    indices.forEach(function (i) {
      var row = document.querySelector('.pcss-symptom-row[data-pcss-index="' + i + '"]');
      if (row) row.classList.add("pcss-symptom-new");
    });
  }

  Shiny.addCustomMessageHandler("ppcrxSaveDraft", function (message) {
    saveDraft(message);
  });

  Shiny.addCustomMessageHandler("ppcrxClearDraft", function () {
    clearDraft();
  });

  Shiny.addCustomMessageHandler("ppcrxHighlightPcss", function (indices) {
    highlightNewSymptoms(indices);
  });

  Shiny.addCustomMessageHandler("ppcrxEndSession", function (msg) {
    var link = document.getElementById("download_csv");
    if (link) link.click();
    setTimeout(function () {
      Shiny.setInputValue("end_session_after_csv", Date.now(), { priority: "event" });
    }, msg && msg.delayMs ? msg.delayMs : 700);
  });

  $(document).on("shiny:connected", function () {
    var draft = getDraft();
    if (!draft) return;
    var days = draftAgeDays(draft);
    if (days > 7) {
      clearDraft();
      return;
    }
    var restore = true;
    if (days >= 1) {
      restore = window.confirm(
        "You have unsaved session data from " +
          Math.floor(days) +
          " day(s) ago. Restore it?"
      );
    }
    if (restore) {
      Shiny.setInputValue("ppcrx_restore_draft", draft, { priority: "event" });
    }
  });
})();
