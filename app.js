(function () {
  var header = document.querySelector(".site-head");
  var toggle = document.querySelector(".nav-toggle");
  var nav = document.querySelector(".site-nav");

  function setNavOpen(open) {
    if (!toggle || !nav) return;
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
    nav.classList.toggle("is-open", open);
    document.body.classList.toggle("nav-open", open);
  }

  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var open = toggle.getAttribute("aria-expanded") === "true";
      setNavOpen(!open);
    });

    nav.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        setNavOpen(false);
      });
    });
  }

  function updateScrollUi() {
    if (header) header.classList.toggle("is-scrolled", window.scrollY > 12);
    var fab = document.querySelector(".scroll-top-fab");
    if (fab) {
      var show = window.scrollY > 280;
      fab.classList.toggle("scroll-top-fab--visible", show);
      fab.setAttribute("aria-hidden", show ? "false" : "true");
      fab.tabIndex = show ? 0 : -1;
    }
  }

  window.addEventListener("scroll", updateScrollUi, { passive: true });
  updateScrollUi();

  var y = document.getElementById("y");
  if (y) y.textContent = String(new Date().getFullYear());

  function scrollToTop() {
    var reduce =
      window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" });
    var topEl = document.getElementById("top");
    if (topEl) {
      try {
        topEl.focus({ preventScroll: true });
      } catch (err) {
        /* ignore */
      }
    }
  }

  function stripHashFromHistory() {
    if (window.history && window.history.replaceState) {
      var path = window.location.pathname + window.location.search;
      window.history.replaceState(null, "", path);
    }
  }

  document.querySelectorAll(".footer-up").forEach(function (footerUp) {
    footerUp.addEventListener("click", function (e) {
      e.preventDefault();
      scrollToTop();
      stripHashFromHistory();
    });
  });

  var scrollTopFab = document.querySelector(".scroll-top-fab");
  if (scrollTopFab) {
    scrollTopFab.addEventListener("click", function () {
      scrollToTop();
      stripHashFromHistory();
    });
  }

  var LEAD_EMAIL = "ba360063@mail.ru";

  var form = document.getElementById("lead-form");
  var status = document.getElementById("form-status");
  if (form && status) {
    try {
      var params = new URLSearchParams(window.location.search);
      if (params.get("sent") === "1") {
        status.textContent =
          "Спасибо! Заявка отправлена на почту " +
          LEAD_EMAIL +
          ". Мы свяжемся с вами по указанным контактам.";
        params.delete("sent");
        var qs = params.toString();
        var clean =
          window.location.pathname + (qs ? "?" + qs : "") + (window.location.hash || "#lead");
        window.history.replaceState(null, "", clean);
      }
    } catch (err) {
      /* ignore */
    }

    form.addEventListener("submit", function (e) {
      if (status) status.textContent = "";

      var honey = form.querySelector('input[name="_honey"]');
      if (honey && honey.value) {
        e.preventDefault();
        return;
      }

      if (!form.querySelector('input[name="consent"]').checked) {
        e.preventDefault();
        status.textContent = "Нужно согласие на обработку персональных данных.";
        return;
      }

      var contactInput = form.querySelector('input[name="contact"]');
      var contact = contactInput ? String(contactInput.value || "").trim() : "";
      var replytoEl = document.getElementById("lead-form-replyto");
      var nextEl = document.getElementById("lead-form-next");
      if (replytoEl) {
        replytoEl.value = contact.indexOf("@") !== -1 ? contact : "";
      }
      if (nextEl && typeof window !== "undefined" && window.location) {
        try {
          var nextUrl = new URL(window.location.href);
          nextUrl.searchParams.set("sent", "1");
          nextUrl.hash = "lead";
          nextEl.value = nextUrl.toString();
        } catch (err2) {
          nextEl.value = "";
        }
      }

      var submitBtn = form.querySelector('button[type="submit"]');
      if (submitBtn) {
        submitBtn.disabled = true;
      }
    });
  }

  document.querySelectorAll(".faq-item").forEach(function (det) {
    det.addEventListener("toggle", function () {
      if (!det.open) return;
      document.querySelectorAll(".faq-item").forEach(function (other) {
        if (other !== det) other.open = false;
      });
    });
  });
})();
