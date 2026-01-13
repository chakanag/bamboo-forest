"""
게시글 API 엔드포인트

게시글 생성, 조회, 추천, 신고 기능을 제공합니다.
"""

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from typing import Literal

import redis.asyncio as redis

from app.core.config import get_redis, get_settings
from app.schemas.post import (
    PostCreate,
    PostResponse,
    PostListResponse,
    PostRecommendResponse,
    PostReportResponse,
)
from app.services.redis_service import RedisService
from app.services.ai_service import AIService
from loguru import logger

router = APIRouter(prefix="/api/v1/posts", tags=["posts"])
settings = get_settings()


@router.post("/", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def create_post(
    background_tasks: BackgroundTasks,
    post: PostCreate,
    redis_client: redis.Redis = Depends(get_redis),
):
    """
    새로운 게시글 생성

    게시글을 생성하고 Redis에 저장합니다. AI 태깅은 백그라운드에서 비동기로 처리됩니다.

    Args:
        post: 게시글 생성 데이터
        redis_client: Redis 클라이언트 (의존성 주입)
        background_tasks: FastAPI 백그라운드 작업

    Returns:
        PostResponse: 생성된 게시글 정보
    """
    try:
        # Redis 서비스 인스턴스 생성
        redis_service = RedisService(redis_client)

        # 게시글 생성 (초기에는 빈 태그)
        post_data = await redis_service.create_post(post.content, tags=[])

        # AI 태깅을 백그라운드에서 비동기 처리
        ai_service = AIService(redis_client)
        background_tasks.add_task(
            ai_service.tag_post, post_data["id"], post_data["content"]
        )

        logger.info(f"게시글 생성됨: {post_data['id']}")

        return PostResponse(**post_data)

    except Exception as e:
        logger.error(f"게시글 생성 실패: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"게시글 생성에 실패했습니다: {str(e)}",
        )


@router.get("/", response_model=PostListResponse)
async def get_posts(
    page: int = 1,
    per_page: int = 20,
    redis_client: redis.Redis = Depends(get_redis),
):
    """
    활성 게시글 목록 조회

    최근 생성된 활성 게시글 목록을 페이지네이션으로 조회합니다.

    Args:
        page: 페이지 번호 (기본값: 1)
        per_page: 페이지당 게시글 수 (기본값: 20, 최대: 100)
        redis_client: Redis 클라이언트

    Returns:
        PostListResponse: 게시글 목록
    """
    try:
        per_page = min(per_page, 100)  # 최대 100개 제한
        redis_service = RedisService(redis_client)
        result = await redis_service.get_active_posts(page, per_page)

        return PostListResponse(**result)

    except Exception as e:
        logger.error(f"게시글 목록 조회 실패: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"게시글 목록 조회에 실패했습니다: {str(e)}",
        )


@router.get("/{post_id}", response_model=PostResponse)
async def get_post(
    post_id: str,
    redis_client: redis.Redis = Depends(get_redis),
):
    """
    게시글 상세 조회

    특정 게시글의 상세 정보를 조회합니다. 조회수가 증가합니다.

    Args:
        post_id: 게시글 ID
        redis_client: Redis 클라이언트

    Returns:
        PostResponse: 게시글 상세 정보

    Raises:
        HTTPException: 게시글을 찾을 수 없는 경우 (404)
    """
    try:
        redis_service = RedisService(redis_client)
        post = await redis_service.get_post(post_id)

        if not post:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="게시글을 찾을 수 없습니다.",
            )

        return PostResponse(**post)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"게시글 조회 실패: {post_id}, 에러: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"게시글 조회에 실패했습니다: {str(e)}",
        )


@router.post("/{post_id}/recommend", response_model=PostRecommendResponse)
async def recommend_post(
    post_id: str,
    redis_client: redis.Redis = Depends(get_redis),
):
    """
    게시글 추천

    게시글을 추천합니다. 100번째 추천마다 5분 TTL 연장됩니다.

    Args:
        post_id: 게시글 ID
        redis_client: Redis 클라이언트

    Returns:
        PostRecommendResponse: 추천 결과

    Raises:
        HTTPException: 게시글을 찾을 수 없는 경우 (404)
    """
    try:
        redis_service = RedisService(redis_client)

        # 게시글 존재 확인
        post = await redis_service.get_post(post_id)
        if not post:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="게시글을 찾을 수 없습니다.",
            )

        # 추천 처리
        result = await redis_service.recommend_post(post_id)

        logger.info(f"게시글 추천됨: {post_id}, 추천수: {result['recommendations']}")

        return PostRecommendResponse(**result)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"게시글 추천 실패: {post_id}, 에러: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"게시글 추천에 실패했습니다: {str(e)}",
        )


@router.post("/{post_id}/report", response_model=PostReportResponse)
async def report_post(
    post_id: str,
    redis_client: redis.Redis = Depends(get_redis),
):
    """
    게시글 신고

    게시글을 신고합니다. 50번째 신고로 게시글이 블라인드됩니다.

    Args:
        post_id: 게시글 ID
        redis_client: Redis 클라이언트

    Returns:
        PostReportResponse: 신고 결과

    Raises:
        HTTPException: 게시글을 찾을 수 없는 경우 (404)
    """
    try:
        redis_service = RedisService(redis_client)

        # 게시글 존재 확인
        post = await redis_service.get_post(post_id)
        if not post:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="게시글을 찾을 수 없습니다.",
            )

        # 신고 처리
        result = await redis_service.report_post(post_id)

        logger.warning(f"게시글 신고됨: {post_id}, 신고수: {result['reports']}")

        return PostReportResponse(**result)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"게시글 신고 실패: {post_id}, 에러: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"게시글 신고에 실패했습니다: {str(e)}",
        )


@router.get("/ranking/{rank_type}", response_model=list[PostResponse])
async def get_ranking(
    rank_type: Literal["views", "recs"] = "views",
    limit: int = 10,
    redis_client: redis.Redis = Depends(get_redis),
):
    """
    게시글 랭킹 조회

    조회수 또는 추천수 상위 게시글 랭킹을 조회합니다.

    Args:
        rank_type: 랭킹 타입 ("views" 또는 "recs")
        limit: 가져올 개수 (기본값: 10, 최대: 50)
        redis_client: Redis 클라이언트

    Returns:
        list[PostResponse]: 랭킹 게시글 리스트
    """
    try:
        limit = min(limit, 50)  # 최대 50개 제한
        redis_service = RedisService(redis_client)
        ranking = await redis_service.get_ranking(rank_type, limit)

        # PostResponse 리스트로 변환
        posts = [PostResponse(**item["post"]) for item in ranking]

        return posts

    except Exception as e:
        logger.error(f"랭킹 조회 실패: {rank_type}, 에러: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"랭킹 조회에 실패했습니다: {str(e)}",
        )
