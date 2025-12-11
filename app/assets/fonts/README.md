# Fonts Directory

Add your OTF font files to this directory.

## Usage

After adding your font files, you can reference them in your CSS:

```css
@font-face {
  font-family: 'YourFontName';
  src: url('font-name.otf') format('opentype');
  font-weight: normal;
  font-style: normal;
}
```

Or using Rails asset helpers:

```css
@font-face {
  font-family: 'YourFontName';
  src: font-url('font-name.otf') format('opentype');
  font-weight: normal;
  font-style: normal;
}
```

## Supported Formats

- `.otf` (OpenType)
- `.ttf` (TrueType)
- `.woff` (Web Open Font Format)
- `.woff2` (Web Open Font Format 2)
