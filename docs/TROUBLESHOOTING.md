# Troubleshooting Guide

This guide helps you diagnose and fix common issues with the Go Microservices Platform.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Docker Compose Issues](#docker-compose-issues)
- [Service-Specific Issues](#service-specific-issues)
- [Database Issues](#database-issues)
- [RabbitMQ Issues](#rabbitmq-issues)
- [Network & Communication Issues](#network--communication-issues)
- [Kubernetes Issues](#kubernetes-issues)
- [Performance Issues](#performance-issues)

---

## Quick Diagnostics

### Check Service Status

```bash
# Check all services
docker-compose ps

# Check specific service logs
docker-compose logs -f broker-service
docker-compose logs -f authentication-service
docker-compose logs -f logger-service
docker-compose logs -f mail-service
docker-compose logs -f listener-service

# Check all logs
docker-compose logs -f
```

### Verify Service Health

```bash
# Test broker service
curl http://localhost:8080/ping

# Test authentication
curl -X POST http://localhost:8080/handle \
  -H "Content-Type: application/json" \
  -d '{"action":"auth","auth":{"email":"admin@example.com","password":"verysecret"}}'
```

### Check Resource Usage

```bash
# Check Docker resource usage
docker stats

# Check disk space
docker system df
```

---

## Docker Compose Issues

### Issue: Services Won't Start

**Symptoms:**
- `docker-compose up` fails
- Services exit immediately
- "Container exited with code 1"

**Solutions:**

1. **Check if ports are already in use:**
   ```bash
   # Check what's using port 8080
   lsof -i :8080

   # Kill the process or change port in docker-compose.yml
   kill -9 <PID>
   ```

2. **Rebuild containers:**
   ```bash
   docker-compose down -v
   docker-compose up --build -d
   ```

3. **Check logs for specific errors:**
   ```bash
   docker-compose logs broker-service
   ```

4. **Verify Docker resources:**
   ```bash
   # Increase Docker memory/CPU in Docker Desktop settings
   # Minimum: 4GB RAM, 2 CPUs
   ```

### Issue: "Cannot connect to Docker daemon"

**Solution:**
```bash
# Start Docker Desktop (macOS/Windows)
# Or start Docker service (Linux)
sudo systemctl start docker

# Verify Docker is running
docker ps
```

### Issue: Containers Keep Restarting

**Check dependency issues:**
```bash
# View restart count
docker-compose ps

# Check if databases are ready before services start
# Services should have depends_on in docker-compose.yml
```

**Add health checks to docker-compose.yml:**
```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### Issue: "Volume mount failed"

**Solution:**
```bash
# On Windows/Mac, ensure Docker Desktop has file sharing enabled
# Settings > Resources > File Sharing

# Remove old volumes and recreate
docker-compose down -v
docker-compose up -d
```

---

## Service-Specific Issues

### Broker Service Issues

**Issue: "Connection refused" to other services**

**Solution:**
```bash
# Check if dependent services are running
docker-compose ps | grep -E "authentication|logger|mail"

# Verify service URLs in broker-service code
# Should use service names: http://authentication-service:80
```

**Issue: RabbitMQ connection failed**

```bash
# Check RabbitMQ is running
docker-compose logs rabbitmq

# Verify connection string
# Should be: amqp://guest:guest@rabbitmq:5672/

# Restart services in order
docker-compose restart rabbitmq
docker-compose restart broker-service
```

### Authentication Service Issues

**Issue: Database connection failed**

```bash
# Check PostgreSQL is running
docker-compose logs postgres

# Verify DSN format
# DSN=host=postgres port=5432 user=postgres password=password dbname=users sslmode=disable

# Test PostgreSQL connection
docker-compose exec postgres psql -U postgres -c "SELECT 1;"

# Check if users table exists
docker-compose exec postgres psql -U postgres -d users -c "\dt"
```

**Issue: "Invalid credentials" for default user**

**Solution:**
```bash
# Check if default user exists
docker-compose exec postgres psql -U postgres -d users -c "SELECT * FROM users;"

# If no users, recreate database
docker-compose down -v
docker-compose up -d postgres
# Wait for postgres to be ready, then start auth service
docker-compose up -d authentication-service
```

### Logger Service Issues

**Issue: MongoDB connection failed**

```bash
# Check MongoDB status
docker-compose logs mongo

# Test connection
docker-compose exec mongo mongosh --eval "db.adminCommand('ping')"

# Verify connection string
# mongodb://admin:password@mongo:27017

# Check credentials
docker-compose exec mongo mongosh -u admin -p password --authenticationDatabase admin
```

**Issue: RPC server not responding**

```bash
# Check if RPC port is exposed
docker-compose ps | grep logger-service

# Verify port 5001 is listening
docker-compose exec logger-service netstat -an | grep 5001

# Check RPC server logs
docker-compose logs logger-service | grep RPC
```

### Mail Service Issues

**Issue: Emails not being sent**

**Solution:**
```bash
# Check MailHog is running
docker-compose ps | grep mailhog

# Access MailHog web UI
open http://localhost:8025

# Check mail service logs
docker-compose logs mail-service

# Verify SMTP configuration
# MAIL_HOST=mailhog
# MAIL_PORT=1025
```

**Issue: "Connection refused" to SMTP server**

```bash
# Restart MailHog
docker-compose restart mailhog

# Wait a few seconds
sleep 5

# Restart mail service
docker-compose restart mail-service
```

### Listener Service Issues

**Issue: Not consuming messages from RabbitMQ**

```bash
# Check RabbitMQ connections
docker-compose exec rabbitmq rabbitmqctl list_connections

# Check queues
docker-compose exec rabbitmq rabbitmqctl list_queues

# Verify listener service is running
docker-compose logs listener-service

# Check RabbitMQ management UI
open http://localhost:15672
# Login: guest / guest
```

---

## Database Issues

### PostgreSQL Issues

**Issue: Database doesn't exist**

```bash
# Create database manually
docker-compose exec postgres psql -U postgres -c "CREATE DATABASE users;"

# Or recreate with volume reset
docker-compose down -v
docker-compose up -d postgres
```

**Issue: Permission denied**

```bash
# Check user permissions
docker-compose exec postgres psql -U postgres -d users -c "\du"

# Grant permissions if needed
docker-compose exec postgres psql -U postgres -d users -c "GRANT ALL PRIVILEGES ON DATABASE users TO postgres;"
```

**Issue: Too many connections**

```bash
# Check current connections
docker-compose exec postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Increase max_connections in docker-compose.yml
postgres:
  command: postgres -c max_connections=200
```

### MongoDB Issues

**Issue: Authentication failed**

```bash
# Check MongoDB authentication
docker-compose exec mongo mongosh --eval "db.adminCommand({ listDatabases: 1 })"

# Reset MongoDB with correct credentials
docker-compose down -v
# Update MONGO_INITDB_ROOT_USERNAME and MONGO_INITDB_ROOT_PASSWORD in .env
docker-compose up -d mongo
```

**Issue: Disk space full**

```bash
# Check MongoDB disk usage
docker-compose exec mongo du -sh /data/db

# Prune old logs (if log retention is implemented)
docker-compose exec mongo mongosh logs --eval "db.log_entries.deleteMany({created_at: {\$lt: new Date(Date.now() - 90*24*60*60*1000)}})"

# Clean up Docker system
docker system prune -a --volumes
```

---

## RabbitMQ Issues

### Issue: Management UI not accessible

```bash
# Check if management plugin is enabled
docker-compose exec rabbitmq rabbitmq-plugins list

# Enable management plugin
docker-compose exec rabbitmq rabbitmq-plugins enable rabbitmq_management

# Restart RabbitMQ
docker-compose restart rabbitmq

# Access UI at http://localhost:15672
# Default credentials: guest/guest
```

### Issue: Messages not being consumed

**Check queue status:**
```bash
# List queues and message counts
docker-compose exec rabbitmq rabbitmqctl list_queues name messages consumers

# Check if listener service is connected
docker-compose logs listener-service | grep -i "connected\|error"
```

**Purge queue if needed:**
```bash
docker-compose exec rabbitmq rabbitmqctl purge_queue <queue-name>
```

### Issue: Connection limit reached

```bash
# Check connection limit
docker-compose exec rabbitmq rabbitmqctl status | grep connection

# Increase connection limit in docker-compose.yml
rabbitmq:
  environment:
    - RABBITMQ_MAX_CONNECTIONS=1000
```

---

## Network & Communication Issues

### Issue: Services can't communicate

**Check Docker network:**
```bash
# List networks
docker network ls

# Inspect network
docker network inspect go-microservices-platform_default

# Verify services are on same network
docker-compose ps
```

**Test connectivity:**
```bash
# From broker to auth service
docker-compose exec broker-service ping authentication-service

# From broker to logger service
docker-compose exec broker-service nc -zv logger-service 80
```

### Issue: CORS errors in frontend

**Solution:**
Update CORS settings in broker-service:
```go
// Enable CORS
c := cors.New(cors.Options{
    AllowedOrigins: []string{"https://*", "http://*"},
    AllowCredentials: true,
})
```

### Issue: Timeout errors

**Increase timeouts:**
```go
client := &http.Client{
    Timeout: 30 * time.Second, // Increase from default
}
```

---

## Kubernetes Issues

### Issue: Pods not starting

```bash
# Check pod status
kubectl get pods

# Describe pod for details
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Issue: ImagePullBackOff

```bash
# Check image name and registry
kubectl describe pod <pod-name> | grep Image

# Verify image exists
docker pull <image-name>

# Update deployment with correct image
kubectl set image deployment/<deployment-name> <container-name>=<correct-image>
```

### Issue: CrashLoopBackOff

```bash
# Check logs for crash reason
kubectl logs <pod-name> --previous

# Check liveness/readiness probes
kubectl describe pod <pod-name> | grep -A5 Liveness

# Adjust probe settings if needed
kubectl edit deployment <deployment-name>
```

### Issue: Service not accessible

```bash
# Check service
kubectl get svc

# Check endpoints
kubectl get endpoints

# Test service connectivity
kubectl run test --rm -it --image=busybox -- wget -O- http://<service-name>
```

---

## Performance Issues

### Issue: High CPU usage

```bash
# Check resource usage
docker stats

# Profile Go services
# Add pprof endpoint in service code
import _ "net/http/pprof"

# Access profile at http://localhost:6060/debug/pprof/
```

### Issue: High memory usage

```bash
# Check for memory leaks
docker stats

# Enable memory profiling
go test -memprofile=mem.out
go tool pprof mem.out
```

### Issue: Slow database queries

**MongoDB:**
```bash
# Enable profiling
docker-compose exec mongo mongosh logs --eval "db.setProfilingLevel(2)"

# Check slow queries
docker-compose exec mongo mongosh logs --eval "db.system.profile.find().limit(10).sort({ts:-1}).pretty()"

# Add indexes
docker-compose exec mongo mongosh logs --eval "db.log_entries.createIndex({created_at: -1})"
```

**PostgreSQL:**
```bash
# Check slow queries
docker-compose exec postgres psql -U postgres -d users -c "SELECT query, calls, total_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

---

## Common Error Messages

### "dial tcp: lookup authentication-service: no such host"

**Cause:** Service name resolution failed
**Solution:** Ensure services are on the same Docker network

### "connection refused"

**Cause:** Target service not ready or wrong port
**Solution:** Check service health and wait for it to start

### "context deadline exceeded"

**Cause:** Request timeout
**Solution:** Increase timeout or check service performance

### "bind: address already in use"

**Cause:** Port conflict
**Solution:** Stop process using the port or change port mapping

---

## Getting More Help

1. **Enable debug logging:**
   ```bash
   # Set LOG_LEVEL=debug in .env
   docker-compose down
   docker-compose up -d
   ```

2. **Check GitHub issues:**
   - Search existing issues
   - Create new issue with full details

3. **Collect diagnostic information:**
   ```bash
   # System info
   docker version
   docker-compose version
   go version

   # Service status
   docker-compose ps

   # Recent logs
   docker-compose logs --tail=100
   ```

4. **Reset everything (last resort):**
   ```bash
   docker-compose down -v
   docker system prune -a
   docker-compose up --build -d
   ```

---

## Prevention Tips

1. **Always check logs first**
2. **Use health checks in production**
3. **Monitor resource usage**
4. **Keep services updated**
5. **Backup databases regularly**
6. **Test changes in development first**
7. **Use proper error handling in code**

---

For additional help, refer to:
- [README.md](../README.md)
- [API Documentation](./API.md)
- [Architecture Documentation](./ARCHITECTURE.md)
- [Deployment Guide](./DEPLOYMENT.md)
