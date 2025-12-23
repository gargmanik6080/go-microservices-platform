# Architecture Documentation

## System Overview

The Go Microservices Platform is a distributed system built on microservices architecture principles, implementing multiple communication patterns and modern cloud-native design patterns.

## Table of Contents

- [Design Principles](#design-principles)
- [System Architecture](#system-architecture)
- [Communication Patterns](#communication-patterns)
- [Service Descriptions](#service-descriptions)
- [Data Flow](#data-flow)
- [Database Architecture](#database-architecture)
- [Message Queue Design](#message-queue-design)
- [Security Architecture](#security-architecture)
- [Scalability & Performance](#scalability--performance)
- [Fault Tolerance](#fault-tolerance)

---

## Design Principles

### 1. Single Responsibility
Each service has a well-defined, focused responsibility:
- **Authentication Service**: User authentication only
- **Logger Service**: Centralized logging only
- **Mail Service**: Email sending only
- **Broker Service**: Request routing and orchestration

### 2. Loose Coupling
Services communicate via well-defined interfaces:
- REST APIs for external communication
- RPC for internal high-performance calls
- Message queues for asynchronous operations

### 3. High Cohesion
Related functionality is grouped within services:
- User management and authentication logic in Auth Service
- All logging functionality in Logger Service
- Email templates and sending logic in Mail Service

### 4. Autonomy
Each service can:
- Be deployed independently
- Scale independently
- Fail without cascading failures
- Use its own database/storage

### 5. API Gateway Pattern
Broker Service acts as a single entry point:
- Simplifies client communication
- Centralizes cross-cutting concerns
- Provides unified API interface

---

## System Architecture

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         Client Layer                          │
│                 (Frontend, Mobile, External)                  │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                      API Gateway Layer                        │
│                      (Broker Service)                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  • Request routing                                      │  │
│  │  • Protocol translation (REST → REST/RPC)              │  │
│  │  • Event publishing                                     │  │
│  │  • Response aggregation                                 │  │
│  └────────────────────────────────────────────────────────┘  │
└──────┬──────────────┬───────────────┬────────────┬───────────┘
       │              │               │            │
       ▼              ▼               ▼            ▼
┌─────────────┐ ┌──────────┐ ┌───────────┐ ┌──────────────┐
│Authentication│ │  Logger  │ │   Mail    │ │   Message    │
│   Service    │ │  Service │ │  Service  │ │    Queue     │
│              │ │          │ │           │ │  (RabbitMQ)  │
│  • REST API  │ │ • REST   │ │ • REST    │ │              │
│              │ │ • RPC    │ │           │ │  • Pub/Sub   │
└──────┬───────┘ └─────┬────┘ └─────┬─────┘ └──────┬───────┘
       │               │            │              │
       ▼               ▼            ▼              ▼
┌──────────────┐ ┌──────────┐ ┌─────────┐ ┌──────────────┐
│  PostgreSQL  │ │  MongoDB │ │ MailHog │ │   Listener   │
│  (Users DB)  │ │(Logs DB) │ │  (SMTP) │ │   Service    │
└──────────────┘ └──────────┘ └─────────┘ └──────────────┘
```

### Component Layers

#### 1. Presentation Layer
- **Frontend Service**: Web UI for testing and demonstration
- **External Clients**: Mobile apps, third-party integrations

#### 2. API Gateway Layer
- **Broker Service**: Single entry point, request routing, orchestration

#### 3. Business Logic Layer
- **Authentication Service**: User authentication and authorization
- **Logger Service**: Centralized logging and audit trails
- **Mail Service**: Email notifications and communications
- **Listener Service**: Asynchronous event processing

#### 4. Data Layer
- **PostgreSQL**: Relational data (users, auth)
- **MongoDB**: Document storage (logs, events)
- **RabbitMQ**: Message queue for async communication

---

## Communication Patterns

### 1. Synchronous REST Communication

**Use Case**: Client-initiated operations requiring immediate response

```
Client → Broker → Service → Response
```

**Example**: User authentication
```http
POST /handle
{
  "action": "auth",
  "auth": {
    "email": "user@example.com",
    "password": "secret"
  }
}
```

**Characteristics**:
- HTTP/1.1 with JSON payloads
- Request-Response pattern
- Timeout: 30 seconds
- Error handling: HTTP status codes

### 2. RPC Communication

**Use Case**: High-frequency, low-latency internal service calls

```
Broker → RPC Client → TCP → RPC Server (Logger)
```

**Example**: Logging via RPC
```go
client.Call("RPCServer.LogInfo", payload, &result)
```

**Characteristics**:
- Go's net/rpc over TCP
- Binary protocol (more efficient than JSON)
- Port: 5001 (Logger Service)
- Timeout: 5 seconds

**Advantages**:
- Lower latency than REST
- Smaller payload size
- Type safety
- Better performance for internal calls

### 3. Event-Driven (Message Queue)

**Use Case**: Asynchronous operations, decoupling services

```
Service → RabbitMQ (Publish) → Queue → Listener (Consume) → Process
```

**Example**: Async log processing
```
Broker publishes → logs_topic exchange → Listener consumes → Logger stores
```

**Characteristics**:
- RabbitMQ AMQP protocol
- Topic exchange with routing keys
- Durable queues
- Acknowledgment-based delivery

**Message Flow**:
```
1. Producer publishes to exchange
2. Exchange routes to queues (based on routing key)
3. Consumer receives message
4. Consumer processes message
5. Consumer acknowledges (or rejects)
```

---

## Service Descriptions

### Broker Service (API Gateway)

**Responsibilities**:
- Receive all external requests
- Route requests to appropriate services
- Aggregate responses
- Publish events to message queue
- Handle CORS and security headers

**Endpoints**:
- `POST /` - Health check
- `GET /ping` - Heartbeat
- `POST /handle` - Main request handler

**Internal Architecture**:
```go
handlers.go
  ├── Broker()           // Health check
  ├── HandleSubmission() // Main handler
  ├── authenticate()     // Auth routing
  ├── logItemViaRPC()    // Logger RPC call
  └── sendMail()         // Mail routing

event/
  └── emitter.go         // RabbitMQ event publishing
```

**Dependencies**:
- Authentication Service (REST)
- Logger Service (RPC)
- Mail Service (REST)
- RabbitMQ (AMQP)

### Authentication Service

**Responsibilities**:
- User authentication
- Password hashing (bcrypt)
- User data management
- Session validation (future: JWT)

**Endpoints**:
- `POST /authenticate` - User login

**Internal Architecture**:
```go
cmd/api/
  ├── handlers.go    // HTTP handlers
  └── routes.go      // Route definitions

data/
  └── models.go      // User model, DB operations
```

**Database Schema (PostgreSQL)**:
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  password VARCHAR(255) NOT NULL,
  user_active INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Logger Service

**Responsibilities**:
- Centralized log storage
- Log retrieval and querying
- Support for multiple protocols (REST, RPC)
- Distributed tracing support

**Endpoints**:
- `POST /log` - Write log entry (HTTP)
- `RPCServer.LogInfo` - Write log entry (RPC)

**Internal Architecture**:
```go
cmd/api/
  ├── handlers.go    // HTTP handlers
  ├── rpc.go         // RPC server
  └── routes.go      // Route definitions

data/
  └── models.go      // Log model, MongoDB ops
```

**Database Schema (MongoDB)**:
```javascript
{
  _id: ObjectId,
  name: String,        // Event name
  data: String,        // Log data
  created_at: Date
}
```

### Mail Service

**Responsibilities**:
- Email composition and sending
- Template management (future)
- SMTP integration
- Email delivery tracking (future)

**Endpoints**:
- `POST /send` - Send email

**SMTP Configuration**:
- Development: MailHog (localhost:1025)
- Production: Configurable SMTP server

### Listener Service

**Responsibilities**:
- Consume events from RabbitMQ
- Process log events asynchronously
- Background job execution
- Event-driven workflows

**Internal Architecture**:
```go
event/
  └── consumer.go      // RabbitMQ consumer
```

**Message Processing**:
1. Connect to RabbitMQ
2. Declare exchange and queue
3. Bind queue to exchange
4. Consume messages
5. Process events
6. Acknowledge or reject

---

## Data Flow

### Authentication Flow

```
1. Client sends credentials
   ↓
2. Broker receives POST /handle (action: "auth")
   ↓
3. Broker forwards to Auth Service
   ↓
4. Auth Service queries PostgreSQL
   ↓
5. Auth Service validates password (bcrypt)
   ↓
6. Auth Service returns user data
   ↓
7. Broker returns response to client
```

### Logging Flow (RPC)

```
1. Client requests log creation
   ↓
2. Broker receives POST /handle (action: "log")
   ↓
3. Broker establishes RPC connection (TCP:5001)
   ↓
4. Broker calls RPCServer.LogInfo
   ↓
5. Logger Service writes to MongoDB
   ↓
6. Logger Service returns success
   ↓
7. Broker returns response to client
```

### Email Flow

```
1. Client requests email send
   ↓
2. Broker receives POST /handle (action: "mail")
   ↓
3. Broker forwards to Mail Service (HTTP)
   ↓
4. Mail Service connects to SMTP (MailHog/Production)
   ↓
5. Mail Service sends email
   ↓
6. Mail Service returns success
   ↓
7. Broker returns response to client
```

### Event-Driven Flow

```
1. Broker publishes event to RabbitMQ
   ↓
2. Event reaches "logs_topic" exchange
   ↓
3. Exchange routes to bound queue
   ↓
4. Listener Service consumes event
   ↓
5. Listener processes event
   ↓
6. Listener sends to Logger Service
   ↓
7. Logger stores in MongoDB
   ↓
8. Listener acknowledges message
```

---

## Database Architecture

### PostgreSQL (Authentication)

**Purpose**: Store relational user data

**Connection**:
```go
dsn := "host=postgres port=5432 user=postgres password=password dbname=users"
db, err := sql.Open("postgres", dsn)
```

**Connection Pool**:
- Max Open Connections: 25
- Max Idle Connections: 25
- Max Lifetime: 5 minutes

**Tables**:
- `users`: User accounts and credentials

### MongoDB (Logging)

**Purpose**: Store unstructured log data

**Connection**:
```go
mongoURL := "mongodb://mongo:27017"
client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURL))
```

**Collections**:
- `logs`: Log entries with timestamps

**Advantages**:
- Schema-less design
- Fast writes
- Horizontal scalability
- JSON-like documents

---

## Message Queue Design

### RabbitMQ Architecture

**Exchange Type**: Topic Exchange (`logs_topic`)

**Routing Keys**:
- `log.INFO`
- `log.WARNING`
- `log.ERROR`

**Queue Configuration**:
```go
Queue: auto-generated name
Durable: true
Auto-delete: false
Exclusive: false
```

**Message Format**:
```json
{
  "name": "event-name",
  "data": "event-data"
}
```

**Consumer Configuration**:
- Auto-Ack: true
- Prefetch: 1
- Exclusive: false

---

## Security Architecture

### Current Implementation

1. **Database Credentials**: Environment variables
2. **Password Storage**: bcrypt hashing
3. **CORS**: Enabled for frontend access
4. **Input Validation**: JSON schema validation

### Future Enhancements

1. **JWT Authentication**:
   ```
   Login → JWT Token → Token in headers → Validate → Access
   ```

2. **API Keys**: For service-to-service authentication

3. **TLS/SSL**: Encrypt communication in transit

4. **Secrets Management**: HashiCorp Vault, AWS Secrets Manager

5. **Rate Limiting**: Prevent abuse

---

## Scalability & Performance

### Horizontal Scaling

Each service can scale independently:

```
Load Balancer
    ├── Broker 1
    ├── Broker 2
    └── Broker 3
         ├── Auth 1, Auth 2
         ├── Logger 1, Logger 2
         └── Mail 1, Mail 2
```

**Kubernetes Deployment**:
```yaml
replicas: 3  # Multiple instances
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Performance Optimizations

1. **RPC for Internal Calls**: Lower latency than REST
2. **Connection Pooling**: Database connection reuse
3. **Message Queue**: Async processing, non-blocking
4. **Caching** (Future): Redis for frequently accessed data

### Load Testing Targets

- **Throughput**: 1000 req/sec per service
- **Latency**: p95 < 100ms, p99 < 500ms
- **Availability**: 99.9% uptime

---

## Fault Tolerance

### Retry Logic

**Database Connections**:
```go
for i := 0; i < 5; i++ {
    conn, err := connectToDB()
    if err == nil {
        return conn
    }
    time.Sleep(2 * time.Second)
}
```

**RabbitMQ Connections**:
- Automatic reconnection
- Exponential backoff
- Max retry attempts: 5

### Circuit Breaker Pattern (Future)

```
Closed → Normal operation
  ↓ (failures exceed threshold)
Open → Reject requests immediately
  ↓ (after timeout)
Half-Open → Test with limited requests
  ↓ (if successful)
Closed
```

### Health Checks

All services expose `/ping` endpoint:
```go
r.Get("/ping", func(w http.ResponseWriter, r *http.Request) {
    w.Write([]byte("OK"))
})
```

### Graceful Degradation

If a service fails:
- **Logger Down**: Continue operation, log locally
- **Mail Down**: Queue emails for later
- **Auth Down**: Return cached session data

---

## Design Patterns Used

1. **API Gateway**: Broker Service
2. **Service Registry** (Future): Service discovery
3. **Circuit Breaker** (Future): Fault tolerance
4. **Event Sourcing**: Message queue logging
5. **CQRS** (Partial): Separate read/write operations
6. **Saga Pattern** (Future): Distributed transactions

---

## Technology Decisions

### Why Go?
- High performance
- Built-in concurrency (goroutines)
- Strong standard library
- Fast compilation
- Small binary size

### Why Chi Router?
- Lightweight (no bloat)
- Idiomatic Go code
- Composable middleware
- Context-aware

### Why RabbitMQ?
- Mature and stable
- Multiple messaging patterns
- High throughput
- Easy clustering

### Why PostgreSQL + MongoDB?
- **PostgreSQL**: ACID compliance for users
- **MongoDB**: Flexible schema for logs

---

## Monitoring & Observability (Future)

### Metrics (Prometheus)
- Request rate
- Error rate
- Response time
- Resource utilization

### Logging (Centralized)
- Structured logging (JSON)
- Correlation IDs for tracing
- Log aggregation (ELK stack)

### Tracing (Jaeger/Zipkin)
- Distributed tracing
- Request flow visualization
- Performance bottleneck identification

---

## References

- [Microservices Patterns](https://microservices.io/patterns/index.html)
- [The Twelve-Factor App](https://12factor.net/)
- [Go Best Practices](https://golang.org/doc/effective_go)
- [RabbitMQ Tutorials](https://www.rabbitmq.com/getstarted.html)
