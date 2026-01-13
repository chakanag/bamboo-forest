# Agent Guidelines for Anonymous Bamboo Forest

## Project Overview
Time-limited anonymous community service (Korean: 익명 대나무숲). Posts expire after 10 minutes unless extended by user recommendations.

## Tech Stack
- **Backend**: Python FastAPI (async)
- **Hot Data**: Redis (TTL, rankings, view counts)
- **Cold Data**: Supabase (PostgreSQL for permanent storage, auth, vector search)
- **Frontend**: Flutter (iOS/Android/Web)
- **AI/ML**: OpenAI API / LangChain (categorization, sentiment analysis)
- **Infra**: Docker & Docker Compose

## Build/Run Commands

### Setup
```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
docker-compose up -d  # Start Redis
```

### Development
```bash
uvicorn app.main:app --reload
```
API Docs: http://localhost:8000/docs

### Testing
```bash
pytest                           # Run all tests
pytest tests/test_posts.py        # Run specific test file
pytest tests/test_posts.py -k test_create_post  # Run specific test
pytest -v                        # Verbose output
pytest --cov=app                 # With coverage
```

### Linting/Formatting
```bash
black app/                       # Format code
ruff check app/                  # Lint
ruff check app/ --fix           # Auto-fix linting
mypy app/                        # Type checking
```

## Code Style Guidelines

### Python/FastAPI Conventions

**File Structure** (Planned):
```
app/
├── main.py          # App entry point, include routers
├── api/
│   └── endpoints/
│       ├── posts.py
│       └── ...
├── core/
│   ├── config.py    # Settings, environment variables
│   └── security.py  # Auth, middleware
├── models/          # Pydantic models for API schemas
├── schemas/         # Pydantic DTOs (rename if confusing with models/)
└── services/        # Business logic (Redis, AI, DB operations)
```

**Imports** (PEP 8):
```python
# 1. Standard library
from datetime import datetime, timedelta
from typing import Optional, List

# 2. Third-party
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
import redis.asyncio as redis

# 3. Local
from app.core.config import settings
from app.schemas.post import PostCreate, PostResponse
```

**Type Hints**: Always include. Use `Optional[T]` for nullable, `List[T]` for collections.

**Naming Conventions**:
- Functions/variables: `snake_case`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Private: `_leading_underscore`

**Error Handling**:
```python
from fastapi import HTTPException, status

try:
    result = await redis_client.get(key)
except redis.RedisError as e:
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail=f"Redis error: {str(e)}"
    )
```

**Async/Await**: All I/O operations must be async (Redis, DB, HTTP calls). Use `async def` and `await`.

## Business Rules (Critical)

### Post Lifecycle
- **Default TTL**: 600 seconds (10 minutes) after creation
- **Extension**: Every 100 recommendations adds 300 seconds (5 minutes)
- **Permanent Storage**: After 100,000 views → moves to Supabase, TTL removed
- **Blind/Deletion**: TTL expires → user UI hides immediately, but data backed up to DB

### Content Constraints
- **Max length**: ~200 characters (enforce in Pydantic schema)
- **AI Tagging**: Auto-generate categories/tags on write using OpenAI/LangChain

### Moderation
- **Report threshold**: 50 reports → instant blind
- **Data retention**: Moderated posts saved to admin DB for legal compliance

## Redis Usage Patterns

```python
# Set post with TTL
await redis.setex(f"post:{post_id}", ttl, json.dumps(post_data))

# Extend TTL (on recommendation)
current_ttl = await redis.ttl(f"post:{post_id}")
if current_ttl > 0:
    await redis.expire(f"post:{post_id}", current_ttl + 300)

# Check before expiration
if await redis.exists(f"post:{post_id}"):
    data = await redis.get(f"post:{post_id}")
else:
    # Post expired, fetch from backup DB or return 404
```

## Supabase Integration

Use `supabase-py` client for:
- Permanent storage (Hall of Fame posts)
- User authentication
- Vector search for historical content

## API Design

**Pydantic Schemas**:
```python
class PostCreate(BaseModel):
    content: str = Field(..., max_length=200, min_length=1)

class PostResponse(BaseModel):
    id: str
    content: str
    created_at: datetime
    ttl_seconds: int
    tags: List[str]
```

**Endpoint Structure**:
```python
from fastapi import APIRouter, Depends

router = APIRouter(prefix="/api/v1/posts", tags=["posts"])

@router.post("/", response_model=PostResponse)
async def create_post(
    post: PostCreate,
    redis_client: redis.Redis = Depends(get_redis)
):
    # Implementation
```

## Language & Comments

**Language**: Korean is the primary business language. Comments and docstrings should be in Korean where describing domain logic.

**Docstrings**: Use Google style for functions:
```python
async def create_post(post: PostCreate, redis_client: redis.Redis) -> PostResponse:
    """
    새로운 게시글을 생성하고 Redis에 저장합니다.

    Args:
        post: 게시글 생성 데이터 (최대 200자)
        redis_client: Redis 비동기 클라이언트

    Returns:
        PostResponse: 생성된 게시글 정보

    Raises:
        HTTPException: Redis 저장 실패 시 500 에러
    """
```

## Environment Variables

Required (create `.env`):
```
REDIS_HOST=localhost
REDIS_PORT=6379
OPENAI_API_KEY=your_key_here
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
```

## Common Pitfalls

1. **Blocking calls**: Never use synchronous Redis/DB calls in async routes
2. **TTL handling**: Always check `redis.exists()` before assuming data exists
3. **Race conditions**: Use Redis transactions (`MULTI/EXEC`) for counter increments
4. **Error suppression**: Never use bare `except:` or empty catch blocks
5. **Type safety**: Never use `type: ignore` or `Any` - properly annotate all types

## Testing

- Use `pytest-asyncio` for async tests
- Mock Redis/Supabase in unit tests
- Integration tests should use test Redis instance
- Test file: `tests/test_{module_name}.py`
- Test function: `test_{scenario}_{expected_result}`

Example:
```python
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_create_post_success():
    response = client.post("/api/v1/posts/", json={"content": "Hello"})
    assert response.status_code == 200
    assert "id" in response.json()
```
