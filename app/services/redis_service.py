"""
Redis 비즈니스 로직 서비스

게시글의 TTL 관리, 카운터 증가, 마이그레이션 등 Redis 관련 모든 작업을 담당합니다.
Lua 스크립트를 사용하여 원자적 연산을 보장합니다.
"""

import json
import uuid
from datetime import datetime
from typing import Optional, Literal

import redis.asyncio as redis

from app.core.config import get_settings
from app.schemas.post import PostStatus
from loguru import logger

settings = get_settings()


class RedisService:
    """
    Redis 비즈니스 로직 서비스

    모든 게시글 관련 Redis 연산을 캡슐화합니다.
    """

    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client

    # Redis 키 구조 (Oracle 권장 패턴)
    # post:{id} - HASH: 게시글 데이터 (TTL 포함)
    # posts:active - ZSET: 활성 게시글 인덱스 (score=created_at)
    # posts:expiring - ZSET: 만료 예정 게시글 (score=expire_at)
    # posts:rank:views - ZSET: 뷰수 랭킹
    # posts:rank:recs - ZSET: 추천수 랭킹

    async def create_post(self, content: str, tags: list[str]) -> dict:
        """
        새로운 게시글 생성

        Redis에 게시글을 저장하고 TTL을 설정합니다.

        Args:
            content: 게시글 내용
            tags: AI 태그 목록

        Returns:
            dict: 생성된 게시글 데이터
        """
        post_id = f"post_{uuid.uuid4().hex[:12]}"
        now = datetime.utcnow()
        now_ts = now.timestamp()

        post_data = {
            "id": post_id,
            "content": content,
            "created_at": now.isoformat(),
            "created_at_ts": str(now_ts),
            "tags": json.dumps(tags),
            "views": "0",
            "recommendations": "0",
            "reports": "0",
            "status": PostStatus.ACTIVE.value,
        }

        # Redis 트랜잭션으로 게시글 저장 및 인덱스 업데이트
        pipe = self.redis.pipeline(transaction=True)
        pipe.hset(f"post:{post_id}", mapping=post_data)
        pipe.expire(f"post:{post_id}", settings.post_default_ttl)
        pipe.zadd("posts:active", {post_id: now_ts})
        pipe.zadd(
            "posts:expiring",
            {post_id: now_ts + settings.post_default_ttl},
        )
        pipe.execute()

        # 랭킹 인덱스 초기화
        await self.redis.zadd("posts:rank:views", {post_id: 0})
        await self.redis.zadd("posts:rank:recs", {post_id: 0})

        logger.info(f"게시글 생성됨: {post_id}")

        return {**post_data, "id": post_id, "tags": tags, "ttl_seconds": settings.post_default_ttl}

    async def get_post(self, post_id: str) -> Optional[dict]:
        """
        게시글 조회

        Redis에서 게시글을 조회합니다.

        Args:
            post_id: 게시글 ID

        Returns:
            Optional[dict]: 게시글 데이터 (없으면 None)
        """
        key = f"post:{post_id}"
        exists = await self.redis.exists(key)

        if not exists:
            return None

        post_data = await self.redis.hgetall(key)

        # 조회수 증가 (Lua 스크립트로 원자적 처리)
        await self._increment_view_atomic(post_id)

        # TTL 계산
        ttl = await self.redis.ttl(key)
        ttl_seconds = max(0, ttl)

        # 랭킹 인덱스 업데이트
        views = int(post_data.get("views", 0))
        await self.redis.zadd("posts:rank:views", {post_id: views})

        return {
            "id": post_id,
            "content": post_data.get("content"),
            "created_at": post_data.get("created_at"),
            "ttl_seconds": ttl_seconds,
            "tags": json.loads(post_data.get("tags", "[]")),
            "views": views,
            "recommendations": int(post_data.get("recommendations", 0)),
            "reports": int(post_data.get("reports", 0)),
            "status": post_data.get("status", PostStatus.ACTIVE.value),
        }

    async def get_active_posts(self, page: int = 1, per_page: int = 20) -> dict:
        """
        활성 게시글 목록 조회

        Args:
            page: 페이지 번호
            per_page: 페이지당 게시글 수

        Returns:
            dict: 게시글 목록 및 메타데이터
        """
        offset = (page - 1) * per_page

        # ZSET에서 최근 게시글 ID 목록 가져오기
        post_ids = await self.redis.zrevrange("posts:active", offset, offset + per_page - 1)

        posts = []
        for post_id in post_ids:
            post = await self.get_post(post_id)
            if post and post["status"] == PostStatus.ACTIVE.value:
                posts.append(post)

        total = await self.redis.zcard("posts:active")

        return {"posts": posts, "total": total, "page": page, "per_page": per_page}

    # Lua 스크립트: 추천 원자적 처리 (Oracle 권장)
    RECOMMEND_SCRIPT = """
    local key = KEYS[1]
    local threshold = tonumber(ARGV[1])
    local extension_ttl = tonumber(ARGV[2])
    local hall_of_fame_threshold = tonumber(ARGV[3])

    -- 상태 확인 (블라인드된 게시글은 추천 불가)
    local status = redis.call('HGET', key, 'status')
    if status == 'blinded' then
        return {-1, redis.call('HGET', key, 'recommendations')}
    end

    -- 추천수 증가
    local recs = redis.call('HINCRBY', key, 'recommendations', 1)

    -- 100번째 추천마다 TTL 연장
    local should_extend = (recs % threshold == 0)
    local current_ttl = redis.call('TTL', key)

    if should_extend and current_ttl > 0 then
        redis.call('EXPIRE', key, current_ttl + extension_ttl)
    end

    -- 랭킹 업데이트
    local post_id = string.sub(key, 6) -- 'post:' 제거
    redis.call('ZINCRBY', 'posts:rank:recs', 1, post_id)

    return {recs, current_ttl, should_extend}
    """

    async def recommend_post(self, post_id: str) -> dict:
        """
        게시글 추천

        Lua 스크립트로 원자적으로 추천수 증가 및 TTL 연장을 처리합니다.

        Args:
            post_id: 게시글 ID

        Returns:
            dict: 추천 결과
        """
        key = f"post:{post_id}"

        # Lua 스크립트 실행
        result = await self.redis.eval(
            self.RECOMMEND_SCRIPT,
            1,  # KEYS count
            key,  # KEYS[1]
            settings.recommendation_extension_threshold,  # ARGV[1]
            settings.recommendation_extension_ttl,  # ARGV[2]
            settings.hall_of_fame_view_threshold,  # ARGV[3] (unused but needed)
        )

        recs, current_ttl, should_extend = result

        if recs == -1:
            # 블라인드된 게시글
            return {
                "success": False,
                "recommendations": int(current_ttl),
                "message": "블라인드된 게시글은 추천할 수 없습니다.",
            }

        message = None
        if should_extend:
            message = f"{settings.recommendation_extension_threshold}번째 추천! {settings.recommendation_extension_ttl // 60}분 연장되었습니다."

        new_ttl = current_ttl + (settings.recommendation_extension_ttl if should_extend else 0)

        return {
            "success": True,
            "recommendations": recs,
            "ttl_seconds": new_ttl,
            "message": message,
        }

    # Lua 스크립트: 신고 원자적 처리
    REPORT_SCRIPT = """
    local key = KEYS[1]
    local blind_threshold = tonumber(ARGV[1])

    local reports = redis.call('HINCRBY', key, 'reports', 1)

    -- 신고 임계치 도달 시 블라인드 처리
    if reports >= blind_threshold then
        redis.call('HSET', key, 'status', 'blinded')
        return {reports, true}
    end

    return {reports, false}
    """

    async def report_post(self, post_id: str) -> dict:
        """
        게시글 신고

        Lua 스크립트로 원자적으로 신고수 증가 및 블라인드 처리를 수행합니다.

        Args:
            post_id: 게시글 ID

        Returns:
            dict: 신고 결과
        """
        key = f"post:{post_id}"

        # Lua 스크립트 실행
        result = await self.redis.eval(
            self.REPORT_SCRIPT,
            1,  # KEYS count
            key,  # KEYS[1]
            settings.report_blind_threshold,  # ARGV[1]
        )

        reports, is_blinded = result

        if is_blinded:
            message = f"{settings.report_blind_threshold}번째 신고로 게시글이 블라인드되었습니다."
            logger.warning(f"게시글 블라인드됨: {post_id}, 신고수: {reports}")
        else:
            message = "게시글이 신고되었습니다."

        return {"success": True, "reports": reports, "message": message}

    async def _increment_view_atomic(self, post_id: str):
        """
        조회수 원자적 증가 (내부 메서드)

        Lua 스크립트로 조회수를 증가시키고 랭킹을 업데이트합니다.

        Args:
            post_id: 게시글 ID
        """
        key = f"post:{post_id}"

        script = """
        local views = redis.call('HINCRBY', KEYS[1], 'views', 1)
        local post_id = string.sub(KEYS[1], 6)
        redis.call('ZINCRBY', 'posts:rank:views', 1, post_id)
        return views
        """

        await self.redis.eval(script, 1, key)

    async def cleanup_expired_indexes(self):
        """
        만료된 게시글 인덱스 정리

        posts:expiring에서 만료된 게시글 ID를 찾아 인덱스에서 제거합니다.
        주기적으로 실행되어야 합니다.
        """
        now = datetime.utcnow().timestamp()

        # 만료된 게시글 ID 목록 가져오기
        expired_ids = await self.redis.zrangebyscore("posts:expiring", 0, now)

        if not expired_ids:
            return

        # 인덱스에서 제거
        pipe = self.redis.pipeline(transaction=True)
        for post_id in expired_ids:
            pipe.zrem("posts:active", post_id)
            pipe.zrem("posts:expiring", post_id)
            pipe.zrem("posts:rank:views", post_id)
            pipe.zrem("posts:rank:recs", post_id)
        pipe.execute()

        logger.info(f"만료된 인덱스 정리됨: {len(expired_ids)}개")

    async def get_ranking(self, rank_type: Literal["views", "recs"], limit: int = 10) -> list[dict]:
        """
        랭킹 조회

        Args:
            rank_type: 랭킹 타입 ("views" 또는 "recs")
            limit: 가져올 개수

        Returns:
            list[dict]: 랭킹 리스트
        """
        rank_key = f"posts:rank:{rank_type}"
        post_ids = await self.redis.zrevrange(rank_key, 0, limit - 1, withscores=True)

        ranking = []
        for post_id, score in post_ids:
            post = await self.get_post(post_id)
            if post:
                ranking.append({"post": post, "score": int(score)})

        return ranking
