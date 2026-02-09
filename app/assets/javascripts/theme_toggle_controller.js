// Theme Toggle Controller - Works with or without Stimulus
(function() {
  'use strict';
  
  function toggleTheme(button) {
    const html = document.documentElement
    const isDark = html.classList.contains('dark')
    
    if (isDark) {
      html.classList.remove('dark')
      localStorage.setItem('avo-theme', 'light')
    } else {
      html.classList.add('dark')
      localStorage.setItem('avo-theme', 'dark')
    }
    
    updateIcon(button)
    
    // Dispatch custom event for other components
    window.dispatchEvent(new CustomEvent('theme-changed', { 
      detail: { isDark: !isDark } 
    }))
  }
  
  function updateIcon(button) {
    if (!button) return
    
    const isDark = document.documentElement.classList.contains('dark')
    const sunIcon = button.querySelector('.sun-icon')
    const moonIcon = button.querySelector('.moon-icon')
    
    if (sunIcon && moonIcon) {
      if (isDark) {
        sunIcon.classList.remove('hidden')
        moonIcon.classList.add('hidden')
      } else {
        sunIcon.classList.add('hidden')
        moonIcon.classList.remove('hidden')
      }
    }
  }
  
  function initThemeToggle() {
    // Find all theme toggle buttons
    const toggleButtons = document.querySelectorAll('[data-controller="theme-toggle"]')
    
    if (toggleButtons.length === 0) {
      // Try again after a short delay if buttons aren't loaded yet
      setTimeout(initThemeToggle, 100)
      return
    }
    
    toggleButtons.forEach(function(button) {
      // Skip if already initialized
      if (button.dataset.themeToggleInitialized === 'true') {
        return
      }
      
      // Mark as initialized
      button.dataset.themeToggleInitialized = 'true'
      
      // Update icon on load
      updateIcon(button)
      
      // Add click listener
      button.addEventListener('click', function(e) {
        e.preventDefault()
        e.stopPropagation()
        toggleTheme(button)
      })
    })
  }
  
  // Wait for Stimulus to be available, then register controller
  function registerStimulusController() {
    if (window.Stimulus) {
      try {
        window.Stimulus.register("theme-toggle", class extends window.Stimulus.Controller {
          static targets = ["icon"]

          connect() {
            this.updateIcon()
          }

          toggle(event) {
            if (event) {
              event.preventDefault()
              event.stopPropagation()
            }
            toggleTheme(this.element)
          }

          updateIcon() {
            updateIcon(this.element)
          }
        })
      } catch (e) {
        console.warn('Theme toggle: Could not register Stimulus controller', e)
      }
    } else {
      // Try again after a short delay
      setTimeout(registerStimulusController, 100)
    }
  }
  
  // Initialize vanilla JS version immediately
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      initThemeToggle()
      registerStimulusController()
    })
  } else {
    initThemeToggle()
    registerStimulusController()
  }
  
  // Also listen for Turbo navigation events
  document.addEventListener('turbo:load', initThemeToggle)
  document.addEventListener('turbo:frame-load', initThemeToggle)
})()
