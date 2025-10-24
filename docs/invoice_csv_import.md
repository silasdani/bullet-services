# Invoice CSV Import

This document describes the CSV import functionality for invoices in the Bullet Services application.

## Overview

The CSV import feature allows users to bulk import invoice data from CSV files. This is useful for migrating data from external systems or bulk data entry.

## API Endpoint

```
POST /api/v1/invoices/csv_import
```

### Authentication
- Requires authentication via Devise Token Auth
- User must have admin or employee role

### Request Format
- Content-Type: `multipart/form-data`
- Parameter: `csv_file` (file upload)

### Response Format

#### Success Response
```json
{
  "success": true,
  "message": "CSV import completed",
  "results": {
    "total_rows": 10,
    "successful_imports": 8,
    "failed_imports": 2,
    "errors": [
      "Row 3: Name can't be blank",
      "Row 7: Slug has already been taken"
    ]
  }
}
```

#### Error Response
```json
{
  "success": false,
  "error": "CSV import failed",
  "message": "Invalid CSV format: Missing headers",
  "results": {
    "total_rows": 0,
    "successful_imports": 0,
    "failed_imports": 0,
    "errors": []
  }
}
```

## CSV Format

### Required Headers
- `name` - Invoice name (required)
- `slug` - Unique identifier (required)
- `freshbooks_client_id` - Client identifier (required)
- `status` - Invoice status (required)
- `final_status` - Final status (required)

### Optional Headers
- `webflow_item_id` - Webflow item ID
- `is_archived` - Boolean (true/false)
- `is_draft` - Boolean (true/false)
- `webflow_created_on` - Date string
- `webflow_published_on` - Date string
- `job` - Job description
- `wrs_link` - WRS link URL
- `included_vat_amount` - Decimal amount
- `excluded_vat_amount` - Decimal amount
- `status_color` - Color code
- `invoice_pdf_link` - PDF link URL

### Data Types
- **Boolean fields**: Accept `true`, `false`, `1`, `0`, `yes`, `no`, `y`, `n`
- **Decimal fields**: Accept currency symbols (£, $, €), commas will be removed
- **Date fields**: Accept any string format
- **All fields**: Leading/trailing whitespace is automatically trimmed

### Example CSV
```csv
name,slug,webflow_item_id,is_archived,is_draft,webflow_created_on,webflow_published_on,freshbooks_client_id,job,wrs_link,included_vat_amount,excluded_vat_amount,status_color,status,final_status,invoice_pdf_link
"Sample Invoice 1","sample-invoice-1","wf-item-123",false,false,"2024-01-15","2024-01-16","client-001","Window Repair Job","https://example.com/wrs/1","120.00","1000.00","#28a745","Paid","Completed","https://example.com/invoices/sample-1.pdf"
```

## Validation Rules

- `name`: Must be present
- `slug`: Must be present and unique
- `webflow_item_id`: Must be unique if provided
- `freshbooks_client_id`: Must be present
- `status`: Must be present
- `final_status`: Must be present
- `included_vat_amount`: Must be >= 0 if provided
- `excluded_vat_amount`: Must be >= 0 if provided

## Error Handling

The import process uses database transactions, so if any row fails validation, the entire import is rolled back. However, the service provides detailed feedback about which rows failed and why.

## Usage Examples

### cURL Example
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "csv_file=@invoices.csv" \
  http://localhost:3000/api/v1/invoices/csv_import
```

### JavaScript Example
```javascript
const formData = new FormData();
formData.append('csv_file', fileInput.files[0]);

fetch('/api/v1/invoices/csv_import', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`
  },
  body: formData
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    console.log(`Imported ${data.results.successful_imports} invoices successfully`);
  } else {
    console.error('Import failed:', data.message);
  }
});
```

## Notes

- The import process logs all activities for debugging purposes
- Large CSV files are processed in memory, so consider file size limits
- All imports are logged with user information for audit purposes
- The service follows the existing application patterns for error handling and logging
