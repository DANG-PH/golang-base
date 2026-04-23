# ══════════════════════════════════════════════════════
# golang-base — Makefile
# Dùng: make <command>
# ══════════════════════════════════════════════════════

.PHONY: run build test test/cover lint fmt vet tidy clean docker/build docker/run help

# Hiện danh sách tất cả commands
help:
	@echo ""
	@echo "  Commands:"
	@echo ""
	@echo "  make run          Chạy server (go run)"
	@echo "  make build        Compile binary → bin/api"
	@echo "  make test         Chạy tests với race detector"
	@echo "  make test/cover   Chạy tests + xuất coverage.html"
	@echo "  make lint         Chạy golangci-lint"
	@echo "  make fmt          Format code (go fmt)"
	@echo "  make vet          Static check (go vet)"
	@echo "  make tidy         Dọn go.mod và go.sum"
	@echo "  make clean        Xóa bin/, coverage, tmp/"
	@echo "  make docker/build Build Docker image"
	@echo "  make docker/run   Chạy container với .env"
	@echo ""

# ── Development ───────────────────────────────────────

# Chạy trực tiếp bằng go run — dùng trong dev
run:
	go run cmd/api/main.go

# Compile ra binary tĩnh vào bin/api
# -ldflags="-s -w": strip debug info, giảm size binary
build:
	go build -ldflags="-s -w" -o bin/api cmd/api/main.go

# ── Testing ───────────────────────────────────────────

# Chạy tất cả tests với race detector
# -race: phát hiện data race giữa các goroutine
# -cover: hiển thị coverage % ra terminal
test:
	go test ./... -race -cover

# Chạy tests + xuất coverage report dạng HTML
# Mở coverage.html để xem từng dòng được test chưa
test/cover:
	go test ./... -race -coverprofile=coverage.out
	go tool cover -html=coverage.out -o coverage.html

# ── Code Quality ──────────────────────────────────────

# Chạy golangci-lint với config từ .golangci.yml
# Cài đặt: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
lint:
	golangci-lint run ./...

# Format toàn bộ code theo chuẩn Go
# Nên chạy trước khi commit
fmt:
	go fmt ./...

# Static analysis cơ bản — built-in Go tool
# Phát hiện: format string sai, unreachable code, shadowed variables...
vet:
	go vet ./...

# Dọn dẹp go.mod và go.sum
# Xóa dependencies không dùng, thêm dependencies còn thiếu
tidy:
	go mod tidy

# ── Cleanup ───────────────────────────────────────────

# Xóa toàn bộ build artifacts và file tạm
clean:
	rm -rf bin/ coverage.out coverage.html tmp/

# ── Docker ────────────────────────────────────────────

# Build Docker image với tag golang-base
# Dùng Dockerfile multi-stage — image cuối ~15MB
docker/build:
	docker build -t golang-base .

# Chạy container, load env từ file .env
# Map port 8080 host → 8080 container
docker/run:
	docker run --env-file .env -p 8080:8080 golang-base