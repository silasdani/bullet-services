// Accordion Component - Professional, simple implementation
(function() {
  'use strict';

  function initAccordion() {
    const accordionContainer = document.querySelector('[data-accordion]');
    if (!accordionContainer) return;

    const toggles = accordionContainer.querySelectorAll('[data-accordion-toggle]');
    
    toggles.forEach(toggle => {
      toggle.addEventListener('click', function() {
        const content = this.nextElementSibling;
        const icon = this.querySelector('svg');
        const isExpanded = this.getAttribute('aria-expanded') === 'true';

        // Close all other items (optional - remove if you want multiple open)
        toggles.forEach(otherToggle => {
          if (otherToggle !== this) {
            const otherContent = otherToggle.nextElementSibling;
            const otherIcon = otherToggle.querySelector('svg');
            otherContent.classList.add('hidden');
            otherToggle.setAttribute('aria-expanded', 'false');
            if (otherIcon) {
              otherIcon.classList.remove('rotate-180');
            }
          }
        });

        // Toggle current item
        if (isExpanded) {
          content.classList.add('hidden');
          this.setAttribute('aria-expanded', 'false');
          if (icon) {
            icon.classList.remove('rotate-180');
          }
        } else {
          content.classList.remove('hidden');
          this.setAttribute('aria-expanded', 'true');
          if (icon) {
            icon.classList.add('rotate-180');
          }
        }
      });
    });
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAccordion);
  } else {
    initAccordion();
  }

  // Reinitialize on Turbo navigation
  document.addEventListener('turbo:load', initAccordion);
  document.addEventListener('turbo:render', initAccordion);
})();
