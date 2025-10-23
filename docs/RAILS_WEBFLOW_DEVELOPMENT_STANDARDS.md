# Ruby on Rails + Webflow Development Standards

## Table of Contents
- [Project Structure](#project-structure)
- [Database Design](#database-design)
- [Model Architecture](#model-architecture)
- [Controller Patterns](#controller-patterns)
- [Service Layer](#service-layer)
- [Webflow Integration](#webflow-integration)
- [Testing Standards](#testing-standards)
- [Security Guidelines](#security-guidelines)
- [Performance Standards](#performance-standards)
- [Error Handling](#error-handling)
- [Code Quality](#code-quality)
- [Deployment & Configuration](#deployment--configuration)

---

## Project Structure

### Directory Organization
```
app/
├── controllers/
│   ├── api/
│   │   └── v1/
│   │       ├── base_controller.rb
│   │       └── [resource]_controller.rb
│   └── application_controller.rb
├── models/
│   ├── concerns/
│   │   ├── soft_deletable.rb
│   │   ├── webflow_syncable.rb
│   │   └── [domain]_concerns.rb
│   └── [domain_models].rb
├── services/
│   ├── application_service.rb
│   ├── [domain]/
│   │   ├── base_service.rb
│   │   ├── creation_service.rb
│   │   ├── update_service.rb
│   │   └── sync_service.rb
│   └── webflow/
│       ├── base_service.rb
│       ├── item_service.rb
│       ├── collection_service.rb
│       └── webhook_service.rb
├── policies/
│   ├── application_policy.rb
│   └── [resource]_policy.rb
├── serializers/
│   ├── application_serializer.rb
│   └── [resource]_serializer.rb
└── jobs/
    ├── application_job.rb
    └── webflow/
        ├── sync_job.rb
        └── webhook_job.rb
```

### Naming Conventions
- **Controllers**: `Api::V1::ResourceController`
- **Models**: `Resource` (singular, PascalCase)
- **Services**: `Domain::ActionService` (e.g., `Wrs::CreationService`)
- **Policies**: `ResourcePolicy`
- **Serializers**: `ResourceSerializer`
- **Jobs**: `ActionJob` (e.g., `WebflowSyncJob`)

---

## Database Design

### Migration Standards

#### ✅ DO
```ruby
class CreateResources < ActiveRecord::Migration[8.0]
  def change
    create_table :resources do |t|
      # Always use appropriate data types
      t.string :name, null: false, limit: 255
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.boolean :is_active, null: false, default: true
      t.datetime :deleted_at
      
      t.timestamps
    end
    
    # Always add indexes for foreign keys
    add_index :resources, :user_id
    add_index :resources, :deleted_at
    
    # Add foreign key constraints
    add_foreign_key :resources, :users, on_delete: :restrict
  end
end
```

#### ❌ DON'T
```ruby
# Wrong data types
t.integer :price  # Use decimal for money
t.string :description  # Use text for long content

# Missing constraints
t.string :name  # Should be null: false
t.boolean :is_active  # Should have default value

# No indexes
# Missing foreign key constraints
```

### Schema Design Principles

1. **Always use `decimal` for monetary values**
   ```ruby
   t.decimal :price, precision: 10, scale: 2
   t.decimal :total_amount, precision: 12, scale: 2
   ```

2. **Implement soft deletes consistently**
   ```ruby
   t.datetime :deleted_at
   add_index :table_name, :deleted_at
   ```

3. **Add proper constraints**
   ```ruby
   t.string :email, null: false, unique: true
   t.string :slug, null: false, unique: true
   ```

4. **Use appropriate column limits**
   ```ruby
   t.string :name, limit: 255
   t.string :status, limit: 50
   ```

---

## Model Architecture

### Model Structure Standards

#### ✅ DO - Thin Models
```ruby
class Resource < ApplicationRecord
  include SoftDeletable
  include WebflowSyncable
  
  # Associations
  belongs_to :user
  has_many :items, dependent: :destroy
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  
  # Scopes
  scope :active, -> { where(deleted_at: nil) }
  scope :by_user, ->(user) { where(user: user) }
  
  # Enums
  enum status: { draft: 0, published: 1, archived: 2 }
  
  # Callbacks (minimal)
  before_validation :generate_slug, on: :create
  after_create :notify_creation
  
  private
  
  def generate_slug
    self.slug = "#{name.parameterize}-#{SecureRandom.hex(4)}"
  end
  
  def notify_creation
    ResourceCreationJob.perform_later(id)
  end
end
```

#### ❌ DON'T - Fat Models
```ruby
# Don't put business logic in models
class Resource < ApplicationRecord
  def calculate_complex_totals
    # 50+ lines of business logic
  end
  
  def sync_to_webflow
    # External API calls
  end
  
  def send_notifications
    # Email/message logic
  end
end
```

### Model Concerns

#### SoftDeletable Concern
```ruby
module SoftDeletable
  extend ActiveSupport::Concern
  
  included do
    scope :active, -> { where(deleted_at: nil) }
    scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
    scope :with_deleted, -> { unscoped }
  end
  
  def soft_delete!
    update!(deleted_at: Time.current)
  end
  
  def restore!
    update!(deleted_at: nil)
  end
  
  def deleted?
    deleted_at.present?
  end
  
  def active?
    deleted_at.nil?
  end
end
```

#### WebflowSyncable Concern
```ruby
module WebflowSyncable
  extend ActiveSupport::Concern
  
  included do
    attr_accessor :skip_webflow_sync
    
    after_commit :auto_sync_to_webflow, 
                 on: [:create, :update], 
                 if: :should_sync_to_webflow?
  end
  
  def webflow_formatted_data
    raise NotImplementedError, "Implement #webflow_formatted_data"
  end
  
  def webflow_collection_id
    raise NotImplementedError, "Implement #webflow_collection_id"
  end
  
  private
  
  def should_sync_to_webflow?
    !deleted? && 
    !skip_webflow_sync && 
    webflow_collection_id.present?
  end
  
  def auto_sync_to_webflow
    WebflowSyncJob.perform_later(self.class.name, id)
  end
end
```

---

## Controller Patterns

### Base Controller Structure

#### ✅ DO - Consistent API Controller
```ruby
class Api::V1::BaseController < ActionController::API
  include Pundit::Authorization
  include DeviseTokenAuth::Concerns::SetUserByToken
  
  before_action :authenticate_user!
  before_action :set_pagination_params
  
  rescue_from Pundit::NotAuthorizedError, with: :handle_authorization_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from StandardError, with: :handle_internal_error
  
  private
  
  def set_pagination_params
    @page = params[:page]&.to_i || 1
    @per_page = [params[:per_page]&.to_i || 20, 100].min
  end
  
  def handle_authorization_error(exception)
    render_error(
      message: "Access denied",
      details: exception.message,
      status: :forbidden
    )
  end
  
  def handle_not_found(exception)
    render_error(
      message: "Resource not found",
      status: :not_found
    )
  end
  
  def handle_internal_error(exception)
    Rails.logger.error "Internal error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render_error(
      message: "Internal server error",
      status: :internal_server_error
    )
  end
  
  def render_error(message:, details: nil, status: :unprocessable_entity)
    error_response = { error: message }
    error_response[:details] = details if details.present?
    
    render json: error_response, status: status
  end
  
  def render_success(data:, message: nil, meta: nil)
    response = { data: data }
    response[:message] = message if message.present?
    response[:meta] = meta if meta.present?
    
    render json: response
  end
end
```

### Resource Controller Pattern

#### ✅ DO - Clean Resource Controller
```ruby
class Api::V1::ResourcesController < Api::V1::BaseController
  before_action :set_resource, only: [:show, :update, :destroy]
  
  def index
    authorize Resource
    
    resources = policy_scope(Resource)
                .includes(:user)
                .page(@page)
                .per(@per_page)
    
    render_success(
      data: ResourceSerializer.new(resources).serializable_hash,
      meta: pagination_meta(resources)
    )
  end
  
  def show
    authorize @resource
    
    render_success(
      data: ResourceSerializer.new(@resource).serializable_hash
    )
  end
  
  def create
    authorize Resource
    
    service = Resource::CreationService.new(
      user: current_user,
      params: resource_params
    )
    
    result = service.call
    
    if result.success?
      render_success(
        data: ResourceSerializer.new(result.data).serializable_hash,
        message: "Resource created successfully"
      )
    else
      render_error(
        message: "Failed to create resource",
        details: result.errors
      )
    end
  end
  
  def update
    authorize @resource
    
    service = Resource::UpdateService.new(
      resource: @resource,
      params: resource_params
    )
    
    result = service.call
    
    if result.success?
      render_success(
        data: ResourceSerializer.new(result.data).serializable_hash,
        message: "Resource updated successfully"
      )
    else
      render_error(
        message: "Failed to update resource",
        details: result.errors
      )
    end
  end
  
  def destroy
    authorize @resource
    
    @resource.soft_delete!
    
    render_success(
      message: "Resource deleted successfully"
    )
  end
  
  private
  
  def set_resource
    @resource = Resource.find(params[:id])
  end
  
  def resource_params
    params.require(:resource).permit(
      :name, :description, :price, :status,
      items_attributes: [:id, :name, :price, :_destroy]
    )
  end
  
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value,
      has_next_page: collection.next_page.present?,
      has_prev_page: collection.prev_page.present?
    }
  end
end
```

---

## Service Layer

### Service Architecture

#### Application Service Base
```ruby
class ApplicationService
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attr_accessor :errors, :result
  
  def initialize(attributes = {})
    super
    @errors = []
    @result = nil
  end
  
  def call
    raise NotImplementedError, "Subclasses must implement #call method"
  end
  
  def success?
    errors.empty?
  end
  
  def failure?
    !success?
  end
  
  def add_error(message)
    errors << message
  end
  
  def add_errors(error_messages)
    errors.concat(Array(error_messages))
  end
  
  protected
  
  def with_error_handling
    yield
  rescue => e
    log_error("Unexpected error: #{e.message}")
    add_error(e.message)
    nil
  end
  
  def with_transaction(&block)
    ActiveRecord::Base.transaction(&block)
  end
  
  def log_info(message)
    Rails.logger.info "#{self.class.name}: #{message}"
  end
  
  def log_error(message)
    Rails.logger.error "#{self.class.name}: #{message}"
  end
end
```

### Domain Service Pattern

#### ✅ DO - Focused Service
```ruby
module Resource
  class CreationService < ApplicationService
    attribute :user
    attribute :params, default: -> { {} }
    
    def call
      with_error_handling do
        with_transaction do
          create_resource
          create_associated_items
          calculate_totals
        end
        
        trigger_webflow_sync if @resource.persisted?
        success_result
      end
    end
    
    private
    
    def create_resource
      @resource = user.resources.build(resource_attributes)
      
      unless @resource.save
        add_errors(@resource.errors.full_messages)
        return false
      end
      
      true
    end
    
    def create_associated_items
      return unless params[:items_attributes]
      
      params[:items_attributes].each do |item_attrs|
        next if item_attrs[:name].blank?
        
        item = @resource.items.build(
          name: item_attrs[:name],
          price: item_attrs[:price] || 0
        )
        
        unless item.save
          add_errors(item.errors.full_messages)
          raise ActiveRecord::Rollback
        end
      end
    end
    
    def calculate_totals
      @resource.calculate_totals!
    end
    
    def trigger_webflow_sync
      WebflowSyncJob.perform_later(@resource.class.name, @resource.id)
    end
    
    def resource_attributes
      {
        name: params[:name],
        description: params[:description],
        status: :draft
      }
    end
    
    def success_result
      { success: true, data: @resource }
    end
  end
end
```

---

## Webflow Integration

### Webflow Service Architecture

#### Base Webflow Service
```ruby
module Webflow
  class BaseService
    include HTTParty
    
    base_uri 'https://api.webflow.com/v2'
    
    def initialize
      @api_key = Rails.application.credentials.webflow[:api_key]
      @site_id = Rails.application.credentials.webflow[:site_id]
      
      raise "Webflow API key not configured" if @api_key.blank?
      raise "Webflow site ID not configured" if @site_id.blank?
    end
    
    private
    
    def headers
      {
        'Authorization' => "Bearer #{@api_key}",
        'accept-version' => '2.0.0',
        'Content-Type' => 'application/json'
      }
    end
    
    def make_request(method, path, options = {})
      options[:headers] = headers.merge(options[:headers] || {})
      
      response = self.class.send(method, path, options)
      
      case response.code
      when 200..299
        response.parsed_response
      when 429
        handle_rate_limit(response)
      else
        raise WebflowApiError.new(
          "Webflow API error: #{response.code}",
          response.code,
          response.body
        )
      end
    rescue HTTParty::Error => e
      raise WebflowApiError.new("Network error: #{e.message}")
    end
    
    def handle_rate_limit(response)
      retry_after = response.headers['Retry-After']&.to_i || 60
      sleep(retry_after)
      raise WebflowApiError.new("Rate limited, retry after #{retry_after} seconds")
    end
  end
end
```

#### Item Service
```ruby
module Webflow
  class ItemService < BaseService
    def list_items(collection_id, params = {})
      query_params = build_query_params(params)
      make_request(
        :get, 
        "/sites/#{@site_id}/collections/#{collection_id}/items/live#{query_params}"
      )
    end
    
    def get_item(collection_id, item_id)
      make_request(
        :get, 
        "/sites/#{@site_id}/collections/#{collection_id}/items/#{item_id}"
      )
    end
    
    def create_item(collection_id, item_data)
      make_request(
        :post, 
        "/sites/#{@site_id}/collections/#{collection_id}/items",
        body: item_data.to_json
      )
    end
    
    def update_item(collection_id, item_id, item_data)
      make_request(
        :patch, 
        "/sites/#{@site_id}/collections/#{collection_id}/items/#{item_id}",
        body: item_data.to_json
      )
    end
    
    def publish_items(collection_id, item_ids)
      make_request(
        :post, 
        "/collections/#{collection_id}/items/publish",
        body: { itemIds: item_ids }.to_json
      )
    end
    
    def unpublish_items(collection_id, item_ids)
      make_request(
        :delete, 
        "/collections/#{collection_id}/items/live",
        body: { items: item_ids.map { |id| { id: id } } }.to_json
      )
    end
    
    private
    
    def build_query_params(params)
      return "" if params.empty?
      
      "?" + params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
    end
  end
end
```

### Webflow Sync Job
```ruby
class WebflowSyncJob < ApplicationJob
  queue_as :webflow
  
  retry_on WebflowApiError, wait: :exponentially_longer, attempts: 3
  
  def perform(model_class, model_id)
    model = model_class.constantize.find(model_id)
    
    return unless model.respond_to?(:webflow_formatted_data)
    return if model.deleted?
    
    service = Webflow::ItemService.new
    
    if model.webflow_item_id.present?
      service.update_item(
        model.webflow_collection_id,
        model.webflow_item_id,
        model.webflow_formatted_data
      )
    else
      response = service.create_item(
        model.webflow_collection_id,
        model.webflow_formatted_data
      )
      
      model.update!(webflow_item_id: response['id'])
    end
    
  rescue WebflowApiError => e
    Rails.logger.error "Webflow sync failed for #{model_class}##{model_id}: #{e.message}"
    raise e
  end
end
```

### Webflow Webhook Handling
```ruby
class WebflowWebhookService < ApplicationService
  attribute :payload
  attribute :signature
  
  def call
    return failure_result("Invalid signature") unless valid_signature?
    
    case payload['trigger']
    when 'collection_item_published'
      handle_item_published
    when 'collection_item_unpublished'
      handle_item_unpublished
    else
      add_error("Unknown webhook trigger: #{payload['trigger']}")
    end
    
    success? ? success_result : failure_result
  end
  
  private
  
  def valid_signature?
    expected_signature = OpenSSL::HMAC.hexdigest(
      'sha256',
      Rails.application.credentials.webflow[:webhook_secret],
      payload.to_json
    )
    
    signature == expected_signature
  end
  
  def handle_item_published
    item_data = payload['data']
    model = find_model_by_webflow_id(item_data['id'])
    
    return unless model
    
    model.update!(
      webflow_item_id: item_data['id'],
      is_draft: false,
      last_published: Time.current
    )
  end
  
  def handle_item_unpublished
    item_data = payload['data']
    model = find_model_by_webflow_id(item_data['id'])
    
    return unless model
    
    model.update!(is_draft: true)
  end
  
  def find_model_by_webflow_id(webflow_id)
    # Implement based on your model structure
    Resource.find_by(webflow_item_id: webflow_id)
  end
end
```

---

## Testing Standards

### Test Structure
```
test/
├── models/
│   ├── concerns/
│   │   ├── soft_deletable_test.rb
│   │   └── webflow_syncable_test.rb
│   └── [model]_test.rb
├── controllers/
│   └── api/
│       └── v1/
│           └── [controller]_test.rb
├── services/
│   ├── [domain]/
│   │   └── [service]_test.rb
│   └── webflow/
│       └── [service]_test.rb
├── jobs/
│   └── webflow/
│       └── [job]_test.rb
├── policies/
│   └── [policy]_test.rb
└── fixtures/
    ├── users.yml
    └── [models].yml
```

### Model Testing
```ruby
require 'test_helper'

class ResourceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @resource = Resource.new(
      name: "Test Resource",
      user: @user
    )
  end
  
  test "should be valid with valid attributes" do
    assert @resource.valid?
  end
  
  test "should require name" do
    @resource.name = nil
    assert_not @resource.valid?
    assert_includes @resource.errors[:name], "can't be blank"
  end
  
  test "should belong to user" do
    assert_respond_to @resource, :user
    assert_equal @user, @resource.user
  end
  
  test "should generate slug on create" do
    @resource.save!
    assert_not_nil @resource.slug
    assert_match /\A[a-z0-9-]+\z/, @resource.slug
  end
  
  test "should soft delete" do
    @resource.save!
    @resource.soft_delete!
    
    assert @resource.deleted?
    assert_not_nil @resource.deleted_at
  end
  
  test "should restore" do
    @resource.save!
    @resource.soft_delete!
    @resource.restore!
    
    assert @resource.active?
    assert_nil @resource.deleted_at
  end
end
```

### Service Testing
```ruby
require 'test_helper'

class Resource::CreationServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @valid_params = {
      name: "Test Resource",
      description: "Test Description",
      items_attributes: [
        { name: "Item 1", price: 100 },
        { name: "Item 2", price: 200 }
      ]
    }
  end
  
  test "creates resource with valid params" do
    service = Resource::CreationService.new(
      user: @user,
      params: @valid_params
    )
    
    result = service.call
    
    assert result[:success]
    assert_equal "Test Resource", result[:data].name
    assert_equal 2, result[:data].items.count
  end
  
  test "calculates totals correctly" do
    service = Resource::CreationService.new(
      user: @user,
      params: @valid_params
    )
    
    result = service.call
    
    assert_equal 300.0, result[:data].total_amount
  end
  
  test "handles invalid params" do
    invalid_params = @valid_params.merge(name: "")
    
    service = Resource::CreationService.new(
      user: @user,
      params: invalid_params
    )
    
    result = service.call
    
    assert_not result[:success]
    assert_includes service.errors, "Name can't be blank"
  end
  
  test "rolls back on error" do
    # Mock an error during item creation
    Resource.any_instance.stubs(:save).returns(false)
    
    service = Resource::CreationService.new(
      user: @user,
      params: @valid_params
    )
    
    result = service.call
    
    assert_not result[:success]
    assert_equal 0, Resource.count
  end
end
```

### Controller Testing
```ruby
require 'test_helper'

class Api::V1::ResourcesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @auth_headers = auth_headers_for(@user)
    @resource = resources(:one)
  end
  
  test "should get index" do
    get api_v1_resources_path, headers: @auth_headers
    
    assert_response :success
    assert_not_nil json_response['data']
    assert_not_nil json_response['meta']
  end
  
  test "should create resource" do
    assert_difference('Resource.count') do
      post api_v1_resources_path, 
           params: { resource: { name: "New Resource" } },
           headers: @auth_headers
    end
    
    assert_response :success
    assert_equal "New Resource", json_response['data']['name']
  end
  
  test "should update resource" do
    patch api_v1_resource_path(@resource),
          params: { resource: { name: "Updated Name" } },
          headers: @auth_headers
    
    assert_response :success
    assert_equal "Updated Name", json_response['data']['name']
  end
  
  test "should soft delete resource" do
    assert_no_difference('Resource.count') do
      delete api_v1_resource_path(@resource), headers: @auth_headers
    end
    
    assert_response :success
    assert @resource.reload.deleted?
  end
  
  test "should require authentication" do
    get api_v1_resources_path
    
    assert_response :unauthorized
  end
  
  private
  
  def auth_headers_for(user)
    {
      'Authorization' => "Bearer #{user.auth_token}",
      'Content-Type' => 'application/json'
    }
  end
  
  def json_response
    JSON.parse(response.body)
  end
end
```

---

## Security Guidelines

### CORS Configuration
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Rails.application.credentials.allowed_origins
    
    resource '*',
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head],
             expose: ['access-token', 'expiry', 'token-type', 'uid', 'client']
  end
end
```

### Rate Limiting
```ruby
# Gemfile
gem 'rack-attack'

# config/initializers/rack_attack.rb
class Rack::Attack
  # Allow requests from localhost
  Rack::Attack.safelist('allow-localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip
  end
  
  # Rate limit API requests
  Rack::Attack.throttle('api/ip', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end
  
  # Rate limit authentication requests
  Rack::Attack.throttle('auth/ip', limit: 5, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/auth/')
  end
end
```

### Input Validation
```ruby
# app/controllers/concerns/input_validation.rb
module InputValidation
  extend ActiveSupport::Concern
  
  private
  
  def sanitize_params(params)
    params.each do |key, value|
      if value.is_a?(String)
        params[key] = value.strip
      elsif value.is_a?(Hash)
        sanitize_params(value)
      end
    end
  end
  
  def validate_file_upload(file)
    return false if file.blank?
    
    allowed_types = %w[image/jpeg image/png image/gif application/pdf]
    max_size = 10.megabytes
    
    unless allowed_types.include?(file.content_type)
      add_error("Invalid file type. Allowed: #{allowed_types.join(', ')}")
      return false
    end
    
    unless file.size <= max_size
      add_error("File too large. Maximum size: #{max_size / 1.megabyte}MB")
      return false
    end
    
    true
  end
end
```

---

## Performance Standards

### Database Optimization
```ruby
# Always use includes to prevent N+1 queries
def index
  @resources = Resource.includes(:user, :items)
                      .page(params[:page])
                      .per(params[:per_page])
end

# Use select to limit columns
def show
  @resource = Resource.select(:id, :name, :created_at)
                     .find(params[:id])
end

# Use counter_cache for associations
class Resource < ApplicationRecord
  belongs_to :user, counter_cache: true
end

class User < ApplicationRecord
  has_many :resources, dependent: :destroy
end
```

### Caching Strategy
```ruby
# Fragment caching
def show
  @resource = Resource.find(params[:id])
  
  render json: Rails.cache.fetch("resource/#{@resource.id}/#{@resource.updated_at.to_i}") do
    ResourceSerializer.new(@resource).serializable_hash
  end
end

# Query caching
def expensive_calculation
  Rails.cache.fetch("expensive_calculation/#{@resource.id}", expires_in: 1.hour) do
    # Expensive calculation
  end
end
```

### Background Job Optimization
```ruby
# Use appropriate queues
class WebflowSyncJob < ApplicationJob
  queue_as :webflow  # Separate queue for external API calls
end

class EmailNotificationJob < ApplicationJob
  queue_as :mailers  # Separate queue for emails
end

# Batch operations
class BulkUpdateJob < ApplicationJob
  def perform(resource_ids, updates)
    Resource.where(id: resource_ids).find_each do |resource|
      resource.update!(updates)
    end
  end
end
```

---

## Error Handling

### Custom Error Classes
```ruby
# app/errors/application_error.rb
class ApplicationError < StandardError
  attr_reader :code, :details
  
  def initialize(message, code: nil, details: nil)
    super(message)
    @code = code
    @details = details
  end
end

# app/errors/webflow_api_error.rb
class WebflowApiError < ApplicationError
  attr_reader :status_code, :response_body
  
  def initialize(message, status_code: nil, response_body: nil)
    super(message, code: 'WEBFLOW_API_ERROR')
    @status_code = status_code
    @response_body = response_body
  end
end
```

### Global Error Handling
```ruby
# app/controllers/concerns/error_handling.rb
module ErrorHandling
  extend ActiveSupport::Concern
  
  included do
    rescue_from ApplicationError, with: :handle_application_error
    rescue_from WebflowApiError, with: :handle_webflow_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
  end
  
  private
  
  def handle_application_error(exception)
    render_error(
      message: exception.message,
      code: exception.code,
      details: exception.details,
      status: :unprocessable_entity
    )
  end
  
  def handle_webflow_error(exception)
    Rails.logger.error "Webflow API Error: #{exception.message}"
    
    render_error(
      message: "External service temporarily unavailable",
      code: 'EXTERNAL_SERVICE_ERROR',
      status: :service_unavailable
    )
  end
  
  def handle_not_found(exception)
    render_error(
      message: "Resource not found",
      code: 'NOT_FOUND',
      status: :not_found
    )
  end
  
  def handle_unauthorized(exception)
    render_error(
      message: "Access denied",
      code: 'UNAUTHORIZED',
      status: :forbidden
    )
  end
end
```

---

## Code Quality

### RuboCop Configuration
```yaml
# .rubocop.yml
AllCops:
  TargetRubyVersion: 3.2
  NewCops: enable
  Exclude:
    - 'db/schema.rb'
    - 'db/migrate/*'
    - 'config/**/*'
    - 'vendor/**/*'

Style/Documentation:
  Enabled: false

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'
    - 'test/**/*'

Metrics/LineLength:
  Max: 120

Metrics/MethodLength:
  Max: 20

Metrics/ClassLength:
  Max: 150

Style/StringLiterals:
  EnforcedStyle: single_quotes

Style/FrozenStringLiteralComment:
  Enabled: true
```

### Code Review Checklist
- [ ] All database queries use proper includes/joins
- [ ] No N+1 query problems
- [ ] Proper error handling for all external API calls
- [ ] Input validation and sanitization
- [ ] Proper use of transactions
- [ ] Background jobs for long-running operations
- [ ] Proper logging for debugging
- [ ] Security considerations (CORS, rate limiting, etc.)
- [ ] Test coverage for new functionality
- [ ] Documentation for complex business logic

---

## Deployment & Configuration

### Environment Configuration
```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.load_defaults 8.0
    
    # API-only configuration
    config.api_only = true
    
    # CORS configuration
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins Rails.application.credentials.allowed_origins
        resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end
    
    # Active Job configuration
    config.active_job.queue_adapter = :solid_queue
    
    # Active Storage configuration
    config.active_storage.service = Rails.env.production? ? :amazon : :local
  end
end
```

### Credentials Management
```yaml
# config/credentials.yml.enc
webflow:
  api_key: your_webflow_api_key
  site_id: your_site_id
  webhook_secret: your_webhook_secret

database:
  url: your_database_url

allowed_origins:
  - https://yourdomain.com
  - https://staging.yourdomain.com
```

### Docker Configuration
```dockerfile
# Dockerfile
FROM ruby:3.2-alpine

RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    nodejs \
    yarn

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY package.json yarn.lock ./
RUN yarn install

COPY . .

RUN bundle exec rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

---

## Conclusion

This document provides comprehensive standards for building maintainable, scalable Ruby on Rails applications with Webflow integration. Follow these patterns consistently to avoid the architectural issues identified in the current codebase.

**Key Principles:**
1. **Separation of Concerns** - Keep models thin, controllers focused, services single-purpose
2. **Consistent Error Handling** - Standardized error responses and logging
3. **Security First** - Proper authentication, authorization, and input validation
4. **Performance Awareness** - Optimize database queries and use background jobs
5. **Test Coverage** - Comprehensive testing at all levels
6. **External API Resilience** - Proper error handling and retry mechanisms for Webflow integration

Remember: **Code is read more often than it's written.** Write for your future self and your team.
