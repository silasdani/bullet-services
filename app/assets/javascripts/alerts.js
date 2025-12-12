// Auto-dismiss alerts after 5 seconds
(function () {
  function dismissAlert(alertElement) {
    alertElement.style.animation = "fadeOut 0.3s ease-out";
    setTimeout(() => {
      alertElement.remove();
    }, 300);
  }

  function initAlerts() {
    const alerts = document.querySelectorAll(".alert");
    alerts.forEach((alert) => {
      // Auto-dismiss after 5 seconds
      const timeoutId = setTimeout(() => {
        dismissAlert(alert);
      }, 5000);

      // Clear timeout if user manually closes the alert
      const closeButton = alert.querySelector(".alert-close");
      if (closeButton) {
        closeButton.addEventListener("click", () => {
          clearTimeout(timeoutId);
        });
      }
    });
  }

  // Initialize when DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAlerts);
  } else {
    initAlerts();
  }

  // Reinitialize on Turbo navigation
  document.addEventListener("turbo:load", initAlerts);
  document.addEventListener("turbo:render", initAlerts);
})();
