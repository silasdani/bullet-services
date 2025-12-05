# Stimulus Controllers

This directory contains Stimulus controllers for interactive JavaScript functionality.

Stimulus is loaded via CDN in the main layout. Controllers should register themselves when the page loads.

## Creating a Controller

Create a new file with the pattern: `[name]_controller.js`

Example: `modal_controller.js`

```javascript
// modal_controller.js
document.addEventListener('DOMContentLoaded', function() {
  if (window.Stimulus) {
    window.Stimulus.register("modal", class extends window.Stimulus.Controller {
      static targets = ["dialog"]
      
      connect() {
        console.log("Modal controller connected")
      }
      
      open() {
        this.dialogTarget.classList.remove("hidden")
      }
      
      close() {
        this.dialogTarget.classList.add("hidden")
      }
    })
  }
})
```

## Using Controllers

In your HTML/ERB templates:

```erb
<div data-controller="modal">
  <button data-action="click->modal#open">Open Modal</button>
  <div data-modal-target="dialog" class="hidden">
    <!-- Modal content -->
  </div>
</div>
```

## Auto-loading

Controllers in this directory are automatically loaded via `require_tree` in `application.js`.

## Documentation

Learn more: https://stimulus.hotwired.dev
