// Typewriter Animation - Professional implementation
(function () {
  "use strict";

  let globalTypewriterInstance = null;

  class TypewriterAnimation {
    constructor(element, words = ["interiors.", "exteriors.", "dreams."]) {
      this.element = element;
      this.words = words;
      this.currentWordIndex = 0;
      this.currentText = "interiors.";
      this.isDeleting = false;
      this.speed = 100;
      this.deleteSpeed = 50;
      this.pauseTime = 1000;
      this.pauseTimer = null;
      this.animationTimer = null;
      this.isPaused = false;

      this.init();
    }

    init() {
      // Start with "interiors." displayed
      this.element.textContent = this.currentText;

      // Start animation after initial pause
      setTimeout(() => {
        this.isDeleting = true;
        this.startAnimation();
      }, 500);
    }

    startAnimation() {
      if (this.animationTimer) {
        clearTimeout(this.animationTimer);
      }

      if (this.isPaused) {
        return;
      }

      const currentWord = this.words[this.currentWordIndex];

      if (this.isDeleting) {
        // Delete character
        this.currentText = this.currentText.slice(0, -1);
        this.element.textContent = this.currentText;

        if (this.currentText === "") {
          // Finished deleting, move to next word
          this.isDeleting = false;
          this.currentWordIndex = (this.currentWordIndex + 1) % this.words.length;

          // Brief pause before typing new word
          this.animationTimer = setTimeout(() => {
            this.startAnimation();
          }, 300);
          return;
        }

        this.animationTimer = setTimeout(() => {
          this.startAnimation();
        }, this.deleteSpeed);
      } else {
        // Type character
        this.currentText = currentWord.slice(0, this.currentText.length + 1);
        this.element.textContent = this.currentText;

        if (this.currentText === currentWord) {
          // Finished typing, pause then start deleting
          this.isPaused = true;
          this.pauseTimer = setTimeout(() => {
            this.isPaused = false;
            this.isDeleting = true;
            this.startAnimation();
          }, this.pauseTime);
          return;
        }

        this.animationTimer = setTimeout(() => {
          this.startAnimation();
        }, this.speed);
      }
    }

    stop() {
      if (this.animationTimer) {
        clearTimeout(this.animationTimer);
        this.animationTimer = null;
      }
      if (this.pauseTimer) {
        clearTimeout(this.pauseTimer);
        this.pauseTimer = null;
      }
    }

    restart() {
      this.stop();
      this.currentText = "interiors.";
      this.currentWordIndex = 0;
      this.isDeleting = false;
      this.isPaused = false;
      this.element.textContent = this.currentText;
      this.init();
    }
  }

  // Initialize typewriter animation (only one instance)
  function initTypewriter() {
    const typewriterElement = document.querySelector("[data-typewriter]");

    if (!typewriterElement) {
      return;
    }

    // Clean up existing instance if any
    if (globalTypewriterInstance) {
      globalTypewriterInstance.stop();
      globalTypewriterInstance = null;
    }

    // Initialize new instance
    globalTypewriterInstance = new TypewriterAnimation(typewriterElement);
  }

  // Initialize when DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => {
      setTimeout(initTypewriter, 500);
    });
  } else {
    setTimeout(initTypewriter, 500);
  }

  // Reinitialize on Turbo navigation
  document.addEventListener("turbo:load", () => {
    setTimeout(initTypewriter, 500);
  });

  document.addEventListener("turbo:render", () => {
    setTimeout(initTypewriter, 500);
  });
})();