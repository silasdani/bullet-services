# Quick Start: Frontend Development

## Getting Started

After running `bundle install`, you're ready to build!

## Creating Your First Component

### ViewComponent Example

```ruby
# app/components/navigation_component.rb
class NavigationComponent < ApplicationComponent
  def initialize(current_path:)
    @current_path = current_path
  end

  private

  attr_reader :current_path

  def active_class(path)
    current_path == path ? "text-blue-600 font-bold" : "text-gray-600"
  end
end
```

```erb
<!-- app/components/navigation_component.html.erb -->
<nav class="flex space-x-4">
  <%= link_to "Home", root_path, class: active_class(root_path) %>
  <%= link_to "About", about_path, class: active_class(about_path) %>
  <%= link_to "Contact", contact_path, class: active_class(contact_path) %>
</nav>
```

```erb
<!-- Usage in view -->
<%= render NavigationComponent.new(current_path: request.path) %>
```

## Using Tailwind CSS

Just use utility classes:

```erb
<div class="container mx-auto px-4 py-8">
  <h1 class="text-4xl font-bold text-gray-900 mb-4">Welcome</h1>
  <p class="text-lg text-gray-600">Build beautiful UIs quickly</p>
</div>
```

## Adding Interactivity with Stimulus

Create a controller:

```javascript
// app/assets/javascripts/controllers/dropdown_controller.js
document.addEventListener('DOMContentLoaded', function() {
  if (window.Stimulus) {
    window.Stimulus.register("dropdown", class extends window.Stimulus.Controller {
      static targets = ["menu"]
      
      toggle() {
        this.menuTarget.classList.toggle("hidden")
      }
    })
  }
})
```

Use it:

```erb
<div data-controller="dropdown">
  <button data-action="click->dropdown#toggle">Menu</button>
  <div data-dropdown-target="menu" class="hidden">
    <!-- Menu items -->
  </div>
</div>
```

## Key Points

- **ViewComponents**: Reusable, testable UI components
- **Tailwind**: Utility classes for styling
- **Stimulus**: Lightweight JS for interactions
- **Turbo**: Automatic - handles navigation automatically

That's it! You're ready to build. 🚀
