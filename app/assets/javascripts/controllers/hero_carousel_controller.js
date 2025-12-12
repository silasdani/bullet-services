// Hero Carousel Controller - Simple vanilla JavaScript approach
(function () {
  "use strict";

  function initCarousel() {
    const carousel = document.querySelector('[data-controller="hero-carousel"]');
    if (!carousel) return;

    const slides = carousel.querySelectorAll('[data-hero-carousel-target="slide"]');
    const dots = carousel.querySelectorAll('[data-hero-carousel-target="dot"]');

    if (slides.length === 0) return;

    let currentIndex = 0;
    let interval = null;

    function showSlide(index) {
      // Hide all slides
      slides.forEach((slide, i) => {
        if (i === index) {
          slide.classList.remove("opacity-0");
          slide.classList.add("opacity-100");
        } else {
          slide.classList.remove("opacity-100");
          slide.classList.add("opacity-0");
        }
      });

      // Update dots
      dots.forEach((dot, i) => {
        if (i === index) {
          dot.classList.remove("bg-white/50");
          dot.classList.add("bg-white");
        } else {
          dot.classList.remove("bg-white");
          dot.classList.add("bg-white/50");
        }
      });

      currentIndex = index;
    }

    function nextSlide() {
      const nextIndex = (currentIndex + 1) % slides.length;
      showSlide(nextIndex);
    }

    function startAutoPlay() {
      stopAutoPlay();
      interval = setInterval(nextSlide, 5000);
    }

    function stopAutoPlay() {
      if (interval) {
        clearInterval(interval);
        interval = null;
      }
    }

    // Add click handlers to dots
    dots.forEach((dot, index) => {
      dot.addEventListener("click", function () {
        showSlide(index);
        stopAutoPlay();
        startAutoPlay();
      });
    });

    // Start auto-play
    startAutoPlay();

    // Pause on hover (optional enhancement)
    carousel.addEventListener("mouseenter", stopAutoPlay);
    carousel.addEventListener("mouseleave", startAutoPlay);
  }

  // Initialize when DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initCarousel);
  } else {
    initCarousel();
  }

  // Reinitialize on Turbo navigation (for SPA-like behavior)
  document.addEventListener("turbo:load", initCarousel);
  document.addEventListener("turbo:render", initCarousel);
})();
