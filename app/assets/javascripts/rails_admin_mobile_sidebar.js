// RailsAdmin mobile sidebar toggle
document.addEventListener("DOMContentLoaded", function () {
  var toggleButton = document.querySelector(".navbar-toggler");
  var sidebar = document.querySelector(".sidebar");

  if (!toggleButton || !sidebar) return;

  toggleButton.addEventListener("click", function () {
    sidebar.classList.toggle("open");
  });
});
