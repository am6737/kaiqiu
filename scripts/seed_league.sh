#!/bin/bash
set -eo pipefail

# ═════════════════════════════════════════════════════════════
# seed_league.sh — 通过 Supabase API 创建测试用户并完成 2026南宁业余联赛 全流程
#
# 用法: bash scripts/seed_league.sh
# 前提: jq 已安装, 网络可达 Supabase
# ═════════════════════════════════════════════════════════════

SUPABASE_URL="https://ejtkfaezztkwhmjqnvnb.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqdGtmYWV6enRrd2htanFudm5iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2Nzc2OTgsImV4cCI6MjA5MjI1MzY5OH0.xleOCLO9cp1KBxH3-bfozphZdNYSGTlX5EGrd9Z_Ao0"
PASSWORD="kaiqiu"

declare -A USER_IDS
declare -A USER_TOKENS

# ─── 工具函数 ──────────────────────────────────────────────

log()  { echo -e "\033[1;32m✓\033[0m $*"; }
info() { echo -e "\033[1;34m➜\033[0m $*"; }
warn() { echo -e "\033[1;33m⚠\033[0m $*"; }
fail() { echo -e "\033[1;31m✗\033[0m $*" >&2; exit 1; }

auth_header() { echo "Authorization: Bearer $1"; }

api_get() {
  local path="$1"; shift
  curl -sf "$SUPABASE_URL/rest/v1/$path" -H "apikey: $ANON_KEY" "$@"
}

api_post() {
  local path="$1" data="$2"; shift 2
  curl -sf -X POST "$SUPABASE_URL/rest/v1/$path" \
    -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    "$@" -d "$data"
}

api_patch() {
  local path="$1" data="$2"; shift 2
  curl -sf -X PATCH "$SUPABASE_URL/rest/v1/$path" \
    -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    "$@" -d "$data"
}

# 登录或注册用户，带重试，将 uid 和 token 存入全局数组
ensure_user() {
  local email="$1" name="$2"
  local resp uid token attempt

  for attempt in 1 2 3; do
    resp=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
      -H "apikey: $ANON_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"email\": \"$email\", \"password\": \"$PASSWORD\"}") || true
    token=$(echo "$resp" | jq -r '.access_token // empty')
    uid=$(echo "$resp" | jq -r '.user.id // empty')

    if [ -n "$token" ] && [ -n "$uid" ]; then
      USER_IDS["$email"]="$uid"
      USER_TOKENS["$email"]="$token"
      return 0
    fi

    # 登录失败，尝试注册
    resp=$(curl -s -X POST "$SUPABASE_URL/auth/v1/signup" \
      -H "apikey: $ANON_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"email\": \"$email\", \"password\": \"$PASSWORD\", \"data\": {\"name\": \"$name\"}}") || true
    uid=$(echo "$resp" | jq -r '.user.id // empty')
    token=$(echo "$resp" | jq -r '.access_token // empty')

    if [ -n "$uid" ] && [ -n "$token" ]; then
      USER_IDS["$email"]="$uid"
      USER_TOKENS["$email"]="$token"
      return 0
    fi

    # 都失败了，等一下重试
    sleep 1
  done

  warn "用户获取失败 (3次重试): $email"
  return 1
}

update_profile() {
  local token="$1" uid="$2" city="$3" position="$4" height="$5" foot="$6"
  api_patch "profiles?id=eq.$uid" \
    "{\"city\":\"$city\",\"position\":\"$position\",\"height\":$height,\"foot\":\"$foot\"}" \
    -H "$(auth_header "$token")" > /dev/null
}

pos_to_role() {
  case "$1" in
    ST|LW|RW) echo "forward" ;;
    CM)       echo "midfielder" ;;
    CB|LB|RB) echo "defender" ;;
    GK)       echo "goalkeeper" ;;
    *)        echo "midfielder" ;;
  esac
}

add_member() {
  local cap_token="$1" team_id="$2" user_id="$3" jersey="$4" position="$5" role="$6"
  local team_pos
  team_pos=$(pos_to_role "$position")
  api_post "team_members" \
    "{\"team_id\":\"$team_id\",\"user_id\":\"$user_id\",\"jersey_number\":$jersey,\"position\":\"$team_pos\",\"role\":\"$role\"}" \
    -H "$(auth_header "$cap_token")" > /dev/null
}

# ═══════════════════════════════════════════════════════════
# Phase 0: 获取赛事信息，清理旧数据
# ═══════════════════════════════════════════════════════════

info "Phase 0: 初始化..."

ensure_user "demo-chenzirui@qiuju.local" "陈子睿"
CREATOR_TOKEN="${USER_TOKENS[demo-chenzirui@qiuju.local]}"

EVENT_ID=$(api_get "events?name=eq.2026%E5%8D%97%E5%AE%81%E4%B8%9A%E4%BD%99%E8%81%94%E8%B5%9B&select=id" \
  -H "$(auth_header "$CREATOR_TOKEN")" | jq -r '.[0].id')
[ -z "$EVENT_ID" ] || [ "$EVENT_ID" = "null" ] && fail "找不到赛事: 2026南宁业余联赛"
log "赛事 ID: $EVENT_ID"

# 删除赛事下已有的 matches 和 goals
curl -s -X DELETE "$SUPABASE_URL/rest/v1/matches?event_id=eq.$EVENT_ID" \
  -H "apikey: $ANON_KEY" \
  -H "$(auth_header "$CREATOR_TOKEN")" > /dev/null 2>&1 || true

# 重置赛事状态
api_patch "events?id=eq.$EVENT_ID" '{"status":"registering"}' \
  -H "$(auth_header "$CREATOR_TOKEN")" > /dev/null
log "赛事状态重置为 registering"

# ═══════════════════════════════════════════════════════════
# Phase 1: 注册40个新用户
# ═══════════════════════════════════════════════════════════

info "Phase 1: 注册新用户..."

# email|name|position|height|foot
NEW_USERS=(
  # ── 凤凰FC ──
  "demo-weiqiang@qiuju.local|韦强|CM|178|right"
  "demo-suming@qiuju.local|苏明|CB|182|right"
  "demo-liaojie@qiuju.local|廖杰|CB|180|right"
  "demo-lufei@qiuju.local|陆飞|LB|175|left"
  "demo-lantian@qiuju.local|蓝天|RB|176|right"
  "demo-nongwei@qiuju.local|农伟|CM|177|right"
  "demo-luohao@qiuju.local|罗浩|CM|174|right"
  "demo-liuyang@qiuju.local|刘洋|LW|172|left"
  "demo-tanfeng@qiuju.local|谭峰|ST|180|right"
  "demo-mochao@qiuju.local|莫超|RW|173|right"
  # ── 邕江联队 ──
  "demo-huangzhiyuan@qiuju.local|黄志远|CM|176|right"
  "demo-heyong@qiuju.local|何勇|GK|185|right"
  "demo-zhoulei@qiuju.local|周磊|CB|183|right"
  "demo-wuhao@qiuju.local|吴昊|CB|181|left"
  "demo-zhangxin@qiuju.local|张鑫|RB|177|right"
  "demo-liqiang@qiuju.local|李强|CM|175|right"
  "demo-yangfan@qiuju.local|杨帆|LW|170|left"
  "demo-wangjun@qiuju.local|王军|RW|174|right"
  "demo-weipeng@qiuju.local|韦鹏|ST|179|right"
  "demo-huanghao@qiuju.local|黄浩|ST|181|right"
  # ── 青秀猎豹 ──
  "demo-lianghao@qiuju.local|梁浩|ST|183|right"
  "demo-weitao@qiuju.local|韦涛|GK|187|right"
  "demo-qinliang@qiuju.local|覃亮|CB|184|right"
  "demo-lucheng@qiuju.local|陆成|CB|180|right"
  "demo-mengjie@qiuju.local|蒙杰|LB|175|left"
  "demo-panyi@qiuju.local|潘毅|RB|176|right"
  "demo-tangwei@qiuju.local|唐伟|CM|178|right"
  "demo-ganxiong@qiuju.local|甘雄|CM|177|both"
  "demo-shilei@qiuju.local|石磊|LW|171|left"
  "demo-lubin@qiuju.local|卢斌|RW|173|right"
  # ── 良庆飞虎 ──
  "demo-qindawei@qiuju.local|覃大伟|CB|186|right"
  "demo-weijie@qiuju.local|韦杰|GK|188|right"
  "demo-huangfeng@qiuju.local|黄锋|CB|182|right"
  "demo-liangjian@qiuju.local|梁坚|LB|176|left"
  "demo-fengda@qiuju.local|冯达|RB|178|right"
  "demo-dengbo@qiuju.local|邓波|CM|175|right"
  "demo-qinlang@qiuju.local|秦朗|CM|177|right"
  "demo-chenhui@qiuju.local|陈辉|LW|172|left"
  "demo-leiyang@qiuju.local|雷阳|RW|174|right"
  "demo-fangzhi@qiuju.local|方志|ST|180|right"
)

CREATED=0
FAILED=0

for entry in "${NEW_USERS[@]}"; do
  IFS='|' read -r email name position height foot <<< "$entry"

  if ensure_user "$email" "$name"; then
    token="${USER_TOKENS[$email]}"
    uid="${USER_IDS[$email]}"
    # 确保 profile 有 city/position（幂等 PATCH）
    update_profile "$token" "$uid" "南宁市" "$position" "$height" "$foot" 2>/dev/null || true
    CREATED=$((CREATED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
  sleep 0.2
done

log "成功 $CREATED 人, 失败 $FAILED 人"
[ "$FAILED" -gt 0 ] && fail "有 $FAILED 个用户创建失败，无法继续"

# 登录已有的南宁用户
info "登录已有南宁用户..."
for email in demo-laowang@qiuju.local demo-xuzheng@qiuju.local demo-linshuai@qiuju.local demo-jiangbei@qiuju.local; do
  ensure_user "$email" ""
done
log "已有用户登录完成"

# ═══════════════════════════════════════════════════════════
# Phase 2: 创建4支球队
# ═══════════════════════════════════════════════════════════

info "Phase 2: 创建球队..."

# 先清理可能已有的球队（由各队长删除）
for cap_email in demo-weiqiang@qiuju.local demo-huangzhiyuan@qiuju.local demo-lianghao@qiuju.local demo-qindawei@qiuju.local; do
  cap_token="${USER_TOKENS[$cap_email]:-}"
  cap_id="${USER_IDS[$cap_email]:-}"
  if [ -n "$cap_token" ] && [ -n "$cap_id" ]; then
    curl -s -X DELETE "$SUPABASE_URL/rest/v1/teams?event_id=eq.$EVENT_ID&captain_id=eq.$cap_id" \
      -H "apikey: $ANON_KEY" \
      -H "$(auth_header "$cap_token")" > /dev/null 2>&1 || true
  fi
done

declare -A TEAM_IDS

create_team() {
  local cap_email="$1" team_name="$2" slogan="$3"
  local cap_id="${USER_IDS[$cap_email]}"
  local cap_token="${USER_TOKENS[$cap_email]}"
  local resp tid
  resp=$(api_post "teams" \
    "{\"event_id\":\"$EVENT_ID\",\"name\":\"$team_name\",\"captain_id\":\"$cap_id\",\"status\":\"approved\",\"slogan\":\"$slogan\"}" \
    -H "$(auth_header "$cap_token")")
  tid=$(echo "$resp" | jq -r '.[0].id')
  TEAM_IDS["$team_name"]="$tid"
  log "$team_name ($tid)"
}

create_team "demo-weiqiang@qiuju.local"      "凤凰FC"   "浴火重生，永不言败"
create_team "demo-huangzhiyuan@qiuju.local"   "邕江联队" "江水长流，意志不屈"
create_team "demo-lianghao@qiuju.local"       "青秀猎豹" "速度与激情"
create_team "demo-qindawei@qiuju.local"       "良庆飞虎" "猛虎下山，势不可挡"

# ═══════════════════════════════════════════════════════════
# Phase 3: 添加队员（每队11人）
# ═══════════════════════════════════════════════════════════

info "Phase 3: 添加队员..."

# ── 凤凰FC ──
T1="${TEAM_IDS[凤凰FC]}"
C1="${USER_TOKENS[demo-weiqiang@qiuju.local]}"
add_member "$C1" "$T1" "${USER_IDS[demo-weiqiang@qiuju.local]}" 10 CM captain
add_member "$C1" "$T1" "${USER_IDS[demo-laowang@qiuju.local]}"   1 GK player
add_member "$C1" "$T1" "${USER_IDS[demo-suming@qiuju.local]}"    4 CB player
add_member "$C1" "$T1" "${USER_IDS[demo-liaojie@qiuju.local]}"   5 CB player
add_member "$C1" "$T1" "${USER_IDS[demo-lufei@qiuju.local]}"     3 LB player
add_member "$C1" "$T1" "${USER_IDS[demo-lantian@qiuju.local]}"   2 RB player
add_member "$C1" "$T1" "${USER_IDS[demo-nongwei@qiuju.local]}"   8 CM player
add_member "$C1" "$T1" "${USER_IDS[demo-luohao@qiuju.local]}"    6 CM player
add_member "$C1" "$T1" "${USER_IDS[demo-liuyang@qiuju.local]}"  11 LW player
add_member "$C1" "$T1" "${USER_IDS[demo-tanfeng@qiuju.local]}"   9 ST player
add_member "$C1" "$T1" "${USER_IDS[demo-mochao@qiuju.local]}"    7 RW player
log "凤凰FC: 11人"

# ── 邕江联队 ──
T2="${TEAM_IDS[邕江联队]}"
C2="${USER_TOKENS[demo-huangzhiyuan@qiuju.local]}"
add_member "$C2" "$T2" "${USER_IDS[demo-huangzhiyuan@qiuju.local]}" 10 CM captain
add_member "$C2" "$T2" "${USER_IDS[demo-xuzheng@qiuju.local]}"       3 CB player
add_member "$C2" "$T2" "${USER_IDS[demo-heyong@qiuju.local]}"        1 GK player
add_member "$C2" "$T2" "${USER_IDS[demo-zhoulei@qiuju.local]}"       4 CB player
add_member "$C2" "$T2" "${USER_IDS[demo-wuhao@qiuju.local]}"         5 CB player
add_member "$C2" "$T2" "${USER_IDS[demo-zhangxin@qiuju.local]}"      2 RB player
add_member "$C2" "$T2" "${USER_IDS[demo-liqiang@qiuju.local]}"       8 CM player
add_member "$C2" "$T2" "${USER_IDS[demo-yangfan@qiuju.local]}"      11 LW player
add_member "$C2" "$T2" "${USER_IDS[demo-wangjun@qiuju.local]}"       7 RW player
add_member "$C2" "$T2" "${USER_IDS[demo-weipeng@qiuju.local]}"       9 ST player
add_member "$C2" "$T2" "${USER_IDS[demo-huanghao@qiuju.local]}"     18 ST player
log "邕江联队: 11人"

# ── 青秀猎豹 ──
T3="${TEAM_IDS[青秀猎豹]}"
C3="${USER_TOKENS[demo-lianghao@qiuju.local]}"
add_member "$C3" "$T3" "${USER_IDS[demo-lianghao@qiuju.local]}"  9 ST captain
add_member "$C3" "$T3" "${USER_IDS[demo-linshuai@qiuju.local]}" 10 CM player
add_member "$C3" "$T3" "${USER_IDS[demo-weitao@qiuju.local]}"    1 GK player
add_member "$C3" "$T3" "${USER_IDS[demo-qinliang@qiuju.local]}"  4 CB player
add_member "$C3" "$T3" "${USER_IDS[demo-lucheng@qiuju.local]}"   5 CB player
add_member "$C3" "$T3" "${USER_IDS[demo-mengjie@qiuju.local]}"   3 LB player
add_member "$C3" "$T3" "${USER_IDS[demo-panyi@qiuju.local]}"     2 RB player
add_member "$C3" "$T3" "${USER_IDS[demo-tangwei@qiuju.local]}"   8 CM player
add_member "$C3" "$T3" "${USER_IDS[demo-ganxiong@qiuju.local]}"  6 CM player
add_member "$C3" "$T3" "${USER_IDS[demo-shilei@qiuju.local]}"   11 LW player
add_member "$C3" "$T3" "${USER_IDS[demo-lubin@qiuju.local]}"     7 RW player
log "青秀猎豹: 11人"

# ── 良庆飞虎 ──
T4="${TEAM_IDS[良庆飞虎]}"
C4="${USER_TOKENS[demo-qindawei@qiuju.local]}"
add_member "$C4" "$T4" "${USER_IDS[demo-qindawei@qiuju.local]}"  4 CB captain
add_member "$C4" "$T4" "${USER_IDS[demo-jiangbei@qiuju.local]}" 11 LW player
add_member "$C4" "$T4" "${USER_IDS[demo-weijie@qiuju.local]}"    1 GK player
add_member "$C4" "$T4" "${USER_IDS[demo-huangfeng@qiuju.local]}"  5 CB player
add_member "$C4" "$T4" "${USER_IDS[demo-liangjian@qiuju.local]}"  3 LB player
add_member "$C4" "$T4" "${USER_IDS[demo-fengda@qiuju.local]}"     2 RB player
add_member "$C4" "$T4" "${USER_IDS[demo-dengbo@qiuju.local]}"     8 CM player
add_member "$C4" "$T4" "${USER_IDS[demo-qinlang@qiuju.local]}"    6 CM player
add_member "$C4" "$T4" "${USER_IDS[demo-chenhui@qiuju.local]}"   17 LW player
add_member "$C4" "$T4" "${USER_IDS[demo-leiyang@qiuju.local]}"    7 RW player
add_member "$C4" "$T4" "${USER_IDS[demo-fangzhi@qiuju.local]}"    9 ST player
log "良庆飞虎: 11人"

# ═══════════════════════════════════════════════════════════
# Phase 4: 赛事推进 → ongoing + 创建赛程
# ═══════════════════════════════════════════════════════════

info "Phase 4: 推进赛事状态，创建赛程..."

# 刷新 creator token
ensure_user "demo-chenzirui@qiuju.local" "陈子睿"
CREATOR_TOKEN="${USER_TOKENS[demo-chenzirui@qiuju.local]}"

api_patch "events?id=eq.$EVENT_ID" '{"status":"ongoing"}' \
  -H "$(auth_header "$CREATOR_TOKEN")" > /dev/null
log "赛事状态 → ongoing"

# 4队循环赛 = 6场
# 第1轮: 凤凰FC vs 邕江联队, 青秀猎豹 vs 良庆飞虎
# 第2轮: 凤凰FC vs 青秀猎豹, 邕江联队 vs 良庆飞虎
# 第3轮: 凤凰FC vs 良庆飞虎, 邕江联队 vs 青秀猎豹

D1=$(date -u -d "14 days ago" +%Y-%m-%dT15:00:00Z)
D2=$(date -u -d "7 days ago" +%Y-%m-%dT15:00:00Z)
D3=$(date -u -d "yesterday" +%Y-%m-%dT15:00:00Z)

create_match() {
  local ta="$1" tb="$2" la="$3" lb="$4" round="$5" when="$6"
  local resp
  resp=$(api_post "matches" \
    "{\"event_id\":\"$EVENT_ID\",\"team_a_id\":\"$ta\",\"team_b_id\":\"$tb\",\"team_a_label\":\"$la\",\"team_b_label\":\"$lb\",\"round\":\"$round\",\"played_at\":\"$when\",\"status\":\"upcoming\"}" \
    -H "$(auth_header "$CREATOR_TOKEN")")
  echo "$resp" | jq -r '.[0].id'
}

M1=$(create_match "$T1" "$T2" "凤凰FC" "邕江联队" "league" "$D1"); log "第1轮: 凤凰FC vs 邕江联队"
M2=$(create_match "$T3" "$T4" "青秀猎豹" "良庆飞虎" "league" "$D1"); log "第1轮: 青秀猎豹 vs 良庆飞虎"
M3=$(create_match "$T1" "$T3" "凤凰FC" "青秀猎豹" "league" "$D2"); log "第2轮: 凤凰FC vs 青秀猎豹"
M4=$(create_match "$T2" "$T4" "邕江联队" "良庆飞虎" "league" "$D2"); log "第2轮: 邕江联队 vs 良庆飞虎"
M5=$(create_match "$T1" "$T4" "凤凰FC" "良庆飞虎" "league" "$D3"); log "第3轮: 凤凰FC vs 良庆飞虎"
M6=$(create_match "$T2" "$T3" "邕江联队" "青秀猎豹" "league" "$D3"); log "第3轮: 邕江联队 vs 青秀猎豹"

# ═══════════════════════════════════════════════════════════
# Phase 5: 模拟比赛（设为已完成）
# ═══════════════════════════════════════════════════════════

info "Phase 5: 模拟比赛结果..."

finish_match() {
  local mid="$1" sa="$2" sb="$3" start="$4" end="$5"
  api_patch "matches?id=eq.$mid" \
    "{\"status\":\"finished\",\"done\":true,\"score_a\":$sa,\"score_b\":$sb,\"started_at\":\"$start\",\"ended_at\":\"$end\"}" \
    -H "$(auth_header "$CREATOR_TOKEN")" > /dev/null
}

D1E=$(date -u -d "14 days ago + 2 hours" +%Y-%m-%dT%H:%M:%SZ)
D2E=$(date -u -d "7 days ago + 2 hours" +%Y-%m-%dT%H:%M:%SZ)
D3E=$(date -u -d "yesterday + 2 hours" +%Y-%m-%dT%H:%M:%SZ)

# 比分:
# M1: 凤凰FC 2-1 邕江联队
# M2: 青秀猎豹 1-0 良庆飞虎
# M3: 凤凰FC 1-2 青秀猎豹
# M4: 邕江联队 3-1 良庆飞虎
# M5: 凤凰FC 2-0 良庆飞虎
# M6: 邕江联队 1-1 青秀猎豹

finish_match "$M1" 2 1 "$D1" "$D1E"; log "凤凰FC 2-1 邕江联队"
finish_match "$M2" 1 0 "$D1" "$D1E"; log "青秀猎豹 1-0 良庆飞虎"
finish_match "$M3" 1 2 "$D2" "$D2E"; log "凤凰FC 1-2 青秀猎豹"
finish_match "$M4" 3 1 "$D2" "$D2E"; log "邕江联队 3-1 良庆飞虎"
finish_match "$M5" 2 0 "$D3" "$D3E"; log "凤凰FC 2-0 良庆飞虎"
finish_match "$M6" 1 1 "$D3" "$D3E"; log "邕江联队 1-1 青秀猎豹"

# ═══════════════════════════════════════════════════════════
# Phase 6: 进球数据
# ═══════════════════════════════════════════════════════════

info "Phase 6: 录入进球..."

goal() {
  local mid="$1" scorer_email="$2" scorer_name="$3" minute="$4" assist_email="${5:-}"
  local sid="${USER_IDS[$scorer_email]}"
  local payload="{\"match_id\":\"$mid\",\"scorer_id\":\"$sid\",\"scorer_name\":\"$scorer_name\",\"minute\":$minute,\"is_own_goal\":false,\"is_penalty\":false"
  if [ -n "$assist_email" ]; then
    payload="$payload,\"assist_id\":\"${USER_IDS[$assist_email]}\""
  fi
  payload="$payload}"
  api_post "goals" "$payload" -H "$(auth_header "$CREATOR_TOKEN")" > /dev/null
}

# M1: 凤凰FC 2-1 邕江联队
goal "$M1" demo-tanfeng@qiuju.local  "谭峰" 23 demo-liuyang@qiuju.local
goal "$M1" demo-weipeng@qiuju.local  "韦鹏" 41
goal "$M1" demo-mochao@qiuju.local   "莫超" 67 demo-weiqiang@qiuju.local

# M2: 青秀猎豹 1-0 良庆飞虎
goal "$M2" demo-lianghao@qiuju.local "梁浩" 55 demo-shilei@qiuju.local

# M3: 凤凰FC 1-2 青秀猎豹
goal "$M3" demo-nongwei@qiuju.local  "农伟" 12
goal "$M3" demo-lianghao@qiuju.local "梁浩" 38 demo-lubin@qiuju.local
goal "$M3" demo-shilei@qiuju.local   "石磊" 72 demo-lianghao@qiuju.local

# M4: 邕江联队 3-1 良庆飞虎
goal "$M4" demo-weipeng@qiuju.local  "韦鹏" 8  demo-yangfan@qiuju.local
goal "$M4" demo-huanghao@qiuju.local "黄浩" 34 demo-huangzhiyuan@qiuju.local
goal "$M4" demo-fangzhi@qiuju.local  "方志" 51
goal "$M4" demo-weipeng@qiuju.local  "韦鹏" 78 demo-wangjun@qiuju.local

# M5: 凤凰FC 2-0 良庆飞虎
goal "$M5" demo-tanfeng@qiuju.local  "谭峰" 15 demo-mochao@qiuju.local
goal "$M5" demo-liuyang@qiuju.local  "刘洋" 63

# M6: 邕江联队 1-1 青秀猎豹
goal "$M6" demo-liqiang@qiuju.local  "李强" 29
goal "$M6" demo-tangwei@qiuju.local  "唐伟" 56 demo-lianghao@qiuju.local

log "录入 14 个进球"

# ═══════════════════════════════════════════════════════════
# Phase 7: 球员评分
# ═══════════════════════════════════════════════════════════

info "Phase 7: 球员评分..."

rate() {
  local mid="$1" rater_email="$2" ratee_email="$3" score="$4" hl="$5" comment="$6"
  local rater_token="${USER_TOKENS[$rater_email]}"
  local payload="{\"match_id\":\"$mid\",\"rater_id\":\"${USER_IDS[$rater_email]}\",\"ratee_id\":\"${USER_IDS[$ratee_email]}\",\"score\":$score,\"highlight\":\"$hl\",\"comment\":\"$comment\"}"
  api_post "ratings" "$payload" -H "$(auth_header "$rater_token")" > /dev/null
}

# M1 评分
rate "$M1" demo-weiqiang@qiuju.local demo-tanfeng@qiuju.local 8.5 "1球" "前锋跑位积极，抢点意识强"
rate "$M1" demo-weiqiang@qiuju.local demo-mochao@qiuju.local  8.0 "1球" "右路突破犀利"
rate "$M1" demo-weiqiang@qiuju.local demo-laowang@qiuju.local 7.5 ""    "门将发挥稳定"

# M3 评分
rate "$M3" demo-lianghao@qiuju.local demo-shilei@qiuju.local  9.0 "1球"   "绝杀！左路之王"
rate "$M3" demo-lianghao@qiuju.local demo-weitao@qiuju.local  8.0 ""      "多次关键扑救"
rate "$M3" demo-lianghao@qiuju.local demo-tangwei@qiuju.local 7.5 ""      "中场调度出色"

# M4 评分
rate "$M4" demo-huangzhiyuan@qiuju.local demo-weipeng@qiuju.local 9.5 "2球" "梅开二度，全场最佳"
rate "$M4" demo-huangzhiyuan@qiuju.local demo-huanghao@qiuju.local 8.0 "1球" "头球破门漂亮"

log "提交 8 条评分"

# ═══════════════════════════════════════════════════════════
# Phase 8: 完赛
# ═══════════════════════════════════════════════════════════

info "Phase 8: 联赛收官..."

api_patch "events?id=eq.$EVENT_ID" '{"status":"completed"}' \
  -H "$(auth_header "$CREATOR_TOKEN")" > /dev/null
log "赛事状态 → completed"

# ═══════════════════════════════════════════════════════════
# 汇总
# ═══════════════════════════════════════════════════════════

echo ""
echo "══════════════════════════════════════════════════"
echo "  2026南宁业余联赛 — 全流程模拟完成"
echo "══════════════════════════════════════════════════"
echo ""
echo "积分榜:"
echo "  1. 青秀猎豹   7分 (2胜1平0负 进4失2 净胜+2)"
echo "  2. 凤凰FC     6分 (2胜0平1负 进5失3 净胜+2)"
echo "  3. 邕江联队   4分 (1胜1平1负 进5失4 净胜+1)"
echo "  4. 良庆飞虎   0分 (0胜0平3负 进1失6 净胜-5)"
echo ""
echo "射手榜:"
echo "  韦鹏 (邕江联队) 3球 | 谭峰 (凤凰FC) 2球 | 梁浩 (青秀猎豹) 2球"
echo ""
echo "数据汇总:"
echo "  用户: $CREATED 人"
echo "  球队: 4支 x 11人"
echo "  比赛: 6场, 14球, 8条评分"
echo ""

# 输出新用户列表
echo "── 新增用户 ──"
printf "%-8s %-35s %s\n" "名称" "邮箱" "UUID"
for entry in "${NEW_USERS[@]}"; do
  IFS='|' read -r email name _ _ _ <<< "$entry"
  printf "%-8s %-35s %s\n" "$name" "$email" "${USER_IDS[$email]:-?}"
done
