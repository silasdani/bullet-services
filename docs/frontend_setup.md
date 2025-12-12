# Frontend Setup Documentation

This document explains the modern frontend stack used in this Rails 8 application.

## Stack Overview

### 1. **Hotwire (Turbo + Stimulus)**
- **Turbo**: Automatically loaded via `turbo-rails` gem
  - Provides SPA-like navigation without a separate frontend framework
  - Handles page transitions, form submissions, and streaming updates
  - No configuration needed - works out of the box

- **Stimulus**: Loaded via CDN (simple, robust)
  - Lightweight JavaScript framework for adding interactivity
  - Controllers live in `app/assets/javascripts/controllers/`
  - Perfect for small JavaScript interactions

### 2. **Tailwind CSS**
- Loaded via CDN for simplicity and robustness
- Utility-first CSS framework
- Easy to migrate to build tools later if needed

### 3. **ViewComponent**
- Component-based view architecture
- Reusable, testable components
- Base class: `ApplicationComponent`

## File Structure

```
app/
├── assets/
│   ├── javascripts/
│   │   ├── application.js          # Main JS manifest (Sprockets)
│   │   └── controllers/            # Stimulus controllers (optional)
│   └── stylesheets/
│       └── application.css         # Main CSS
├── components/                     # ViewComponent classes
│   └── application_component.rb    # Base component class
└── views/
    └── layouts/
        └── application.html.erb    # Main layout
```

## Usage Examples

### Creating a ViewComponent

```ruby
# app/components/button_component.rb
class ButtonComponent < ApplicationComponent
  def initialize(text:, variant: :primary)
    @text = text
    @variant = variant
  end

  private

  attr_reader :text, :variant

  def button_classes
    base = "px-4 py-2 rounded"
    variants = {
      primary: "bg-blue-500 text-white",
      secondary: "bg-gray-500 text-white"
    }
    "#{base} #{variants[variant]}"
  end
end
```

```erb
<!-- app/components/button_component.html.erb -->
<button class="<%= button_classes %>">
  <%= text %>
</button>
```

```erb
<!-- Usage in views -->
<%= render ButtonComponent.new(text: "Click me", variant: :primary) %>
```

### Creating a Stimulus Controller

```javascript
// app/assets/javascripts/controllers/modal_controller.js
// Usage: <div data-controller="modal">

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

```erb
<!-- Usage in HTML -->
<div data-controller="modal">
  <button data-action="click->modal#open">Open</button>
  <div data-modal-target="dialog" class="hidden">
    <!-- Modal content -->
  </div>
</div>
```

### Using Tailwind CSS

Simply use Tailwind utility classes in your HTML/ERB:

```erb
<div class="container mx-auto px-4 py-8">
  <h1 class="text-4xl font-bold text-gray-900 mb-4">Hello World</h1>
  <p class="text-gray-600">This is styled with Tailwind CSS</p>
</div>
```

## Key Benefits

1. **Simple**: CDN-based setup means no build configuration
2. **Robust**: Battle-tested libraries, minimal dependencies
3. **Maintainable**: Clear structure, easy to understand
4. **Scalable**: Easy to migrate to build tools later if needed
5. **Fast Development**: No compilation step for CSS/JS changes

## Upgrading Later

If you want to move to build tools in the future:

- **Tailwind**: Can migrate to `tailwindcss-rails` gem
- **Stimulus**: Can use `stimulus-rails` gem with importmap
- **JavaScript**: Can migrate to importmap or esbuild/webpack

The current setup makes this migration straightforward.

## Resources

- [Turbo Documentation](https://turbo.hotwired.dev)
- [Stimulus Documentation](https://stimulus.hotwired.dev)
- [Tailwind CSS Documentation](https://tailwindcss.com)
- [ViewComponent Documentation](https://viewcomponent.org)
