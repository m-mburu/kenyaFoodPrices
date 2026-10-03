(function () {
  if (window.kfpInteractions && window.kfpInteractions.initialised) {
    return;
  }

  const state = {
    initialised: false,
    resizeObserver: null,
    resizeScheduled: false
  };

  function scheduleDataTableAdjust() {
    if (state.resizeScheduled) {
      return;
    }

    state.resizeScheduled = true;
    window.requestAnimationFrame(function () {
      state.resizeScheduled = false;

      if (!window.jQuery || !jQuery.fn || !jQuery.fn.dataTable) {
        return;
      }

      const tables = jQuery.fn.dataTable.tables({ visible: true, api: true });
      if (tables && typeof tables.columns === "function") {
        tables.columns.adjust();
      }
    });
  }

  function restoreDetailsState(node, defaultOpen) {
    if (!node || !node.id || !node.dataset.kfpRemember) {
      return;
    }

    const key = "kfp-details:" + node.id;
    const stored = window.sessionStorage.getItem(key);
    if (stored === "open") {
      node.open = true;
      return;
    }
    if (stored === "closed") {
      node.open = false;
      return;
    }

    if (typeof defaultOpen === "boolean") {
      node.open = defaultOpen;
    }
  }

  function rememberDetailsState(node) {
    if (!node || !node.id || !node.dataset.kfpRemember) {
      return;
    }

    const key = "kfp-details:" + node.id;
    window.sessionStorage.setItem(key, node.open ? "open" : "closed");
  }

  function initDetailsState() {
    const phone = window.matchMedia("(max-width: 768px)");
    document.querySelectorAll("details[data-kfp-remember]").forEach(function (
      node
    ) {
      // Roles work with any module namespace; storage remains per instance ID.
      const defaultOpen = node.dataset.kfpFilterRole === "main"
        ? !phone.matches
        : undefined;
      restoreDetailsState(node, defaultOpen);
    });
  }

  function bindResizeObserver() {
    if (!("ResizeObserver" in window)) {
      return;
    }

    if (state.resizeObserver) {
      state.resizeObserver.disconnect();
    }

    state.resizeObserver = new ResizeObserver(scheduleDataTableAdjust);
    ["main-content", ".tab-content"].forEach(function (selector) {
      const node = selector.startsWith("#")
        ? document.getElementById(selector.slice(1))
        : document.querySelector(selector);
      if (node) {
        state.resizeObserver.observe(node);
      }
    });
  }

  function bindDocumentEvents() {
    document.addEventListener("toggle", function (event) {
      if (!(event.target instanceof HTMLDetailsElement)) {
        return;
      }

      rememberDetailsState(event.target);
      if (event.target.open && event.target.dataset.kfpAdjust === "datatable") {
        scheduleDataTableAdjust();
      }
    }, true);

    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape" || !window.Shiny) {
        return;
      }

      const panel = document.getElementById("trend_selection_panel");
      const active = document.activeElement;
      if (!panel || panel.offsetParent === null) {
        return;
      }
      if (active instanceof Element && !active.closest(".kfp-trends")) {
        return;
      }

      Shiny.setInputValue("trend_selection_escape", Date.now(), {
        priority: "event"
      });
    });

    window.addEventListener("resize", scheduleDataTableAdjust, {
      passive: true
    });

    if (window.jQuery) {
      jQuery(document).on("shown.bs.tab", scheduleDataTableAdjust);
    }

    document.addEventListener("shiny:recalculated", scheduleDataTableAdjust);
  }

  function registerMessageHandlers() {
    if (!window.Shiny || window.kfpFocusHandlerRegistered) {
      return;
    }

    Shiny.addCustomMessageHandler("kfp-focus", function (message) {
      if (!message || !message.id) {
        return;
      }

      window.requestAnimationFrame(function () {
        const target = document.getElementById(message.id);
        if (target && typeof target.focus === "function") {
          target.focus();
        }
      });
    });

    window.kfpFocusHandlerRegistered = true;
  }

  function init() {
    if (state.initialised) {
      return;
    }

    state.initialised = true;
    initDetailsState();
    bindResizeObserver();
    bindDocumentEvents();
    registerMessageHandlers();
    scheduleDataTableAdjust();
  }

  document.addEventListener("DOMContentLoaded", init, { once: true });
  document.addEventListener("shiny:connected", registerMessageHandlers);
  window.kfpInteractions = state;
})();
