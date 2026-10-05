/* app.js - small behaviours for the UI kit.   REQ-IDs: none - starter app
   No inline scripts anywhere (the Content-Security-Policy forbids them). */
(function () {
  "use strict";

  /** Close a toast now.
   *  Calls: none */
  function dismiss(toast) {
    if (toast && toast.parentNode) toast.parentNode.removeChild(toast);
  }

  /** Auto-close a toast after a while, but never while the pointer or keyboard focus is on it.
   *  Calls: dismiss:app.js:src/app/static/js */
  function arm(toast) {
    var ms = toast.classList.contains("toast-error") ? 10000 : 6000;
    var timer = setTimeout(function () { dismiss(toast); }, ms);
    toast.addEventListener("mouseenter", function () { clearTimeout(timer); });
    toast.addEventListener("focusin", function () { clearTimeout(timer); });
  }

  /** Arm every toast that has not been armed yet.
   *  Calls: arm:app.js:src/app/static/js */
  function armAll() {
    document.querySelectorAll(".toast:not([data-armed])").forEach(function (t) {
      t.setAttribute("data-armed", "1");
      arm(t);
    });
  }

  document.addEventListener("click", function (e) {
    var close = e.target.closest(".toast-close");
    if (close) dismiss(close.closest(".toast"));
  });

  document.addEventListener("htmx:afterSwap", armAll);
  document.addEventListener("htmx:afterSettle", function (e) {
    // After a form comes back with errors (422), move the keyboard focus to the first field to fix.
    if (!e.detail.xhr || e.detail.xhr.status !== 422) return;
    var bad = document.querySelector("[aria-invalid='true']");
    if (bad) bad.focus();
  });
  document.addEventListener("htmx:oobAfterSwap", armAll);

  document.addEventListener("htmx:afterRequest", function (e) {
    // The Undo button lives in a toast: remove that toast once the undo is done.
    var t = e.detail.elt.closest && e.detail.elt.closest(".toast");
    if (t && e.detail.successful) dismiss(t);
  });

  document.addEventListener("DOMContentLoaded", armAll);
})();
