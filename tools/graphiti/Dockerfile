# syntax=docker/dockerfile:1
#
# Build từ source của getzep/graphiti (git submodule tại ./graphiti/)
# Để update lên version mới: git submodule update --remote tools/graphiti/graphiti
#                             docker compose build --no-cache graphiti-mcp

FROM python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv package manager
ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh
ENV PATH="/root/.local/bin:${PATH}"

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    MCP_SERVER_HOST="0.0.0.0" \
    PYTHONUNBUFFERED=1

WORKDIR /app/mcp

# --- Dependencies ---
# Copy từ submodule graphiti/mcp_server/ (không có local path override)
COPY graphiti/mcp_server/pyproject.toml graphiti/mcp_server/uv.lock ./

# Cài đặt với --extra providers để có google-genai, anthropic, groq, v.v.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --no-group dev --extra providers

# --- Cross-encoder patch (idempotent) ---
# Lý do: graphiti_core mặc định dùng OpenAIRerankerClient dù config là Gemini.
# Patch này inject GeminiRerankerClient khi GOOGLE_API_KEY có mặt.
# Khi upstream fix bug này, patch sẽ tự bỏ qua (in "patch not needed").
RUN python3 << 'PATCH'
import pathlib, sys

target = pathlib.Path('.venv/lib/python3.11/site-packages/graphiti_core/graphiti.py')
if not target.exists():
    candidates = list(pathlib.Path('.venv/lib').glob('python3.*/site-packages/graphiti_core/graphiti.py'))
    if not candidates:
        print('WARNING: graphiti_core/graphiti.py not found, skipping patch', file=sys.stderr)
        sys.exit(0)
    target = candidates[0]

src = target.read_text()

# Tìm toàn bộ else block hardcode OpenAI để thay thế
old = "        else:\n            self.cross_encoder = OpenAIRerankerClient()"

if old not in src:
    print('INFO: Cross-encoder patch not needed — upstream already fixed or API changed')
    sys.exit(0)

# Inject logic đọc RERANKER_PROVIDER tại runtime để chọn cross-encoder phù hợp:
#   gemini  → GeminiRerankerClient  (cần GOOGLE_API_KEY)
#   openai  → OpenAIRerankerClient  (cần OPENAI_API_KEY)
#   bge     → BGERerankerClient     (local, không cần API key)
#   none    → NoOpReranker          (bỏ qua reranking, trả về thứ tự gốc)
#   (unset) → auto-detect: gemini nếu có GOOGLE_API_KEY, openai nếu có OPENAI_API_KEY, không thì none
new = """\
        else:
            _reranker = __import__('os').environ.get('RERANKER_PROVIDER', '').lower()
            if _reranker == 'gemini':
                from graphiti_core.cross_encoder.gemini_reranker_client import GeminiRerankerClient
                from graphiti_core.llm_client import LLMConfig
                self.cross_encoder = GeminiRerankerClient(
                    config=LLMConfig(api_key=__import__('os').environ.get('GOOGLE_API_KEY', ''))
                )
            elif _reranker == 'openai':
                self.cross_encoder = OpenAIRerankerClient()
            elif _reranker == 'bge':
                from graphiti_core.cross_encoder.bge_reranker_client import BGERerankerClient
                self.cross_encoder = BGERerankerClient()
            elif _reranker in ('none', 'disabled'):
                from graphiti_core.cross_encoder.client import CrossEncoderClient
                class _NoOpReranker(CrossEncoderClient):
                    async def rank(self, query, passages):
                        return [(p, 1.0) for p in passages]
                self.cross_encoder = _NoOpReranker()
            else:
                _os = __import__('os')
                if _os.environ.get('GOOGLE_API_KEY'):
                    from graphiti_core.cross_encoder.gemini_reranker_client import GeminiRerankerClient
                    from graphiti_core.llm_client import LLMConfig
                    self.cross_encoder = GeminiRerankerClient(
                        config=LLMConfig(api_key=_os.environ['GOOGLE_API_KEY'])
                    )
                elif _os.environ.get('OPENAI_API_KEY'):
                    self.cross_encoder = OpenAIRerankerClient()
                else:
                    from graphiti_core.cross_encoder.client import CrossEncoderClient
                    class _NoOpReranker(CrossEncoderClient):
                        async def rank(self, query, passages):
                            return [(p, 1.0) for p in passages]
                    self.cross_encoder = _NoOpReranker()"""

target.write_text(src.replace(old, new, 1))
print(f'SUCCESS: Flexible cross-encoder patch applied to {target}')
PATCH

# --- Application source ---
COPY graphiti/mcp_server/main.py ./
COPY graphiti/mcp_server/src/ ./src/
COPY graphiti/mcp_server/config/ ./config/

# Override config mặc định bằng config của team
COPY config.yaml ./config/config.yaml

RUN mkdir -p /var/log/graphiti

EXPOSE 8001

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=5 \
    CMD curl -f http://localhost:${PORT_MCP:-8001}/health || exit 1

CMD ["uv", "run", "--no-sync", "main.py"]
