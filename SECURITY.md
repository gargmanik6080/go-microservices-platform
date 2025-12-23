# Security Policy

## Supported Versions

Currently supported versions for security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

---

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do NOT** open a public GitHub issue
2. Email the maintainers with details
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We aim to respond within 48 hours and provide a fix within 7 days for critical issues.

---

## Security Best Practices

### For Development

1. **Environment Variables**
   - Never commit `.env` files to version control
   - Use `.env.example` as a template only
   - Keep sensitive credentials out of code

2. **Default Credentials**
   - Change all default passwords before deployment
   - Use strong, unique passwords for databases
   - Rotate credentials regularly

3. **Dependencies**
   - Keep Go modules up to date: `go get -u ./...`
   - Regularly scan for vulnerabilities: `go list -json -m all | nancy sleuth`
   - Review dependency changes before updating

### For Production Deployment

#### 1. Authentication & Authorization

**Current State:**
- Basic password authentication with bcrypt hashing
- No JWT implementation yet

**Recommendations:**
- Implement JWT token-based authentication
- Add role-based access control (RBAC)
- Enable multi-factor authentication (MFA)
- Set session timeouts

**Example JWT Implementation:**
```go
import "github.com/golang-jwt/jwt/v5"

func GenerateJWT(userID int, secret string) (string, error) {
    claims := jwt.MapClaims{
        "user_id": userID,
        "exp":     time.Now().Add(24 * time.Hour).Unix(),
    }
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(secret))
}
```

#### 2. Database Security

**PostgreSQL:**
```bash
# Use strong passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Enable SSL connections
sslmode=require

# Limit connection sources
# In pg_hba.conf: host all all 10.0.0.0/8 md5

# Regular backups with encryption
pg_dump -U postgres users | gpg -c > backup.sql.gpg
```

**MongoDB:**
```bash
# Strong passwords
MONGO_PASSWORD=$(openssl rand -base64 32)

# Enable authentication
--auth

# Use network encryption
--tlsMode requireTLS

# Limit network access
bind_ip = 127.0.0.1,10.0.0.1
```

#### 3. API Security

**Rate Limiting:**
```go
import "golang.org/x/time/rate"

limiter := rate.NewLimiter(rate.Limit(10), 100) // 10 req/sec, burst of 100

func rateLimitMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if !limiter.Allow() {
            http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

**Input Validation:**
```go
import "github.com/go-playground/validator/v10"

type LoginRequest struct {
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"password" validate:"required,min=8"`
}

func validateInput(req LoginRequest) error {
    validate := validator.New()
    return validate.Struct(req)
}
```

**CORS Configuration:**
```go
// Don't use wildcards in production
cors.New(cors.Options{
    AllowedOrigins: []string{"https://yourdomain.com"},
    AllowedMethods: []string{"GET", "POST", "PUT", "DELETE"},
    AllowedHeaders: []string{"Authorization", "Content-Type"},
    AllowCredentials: true,
    MaxAge: 300,
})
```

#### 4. TLS/SSL Configuration

**Enable HTTPS:**
```go
// Use Let's Encrypt for free SSL certificates
func main() {
    certManager := autocert.Manager{
        Prompt:     autocert.AcceptTOS,
        HostPolicy: autocert.HostWhitelist("yourdomain.com"),
        Cache:      autocert.DirCache("/var/www/.cache"),
    }

    server := &http.Server{
        Addr:         ":443",
        Handler:      router,
        TLSConfig:    &tls.Config{GetCertificate: certManager.GetCertificate},
    }

    log.Fatal(server.ListenAndServeTLS("", ""))
}
```

**For Kubernetes:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - api.yourdomain.com
    secretName: tls-secret
```

#### 5. Secrets Management

**Kubernetes Secrets:**
```bash
# Create secrets
kubectl create secret generic db-credentials \
  --from-literal=postgres-password=$(openssl rand -base64 32) \
  --from-literal=mongo-password=$(openssl rand -base64 32)

# Use in deployments
env:
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: postgres-password
```

**External Secrets Management:**
- Use HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager

#### 6. Container Security

**Dockerfile Best Practices:**
```dockerfile
# Use specific versions, not 'latest'
FROM golang:1.22-alpine AS builder

# Run as non-root user
RUN adduser -D -u 1000 appuser
USER appuser

# Use multi-stage builds
FROM alpine:3.19
COPY --from=builder /app/service .

# Scan for vulnerabilities
RUN apk add --no-cache ca-certificates
```

**Scan images:**
```bash
# Trivy scanner
trivy image yourusername/broker-service:latest

# Docker scan
docker scan yourusername/broker-service:latest
```

#### 7. Network Security

**Kubernetes Network Policies:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: broker-policy
spec:
  podSelector:
    matchLabels:
      app: broker-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
```

**Firewall Rules:**
- Only expose necessary ports
- Use VPN for admin access
- Implement IP whitelisting for sensitive endpoints

#### 8. Logging & Monitoring

**Security Event Logging:**
```go
// Log authentication attempts
log.Printf("[SECURITY] Failed login attempt: email=%s, ip=%s", email, r.RemoteAddr)

// Log suspicious activity
log.Printf("[SECURITY] Multiple failed attempts: email=%s, count=%d", email, failCount)

// Log admin actions
log.Printf("[AUDIT] Admin action: user=%s, action=%s", userID, action)
```

**Set up alerts:**
- Failed authentication attempts
- Unusual traffic patterns
- Resource exhaustion
- Unauthorized access attempts

#### 9. RabbitMQ Security

```bash
# Change default credentials
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=$(openssl rand -base64 32)

# Enable SSL/TLS
RABBITMQ_SSL_CERTFILE=/path/to/cert.pem
RABBITMQ_SSL_KEYFILE=/path/to/key.pem

# Limit permissions
rabbitmqctl set_permissions -p / broker_user ".*" ".*" ".*"
```

#### 10. Email Security

**Prevent Email Injection:**
```go
func sanitizeEmail(email string) string {
    // Remove newlines and special characters
    email = strings.ReplaceAll(email, "\n", "")
    email = strings.ReplaceAll(email, "\r", "")
    return email
}
```

**Use SPF, DKIM, DMARC:**
```
# DNS records
yourdomain.com. IN TXT "v=spf1 include:_spf.google.com ~all"
yourdomain.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:admin@yourdomain.com"
```

---

## Security Checklist

### Pre-Deployment

- [ ] All default passwords changed
- [ ] Environment variables properly configured
- [ ] Secrets stored securely (not in code)
- [ ] Dependencies updated and scanned
- [ ] Input validation implemented
- [ ] Rate limiting enabled
- [ ] CORS properly configured
- [ ] TLS/SSL certificates configured

### Production

- [ ] HTTPS enabled on all external endpoints
- [ ] Database connections encrypted
- [ ] Strong password policies enforced
- [ ] JWT authentication implemented
- [ ] Logging and monitoring active
- [ ] Firewall rules configured
- [ ] Regular security audits scheduled
- [ ] Incident response plan documented
- [ ] Backup and recovery tested

### Ongoing

- [ ] Regular dependency updates
- [ ] Security patch monitoring
- [ ] Log analysis and alerting
- [ ] Access control reviews
- [ ] Penetration testing (annual)
- [ ] Security training for team

---

## Common Vulnerabilities & Prevention

### SQL Injection
**Prevention:** Use parameterized queries
```go
// Good
db.Query("SELECT * FROM users WHERE email = $1", email)

// Bad
db.Query(fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email))
```

### NoSQL Injection
**Prevention:** Validate and sanitize input
```go
filter := bson.M{"email": email} // Good - uses BSON
// Never use string concatenation for queries
```

### Cross-Site Scripting (XSS)
**Prevention:** Escape output, use Content Security Policy
```go
import "html/template"
tmpl.Execute(w, template.HTMLEscapeString(userInput))
```

### Command Injection
**Prevention:** Avoid shell commands, use Go functions
```go
// Bad
exec.Command("sh", "-c", fmt.Sprintf("echo %s", userInput))

// Good
// Don't execute user input directly
```

### Path Traversal
**Prevention:** Validate file paths
```go
import "path/filepath"

func secureFilePath(userPath string) (string, error) {
    cleaned := filepath.Clean(userPath)
    if strings.Contains(cleaned, "..") {
        return "", errors.New("invalid path")
    }
    return cleaned, nil
}
```

---

## Incident Response

If a security breach occurs:

1. **Immediate Actions:**
   - Isolate affected systems
   - Preserve evidence (logs, snapshots)
   - Assess scope of breach

2. **Investigation:**
   - Review logs and audit trails
   - Identify entry point
   - Determine data exposure

3. **Remediation:**
   - Patch vulnerabilities
   - Rotate all credentials
   - Update security measures

4. **Communication:**
   - Notify affected users
   - Report to authorities if required
   - Document lessons learned

---

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Go Security Best Practices](https://github.com/guardrailsio/awesome-golang-security)
- [Docker Security](https://docs.docker.com/engine/security/)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)

---

## Updates

This security policy is reviewed and updated regularly. Last updated: 2024-12-23
