# Testing Cheatsheet - Bullet Services

## Quick Test Commands

### Run All Tests
```bash
rails test
```

### Run Specific Test Files
```bash
# Service layer tests
rails test test/services/wrs_creation_service_test.rb
rails test test/services/wrs_creation_service_test.rb -n test_creates_WRS_with_windows_and_tools

# Controller tests
rails test test/controllers/api/v1/work_orders_controller_test.rb
rails test test/controllers/api/v1/work_orders_controller_test.rb -n test_should_get_index

# Model tests
rails test test/models/work_order_auto_sync_test.rb
rails test test/models/window_test.rb

# Policy tests
rails test test/policies/work_order_policy_test.rb
```

### Run Tests with Verbose Output
```bash
rails test test/services/wrs_creation_service_test.rb --verbose
```

### Run Tests with Specific Seed
```bash
rails test --seed 12345
```

## Test Environment Setup

### Test Database
```bash
# Reset test database
rails db:test:prepare

# Load fixtures
rails db:fixtures:load RAILS_ENV=test
```

## Authentication Testing

### API Authentication Helper
```ruby
# In test_helper.rb - already implemented
def auth_headers(user)
  if user.tokens.empty?
    user.create_token
    user.save!
  end
  
  {
    'access-token' => user.tokens.values.first['token'],
    'client' => user.tokens.keys.first,
    'uid' => user.uid
  }
end

# Usage in tests
get api_v1_work_orders_url, headers: auth_headers(@user)
```

### User Setup
```ruby
def setup
  @user = users(:one)  # Uses fixtures
  # Don't use sign_in for API tests - use token auth instead
end
```

## Service Layer Testing

### WRS Creation Service
```ruby
test 'creates WRS with windows and tools' do
  service = Wrs::CreationService.new(user: @user, params: @valid_params)
  result = service.call

  assert result[:success]
  assert_equal 'Test WRS', result[:wrs].name
  assert_equal 2, result[:wrs].windows.count
  assert_equal 225.0, result[:wrs].total_vat_excluded_price
end
```

### Service Error Testing
```ruby
test 'handles invalid params' do
  invalid_params = @valid_params.merge(name: '')
  service = Wrs::CreationService.new(user: @user, params: invalid_params)
  result = service.call

  refute result[:success]
  assert_includes service.errors, "Name can't be blank"
end
```

## Controller Testing

### API Controller Tests
```ruby
test 'should get index' do
  get api_v1_work_orders_url, headers: auth_headers(@user)
  assert_response :success
end

test 'should create work_order' do
  assert_difference('WorkOrder.count') do
    post api_v1_work_orders_url, 
         params: { work_order: valid_attributes },
         headers: auth_headers(@user)
  end
  assert_response :created
end
```

### Controller Test Setup
```ruby
def setup
  @user = users(:one)
  @work_order = @user.work_orders.create!(
    name: 'Test Schedule',
    slug: "test-schedule-#{Time.current.to_i}",
    address: '123 Test St',
    total_vat_included_price: 1000
  )
end
```

## Model Testing

### Soft Delete Testing
```ruby
test 'should soft delete WRS' do
  wrs = work_orders(:one)
  wrs.soft_delete!
  
  assert wrs.deleted?
  assert wrs.deleted_at.present?
end

test 'should restore WRS' do
  wrs = work_orders(:one)
  wrs.soft_delete!
  wrs.restore!
  
  assert wrs.active?
  assert wrs.deleted_at.nil?
end
```

## Mock Testing

### Minitest::Mock Usage
```ruby
test 'creates WRS with image upload' do
  mock_file = mock('uploaded_file')
  mock_file.expect(:present?, true)
  mock_file.expect(:respond_to?, true, [:content_type])
  mock_file.expect(:content_type, 'image/jpeg')
  mock_file.expect(:original_filename, 'test.jpg')

  params_with_image = @valid_params.deep_dup
  params_with_image[:windows_attributes][0][:image] = mock_file

  service = Wrs::CreationService.new(user: @user, params: params_with_image)
  result = service.call

  assert result[:success]
end
```

## Policy Testing

### Pundit Policy Tests
```ruby
test 'scope returns user WRS' do
  user = users(:one)
  wrs = work_orders(:one)
  
  scope = WorkOrderPolicy::Scope.new(user, WorkOrder).resolve
  assert_includes scope, wrs
end
```

## Common Test Patterns

### Database Changes
```ruby
# Test record creation
assert_difference('WorkOrder.count', 1) do
  # action
end

# Test record deletion
assert_difference('WorkOrder.count', -1) do
  # action
end

# Test no change
assert_no_difference('WorkOrder.count') do
  # action
end
```

### Response Testing
```ruby
assert_response :success        # 200
assert_response :created        # 201
assert_response :unauthorized   # 401
assert_response :forbidden      # 403
assert_response :not_found      # 404
assert_response :unprocessable_entity  # 422
```

### JSON Response Testing
```ruby
response_body = JSON.parse(response.body)
assert_equal 'success', response_body['status']
assert_includes response_body['data'], 'id'
```

## Debugging Tests

### Check Test Logs
```bash
tail -f log/test.log
```

### Run Single Test with Debug
```bash
rails test test/services/wrs_creation_service_test.rb -n test_creates_WRS_with_windows_and_tools --verbose
```

### Rails Console for Testing
```bash
rails console --environment=test
```

## Test Data Setup

### Fixtures Usage
```ruby
# In test files
@user = users(:one)
@work_order = work_orders(:one)
@window = windows(:one)
```

### Factory Pattern (if using FactoryBot)
```ruby
# Create test data
user = create(:user)
work_order = create(:work_order, user: user)
```

## Common Issues & Solutions

### Authentication Issues
- **Problem**: 401 Unauthorized errors
- **Solution**: Use `auth_headers(@user)` instead of `sign_in @user` for API tests

### Mock Issues
- **Problem**: `undefined method 'stubs'`
- **Solution**: Use `expect` instead of `stubs` with Minitest::Mock

### Database Issues
- **Problem**: Tests affecting each other
- **Solution**: Use `setup` and `teardown` methods, or `rails db:test:prepare`

### Service Layer Issues
- **Problem**: Service returning `nil`
- **Solution**: Check error handling in service `call` method

## Performance Testing

### Run Tests in Parallel (if supported)
```bash
# Disabled due to Ruby 3.4.4 segfault with PostgreSQL
# parallelize(workers: :number_of_processors)
```

### Test Coverage
```bash
# If using SimpleCov
COVERAGE=true rails test
```

## Quick Debugging Commands

```bash
# Check routes
rails routes | grep api

# Check database schema
rails db:schema:dump

# Check environment
rails runner "puts Rails.env"

# Check credentials
rails credentials:show
```

## Test File Structure

```
test/
├── controllers/
│   └── api/v1/
│       ├── work_orders_controller_test.rb
│       ├── windows_controller_test.rb
│       └── images_controller_test.rb
├── models/
│   ├── window_schedule_repair_auto_sync_test.rb
│   ├── window_test.rb
│   └── tool_test.rb
├── services/
│   └── wrs_creation_service_test.rb
├── policies/
│   ├── window_schedule_repair_policy_test.rb
│   ├── window_policy_test.rb
│   └── user_policy_test.rb
├── fixtures/
│   ├── users.yml
│   ├── work_orders.yml
│   └── windows.yml
└── test_helper.rb
```

## Best Practices

1. **Use descriptive test names** that explain what's being tested
2. **Keep tests focused** - one assertion per test when possible
3. **Use proper setup/teardown** to avoid test interference
4. **Mock external services** to avoid dependencies
5. **Test both success and failure cases**
6. **Use fixtures for consistent test data**
7. **Keep tests fast** - avoid unnecessary database operations
8. **Use meaningful assertions** - prefer specific assertions over generic ones

---

*This cheatsheet covers the current test structure and common patterns used in the Bullet Services project.*
