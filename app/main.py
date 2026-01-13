"""
FastAPI 애플리케이션 엔트리 포인트

애플리케이션 초기화, 라우터 등록, 미들웨어 설정을 담당합니다.
"""

import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.endpoints.posts import router as posts_router
from app.core.config import get_settings, close_connections, logger
from app.services.redis_service import RedisService
from app.core.config import get_redis

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    애플리케이션 라이프사이클 관리

    Startup: 백그라운드 작업 시작
    Shutdown: 연결 정리
    """
    # Startup
    logger.info(f"{settings.app_name} v{settings.app_version} 시작됨")

    # 인덱스 정리 작업 시작 (백그라운드 코루틴)
    redis_client = await get_redis()
    redis_service = RedisService(redis_client)

    async def cleanup_task():
        """주기적 인덱스 정리 작업"""
        while True:
            try:
                await redis_service.cleanup_expired_indexes()
            except Exception as e:
                logger.error(f"인덱스 정리 실패: {str(e)}")
            await asyncio.sleep(30)  # 30초마다 실행

    # 백그라운드 작업 시작
    cleanup_task_obj = asyncio.create_task(cleanup_task())

    yield

    # Shutdown
    logger.info("애플리케이션 종료 중...")
    cleanup_task_obj.cancel()
    try:
        await cleanup_task_obj
    except asyncio.CancelledError:
        pass
    await close_connections()
    logger.info("연결 정리 완료")


# FastAPI 애플리케이션 생성
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="시간 제한이 있는 익명 대나무숲 API",
    lifespan=lifespan,
)

# CORS 미들웨어 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 예외 처리 (전역 에러 핸들러)
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """
    전역 예외 핸들러

    처리되지 않은 예외를 캐치하여 적절한 형식으로 응답합니다.
    """
    logger.error(f"처리되지 않은 예외: {str(exc)}", exc_info=True)

    return JSONResponse(
        status_code=500,
        content={
            "error": "INTERNAL_SERVER_ERROR",
            "message": "서버 내부 오류가 발생했습니다.",
            "detail": str(exc) if settings.debug else None,
        },
    )


# 라우터 등록
app.include_router(posts_router)


# 헬스 체크 엔드포인트
@app.get("/health")
async def health_check():
    """
    헬스 체크

    애플리케이션 상태를 확인합니다.
    """
    return {
        "status": "healthy",
        "app_name": settings.app_name,
        "version": settings.app_version,
    }


# 루트 엔드포인트
@app.get("/")
async def root():
    """
    루트 엔드포인트

    API 기본 정보를 반환합니다.
    """
    return {
        "message": "Anonymous Bamboo Forest API",
        "version": settings.app_version,
        "docs": "/docs",
        "health": "/health",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        log_level=settings.log_level.lower(),
    )
