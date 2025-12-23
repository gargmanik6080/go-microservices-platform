# Go Microservices Platform

A production-ready microservices platform built with Go, demonstrating modern distributed systems architecture with event-driven communication, containerization, and orchestration capabilities.

![Go Version](https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat&logo=go)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat&logo=docker)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Ready-326CE5?style=flat&logo=kubernetes)
![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Services](#services)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [API Documentation](#api-documentation)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This platform showcases a complete microservices ecosystem with:
- **Multiple independent services** communicating via REST, RPC, and message queues
- **Event-driven architecture** using RabbitMQ for asynchronous processing
- **Centralized logging** with MongoDB for distributed tracing
- **JWT-based authentication** with PostgreSQL user management
- **Containerized deployment** with Docker and Kubernetes support
- **API Gateway pattern** for unified service access

Perfect for learning microservices architecture, distributed systems design, and modern DevOps practices.

## 🏗️ Architecture

```
┌─────────────┐
│   Frontend  │ (Port 8081)
│  (Go HTML)  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│                     Broker Service                          │
│              (API Gateway - Port 8080)                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Routes: /handle (POST)                             │    │
│  │  • Authentication requests → Auth Service           │    │
│  │  • Logging requests → Logger Service (RPC)          │    │
│  │  • Email requests → Mail Service                    │    │
│  │  • Event publishing → RabbitMQ                      │    │
│  └─────────────────────────────────────────────────────┘    │
└────┬────────────┬─────────────┬────────────┬────────────────┘
     │            │             │            │
     ▼            ▼             ▼            ▼
┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐
│  Auth   │ │  Logger  │ │   Mail   │ │  RabbitMQ    │
│ Service │ │ Service  │ │ Service  │ │  (Message    │
│         │ │          │ │          │ │   Queue)     │
│  Port:  │ │ Port: 80 │ │ Port: 80 │ │  Port: 5672  │
│   80    │ │ RPC:5001 │ │          │ │              │
└────┬────┘ └─────┬────┘ └─────┬────┘ └──────┬───────┘
     │            │            │             │
     ▼            ▼            ▼             ▼
┌──────────┐ ┌─────────┐  ┌─────────┐  ┌──────────┐
│PostgreSQL│ │ MongoDB │  │ MailHog │  │ Listener │
│  (Users) │ │ (Logs)  │  │  (SMTP) │  │ Service  │
│Port: 5432│ │Port:    │  │Port:1025│  │ (Event   │
│          │ │  27017  │  │Web: 8025│  │Consumer) │
└──────────┘ └─────────┘  └─────────┘  └──────────┘
```

## 🚀 Services

### 1. **Broker Service** (API Gateway)
- **Port**: 8080
- **Purpose**: Central entry point for all client requests
- **Responsibilities**:
  - Request routing to appropriate microservices
  - Load distribution and service orchestration
  - Event publishing to message queue
- **Communication**: REST API, RPC, RabbitMQ

### 2. **Authentication Service**
- **Port**: 80 (internal)
- **Purpose**: User authentication and authorization
- **Responsibilities**:
  - User login/registration
  - Password hashing and validation
  - JWT token management (future enhancement)
- **Database**: PostgreSQL
- **Communication**: REST API

### 3. **Logger Service**
- **Port**: 80 (REST), 5001 (RPC)
- **Purpose**: Centralized logging for all services
- **Responsibilities**:
  - Log entry storage and retrieval
  - Distributed tracing support
  - Audit trail management
- **Database**: MongoDB
- **Communication**: REST API, RPC

### 4. **Mail Service**
- **Port**: 80 (internal)
- **Purpose**: Email notification handling
- **Responsibilities**:
  - Email composition and sending
  - Template management
  - SMTP integration
- **External Service**: MailHog (development SMTP server)
- **Communication**: REST API

### 5. **Listener Service**
- **Purpose**: Asynchronous event processing
- **Responsibilities**:
  - Consuming messages from RabbitMQ
  - Processing log events
  - Background job execution
- **Communication**: RabbitMQ consumer

### 6. **Frontend Service**
- **Port**: 8081
- **Purpose**: Web UI for testing microservices
- **Tech**: Go HTML templates with embedded JavaScript
- **Features**: Service testing interface

## 🛠️ Tech Stack

### Backend
- **Language**: Go 1.22+
- **Routing**: Chi Router (lightweight, composable)
- **Communication**:
  - REST (JSON over HTTP)
  - RPC (net/rpc for low-latency calls)
  - Message Queue (RabbitMQ for async events)

### Databases
- **PostgreSQL 14**: Relational data (users, authentication)
- **MongoDB 8.2**: Document store (logs, events)

### Message Queue
- **RabbitMQ 4.2**: Event-driven communication and async processing

### DevOps
- **Docker**: Containerization
- **Docker Compose**: Local development orchestration
- **Kubernetes**: Production deployment (manifests in `/k8s`)
- **Makefile**: Build automation

### External Services
- **MailHog**: SMTP testing server (development)

## ✨ Features

✅ **Microservices Architecture**
- Independent, loosely-coupled services
- Single responsibility principle
- Scalable and maintainable

✅ **Multiple Communication Patterns**
- RESTful APIs for standard operations
- RPC for low-latency internal calls
- Event-driven messaging for async workflows

✅ **Data Persistence**
- PostgreSQL for relational data
- MongoDB for unstructured logs
- Connection pooling and retry logic

✅ **Event-Driven Design**
- RabbitMQ message queue integration
- Pub/sub pattern implementation
- Async event processing

✅ **Containerization**
- Docker images for all services
- Docker Compose for local development
- Kubernetes-ready manifests

✅ **Production-Ready Patterns**
- Centralized logging
- Health check endpoints (`/ping`)
- CORS configuration
- Graceful error handling
- Connection retry with exponential backoff

## 📦 Prerequisites

- **Go** 1.22 or higher
- **Docker** 20.10+
- **Docker Compose** 2.0+
- **Make** (optional, for convenience commands)

For Kubernetes deployment:
- **kubectl** 1.24+
- **Minikube** or cloud Kubernetes cluster

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/go-microservices-platform.git
cd go-microservices-platform
```

### 2. Configure Environment Variables (Optional)
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your configurations (optional for development)
# The default values work out of the box with Docker Compose
```

### 3. Start All Services
```bash
# Start all services with Docker Compose
make up_build

# Or without Make:
docker-compose up --build -d
```

This will start:
- Broker Service on `localhost:8080`
- Authentication Service (internal)
- Logger Service (internal)
- Mail Service (internal)
- Listener Service (background)
- PostgreSQL on `localhost:5432`
- MongoDB on `localhost:27017`
- RabbitMQ on `localhost:5672`
- MailHog UI on `localhost:8025`

### 4. Start Frontend (Optional)
```bash
make start

# Or manually:
cd frontend
go build -o frontApp ./cmd/web
./frontApp
```

Frontend will be available at `http://localhost:8081`

### 5. Test the Services

**Using Frontend:**
- Navigate to `http://localhost:8081`
- Click buttons to test each service

**Using cURL:**
```bash
# Test Broker
curl -X POST http://localhost:8080

# Test Authentication
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{
    "action": "auth",
    "auth": {
      "email": "admin@example.com",
      "password": "verysecret"
    }
  }'

# Test Logging
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{
    "action": "log",
    "log": {
      "name": "test-event",
      "data": "Test log message"
    }
  }'

# Test Mail
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{
    "action": "mail",
    "mail": {
      "from": "sender@example.com",
      "to": "recipient@example.com",
      "subject": "Test Email",
      "message": "This is a test email"
    }
  }'
```

### 6. Stop Services
```bash
make down

# Or:
docker-compose down
```

## 📚 API Documentation

See [API.md](./docs/API.md) for complete endpoint documentation.

**Quick Reference:**

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Health check for broker |
| GET | `/ping` | Heartbeat endpoint |
| POST | `/handle` | Main request handler (see payload formats) |

**Payload Actions:**
- `auth`: Authenticate user
- `log`: Create log entry (via RPC)
- `mail`: Send email

For detailed request/response formats, see [API.md](./docs/API.md).

## 💻 Development

### Project Structure
```
.
├── authentication-service/
│   ├── cmd/api/          # HTTP handlers and routes
│   └── data/             # Database models
├── broker-service/
│   ├── cmd/api/          # Main API logic
│   └── event/            # RabbitMQ producer
├── logger-service/
│   ├── cmd/api/          # HTTP and RPC handlers
│   └── data/             # MongoDB models
├── mail-service/
│   └── cmd/api/          # Email handling
├── listener-service/
│   └── event/            # RabbitMQ consumer
├── frontend/
│   └── cmd/web/          # Web UI
├── k8s/                  # Kubernetes manifests
├── docker-compose.yml    # Local development
└── Makefile              # Build scripts
```

### Build Individual Services
```bash
# Build broker
make build_broker

# Build authentication service
make build_auth

# Build logger service
make build_logger

# Build mail service
make build_mailer

# Build listener service
make build_listener

# Build frontend
make build_front
```

### Environment Variables

Each service uses environment variables for configuration. See [.env.example](./.env.example) files in each service directory.

**Key Variables:**
- `DSN`: Database connection string (PostgreSQL)
- `MONGO_URL`: MongoDB connection string
- `BROKER_URL`: Broker service URL
- `MAIL_*`: SMTP configuration

## 🧪 Testing

### Run All Tests
```bash
# Run tests for all services
cd authentication-service && go test ./...
cd ../broker-service && go test ./...
cd ../logger-service && go test ./...
cd ../mail-service && go test ./...
```

### Manual Testing
1. Use the frontend UI at `http://localhost:8081`
2. Check MailHog for emails: `http://localhost:8025`
3. Monitor logs: `docker-compose logs -f [service-name]`

## 🚢 Deployment

### Docker Compose (Development)
```bash
make up_build
```

### Kubernetes (Production)

1. **Build and push images** (update image registry):
```bash
docker build -t yourregistry/broker-service:latest ./broker-service
docker push yourregistry/broker-service:latest
# Repeat for other services
```

2. **Update Kubernetes manifests** in `/k8s/` with your image names

3. **Deploy to cluster**:
```bash
kubectl apply -f k8s/
```

4. **Verify deployment**:
```bash
kubectl get pods
kubectl get services
```

### Production Considerations

- [ ] Add TLS/SSL certificates
- [ ] Configure ingress controller
- [ ] Set up secrets management (not hardcoded)
- [ ] Implement health checks
- [ ] Add monitoring (Prometheus/Grafana)
- [ ] Configure auto-scaling
- [ ] Set up CI/CD pipeline
- [ ] Add rate limiting
- [ ] Implement JWT authentication
- [ ] Add request logging and tracing

## 🙏 Acknowledgments

Built as a learning project to demonstrate microservices architecture patterns and modern Go development practices.
