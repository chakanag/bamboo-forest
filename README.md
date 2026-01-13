# 🎋 Anonymous Bamboo Forest (Project: Time-Limited)

> **"모든 감정에는 유효기간이 있다."**
>
> 시간 제한이 있는 익명 대나무숲 서비스. 사용자의 공감(추천)을 통해 글의 수명을 연장하고, AI를 통해 시대의 의제를 파악하는 소셜 플랫폼 프로젝트입니다.

## 1. 프로젝트 개요 (Overview)
이 서비스는 휘발성(Volatility)과 공감(Empathy)을 결합한 익명 커뮤니티입니다. 기본적으로 모든 글은 10분 뒤 사라지지만, 타인의 공감을 얻으면 생명력을 얻어 더 오래 세상에 머물 수 있습니다.

### 핵심 가치
* **Simple:** 200자 내외의 짧은 글, 직관적인 UI.
* **Ephemeral:** 기본 10분 노출 후 자동 삭제 (Redis TTL 활용).
* **Survival:** 추천을 통한 시간 연장 게임화(Gamification).
* **Analytics:** AI를 활용한 카테고리 자동화 및 시대적 의제(Agenda) 분석.

---

## 2. 핵심 기능 및 규칙 (Business Logic)

### 📝 작성 (Write)
* **제약:** 200글자 내외의 텍스트만 작성 가능.
* **AI 태깅:** 작성 시 AI가 내용을 분석하여 자동으로 카테고리/태그 부여.

### ⏳ 생명주기 (Lifecycle - The "Time is Life" System)
1. **기본 수명:** 글 작성 시 **10분(600초)**의 카운트다운 시작.
2. **생명 연장:** 추천(공감) **100회** 달성 시마다 수명 **5분(300초)** 연장.
3. **영구 보존 (Hall of Fame):** 누적 노출(View) **10만 회** 달성 시 시간 제한 해제 및 '영구 저장소'로 이동.
4. **삭제 (Death):** 시간이 0이 되면 사용자 화면에서 즉시 블라인드 처리 (분석용 DB로는 백업).

### 🛡️ 관리 및 제재 (Moderation)
* **신고:** 누적 신고 **50회** 이상 시 즉시 **비노출(Blind)** 처리.
* **데이터 보존:** 신고로 삭제된 글은 법적 대응 및 징계 처리를 위해 별도 관리자 DB에 원본 보존.

---

## 3. 기술 스택 (Tech Stack)

효율적인 1인 개발과 고성능 처리를 위해 다음 스택을 사용합니다.

| 구분 | 기술 | 설명 |
| :--- | :--- | :--- |
| **Backend** | **Python FastAPI** | 비동기 처리 지원, 높은 생산성, AI 라이브러리 연동 용이 |
| **Database** | **Redis** | 게시글의 수명(TTL) 관리, 실시간 랭킹/조회수 처리 (Hot Data) |
| **Database** | **Supabase (PostgreSQL)** | 영구 데이터 저장, 사용자 인증(Auth), 벡터 검색 (Cold Data) |
| **Frontend** | **Flutter** | iOS/Android/Web 크로스 플랫폼 지원, 심플한 UI 구현 |
| **AI/ML** | **OpenAI API / LangChain** | 글 카테고리 분류, 요약, 감정 분석 |
| **Infra** | **Docker** | 개발 환경의 일관성 유지 (Redis 등) |

---

## 4. 시스템 아키텍처 (Architecture)

```mermaid
graph TD
    User[User Client (Flutter)] -->|API Request| API[FastAPI Gateway]
    
    subgraph "Backend Logic"
        API -->|1. Write/Read (TTL)| Redis[(Redis Cache)]
        API -->|2. Archive/Log| DB[(Supabase PG)]
        API -->|3. Analyze| AI[AI Agent]
    end
    
    Redis -->|Expired| DB
    AI -->|Tagging/Summary| DB
```
---

## 5. 프로젝트 구조(directory Structure)
```
bamboo-forest/
├── app/
│   ├── main.py          # App Entry Point
│   ├── api/             # Endpoints (v1)
│   ├── core/            # Config, Security
│   ├── models/          # DB Models
│   ├── schemas/         # Pydantic DTOs
│   └── services/        # Business Logic (Redis, AI)
├── docker-compose.yml   # Redis & Local Infra
├── requirements.txt     # Python Dependencies
└── .env                 # Environment Variables
```

---

## 6. 시작하기 (Getting Started)

### **사전 준비**
* Python 3.10+

* Docker & Docker Compose

### 설치 및 실행
1. **환경 설정 및 패키지 설치**
``` 
Bash

python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

2. **인프라 실행 (Redis)**
```
Bash

docker-compose up -d
```
3. **서버 실행**
```
Bash

uvicorn app.main:app --reload
```
* Swagger API Docs: http://localhost:8000/docs

## 7. 개발 로드맵 (Roadmap)
[ ] Phase 1: MVP (Core Logic)

[x] 프로젝트 세팅 및 Redis 연동

[ ] 게시글 작성 API (TTL 10분 설정)

[ ] 게시글 조회 및 추천(시간 연장) 로직 구현

[ ] Phase 2: Client & AI

[ ] Flutter 기본 UI (타임라인) 구현

[ ] OpenAI API 연동 (자동 태깅)

[ ] Phase 3: Stabilization & Analytics

[ ] Supabase 영구 저장소 연동 (명예의 전당)

[ ] 신고 처리 및 관리자 기능

[ ] 통계 대시보드 API

---

### ✅ Next Step
`README.md` 파일을 저장하신 후, OpenCode 채팅창에 아래와 같이 입력하여 **본격적인 개발(Phase 1)**을 시작해보세요.

> **"README.md 파일 내용을 참고해서, `app/api/endpoints/posts.py`에 게시글 작성(POST) 및 조회(GET) API를 만들어줘. Redis를 사용해서 10분 뒤에 삭제되는 로직이 포함되어야 해."**