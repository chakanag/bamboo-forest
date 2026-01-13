"""
게시글 관련 Pydantic 스키마

API 요청/응답의 데이터 구조와 유효성 검증을 정의합니다.
"""

from datetime import datetime
from typing import Optional
from enum import Enum

from pydantic import BaseModel, Field, field_validator


class PostStatus(str, Enum):
    """게시글 상태"""

    ACTIVE = "active"
    BLINDED = "blinded"
    EXPIRED = "expired"
    HALL_OF_FAME = "hall_of_fame"


class PostCreate(BaseModel):
    """
    게시글 생성 요청 스키마

    사용자로부터 받을 입력 데이터를 정의합니다.
    """

    content: str = Field(
        ...,
        min_length=1,
        max_length=200,
        description="게시글 내용 (최대 200자)",
    )

    @field_validator("content")
    @classmethod
    def validate_content(cls, v: str) -> str:
        """게시글 내용 검증"""
        v = v.strip()
        if not v:
            raise ValueError("게시글 내용은 비워둘 수 없습니다.")
        return v


class PostResponse(BaseModel):
    """
    게시글 응답 스키마

    API 응답에서 클라이언트에게 반환할 데이터를 정의합니다.
    """

    id: str = Field(..., description="게시글 고유 ID")
    content: str = Field(..., description="게시글 내용")
    created_at: datetime = Field(..., description="생성 시각")
    ttl_seconds: int = Field(..., description="남은 TTL (초), 0이면 만료 또는 영구 저장", ge=0)
    tags: list[str] = Field(default_factory=list, description="AI가 생성한 태그 목록")
    views: int = Field(default=0, description="조회수", ge=0)
    recommendations: int = Field(default=0, description="추천수", ge=0)
    reports: int = Field(default=0, description="신고수", ge=0)
    status: PostStatus = Field(default=PostStatus.ACTIVE, description="게시글 상태")

    class Config:
        json_schema_extra = {
            "example": {
                "id": "post_123456",
                "content": "오늘 날씨가 정말 좋네요! ☀️",
                "created_at": "2026-01-13T23:30:00Z",
                "ttl_seconds": 480,
                "tags": ["일상", "감성"],
                "views": 42,
                "recommendations": 5,
                "reports": 0,
                "status": "active",
            }
        }


class PostListResponse(BaseModel):
    """
    게시글 목록 응답 스키마
    """

    posts: list[PostResponse]
    total: int = Field(..., description="전체 게시글 수")
    page: int = Field(..., description="현재 페이지")
    per_page: int = Field(..., description="페이지당 게시글 수")


class PostRecommendResponse(BaseModel):
    """
    게시글 추천 응답 스키마
    """

    success: bool = Field(..., description="추천 성공 여부")
    recommendations: int = Field(..., description="업데이트된 추천수")
    ttl_seconds: int = Field(..., description="업데이트된 TTL (초)")
    message: Optional[str] = Field(None, description="추천 결과 메시지")

    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "recommendations": 101,
                "ttl_seconds": 480,
                "message": "100번째 추천! 5분 연장되었습니다.",
            }
        }


class PostReportResponse(BaseModel):
    """
    게시글 신고 응답 스키마
    """

    success: bool = Field(..., description="신고 성공 여부")
    reports: int = Field(..., description="업데이트된 신고수")
    message: Optional[str] = Field(None, description="신고 결과 메시지")

    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "reports": 1,
                "message": "게시글이 신고되었습니다.",
            }
        }


class ErrorResponse(BaseModel):
    """
    에러 응답 스키마 (표준화)
    """

    error: str = Field(..., description="에러 유형")
    message: str = Field(..., description="에러 메시지")
    detail: Optional[str] = Field(None, description="상세 에러 정보 (디버깅용)")

    class Config:
        json_schema_extra = {
            "example": {
                "error": "POST_NOT_FOUND",
                "message": "게시글을 찾을 수 없습니다.",
                "detail": "post_id=invalid_123 not found in Redis or Supabase",
            }
        }
