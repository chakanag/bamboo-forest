"""
게시글 API 테스트

게시글 생성, 조회, 추천, 신고 기능을 테스트합니다.
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, AsyncMock

from app.main import app

client = TestClient(app)


class TestCreatePost:
    """게시글 생성 테스트"""

    def test_create_post_success(self):
        """게시글 생성 성공"""
        response = client.post(
            "/api/v1/posts/",
            json={"content": "테스트 게시글입니다."},
        )

        assert response.status_code == 201
        data = response.json()
        assert "id" in data
        assert data["content"] == "테스트 게시글입니다."
        assert data["tags"] == []  # 초기에는 빈 태그
        assert data["views"] == 0
        assert data["recommendations"] == 0
        assert data["reports"] == 0
        assert data["status"] == "active"
        assert data["ttl_seconds"] == 600  # 기본 10분

    def test_create_post_too_long(self):
        """너무 긴 게시글 생성 실패"""
        response = client.post(
            "/api/v1/posts/",
            json={"content": "a" * 201},  # 200자 초과
        )

        assert response.status_code == 422  # Validation Error

    def test_create_post_empty(self):
        """빈 게시글 생성 실패"""
        response = client.post("/api/v1/posts/", json={"content": ""})

        assert response.status_code == 422


class TestGetPosts:
    """게시글 목록 조회 테스트"""

    def test_get_posts_empty(self):
        """빈 게시글 목록 조회"""
        response = client.get("/api/v1/posts/")

        assert response.status_code == 200
        data = response.json()
        assert data["posts"] == []
        assert data["total"] == 0
        assert data["page"] == 1
        assert data["per_page"] == 20

    def test_get_posts_with_data(self):
        """게시글 목록 조회 (데이터 있음)"""
        # 게시글 생성
        client.post("/api/v1/posts/", json={"content": "게시글 1"})
        client.post("/api/v1/posts/", json={"content": "게시글 2"})

        # 목록 조회
        response = client.get("/api/v1/posts/")

        assert response.status_code == 200
        data = response.json()
        assert len(data["posts"]) == 2
        assert data["total"] == 2


class TestGetPost:
    """게시글 상세 조회 테스트"""

    def test_get_post_success(self):
        """게시글 상세 조회 성공"""
        # 게시글 생성
        create_response = client.post("/api/v1/posts/", json={"content": "테스트 게시글"})
        post_id = create_response.json()["id"]

        # 상세 조회
        response = client.get(f"/api/v1/posts/{post_id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == post_id
        assert data["content"] == "테스트 게시글"
        assert data["views"] == 1  # 조회 시 조회수 증가

    def test_get_post_not_found(self):
        """존재하지 않는 게시글 조회 실패"""
        response = client.get("/api/v1/posts/nonexistent_post")

        assert response.status_code == 404
        data = response.json()
        assert "detail" in data


class TestRecommendPost:
    """게시글 추천 테스트"""

    def test_recommend_post_success(self):
        """게시글 추천 성공"""
        # 게시글 생성
        create_response = client.post("/api/v1/posts/", json={"content": "테스트 게시글"})
        post_id = create_response.json()["id"]

        # 추천
        response = client.post(f"/api/v1/posts/{post_id}/recommend")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] == True
        assert data["recommendations"] == 1
        assert "ttl_seconds" in data

    def test_recommend_post_multiple(self):
        """다중 추천 테스트"""
        # 게시글 생성
        create_response = client.post("/api/v1/posts/", json={"content": "테스트 게시글"})
        post_id = create_response.json()["id"]

        # 101번 추천
        for _ in range(101):
            response = client.post(f"/api/v1/posts/{post_id}/recommend")

        # 마지막 응답 확인
        assert response.status_code == 200
        data = response.json()
        assert data["recommendations"] == 101
        assert data["ttl_seconds"] == 600 + 300  # 10분 + 5분 연장
        assert "100번째 추천" in data["message"]

    def test_recommend_post_not_found(self):
        """존재하지 않는 게시글 추천 실패"""
        response = client.post("/api/v1/posts/nonexistent_post/recommend")

        assert response.status_code == 404


class TestReportPost:
    """게시글 신고 테스트"""

    def test_report_post_success(self):
        """게시글 신고 성공"""
        # 게시글 생성
        create_response = client.post("/api/v1/posts/", json={"content": "테스트 게시글"})
        post_id = create_response.json()["id"]

        # 신고
        response = client.post(f"/api/v1/posts/{post_id}/report")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] == True
        assert data["reports"] == 1

    def test_report_post_blind(self):
        """50번 신고로 블라인드 처리"""
        # 게시글 생성
        create_response = client.post("/api/v1/posts/", json={"content": "테스트 게시글"})
        post_id = create_response.json()["id"]

        # 50번 신고
        for _ in range(50):
            response = client.post(f"/api/v1/posts/{post_id}/report")

        # 마지막 응답 확인
        assert response.status_code == 200
        data = response.json()
        assert data["reports"] == 50
        assert "블라인드되었습니다" in data["message"]

    def test_report_post_not_found(self):
        """존재하지 않는 게시글 신고 실패"""
        response = client.post("/api/v1/posts/nonexistent_post/report")

        assert response.status_code == 404


class TestRanking:
    """랭킹 조회 테스트"""

    def test_get_views_ranking(self):
        """조회수 랭킹 조회"""
        # 게시글 생성
        post1 = client.post("/api/v1/posts/", json={"content": "게시글 1"}).json()["id"]
        post2 = client.post("/api/v1/posts/", json={"content": "게시글 2"}).json()["id"]

        # 조회수 증가
        client.get(f"/api/v1/posts/{post1}")
        client.get(f"/api/v1/posts/{post1}")  # post1: 2회

        # 랭킹 조회
        response = client.get("/api/v1/posts/ranking/views")

        assert response.status_code == 200
        data = response.json()
        assert len(data) > 0
        assert data[0]["views"] >= 2  # 첫 번째 게시글의 조회수 확인

    def test_get_recs_ranking(self):
        """추천수 랭킹 조회"""
        # 게시글 생성
        post1 = client.post("/api/v1/posts/", json={"content": "게시글 1"}).json()["id"]
        post2 = client.post("/api/v1/posts/", json={"content": "게시글 2"}).json()["id"]

        # 추천수 증가
        for _ in range(10):
            client.post(f"/api/v1/posts/{post1}/recommend")

        # 랭킹 조회
        response = client.get("/api/v1/posts/ranking/recs")

        assert response.status_code == 200
        data = response.json()
        assert len(data) > 0
        assert any(post["recommendations"] >= 10 for post in data)


class TestHealthAndRoot:
    """헬스 체크 및 루트 엔드포인트 테스트"""

    def test_health_check(self):
        """헬스 체크"""
        response = client.get("/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "app_name" in data
        assert "version" in data

    def test_root_endpoint(self):
        """루트 엔드포인트"""
        response = client.get("/")

        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert data["docs"] == "/docs"
        assert data["health"] == "/health"
