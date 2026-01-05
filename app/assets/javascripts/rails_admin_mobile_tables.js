// RailsAdmin Mobile Table Enhancements
// Adds data-label attributes to table cells for mobile card layout
(function() {
  'use strict';

  function enhanceTables() {
    // Find all tables in Rails Admin
    var tables = document.querySelectorAll('.rails_admin .table');
    
    tables.forEach(function(table) {
      var thead = table.querySelector('thead');
      var tbody = table.querySelector('tbody');
      
      if (!thead || !tbody) return;
      
      // Get header labels
      var headers = [];
      var headerCells = thead.querySelectorAll('th');
      
      headerCells.forEach(function(th) {
        // Get text content, excluding icons and buttons
        var text = th.textContent.trim();
        // Clean up text (remove extra whitespace, newlines)
        text = text.replace(/\s+/g, ' ');
        headers.push(text);
      });
      
      // Add data-label attributes to each cell
      var rows = tbody.querySelectorAll('tr');
      rows.forEach(function(row) {
        var cells = row.querySelectorAll('td');
        cells.forEach(function(cell, index) {
          if (headers[index]) {
            cell.setAttribute('data-label', headers[index]);
          }
        });
      });
    });
  }

  // Initialize on page load
  function init() {
    enhanceTables();
  }

  // Run on DOMContentLoaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Re-run after Turbo navigation (Turbo Drive/Turbo Frame)
  if (typeof Turbo !== 'undefined') {
    document.addEventListener('turbo:load', init);
    document.addEventListener('turbo:frame-load', init);
  }

  // Also support jQuery ready if available (Rails Admin uses jQuery)
  if (typeof jQuery !== 'undefined') {
    jQuery(document).ready(init);
    jQuery(document).on('ajax:complete', init);
  }
})();

