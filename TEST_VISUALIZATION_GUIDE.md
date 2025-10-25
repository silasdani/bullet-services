# 🧪 RSpec Test Visualization Guide

## Overview
This guide shows you how to get IntelliJ-like test visualization in your Rails project using RSpec.

## 🎯 Test Visualization Formats

### 1. **Documentation Format** (Recommended)
```bash
bundle exec rspec --format documentation
# or
./bin/test_runner doc
```

**Output:**
```
User
  associations
    has many window_schedule_repairs
    has many windows through window_schedule_repairs
  validations
    validates presence of email
    validates presence of password
  role helper methods
    when user is admin
      returns true for is_admin?
      returns true for webflow_access
    when user is employee
      returns true for is_employee?
      returns true for webflow_access
```

### 2. **Progress Format** (Quick Overview)
```bash
bundle exec rspec --format progress
# or
./bin/test_runner progress
```

**Output:**
```
..................
18 examples, 0 failures
```

### 3. **JSON Format** (For CI/CD)
```bash
bundle exec rspec --format json
# or
./bin/test_runner json
```

### 4. **HTML Report** (Beautiful Reports)
```bash
bundle exec rspec --format html --out spec/reports/test_report.html
# or
./bin/test_runner html
```

### 5. **Watch Mode** (Auto-rerun on changes)
```bash
bundle exec rspec --format documentation --watch
# or
./bin/test_runner watch
```

## 🚀 Quick Commands

### Run All Tests
```bash
bundle exec rspec
```

### Run Specific Test File
```bash
bundle exec rspec spec/models/user_spec.rb
```

### Run Tests Matching Pattern
```bash
bundle exec rspec spec/models/
bundle exec rspec spec/controllers/
bundle exec rspec spec/services/
```

### Run Failed Tests Only
```bash
bundle exec rspec --only-failures
```

### Run Tests with Coverage
```bash
bundle exec rspec --format documentation --color
```

## 🎨 VS Code Integration

### 1. **Test Explorer Extension**
Install the "RSpec Test Explorer" extension for VS Code to get:
- Test tree view in sidebar
- Run individual tests with click
- See test results inline
- Debug tests directly

### 2. **Launch Configuration**
Use the provided `.vscode/launch.json` to run tests with F5:
- Press F5 to run all tests
- Set breakpoints in your tests
- Debug test failures

### 3. **Terminal Integration**
```bash
# Run tests in VS Code terminal
bundle exec rspec --format documentation

# Watch mode for development
bundle exec rspec --watch
```

## 📊 Test Structure Best Practices

### 1. **Organize Tests Hierarchically**
```ruby
RSpec.describe User, type: :model do
  describe 'associations' do
    it 'has many window_schedule_repairs' do
      # test code
    end
  end

  describe 'validations' do
    context 'when email is missing' do
      it 'is not valid' do
        # test code
      end
    end
  end
end
```

### 2. **Use Descriptive Test Names**
```ruby
# Good
it 'returns true for is_admin? when user role is admin'

# Bad
it 'test admin method'
```

### 3. **Group Related Tests**
```ruby
describe 'soft delete functionality' do
  let(:user) { create(:user) }

  it 'can be soft deleted' do
    expect { user.soft_delete! }.to change { user.deleted_at }.from(nil)
  end

  it 'can be restored' do
    user.soft_delete!
    expect { user.restore! }.to change { user.deleted_at }.to(nil)
  end
end
```

## 🔧 Advanced Features

### 1. **Test Tags**
```ruby
# Mark slow tests
it 'processes large dataset', :slow do
  # test code
end

# Run only fast tests
bundle exec rspec --tag ~slow
```

### 2. **Shared Examples**
```ruby
# spec/support/shared_examples.rb
RSpec.shared_examples 'soft deletable' do
  it 'can be soft deleted' do
    expect { subject.soft_delete! }.to change { subject.deleted_at }.from(nil)
  end
end

# In your specs
RSpec.describe User do
  include_examples 'soft deletable'
end
```

### 3. **Custom Matchers**
```ruby
# spec/support/custom_matchers.rb
RSpec::Matchers.define :have_webflow_access do
  match do |user|
    user.webflow_access
  end
end

# Usage
expect(admin_user).to have_webflow_access
```

## 📈 Test Performance

### 1. **Parallel Testing**
```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.parallelize(workers: :number_of_processors)
end
```

### 2. **Database Cleaner**
```ruby
# spec/support/database_cleaner.rb
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end
end
```

## 🎯 IntelliJ-like Features

### 1. **Test Tree View**
- Install "RSpec Test Explorer" extension
- See all tests organized by file/class
- Run tests with single click
- See pass/fail status inline

### 2. **Inline Test Results**
- Green checkmarks for passing tests
- Red X for failing tests
- Yellow warning for pending tests

### 3. **Test Coverage**
```ruby
# Add to Gemfile
gem 'simplecov', group: :test

# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start 'rails'
```

### 4. **Debugging**
- Set breakpoints in tests
- Step through test execution
- Inspect variables during test run

## 🚀 Getting Started

1. **Run your first test:**
   ```bash
   bundle exec rspec spec/models/user_spec.rb --format documentation
   ```

2. **Install VS Code extensions:**
   - RSpec Test Explorer
   - Ruby
   - Rails

3. **Use the test runner:**
   ```bash
   ./bin/test_runner doc
   ```

4. **Watch tests during development:**
   ```bash
   ./bin/test_runner watch
   ```

## 📝 Example Test Output

```
User
  associations
    has many window_schedule_repairs
    has many windows through window_schedule_repairs
  validations
    validates presence of email
    validates presence of password
  enums
    has role enum with correct values
  role helper methods
    when user is admin
      returns true for is_admin?
      returns true for webflow_access
    when user is employee
      returns true for is_employee?
      returns true for webflow_access
    when user is client
      returns false for is_admin?
      returns false for is_employee?
      returns false for webflow_access
  soft delete functionality
    can be soft deleted
    can be restored
    knows if it is deleted
    knows if it is active
  default role assignment
    assigns client role by default
  confirmation
    sets confirmed_at after creation

Finished in 0.29073 seconds (files took 0.81674 seconds to load)
18 examples, 0 failures
```

This gives you IntelliJ-like test visualization with:
- ✅ Hierarchical test organization
- ✅ Clear test descriptions
- ✅ Color-coded results
- ✅ Detailed failure information
- ✅ Performance metrics
- ✅ Easy debugging and navigation
