// Mobile Menu Controller - Toggles mobile navigation menu
document.addEventListener('DOMContentLoaded', function() {
  if (window.Stimulus) {
    window.Stimulus.register("mobile-menu", class extends window.Stimulus.Controller {
      static targets = ["menu", "button"]

      connect() {
        // Close menu when clicking outside
        this.boundHandleClickOutside = this.handleClickOutside.bind(this)
        document.addEventListener('click', this.boundHandleClickOutside)
        
        // Close menu on window resize (if resizing to desktop)
        this.boundHandleResize = this.handleResize.bind(this)
        window.addEventListener('resize', this.boundHandleResize)
      }

      disconnect() {
        document.removeEventListener('click', this.boundHandleClickOutside)
        window.removeEventListener('resize', this.boundHandleResize)
      }

      toggle() {
        const isOpen = !this.menuTarget.classList.contains('hidden')
        if (isOpen) {
          this.close()
        } else {
          this.open()
        }
      }

      open() {
        this.menuTarget.classList.remove('hidden')
        this.menuTarget.classList.add('block')
        // Prevent body scroll when menu is open
        document.body.style.overflow = 'hidden'
      }

      close() {
        this.menuTarget.classList.add('hidden')
        this.menuTarget.classList.remove('block')
        document.body.style.overflow = ''
      }

      handleClickOutside(event) {
        if (!this.element.contains(event.target) && !this.menuTarget.classList.contains('hidden')) {
          this.close()
        }
      }

      handleResize() {
        // Close menu if resizing to desktop (lg breakpoint is 1024px in Tailwind)
        if (window.innerWidth >= 1024 && !this.menuTarget.classList.contains('hidden')) {
          this.close()
        }
      }
    })
  }
})

// Also handle Turbo navigation
document.addEventListener('turbo:load', function() {
  if (window.Stimulus && !window.Stimulus.controllers.find(c => c.identifier === 'mobile-menu')) {
    // Re-register if needed (though Stimulus should handle this automatically)
  }
})

