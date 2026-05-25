#!/usr/bin/env bash
# =============================================================================
#  yeongi.sh — Yeongi 프로젝트 통합 관리 스크립트
#  마음도 지워질 자유가 있다.
#
#  사용법:
#    ./yeongi.sh <command> [target]
#
#  Commands : start | stop | restart | status | logs | build | setup
#  Targets  : all | redis | api | app
# =============================================================================

set -euo pipefail

# ── 경로 설정 ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
FLUTTER_DIR="$PROJECT_ROOT/flutter_app"
VENV_DIR="$PROJECT_ROOT/venv"
PIDS_DIR="$PROJECT_ROOT/.pids"
LOGS_DIR="$PROJECT_ROOT/.logs"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

mkdir -p "$PIDS_DIR" "$LOGS_DIR"

# ── 색상 / 아이콘 ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── 로그 헬퍼 ─────────────────────────────────────────────────────────────────
log_ok()      { echo -e "  ${GREEN}✓${NC}  $*"; }
log_info()    { echo -e "  ${BLUE}›${NC}  $*"; }
log_warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; }
log_error()   { echo -e "  ${RED}✗${NC}  $*" >&2; }
log_header()  {
  echo ""
  echo -e "${PURPLE}${BOLD}  ▸ $*${NC}"
  echo -e "${DIM}  $(printf '─%.0s' {1..48})${NC}"
}

# ── PID 파일 헬퍼 ─────────────────────────────────────────────────────────────
pid_file() { echo "$PIDS_DIR/$1.pid"; }
log_file()  { echo "$LOGS_DIR/$1.log"; }

is_running() {
  local f; f="$(pid_file "$1")"
  [[ -f "$f" ]] || return 1
  local pid; pid="$(cat "$f")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

get_pid() { cat "$(pid_file "$1")" 2>/dev/null || echo ""; }

# 프로세스 그룹까지 종료 (macOS / Linux 공통)
kill_proc() {
  local pid="$1"
  # 자식 프로세스 먼저 종료
  pkill -P "$pid" 2>/dev/null || true
  sleep 0.3
  kill "$pid" 2>/dev/null || true
  # 남아있으면 강제 종료
  sleep 1
  kill -9 "$pid" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
#  REDIS (docker-compose)
# ═══════════════════════════════════════════════════════════════════════════════

redis_is_running() {
  docker compose -f "$COMPOSE_FILE" ps redis 2>/dev/null \
    | grep -qE "running|Up" 2>/dev/null
}

redis_start() {
  log_header "Redis"
  if redis_is_running; then
    log_ok "Redis 이미 실행 중 (port 6379)"
    return 0
  fi
  if ! command -v docker &>/dev/null; then
    log_error "Docker가 설치되지 않았습니다"
    return 1
  fi
  docker compose -f "$COMPOSE_FILE" up -d redis 2>&1 \
    | grep -v "^#" | sed 's/^/  /' || true
  sleep 1
  if redis_is_running; then
    log_ok "Redis 시작됨 (port 6379)"
  else
    log_error "Redis 시작 실패. docker logs bamboo-forest-redis 확인"
    return 1
  fi
}

redis_stop() {
  log_header "Redis"
  if ! redis_is_running; then
    log_warn "Redis가 실행 중이 아닙니다"
    return 0
  fi
  docker compose -f "$COMPOSE_FILE" stop redis 2>&1 | sed 's/^/  /' || true
  log_ok "Redis 중지됨"
}

redis_restart() {
  log_header "Redis"
  docker compose -f "$COMPOSE_FILE" restart redis 2>&1 | sed 's/^/  /' || true
  log_ok "Redis 재기동됨"
}

redis_status() {
  if redis_is_running; then
    # ping 체크
    local pong
    pong="$(docker exec bamboo-forest-redis redis-cli ping 2>/dev/null || echo "ERR")"
    if [[ "$pong" == "PONG" ]]; then
      printf "  ${GREEN}●${NC} ${BOLD}Redis${NC}   running  :6379  ${DIM}(PONG ok)${NC}\n"
    else
      printf "  ${YELLOW}●${NC} ${BOLD}Redis${NC}   running  :6379  ${DIM}(ping failed)${NC}\n"
    fi
  else
    printf "  ${RED}●${NC} ${BOLD}Redis${NC}   stopped\n"
  fi
}

redis_logs() {
  docker compose -f "$COMPOSE_FILE" logs -f --tail=80 redis
}

# ═══════════════════════════════════════════════════════════════════════════════
#  API (FastAPI + uvicorn — venv 격리)
# ═══════════════════════════════════════════════════════════════════════════════

_check_venv() {
  if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
    log_error "venv가 없습니다. 먼저 실행: ./yeongi.sh setup api"
    return 1
  fi
}

api_start() {
  log_header "API (FastAPI)"
  if is_running api; then
    log_ok "API 이미 실행 중 (PID: $(get_pid api), port: 8000)"
    return 0
  fi
  _check_venv || return 1

  # .env 필수 키 사전 검증
  if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    log_error ".env 파일이 없습니다. .env.example 을 복사하여 설정하세요"
    return 1
  fi
  local missing=()
  for key in SUPABASE_URL SUPABASE_KEY OPENAI_API_KEY; do
    local val; val="$(grep -E "^${key}=" "$PROJECT_ROOT/.env" | cut -d= -f2- | xargs)"
    [[ -z "$val" || "$val" == "your_"* ]] && missing+=("$key")
  done
  if (( ${#missing[@]} > 0 )); then
    log_error ".env 에 다음 키 값이 비어있습니다: ${missing[*]}"
    log_info ".env 파일을 열어 값을 채워주세요"
    return 1
  fi

  # Redis 연결 사전 확인
  if ! redis_is_running; then
    log_warn "Redis가 실행 중이 아닙니다 — 먼저 시작합니다"
    redis_start || return 1
    sleep 1
  fi

  cd "$PROJECT_ROOT"
  # venv 내에서만 실행 — 시스템 환경변수 등록 없음
  local log_f; log_f="$(log_file api)"
  : > "$log_f"  # 로그 초기화
  (
    source "$VENV_DIR/bin/activate"
    nohup python -m uvicorn app.main:app \
      --host 0.0.0.0 \
      --port 8000 \
      --reload \
      >> "$log_f" 2>&1 &
    echo $! > "$(pid_file api)"
  )

  # 기동 확인 — health endpoint 응답까지 대기 (최대 10초)
  log_info "기동 확인 중..."
  local i=0
  while (( i < 10 )); do
    sleep 1; (( i++ ))
    # 프로세스 살아있는지 + health 응답 오는지 모두 확인
    if is_running api && curl -sf --max-time 1 http://localhost:8000/health &>/dev/null; then
      log_ok "API 시작됨 (PID: $(get_pid api), port: 8000)"
      log_info "Swagger : http://localhost:8000/docs"
      log_info "Health  : http://localhost:8000/health"
      return 0
    fi
    # 프로세스가 이미 죽었으면 즉시 실패 처리
    if ! is_running api && (( i >= 3 )); then
      break
    fi
  done

  log_error "API 시작 실패. 최근 로그:"
  tail -20 "$log_f" | sed 's/^/    /' >&2
  log_info "전체 로그: ./yeongi.sh logs api"
  rm -f "$(pid_file api)"
  return 1
}

api_stop() {
  log_header "API (FastAPI)"
  local pid_f; pid_f="$(pid_file api)"
  if ! is_running api; then
    log_warn "API가 실행 중이 아닙니다"
    rm -f "$pid_f"
    return 0
  fi
  local pid; pid="$(get_pid api)"
  kill_proc "$pid"
  rm -f "$pid_f"
  log_ok "API 중지됨"
}

api_restart() {
  api_stop
  sleep 1
  api_start
}

api_status() {
  if is_running api; then
    local pid; pid="$(get_pid api)"
    # health endpoint 체크
    local health
    health="$(curl -sf --max-time 2 http://localhost:8000/health 2>/dev/null \
      | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("status","?"))' \
      2>/dev/null || echo "unreachable")"
    printf "  ${GREEN}●${NC} ${BOLD}API${NC}     running  :8000  ${DIM}(health: %s, PID: %s)${NC}\n" \
      "$health" "$pid"
  else
    printf "  ${RED}●${NC} ${BOLD}API${NC}     stopped\n"
  fi
}

api_logs() {
  local f; f="$(log_file api)"
  if [[ ! -f "$f" ]]; then
    log_warn "로그 파일이 없습니다: $f"
    return 1
  fi
  log_info "API 로그 스트림 (Ctrl+C 로 종료)"
  echo ""
  tail -n 50 -f "$f"
}

api_build() {
  log_header "API — 의존성 설치 (venv)"
  if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
    log_info "venv 생성 중..."
    python3 -m venv "$VENV_DIR"
    log_ok "venv 생성됨: $VENV_DIR"
  fi
  (
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip --quiet
    pip install -r "$PROJECT_ROOT/requirements.txt" --quiet
  )
  log_ok "Python 의존성 설치 완료"
  log_info "venv 경로: $VENV_DIR  (시스템 환경변수 미등록)"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  APP (Flutter)
# ═══════════════════════════════════════════════════════════════════════════════

_flutter_cmd() {
  # Flutter SDK 경로 자동 탐지
  if command -v flutter &>/dev/null; then
    echo "flutter"
  elif [[ -x "$HOME/flutter/bin/flutter" ]]; then
    echo "$HOME/flutter/bin/flutter"
  elif [[ -x "/opt/homebrew/bin/flutter" ]]; then
    echo "/opt/homebrew/bin/flutter"
  else
    log_error "Flutter SDK를 찾을 수 없습니다. PATH에 flutter가 있는지 확인하세요"
    return 1
  fi
}

# restart 시 이전 디바이스를 재사용하기 위한 내부 변수
_APP_FORCE_DEVICE=""

app_start() {
  log_header "Flutter App"
  local pid_f; pid_f="$(pid_file app)"

  if is_running app; then
    log_ok "Flutter 이미 실행 중 (PID: $(get_pid app))"
    return 0
  fi

  local fl; fl="$(_flutter_cmd)" || return 1
  cd "$FLUTTER_DIR"

  # web 지원 활성화 (최초 1회)
  $fl config --enable-web &>/dev/null 2>&1 || true

  local device="$_APP_FORCE_DEVICE"
  _APP_FORCE_DEVICE=""  # 사용 후 초기화

  if [[ -z "$device" ]]; then
    # ── 모바일 기기 탐지 (iOS 시뮬레이터 / Android 실기기) ─────────────────
    local mobile_lines
    mobile_lines="$($fl devices 2>/dev/null \
      | grep -v "^Found\|^No \|^$" \
      | grep -iE "ios|android" || true)"

    if [[ -z "$mobile_lines" ]]; then
      # 모바일 기기 없음 → Chrome 자동 선택
      device="chrome"
      log_info "연결된 모바일 기기 없음 → Chrome으로 자동 실행"
    else
      # 모바일 기기 감지 → 선택 메뉴 (Chrome이 기본 1번)
      echo ""
      echo -e "  ${BOLD}실행할 디바이스 선택:${NC}"
      echo ""
      printf "    ${GREEN}1)${NC}  %-32s %s\n" "Chrome" "(기본 — 웹 브라우저)"

      local idx=2
      local mobile_ids=()
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local dname; dname="$(echo "$line" | awk -F'•' '{print $1}' | xargs)"
        local did;   did="$(  echo "$line" | awk -F'•' '{print $2}' | xargs)"
        local dtype; dtype="$(echo "$line" | awk -F'•' '{print $3}' | xargs)"
        printf "    ${CYAN}%s)${NC}  %-32s %s\n" "$idx" "$dname" "($dtype)"
        mobile_ids+=("$did")
        (( idx++ ))
      done <<< "$mobile_lines"

      echo ""
      read -rp "  번호 선택 [엔터 = Chrome]: " dev_input

      if [[ -z "$dev_input" || "$dev_input" == "1" ]]; then
        device="chrome"
      elif [[ "$dev_input" =~ ^[0-9]+$ && "$dev_input" -ge 2 ]]; then
        local arr_idx=$(( dev_input - 2 ))
        device="${mobile_ids[$arr_idx]:-chrome}"
      else
        # 직접 ID 입력
        device="$dev_input"
      fi
    fi
  fi

  log_info "디바이스: $device"
  # 선택한 디바이스 저장 → restart 시 재사용
  echo "$device" > "$PIDS_DIR/app.device"

  # ── tmux 세션 또는 백그라운드 실행 ──────────────────────────────────────
  if command -v tmux &>/dev/null; then
    local session="yeongi-app"
    tmux kill-session -t "$session" 2>/dev/null || true
    tmux new-session -d -s "$session" \
      "cd '$FLUTTER_DIR' && $fl run -d '$device' 2>&1 | tee '$(log_file app)'"
    sleep 2
    local fl_pid
    fl_pid="$(pgrep -f "flutter run" | head -1 || echo "0")"
    echo "${fl_pid}" > "$pid_f"
    log_ok "Flutter 시작됨 (tmux: $session, device: $device)"
    log_info "핫 리로드 접속 : tmux attach -t $session"
    log_info "분리하기       : Ctrl+B, D"
    log_info "로그 보기      : ./yeongi.sh logs app"
  else
    log_warn "tmux 없음 → 백그라운드 실행 (brew install tmux 권장)"
    nohup $fl run -d "$device" >> "$(log_file app)" 2>&1 &
    echo $! > "$pid_f"
    log_ok "Flutter 시작됨 (PID: $(get_pid app), device: $device)"
    log_info "로그 보기: ./yeongi.sh logs app"
  fi
}

app_stop() {
  log_header "Flutter App"
  local pid_f; pid_f="$(pid_file app)"

  # tmux 세션 종료
  if command -v tmux &>/dev/null && tmux has-session -t yeongi-app 2>/dev/null; then
    tmux kill-session -t yeongi-app 2>/dev/null || true
    log_ok "Flutter tmux 세션 종료됨"
  fi

  # flutter run 프로세스 종료
  local fl_pids
  fl_pids="$(pgrep -f "flutter run" 2>/dev/null || true)"
  if [[ -n "$fl_pids" ]]; then
    echo "$fl_pids" | xargs kill 2>/dev/null || true
    log_ok "flutter run 프로세스 종료됨"
  fi

  # dart/frontend 빌드 프로세스 정리
  pkill -f "frontend_server" 2>/dev/null || true

  if is_running app; then
    kill_proc "$(get_pid app)"
  fi
  rm -f "$pid_f"
}

app_restart() {
  app_stop
  sleep 1
  # 이전에 선택했던 디바이스 재사용 (있으면)
  if [[ -f "$PIDS_DIR/app.device" ]]; then
    _APP_FORCE_DEVICE="$(cat "$PIDS_DIR/app.device")"
    log_info "이전 디바이스로 재기동: $_APP_FORCE_DEVICE"
  fi
  app_start
}

app_status() {
  local fl_running=false

  # tmux 세션 확인
  if command -v tmux &>/dev/null && tmux has-session -t yeongi-app 2>/dev/null; then
    fl_running=true
  fi

  # 프로세스 직접 확인
  if pgrep -f "flutter run" &>/dev/null; then
    fl_running=true
  fi

  if $fl_running; then
    local pid; pid="$(pgrep -f "flutter run" | head -1 || echo "-")"
    local tmux_info=""
    tmux has-session -t yeongi-app 2>/dev/null \
      && tmux_info=" ${DIM}[tmux: yeongi-app]${NC}"
    printf "  ${GREEN}●${NC} ${BOLD}App${NC}     running  ${DIM}(PID: %s)%s${NC}\n" \
      "$pid" "$tmux_info"
  else
    printf "  ${RED}●${NC} ${BOLD}App${NC}     stopped\n"
  fi
}

app_logs() {
  local f; f="$(log_file app)"
  if [[ ! -f "$f" ]]; then
    log_warn "로그 파일이 없습니다: $f"
    log_info "tmux 로그 보기: tmux attach -t yeongi-app"
    return 1
  fi
  log_info "Flutter 로그 스트림 (Ctrl+C 로 종료)"
  echo ""
  tail -n 50 -f "$f"
}

app_build() {
  log_header "Flutter 빌드"
  local fl; fl="$(_flutter_cmd)" || return 1
  cd "$FLUTTER_DIR"

  echo ""
  echo -e "  ${BOLD}빌드 타겟 선택:${NC}"
  echo ""
  echo "    1)  macOS  (데스크탑 앱)"
  echo "    2)  iOS    (시뮬레이터용 .app)"
  echo "    3)  iOS    (배포용 — 코드서명 필요)"
  echo "    4)  Android APK  (디버그)"
  echo "    5)  Android APK  (릴리즈)"
  echo "    6)  Web"
  echo ""
  read -rp "  번호 선택 [1-6]: " choice
  echo ""

  case "$choice" in
    1)
      log_info "macOS 빌드 시작..."
      $fl build macos --release
      log_ok "완료: $FLUTTER_DIR/build/macos/Build/Products/Release/"
      ;;
    2)
      log_info "iOS 빌드 시작 (no-codesign)..."
      $fl build ios --no-codesign
      log_ok "완료: $FLUTTER_DIR/build/ios/iphoneos/"
      ;;
    3)
      log_info "iOS 배포 빌드 시작..."
      $fl build ipa
      log_ok "완료: $FLUTTER_DIR/build/ios/ipa/"
      ;;
    4)
      log_info "Android APK (debug) 빌드 시작..."
      $fl build apk --debug
      log_ok "완료: $FLUTTER_DIR/build/app/outputs/flutter-apk/app-debug.apk"
      ;;
    5)
      log_info "Android APK (release) 빌드 시작..."
      $fl build apk --release
      log_ok "완료: $FLUTTER_DIR/build/app/outputs/flutter-apk/app-release.apk"
      ;;
    6)
      log_info "Web 빌드 시작..."
      $fl build web
      log_ok "완료: $FLUTTER_DIR/build/web/"
      ;;
    *)
      log_error "잘못된 선택: $choice"
      return 1
      ;;
  esac
}

app_pub() {
  log_header "Flutter — 패키지 설치"
  local fl; fl="$(_flutter_cmd)" || return 1
  cd "$FLUTTER_DIR"
  $fl pub get
  log_ok "패키지 설치 완료"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  STATUS DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════

show_status() {
  echo ""
  echo -e "${PURPLE}${BOLD}┌────────────────────────────────────────────────┐${NC}"
  echo -e "${PURPLE}${BOLD}│  Yeongi — 서비스 현황                          │${NC}"
  echo -e "${PURPLE}${BOLD}│  잠깐이었어도 진심이야.                         │${NC}"
  echo -e "${PURPLE}${BOLD}└────────────────────────────────────────────────┘${NC}"
  echo ""
  redis_status
  api_status
  app_status
  echo ""
  echo -e "${DIM}  로그 디렉터리 : $LOGS_DIR${NC}"
  echo -e "${DIM}  PID 디렉터리  : $PIDS_DIR${NC}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  SETUP (초기 환경 구성)
# ═══════════════════════════════════════════════════════════════════════════════

setup_all() {
  log_header "초기 환경 구성"
  echo ""
  log_info "1/3  Python venv 및 의존성 설치..."
  api_build
  echo ""
  log_info "2/3  Flutter 패키지 설치..."
  app_pub
  echo ""
  log_info "3/3  .env 파일 확인..."
  if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    log_warn ".env 파일이 없습니다"
    if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
      cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
      log_ok ".env.example → .env 복사됨 (값을 직접 입력하세요)"
    else
      log_warn ".env.example도 없습니다. 수동으로 .env 파일을 생성하세요"
    fi
  else
    log_ok ".env 파일 존재"
  fi
  echo ""
  log_ok "초기 설정 완료"
  echo ""
  echo -e "  다음 단계:"
  echo -e "    ${CYAN}./yeongi.sh start all${NC}    # 전체 서비스 시작"
  echo -e "    ${CYAN}./yeongi.sh status${NC}       # 상태 확인"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  HELP
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
  cat <<EOF

${PURPLE}${BOLD}  Yeongi 프로젝트 관리 스크립트${NC}
  마음도 지워질 자유가 있다.

${BOLD}  사용법:${NC}
    $(basename "$0") <command> [target]

${BOLD}  Commands:${NC}

    ${CYAN}start${NC}   [target]   서비스 시작
    ${CYAN}stop${NC}    [target]   서비스 중지
    ${CYAN}restart${NC} [target]   서비스 재기동
    ${CYAN}status${NC}             전체 상태 대시보드
    ${CYAN}logs${NC}    <target>   로그 실시간 스트림
    ${CYAN}build${NC}   [target]   빌드 실행
    ${CYAN}setup${NC}              초기 환경 구성 (venv + pub get + .env)

${BOLD}  Targets:${NC}

    ${GREEN}all${NC}      전체 (순서 보장: redis → api → app)
    ${GREEN}redis${NC}    Redis DB     (docker-compose)
    ${GREEN}api${NC}      FastAPI 백엔드  (venv + uvicorn)
    ${GREEN}app${NC}      Flutter 앱   (tmux or background)

${BOLD}  예시:${NC}

    $(basename "$0") setup              # 최초 환경 구성
    $(basename "$0") start all         # 전체 서비스 시작
    $(basename "$0") status            # 상태 확인
    $(basename "$0") stop api          # API만 중지
    $(basename "$0") restart redis     # Redis 재기동
    $(basename "$0") logs api          # API 로그 실시간 확인
    $(basename "$0") build app         # Flutter 배포 빌드 (타겟 선택)
    $(basename "$0") build api         # Python 의존성 재설치

${BOLD}  환경 정보:${NC}

    venv     : $VENV_DIR
    로그      : $LOGS_DIR/
    PID      : $PIDS_DIR/

  ${DIM}⚑  venv는 시스템 환경변수에 등록되지 않습니다 (격리 실행)${NC}

EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
#  메인 라우터
# ═══════════════════════════════════════════════════════════════════════════════

CMD="${1:-help}"
TARGET="${2:-all}"

case "$CMD" in

  # ── start ─────────────────────────────────────────────────────────────────
  start)
    case "$TARGET" in
      all)
        redis_start
        sleep 1
        api_start
        sleep 1
        app_start
        ;;
      redis) redis_start ;;
      api)   api_start ;;
      app)   app_start "$@" ;;
      *)     log_error "알 수 없는 타겟: $TARGET"; show_help; exit 1 ;;
    esac
    ;;

  # ── stop ──────────────────────────────────────────────────────────────────
  stop)
    case "$TARGET" in
      all)
        app_stop
        api_stop
        redis_stop
        ;;
      redis) redis_stop ;;
      api)   api_stop ;;
      app)   app_stop ;;
      *)     log_error "알 수 없는 타겟: $TARGET"; show_help; exit 1 ;;
    esac
    ;;

  # ── restart ───────────────────────────────────────────────────────────────
  restart)
    case "$TARGET" in
      all)
        app_stop; api_stop; redis_stop
        sleep 1
        redis_start
        sleep 1
        api_start
        sleep 1
        log_info "Flutter 재기동:"
        log_info "  ./yeongi.sh start app"
        ;;
      redis) redis_restart ;;
      api)   api_restart ;;
      app)   app_restart "$@" ;;
      *)     log_error "알 수 없는 타겟: $TARGET"; show_help; exit 1 ;;
    esac
    ;;

  # ── status ────────────────────────────────────────────────────────────────
  status) show_status ;;

  # ── logs ──────────────────────────────────────────────────────────────────
  logs)
    case "$TARGET" in
      redis) redis_logs ;;
      api)   api_logs ;;
      app)   app_logs ;;
      all)
        log_info "전체 로그: tail -f $LOGS_DIR/*.log"
        tail -f "$LOGS_DIR"/*.log 2>/dev/null \
          || log_warn "로그 파일이 없습니다. 서비스를 먼저 시작하세요"
        ;;
      *)
        log_error "logs 타겟: redis | api | app | all"
        exit 1
        ;;
    esac
    ;;

  # ── build ─────────────────────────────────────────────────────────────────
  build)
    case "$TARGET" in
      all)
        api_build
        app_pub
        ;;
      api)   api_build ;;
      app)   app_build ;;
      *)     log_error "알 수 없는 타겟: $TARGET"; show_help; exit 1 ;;
    esac
    ;;

  # ── setup ─────────────────────────────────────────────────────────────────
  setup) setup_all ;;

  # ── help ──────────────────────────────────────────────────────────────────
  help|--help|-h|"") show_help ;;

  *) log_error "알 수 없는 명령: $CMD"; show_help; exit 1 ;;
esac
