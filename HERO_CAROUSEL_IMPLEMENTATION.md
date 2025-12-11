# Hero Carousel Implementation

## Overview

Implemented a hero carousel/slider on the homepage that matches the Webflow design with auto-rotation, navigation dots, and the signature radial gradient overlay.

## Features

### ✅ Auto-Rotating Slides
- Automatically transitions between slides every 5 seconds
- Smooth fade transitions (1 second duration)
- Pauses and restarts timer when user manually navigates

### ✅ Manual Navigation
- Navigation dots at the bottom center
- Click any dot to jump to that slide
- Active dot is highlighted in white

### ✅ Design Matching Webflow
- Radial gradient overlay (transparent to black at bottom-right)
- Same background positioning and sizing
- Responsive background-repeat behavior
- Full-screen height hero section

### ✅ Responsive Images
- Different images can be configured for different screen sizes
- Currently uses same images but structure supports responsive switching

## Components

### 1. HeroCarouselComponent
**Location**: `app/components/hero_carousel_component.rb`

Ruby component that defines the slides:
- Each slide has an image and title
- Easy to add/remove/modify slides
- Currently has 3 slides

### 2. Hero Carousel Template
**Location**: `app/components/hero_carousel_component.html.erb`

The HTML structure:
- Multiple slide divs stacked with opacity transitions
- Navigation dots for manual control
- Responsive styling

### 3. Stimulus Controller
**Location**: `app/assets/javascripts/controllers/hero_carousel_controller.js`

JavaScript functionality:
- Auto-rotation logic
- Manual navigation handlers
- Slide transitions
- Timer management

### 4. Custom CSS
**Location**: `app/assets/stylesheets/hero_carousel.css`

Matching Webflow styles:
- Radial gradient positioning
- Responsive background-repeat rules
- Border styling

## Current Slides

1. **Slide 1**: `cover.jpg` (default) / `madeleine-ragsdale-pJwH0MNXQp0-unsplash.jpg` (large screens)
2. **Slide 2**: `black-white-exterior-building.jpg`
3. **Slide 3**: `madeleine-ragsdale-pJwH0MNXQp0-unsplash.jpg` (default) / `cover.jpg` (large screens)

All slides display: "We build exteriors."

## Customization

### Adding More Slides

Edit `app/components/hero_carousel_component.rb`:

```ruby
@slides = [
  {
    image: "your-image.jpg",
    image_large: "your-large-image.jpg", # Optional: different for 1920px+
    title: "Your Title"
  },
  # Add more slides...
]
```

### Changing Auto-Rotate Speed

Edit `app/assets/javascripts/controllers/hero_carousel_controller.js`:

```javascript
// Change 5000 to desired milliseconds (currently 5 seconds)
this.interval = setInterval(() => {
  this.nextSlide()
}, 5000) // Change this number
```

### Changing Transition Duration

Edit `app/components/hero_carousel_component.html.erb`:

```erb
class="hero-slide ... transition-opacity duration-1000 ..."
<!-- Change duration-1000 to duration-500, duration-2000, etc. -->
```

## Technical Details

### Styling
- Uses Tailwind CSS for layout and utilities
- Custom CSS for Webflow-specific background patterns
- Radial gradient: `circle at 100% 100%` (bottom-right corner)

### JavaScript
- Uses Stimulus framework (loaded via CDN)
- Auto-registers when page loads
- Handles DOM manipulation and timing

### Image Assets
- Images stored in `app/assets/images/`
- Referenced via Rails `asset_path` helper
- Supports different images for large screens (1920px+)

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- Requires JavaScript enabled
- Gracefully degrades - first slide always visible

## Notes

- The carousel automatically loads when the page loads
- Navigation dots appear at the bottom center
- Smooth transitions between slides
- Matches the Webflow design aesthetic
