### FreshBooks `invoice.update` Webhook – Baby Steps Guide

This walks you through, step‑by‑step, how to get from zero to “FreshBooks hits our webhook and we reconcile that invoice in Bullet”.

---

## 1. Prerequisites

1. **Have a FreshBooks app & OAuth set up**
   - You should already have:
     - `FRESHBOOKS_CLIENT_ID`
     - `FRESHBOOKS_CLIENT_SECRET`
     - `FRESHBOOKS_REDIRECT_URI`
   - Tokens are managed via `FreshbooksToken` and the rake tasks in `lib/tasks/freshbooks.rake`.

2. **Have your Rails app running on a public URL**
   - Production: `https://bulletservices.co.uk`

3. **Know your webhook callback URL**
   - In this app the route is:

     ```text
     POST /api/v1/webhooks/freshbooks
     ```

   - Final URL example:
     - `https://bulletservices.co.uk/api/v1/webhooks/freshbooks`  

---

## 2. Configure environment variables

1. Open your environment config (e.g. `.env`, Heroku config, etc.).
2. Ensure the **core FreshBooks envs** are set:

   ```bash
   FRESHBOOKS_CLIENT_ID=...
   FRESHBOOKS_CLIENT_SECRET=...
   FRESHBOOKS_REDIRECT_URI=https://bulletservices.co.uk/freshbooks/callback
   ```

3. Ensure the **business ID and access tokens** are set OR stored in `FreshbooksToken`:

   ```bash
   FRESHBOOKS_ACCESS_TOKEN=...     # optional if using DB token
   FRESHBOOKS_REFRESH_TOKEN=...    # optional if using DB token
   FRESHBOOKS_BUSINESS_ID=...
   ```

4. For now, **leave `FRESHBOOKS_WEBHOOK_SECRET` empty**; we’ll fill it after FreshBooks sends the verification code.

   ```bash
   FRESHBOOKS_WEBHOOK_SECRET=
   ```

5. Restart your Rails server so the initializer `config/initializers/freshbooks.rb` picks up the envs.

---

## 3. Verify OAuth / connectivity (optional but recommended)

1. Run the config check:

   ```bash
   bundle exec rake freshbooks:verify_config
   ```

2. Run the connection test:

   ```bash
   bundle exec rake freshbooks:test
   ```

3. Confirm:
   - No errors are printed.
   - A small number of clients is returned (just to prove API connectivity).

---

## 4. Decide on your webhook URL

1. Decide which URL you’ll give to FreshBooks, e.g.:

   - Production: `https://bulletservices.co.uk/api/v1/webhooks/freshbooks`

2. Keep this URL handy; we’ll pass it to rake as `WEBHOOK_URL`.

---

## 5. Register the `invoice.update` webhook (and friends)

This app already has a helper rake task: `freshbooks:webhooks:register_all`.

1. From the project root, run:

   ```bash
   WEBHOOK_URL=https://bulletservices.co.uk/api/v1/webhooks/freshbooks \
   bundle exec rake freshbooks:webhooks:register_all
   ```

2. Watch the output:
   - It will attempt to register:

     ```text
     payment.create
     payment.update
     invoice.create
     invoice.update
     ```

   - For each event you should see something like:

    ```text
    Registering invoice.update...
      ✅ Registered (ID: 2001)
    ```

3. At the end you’ll get a **Summary** listing each event and whether it’s **Verified** or **Pending**.

---

## 6. Handle FreshBooks’ webhook verification

When you create a webhook, FreshBooks sends a **verification request** to your callback URL with:

- A `verifier` (verification code)
- A `callbackid`/`id` (callback ID)

This app already has logic to help:

- Controller: `Api::V1::FreshbooksWebhooksController#create`
- Concern: `FreshbooksWebhookVerification`

### 6.1. Capture the verification code

1. Make sure your Rails server logs are visible (tail the logs).

2. When FreshBooks sends the verification POST, you’ll see log lines like:

   ```text
   FreshBooks webhook verification request received
     Callback ID: 2001
     Verification code: present
   ```

3. You need the **verification code** (the `verifier` value) from that request.

   - You can see it:
     - In Rails logs (if you log params)
     - Or by temporarily:
       - Adding local logging around `params[:verifier]`, or

4. Once you know the verification code, set it as `FRESHBOOKS_WEBHOOK_SECRET`:

   ```bash
   FRESHBOOKS_WEBHOOK_SECRET=scADVVi5QuKuj5qTjVkbJNYQe7V7USpGd
   ```

5. Restart your Rails server so the new secret is loaded.

> This secret is later used to verify all incoming webhooks via `X-FreshBooks-Hmac-SHA256`.

---

## 7. Confirm webhooks are registered

1. List webhooks with the rake task:

   ```bash
   bundle exec rake freshbooks:webhooks:list
   ```

2. You should see entries similar to:

   ```text
   Registered Webhooks:

     ID: 2001
     Event: invoice.update
     URL: https://bulletservices.co.uk/api/v1/webhooks/freshbooks
     Status: Verified
   ```

3. If status is still **Pending Verification**:
   - Ensure your server handled the verification request.
   - Use the manual verify task (if needed):

     ```bash
     bundle exec rake freshbooks:webhooks:verify[CALLBACK_ID,VERIFICATION_CODE]
     ```

---

## 8. What happens when `invoice.update` fires (runtime flow)

Once everything above is set:

1. A change happens in FreshBooks (e.g. invoice marked **Paid**).
2. FreshBooks sends a webhook:

   - `name=invoice.update`
   - `object_id=<invoice_id>`
   - `account_id=...`
   - `business_id=...`
   - Header `X-FreshBooks-Hmac-SHA256=<signature>`

3. Rails receives the POST at:

   ```text
   POST /api/v1/webhooks/freshbooks
   ```

   and runs `Api::V1::FreshbooksWebhooksController#create`:

   - If request contains `verifier` / `verification_code` → verification flow.
   - Otherwise:
     - It calls `verify_webhook_signature` (HMAC check) using `FRESHBOOKS_WEBHOOK_SECRET`.
     - It calls `process_webhook_event`.

4. `process_webhook_event`:

   - Reads the event type (`invoice.update`) and `object_id` (invoice ID).
   - For `invoice.update` it calls:

     ```ruby
     handle_invoice_webhook_by_id(object_id)
     ```

5. `handle_invoice_webhook_by_id` (in `FreshbooksWebhookHandling` concern):

   - Enqueues a background job:

     ```ruby
     Freshbooks::SyncInvoicesJob.perform_later(invoice_id)
     ```

   - Logs: `Invoice webhook enqueued for sync: <invoice_id>`.
   - Returns quickly so the webhook responds fast (minimal risk of timeout).

6. `Freshbooks::SyncInvoicesJob` runs:

   - Fetches the invoice JSON via the FreshBooks API.
   - `find_or_initialize_by(freshbooks_id: invoice_id)` on `FreshbooksInvoice`.
   - Updates all invoice attributes (status, amounts, dates, etc.).
   - Calls `Freshbooks::InvoiceLifecycleService` to:
     - Reconcile payments.
     - Propagate status to the local `Invoice` record.

7. Any code reading `Invoice` or `FreshbooksInvoice` now sees the **reconciled, current state**.

---

## 9. Testing the flow safely

### 9.1. Manual job trigger

1. Take a known FreshBooks invoice ID, e.g. `1234567`.
2. Run:

   ```bash
   bundle exec rails console
   ```

3. Inside console:

   ```ruby
   Freshbooks::SyncInvoicesJob.perform_now(1234567)
   ```

4. Verify:
   - `FreshbooksInvoice.find_by(freshbooks_id: 1234567)` exists.
   - Its `status`, `amount_outstanding`, etc., match FreshBooks.
   - If linked, the corresponding `Invoice` record’s status is updated.

### 9.2. Simulate a webhook request (locally)

1. With your Rails server running, send a POST (without worrying about signature at first):

   ```bash
   curl -X POST http://localhost:3000/api/v1/webhooks/freshbooks \
     -d "name=invoice.update" \
     -d "object_id=1234567"
   ```

2. For quick tests, you can temporarily:

   - Comment out or tweak `verify_webhook_signature` to always return `true` on development, **or**
   - Set a dummy `FRESHBOOKS_WEBHOOK_SECRET` and compute a matching signature in a small script.

3. Confirm:
   - Logs show `FreshBooks webhook received: invoice.update`.
   - Logs show `Invoice webhook enqueued for sync: 1234567`.
   - The job runs and `FreshbooksInvoice` / `Invoice` are updated as expected.

---

## 10. How this ties into the mobile app

Once the above is in place, the React Native app doesn’t need to know about webhooks directly:

1. The mobile app calls existing invoice APIs (e.g. `GET /api/v1/invoices/:id`).
2. Because webhooks keep `Invoice` and `FreshbooksInvoice` in sync:
   - Status (`paid`, `voided`, etc.) will be **updated shortly after any FreshBooks change**.
3. Best practice:
   - Refresh invoice data:
     - On screen focus.
     - On pull‑to‑refresh.
   - Use simple status chips / labels that reflect `Invoice.status`.

No extra complexity on the client: the server’s webhook + jobs keep everything current.

---

This is the full “baby steps” path from configuration → registration → verification → runtime behavior → testing → mobile impact.

