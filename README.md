<div align="center">

  <img src="https://raw.githubusercontent.com/DANG-PH/DANG-PH/main/go-trans.png" alt="Go Gopher" width="100"/>

  <h1>Golang Base</h1>

  <p>A minimal, production-ready Go project core — the skeleton every service starts from.</p>

  <p>
    <a href="https://golang.org/"><img src="https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat&logo=go" alt="Go Version"/></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"/></a>
    <a href="https://github.com/DANG-PH/golang-base/stargazers"><img src="https://img.shields.io/github/stars/DANG-PH/golang-base?style=flat&color=yellow" alt="Stars"/></a>
    <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"/></a>
    <a href="https://goreportcard.com/report/github.com/DANG-PH/golang-base"><img src="https://goreportcard.com/badge/github.com/DANG-PH/golang-base?v=2" alt="Go Report Card"/></a>
  </p>

  <p>
    <a href="#-philosophy">Philosophy</a> •
    <a href="#-structure">Structure</a> •
    <a href="#-whats-included">What's Included</a> •
    <a href="#-extension-rules">Extension Rules</a> •
    <a href="#-getting-started">Getting Started</a> •
    <a href="#%EF%B8%8F-makefile-commands">Makefile</a> •
    <a href="#-contributing">Contributing</a>
  </p>

</div>

---

## 💡 Philosophy

This is the **minimum shared core** for every Go service — nothing more, nothing less.

No web framework. No ORM. No business logic. Those get added per service based on actual requirements. The only goal here is a clean starting point with a clear structural direction, without dictating tech stack choices.

> Clone it. Add dependencies. Ship the service.

---

## 📁 Structure

```
golang-base/
│
├── cmd/
│   └── api/
│       └── main.go                    # Entry point — where everything gets wired together
│
├── internal/
│   ├── config/
│   │   └── config.go                  # Load and validate env config
│   │
│   ├── app/
│   │   └── app.go                     # Bootstrap — initialize and run the app
│   │
│   ├── transport/                     # Inbound — the world calling into us
│   │   ├── http/
│   │   │   ├── server.go              # HTTP server lifecycle, timeouts, graceful shutdown
│   │   │   ├── router.go              # Route registration
│   │   │   └── middleware/
│   │   │       ├── logger.go          # Log method, path, status, latency per request
│   │   │       └── recovery.go        # Catch panics, return 500 instead of crashing
│   │   │
│   │   ├── grpc/                      # gRPC server — receive RPCs from other services
│   │   │   ├── server.go              # gRPC server setup, TLS, interceptor chain
│   │   │   └── interceptor/
│   │   │       └── logger.go          # Log interceptor
│   │   │
│   │   └── consumer/                  # Receive messages from a broker (RabbitMQ, Kafka, NATS)
│   │       └── handler.go             # Deserialize message, delegate to service
│   │
│   ├── external/                      # Outbound — us calling out
│   │   ├── client/                    # Sync calls — call and wait for response
│   │   │   └── example.go             # gRPC/HTTP client → external service
│   │   └── messaging/                 # Async calls — publish and forget
│   │       ├── publisher.go           # Publish messages to a queue/topic
│   │       └── messages.go            # Message type definitions
│   │
│   ├── shared/                        # Add only when multiple domains share something
│   │   ├── enums.go                   # OrderStatus, PaymentStatus, Role...
│   │   ├── types.go                   # UserID, Money, Timestamp...
│   │   └── errors.go                  # ErrNotFound, ErrUnauthorized...
│   │
│   └── user/                          # Example domain — replace with your real domain
│       ├── handler.go                 # HTTP layer: bind, validate, delegate
│       ├── service.go                 # Interface — what this domain exposes
│       ├── service_impl.go            # Implementation — business logic
│       ├── repository.go              # Interface — data access contract
│       ├── model.go                   # Domain structs & DTOs
│       └── postgres/
│           └── repository.go          # Repository implementation for Postgres
│
├── pkg/                               # Exportable shared packages (empty by default)
│
├── .github/
│   └── workflows/
│       └── ci.yml                     # CI pipeline — lint, test, build
│
├── .air.toml                          # Air hot-reload config
├── Dockerfile                         # Multi-stage production build
├── .dockerignore
├── .env.example                       # Env var template — commit to Git, no secrets
├── .gitignore
├── .golangci.yml                      # Linter config
├── go.mod
├── Makefile
└── README.md
```

**Why this structure?**

- **`cmd/api/`** — follows the [official Go project layout](https://go.dev/doc/modules/layout). `main.go` does exactly one thing: parse config, build app, run.
- **`internal/config/`** — every service needs config. Centralizing it here prevents `os.Getenv` calls from scattering everywhere.
- **`internal/app/`** — a bootstrap pattern found in virtually every production repo. Keeps `main.go` lean and the app easy to test.
- **`internal/transport/`** — all **inbound** protocols in one place. HTTP server, gRPC server, MQ consumer are all ways of receiving input — they belong together.
- **`internal/external/`** — a perfect counterpart to `transport/`. `client/` for sync calls, `messaging/` for async publish.
- **`internal/shared/`** — only create when two or more domains genuinely need the same thing. Don't create it early.
- **`internal/<domain>/`** — domain-driven layout. Each domain owns its full vertical slice.
- **`pkg/`** — reusable code shared across multiple services. Empty by default.

---

## ✅ What's Included

The following files are fully implemented — clone and use immediately.

### `internal/config/config.go`

Loads config from environment variables with sensible defaults for every field. No external dependencies — just plain `os.Getenv`. To add a new field, declare it in the `Config` struct and `Load()` function.

```
APP_ENV   → cfg.App.Env   (default: development)
APP_PORT  → cfg.App.Port  (default: 8080)
```

### `internal/app/app.go`

Bootstraps the entire app. Initializes the HTTP server with correct timeouts, registers routes, and handles graceful shutdown on `SIGINT`/`SIGTERM`. The server waits for in-flight requests to complete (up to 10 seconds) before shutting down.

The `/health` endpoint returning `{"status":"ok"}` is included — ready for liveness checks out of the box.

### `internal/transport/http/server.go`

Creates an `*http.Server` with production-appropriate timeouts:

| Timeout | Value | Purpose |
|---|---|---|
| `ReadTimeout` | 10s | Blocks slow clients from dragging out request reads |
| `WriteTimeout` | 10s | Caps the time allowed to write a response |
| `IdleTimeout` | 60s | Closes idle keep-alive connections after 60s |

### `internal/transport/http/middleware/logger.go`

Logs each request as: `POST /v1/users 201 23ms`. Wraps `http.ResponseWriter` to capture the status code after the handler returns.

### `internal/transport/http/middleware/recovery.go`

Catches any `panic` inside a handler, logs the full stack trace, and returns `500` instead of crashing the server. **This is non-negotiable in production** — without it, a single panic kills the entire process.

### `Dockerfile`

Multi-stage build: stage 1 compiles the binary, stage 2 runs on `alpine:3.19` (~15MB image). The binary is built with `-ldflags="-s -w"` to strip debug info and reduce size.

---

## 🏛️ Domain Architecture

Each domain follows a layered pattern with interfaces and implementations kept separate:

```
Incoming request
  └── handler.go          ← HTTP only: bind JSON, validate, delegate
        └── service.go        ← Interface: domain contract
        └── service_impl.go   ← Implementation: business rules
              └── repository.go       ← Interface: data access contract
              └── postgres/
                    └── repository.go ← Implementation: SQL queries
                          └── model.go ← Structs, DTOs
```

**Rules that don't bend:**
- Handlers never access the database directly.
- Services know nothing about HTTP — no `http.Request`, no status codes.
- Repositories contain no business rules.
- `service.go` defines the interface; `service_impl.go` implements it — mocking for tests is trivial.
- `repository.go` defines the interface; `postgres/repository.go` implements it — swapping databases means adding a new subfolder, nothing else.
- Models are shared freely within a domain, never across domains.

---

## 🔌 Extension Rules

> Read this before adding any new file or folder.

---

### 1. Adding a New Domain

Each business feature = one folder under `internal/`.

```
internal/
└── order/                  # domain name, singular, lowercase
    ├── handler.go           # receive HTTP request, bind, validate, call service
    ├── service.go           # interface OrderService { ... }
    ├── service_impl.go      # struct orderService implementing the interface above
    ├── repository.go        # interface OrderRepository { ... }
    ├── model.go             # Order struct, CreateOrderRequest, OrderResponse
    └── postgres/
        └── repository.go   # implement OrderRepository with GORM/sqlx
```

**File naming rules:**

| File | Contents | Notes |
|---|---|---|
| `handler.go` | HTTP handlers | One file for few routes; split into `handler_admin.go` if there are many |
| `service.go` | Interface | Interface only, no logic |
| `service_impl.go` | Implementation | Struct + methods implementing the interface |
| `repository.go` | Interface | Interface only |
| `model.go` | Structs | Domain entity + request/response DTOs in one file |
| `postgres/repository.go` | DB impl | For MySQL, create `mysql/repository.go` |

**Do not:**
```
❌ internal/order/orderHandler.go   — no camelCase in file names
❌ internal/order/order_handler.go  — don't prefix the domain name into file names
❌ internal/order/handlers/         — don't create subfolders per layer
```

---

### 2. Adding a New Transport

A transport is a way to receive input from the outside world. Everything goes under `internal/transport/`.

**Adding WebSocket:**
```
internal/transport/
└── ws/
    ├── server.go       # upgrade HTTP → WS, manage hub
    ├── hub.go          # manage connections, broadcast
    └── client.go       # 1 goroutine/client: readPump + writePump
```

**Adding gRPC server:**
```
internal/transport/
└── grpc/
    ├── server.go
    └── interceptor/
        ├── auth.go     # metadata token check
        └── logger.go
```

**Adding a consumer (MQ):**
```
internal/transport/
└── consumer/
    ├── handler.go          # entry point — subscribe and dispatch
    ├── order_handler.go    # handle order events
    └── user_handler.go     # handle user events
```

**Do not:**
```
❌ internal/websocket/      — must live under transport/
❌ internal/transport/websocketServer.go — must be a folder, not a single file
```

---

### 3. Adding Outbound Calls

Everything that calls out goes under `internal/external/`.

**Calling another service (sync):**
```
internal/external/
└── client/
    ├── payment.go      # gRPC/HTTP client → payment service
    └── inventory.go    # gRPC/HTTP client → inventory service
```

Each client file should:
- Declare an interface at the top (for injection into `service_impl.go`)
- Implement the gRPC stub below
- Contain no business logic — just wrap the network call

```go
// internal/external/client/payment.go

type PaymentClient interface {
    Charge(ctx context.Context, req ChargeRequest) (*ChargeResponse, error)
}

type grpcPaymentClient struct { conn *grpc.ClientConn }

func NewPaymentClient(addr string) (PaymentClient, error) { ... }
func (c *grpcPaymentClient) Charge(...) { ... }
```

**Publishing messages (async):**
```
internal/external/
└── messaging/
    ├── publisher.go    # implement publishing to a broker
    └── messages.go     # define all message types
```

```go
// internal/external/messaging/messages.go
type OrderCreatedEvent struct {
    OrderID   string
    UserID    string
    CreatedAt time.Time
}
```

**Do not:**
```
❌ internal/payment/client.go   — clients must live under external/client/
❌ internal/rabbitmq/           — infrastructure details don't belong in folder names
```

---

### 4. Adding HTTP Middleware

All middleware lives under `internal/transport/http/middleware/`.

```
middleware/
├── logger.go       # included
├── recovery.go     # included
├── auth.go         # add when you need JWT verification
├── ratelimit.go    # add when you need rate limiting
├── cors.go         # add when you need CORS
└── idempotency.go  # add when you need idempotency key checks
```

Each middleware gets its own file, named exactly after its function. Register the order in `router.go`:

```go
// router.go — middleware order matters
handler = middleware.Recovery(handler)   // outermost — catches all panics
handler = middleware.Logger(handler)     // after recovery
handler = middleware.CORS(handler)       // before auth
handler = middleware.Auth(handler)       // innermost — runs just before the handler
```

**Do not:**
```
❌ internal/middleware/         — must live under transport/http/middleware/
❌ middleware/authMiddleware.go  — don't suffix file names with "Middleware"
```

---

### 5. Adding gRPC Interceptors

Same idea as middleware, but named `interceptor` — aligned with gRPC conventions.

```
internal/transport/grpc/interceptor/
├── logger.go       # included
├── auth.go         # metadata token check
└── recovery.go     # catch panics inside RPC handlers
```

---

### 6. Adding Shared Types

Only create `internal/shared/` when **two or more domains** need the same thing.

```
internal/shared/
├── enums.go        # const + type for statuses, roles, kinds...
├── types.go        # custom types: UserID, Money, Timestamp
└── errors.go       # shared sentinel errors
```

```go
// internal/shared/errors.go
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
    ErrConflict     = errors.New("conflict")
)
```

**Do not:**
```
❌ internal/shared/user_enums.go    — if only user needs it, keep it in user/model.go
❌ internal/shared/utils.go         — "utils" is a dump folder, not allowed
❌ internal/common/                  — same problem, don't use generic names
```

---

### 7. Adding pkg Utilities

`pkg/` is reserved for code **reusable across multiple services**.

```
pkg/
├── response/
│   └── response.go     # standard JSON format {success, data, error, meta}
├── apperror/
│   └── apperror.go     # custom error type with HTTP status code
├── logger/
│   └── logger.go       # zap/slog wrapper
├── paginate/
│   └── paginate.go     # offset + cursor pagination
├── telemetry/
│   └── telemetry.go    # OpenTelemetry setup — tracing + metrics
└── health/
    └── health.go       # /health + /ready handlers
```

Each package under `pkg/` is its own folder with one primary file sharing the same name. If it grows larger, split into multiple files but keep the same package name.

**Do not:**
```
❌ pkg/utils/           — no generic names
❌ pkg/helpers/         — same
❌ pkg/user/            — domain logic doesn't go in pkg/
❌ pkg/jwt/jwt.go then import internal/ — pkg must never import internal/
```

---

### 8. Adding Database Migrations

```
migrations/
└── postgres/
    ├── 001_create_users.sql
    ├── 002_create_orders.sql
    └── 003_add_index_orders_user_id.sql
```

**Naming rules:**
- Incrementing numeric prefix: `001`, `002`, `003`...
- Descriptive action names: `create_<table>`, `add_<column>_<table>`, `add_index_<table>_<column>`
- Never rename a file after it's been committed — migration tools track versions by filename

---

### 9. Adding Tests

**Unit tests** — placed alongside the source file:
```
internal/user/
├── service_impl.go
└── service_impl_test.go    # test file in the same package
```

**Integration tests** — require real infrastructure (DB, Redis):
```
test/
└── integration/
    ├── user_test.go        # uses testcontainers-go to spin up a real DB
    └── order_test.go
```

**E2E tests** — test the full HTTP flow:
```
test/
└── e2e/
    └── auth_test.go        # sends real HTTP requests, checks responses
```

**Mocks** — generated with mockery:
```
test/
└── mock/
    ├── user_service.go     # auto-generated mock of the UserService interface
    └── user_repository.go  # auto-generated mock of the UserRepository interface
```

---

### 10. Adding a New Binary

When you need a worker, CLI, or a separately running service:

```
cmd/
├── api/
│   └── main.go         # already here — HTTP API server
├── worker/
│   └── main.go         # add when you need a background job processor
└── migrate/
    └── main.go         # add when you need a migration CLI
```

Each binary under `cmd/` does exactly one thing: load config → call `app.New()` → run. No business logic in `main.go`.

---

### 11. Adding Proto Definitions

```
api/
└── proto/
    ├── user/
    │   └── user.proto
    └── order/
        └── order.proto
```

Generated Go code from proto files is **not committed** to the repo — regenerate in CI with `make proto`. If you prefer to commit it, put it in a dedicated folder:

```
internal/transport/grpc/pb/
├── user/
│   └── user.pb.go      # generated
└── order/
    └── order.pb.go     # generated
```

---

### 12. Adding New Config

Never call `os.Getenv` directly in code — always add it to `internal/config/config.go`:

```go
// Add struct
type DatabaseConfig struct {
    Host     string
    Port     int
    Name     string
    User     string
    Password string
}

// Add to Config
type Config struct {
    App      AppConfig
    Database DatabaseConfig   // add here
}

// Add to Load()
Database: DatabaseConfig{
    Host: getEnv("DB_HOST", "localhost"),
    Port: getEnvInt("DB_PORT", 5432),
    ...
}
```

Always update `.env.example` at the same time as the code.

---

### Quick Reference: Where Does a New File Go?

| Type | Location |
|---|---|
| New business feature | `internal/<domain>/` |
| HTTP handler | `internal/<domain>/handler.go` |
| Business logic | `internal/<domain>/service_impl.go` |
| DB queries | `internal/<domain>/postgres/repository.go` |
| HTTP middleware | `internal/transport/http/middleware/<name>.go` |
| gRPC interceptor | `internal/transport/grpc/interceptor/<name>.go` |
| WebSocket | `internal/transport/ws/` |
| MQ consumer | `internal/transport/consumer/<name>_handler.go` |
| Sync call to another service | `internal/external/client/<service>.go` |
| Async message publish | `internal/external/messaging/` |
| Shared enums/types | `internal/shared/enums.go` or `types.go` |
| Shared sentinel errors | `internal/shared/errors.go` |
| Reusable utility | `pkg/<name>/<name>.go` |
| SQL migration | `migrations/postgres/NNN_<action>_<table>.sql` |
| Unit test | Same folder as the source file (`_test.go`) |
| Integration test | `test/integration/` |
| E2E test | `test/e2e/` |
| Proto definition | `api/proto/<domain>/<domain>.proto` |
| New binary | `cmd/<name>/main.go` |
| New config | `internal/config/config.go` + `.env.example` |

---

## 📦 `pkg/` — When to Use It

`pkg/` is intentionally empty. Only add to it when code meets **both** criteria:

1. It is **not** specific to this service's business logic.
2. Another service could copy it and use it without modification.

**Good fits:**

```
pkg/
├── response/      # standard HTTP response format
├── apperror/      # custom error types with HTTP status mapping
├── logger/        # structured logger wrapper
├── telemetry/     # OpenTelemetry tracing + Prometheus metrics
├── health/        # /health + /ready endpoints
├── paginate/      # offset and cursor-based pagination
└── testutil/      # test helpers
```

**Not a fit:**

```
❌ pkg/jwt/        — not every service authenticates with JWT
❌ pkg/auth/       — auth logic is business logic
❌ pkg/database/   — DB configuration is a per-service decision
❌ pkg/utils/      — generic name, not allowed
```

---

## 🚀 Getting Started

### Prerequisites

Install the following tools before beginning:

#### 1. Install Go 1.22+

**Windows:**
- Download the installer from [https://golang.org/dl/](https://golang.org/dl/) → pick the `.msi` file
- Run it; installs to `C:\Program Files\Go` by default
- Open a new terminal and verify:
```powershell
go version
# → go version go1.22.x windows/amd64
```

**Linux/Mac:**
```bash
# Mac (Homebrew)
brew install go

# Ubuntu/Debian
sudo apt install golang-go

# Verify
go version
```

#### 2. Install Make

**Windows** — Make isn't bundled; install via Chocolatey:
```powershell
# Install Chocolatey first (run PowerShell as Admin)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Then install Make
choco install make

# Verify
make --version
```

**Linux/Mac:**
```bash
# Mac
brew install make

# Ubuntu/Debian
sudo apt install make

# Verify
make --version
```

#### 3. Install Air (hot-reload)

```bash
go install github.com/air-verse/air@latest
```

Verify:
```bash
air -v
```

> **Windows:** The first time you run `make dev`, Windows Firewall will ask for permission to allow `tmp/api.exe` — click **Allow** once and it won't ask again.

#### 4. Docker (optional — only needed for `make docker/*`)

Download at [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)

---

### Setup — Linux/Mac

```bash
# 1. Clone
git clone https://github.com/DANG-PH/golang-base.git my-service
cd my-service

# 2. Replace import paths in .go files
find . -type f -name "*.go" -exec sed -i.bak 's|github.com/DANG-PH/golang-base|github.com/DANG-PH/my-service|g' {} +
find . -type f -name "*.bak" -delete

# 3. Update the module path correctly via Go toolchain (do NOT edit go.mod manually)
go mod edit -module github.com/DANG-PH/my-service
go mod tidy

# 4. Reset git history
rm -rf .git && git init
git add .
git commit -m "chore: initial from golang-base"

# 5. Set up env
cp .env.example .env

# 6. Run with hot-reload
make dev

# 7. Verify
curl http://localhost:8080/health
# → {"status":"ok"}
```

### Setup — Windows (PowerShell)

```powershell
# 1. Clone
git clone https://github.com/DANG-PH/golang-base.git my-service
cd my-service

# 2. Replace import paths in .go files
Get-ChildItem -Recurse -Filter "*.go" | % { [System.IO.File]::WriteAllText($_.FullName, ([System.IO.File]::ReadAllText($_.FullName) -replace 'github.com/DANG-PH/golang-base','github.com/DANG-PH/my-service'), (New-Object System.Text.UTF8Encoding($false))) }

# 3. Update module path correctly (avoids BOM + syntax errors)
go mod edit -module github.com/DANG-PH/my-service
go mod tidy

# 4. Reset git history
Remove-Item -Recurse -Force .git; git init
git add .
git commit -m "chore: initial from golang-base"

# 5. Set up env
Copy-Item .env.example .env

# 6. Run with hot-reload
make dev

# 7. Verify
curl http://localhost:8080/health
# → {"status":"ok"}
```

---

### How `make dev` Works

```
You save a .go file
       ↓
Air detects the change (file watcher)
       ↓
Auto-rebuild → tmp/api.exe
       ↓
Kill old process → Start new process
       ↓
Server is running your new code — nothing else needed
```

The terminal shows:
```
building...
running...
```

No `Ctrl+C`, no manual restart. Just code, save, test.

---

## ⚙️ Configuration

```env
APP_ENV=development   # development | staging | production
APP_PORT=8080
GRPC_PORT=9090        # add when using gRPC
```

Add new vars to `.env.example` as the service grows — never commit `.env`.

---

## 🛠️ Makefile Commands

| Command | Description |
|---|---|
| `make dev` | **Run with hot-reload (Air) ← use this daily** |
| `make run` | Run the application (fallback without Air) |
| `make build` | Compile to `./bin/api` |
| `make test` | Run all tests with race detector |
| `make test/cover` | Show coverage report |
| `make lint` | Run `golangci-lint` |
| `make fmt` | Run `go fmt` |
| `make vet` | Run `go vet` |
| `make tidy` | Run `go mod tidy` |
| `make clean` | Remove build artifacts |
| `make docker/build` | Build Docker image |
| `make docker/run` | Run Docker container with `.env` |
| `make proto` | Compile `.proto` files → Go code |

---

## 🔄 CI Pipeline

GitHub Actions runs on every push to `main` and every pull request:

- **lint** — `golangci-lint` with `.golangci.yml`
- **test** — `go test -race ./...` with coverage report

---

## 🤝 Contributing

1. Fork the repository
2. Create a branch (`git checkout -b feature/your-feature`)
3. Commit following [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`)
4. Push and open a Pull Request

PRs adding framework-specific or business-specific code won't be merged — this repo stays generic.

---

## 👤 Author

<p align="left">
  <a href="https://github.com/DANG-PH">
    <img src="https://github.com/DANG-PH.png" width="72" style="border-radius:50%" alt="DANG-PH"/>
  </a>
  <br/>
  <strong>Phạm Hải Đăng</strong> &nbsp;·&nbsp; <a href="https://github.com/DANG-PH">@DANG-PH</a>
  <br/>
  Backend Engineer · Go · NestJS · Distributed Systems
</p>

If this saved you 30 minutes of setup — leave a ⭐. It helps others find the repo when searching for Go starters.

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.

<p align="center"><sub>Built with Go · Kept simple on purpose</sub></p>