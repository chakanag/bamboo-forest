"""
애플리케이션 설정 및 의존성 주입 (Dependency Injection)

이 모듈은 환경 변수 설정, Redis 및 Supabase 클라이언트 초기화를 담당합니다.
"""

import os
from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict
import redis.asyncio as redis
from supabase import create_client

from loguru import logger


class Settings(BaseSettings):
    """
    애플리케이션 설정을 관리하는 Pydantic 모델

    환경 변수에서 값을 로드하며, 기본값을 제공합니다.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # FastAPI 설정
    app_name: str = "Anonymous Bamboo Forest"
    app_version: str = "1.0.0"
    debug: bool = True
    host: str = "0.0.0.0"
    port: int = 8000

    # Redis 설정
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0
    redis_password: Optional[str] = None
    redis_max_connections: int = 50

    # Supabase 설정
    supabase_url: str
    supabase_key: str
    supabase_service_role_key: Optional[str] = None

    # OpenAI 설정
    openai_api_key: str
    openai_model: str = "gpt-4o-mini"

    # 비즈니스 로직 설정 (초 단위)
    post_default_ttl: int = 600  # 10분
    recommendation_extension_ttl: int = 300  # 5분
    recommendation_extension_threshold: int = 100
    hall_of_fame_view_threshold: int = 100000
    report_blind_threshold: int = 50

    # 로깅 설정
    log_level: str = "INFO"

    # CORS 설정
    allowed_origins: str = "http://localhost:3000,http://localhost:8000,http://localhost:8080"

    @property
    def allowed_origins_list(self) -> list[str]:
        """CORS 허용 오리진을 리스트로 변환"""
        return [origin.strip() for origin in self.allowed_origins.split(",")]

    @property
    def redis_url(self) -> str:
        """Redis 연결 URL 생성"""
        if self.redis_password:
            return f"redis://:{self.redis_password}@{self.redis_host}:{self.redis_port}/{self.redis_db}"
        return f"redis://{self.redis_host}:{self.redis_port}/{self.redis_db}"


@lru_cache()
def get_settings() -> Settings:
    """
    캐시된 설정 인스턴스 반환 (Singleton 패턴)

    Returns:
        Settings: 애플리케이션 설정 인스턴스
    """
    return Settings()


# Redis 연결 풀 (전역 Singleton)
_redis_pool: Optional[redis.ConnectionPool] = None


async def get_redis_pool() -> redis.ConnectionPool:
    """
    Redis 연결 풀 생성 및 반환 (Singleton)

    전역으로 하나의 연결 풀을 재사용하여 연결 리소스를 효율적으로 관리합니다.

    Returns:
        redis.ConnectionPool: Redis 연결 풀 인스턴스
    """
    global _redis_pool

    if _redis_pool is None:
        settings = get_settings()
        _redis_pool = redis.ConnectionPool.from_url(
            settings.redis_url,
            max_connections=settings.redis_max_connections,
            socket_timeout=5,
            socket_connect_timeout=5,
            encoding="utf-8",
            decode_responses=True,
            health_check_interval=30,
        )
        logger.info("Redis 연결 풀 생성됨")

    return _redis_pool


async def get_redis() -> redis.Redis:
    """
    FastAPI Dependency Injection 용 Redis 클라이언트

    각 요청마다 연결 풀에서 연결을 가져와 사용합니다.

    Returns:
        redis.Redis: 비동기 Redis 클라이언트
    """
    pool = await get_redis_pool()
    return redis.Redis(connection_pool=pool)


# Supabase 클라이언트 (전역 Singleton)
_supabase_client = None


def get_supabase_client():
    """
    Supabase 클라이언트 생성 및 반환 (Singleton)

    Returns:
        supabase.Client: Supabase 동기 클라이언트
    """
    global _supabase_client

    if _supabase_client is None:
        settings = get_settings()
        _supabase_client = create_client(settings.supabase_url, settings.supabase_key)
        logger.info("Supabase 클라이언트 초기화됨")

    return _supabase_client


async def close_connections():
    """
    애플리케이션 종료 시 연결 정리

    Redis 연결 풀을 닫고 리소스를 해제합니다.
    """
    global _redis_pool

    if _redis_pool is not None:
        await _redis_pool.aclose()
        _redis_pool = None
        logger.info("Redis 연결 풀 닫힘")


# 로거 설정
logger.remove()
logger.add(
    sink=lambda msg: print(msg, end=""),
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan> - <level>{message}</level>",
    level=get_settings().log_level,
)
