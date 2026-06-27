# Workspace

Team workspace với shared memory qua Graphiti knowledge graph. Mọi quyết định, context, và architecture được lưu vào Neo4j để các thành viên không mất context của nhau giữa các session.

## Cấu trúc

```
workspace/
├── docker-compose.yml       # Root compose — gom tất cả tools
├── .env.example             # Template config cho team members
├── .claude/
│   └── settings.json        # Kết nối Graphiti MCP tự động
├── CLAUDE.md                # Hướng dẫn Claude dùng shared memory
└── tools/                   # Third-party services
    ├── neo4j/
    │   └── docker-compose.yml
    └── graphiti/
        └── docker-compose.yml
```

## Quick Start

```bash
# 1. Tạo file .env từ template
cp .env.example .env

# 2. Điền các biến bắt buộc trong .env
#    - OPENAI_API_KEY
#    - NEO4J_PASSWORD (đổi khỏi giá trị mặc định)

# 3. Khởi động tất cả services
docker compose --profile default up -d

# 4. Kiểm tra
curl http://localhost:8001/health
# → {"status":"healthy","service":"graphiti-mcp"}
```

---

## Third-party Tools

### Neo4j

Graph database — nơi Graphiti lưu toàn bộ knowledge graph (entities, facts, episodes).

**Config:** [tools/neo4j/docker-compose.yml](tools/neo4j/docker-compose.yml)

| | |
|---|---|
| Image | `neo4j:5.26.0` |
| Browser UI | http://localhost:7474 |
| Bolt (driver) | `bolt://localhost:7687` |
| Default user | `neo4j` |

**Env vars** (trong `.env`):

| Biến | Mô tả | Default |
|------|--------|---------|
| `NEO4J_USER` | Username | `neo4j` |
| `NEO4J_PASSWORD` | Password — **bắt buộc đổi** | `password` |
| `NEO4J_DATABASE` | Tên database | `neo4j` |
| `NEO4J_HTTP_PORT` | Port cho Browser UI | `7474` |
| `NEO4J_BOLT_PORT` | Port cho Bolt driver | `7687` |

**Lệnh thường dùng:**

```bash
# Start (dùng profile default vì neo4j thuộc profile này)
docker compose --profile default up neo4j -d

# Stop
docker compose stop neo4j

# Xem logs
docker compose logs neo4j -f

# Xóa data (reset hoàn toàn)
docker compose down -v
```

> **Lưu ý:** Data được persist trong Docker volume `neo4j_data`. Chạy `docker compose down -v` sẽ xóa toàn bộ memory của team.

---

### Graphiti MCP

MCP server expose Graphiti knowledge graph cho Claude Code. Claude dùng tool này để lưu và tìm kiếm context của team.

**Config:** [tools/graphiti/docker-compose.yml](tools/graphiti/docker-compose.yml)

| | |
|---|---|
| Image | `zepai/knowledge-graph-mcp:standalone` |
| MCP endpoint | http://localhost:8001/mcp |
| Health check | http://localhost:8001/health |
| Transport | SSE (Server-Sent Events) |

**Env vars** (trong `.env`):

| Biến | Mô tả | Default |
|------|--------|---------|
| `OPENAI_API_KEY` | API key để extract entities — **bắt buộc** | — |
| `MODEL_NAME` | LLM dùng để xử lý text | `gpt-4o-mini` |
| `GRAPHITI_GROUP_ID` | Namespace memory trong Neo4j | `workspace` |
| `PORT_MCP` | Port expose MCP server | `8001` |
| `SEMAPHORE_LIMIT` | Max concurrent requests | `10` |

**group_id — Chiến lược phân vùng memory:**

| group_id | Mục đích |
|----------|----------|
| `workspace` | Shared project memory — mọi member đọc/ghi |
| `workspace-{tên}` | Personal memory (vd: `workspace-thang`) |

**Lệnh thường dùng:**

```bash
# Start (tự chờ Neo4j healthy rồi mới start)
docker compose up graphiti-mcp -d

# Stop
docker compose stop graphiti-mcp

# Xem logs
docker compose logs graphiti-mcp -f

# Test kết nối
curl http://localhost:8001/health
```

**Kết nối với Claude Code:**

MCP được cấu hình sẵn trong [.claude/settings.json](.claude/settings.json). Claude Code trong workspace này tự động kết nối khi mở.

Hoặc thêm thủ công qua CLI:

```bash
# Local server
claude mcp add --transport http graphiti-memory http://localhost:8001/mcp

# Shared server
claude mcp add --transport http graphiti-memory http://<server-ip>:8001/mcp
```

Nếu team dùng shared server thay vì local:
```json
{
  "mcpServers": {
    "graphiti": {
      "type": "sse",
      "url": "http://<server-ip>:8001/mcp"
    }
  }
}
```

---

## Thêm Third-party Tool Mới

1. Tạo thư mục và compose file:
   ```bash
   mkdir tools/<tên-tool>
   # Viết tools/<tên-tool>/docker-compose.yml
   ```

2. Thêm vào root `docker-compose.yml`:
   ```yaml
   include:
     - tools/neo4j/docker-compose.yml
     - tools/graphiti/docker-compose.yml
     - tools/<tên-tool>/docker-compose.yml  # thêm dòng này
   ```

3. Thêm env vars cần thiết vào `.env.example`.

4. Thêm mục hướng dẫn vào README này.
