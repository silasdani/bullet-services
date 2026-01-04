// Professional Mobile Menu - Enhanced UX/UI Implementation
(function () {
  "use strict";

  class MobileMenu {
    constructor() {
      this.menuButton = document.querySelector('[data-mobile-menu-button]');
      this.menuPanel = document.querySelector('[data-mobile-menu-panel]');
      this.menuBackdrop = document.querySelector('[data-mobile-menu-backdrop]');
      this.menuLinks = document.querySelectorAll('[data-mobile-menu-link]');
      this.isOpen = false;
      this.scrollY = 0;
      this.focusableElements = 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])';
      this.firstFocusableElement = null;
      this.lastFocusableElement = null;
      
      if (!this.menuButton || !this.menuPanel || !this.menuBackdrop) return;

      this.init();
    }

    init() {
      // Set up focusable elements
      this.updateFocusableElements();

      // Event listeners
      this.menuButton.addEventListener('click', (e) => this.toggle(e));
      this.menuBackdrop.addEventListener('click', () => this.close());
      
      // Keyboard navigation
      document.addEventListener('keydown', (e) => this.handleKeydown(e));
      
      // Close on window resize to desktop
      let resizeTimer;
      window.addEventListener('resize', () => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => {
          if (window.innerWidth >= 1024 && this.isOpen) {
            this.close();
          }
        }, 250);
      });

      // Close on navigation link click
      this.menuLinks.forEach(link => {
        link.addEventListener('click', () => {
          // Small delay for better UX (allows click animation to complete)
          setTimeout(() => this.close(), 100);
        });
      });
    }

    updateFocusableElements() {
      const focusable = this.menuPanel.querySelectorAll(this.focusableElements);
      this.firstFocusableElement = focusable[0];
      this.lastFocusableElement = focusable[focusable.length - 1];
    }

    toggle(e) {
      if (e) e.preventDefault();
      if (this.isOpen) {
        this.close();
      } else {
        this.open();
      }
    }

    open() {
      if (this.isOpen) return;
      
      this.isOpen = true;
      this.updateFocusableElements();
      
      // Save scroll position
      this.scrollY = window.scrollY;
      
      // Update ARIA attributes
      this.menuButton.setAttribute('aria-expanded', 'true');
      this.menuButton.classList.add('is-open');
      this.menuPanel.classList.add('is-open');
      this.menuBackdrop.classList.add('is-open');
      
      // Prevent body scroll and preserve scroll position
      document.body.style.top = `-${this.scrollY}px`;
      document.body.classList.add('mobile-menu-open');
      
      // Focus management - focus first link
      requestAnimationFrame(() => {
        if (this.firstFocusableElement) {
          this.firstFocusableElement.focus();
        }
      });
    }

    close() {
      if (!this.isOpen) return;
      
      this.isOpen = false;
      
      // Update ARIA attributes
      this.menuButton.setAttribute('aria-expanded', 'false');
      this.menuButton.classList.remove('is-open');
      this.menuPanel.classList.remove('is-open');
      this.menuBackdrop.classList.remove('is-open');
      
      // Restore body scroll and scroll position
      document.body.classList.remove('mobile-menu-open');
      document.body.style.top = '';
      window.scrollTo(0, this.scrollY);
      
      // Return focus to menu button
      requestAnimationFrame(() => {
        this.menuButton.focus();
      });
    }

    handleKeydown(e) {
      if (!this.isOpen) return;

      // Close on ESC key
      if (e.key === 'Escape' || e.keyCode === 27) {
        e.preventDefault();
        this.close();
        return;
      }

      // Trap focus within menu (Tab and Shift+Tab)
      if (e.key === 'Tab' || e.keyCode === 9) {
        if (e.shiftKey) {
          // Shift + Tab
          if (document.activeElement === this.firstFocusableElement) {
            e.preventDefault();
            this.lastFocusableElement.focus();
          }
        } else {
          // Tab
          if (document.activeElement === this.lastFocusableElement) {
            e.preventDefault();
            this.firstFocusableElement.focus();
          }
        }
      }
    }
  }

  function initMobileMenu() {
    new MobileMenu();
  }

  // Initialize when DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initMobileMenu);
  } else {
    initMobileMenu();
  }

  // Reinitialize on Turbo navigation
  document.addEventListener("turbo:load", initMobileMenu);
  document.addEventListener("turbo:render", initMobileMenu);
})();
