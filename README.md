# Bullet Services

A Ruby on Rails API backend for managing glass repair quotations, with user authentication (Devise Token Auth), image uploads, and integration with Webflow CMS. Designed for use with a React Native frontend.

## Table of Contents

- [Requirements](#requirements)
- [Setup](#setup)
- [Configuration](#configuration)
- [Database](#database)
- [Running the App](#running-the-app)
- [Testing](#testing)
- [Services](#services)
- [Deployment](#deployment)
- [API Endpoints](#api-endpoints)
- [User Roles](#user-roles)
- [Image Upload](#image-upload)
- [Webflow Integration](#webflow-integration)
- [License](#license)

---

## Requirements

- Ruby 3.2.x (or compatible)
- Rails 7.x
- PostgreSQL
- Node.js & Yarn (for JS dependencies)
- Bundler

## Setup

1. **Clone the repository:**

    ```bash
    git clone https://github.com/yourusername/glass_quotes_api.git
    cd glass_quotes_api
    ```

2. **Install dependencies:**

    ```bash
    bundle install
    yarn install
    ```

3. **Set up environment variables and credentials:**

   Edit Rails credentials for Webflow API keys and collection ID:

    ```bash
    EDITOR="code --wait" rails credentials:edit
    ```

   Add:

    ```yaml
    webflow_api_key: your_webflow_api_key
    webflow_collection_id: your_webflow_collection_id
    ```

## Configuration

- **CORS:** Configured via `config/initializers/cors.rb` to allow requests from your frontend.
- **Devise Token Auth:** Handles user authentication and roles (`admin`, `employee`, `client`).
- **Active Storage:** For image uploads (local or S3, configurable).

## Database

1. **Create and migrate the database:**

    ```bash
    rails db:create
    rails db:migrate
    ```

2. **(Optional) Seed initial data:**

    ```bash
    rails db:seed
    ```

## Running the App

Start the Rails API server:

```bash
rails server
```

The API will be available at `http://localhost:3000`.

## Testing

To run the test suite (RSpec or Minitest, depending on your setup):

```bash
rails test
# or, if using RSpec
rspec
```

## Services

- **User Authentication:** [Devise Token Auth](https://github.com/lynndylanhurley/devise_token_auth)
- **Image Uploads:** [Active Storage](https://edgeguides.rubyonrails.org/active_storage_overview.html)
- **Webflow CMS Integration:** [Webflow API](https://developers.webflow.com/)
- **Background Jobs:** [Active Job](https://guides.rubyonrails.org/active_job_basics.html) (for sending data to Webflow)
- **API Documentation:** (Add link if using Swagger, Rswag, etc.)

## Deployment

- Recommended platforms: [Heroku](https://devcenter.heroku.com/categories/ruby-support), [Render](https://render.com/), AWS, DigitalOcean.
- Set environment variables for production (Webflow API keys, database credentials, etc.).
- Run migrations on deploy:

    ```bash
    rails db:migrate
    ```

## API Endpoints

### Authentication

- `POST /auth/sign_in` — User login
- `POST /auth` — User registration
- `DELETE /auth/sign_out` — User logout

### Quotations

- `GET /api/v1/quotations` — List quotations (filtered by user role)
- `POST /api/v1/quotations` — Create quotation (with images)
- `GET /api/v1/quotations/:id` — Show quotation details
- `PUT /api/v1/quotations/:id` — Update quotation
- `DELETE /api/v1/quotations/:id` — Delete quotation
- `POST /api/v1/quotations/:id/send_to_webflow` — Send quotation to Webflow

### Users

- `GET /api/v1/users/:id` — Show user profile
- `PUT /api/v1/users/:id` — Update user profile
- `PATCH /api/v1/users/:id/update_role` — Update user role (admin only)

## User Roles

- **Admin:** Full access to all quotations and user management
- **Employee:** Can create, edit, and manage quotations
- **Client:** Can view only their own quotations

## Image Upload

Images are handled via Active Storage and can be configured for:

- Local storage (development)
- AWS S3 (production)
- Google Cloud Storage
- Azure Storage

## Webflow Integration

The API automatically syncs quotation data to your Webflow CMS collection when:

- A new quotation is created
- Manual sync is triggered via the `/send_to_webflow` endpoint

## License

MIT
```

Let me know if you want to add or change anything![object Object]
```