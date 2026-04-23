# 📘 GOLANG.md — Hướng dẫn Go cho người mới

> Tài liệu này giải thích các khái niệm **đặc thù của Go** mà dev mới thường gặp trong project này.
> Không giải thích Docker, `.env`, CI/CD vì những thứ đó phổ biến ở mọi tech stack.

---

## 📑 Mục lục

1. [Linter là gì?](#1-linter-là-gì)
2. [go.mod — Khai báo module](#2-gomod--khai-báo-module)
3. [go.sum — File khóa dependency](#3-gosum--file-khóa-dependency)
4. [Makefile trong Go](#4-makefile-trong-go)
5. [Air — Hot reload](#5-air--hot-reload)
6. [.air.toml — Cấu hình Air](#6-airtoml--cấu-hình-air)
7. [.golangci.yml — Cấu hình linter](#7-golangciyml--cấu-hình-linter)
8. [go vet, go fmt, go test](#8-go-vet-go-fmt-go-test)
9. [Race Detector](#9-race-detector)
10. [Build Tags](#10-build-tags)
11. [internal/ — Package đặc biệt của Go](#11-internal--package-đặc-biệt-của-go)
12. [pkg/ — Public shared packages](#12-pkg--public-shared-packages)
13. [cmd/ — Entry point](#13-cmd--entry-point)
14. [Interface trong Go](#14-interface-trong-go)
15. [Goroutine và Channel](#15-goroutine-và-channel)
16. [Context](#16-context)
17. [defer, panic, recover](#17-defer-panic-recover)
18. [Error handling trong Go](#18-error-handling-trong-go)
19. [Struct và Embedding](#19-struct-và-embedding)
20. [Pointer](#20-pointer)
21. [Go Runtime Stack — Tại sao Go nhanh?](#21-go-runtime-stack--tại-sao-go-nhanh)
22. [Go Scheduler — M:N Threading](#22-go-scheduler--mn-threading)
23. [Memory Model và Escape Analysis](#23-memory-model-và-escape-analysis)
24. [Slice và Array — Hiểu đúng bản chất](#24-slice-và-array--hiểu-đúng-bản-chất)
25. [Map — Cạm bẫy thường gặp](#25-map--cạm-bẫy-thường-gặp)
26. [sync Package — Đồng bộ hóa](#26-sync-package--đồng-bộ-hóa)
27. [select Statement](#27-select-statement)
28. [Generics (Go 1.18+)](#28-generics-go-118)
29. [init() Function](#29-init-function)
30. [Blank Identifier _](#30-blank-identifier-_)
31. [Các file cấu hình thường gặp trong Go project](#31-các-file-cấu-hình-thường-gặp-trong-go-project)
32. [go generate và Tooling](#32-go-generate-và-tooling)
33. [Testing nâng cao](#33-testing-nâng-cao)
34. [Profiling — Tìm bottleneck](#34-profiling--tìm-bottleneck)
35. [Những lỗi phổ biến của người mới học Go](#35-những-lỗi-phổ-biến-của-người-mới-học-go)
36. [Thuật ngữ chuyên ngành](#36-thuật-ngữ-chuyên-ngành)

---

## 1. Linter là gì?

**Linter** là công cụ đọc source code của bạn mà **không chạy nó**, rồi tìm ra các vấn đề như:

- Bug tiềm ẩn (quên check error, dùng biến sai kiểu)
- Code style không nhất quán (format sai, import lộn xộn)
- Security issue (SQL injection, hardcoded password)
- Code phức tạp quá mức (function quá nhiều nhánh if/else)

Hãy nghĩ linter như một **code reviewer tự động** — nó review code của bạn trước khi đồng đội review.

```
Bạn viết code
     ↓
Linter đọc code (không chạy)
     ↓
Linter báo: "Dòng 42: bạn quên check error ở đây"
     ↓
Bạn fix
     ↓
Commit lên Git
```

**Tại sao cần linter?**

Không có linter, những lỗi này vẫn compile được, vẫn chạy được — nhưng sẽ gây bug âm thầm ở production:

```go
// Compile được, chạy được, nhưng SAI
resp, _ := http.Get(url)        // bỏ qua error
defer resp.Body.Close()         // nếu http.Get lỗi, resp là nil → PANIC

// Linter (errcheck + bodyclose) sẽ bắt được cả 2 vấn đề trên
```

**golangci-lint** là tool gộp nhiều linter lại, chạy 1 lệnh thay vì 10 lệnh riêng lẻ. Config trong `.golangci.yml`.

---

## 2. `go.mod` — Khai báo module

### File này là gì?

`go.mod` là file khai báo **module name** và **danh sách dependencies** của project. Tương đương `package.json` (Node) hay `pom.xml` (Java).

```
go.mod ↔ package.json trong Node.js
go.sum ↔ package-lock.json trong Node.js
```

### Cấu trúc

```
module github.com/DANG-PH/game-service-go   ← tên module (import path)

go 1.22                                      ← phiên bản Go tối thiểu

require (
    github.com/gin-gonic/gin v1.9.1          ← dependency + version
    github.com/jackc/pgx/v5 v5.5.0
)
```

### Module name quan trọng như thế nào?

Module name chính là **prefix của mọi import path** trong project:

```go
// Module name: github.com/DANG-PH/game-service-go
// Khi import internal package:
import "github.com/DANG-PH/game-service-go/internal/config"
//      ↑ module name                      ↑ đường dẫn thư mục
```

Nếu đổi module name mà không update import → code không compile được.

### Các lệnh thường dùng

```bash
go mod init github.com/ten-cua-ban/ten-project  # Tạo go.mod mới
go mod tidy                                      # Dọn dẹp: xóa dep không dùng, thêm dep còn thiếu
go get github.com/gin-gonic/gin@v1.9.1          # Thêm/update 1 dependency
go get github.com/gin-gonic/gin@latest          # Lấy version mới nhất
```

### `go mod tidy` làm gì?

```
Đọc toàn bộ .go file trong project
         ↓
Tìm tất cả import đang dùng
         ↓
So sánh với go.mod
         ↓
Thêm vào go.mod những dep đang import nhưng chưa có
Xóa khỏi go.mod những dep có trong file nhưng không import ở đâu
         ↓
Cập nhật go.sum tương ứng
```

**Nên chạy `go mod tidy` trước mỗi lần commit.**

---

## 3. `go.sum` — File khóa dependency

### File này làm gì?

`go.sum` lưu **checksum (mã hash)** của từng dependency — đảm bảo code bạn download về đúng là code gốc, không bị ai tamper.

```
github.com/gin-gonic/gin v1.9.1 h1:4idEAncQnU5cB7BeOkPtxjfCSye0AAm1R0RVIqJ+Jmg=
github.com/gin-gonic/gin v1.9.1/go.mod h1:hPrL7YrpYKXt5YId3A/Tnip5kqbEAP+KLuI3SUcPTeU=
```

Mỗi dòng = `tên_package version hash`

### Có cần chỉnh sửa `go.sum` không?

**Không bao giờ.** File này được Go tool tự quản lý. Bạn chỉ cần:
- **Commit** `go.sum` lên Git (bắt buộc — CI cần nó)
- **Không edit tay**
- Nếu `go.sum` lỗi → chạy `go mod tidy` để regenerate

---

## 4. Makefile trong Go

### Makefile là gì?

`Makefile` là file định nghĩa **shortcut commands** cho project. Thay vì nhớ lệnh dài, bạn dùng tên ngắn:

```bash
# Không có Makefile — phải nhớ lệnh dài
go build -ldflags="-s -w" -o bin/api cmd/api/main.go

# Có Makefile — chỉ cần nhớ
make build
```

### Cách Makefile hoạt động

```makefile
# Cấu trúc cơ bản:
tên-target:
[TAB]lệnh-sẽ-chạy

# Ví dụ:
build:
    go build -ldflags="-s -w" -o bin/api cmd/api/main.go

test:
    go test ./... -race -cover
```

> ⚠️ **Quan trọng:** Trước lệnh phải là **TAB**, không phải spaces. Dùng spaces → Makefile báo lỗi.

### `make` tìm Makefile ở đâu?

Khi bạn gõ `make <target>`, nó tìm file tên `Makefile` trong **thư mục hiện tại**. Vì vậy terminal phải đang đứng ở root project:

```
D:\Backend_NRO\game-service-go> make dev   ✅ (Makefile ở đây)
D:\Backend_NRO\game-service-go\internal> make dev   ❌ (không tìm thấy Makefile)
```

### `.PHONY` là gì?

```makefile
.PHONY: run build test clean
```

Khai báo rằng các target này **không phải tên file**. Nếu không có `.PHONY` mà trong thư mục tồn tại file tên `build` → `make build` sẽ bị confused, nghĩ file đó đã up-to-date và không chạy gì cả.

Quy tắc: **mọi target không tạo ra file thì đều khai báo trong `.PHONY`**.

### Tại sao Go project dùng Makefile?

Go không có task runner tích hợp như npm scripts. Makefile là cách phổ biến nhất trong Go ecosystem để:
- Chuẩn hóa commands trong team
- Gộp nhiều lệnh phức tạp thành 1 lệnh ngắn
- Dùng trong CI/CD (GitHub Actions gọi `make lint`, `make test`)

---

## 5. Air — Hot reload

### Hot reload là gì?

Bình thường khi dev Go:
```
Sửa code → Ctrl+C dừng server → go run lại → test → lặp lại
```

Với Air:
```
Sửa code → Save → Air tự rebuild và restart → test → lặp lại
```

Air theo dõi thay đổi file, tự động rebuild và restart server. Bạn không cần làm gì ngoài save file.

### Tại sao không dùng `go run` mãi?

Vấn đề với `go run cmd/api/main.go` trên Windows:
- Mỗi lần chạy, Go compile ra file `.exe` tạm trong `%TEMP%`
- Windows Defender thấy file `.exe` lạ → hỏi quyền mỗi lần
- Phải Ctrl+C và chạy lại mỗi khi sửa code

Air build vào `tmp/api.exe` cố định → Windows chỉ hỏi quyền **một lần duy nhất**.

### Cài đặt Air

```bash
go install github.com/air-verse/air@latest
```

Lệnh này tải Air về và đặt binary vào `$GOPATH/bin` — sau đó bạn có thể gọi `air` từ bất kỳ đâu.

### Chạy Air

```bash
# Cách 1: trực tiếp
air

# Cách 2: qua Makefile (khuyến nghị)
make dev
```

### Flow hoạt động của Air

```
make dev → gọi air
              ↓
         Đọc .air.toml
              ↓
         Build lần đầu → tmp/api.exe
              ↓
         Chạy tmp/api.exe (server up)
              ↓
         Ngồi watch thư mục...
              ↓ (bạn save file .go)
         OS báo: "file X thay đổi"
              ↓
         Kill tmp/api.exe cũ
              ↓
         Build lại → tmp/api.exe mới
              ↓
         Chạy tmp/api.exe mới
              ↓
         Tiếp tục watch...
```

---

## 6. `.air.toml` — Cấu hình Air

File config của Air, đặt ở **root project**. Air tự tìm file này khi khởi động.

```toml
root = "."        # Thư mục gốc để watch
tmp_dir = "tmp"   # Thư mục chứa binary tạm

[build]
  cmd = "go build -o tmp/api.exe cmd/api/main.go"
  # ↑ Lệnh build — chạy mỗi khi detect thay đổi

  bin = "tmp/api.exe"
  # ↑ Binary sẽ chạy sau khi build xong

  include_ext = ["go", "env"]
  # ↑ Chỉ watch file .go và .env
  #   Bỏ qua .md, .yml, .json... không cần rebuild khi sửa docs

  exclude_dir = ["vendor", "bin", "tmp"]
  # ↑ Không watch các folder này
  #   tmp/ đặc biệt quan trọng: nếu watch tmp/ thì mỗi lần build
  #   xong tạo file mới trong tmp/ → Air lại detect thay đổi → rebuild mãi (vòng lặp vô tận)

  delay = 500
  # ↑ Đợi 500ms sau khi detect thay đổi rồi mới build
  #   Khi bạn save nhiều file liên tiếp (format code, rename...) 
  #   tránh rebuild sau mỗi file, đợi "yên" rồi build 1 lần

[log]
  time = true     # Hiển thị timestamp trong log

[misc]
  clean_on_exit = true  # Xóa tmp/api.exe khi tắt Air (Ctrl+C)
```

---

## 7. `.golangci.yml` — Cấu hình linter

File config của `golangci-lint`, đặt ở **root project**. Khi chạy `make lint` hoặc `golangci-lint run ./...`, tool này tự tìm file config.

Chi tiết từng linter đã giải thích ở cuộc trò chuyện trước. Tóm tắt nhanh:

| Linter | Bắt gì |
|---|---|
| `errcheck` | Quên check error |
| `govet` | Suspicious code (format string sai, copy mutex...) |
| `staticcheck` | Bug tinh vi (context leak, dead code...) |
| `unused` | Function/type khai báo nhưng không dùng |
| `gofmt` | Code chưa được format |
| `goimports` | Import không đúng chuẩn |
| `gosec` | Security vulnerability |
| `gocyclo` | Function quá phức tạp |
| `bodyclose` | Quên đóng HTTP response body |
| `noctx` | HTTP request không có context |

---

## 8. `go vet`, `go fmt`, `go test`

Đây là các **built-in tool** của Go — không cần cài thêm gì.

### `go fmt`

Format code theo chuẩn Go. Go có **1 cách format duy nhất** — không tranh cãi tabs vs spaces, indent bao nhiêu.

```bash
go fmt ./...    # Format tất cả file .go trong project
```

Sau khi format, diff của bạn sẽ sạch hơn — không có noise từ whitespace.

### `go vet`

Static analysis cơ bản — tìm code suspicious mà compiler bỏ qua:

```bash
go vet ./...
```

Ví dụ những thứ `go vet` bắt được:
```go
// Lỗi format string
fmt.Printf("%d", "hello")  // %d cho int, nhưng truyền string

// Copy sync.Mutex
mu := sync.Mutex{}
mu2 := mu  // ← KHÔNG được copy mutex, go vet báo ngay

// Unreachable code
return
fmt.Println("never reached")  // ← go vet bắt được
```

### `go test`

Chạy tất cả test trong project:

```bash
go test ./...               # Chạy tất cả test
go test ./internal/user/... # Chạy test trong 1 package cụ thể
go test -v ./...            # Verbose — hiện tên từng test
go test -run TestUserCreate # Chạy đúng 1 test theo tên
```

File test trong Go phải đặt tên `_test.go` và function test phải bắt đầu bằng `Test`:

```go
// internal/user/service_impl_test.go
func TestCreateUser(t *testing.T) {
    // ...
}
```

---

## 9. Race Detector

### Data Race là gì?

Khi 2 goroutine cùng đọc/ghi vào 1 biến cùng lúc mà không có synchronization → **data race**. Kết quả không xác định, bug cực khó reproduce.

```go
// Ví dụ data race
var counter int

go func() { counter++ }()  // goroutine 1 ghi
go func() { counter++ }()  // goroutine 2 ghi cùng lúc
// counter có thể là 1 hoặc 2 — không đoán được
```

### Race Detector làm gì?

```bash
go test ./... -race    # Chạy test với race detector bật
go run -race main.go   # Chạy app với race detector
```

Race detector instrument code của bạn — theo dõi mọi lần đọc/ghi memory trong runtime. Khi phát hiện race condition → in warning và exit.

**Lưu ý:** Race detector làm chương trình chậm hơn ~5-10x và dùng nhiều RAM hơn → chỉ dùng trong dev/test, không bật ở production.

```bash
# Trong Makefile
test:
    go test ./... -race -cover   # ← -race bật race detector
```

---

## 10. Build Tags

### Build Tag là gì?

Build tag (còn gọi là build constraint) là cách nói với Go compiler: **"chỉ compile file này khi điều kiện X thỏa mãn"**.

```go
//go:build integration
// ↑ Chỉ compile file này khi build với tag "integration"

package integration_test
```

### Dùng ở đâu?

Phổ biến nhất với **integration test** — test cần DB thật, Redis thật, không nên chạy cùng unit test:

```go
// test/integration/user_test.go
//go:build integration

package integration_test

func TestUserIntegration(t *testing.T) {
    // Kết nối DB thật, test thật
}
```

```bash
# Chạy unit test bình thường (không có integration test)
go test ./...

# Chạy kèm integration test
go test ./... -tags integration
```

### Các tag thường gặp

```bash
-tags integration   # Bật integration test
-tags e2e           # Bật e2e test
-tags mock          # Dùng mock thay vì real service
```

---

## 11. `internal/` — Package đặc biệt của Go

### Tính năng đặc biệt

`internal/` là tên thư mục có ý nghĩa đặc biệt với Go compiler: **code trong `internal/` chỉ được import bởi code trong cùng module**.

```
game-service-go/
├── internal/
│   └── config/
│       └── config.go    ← package này
└── cmd/
    └── api/
        └── main.go      ← có thể import internal/config ✅
```

Nếu service khác (`payment-service`) cố import `game-service-go/internal/config` → **compile error**. Go compiler chặn ở compile time, không phải runtime.

### Tại sao dùng `internal/`?

Đây là cách Go enforce **encapsulation ở cấp module**. Business logic, domain code, implementation details → đặt vào `internal/`. Chỉ những gì thực sự muốn chia sẻ giữa nhiều service mới đặt vào `pkg/`.

---

## 12. `pkg/` — Public shared packages

Code trong `pkg/` **có thể được import** bởi bất kỳ module nào khác. Đặt ở đây khi:

1. Code không đặc thù cho business logic của service này
2. Service khác có thể dùng mà không cần sửa

```
pkg/
├── response/    # HTTP response format chuẩn — mọi service đều cần
├── apperror/    # Custom error type — reusable
└── logger/      # Logger wrapper — reusable
```

**Quy tắc quan trọng:** `pkg/` **không được** import `internal/`. Nếu cần import internal thì code đó không thuộc về `pkg/`.

---

## 13. `cmd/` — Entry point

Mỗi subfolder trong `cmd/` là 1 **binary có thể chạy độc lập**:

```
cmd/
├── api/
│   └── main.go     → compile thành binary "api" (HTTP server)
├── worker/
│   └── main.go     → compile thành binary "worker" (background job)
└── migrate/
    └── main.go     → compile thành binary "migrate" (DB migration CLI)
```

Mỗi `main.go` chỉ làm 1 việc: **load config → khởi tạo app → chạy**. Không có business logic trong `main.go`.

```go
// cmd/api/main.go — đúng chuẩn
func main() {
    cfg := config.Load()
    app := app.New(cfg)
    app.Run()
}
```

### Tại sao không có 1 `main.go` ở root?

Vì project thực tế thường cần nhiều binary: server chính, worker xử lý background job, CLI chạy migration. Mỗi cái là 1 binary riêng nhưng dùng chung `internal/` code.

---

## 14. Interface trong Go

### Interface là gì?

Interface trong Go định nghĩa **tập hợp method mà một type phải có**. Khác với Java/C#, Go dùng **implicit implementation** — không cần khai báo `implements`.

```go
// Định nghĩa interface
type UserService interface {
    GetUser(ctx context.Context, id string) (*User, error)
    CreateUser(ctx context.Context, req CreateUserRequest) (*User, error)
}

// Implement interface — không cần khai báo "implements UserService"
type userService struct {
    repo UserRepository
}

func (s *userService) GetUser(ctx context.Context, id string) (*User, error) {
    // ...
}

func (s *userService) CreateUser(ctx context.Context, req CreateUserRequest) (*User, error) {
    // ...
}

// Go tự nhận ra userService implement UserService vì có đủ methods
```

### Tại sao project dùng pattern interface/implementation tách biệt?

```
service.go       → chỉ chứa interface (contract)
service_impl.go  → chứa implementation (logic thật)
```

**Lợi ích 1: Mock khi test**

```go
// test — dùng mock thay vì gọi DB thật
type mockUserService struct{}

func (m *mockUserService) GetUser(ctx context.Context, id string) (*User, error) {
    return &User{ID: id, Name: "Test User"}, nil  // trả data giả
}

// mock này thỏa mãn UserService interface → có thể dùng thay thế
```

**Lợi ích 2: Đổi implementation không ảnh hưởng code khác**

```go
// Hôm nay dùng Postgres
repo := postgres.NewUserRepository(db)

// Mai đổi sang MongoDB — chỉ đổi dòng này, handler không cần sửa
repo := mongodb.NewUserRepository(client)
```

---

## 15. Goroutine và Channel

### Goroutine

Goroutine là **lightweight thread** của Go — nhẹ hơn OS thread rất nhiều (vài KB so với vài MB). Tạo goroutine bằng từ khóa `go`:

```go
// Chạy bình thường — block, chờ xong rồi tiếp
result := fetchData()

// Chạy trong goroutine — không block, chạy song song
go fetchData()

// Thực tế hay dùng với anonymous function
go func() {
    result := fetchData()
    // xử lý result
}()
```

**Lưu ý:** Goroutine chạy song song nhưng không có cách nào lấy return value trực tiếp — dùng channel hoặc sync.WaitGroup để đồng bộ.

### Channel

Channel là **pipeline** để goroutine giao tiếp với nhau — truyền data an toàn mà không cần lock.

```go
// Tạo channel
ch := make(chan string)      // unbuffered — gửi block cho đến khi ai đó nhận
ch := make(chan string, 10)  // buffered — gửi không block nếu buffer còn chỗ

// Gửi vào channel
ch <- "hello"

// Nhận từ channel
msg := <-ch

// Ví dụ thực tế
func main() {
    ch := make(chan string)

    go func() {
        result := callExternalAPI()  // tốn thời gian
        ch <- result                 // gửi kết quả về
    }()

    // Làm việc khác trong lúc chờ...

    result := <-ch  // nhận kết quả (block cho đến khi goroutine gửi)
    fmt.Println(result)
}
```

### Khi nào cần dùng?

Goroutine thường xuất hiện trong:
- Xử lý nhiều request HTTP song song (Go HTTP server tự dùng goroutine cho mỗi request)
- Fan-out: gọi nhiều service cùng lúc, chờ tất cả xong
- Background job: worker chạy song song với main server

---

## 16. Context

### Context là gì?

`context.Context` là cách **truyền thông tin xuyên suốt call chain** — đặc biệt là:
- **Deadline/Timeout**: request này phải xong trong 5 giây
- **Cancellation**: client đã ngắt kết nối, hủy mọi việc đang làm
- **Request-scoped values**: request ID, user ID, trace ID

```go
// Tạo context với timeout 5 giây
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()  // LUÔN gọi cancel để giải phóng resource

// Truyền context xuống mọi tầng
user, err := userService.GetUser(ctx, userID)
//                               ↑ context đi theo
```

### Tại sao mọi function đều nhận `ctx context.Context` làm tham số đầu tiên?

Đây là **convention của Go** — không phải bắt buộc về syntax nhưng là best practice:

```go
func (s *userService) GetUser(ctx context.Context, id string) (*User, error)
//                            ↑ luôn là tham số đầu tiên
```

Khi context bị cancel (timeout, client ngắt kết nối), mọi operation đang dùng context đó sẽ nhận được signal để dừng — tránh lãng phí tài nguyên làm việc cho một request đã "chết".

```go
// Ví dụ: query DB với context
rows, err := db.QueryContext(ctx, "SELECT * FROM users WHERE id = $1", id)
// Nếu ctx bị cancel trước khi query xong → query tự hủy
```

### Quy tắc với Context

- **Không lưu context vào struct** — luôn truyền qua parameter
- **Context là tham số đầu tiên**, tên thường là `ctx`
- **Luôn gọi `cancel()`** sau `WithTimeout` hoặc `WithCancel` — dùng `defer`
- **Không truyền `nil` context** — dùng `context.Background()` hoặc `context.TODO()` nếu chưa có context

---

## 17. `defer`, `panic`, `recover`

### `defer`

`defer` trì hoãn thực thi một function cho đến **khi function hiện tại return** — dù return bình thường hay do panic.

```go
func readFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()  // ← sẽ chạy khi readFile() return, dù return ở đâu
    
    // đọc file...
    return nil
}
// f.Close() luôn được gọi dù có error hay không
```

**Thứ tự thực thi:** nhiều defer thực thi theo thứ tự **LIFO** (Last In, First Out):

```go
defer fmt.Println("1")
defer fmt.Println("2")
defer fmt.Println("3")
// In ra: 3, 2, 1
```

### `panic`

`panic` dừng ngay execution hiện tại, unwind stack — tương tự throw exception nhưng **nghiêm trọng hơn**. Chỉ dùng cho lỗi không thể recover được:

```go
func divide(a, b int) int {
    if b == 0 {
        panic("cannot divide by zero")  // ← dừng chương trình
    }
    return a / b
}
```

**Go convention:** dùng `panic` cho lỗi programmer (programming error), không phải lỗi runtime bình thường. Lỗi bình thường thì return error.

### `recover`

`recover` bắt panic và cho phép chương trình tiếp tục. Phải dùng bên trong `defer`:

```go
func safeHandler(w http.ResponseWriter, r *http.Request) {
    defer func() {
        if err := recover(); err != nil {
            log.Printf("panic: %v", err)
            http.Error(w, "Internal Server Error", 500)
        }
    }()
    
    // code có thể panic ở đây
    riskyOperation()
}
```

Đây chính xác là những gì `middleware/recovery.go` trong project làm — bắt panic từ bất kỳ handler nào, trả `500` thay vì crash cả server.

---

## 18. Error handling trong Go

### Triết lý

Go **không có exception**. Error là giá trị bình thường, được trả về như return value:

```go
// Hầu hết function Go trả (result, error)
user, err := userService.GetUser(ctx, id)
if err != nil {
    // xử lý lỗi
    return nil, err
}
// dùng user
```

### Wrapping error

Thêm context vào error để biết lỗi xảy ra ở đâu:

```go
user, err := repo.FindByID(ctx, id)
if err != nil {
    return nil, fmt.Errorf("userService.GetUser: %w", err)
    //                                              ↑ %w wrap error gốc
}
```

### Unwrapping và kiểm tra loại error

```go
var ErrNotFound = errors.New("not found")

// Kiểm tra error có phải ErrNotFound không (kể cả khi đã wrap nhiều lớp)
if errors.Is(err, ErrNotFound) {
    // trả 404
}

// Kiểm tra error có phải type cụ thể không
var validationErr *ValidationError
if errors.As(err, &validationErr) {
    // trả 400 với validationErr.Fields
}
```

### Sentinel errors

Là các error được khai báo trước dùng để so sánh:

```go
// internal/shared/errors.go
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
    ErrConflict     = errors.New("conflict")
)

// Dùng
if errors.Is(err, shared.ErrNotFound) {
    http.Error(w, "not found", 404)
}
```

---

## 19. Struct và Embedding

### Struct

Go không có class — dùng struct để nhóm data:

```go
type User struct {
    ID        string
    Name      string
    Email     string
    CreatedAt time.Time
}

// Tạo instance
user := User{
    ID:    "123",
    Name:  "Đăng",
    Email: "dang@example.com",
}

// Method trên struct
func (u *User) IsActive() bool {
    return u.CreatedAt.After(time.Now().AddDate(-1, 0, 0))
}
```

### Embedding

Go dùng **embedding** thay vì inheritance:

```go
type BaseModel struct {
    ID        string
    CreatedAt time.Time
    UpdatedAt time.Time
}

type User struct {
    BaseModel         // ← embed BaseModel, User có tất cả field của BaseModel
    Name  string
    Email string
}

user := User{}
user.ID        // ← access field của BaseModel trực tiếp
user.CreatedAt // ← không cần user.BaseModel.CreatedAt
```

### Tags trong struct

```go
type CreateUserRequest struct {
    Name  string `json:"name" validate:"required,min=2"`
    Email string `json:"email" validate:"required,email"`
    Age   int    `json:"age" validate:"min=18"`
}
```

Tags là metadata được đọc bởi các thư viện:
- `json:"name"` → khi marshal/unmarshal JSON, dùng key "name"
- `validate:"required"` → thư viện validate đọc rule này
- `db:"user_name"` → thư viện ORM map vào column "user_name"

---

## 20. Pointer

### Pointer là gì?

Pointer lưu **địa chỉ bộ nhớ** của một giá trị thay vì bản sao của giá trị đó.

```go
x := 42
p := &x    // p là pointer trỏ tới x — & lấy địa chỉ
*p = 100   // *p dereference — thay đổi giá trị tại địa chỉ đó
fmt.Println(x)  // → 100 (x bị thay đổi qua pointer)
```

### Khi nào dùng pointer receiver trong method?

```go
// Value receiver — s là bản sao, thay đổi không ảnh hưởng original
func (s userService) badMethod() {
    s.someField = "changed"  // chỉ thay đổi bản sao
}

// Pointer receiver — s trỏ tới original, thay đổi có hiệu lực
func (s *userService) goodMethod() {
    s.someField = "changed"  // thay đổi thật sự
}
```

**Quy tắc thực tế:** Hầu hết method trong Go dùng pointer receiver `*T`. Dùng value receiver `T` khi struct rất nhỏ (1-2 field) và bạn muốn immutability.

### Pointer và nil

```go
var user *User = nil  // pointer chưa trỏ vào đâu

if user == nil {
    // check nil trước khi dùng
}

user.Name  // ← PANIC nếu user là nil — đây là nil pointer dereference
```

Nil pointer dereference là lỗi runtime phổ biến nhất trong Go — luôn check nil trước khi dùng pointer.

---

## 21. Go Runtime Stack — Tại sao Go nhanh?

### Câu hỏi cốt lõi

Node.js nổi tiếng vì **non-blocking I/O** — không block thread khi chờ DB, file, network. Nhờ vậy 1 thread xử lý được hàng nghìn request đồng thời.

Go lại dùng **blocking I/O** — khi gọi DB, goroutine block lại chờ kết quả. Vậy tại sao Go vẫn nhanh và xử lý được hàng triệu concurrent request?

### Blocking vs Non-blocking — Hiểu đúng bản chất

**Non-blocking I/O (Node.js model):**

```
Thread duy nhất
      │
      ├── Nhận request A → gửi query DB → KHÔNG chờ, tiếp tục
      ├── Nhận request B → gửi query DB → KHÔNG chờ, tiếp tục
      ├── Nhận request C → gửi query DB → KHÔNG chờ, tiếp tục
      │
      └── Event loop polling: "DB trả kết quả chưa?"
              → Có → callback → xử lý tiếp
```

Lập trình viên phải viết code bất đồng bộ (callback, Promise, async/await) — phức tạp hơn, khó debug hơn.

**Blocking I/O với Goroutine (Go model):**

```
Goroutine A (chạy trên OS Thread 1)
      │
      ├── Nhận request A
      ├── Gọi DB → BLOCK... chờ...
      │         ↓
      │   Go Scheduler phát hiện goroutine A đang block
      │         ↓
      │   Tạm thời "park" goroutine A
      │         ↓
      │   Đặt goroutine B lên OS Thread 1 chạy tiếp
      │
      ↓ (khi DB trả kết quả)
      Go Scheduler "unpark" goroutine A → tiếp tục chạy
```

Lập trình viên viết code **đồng bộ bình thường** — nhưng bên dưới Go tự động làm non-blocking.

### Tại sao Goroutine nhẹ hơn OS Thread?

| | OS Thread | Goroutine |
|---|---|---|
| Stack size ban đầu | 1–8 MB | **2–4 KB** |
| Stack size tối đa | Cố định | **Tự co giãn** (lên đến 1GB) |
| Tạo mới | ~1ms, tốn kém | **~300ns, rất rẻ** |
| Switch context | Kernel space, chậm | **User space, nhanh** |
| Số lượng thực tế | Vài nghìn | **Hàng triệu** |

Go có thể tạo 1 triệu goroutine trên 1 máy bình thường — điều không thể với OS thread.

### Stack của Goroutine tự co giãn như thế nào?

```
Goroutine mới tạo ra
        ↓
Stack = 2KB (rất nhỏ)
        ↓
Function đệ quy sâu hoặc nhiều local variable
        ↓
Stack sắp đầy → Go runtime phát hiện (stack guard check)
        ↓
Cấp phát stack mới gấp đôi (4KB)
Copy toàn bộ stack cũ sang stack mới
Cập nhật tất cả pointer
        ↓
Tiếp tục chạy bình thường
        ↓
Function return, bộ nhớ ít dùng hơn
        ↓
Stack được shrink lại (tiết kiệm RAM)
```

Đây là lý do Go dùng được hàng triệu goroutine — mỗi cái chỉ dùng đúng lượng RAM cần thiết, không cấp phát thừa.

### Syscall và Network Poller

Khi goroutine thực hiện **network I/O** (gọi DB, HTTP call...):

```
Goroutine gọi db.Query(...)
        ↓
Go runtime chuyển thành non-blocking syscall ở kernel level
        ↓
Goroutine bị park (không chiếm CPU)
        ↓
netpoller (epoll/kqueue/IOCP tùy OS) theo dõi socket
        ↓
Data từ DB về → netpoller báo Go scheduler
        ↓
Goroutine được unpark → tiếp tục chạy
```

Kết quả: **Lập trình viên viết code blocking đơn giản, nhưng Go tự làm non-blocking ở tầng thấp hơn.** Đây là điểm khác biệt lớn nhất so với Node.js — developer experience của blocking code, performance của non-blocking.

---

## 22. Go Scheduler — M:N Threading

### M:N Threading là gì?

Go dùng mô hình **M:N** — map M goroutine lên N OS thread:

```
Goroutines (M — hàng triệu)     OS Threads (N — bằng số CPU core)
      G1 ─┐
      G2 ─┤                           T1 (core 1)
      G3 ─┼──── Go Scheduler ────►    T2 (core 2)
      G4 ─┤                           T3 (core 3)
      G5 ─┘                           T4 (core 4)
     ...
```

Go Scheduler quyết định goroutine nào chạy trên thread nào — hoàn toàn ở user space, không cần kernel.

### GMP Model

Go Scheduler dùng mô hình **GMP**:

```
G = Goroutine    — unit of work
M = Machine      — OS thread thật
P = Processor    — logical processor, thường = số CPU core (GOMAXPROCS)
```

```
P1 (Processor 1)           P2 (Processor 2)
│                           │
├── Local Queue: [G3,G4]   ├── Local Queue: [G7,G8]
│                           │
└── chạy trên M1 (Thread)  └── chạy trên M2 (Thread)

Global Queue: [G9, G10, G11...]  ← overflow từ local queue
```

**Flow:**
1. G mới tạo ra → vào Local Queue của P đang chạy
2. P lấy G từ Local Queue → assign cho M để chạy
3. Local Queue rỗng → P "steal" G từ P khác (work stealing)
4. G block vào syscall → M detach khỏi P → P lấy M khác tiếp tục chạy

### GOMAXPROCS

```go
import "runtime"

// Mặc định = số CPU core của máy
fmt.Println(runtime.GOMAXPROCS(0))  // in ra số P hiện tại

// Đặt thủ công (hiếm khi cần)
runtime.GOMAXPROCS(4)  // dùng 4 processor
```

Hoặc qua environment variable:
```bash
GOMAXPROCS=2 ./api   # chỉ dùng 2 CPU core
```

### Work Stealing — Tự cân bằng tải

Khi P1 hết việc (local queue rỗng), thay vì ngồi chờ:

```
P1: "Local queue trống, đi xin việc..."
        ↓
P1 xem Global Queue → có G không? → lấy về
        ↓
Không có → P1 "steal" một nửa Local Queue của P2
        ↓
P1 tiếp tục chạy — không lãng phí CPU
```

Điều này đảm bảo CPU luôn được sử dụng tối đa mà không cần lập trình viên quản lý.

---

## 23. Memory Model và Escape Analysis

### Heap vs Stack trong Go

Go tự quyết định biến nào nằm trên **stack** (nhanh, tự giải phóng), biến nào nằm trên **heap** (chậm hơn, cần GC):

```go
func createUser() *User {
    u := User{Name: "Đăng"}  // u được tạo ở đâu?
    return &u                 // trả pointer ra ngoài
}
// → u phải nằm trên HEAP vì pointer của nó sống lâu hơn function
```

```go
func calculate() int {
    x := 42    // x chỉ dùng trong function này
    return x   // trả value, không phải pointer
}
// → x nằm trên STACK, tự giải phóng khi function return
```

### Escape Analysis

Go compiler phân tích xem biến có "escape" ra khỏi function không:

```bash
# Xem compiler quyết định gì
go build -gcflags="-m" ./...

# Output ví dụ:
# ./user.go:10:6: &u escapes to heap   ← u lên heap vì return pointer
# ./calc.go:5:3: x does not escape     ← x ở lại stack
```

**Tại sao quan tâm?** Biến trên heap → GC phải dọn → tốn thời gian. Biến trên stack → tự giải phóng → nhanh hơn. Khi tối ưu performance, giảm allocation trên heap là mục tiêu.

### Garbage Collector của Go

Go dùng **tricolor mark-and-sweep GC** với mục tiêu latency thấp (< 1ms pause):

```
Giai đoạn 1 — Mark (concurrent, chạy song song với code):
  GC đánh dấu tất cả object còn được reference

Giai đoạn 2 — Sweep (concurrent):
  GC giải phóng object không được đánh dấu

STW (Stop The World) — rất ngắn:
  Chỉ xảy ra ở đầu/cuối mỗi giai đoạn, < 1ms
```

So với Java GC (có thể pause hàng trăm ms), Go GC ưu tiên latency thấp — quan trọng với web server.

---

## 24. Slice và Array — Hiểu đúng bản chất

### Array — Fixed size, ít dùng trực tiếp

```go
var arr [5]int          // array 5 phần tử, size cố định
arr := [3]string{"a", "b", "c"}
arr := [...]int{1, 2, 3}  // compiler tự đếm size
```

Array trong Go là **value type** — gán hay truyền vào function là copy toàn bộ:

```go
a := [3]int{1, 2, 3}
b := a          // copy toàn bộ array
b[0] = 99
fmt.Println(a)  // [1 2 3] — a không thay đổi
```

### Slice — Dynamic, dùng thường xuyên

Slice là **view vào một array** — gồm 3 field:

```
Slice header (24 bytes):
┌──────────┬──────┬──────────┐
│  pointer │ len  │   cap    │
│ (8 bytes)│(8b)  │  (8b)    │
└──────────┴──────┴──────────┘
     │
     ▼
Underlying Array: [1][2][3][4][5]
```

```go
arr := [5]int{1, 2, 3, 4, 5}
s := arr[1:4]   // slice: pointer→arr[1], len=3, cap=4
// s = [2, 3, 4]
```

### Cạm bẫy 1: Slice dùng chung underlying array

```go
a := []int{1, 2, 3, 4, 5}
b := a[1:3]     // b = [2, 3], cùng array với a

b[0] = 99       // sửa b
fmt.Println(a)  // [1 99 3 4 5] — a BỊ THAY ĐỔI!
```

Khi muốn slice độc lập:
```go
b := make([]int, len(a[1:3]))
copy(b, a[1:3])  // copy data sang array mới
```

### Cạm bẫy 2: append và reallocation

```go
s := make([]int, 3, 5)  // len=3, cap=5
s = append(s, 4)        // len=4, cap=5, cùng array

// Khi vượt cap:
s = append(s, 5, 6)     // len=6, cap > 5
// Go cấp phát array mới (thường cap*2), copy data sang
// s giờ trỏ vào array MỚI
```

```go
// Tạo slice đúng cách khi biết trước size
users := make([]User, 0, 100)  // pre-allocate cap=100, tránh reallocation
for i := 0; i < 100; i++ {
    users = append(users, User{})
}
```

### Cạm bẫy 3: Nil slice vs Empty slice

```go
var s []int         // nil slice — s == nil là true
s := []int{}        // empty slice — s == nil là false
s := make([]int, 0) // empty slice

// Cả 3 đều dùng append được, len() = 0
// Nhưng khác khi marshal JSON:
json.Marshal(nil slice)    // → null
json.Marshal(empty slice)  // → []
```

---

## 25. Map — Cạm bẫy thường gặp

### Cơ bản

```go
// Tạo map
m := make(map[string]int)
m := map[string]int{"a": 1, "b": 2}

// Đọc — luôn trả zero value nếu key không tồn tại
val := m["key"]            // 0 nếu không có key
val, ok := m["key"]        // ok = false nếu không có key — luôn dùng dạng này

// Ghi
m["key"] = 42

// Xóa
delete(m, "key")

// Iterate (thứ tự random mỗi lần)
for k, v := range m {
    fmt.Println(k, v)
}
```

### Cạm bẫy 1: Nil map panic

```go
var m map[string]int  // nil map
m["key"] = 1          // PANIC: assignment to entry in nil map

// Phải khởi tạo trước
m := make(map[string]int)
m["key"] = 1  // OK
```

### Cạm bẫy 2: Map không thread-safe

```go
// NGUY HIỂM — concurrent read/write vào map
m := make(map[string]int)

go func() { m["a"] = 1 }()  // goroutine 1 ghi
go func() { _ = m["a"] }()  // goroutine 2 đọc

// → race condition → panic hoặc data corruption
```

Giải pháp:
```go
// Dùng sync.RWMutex
type SafeMap struct {
    mu sync.RWMutex
    m  map[string]int
}

func (s *SafeMap) Set(k string, v int) {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.m[k] = v
}

// Hoặc dùng sync.Map (built-in, tối ưu cho concurrent access)
var m sync.Map
m.Store("key", 42)
val, ok := m.Load("key")
```

---

## 26. sync Package — Đồng bộ hóa

### sync.Mutex — Khóa độc quyền

```go
type Counter struct {
    mu    sync.Mutex
    value int
}

func (c *Counter) Increment() {
    c.mu.Lock()           // chỉ 1 goroutine vào được
    defer c.mu.Unlock()   // luôn dùng defer để tránh quên unlock
    c.value++
}

func (c *Counter) Get() int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.value
}
```

### sync.RWMutex — Khóa đọc/ghi

Cho phép nhiều goroutine **đọc cùng lúc**, nhưng chỉ 1 goroutine **ghi** tại một thời điểm:

```go
type Cache struct {
    mu   sync.RWMutex
    data map[string]string
}

func (c *Cache) Get(key string) string {
    c.mu.RLock()         // nhiều goroutine có thể RLock cùng lúc
    defer c.mu.RUnlock()
    return c.data[key]
}

func (c *Cache) Set(key, value string) {
    c.mu.Lock()          // chỉ 1 goroutine Lock tại một thời điểm
    defer c.mu.Unlock()
    c.data[key] = value
}
```

### sync.WaitGroup — Chờ nhiều goroutine xong

```go
func processUsers(users []User) {
    var wg sync.WaitGroup

    for _, u := range users {
        wg.Add(1)              // đăng ký 1 goroutine
        go func(user User) {
            defer wg.Done()    // báo xong khi return
            processUser(user)
        }(u)
    }

    wg.Wait()  // block cho đến khi tất cả goroutine Done()
    fmt.Println("Tất cả users đã được xử lý")
}
```

### sync.Once — Chạy đúng 1 lần

```go
var (
    instance *DB
    once     sync.Once
)

func GetDB() *DB {
    once.Do(func() {
        // Chỉ chạy 1 lần dù gọi GetDB() từ 1000 goroutine
        instance = connectDB()
    })
    return instance
}
```

Dùng phổ biến cho **singleton pattern** — khởi tạo DB connection, config, logger một lần duy nhất.

### sync.Pool — Tái dùng object, giảm GC pressure

```go
var bufPool = sync.Pool{
    New: func() interface{} {
        return make([]byte, 0, 4096)  // tạo mới nếu pool trống
    },
}

func handleRequest() {
    buf := bufPool.Get().([]byte)  // lấy từ pool
    defer bufPool.Put(buf[:0])     // trả về pool khi xong

    // dùng buf để xử lý request
    // không cần cấp phát memory mới mỗi request
}
```

---

## 27. `select` Statement

`select` cho phép goroutine chờ **nhiều channel operation** cùng lúc — chọn cái nào sẵn sàng trước:

```go
select {
case msg := <-ch1:
    fmt.Println("Nhận từ ch1:", msg)
case msg := <-ch2:
    fmt.Println("Nhận từ ch2:", msg)
case ch3 <- "hello":
    fmt.Println("Gửi vào ch3 thành công")
default:
    fmt.Println("Không có channel nào sẵn sàng")
    // default giúp select không block
}
```

### Pattern: Timeout với select

```go
func fetchWithTimeout(url string) (string, error) {
    ch := make(chan string, 1)

    go func() {
        result := fetch(url)  // có thể chậm
        ch <- result
    }()

    select {
    case result := <-ch:
        return result, nil
    case <-time.After(5 * time.Second):
        return "", errors.New("timeout sau 5 giây")
    }
}
```

### Pattern: Done channel để dừng goroutine

```go
func worker(done <-chan struct{}) {
    for {
        select {
        case <-done:
            fmt.Println("Worker dừng lại")
            return
        default:
            doWork()
        }
    }
}

done := make(chan struct{})
go worker(done)

// Khi muốn dừng worker:
close(done)  // đóng channel → tất cả goroutine đang select trên done đều nhận được
```

---

## 28. Generics (Go 1.18+)

### Generics là gì?

Trước Go 1.18, muốn viết function xử lý nhiều type phải dùng `interface{}` và type assertion:

```go
// Trước generics — không type-safe
func Contains(slice []interface{}, item interface{}) bool {
    for _, v := range slice {
        if v == item { return true }
    }
    return false
}
```

Với generics:

```go
// Với generics — type-safe, compiler check được
func Contains[T comparable](slice []T, item T) bool {
    for _, v := range slice {
        if v == item { return true }
    }
    return false
}

// Dùng
Contains([]int{1, 2, 3}, 2)           // ✅
Contains([]string{"a", "b"}, "a")     // ✅
```

### Type Constraint

```go
// comparable — có thể dùng == và !=
func Contains[T comparable](s []T, v T) bool { ... }

// any — bất kỳ type nào (= interface{})
func Print[T any](v T) { fmt.Println(v) }

// Custom constraint — chỉ nhận numeric types
type Number interface {
    int | int32 | int64 | float32 | float64
}

func Sum[T Number](nums []T) T {
    var total T
    for _, n := range nums {
        total += n
    }
    return total
}

Sum([]int{1, 2, 3})        // = 6
Sum([]float64{1.1, 2.2})   // = 3.3
```

### Khi nào dùng Generics?

Dùng khi viết **utility function** dùng cho nhiều type: collections (filter, map, reduce), data structures (stack, queue, set). Không dùng cho business logic — thường không cần.

---

## 29. `init()` Function

### `init()` là gì?

Mỗi package có thể có một hoặc nhiều function `init()` — tự động chạy **trước `main()`**, sau khi tất cả variable được khởi tạo:

```go
// internal/config/config.go
var defaultTimeout = 30 * time.Second  // khởi tạo trước

func init() {
    // Chạy tự động khi package được import
    // Thường dùng để: register, validate config, setup global state
    if os.Getenv("APP_ENV") == "" {
        os.Setenv("APP_ENV", "development")
    }
}
```

### Thứ tự thực thi

```
Import packages
      ↓
Khởi tạo package-level variables
      ↓
Chạy init() của từng package (theo thứ tự import)
      ↓
Chạy main()
```

### Dùng phổ biến ở đâu?

```go
// Đăng ký database driver
import _ "github.com/lib/pq"  // ← import blank, chỉ để chạy init()

// Trong thư viện pq:
func init() {
    sql.Register("postgres", &Driver{})  // đăng ký driver với database/sql
}
```

Dấu `_` trước import nghĩa là: **"tôi không dùng package này trực tiếp, chỉ muốn chạy init() của nó"**.

### Cảnh báo

- Tránh logic phức tạp trong `init()` — khó test, khó debug
- `init()` không nhận tham số, không trả về — không xử lý error được
- Nhiều `init()` trong cùng file chạy theo thứ tự từ trên xuống

---

## 30. Blank Identifier `_`

`_` là cách nói với Go: **"tôi biết có giá trị này nhưng tôi không cần"**:

```go
// Bỏ qua return value thứ 2
val, _ := strconv.Atoi("42")   // bỏ qua error (cẩn thận!)

// Bỏ qua index khi range
for _, v := range slice {      // chỉ cần value, không cần index
    fmt.Println(v)
}

// Import chỉ để chạy init()
import _ "github.com/lib/pq"

// Kiểm tra type implement interface tại compile time
var _ UserService = (*userServiceImpl)(nil)
//  ↑ blank     ↑ phải implement UserService
// Nếu userServiceImpl thiếu method → compile error ngay
// Đây là pattern rất hay để đảm bảo implementation đúng interface
```

---

## 31. Các file cấu hình thường gặp trong Go project

### `.goreleaser.yml` — Build và release binary

Dùng khi cần release binary cho nhiều OS/arch cùng lúc (GitHub Releases, Homebrew...).

```yaml
# .goreleaser.yml
project_name: api

builds:
  - env:
      - CGO_ENABLED=0       # Build static binary, không cần C compiler
    goos:
      - linux
      - windows
      - darwin              # macOS
    goarch:
      - amd64
      - arm64

archives:
  - format: tar.gz
    format_overrides:
      - goos: windows
        format: zip

checksum:
  name_template: 'checksums.txt'

release:
  github:
    owner: DANG-PH
    name: game-service-go
```

**Được gọi khi nào:** `goreleaser release` hoặc GitHub Actions khi push tag (`v1.0.0`).

---

### `.mockery.yaml` — Generate mock từ interface

Mockery tự động generate mock implementation từ Go interface — dùng trong unit test.

```yaml
# .mockery.yaml
with-expecter: true        # Generate Expecter API — type-safe mock setup
dir: "test/mock"           # Output directory
outpkg: "mock"             # Package name của generated file
filename: "{{.InterfaceName}}.go"

packages:
  github.com/DANG-PH/game-service-go/internal/user:
    interfaces:
      UserService:          # Generate mock cho interface này
      UserRepository:
```

**Được gọi khi nào:** `mockery --config=.mockery.yaml` hoặc `go generate ./...` (nếu có directive).

**Output:**
```go
// test/mock/UserService.go (auto-generated, không edit tay)
type UserService struct { mock.Mock }

func (m *UserService) GetUser(ctx context.Context, id string) (*user.User, error) {
    args := m.Called(ctx, id)
    return args.Get(0).(*user.User), args.Error(1)
}
```

---

### `buf.yaml` và `buf.gen.yaml` — Quản lý Protobuf

Thay thế cho `protoc` thủ công — quản lý dependencies và generate code từ `.proto`.

```yaml
# buf.yaml — khai báo module protobuf
version: v1
name: buf.build/DANG-PH/game-service

deps:
  - buf.build/googleapis/googleapis   # Google common protos

lint:
  use:
    - DEFAULT                         # Bật tất cả lint rule mặc định
  except:
    - PACKAGE_VERSION_SUFFIX          # Tắt rule này nếu không dùng versioned package

breaking:
  use:
    - FILE                            # Phát hiện breaking change ở level file
```

```yaml
# buf.gen.yaml — cấu hình code generation
version: v1
plugins:
  - plugin: go                        # Generate Go structs từ .proto
    out: internal/transport/grpc/pb
    opt:
      - paths=source_relative

  - plugin: go-grpc                   # Generate gRPC service stubs
    out: internal/transport/grpc/pb
    opt:
      - paths=source_relative
```

**Được gọi khi nào:** `buf generate` hoặc `make proto`.

---

### `sqlc.yaml` — Generate type-safe SQL

Sqlc đọc file `.sql` và generate Go code type-safe — không cần ORM, không cần viết tay.

```yaml
# sqlc.yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "internal/user/postgres/queries.sql"   # File SQL bạn viết
    schema: "migrations/postgres/"                   # Schema hiện tại
    gen:
      go:
        package: "postgres"
        out: "internal/user/postgres"
        emit_json_tags: true
        emit_interface: true    # Generate interface cho dễ mock
```

**Viết SQL:**
```sql
-- internal/user/postgres/queries.sql

-- name: GetUser :one
SELECT * FROM users WHERE id = $1 LIMIT 1;

-- name: ListUsers :many
SELECT * FROM users ORDER BY created_at DESC;

-- name: CreateUser :one
INSERT INTO users (id, name, email) VALUES ($1, $2, $3) RETURNING *;
```

**Output được generate:**
```go
// Sqlc generate ra code này — không edit tay
func (q *Queries) GetUser(ctx context.Context, id string) (User, error) { ... }
func (q *Queries) ListUsers(ctx context.Context) ([]User, error) { ... }
func (q *Queries) CreateUser(ctx context.Context, arg CreateUserParams) (User, error) { ... }
```

**Được gọi khi nào:** `sqlc generate` hoặc `make generate`.

---

### `.github/workflows/ci.yml` — GitHub Actions cho Go

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'
          cache: true              # Cache Go modules — tăng tốc CI

      - name: Download dependencies
        run: go mod download

      - name: Run linter
        uses: golangci/golangci-lint-action@v4
        with:
          version: latest

      - name: Run tests
        run: go test ./... -race -cover -coverprofile=coverage.out

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: coverage.out
```

**Được gọi khi nào:** Tự động khi push lên `main` hoặc tạo Pull Request.

---

### `testdata/` — Fixtures cho test

Convention của Go: thư mục `testdata/` trong package chứa data dùng cho test — JSON fixtures, file mẫu, response mẫu:

```
internal/user/
├── service_impl.go
├── service_impl_test.go
└── testdata/
    ├── create_user_request.json
    ├── user_response.json
    └── invalid_request.json
```

```go
// Đọc testdata trong test
func TestCreateUser(t *testing.T) {
    data, _ := os.ReadFile("testdata/create_user_request.json")
    // ...
}
```

Go test runner tự động set working directory về package directory — nên path `testdata/...` luôn đúng.

---

## 32. `go generate` và Tooling

### `go generate` là gì?

`go generate` đọc comment đặc biệt trong source code và chạy lệnh tương ứng:

```go
// internal/user/service.go

//go:generate mockery --name=UserService --output=../../test/mock
type UserService interface {
    GetUser(ctx context.Context, id string) (*User, error)
}

//go:generate stringer -type=Status
type Status int
const (
    StatusActive Status = iota
    StatusInactive
    StatusBanned
)
```

```bash
go generate ./...  # Chạy tất cả //go:generate trong project
```

### `stringer` — Generate String() cho enum

```bash
go install golang.org/x/tools/cmd/stringer@latest
```

```go
//go:generate stringer -type=Status
type Status int
const (
    StatusActive   Status = iota  // 0
    StatusInactive                 // 1
    StatusBanned                   // 2
)

// Sau khi generate:
fmt.Println(StatusActive)   // In ra "StatusActive" thay vì "0"
```

---

## 33. Testing nâng cao

### Table-driven test — Pattern chuẩn của Go

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive numbers", 1, 2, 3},
        {"negative numbers", -1, -2, -3},
        {"zero", 0, 5, 5},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Add(tt.a, tt.b)
            if result != tt.expected {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, result, tt.expected)
            }
        })
    }
}
```

Chạy đúng 1 subtest:
```bash
go test -run "TestAdd/positive_numbers" ./...
```

### testify — Assertion library phổ biến nhất

```bash
go get github.com/stretchr/testify
```

```go
import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestCreateUser(t *testing.T) {
    user, err := service.CreateUser(ctx, req)

    require.NoError(t, err)           // fail ngay nếu có error (không tiếp tục)
    assert.Equal(t, "Đăng", user.Name) // tiếp tục dù fail
    assert.NotEmpty(t, user.ID)
    assert.True(t, user.IsActive())
}
```

**Khác biệt `require` vs `assert`:**
- `assert` — ghi nhận failure nhưng tiếp tục chạy test
- `require` — fail ngay, không chạy tiếp (dùng khi bước sau phụ thuộc bước này)

### httptest — Test HTTP handler không cần server thật

```go
import "net/http/httptest"

func TestUserHandler(t *testing.T) {
    // Tạo request
    req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader(`{"name":"Đăng"}`))
    req.Header.Set("Content-Type", "application/json")

    // Tạo response recorder
    w := httptest.NewRecorder()

    // Gọi handler trực tiếp
    handler.CreateUser(w, req)

    // Check kết quả
    resp := w.Result()
    assert.Equal(t, http.StatusCreated, resp.StatusCode)
}
```

### Benchmark test

```go
func BenchmarkAdd(b *testing.B) {
    for i := 0; i < b.N; i++ {  // b.N được Go tự chọn để đủ accurate
        Add(1, 2)
    }
}
```

```bash
go test -bench=. ./...               # Chạy tất cả benchmark
go test -bench=BenchmarkAdd -benchmem ./...  # Kèm memory stats
```

Output:
```
BenchmarkAdd-8    1000000000    0.234 ns/op    0 B/op    0 allocs/op
```

---

## 34. Profiling — Tìm bottleneck

### pprof — Built-in profiler

```go
import _ "net/http/pprof"  // chỉ cần import là có profiling endpoint

// Thêm vào server (chỉ trong development!)
go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil))
}()
```

```bash
# CPU profile — xem function nào chiếm nhiều CPU nhất
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30

# Memory profile — xem allocation nhiều ở đâu
go tool pprof http://localhost:6060/debug/pprof/heap

# Goroutine dump — xem goroutine nào đang làm gì
go tool pprof http://localhost:6060/debug/pprof/goroutine
```

Sau khi vào pprof interactive shell:
```
(pprof) top10     # 10 function tốn CPU nhất
(pprof) web       # Mở flame graph trong browser (cần graphviz)
(pprof) list main # Xem từng dòng code
```

### Benchmark profile

```bash
# Vừa benchmark vừa thu thập CPU profile
go test -bench=. -cpuprofile=cpu.prof ./...
go tool pprof cpu.prof

# Memory profile
go test -bench=. -memprofile=mem.prof ./...
go tool pprof mem.prof
```

---

## 35. Những lỗi phổ biến của người mới học Go

### ❌ Lỗi 1: Capture loop variable trong goroutine

```go
// SAI — tất cả goroutine đều dùng cùng biến i
for i := 0; i < 5; i++ {
    go func() {
        fmt.Println(i)  // i có thể là 5 khi goroutine chạy
    }()
}

// ĐÚNG — truyền i như tham số
for i := 0; i < 5; i++ {
    go func(i int) {
        fmt.Println(i)  // i là bản sao tại thời điểm gọi
    }(i)
}

// Hoặc trong Go 1.22+, loop variable được copy tự động — không còn bug này
```

### ❌ Lỗi 2: Goroutine leak

```go
// SAI — goroutine bị leak nếu không ai đọc từ ch
func leak() {
    ch := make(chan int)
    go func() {
        ch <- heavyComputation()  // block mãi nếu không ai đọc
    }()
    // return mà không đọc ch → goroutine stuck forever
}

// ĐÚNG — dùng buffered channel hoặc context để cancel
func noLeak(ctx context.Context) {
    ch := make(chan int, 1)  // buffered — goroutine không bị block
    go func() {
        select {
        case ch <- heavyComputation():
        case <-ctx.Done():  // cancel nếu context done
        }
    }()
}
```

### ❌ Lỗi 3: Quên close channel khi range

```go
// SAI — range block mãi vì không biết channel đã hết data
ch := make(chan int)
go func() {
    for i := 0; i < 5; i++ {
        ch <- i
    }
    // quên close(ch) → goroutine đọc sẽ block forever
}()
for v := range ch { fmt.Println(v) }

// ĐÚNG
go func() {
    defer close(ch)  // luôn close khi producer xong
    for i := 0; i < 5; i++ { ch <- i }
}()
for v := range ch { fmt.Println(v) }
```

### ❌ Lỗi 4: Dùng sync.Mutex sai cách

```go
// SAI — copy mutex
type Worker struct{ mu sync.Mutex }
w1 := Worker{}
w2 := w1  // ← KHÔNG được copy struct chứa mutex

// ĐÚNG — dùng pointer
w2 := &w1  // hoặc truyền qua pointer
```

### ❌ Lỗi 5: Return trong defer

```go
// Không làm được — defer không thể thay đổi return value bình thường
func wrong() int {
    defer func() {
        return 42  // return này không ảnh hưởng gì
    }()
    return 0  // hàm vẫn trả 0
}

// Muốn thay đổi return value trong defer → dùng named return
func correct() (result int) {
    defer func() {
        result = 42  // thay đổi named return variable
    }()
    return 0  // defer chạy sau, đổi result thành 42
}
```

### ❌ Lỗi 6: Interface nil không phải nil

```go
// Đây là bug nổi tiếng và confusing nhất của Go
func getError() error {
    var err *MyError = nil  // typed nil pointer
    return err              // ← KHÔNG phải nil interface!
}

if getError() != nil {
    // Vào đây dù tưởng là nil!
    // Vì interface có 2 field: (type, value)
    // type = *MyError, value = nil → interface KHÔNG nil
}

// ĐÚNG — trả nil interface thật sự
func getError() error {
    var err *MyError = nil
    if err == nil {
        return nil  // trả nil interface
    }
    return err
}
```

---

## 36. Thuật ngữ chuyên ngành

| Thuật ngữ | Giải thích |
|---|---|
| **Module** | Đơn vị phân phối code trong Go — 1 repo thường = 1 module. Khai báo trong `go.mod`. |
| **Package** | Đơn vị tổ chức code trong Go — 1 folder = 1 package. Khai báo bằng `package <tên>` đầu file. |
| **Import path** | Đường dẫn dùng để import package: `"github.com/DANG-PH/game-service-go/internal/config"` |
| **Goroutine** | Lightweight thread của Go — tạo bằng từ khóa `go`. Có thể chạy hàng triệu goroutine cùng lúc. |
| **Channel** | Pipeline để goroutine giao tiếp an toàn — truyền data không cần lock. |
| **Buffered channel** | Channel có buffer: `make(chan int, 10)` — gửi không block cho đến khi buffer đầy. |
| **Interface** | Contract định nghĩa method mà một type phải có. Go dùng implicit implementation. |
| **Receiver** | Type mà method gắn vào: `func (u *User) Save()` — `*User` là receiver. |
| **Pointer receiver** | `func (s *Service) Method()` — method có thể thay đổi state của struct. |
| **Value receiver** | `func (s Service) Method()` — method nhận bản sao, không thay đổi original. |
| **Embedding** | Nhúng struct vào struct khác để tái dùng field/method — Go thay thế inheritance bằng cách này. |
| **Defer** | Trì hoãn thực thi function đến khi function hiện tại return. |
| **Panic** | Dừng chương trình ngay lập tức — dùng cho lỗi không thể recover. |
| **Recover** | Bắt panic trong `defer`, cho phép chương trình tiếp tục. |
| **Sentinel error** | Error được khai báo trước để so sánh: `var ErrNotFound = errors.New("not found")`. |
| **Error wrapping** | Thêm context vào error: `fmt.Errorf("context: %w", err)`. |
| **Context** | Mang thông tin xuyên suốt call chain: timeout, cancellation, request-scoped values. |
| **Race condition** | Khi 2 goroutine cùng đọc/ghi 1 biến mà không sync → kết quả không xác định. |
| **Race detector** | Tool build vào Go (`-race`) để phát hiện race condition lúc runtime. |
| **Build tag** | Điều kiện để compiler include/exclude file: `//go:build integration`. |
| **Linter** | Tool phân tích code tĩnh — tìm bug, style issue, security vulnerability mà không chạy code. |
| **golangci-lint** | Meta-linter: gộp nhiều linter vào 1 tool, chạy song song, dùng 1 file config. |
| **go.mod** | File khai báo module name và dependencies — tương đương `package.json`. |
| **go.sum** | File checksum của dependencies — đảm bảo integrity khi download. |
| **Makefile** | File định nghĩa shortcut commands. `make dev` thay vì gõ lệnh dài. |
| **Air** | Hot-reload tool cho Go — tự rebuild và restart server khi save file. |
| **Binary** | File thực thi được compile từ Go code. |
| **Static binary** | Binary không phụ thuộc external library — copy sang máy khác chạy được ngay. Go tạo static binary mặc định. |
| **CGO_ENABLED=0** | Tắt C interop khi build — tạo static binary thuần Go, chạy được trong container Alpine. |
| **Cyclomatic complexity** | Đo độ phức tạp của function — mỗi nhánh điều kiện tăng 1 điểm. Cao → khó test, khó đọc. |
| **Dead code** | Code không bao giờ được chạy — compiler/linter có thể phát hiện. |
| **nil** | Zero value của pointer, interface, map, slice, channel, function. Phải check nil trước khi dùng. |
| **Zero value** | Giá trị mặc định khi khai báo biến không gán: `int`→`0`, `string`→`""`, `bool`→`false`, pointer→`nil`. |
| **Variadic function** | Function nhận số lượng argument tùy ý: `func sum(nums ...int)`. |
| **Type assertion** | Lấy underlying type từ interface: `val, ok := x.(string)`. Luôn dùng dạng có `ok` để tránh panic. |
| **Type switch** | Switch theo type: `switch v := x.(type) { case string: ... case int: ... }` |
| **Method set** | Tập hợp methods mà một type có — quyết định type đó implement interface nào. |
| **Dependency injection** | Truyền dependency vào qua constructor thay vì tạo bên trong — dễ test, dễ swap implementation. |
| **Graceful shutdown** | Tắt server không crash đột ngột — chờ request đang xử lý xong rồi mới tắt. |
| **GMP** | Goroutine-Machine-Processor — mô hình scheduler của Go runtime. |
| **GOMAXPROCS** | Số P (processor) Go dùng — mặc định = số CPU core. |
| **Escape analysis** | Compiler phân tích biến nào lên heap, biến nào ở stack. |
| **GC (Garbage Collector)** | Bộ dọn rác tự động của Go — tricolor mark-and-sweep, pause < 1ms. |
| **STW (Stop The World)** | Khoảnh khắc GC tạm dừng tất cả goroutine — rất ngắn trong Go (< 1ms). |
| **Heap** | Vùng nhớ cấp phát động — GC quản lý. Biến "escape" ra khỏi function thì lên heap. |
| **Stack** | Vùng nhớ nhanh, tự giải phóng khi function return. Goroutine stack bắt đầu 2KB, tự co giãn. |
| **Work stealing** | P rảnh việc "ăn cắp" goroutine từ P khác — tự cân bằng tải. |
| **Blocking I/O** | Goroutine block khi chờ I/O — Go scheduler chạy goroutine khác trong lúc chờ. |
| **netpoller** | Component của Go runtime dùng epoll/kqueue/IOCP để theo dõi network I/O non-blocking. |
| **Goroutine leak** | Goroutine bị stuck, không bao giờ kết thúc — tích lũy → OOM. |
| **pprof** | Built-in profiler của Go — phân tích CPU, memory, goroutine. |
| **Benchmark** | Test đo performance: `func BenchmarkXxx(b *testing.B)`. |
| **Table-driven test** | Pattern test phổ biến trong Go — dùng slice of struct để test nhiều case. |
| **httptest** | Package built-in để test HTTP handler không cần server thật. |
| **sync.Mutex** | Khóa độc quyền — chỉ 1 goroutine access tại một thời điểm. |
| **sync.RWMutex** | Khóa đọc/ghi — nhiều goroutine đọc cùng lúc, chỉ 1 goroutine ghi. |
| **sync.WaitGroup** | Chờ nhiều goroutine hoàn thành trước khi tiếp tục. |
| **sync.Once** | Đảm bảo một đoạn code chỉ chạy đúng 1 lần, thread-safe. |
| **sync.Pool** | Pool tái dùng object — giảm GC pressure khi cấp phát nhiều object ngắn hạn. |
| **select** | Chờ nhiều channel operation — chọn cái nào sẵn sàng trước. |
| **Generics** | Viết code dùng được cho nhiều type — type parameter: `func Fn[T any](v T)`. |
| **Type constraint** | Giới hạn type trong generics: `[T comparable]`, `[T int \| float64]`. |
| **init()** | Function tự động chạy khi package được import, trước `main()`. |
| **Blank import** | `import _ "pkg"` — chỉ chạy `init()` của package, không dùng symbol nào. |
| **go generate** | Chạy code generator theo directive `//go:generate` trong source file. |
| **mockery** | Tool generate mock từ Go interface — dùng trong unit test. |
| **sqlc** | Generate type-safe Go code từ SQL query. |
| **buf** | Tool quản lý Protobuf — lint, generate, check breaking change. |
| **Escape to heap** | Khi compiler quyết định biến phải lên heap thay vì stack. |
| **Allocs/op** | Số lần cấp phát memory mỗi operation — metric benchmark. |
| **ns/op** | Nanosecond per operation — metric benchmark. |

---

<p align="center"><sub>Tài liệu này dành cho dev mới — cập nhật khi có khái niệm mới xuất hiện trong project.</sub></p>