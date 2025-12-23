# API Documentation

Complete API reference for the Go Microservices Platform.

## Table of Contents

- [Base URL](#base-url)
- [Authentication](#authentication)
- [Broker Service APIs](#broker-service-apis)
- [Authentication Service APIs](#authentication-service-apis)
- [Logger Service APIs](#logger-service-apis)
- [Mail Service APIs](#mail-service-apis)
- [Error Handling](#error-handling)
- [Status Codes](#status-codes)

---

## Base URL

**Development**: `http://localhost:8080`

**Production**: Update with your deployed URL

---

## Authentication

Currently, the platform uses basic authentication for the Authentication Service.

**Future Enhancement**: JWT token-based authentication will be added.

---

## Broker Service APIs

The Broker Service acts as an API Gateway, routing requests to appropriate microservices.

### Health Check

Check if the broker service is running.

**Endpoint**: `POST /`

**Request**:
```bash
curl -X POST http://localhost:8080
```

**Response**:
```json
{
  "error": false,
  "message": "Hit the Broker"
}
```

---

### Heartbeat

Health check endpoint using Chi middleware.

**Endpoint**: `GET /ping`

**Request**:
```bash
curl http://localhost:8080/ping
```

**Response**:
```
OK
```

---

### Handle Request

Main request handler that routes to different services based on the `action` field.

**Endpoint**: `POST /handle`

**Request Headers**:
```
Content-Type: application/json
```

**Supported Actions**:
- `auth`: Authenticate a user
- `log`: Create a log entry (via RPC)
- `mail`: Send an email

---

#### Action: Authentication

Authenticate a user with email and password.

**Request Body**:
```json
{
  "action": "auth",
  "auth": {
    "email": "admin@example.com",
    "password": "verysecret"
  }
}
```

**Example**:
```bash
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{
    "action": "auth",
    "auth": {
      "email": "admin@example.com",
      "password": "verysecret"
    }
  }'
```

**Success Response** (HTTP 202):
```json
{
  "error": false,
  "message": "Authenticated!",
  "data": {
    "id": 1,
    "email": "admin@example.com",
    "first_name": "Admin",
    "last_name": "User",
    "active": 1,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

**Error Response** (HTTP 401):
```json
{
  "error": true,
  "message": "Invalid credentials!!!"
}
```

---

#### Action: Logging

Create a log entry in the centralized logging system (via RPC).

**Request Body**:
```json
{
  "action": "log",
  "log": {
    "name": "event-name",
    "data": "Log message or data"
  }
}
```

**Example**:
```bash
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{
    "action": "log",
    "log": {
      "name": "user-login",
      "data": "User admin@example.com logged in successfully"
    }
  }'
```

**Success Response** (HTTP 202):
```json
{
  "error": false,
  "message": "Logged via RPC: Processing succeeded"
}
```

**Common Log Names**:
- `authentication`: User authentication events
- `error`: Error logging
- `info`: General information
- `warning`: Warning messages
- `audit`: Audit trail events

---

#### Action: Mail

Send an email via the mail service.

**Request Body**:
```json
{
  "action": "mail",
  "mail": {
    "from": "sender@example.com",
    "to": "recipient@example.com",
    "subject": "Email Subject",
    "message": "Email body content"
  }
}
```

**Example**:
```bash
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{
    "action": "mail",
    "mail": {
      "from": "noreply@example.com",
      "to": "user@example.com",
      "subject": "Welcome to Our Platform",
      "message": "Thank you for signing up!"
    }
  }'
```

**Success Response** (HTTP 202):
```json
{
  "error": false,
  "message": "Message sent to user@example.com"
}
```

**Error Response** (HTTP 500):
```json
{
  "error": true,
  "message": "Error calling mail service"
}
```

---

## Authentication Service APIs

Direct access to authentication service (typically called via Broker).

### Authenticate User

**Endpoint**: `POST http://authentication-service/authenticate`

**Note**: This is an internal service endpoint. Use the Broker's `/handle` endpoint with `action: "auth"` instead.

**Request Body**:
```json
{
  "email": "admin@example.com",
  "password": "verysecret"
}
```

**Success Response** (HTTP 202):
```json
{
  "error": false,
  "message": "Logged in user admin@example.com",
  "data": {
    "id": 1,
    "email": "admin@example.com",
    "first_name": "Admin",
    "last_name": "User",
    "active": 1,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

**Error Response** (HTTP 400):
```json
{
  "error": true,
  "message": "Invalid Credentials"
}
```

---

## Logger Service APIs

Direct access to logger service (typically called via Broker or RPC).

### Write Log Entry (HTTP)

**Endpoint**: `POST http://logger-service/log`

**Note**: This is an internal service endpoint. Use the Broker's `/handle` endpoint with `action: "log"` instead.

**Request Body**:
```json
{
  "name": "event-name",
  "data": "Log data or message"
}
```

**Success Response** (HTTP 202):
```json
{
  "error": false,
  "message": "logged"
}
```

---

### Write Log Entry (RPC)

**Protocol**: Go net/rpc over TCP

**Address**: `logger-service:5001`

**Method**: `RPCServer.LogInfo`

**Payload Structure**:
```go
type RPCPayload struct {
    Name string
    Data string
}
```

**Example (Go Client)**:
```go
client, err := rpc.Dial("tcp", "logger-service:5001")
if err != nil {
    log.Fatal(err)
}

payload := RPCPayload{
    Name: "event-name",
    Data: "Log message",
}

var result string
err = client.Call("RPCServer.LogInfo", payload, &result)
if err != nil {
    log.Fatal(err)
}

fmt.Println(result) // "Processing succeeded"
```

---

## Mail Service APIs

Direct access to mail service (typically called via Broker).

### Send Email

**Endpoint**: `POST http://mail-service/send`

**Note**: This is an internal service endpoint. Use the Broker's `/handle` endpoint with `action: "mail"` instead.

**Request Body**:
```json
{
  "from": "sender@example.com",
  "to": "recipient@example.com",
  "subject": "Email Subject",
  "message": "Email body content"
}
```

**Success Response** (HTTP 202):
```json
{
  "error": false,
  "message": "email sent to recipient@example.com"
}
```

**Error Response** (HTTP 500):
```json
{
  "error": true,
  "message": "error message details"
}
```

**Notes**:
- In development, emails are sent to MailHog (SMTP test server)
- View sent emails at: `http://localhost:8025`
- Configure production SMTP in environment variables

---

## Error Handling

All services return a consistent error response format:

```json
{
  "error": true,
  "message": "Human-readable error message"
}
```

### Common Error Messages

| Message | Meaning | Action |
|---------|---------|--------|
| `Invalid credentials!!!` | Wrong email/password | Check credentials |
| `Unknown action!!!` | Invalid action in request | Use: auth, log, or mail |
| `Error calling the Auth Service!!!` | Auth service unavailable | Check service health |
| `Error calling mail service` | Mail service unavailable | Check service health |
| `Invalid Credentials` | Authentication failed | Verify user exists and password is correct |

---

## Status Codes

The API uses standard HTTP status codes:

| Code | Meaning | Usage |
|------|---------|-------|
| **200** | OK | Successful GET requests |
| **202** | Accepted | Successful POST requests (async processing) |
| **400** | Bad Request | Invalid request format or parameters |
| **401** | Unauthorized | Authentication failed |
| **500** | Internal Server Error | Server-side error occurred |

---

## Rate Limiting

**Current**: No rate limiting implemented

**Future Enhancement**: Rate limiting will be added at the Broker level

---

## Request Examples

### Using cURL

```bash
# Test authentication
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{"action":"auth","auth":{"email":"admin@example.com","password":"verysecret"}}'

# Test logging
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{"action":"log","log":{"name":"test","data":"Test message"}}'

# Test email
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{"action":"mail","mail":{"from":"me@example.com","to":"you@example.com","subject":"Test","message":"Hello"}}'
```

### Using JavaScript (Fetch API)

```javascript
// Authentication
fetch('http://localhost:8080/handle', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    action: 'auth',
    auth: {
      email: 'admin@example.com',
      password: 'verysecret'
    }
  })
})
.then(res => res.json())
.then(data => console.log(data))
.catch(err => console.error(err));

// Logging
fetch('http://localhost:8080/handle', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    action: 'log',
    log: {
      name: 'user-action',
      data: 'User performed an action'
    }
  })
})
.then(res => res.json())
.then(data => console.log(data));

// Email
fetch('http://localhost:8080/handle', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    action: 'mail',
    mail: {
      from: 'sender@example.com',
      to: 'recipient@example.com',
      subject: 'Test Email',
      message: 'This is a test email'
    }
  })
})
.then(res => res.json())
.then(data => console.log(data));
```

### Using Postman

1. Create a new POST request to `http://localhost:8080/handle`
2. Set header: `Content-Type: application/json`
3. In the Body tab, select "raw" and "JSON"
4. Paste one of the request examples above
5. Click "Send"

---

## Event-Driven Architecture (RabbitMQ)

The platform also supports asynchronous event processing via RabbitMQ.

### Event Publishing

Events are published to RabbitMQ by the Broker Service for async processing.

**Exchange**: `logs_topic`
**Routing Keys**:
- `log.INFO`
- `log.WARNING`
- `log.ERROR`

**Event Payload Format**:
```json
{
  "name": "event-name",
  "data": "event-data"
}
```

### Event Consumption

The Listener Service consumes events and processes them asynchronously.

**Queue**: Bound to `logs_topic` exchange
**Processing**: Events are logged to the Logger Service

---

## Troubleshooting

### Service Not Responding

```bash
# Check if services are running
docker-compose ps

# View service logs
docker-compose logs -f broker-service
docker-compose logs -f authentication-service
```

### Database Connection Issues

```bash
# Check database containers
docker-compose logs -f postgres
docker-compose logs -f mongo

# Verify database is accessible
docker-compose exec postgres psql -U postgres -c "SELECT 1;"
docker-compose exec mongo mongosh --eval "db.runCommand({ ping: 1 })"
```

### RabbitMQ Connection Issues

```bash
# Check RabbitMQ logs
docker-compose logs -f rabbitmq

# Access RabbitMQ management UI (if enabled)
# http://localhost:15672 (guest/guest)
```

---

## Support

For issues or questions:
- Open an issue on GitHub
- Check existing documentation
- Review service logs for error details

---
