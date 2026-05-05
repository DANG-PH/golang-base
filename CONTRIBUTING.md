# Contributing to golang-base

Thank you for your interest in golang-base! This repo is a **shared core skeleton** — every contribution is carefully considered to maintain simplicity and generality.

---

## Core principles

Before opening a PR, ask yourself:

> *"Does every service need this?"*

If the answer is **not sure** — don't add it here.

### ✅ Accepted

- Improvements to structure, naming conventions, or documentation
- Bug fixes in existing parts (config loader, middleware, Dockerfile...)
- CI pipeline or Makefile improvements
- Truly generic utilities in `pkg/` (no business logic dependency)

### ❌ Not accepted

- Any web framework (Gin, Echo, Fiber...)
- Specific ORM or database drivers (GORM, sqlx, pgx...)
- Business logic in any form
- Authentication/authorization implementations
- Unnecessary dependencies added to `go.mod`

---

## Process

### 1. Open an issue first

For changes larger than a typo fix, open an issue first to discuss. Avoid writing a lot of code only for the PR to be rejected because it doesn't fit the repo's direction.

### 2. Fork and create a branch

```bash
git clone https://github.com/<your-username>/golang-base.git
cd golang-base
git checkout -b <type>/<short-description>
```

Branch naming pattern:

```
feat/add-grpc-interceptor-example
fix/recovery-middleware-nil-panic
docs/clarify-external-client-rules
chore/update-golangci-config
```

### 3. Write code

Follow the extension rules in the README. Place new files in the correct location per the structure table.

Run these checks before committing:

```bash
make fmt      # format code
make vet      # static analysis
make lint     # golangci-lint
make test     # run tests
```

All must pass with no warnings before committing.

### 4. Commit

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add recovery interceptor for gRPC server
fix: handle nil context in logger middleware
docs: add WebSocket transport example to README
chore: bump golangci-lint to v1.57
refactor: simplify config loader default handling
```

Each commit does **one thing**. No "fix stuff" or "update" commits.

### 5. Open a Pull Request

- Title follows Conventional Commits format
- Short description: **why** the change is needed, not what it does (code says that)
- If related to an issue: `Closes #<number>`
- No long checklists — CI will check automatically

---

## Code style

This repo uses no framework, so there are no special conventions beyond Go standard:

- `gofmt` — required, run via `make fmt`
- `golangci-lint` with config in `.golangci.yml` — required
- Comment public API in English, following Go doc convention (`// FunctionName does...`)
- Error messages in lowercase, no trailing period (`"something went wrong"` not `"Something went wrong."`)
- No `panic` in library code — only in `main.go` when startup fails

---

## Adding to `pkg/`

This is the most commonly misused area. A new package in `pkg/` must satisfy **both**:

1. Contains no business logic whatsoever
2. Can be copied to another service and used immediately without modification

If only one condition is met — it doesn't belong here.

Each package is one folder, with the main file matching the package name:

```
pkg/paginate/paginate.go    ✅
pkg/utils/string.go         ❌  — generic name not allowed
pkg/auth/jwt.go             ❌  — business-specific
```

---

## Questions?

Open a [Discussion](https://github.com/DANG-PH/golang-base/discussions) or comment directly on the related issue.