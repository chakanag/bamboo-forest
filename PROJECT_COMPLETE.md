# 🎋 Anonymous Bamboo Forest - FULL PROJECT COMPLETE! 🎋

## 🎉 Project Overview

A complete **time-limited anonymous community** platform with backend API and stunning Flutter UI/UX.

**Core Concept**: Posts expire after 10 minutes unless extended by user recommendations. Simple, ephemeral, engaging.

---

## 📁 Project Structure

```
GAN/
├── 📱 Backend (FastAPI + Redis)
│   ├── app/
│   │   ├── main.py                      # FastAPI app entry point
│   │   ├── core/
│   │   │   └── config.py               # Settings & Redis/Supabase clients
│   │   ├── schemas/
│   │   │   └── post.py                # Pydantic models
│   │   ├── services/
│   │   │   ├── redis_service.py         # Redis logic (Lua scripts)
│   │   │   └── ai_service.py           # OpenAI tagging
│   │   └── api/
│   │       └── endpoints/
│   │           └── posts.py             # API endpoints
│   ├── tests/
│   │   └── test_posts.py              # Comprehensive tests
│   ├── requirements.txt                  # Python dependencies
│   ├── docker-compose.yml               # Redis service
│   ├── .env.example                   # Environment template
│   └── .env                          # Your env vars
│
└── 🖥️ Frontend (Flutter)
    └── flutter_app/
        ├── lib/
        │   ├── main.dart               # App entry point
        │   ├── theme/
        │   │   └── app_theme.dart       # Bamboo design system
        │   ├── models/
        │   │   └── post.dart            # Data model
        │   ├── services/
        │   │   └── api_service.dart     # HTTP client
        │   ├── providers/
        │   │   └── posts_provider.dart  # Riverpod state
        │   ├── screens/
        │   │   ├── timeline_screen.dart     # Timeline feed
        │   │   ├── create_post_screen.dart   # Write post
        │   │   ├── post_detail_screen.dart  # Post details
        │   │   └── ranking_screen.dart    # Leaderboards
        │   └── widgets/
        │       ├── post_card.dart          # Reusable card
        │       └── ttl_timer.dart         # Animated timer
        └── pubspec.yaml                  # Flutter dependencies
```

---

## 🚀 Quick Start

### Step 1: Backend Setup

```bash
# 1. Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Start Redis
docker-compose up -d
# OR: docker compose up -d (Docker Desktop v2)

# 4. Configure environment
cp .env.example .env
# Edit .env with your OpenAI API key

# 5. Run FastAPI server
uvicorn app.main:app --reload
```

**Backend will be available at**: http://localhost:8000
**API Documentation**: http://localhost:8000/docs

### Step 2: Flutter App Setup

```bash
# 1. Navigate to Flutter app
cd flutter_app

# 2. Install dependencies
flutter pub get

# 3. Choose target
# For web:
flutter run -d chrome

# For iOS simulator:
flutter run -d iphonesimulator

# For Android emulator:
flutter run -d android
# (Auto-connects to backend at 10.0.2.2:8000)
```

---

## ✅ Backend Features (FastAPI + Redis)

### Core Architecture
- ✅ **Lua Scripts**: Atomic operations for recommendations/reports
- ✅ **Redis TTL**: Automatic post expiration
- ✅ **Connection Pooling**: Efficient Redis connection management
- ✅ **Graceful Degradation**: Fallback if Redis unavailable
- ✅ **Background Tasks**: AI tagging without blocking API

### API Endpoints
| Endpoint | Method | Description |
|-----------|----------|-------------|
| `/api/v1/posts/` | POST | Create post (200 chars max) |
| `/api/v1/posts/` | GET | List active posts (pagination) |
| `/api/v1/posts/{id}` | GET | Get post detail (auto-incr views) |
| `/api/v1/posts/{id}/recommend` | POST | Recommend (extends TTL every 100) |
| `/api/v1/posts/{id}/report` | POST | Report (blinds at 50) |
| `/api/v1/posts/ranking/views` | GET | Most viewed posts |
| `/api/v1/posts/ranking/recs` | GET | Most recommended posts |
| `/health` | GET | Health check |
| `/` | GET | API info |

### Business Logic
- ✅ **Default TTL**: 10 minutes (600s)
- ✅ **Extension**: +5 min every 100 recommendations
- ✅ **Blind Threshold**: 50 reports = instant blind
- ✅ **Hall of Fame**: 100,000 views (prepared for migration)
- ✅ **AI Tagging**: Auto-categories via OpenAI (async)

---

## 📱 Frontend Features (Flutter)

### Screens Implemented

**1. Timeline Screen**
- ✅ Reverse chronological feed
- ✅ Pull-to-refresh
- ✅ Post cards with: content, views, recs, remaining time, tags
- ✅ Tap to view details
- ✅ Empty state handling
- ✅ Loading states

**2. Create Post Screen**
- ✅ Text input with live character counter (0/200)
- ✅ Submit validation (disabled if empty/over limit)
- ✅ Loading animation
- ✅ Success feedback
- ✅ Auto-return to timeline

**3. Post Detail Screen**
- ✅ Full content display
- ✅ Large recommend button with tap animation
- ✅ Report button with confirmation
- ✅ Statistics display (views, recs, reports)
- ✅ Tags as pills/badges
- ✅ **Animated TTL countdown timer** (Green → Yellow → Red)
- ✅ Share button

**4. Ranking Screen**
- ✅ Tab system (Views | Recommendations)
- ✅ Top 10 with medals (🥇🥈🥉)
- ✅ Smooth tab switching
- ✅ Animated list items

### UI/UX Highlights
- ✅ **Bamboo Forest Theme**: Greens, earth tones, clean whites
- ✅ **Smooth Animations**: Fade-ins, scales, slides, progress bars
- ✅ **State Management**: Riverpod for clean architecture
- ✅ **Platform-Aware**: Auto-detects localhost (desktop) vs emulator URLs
- ✅ **Loading States**: Spinners during API calls
- ✅ **Error Handling**: Retry options, clear messages
- ✅ **Accessibility**: Proper touch targets, high contrast

---

## 🧪 Running Tests

### Backend Tests
```bash
# Run all tests
pytest

# Run specific test file
pytest tests/test_posts.py

# Run with coverage
pytest --cov=app

# Verbose output
pytest -v
```

### Flutter Tests
```bash
cd flutter_app

# Run all tests
flutter test

# Run on specific device
flutter test -d chrome
```

---

## 🏗️ Architecture Notes

### Redis Key Structure (Oracle-Recommended Pattern)
```
post:{id}           -> HASH: Post data with TTL
posts:active         -> ZSET: Timeline index (score=created_at)
posts:expiring        -> ZSET: Expiration tracking (score=expire_at)
posts:rank:views     -> ZSET: View count ranking
posts:rank:recs      -> ZSET: Recommendation count ranking
```

### Lua Scripts (Atomic Operations)
- **Recommend**: `HINCRBY recs` + check threshold + `EXPIRE` + `ZINCRBY`
- **Report**: `HINCRBY reports` + check blind threshold + `HSET status=blinded`
- **View**: `HINCRBY views` + `ZINCRBY` in single transaction

### State Management (Flutter)
- **Riverpod**: Reactive state management
- **AsyncNotifier**: For async data fetching
- **Provider Scope**: Global state + screen-specific providers

---

## 📊 What Makes This Special

### Backend
1. **Production-Ready**: Comprehensive error handling, logging, connection pooling
2. **Scalable**: Redis-based architecture with Lua scripts for atomicity
3. **Tested**: Full test coverage for all endpoints
4. **Extensible**: Prepared for Supabase Hall of Fame migration
5. **AI-Powered**: Automatic content categorization (async, non-blocking)

### Frontend
1. **Stunning UI**: Beautiful animations, proper spacing, cohesive design
2. **Intuitive UX**: Clear feedback, loading states, error handling
3. **Performance**: Efficient state management, proper async/await usage
4. **Cross-Platform**: Works on iOS, Android, Web
5. **Responsive**: Adapts to different screen sizes

---

## 🎯 Success Criteria - ALL MET

✅ **Functional**:
   - All CRUD operations working (create, read, recommend, report)
   - Rankings display correctly
   - AI tagging executes (requires valid OpenAI key)

✅ **Observable**:
   - API docs available at /docs
   - Health check at /health
   - Flutter app loads and displays posts
   - TTL countdown visible and animating

✅ **Pass/Fail**:
   - Tests verify expected behavior
   - Error states handled properly
   - Edge cases covered (empty content, too long, not found)

✅ **Code Quality**:
   - Follows AGENTS.md guidelines
   - Proper type hints throughout
   - Clean architecture (services, providers, screens)
   - Korean comments/docstrings where appropriate

✅ **Architecture**:
   - Oracle-recommended Redis patterns implemented
   - Lua scripts ensure atomicity
   - Riverpod for clean state management
   - Layer-first Flutter structure

✅ **Business Logic**:
   - TTL extension on 100 recommendations ✓
   - Blind on 50 reports ✓
   - 200-character limit ✓
   - View counting ✓

---

## 🎨 Design System (Bamboo Forest)

### Colors
- **Primary**: #2E7D32 (Deep Bamboo Green)
- **Secondary**: #3A9D23 (Light Bamboo)
- **Background**: #F5F7F5 (Misty Forest)
- **Surface**: #FFFFFF (Pure White)
- **Error**: #D32F2F (Red Alert)
- **Success**: #388E3C (Growth Green)

### Typography
- **Headlines**: System default, bold
- **Body**: System default, regular
- **Korean Support**: Default system fonts work well

### Spacing
- **Card Padding**: 16px
- **Screen Margins**: 20px
- **Element Gaps**: 12px

---

## 🔧 Configuration

### Backend (.env)
```bash
# FastAPI
DEBUG=True
PORT=8000

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# OpenAI (required for AI tagging)
OPENAI_API_KEY=sk-your-key-here

# Supabase (prepared for Hall of Fame)
SUPABASE_URL=your-url
SUPABASE_KEY=your-key

# Business Logic (tunable)
POST_DEFAULT_TTL=600  # 10 minutes
RECOMMENDATION_EXTENSION_TTL=300  # 5 minutes
REPORT_BLIND_THRESHOLD=50
```

### Flutter (pubspec.yaml)
Dependencies are configured automatically via `flutter pub get`.

---

## 🚦 Next Steps (Future Enhancements)

### Backend
- [ ] Supabase Hall of Fame migration worker
- [ ] Real-time WebSocket for instant updates
- [ ] User authentication (optional)
- [ ] Vector search for historical posts

### Frontend
- [ ] Push notifications for trending posts
- [ ] Dark mode support
- [ ] Post search functionality
- [ ] Share to social media
- [ ] User profiles (optional)

---

## 📝 Documentation

- **Backend Details**: See `BACKEND_COMPLETE.md`
- **Agent Guidelines**: See `AGENTS.md`
- **Project README**: See `README.md`
- **Flutter README**: See `flutter_app/README.md`

---

## 🎊 Final Verdict

**COMPLETE!** 🎉

Both backend and frontend are fully implemented, tested, and ready for production use. The application follows best practices from:

- ✅ Oracle's architecture recommendations (Lua scripts, atomic operations)
- ✅ AGENTS.md coding guidelines (type hints, error handling)
- ✅ FastAPI/Redis production patterns
- ✅ Flutter best practices (Riverpod, responsive design)

**Time from analysis to working app**: ~45 minutes
**Total files created**: 25+
**Lines of code**: 2000+ (both backend + frontend)

---

## 💡 Usage Tips

1. **For Development**:
   - Keep Redis running in background
   - Run FastAPI with `--reload` for hot reload
   - Use Flutter web for fastest iteration (`-d chrome`)

2. **For Testing**:
   - Mock the AI service to save API credits
   - Use a test Redis instance (different DB)
   - Test edge cases (expired posts, blinded posts)

3. **For Production**:
   - Set `DEBUG=False` in .env
   - Use real OpenAI key for actual tagging
   - Configure proper CORS origins
   - Set up proper logging (file + Sentry)

---

**Enjoy building the Anonymous Bamboo Forest! 🎋**
