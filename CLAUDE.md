# Workspace — Team Memory với Graphiti MCP

## Mục đích
Workspace này được thiết kế để nhiều thành viên trong team cùng làm việc mà không mất context của nhau. Mọi quyết định, architecture, bug, và context quan trọng được lưu vào Graphiti knowledge graph qua MCP.

## Graphiti Memory — Cách dùng

> Full rules also available in [docs/graphiti_rules.md](docs/graphiti_rules.md) and mirrored to all AI tool configs (`.github/copilot-instructions.md`, `.cursor/rules/`, `.windsurfrules`, `.clinerules`, `AGENTS.md`, `.devin/instructions.md`).

### Before Starting Any Task (MCP Tool Rules)

- **Always search first:** Use `search_nodes` to look for relevant preferences and procedures before beginning work.
- **Search for facts too:** Use `search_facts` to discover relationships and factual information relevant to the task.
- **Filter by entity type:** Specify `Preference`, `Procedure`, or `Requirement` in your node search for targeted results.
- **Review all matches:** Carefully examine any preferences, procedures, or facts that match your current task.

### Always Save New or Updated Information

- **Capture requirements and preferences immediately:** When a user expresses a requirement or preference, use `add_memory` to store it right away. Split very long requirements into shorter logical chunks.
- **Only add what's changed or new** — be explicit if something updates existing knowledge.
- **Document procedures clearly:** When you discover how a user wants things done, record it as a procedure.
- **Record factual relationships:** When you learn about connections between entities, store these as facts.
- **Be specific with categories:** Label preferences and procedures with clear categories for better retrieval.

### Best Practices

- **Search before suggesting:** Always check if there's established knowledge before making recommendations.
- **Combine node and fact searches:** For complex tasks, search both nodes and facts to build a complete picture.
- **Use `center_node_uuid`:** When exploring related information, center your search around a specific node.
- **Prioritize specific matches:** More specific information takes precedence over general information.
- **Be proactive:** If you notice patterns in user behavior, store them as preferences or procedures.

### Khi nào cần lưu memory
Luôn gọi `add_memory` sau khi:
- Đưa ra quyết định kiến trúc hoặc kỹ thuật
- Hoàn thành một feature hoặc fix bug quan trọng
- Phát hiện constraint hoặc gotcha trong codebase
- Team thống nhất về một cách tiếp cận
- Có thông tin quan trọng về project context

### Khi nào cần tìm memory
Luôn gọi `search_nodes` hoặc `search_memory_facts` trước khi:
- Bắt đầu implement feature mới
- Đưa ra quyết định kiến trúc
- Debug một vấn đề phức tạp
- Trả lời câu hỏi về project context

### Quy ước group_id
| group_id | Dùng cho |
|----------|----------|
| `workspace` | Project memory chung — mọi member đều đọc/ghi |
| `workspace-{tên}` | Memory riêng của từng member (vd: `workspace-thang`) |

Mặc định server dùng `GRAPHITI_GROUP_ID=workspace` (shared). Để ghi vào namespace cá nhân, truyền `group_id` vào tool call.

### Ví dụ workflow

**Trước khi bắt đầu task:**
```
search_nodes("authentication architecture")
search_memory_facts("API design decisions")
```

**Sau khi hoàn thành:**
```
add_memory(
  name="Auth module dùng JWT + refresh token",
  episode_body="Đã quyết định dùng JWT (15 phút) + refresh token (7 ngày) lưu trong Redis. Lý do: stateless JWT giúp scale horizontal, refresh token trong Redis để có thể revoke.",
  source_description="Architecture decision - 2026-06-27"
)
```

## Cài đặt cho Team Members

### Lần đầu setup
```bash
# 1. Copy env file
cp .env.example .env
# Điền OPENAI_API_KEY và đổi NEO4J_PASSWORD

# 2. Start services
docker compose up -d

# 3. Kiểm tra server
curl http://localhost:8001/health
# → {"status":"healthy","service":"graphiti-mcp"}

# 4. Mở Claude Code trong thư mục này
# MCP sẽ tự động kết nối qua .claude/settings.json
```

### Dùng shared server (khuyến nghị cho team)
Nếu team có một server chung, thay URL trong [.claude/settings.json](.claude/settings.json):
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

## Cấu trúc Memory

Graphiti tự động extract các entity types từ nội dung:
- **Requirement** — Yêu cầu tính năng, spec
- **Procedure** — Quy trình, workflow, SOP
- **Preference** — Lựa chọn kỹ thuật, coding style
- **Event** — Incident, release, sprint milestone
- **Document** — Tài liệu tham chiếu

## Services

| Service | URL | Dùng cho |
|---------|-----|----------|
| Graphiti MCP | http://localhost:8001/mcp | Claude Code kết nối |
| Graphiti Health | http://localhost:8001/health | Kiểm tra trạng thái |
| Neo4j Browser | http://localhost:7474 | Xem knowledge graph |
