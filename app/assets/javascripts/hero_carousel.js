// Hero Carousel - Professional implementation
(function () {
  "use strict";

  class HeroCarousel {
    constructor(container) {
      this.container = container;
      this.wrapper = container.querySelector("#carousel-wrapper");
      this.allSlides = Array.from(container.querySelectorAll(".hero-slide"));
      this.realSlides = this.allSlides.filter((slide) => {
        const slideData = slide.getAttribute("data-slide");
        return slideData !== "clone-last" && slideData !== "clone-first";
      });
      this.dots = Array.from(container.querySelectorAll("[data-dot]"));

      this.currentIndex = 0;
      this.totalSlides = this.realSlides.length;
      this.autoPlayInterval = null;
      this.isTransitioning = false;
      this.slideWidth = 0;

      this.init();
    }

    init() {
      if (this.totalSlides === 0) return;

      this.setupSlides();
      this.setupEventListeners();
      this.goToSlide(0, true);
      this.startAutoPlay();
    }

    setupSlides() {
      this.slideWidth = window.innerWidth;
      const totalWidth = this.allSlides.length * this.slideWidth;

      this.wrapper.style.width = `${totalWidth}px`;

      this.allSlides.forEach((slide) => {
        slide.style.width = `${this.slideWidth}px`;
        slide.style.minWidth = `${this.slideWidth}px`;
      });
    }

    setupEventListeners() {
      // Dot navigation
      this.dots.forEach((dot, index) => {
        dot.addEventListener("click", () => {
          this.goToSlide(index);
          this.resetAutoPlay();
        });
      });

      // Pause on hover
      this.container.addEventListener("mouseenter", () => this.stopAutoPlay());
      this.container.addEventListener("mouseleave", () => this.startAutoPlay());

      // Handle resize
      let resizeTimer;
      window.addEventListener("resize", () => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => {
          this.handleResize();
        }, 250);
      });
    }

    handleResize() {
      this.setupSlides();
      this.goToSlide(this.currentIndex, true);
    }

    updateDots(index) {
      this.dots.forEach((dot, i) => {
        if (i === index) {
          dot.classList.remove("bg-white/50");
          dot.classList.add("bg-white");
        } else {
          dot.classList.remove("bg-white");
          dot.classList.add("bg-white/50");
        }
      });
    }

    goToSlide(index, skipTransition = false) {
      if (this.isTransitioning || (index === this.currentIndex && !skipTransition)) return;
      if (index < 0 || index >= this.totalSlides) return;

      this.isTransitioning = !skipTransition;

      // Real slides start at position 1 (after clone-last)
      const position = (index + 1) * this.slideWidth;

      if (skipTransition) {
        this.wrapper.style.transition = "none";
        this.wrapper.style.transform = `translateX(-${position}px)`;
        setTimeout(() => {
          this.wrapper.style.transition = "transform 700ms ease-in-out";
        }, 50);
      } else {
        this.wrapper.style.transform = `translateX(-${position}px)`;
      }

      this.currentIndex = index;
      this.updateDots(index);

      if (!skipTransition) {
        setTimeout(() => {
          this.isTransitioning = false;
        }, 700);
      } else {
        this.isTransitioning = false;
      }
    }

    nextSlide() {
      if (this.isTransitioning) return;

      const nextIndex = (this.currentIndex + 1) % this.totalSlides;

      if (this.currentIndex === this.totalSlides - 1 && nextIndex === 0) {
        // Loop: transition to clone-first, then jump to real first
        this.isTransitioning = true;
        const clonePosition = (this.totalSlides + 1) * this.slideWidth;
        this.wrapper.style.transform = `translateX(-${clonePosition}px)`;

        setTimeout(() => {
          this.wrapper.style.transition = "none";
          this.wrapper.style.transform = `translateX(-${this.slideWidth}px)`;
          this.currentIndex = 0;
          this.updateDots(0);
          this.isTransitioning = false;

          setTimeout(() => {
            this.wrapper.style.transition = "transform 700ms ease-in-out";
          }, 50);
        }, 700);
      } else {
        this.goToSlide(nextIndex);
      }
    }

    startAutoPlay() {
      this.stopAutoPlay();
      this.autoPlayInterval = setInterval(() => {
        this.nextSlide();
      }, 5000);
    }

    stopAutoPlay() {
      if (this.autoPlayInterval) {
        clearInterval(this.autoPlayInterval);
        this.autoPlayInterval = null;
      }
    }

    resetAutoPlay() {
      this.stopAutoPlay();
      this.startAutoPlay();
    }
  }

  // Initialize carousel
  function init() {
    const carousel = document.getElementById("hero-carousel");
    if (carousel) {
      new HeroCarousel(carousel);
    }
  }

  // Initialize when DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    setTimeout(init, 100);
  }

  // Reinitialize on Turbo navigation
  document.addEventListener("turbo:load", () => setTimeout(init, 100));
  document.addEventListener("turbo:render", () => setTimeout(init, 100));
})();
