"""
AI 서비스

OpenAI API를 사용하여 게시글의 카테고리 태깅 및 감정 분석을 수행합니다.
"""

import asyncio
from typing import Optional

import redis.asyncio as redis
from openai import AsyncOpenAI

from app.core.config import get_settings
from loguru import logger

settings = get_settings()


class AIService:
    """
    AI 태깅 및 분석 서비스
    """

    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client
        self.client = AsyncOpenAI(api_key=settings.openai_api_key)

    async def tag_post(self, post_id: str, content: str) -> list[str]:
        """
        게시글 태깅 (비동기 처리)

        OpenAI를 사용하여 게시글 내용에서 카테고리 태그를 생성합니다.
        백그라운드에서 비동기로 실행되어 API 응답을 막지 않습니다.

        Args:
            post_id: 게시글 ID
            content: 게시글 내용

        Returns:
            list[str]: 생성된 태그 목록
        """
        try:
            logger.info(f"AI 태깅 시작: {post_id}")

            # OpenAI API 호출
            response = await self.client.chat.completions.create(
                model=settings.openai_model,
                messages=[
                    {
                        "role": "system",
                        "content": "당신은 익명 커뮤니티 게시글을 분석하여 태그를 생성하는 AI입니다. "
                        "게시글 내용을 읽고, 2-3개의 짧은 태그(한국어, 최대 5자)를 생성하세요. "
                        "태그는 쉼표로 구분하여 JSON 형식의 리스트로 반환하세요. "
                        "예: ['일상', '감성'] 또는 ['질문', '개발']",
                    },
                    {"role": "user", "content": content},
                ],
                temperature=0.7,
                max_tokens=100,
            )

            # 응답 파싱
            content_text = response.choices[0].message.content

            # JSON 파싱 (안전하게 처리)
            import ast

            try:
                tags = ast.literal_eval(content_text)
                if isinstance(tags, list):
                    tags = [str(tag)[:5] for tag in tags if tag]  # 태그 길이 제한
                else:
                    tags = []
            except (ValueError, SyntaxError):
                # 파싱 실패 시 기본 태그
                tags = ["기타"]

            logger.info(f"AI 태깅 완료: {post_id}, 태그: {tags}")

            # Redis에 태그 업데이트
            await self.redis.hset(f"post:{post_id}", "tags_json", str(tags))

            return tags

        except Exception as e:
            logger.error(f"AI 태깅 실패: {post_id}, 에러: {str(e)}")
            # 실패 시 기본 태그 반환
            return ["기타"]

    async def analyze_sentiment(self, content: str) -> dict:
        """
        감정 분석 (옵션)

        게시글의 긍정/부정 감정을 분석합니다.

        Args:
            content: 게시글 내용

        Returns:
            dict: 감정 분석 결과
        """
        try:
            response = await self.client.chat.completions.create(
                model=settings.openai_model,
                messages=[
                    {
                        "role": "system",
                        "content": "당신은 텍스트의 감정을 분석하는 AI입니다. "
                        "텍스트를 읽고, 'positive', 'neutral', 'negative' 중 하나로 분류하세요. "
                        "반환 형식: {'sentiment': 'positive', 'confidence': 0.85}",
                    },
                    {"role": "user", "content": content},
                ],
                temperature=0.3,
                max_tokens=50,
            )

            import ast

            content_text = response.choices[0].message.content
            sentiment_data = ast.literal_eval(content_text)

            return sentiment_data

        except Exception as e:
            logger.error(f"감정 분석 실패: {str(e)}")
            return {"sentiment": "neutral", "confidence": 0.0}
