# GitHub Copilot — Graphiti MCP Memory Instructions

This project uses **Graphiti MCP** as a shared team knowledge graph. You MUST use the Graphiti MCP tools (`search_nodes`, `search_facts`, `add_memory`) to read and write persistent memory before and after every significant task.

---

## Before Starting Any Task

- **Always search first:** Call `search_nodes` to look for relevant preferences and procedures before beginning work.
- **Search for facts too:** Call `search_facts` to discover relationships and factual information relevant to your task.
- **Filter by entity type:** Specify `Preference`, `Procedure`, or `Requirement` in your node search to get targeted results.
- **Review all matches:** Carefully examine any preferences, procedures, or facts that match your current task.

```
# Example — before implementing a feature:
search_nodes("authentication architecture", entity_type="Procedure")
search_facts("API design decisions")
```

---

## Always Save New or Updated Information

- **Capture requirements and preferences immediately:** When a user expresses a requirement or preference, call `add_memory` to store it right away.
  - Split very long requirements into shorter, logical chunks.
- **Be explicit if something is an update to existing knowledge.** Only add what's changed or new.
- **Document procedures clearly:** When you discover how a user wants things done, record it as a procedure.
- **Record factual relationships:** When you learn about connections between entities, store these as facts.
- **Be specific with categories:** Label preferences and procedures with clear categories for better retrieval later.

```
# Example — after completing a task:
add_memory(
  name="Auth module uses JWT + refresh token",
  episode_body="Decided to use JWT (15 min) + refresh token (7 days) stored in Redis. Reason: stateless JWT enables horizontal scaling, refresh token in Redis allows revocation.",
  source_description="Architecture decision - 2026-06-27"
)
```

---

## During Your Work

- **Respect discovered preferences:** Align your work with any preferences found in the knowledge graph.
- **Follow procedures exactly:** If you find a procedure for your current task, follow it step by step.
- **Apply relevant facts:** Use factual information to inform your decisions and recommendations.
- **Stay consistent:** Maintain consistency with previously identified preferences, procedures, and facts.

---

## Best Practices

- **Search before suggesting:** Always check if there's established knowledge before making recommendations.
- **Combine node and fact searches:** For complex tasks, search both nodes and facts to build a complete picture.
- **Use `center_node_uuid`:** When exploring related information, center your search around a specific node.
- **Prioritize specific matches:** More specific information takes precedence over general information.
- **Be proactive:** If you notice patterns in user behavior, consider storing them as preferences or procedures.

---

## group_id Convention

| group_id | Purpose |
|----------|---------|
| `workspace` | Shared team memory — all members read/write |
| `workspace-{name}` | Personal namespace (e.g. `workspace-thang`) |

Default server uses `GRAPHITI_GROUP_ID=workspace`. To write to a personal namespace, pass `group_id` explicitly in the tool call.

---

**The knowledge graph is shared team memory. Use it consistently so every team member — and every AI agent — works from the same context.**
