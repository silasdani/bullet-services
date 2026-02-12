# API Versioning Strategy

## Overview

This document outlines the API versioning strategy for the Bullet Services API.

## Current Version

- **Current API Version**: `v1`
- **Base Path**: `/api/v1/`

## Versioning Approach

### URL-Based Versioning

We use URL-based versioning where the version is included in the path:

```
/api/v1/work_orders
/api/v1/users
/api/v1/invoices
```

### Version Format

- Versions follow semantic versioning (major.minor.patch)
- Only major versions are included in the URL (e.g., `v1`, `v2`)
- Minor and patch versions are backward compatible within the same major version

## Version Lifecycle

### Version Deprecation Policy

1. **Announcement Period**: 6 months before deprecation
   - Deprecated endpoints will return a `Deprecation` header
   - Documentation will clearly mark deprecated endpoints

2. **Deprecation Period**: 3 months
   - Deprecated endpoints continue to work
   - Clients receive warnings in response headers
   - New features are not added to deprecated versions

3. **Sunset Period**: 1 month before removal
   - Final warnings sent to all API consumers
   - Support tickets prioritized for migration

4. **Removal**: After sunset period
   - Deprecated versions are removed
   - Clients must upgrade to supported versions

### Version Support

- **Current Version**: Fully supported, receives all updates
- **Previous Major Version**: Supported for 12 months after new version release
- **Older Versions**: Not supported, may be removed

## Breaking Changes

### What Constitutes a Breaking Change?

Breaking changes require a new major version:

- Removing endpoints
- Removing required fields from requests
- Changing response structure significantly
- Changing authentication mechanisms
- Removing or changing error codes

### Non-Breaking Changes (Same Version)

These changes can be made within the same major version:

- Adding new endpoints
- Adding optional fields to requests
- Adding new fields to responses
- Adding new error codes
- Performance improvements
- Bug fixes

## Migration Guide

### For API Consumers

When a new version is released:

1. Review the [CHANGELOG.md](../CHANGELOG.md) for breaking changes
2. Update your API client to use the new version
3. Test thoroughly in a staging environment
4. Update your integration before the deprecation deadline

### Example Migration

```ruby
# Old (v1)
GET /api/v1/work_orders

# New (v2)
GET /api/v2/work_orders
```

## Version Headers

API responses include version information:

```
API-Version: v1
API-Deprecated: false
API-Sunset: null
```

For deprecated versions:

```
API-Version: v1
API-Deprecated: true
API-Sunset: 2026-06-01
```

## Implementation

### Adding a New Version

1. Create new controller namespace: `Api::V2::`
2. Copy base controller structure
3. Implement new endpoints
4. Update routes: `namespace :v2 do ... end`
5. Update documentation
6. Announce deprecation of old version

### Deprecating a Version

1. Add deprecation headers to responses
2. Update documentation
3. Notify API consumers
4. Set sunset date
5. Monitor usage metrics

## Best Practices

1. **Backward Compatibility**: Maintain backward compatibility within major versions
2. **Clear Documentation**: Document all changes clearly
3. **Gradual Migration**: Provide migration paths and tools
4. **Communication**: Notify consumers well in advance
5. **Testing**: Test version changes thoroughly before release

## Future Considerations

- Consider GraphQL for more flexible API evolution
- Evaluate API gateway solutions for version management
- Implement version negotiation via headers (future enhancement)

## Questions?

For questions about API versioning, contact the development team or open an issue.
