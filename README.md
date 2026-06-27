# Workspace

Team workspace với shared memory qua Graphiti knowledge graph. Mọi quyết định, context, và architecture được lưu vào Neo4j — các thành viên không bao giờ mất context giữa các session.

## Mục lục

- [Cấu trúc](#cấu-trúc)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Cấu hình](#cấu-hình)
- [Services](#services)
- [Maintenance](#maintenance)
- [Team Setup](#team-setup-shared-server)
- [Thêm Tool Mới](#thêm-tool-mới)

---

## Cấu trúc

```
workspace/
├── docker-compose.yml          # Root compose — include tất cả tools
├── .env.example                # Template — copy thành .env để dùng
├── .env                        # Config thực tế (không commit)
├── scripts/
│   └── start.sh                # Script khởi động (tạo network + start services)
├── .claude/
│   └── settings.json           # Claude Code tự động kết nối MCP khi mở workspace
├── CLAUDE.md                   # Hướng dẫn Claude dùng shared memory
└── tools/
    ├── neo4j/
    │   └── docker-compose.yml
    └── graphiti/
        ├── docker-compose.yml  # Build từ source (không dùng prebuilt image)
        ├── Dockerfile          # Custom build với cross-encoder patch
        ├── config.yaml         # Graphiti server config (mount vào container)
        └── graphiti/           # git submodule — github.com/getzep/graphiti
```

---

## Prerequisites

| Yêu cầu | Version tối thiểu | Cài đặt |
|---------|-------------------|---------|
| Docker | 24.0+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.20+ (plugin) | Bundled với Docker Desktop |
| Git | 2.25+ | Cần cho `--recurse-submodules` |
| API key | ít nhất 1 LLM provider | Xem phần [Cấu hình](#cấu-hình) |

---

## Quick Start

### 1. Clone repository

```bash
# Clone kèm submodule (graphiti source)
git clone --recurse-submodules <repo-url>
cd workspace

# Nếu đã clone mà chưa init submodule
git submodule update --init --recursive
```

### 2. Tạo file cấu hình

```bash
cp .env.example .env
```

Mở `.env` và điền **tối thiểu** những biến sau:

| Biến | Bắt buộc | Ghi chú |
|------|----------|---------|
| `PROJECT_NAME` | Có | Prefix cho container/network name |
| `NEO4J_PASSWORD` | Có | Đổi khỏi giá trị mặc định |
| `GOOGLE_API_KEY` | Nếu dùng Gemini | LLM + Embedder + Reranker |
| Hoặc key của provider khác | Tùy chọn | Xem [Cấu hình](#cấu-hình) |

### 3. Khởi động

```bash
bash scripts/start.sh
```

Script tự động tạo Docker network và start tất cả services.

### 4. Kiểm tra

```bash
# Graphiti MCP
curl http://localhost:8001/health
# → {"status":"healthy","service":"graphiti-mcp"}

# Neo4j Browser (đăng nhập bằng NEO4J_USER / NEO4J_PASSWORD)
open http://localhost:7474
```

> Claude Code tự động kết nối MCP khi mở workspace này nhờ `.claude/settings.json`.

---

## Cấu hình

Ba thành phần được config **hoàn toàn độc lập** — mỗi thứ có thể dùng provider khác nhau:

```
LLM_PROVIDER     →  xử lý text, extract entities, summarize
EMBEDDER_PROVIDER →  tạo vector cho semantic search
RERANKER_PROVIDER →  chấm điểm lại kết quả search (cross-encoder)
```

### Provider options

| Thành phần | Options | Không hỗ trợ |
|---|---|---|
| **LLM** | `gemini` · `openai` · `anthropic` · `groq` · `azure_openai` | — |
| **Embedder** | `gemini` · `openai` · `voyage` · `azure_openai` | `groq`, `anthropic` |
| **Reranker** | `gemini` · `openai` · `bge` · `none` | — |

### Combo ví dụ

```bash
# ── Gemini all-in-one (1 API key, khuyến nghị để bắt đầu) ──────────────────
LLM_PROVIDER=gemini
MODEL_NAME=gemini-2.0-flash
EMBEDDER_PROVIDER=gemini
EMBEDDER_MODEL=gemini-embedding-2
RERANKER_PROVIDER=gemini
GOOGLE_API_KEY=...

# ── Groq (LLM nhanh) + Gemini (embed/rerank) ───────────────────────────────
LLM_PROVIDER=groq
MODEL_NAME=llama-3.3-70b-versatile
GROQ_API_KEY=...
EMBEDDER_PROVIDER=gemini
RERANKER_PROVIDER=gemini
GOOGLE_API_KEY=...

# ── Anthropic + Voyage + BGE (không phụ thuộc Google/OpenAI cho search) ────
LLM_PROVIDER=anthropic
MODEL_NAME=claude-sonnet-4-6
ANTHROPIC_API_KEY=...
EMBEDDER_PROVIDER=voyage
VOYAGE_API_KEY=...
RERANKER_PROVIDER=bge          # local model, không cần API key

# ── OpenAI thuần túy ────────────────────────────────────────────────────────
LLM_PROVIDER=openai
MODEL_NAME=gpt-4o-mini
EMBEDDER_PROVIDER=openai
EMBEDDER_MODEL=text-embedding-3-large
RERANKER_PROVIDER=openai
OPENAI_API_KEY=...
```

### Reranker chi tiết

| `RERANKER_PROVIDER` | Cơ chế | API key | Latency | Chi phí |
|---|---|---|---|---|
| `gemini` | Gemini API scoring | `GOOGLE_API_KEY` | Thấp | Per-call |
| `openai` | OpenAI logprobs | `OPENAI_API_KEY` | Thấp | Per-call |
| `bge` | Local model `BAAI/bge-reranker-v2-m3` | Không cần | Cao hơn (CPU) | Miễn phí |
| `none` | Bỏ qua reranking | Không cần | Thấp nhất | Miễn phí |
| *(để trống)* | Auto: gemini → openai → none | Tự động detect | — | — |

> `bge` download ~600MB model lần đầu build image. Sau đó cached trong image layer.

---

## Services

### Neo4j

Graph database lưu toàn bộ knowledge graph (entities, facts, episodes).

| | |
|---|---|
| Image | `neo4j:5.26.0` |
| Browser UI | http://localhost:7474 |
| Bolt driver | `bolt://localhost:7687` |
| Credentials | `NEO4J_USER` / `NEO4J_PASSWORD` |

```bash
docker compose logs neo4j -f          # Theo dõi logs
docker compose stop neo4j             # Dừng (giữ data)
docker compose down -v                # ⚠ Dừng + xóa toàn bộ data
```

> Data persist trong Docker volume `neo4j_data`. Backup trước khi chạy `down -v`.

---

### Graphiti MCP

MCP server expose Graphiti knowledge graph cho Claude Code qua HTTP transport.

| | |
|---|---|
| Build | Từ source (`tools/graphiti/graphiti/` submodule) |
| MCP endpoint | http://localhost:8001/mcp |
| Health check | http://localhost:8001/health |
| Transport | HTTP streamable |

```bash
docker compose logs graphiti-mcp -f              # Theo dõi logs

# Sau khi đổi .env (không cần rebuild image)
docker compose restart graphiti-mcp

# Sau khi đổi Dockerfile hoặc update submodule
docker compose build --no-cache graphiti-mcp
docker compose up -d graphiti-mcp
```

**Kết nối Claude Code:**

Tự động qua `.claude/settings.json`. Hoặc thêm thủ công:

```bash
# Local
claude mcp add --transport http graphiti-memory http://localhost:8001/mcp

# Shared server
claude mcp add --transport http graphiti-memory http://<server-ip>:8001/mcp
```

**group_id — phân vùng memory:**

| `GRAPHITI_GROUP_ID` | Mục đích |
|---|---|
| `my-project` | Shared — toàn bộ team đọc/ghi chung |
| `my-project-thang` | Personal namespace của member `thang` |

Truyền `group_id` khác vào từng tool call khi cần switch namespace.

---

## Maintenance

### Update Graphiti lên version mới

```bash
# 1. Pull version mới từ upstream
git submodule update --remote tools/graphiti/graphiti

# 2. Rebuild image
docker compose build --no-cache graphiti-mcp

# 3. Redeploy
docker compose up -d graphiti-mcp

# 4. Commit submodule pointer mới
git add tools/graphiti/graphiti
git commit -m "chore: update graphiti to latest upstream"
```

> Patch cross-encoder trong Dockerfile là **idempotent** — tự bỏ qua nếu upstream đã fix bug.

### Backup & Restore Neo4j

```bash
# Backup (thay PROJECT_NAME cho đúng)
docker run --rm \
  -v ${PROJECT_NAME}-neo4j_data:/data \
  -v "$(pwd)":/backup \
  ubuntu tar czf /backup/neo4j-$(date +%Y%m%d-%H%M).tar.gz /data

# Restore
docker compose stop neo4j
docker run --rm \
  -v ${PROJECT_NAME}-neo4j_data:/data \
  -v "$(pwd)":/backup \
  ubuntu bash -c "rm -rf /data/* && tar xzf /backup/neo4j-<timestamp>.tar.gz -C /"
docker compose up -d neo4j
```

---

## Team Setup (Shared Server)

Một member chạy server, cả team dùng chung:

**Trên server:**
```bash
# Đặt HOST_BIND=0.0.0.0 trong .env
# Kiểm tra firewall cho phép port 8001 và 7474
bash scripts/start.sh
```

**Trên máy mỗi member** — sửa `.claude/settings.json`:
```json
{
  "mcpServers": {
    "graphiti": {
      "type": "http",
      "url": "http://<server-ip>:8001/mcp"
    }
  }
}
```

Member không cần cài Docker hay chạy service gì cả.

---

## Thêm Tool Mới

1. **Tạo compose file:**
   ```bash
   mkdir tools/<tool-name>
   # Viết tools/<tool-name>/docker-compose.yml
   # Container phải join workspace-network để giao tiếp với các service khác
   ```

2. **Include vào root compose:**
   ```yaml
   # docker-compose.yml
   include:
     - tools/neo4j/docker-compose.yml
     - tools/graphiti/docker-compose.yml
     - tools/<tool-name>/docker-compose.yml
   ```

3. **Thêm env vars** vào `.env.example` với comment đầy đủ.

4. **Cập nhật README** này — thêm mục mô tả service mới vào phần [Services](#services).
