// mock.dart — 开球 原型 mock data，1:1 对应 /home/coder/workspaces/qiuju/src/data.js
//
// 用 Dart 原生结构存，屏幕层直接消费。不走 Supabase。

// ─────────────────────────────────────────────────────────────
// User / Profile
// ─────────────────────────────────────────────────────────────
class MockUser {
  final String name;
  final String handle;
  final String city;
  final String district;
  final String position; // CF
  final String positionFull; // 前锋
  final int rating; // 综合评分 0-99
  final int height;
  final String foot;
  final MockStats stats;
  final Map<String, int> attrs; // 速度/射门/传球/防守/体能/技术
  final List<MockHonor> honors;

  const MockUser({
    required this.name,
    required this.handle,
    required this.city,
    required this.district,
    required this.position,
    required this.positionFull,
    required this.rating,
    required this.height,
    required this.foot,
    required this.stats,
    required this.attrs,
    required this.honors,
  });
}

class MockStats {
  final int matches, goals, assists, mvp;
  const MockStats({
    required this.matches,
    required this.goals,
    required this.assists,
    required this.mvp,
  });
}

class MockHonor {
  final String year, title, meta;
  const MockHonor({
    required this.year,
    required this.title,
    required this.meta,
  });
}

// ─────────────────────────────────────────────────────────────
// Pickup / Event / Match
// ─────────────────────────────────────────────────────────────
class MockPickup {
  final int id;
  final String venue, time, dur, level, host, status; // open/almost/full
  final int need, total, fee;
  final double lat, lng; // 0..1 normalized on map canvas

  const MockPickup({
    required this.id,
    required this.venue,
    required this.time,
    required this.dur,
    required this.need,
    required this.total,
    required this.level,
    required this.fee,
    required this.host,
    required this.status,
    required this.lat,
    required this.lng,
  });
}

class MockEvent {
  final String id, name, sub, city, deadline, status, prize;
  final int teams, teamsMax;
  const MockEvent({
    required this.id,
    required this.name,
    required this.sub,
    required this.city,
    required this.teams,
    required this.teamsMax,
    required this.deadline,
    required this.status,
    required this.prize,
  });
}

// ─────────────────────────────────────────────────────────────
// Feed — 4 kinds: pickup / result / post / event
// ─────────────────────────────────────────────────────────────
sealed class FeedItem {
  String get kind;
  String get id;
  String get time;
}

class FeedPickup extends FeedItem {
  @override
  final String id;
  @override
  final String time;
  final String host, venue, when, level;
  final int need, total, fee;
  FeedPickup({
    required this.id,
    required this.time,
    required this.host,
    required this.venue,
    required this.when,
    required this.need,
    required this.total,
    required this.level,
    required this.fee,
  });
  @override
  String get kind => 'pickup';
}

class FeedResult extends FeedItem {
  @override
  final String id;
  @override
  final String time;
  final String teamA, teamB, event;
  final int scoreA, scoreB;
  final List<String> scorers;
  FeedResult({
    required this.id,
    required this.time,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.event,
    required this.scorers,
  });
  @override
  String get kind => 'result';
}

class FeedPost extends FeedItem {
  @override
  final String id;
  @override
  final String time;
  final String author, text;
  final List<String> tags;
  FeedPost({
    required this.id,
    required this.time,
    required this.author,
    required this.text,
    required this.tags,
  });
  @override
  String get kind => 'post';
}

class FeedEvent extends FeedItem {
  @override
  final String id;
  @override
  final String time;
  final String event, startIn;
  final int teamsRegistered, teamsMax;
  FeedEvent({
    required this.id,
    required this.time,
    required this.event,
    required this.teamsRegistered,
    required this.teamsMax,
    required this.startIn,
  });
  @override
  String get kind => 'event';
}

// ─────────────────────────────────────────────────────────────
// Live / World Cup
// ─────────────────────────────────────────────────────────────
class LiveMatch {
  final String id, teamA, teamB, minute, viewers;
  final int scoreA, scoreB;
  const LiveMatch({
    required this.id,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.minute,
    required this.viewers,
  });
}

class WcMatch {
  final String id, teamA, teamB, flagA, flagB, time;
  final bool live;
  final int? scoreA, scoreB;
  final String? minute, status;
  const WcMatch({
    required this.id,
    required this.teamA,
    required this.teamB,
    required this.flagA,
    required this.flagB,
    required this.time,
    required this.live,
    this.scoreA,
    this.scoreB,
    this.minute,
    this.status,
  });
}

// ─────────────────────────────────────────────────────────────
// Standings / Scorers / Bracket
// ─────────────────────────────────────────────────────────────
class Standing {
  final int rank, p, w, d, l, gf, ga, pts;
  final String team;
  const Standing({
    required this.rank,
    required this.team,
    required this.p,
    required this.w,
    required this.d,
    required this.l,
    required this.gf,
    required this.ga,
    required this.pts,
  });
}

class Scorer {
  final int rank, goals, matches;
  final String name, team;
  const Scorer({
    required this.rank,
    required this.name,
    required this.team,
    required this.goals,
    required this.matches,
  });
}

class BracketGame {
  final String a, b;
  final int? sa, sb;
  final bool done;
  final String? pk, time;
  const BracketGame({
    required this.a,
    required this.b,
    this.sa,
    this.sb,
    this.done = false,
    this.pk,
    this.time,
  });
}

class Bracket {
  final List<BracketGame> qf;
  final List<BracketGame> sf;
  final BracketGame finalGame;
  const Bracket({required this.qf, required this.sf, required this.finalGame});
}

// ─────────────────────────────────────────────────────────────
// Lineup
// ─────────────────────────────────────────────────────────────
class LineupSlot {
  final String pos;
  final String? name; // null → 空位
  final int x, y; // 0-100 grid
  const LineupSlot({
    required this.pos,
    this.name,
    required this.x,
    required this.y,
  });
}

class Lineup {
  final String formation;
  final List<LineupSlot> filled;
  const Lineup({required this.formation, required this.filled});
}

// ─────────────────────────────────────────────────────────────
// Teammate / History / Message
// ─────────────────────────────────────────────────────────────
class Teammate {
  final String name;
  final int matches;
  const Teammate({required this.name, required this.matches});
}

class HistoryMatch {
  final String date, event, opp, score;
  final int goals, assists;
  final bool mvp;
  const HistoryMatch({
    required this.date,
    required this.event,
    required this.opp,
    required this.score,
    required this.goals,
    required this.assists,
    this.mvp = false,
  });
}

class MessageThread {
  final String name, last, time;
  final int unread;
  const MessageThread({
    required this.name,
    required this.last,
    required this.time,
    this.unread = 0,
  });
}

// ─────────────────────────────────────────────────────────────
// 评分 (虎扑式)
// ─────────────────────────────────────────────────────────────
class RatingMatchInfo {
  final String event, teamA, teamB, date;
  final int scoreA, scoreB;
  const RatingMatchInfo({
    required this.event,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.date,
  });
}

class RatingPlayer {
  final String name, pos;
  final bool you;
  final bool hot;
  final double avgScore;
  final int votes;
  final String? highlight;
  final String? team;
  final RatingTopComment? topComment;
  const RatingPlayer({
    required this.name,
    required this.pos,
    this.you = false,
    this.hot = false,
    required this.avgScore,
    required this.votes,
    this.highlight,
    this.team,
    this.topComment,
  });
}

class RatingTopComment {
  final String user, text;
  final int likes;
  const RatingTopComment({
    required this.user,
    required this.text,
    required this.likes,
  });
}

class HotRated {
  final int rank;
  final String name, team, trend;
  final double avgScore;
  final int votes;
  final bool trendUp;
  const HotRated({
    required this.rank,
    required this.name,
    required this.team,
    required this.avgScore,
    required this.votes,
    required this.trend,
    required this.trendUp,
  });
}

class TopComment {
  final String user, text, time;
  final int score, likes;
  const TopComment({
    required this.user,
    required this.score,
    required this.text,
    required this.likes,
    required this.time,
  });
}

// ─────────────────────────────────────────────────────────────
// The data
// ─────────────────────────────────────────────────────────────
const user = MockUser(
  name: '陈子睿',
  handle: '@chenzirui',
  city: '深圳',
  district: '龙岗',
  position: 'CF',
  positionFull: '前锋',
  rating: 82,
  height: 178,
  foot: '右脚',
  stats: MockStats(matches: 47, goals: 38, assists: 21, mvp: 6),
  attrs: {'速度': 86, '射门': 84, '传球': 72, '防守': 58, '体能': 79, '技术': 81},
  honors: [
    MockHonor(year: '2026', title: '龙岗村超 · 金靴', meta: '14球'),
    MockHonor(year: '2025', title: '深企联赛 · 最佳球员', meta: '腾讯队'),
    MockHonor(year: '2025', title: '南山夜场联赛 · 亚军', meta: '淘汰赛'),
  ],
);

const pickups = [
  MockPickup(
    id: 1,
    venue: '龙岗体育中心 3号场',
    time: '今晚 19:30',
    dur: '2h',
    need: 3,
    total: 10,
    level: '中级',
    fee: 50,
    host: '老王',
    status: 'open',
    lat: 0.4,
    lng: 0.35,
  ),
  MockPickup(
    id: 2,
    venue: '大运公园足球场',
    time: '明天 07:00',
    dur: '1.5h',
    need: 1,
    total: 12,
    level: '高级',
    fee: 40,
    host: 'Kevin',
    status: 'almost',
    lat: 0.6,
    lng: 0.5,
  ),
  MockPickup(
    id: 3,
    venue: '平湖体育公园',
    time: '周六 15:00',
    dur: '2h',
    need: 5,
    total: 10,
    level: '初级',
    fee: 30,
    host: '张教练',
    status: 'open',
    lat: 0.3,
    lng: 0.65,
  ),
  MockPickup(
    id: 4,
    venue: '坂田足球场',
    time: '周日 20:00',
    dur: '2h',
    need: 0,
    total: 10,
    level: '中级',
    fee: 45,
    host: '阿泽',
    status: 'full',
    lat: 0.7,
    lng: 0.3,
  ),
  MockPickup(
    id: 5,
    venue: '华南城五人制',
    time: '后天 21:00',
    dur: '1h',
    need: 2,
    total: 5,
    level: '中级',
    fee: 60,
    host: '林帅',
    status: 'open',
    lat: 0.5,
    lng: 0.2,
  ),
  MockPickup(
    id: 6,
    venue: '大鹏海滨球场',
    time: '下周六 09:00',
    dur: '2h',
    need: 4,
    total: 10,
    level: '初级',
    fee: 35,
    host: '小赵',
    status: 'open',
    lat: 0.82,
    lng: 0.55,
  ),
];

const events = [
  MockEvent(
    id: 'e1',
    name: '2026 龙岗村超',
    sub: '第三届社区联赛',
    city: '深圳 · 龙岗区',
    teams: 14,
    teamsMax: 16,
    deadline: '4月26日 截止',
    status: 'registering',
    prize: '5万',
  ),
  MockEvent(
    id: 'e2',
    name: '深企杯 · 春季',
    sub: '企业员工八人制',
    city: '深圳 · 南山区',
    teams: 24,
    teamsMax: 24,
    deadline: '进行中',
    status: 'ongoing',
    prize: '3万',
  ),
  MockEvent(
    id: 'e3',
    name: '大运夜联赛',
    sub: '7v7 业余联赛',
    city: '深圳 · 龙岗',
    teams: 8,
    teamsMax: 12,
    deadline: '5月03日 截止',
    status: 'registering',
    prize: '2万',
  ),
  MockEvent(
    id: 'e4',
    name: '华南区校友杯',
    sub: '高校校友足球赛',
    city: '广州 · 天河',
    teams: 12,
    teamsMax: 16,
    deadline: '进行中',
    status: 'ongoing',
    prize: '1.5万',
  ),
];

final feeds = <FeedItem>[
  FeedPickup(
    id: 'f1',
    time: '10分钟前',
    host: '老王',
    venue: '龙岗体育中心 3号场',
    when: '今晚 19:30',
    need: 3,
    total: 10,
    level: '中级',
    fee: 50,
  ),
  FeedResult(
    id: 'f2',
    time: '2小时前',
    teamA: '龙岗狼队',
    teamB: 'FC 黑马',
    scoreA: 3,
    scoreB: 2,
    event: '龙岗村超 · 小组赛 B组',
    scorers: ['陈子睿 2', '林帅 1'],
  ),
  FeedPost(
    id: 'f3',
    time: '3小时前',
    author: 'Kevin',
    text: '今天凌晨的野球，和一群陌生人踢出了最默契的配合。右边后卫那哥们传球精准得像 PS5 手柄按 L1 三角。',
    tags: ['野球日记', '龙岗'],
  ),
  FeedEvent(
    id: 'f4',
    time: '4小时前',
    event: '2026 龙岗村超',
    teamsRegistered: 14,
    teamsMax: 16,
    startIn: '6天后开赛',
  ),
  FeedResult(
    id: 'f5',
    time: '昨天',
    teamA: '南山电竞',
    teamB: '华为鹏城',
    scoreA: 1,
    scoreB: 1,
    event: '深企杯 · 小组赛 A组',
    scorers: ['江北 1', '徐铮 1'],
  ),
];

const liveNow = [
  LiveMatch(
    id: 'l1',
    teamA: '阿根廷',
    teamB: '巴西',
    scoreA: 2,
    scoreB: 1,
    minute: "67'",
    viewers: '128K',
  ),
  LiveMatch(
    id: 'l2',
    teamA: '龙岗狼队',
    teamB: 'FC 黑马',
    scoreA: 0,
    scoreB: 0,
    minute: "12'",
    viewers: '842',
  ),
  LiveMatch(
    id: 'l3',
    teamA: '皇家马德里',
    teamB: '巴塞罗那',
    scoreA: 1,
    scoreB: 3,
    minute: '半场',
    viewers: '94K',
  ),
];

const wcMatches = [
  WcMatch(
    id: 'w1',
    teamA: '阿根廷',
    teamB: '巴西',
    flagA: 'AR',
    flagB: 'BR',
    time: '03:00',
    live: true,
    scoreA: 2,
    scoreB: 1,
    minute: "67'",
  ),
  WcMatch(
    id: 'w2',
    teamA: '法国',
    teamB: '英格兰',
    flagA: 'FR',
    flagB: 'EN',
    time: '21:00',
    live: false,
    status: '今晚',
  ),
  WcMatch(
    id: 'w3',
    teamA: '德国',
    teamB: '西班牙',
    flagA: 'DE',
    flagB: 'ES',
    time: '明 00:30',
    live: false,
    status: '明日',
  ),
  WcMatch(
    id: 'w4',
    teamA: '荷兰',
    teamB: '葡萄牙',
    flagA: 'NL',
    flagB: 'PT',
    time: '明 03:00',
    live: false,
    status: '明日',
  ),
];

const standings = [
  Standing(
    rank: 1,
    team: '龙岗狼队',
    p: 5,
    w: 4,
    d: 1,
    l: 0,
    gf: 14,
    ga: 3,
    pts: 13,
  ),
  Standing(
    rank: 2,
    team: 'FC 黑马',
    p: 5,
    w: 3,
    d: 1,
    l: 1,
    gf: 11,
    ga: 6,
    pts: 10,
  ),
  Standing(rank: 3, team: '平湖闪电', p: 5, w: 3, d: 0, l: 2, gf: 9, ga: 7, pts: 9),
  Standing(rank: 4, team: '坂田联', p: 5, w: 2, d: 1, l: 2, gf: 7, ga: 8, pts: 7),
  Standing(
    rank: 5,
    team: '大鹏渔民',
    p: 5,
    w: 1,
    d: 1,
    l: 3,
    gf: 4,
    ga: 10,
    pts: 4,
  ),
  Standing(
    rank: 6,
    team: '华南城 FC',
    p: 5,
    w: 0,
    d: 2,
    l: 3,
    gf: 3,
    ga: 14,
    pts: 2,
  ),
];

const scorers = [
  Scorer(rank: 1, name: '陈子睿', team: '龙岗狼队', goals: 8, matches: 5),
  Scorer(rank: 2, name: '林帅', team: 'FC 黑马', goals: 6, matches: 5),
  Scorer(rank: 3, name: 'Kevin', team: '平湖闪电', goals: 5, matches: 5),
  Scorer(rank: 4, name: '阿泽', team: '坂田联', goals: 4, matches: 5),
  Scorer(rank: 5, name: '江北', team: '龙岗狼队', goals: 3, matches: 5),
];

const bracket = Bracket(
  qf: [
    BracketGame(a: '龙岗狼队', b: 'FC 黑马', sa: 3, sb: 1, done: true),
    BracketGame(a: '平湖闪电', b: '坂田联', sa: 2, sb: 2, done: true, pk: '4-3'),
    BracketGame(a: '大鹏渔民', b: '华南城 FC', time: '5月8日 19:30'),
    BracketGame(a: '南山电竞', b: '华为鹏城', time: '5月8日 21:00'),
  ],
  sf: [
    BracketGame(a: '龙岗狼队', b: '平湖闪电', time: '5月15日'),
    BracketGame(a: 'TBD', b: 'TBD', time: '5月15日'),
  ],
  finalGame: BracketGame(a: 'TBD', b: 'TBD', time: '5月22日'),
);

const lineup = Lineup(
  formation: '4-3-3',
  filled: [
    LineupSlot(pos: 'GK', name: '老王', x: 50, y: 92),
    LineupSlot(pos: 'LB', name: 'Kevin', x: 18, y: 72),
    LineupSlot(pos: 'CB', name: '阿泽', x: 38, y: 72),
    LineupSlot(pos: 'CB', x: 62, y: 72),
    LineupSlot(pos: 'RB', name: '江北', x: 82, y: 72),
    LineupSlot(pos: 'CM', name: '林帅', x: 30, y: 48),
    LineupSlot(pos: 'CM', x: 50, y: 48),
    LineupSlot(pos: 'CM', name: '小赵', x: 70, y: 48),
    LineupSlot(pos: 'LW', name: '徐铮', x: 20, y: 22),
    LineupSlot(pos: 'ST', x: 50, y: 14),
    LineupSlot(pos: 'RW', name: '陈子睿', x: 80, y: 22),
  ],
);

const teammates = [
  Teammate(name: '老王', matches: 28),
  Teammate(name: 'Kevin', matches: 21),
  Teammate(name: '林帅', matches: 19),
  Teammate(name: '阿泽', matches: 15),
  Teammate(name: '江北', matches: 12),
  Teammate(name: '小赵', matches: 9),
  Teammate(name: '徐铮', matches: 7),
  Teammate(name: '张教练', matches: 5),
];

const history = [
  HistoryMatch(
    date: '04.18',
    event: '龙岗村超 / 小组赛',
    opp: 'vs FC 黑马',
    score: '3-2 胜',
    goals: 2,
    assists: 1,
    mvp: true,
  ),
  HistoryMatch(
    date: '04.11',
    event: '周末野球',
    opp: 'vs 路人队',
    score: '5-3 胜',
    goals: 1,
    assists: 2,
  ),
  HistoryMatch(
    date: '04.04',
    event: '深企杯 / 小组赛',
    opp: 'vs 华为鹏城',
    score: '1-1 平',
    goals: 0,
    assists: 0,
  ),
  HistoryMatch(
    date: '03.28',
    event: '龙岗村超 / 小组赛',
    opp: 'vs 平湖闪电',
    score: '2-0 胜',
    goals: 1,
    assists: 0,
  ),
  HistoryMatch(
    date: '03.21',
    event: '夜场野球',
    opp: 'vs 联合队',
    score: '4-6 负',
    goals: 2,
    assists: 1,
  ),
];

const messageThreads = [
  MessageThread(
    name: '龙岗狼队群',
    last: '老王: 周六记得提前半小时到场热身',
    time: '14:02',
    unread: 3,
  ),
  MessageThread(name: 'Kevin', last: '兄弟今晚的球还缺人吗？', time: '13:40', unread: 1),
  MessageThread(name: '龙岗村超官方', last: '你报名的队伍已通过审核', time: '12:15', unread: 0),
  MessageThread(name: '林帅', last: '那个传中球你回看了没哈哈', time: '昨天', unread: 0),
];

// ─────────────────────────────────────────────────────────────
// Rating data
// ─────────────────────────────────────────────────────────────
const ratingMatchInfo = RatingMatchInfo(
  event: '龙岗村超 · 1/4 决赛',
  teamA: '龙岗狼队',
  teamB: 'FC 黑马',
  scoreA: 3,
  scoreB: 1,
  date: '2026.04.18',
);

const yourTeam = [
  RatingPlayer(
    name: '陈子睿',
    pos: 'CF',
    you: true,
    hot: true,
    avgScore: 8.7,
    votes: 142,
    highlight: '2球1助',
    topComment: RatingTopComment(
      user: 'Kevin',
      text: '那脚世界波抽射真的绝了，门将毫无反应',
      likes: 86,
    ),
  ),
  RatingPlayer(
    name: '老王',
    pos: 'GK',
    avgScore: 7.6,
    votes: 98,
    highlight: '3次关键扑救',
    topComment: RatingTopComment(
      user: '阿泽',
      text: '关键时刻几次神扑，配得上这个均分',
      likes: 42,
    ),
  ),
  RatingPlayer(
    name: 'Kevin',
    pos: 'LB',
    avgScore: 7.3,
    votes: 87,
    topComment: RatingTopComment(
      user: '林帅',
      text: '左路防守稳，下半场那次助攻有想法',
      likes: 23,
    ),
  ),
  RatingPlayer(
    name: '阿泽',
    pos: 'CB',
    avgScore: 7.1,
    votes: 84,
    topComment: RatingTopComment(
      user: '老王',
      text: '解围果断，就是几次回追节奏慢了点',
      likes: 18,
    ),
  ),
  RatingPlayer(
    name: '林帅',
    pos: 'CM',
    avgScore: 8.1,
    votes: 115,
    highlight: '全场跑动 9.8km',
    topComment: RatingTopComment(
      user: '陈子睿',
      text: '中场节拍器名不虚传，跑动覆盖满分',
      likes: 67,
    ),
  ),
  RatingPlayer(
    name: '江北',
    pos: 'RW',
    avgScore: 6.8,
    votes: 72,
    topComment: RatingTopComment(
      user: '路人丙',
      text: '右路突破太急，传中质量还得再练',
      likes: 15,
    ),
  ),
];

const oppTeam = [
  RatingPlayer(
    name: '徐铮',
    pos: 'CF',
    avgScore: 7.4,
    votes: 65,
    highlight: '1球',
    team: 'FC 黑马',
    topComment: RatingTopComment(
      user: '路人丁',
      text: '孤单的箭头，那个进球全靠自己单兵作战',
      likes: 28,
    ),
  ),
  RatingPlayer(
    name: '路人甲',
    pos: 'GK',
    avgScore: 5.2,
    votes: 61,
    highlight: '被过 4 次',
    team: 'FC 黑马',
    topComment: RatingTopComment(user: '陈子睿', text: '四次被单刀，这场真的扛不住', likes: 34),
  ),
  RatingPlayer(
    name: '路人乙',
    pos: 'CB',
    avgScore: 6.3,
    votes: 54,
    team: 'FC 黑马',
    topComment: RatingTopComment(
      user: '江北',
      text: '防守动作偏大，几次犯规也是没办法',
      likes: 12,
    ),
  ),
];

const hotRated = [
  HotRated(
    rank: 1,
    name: '陈子睿',
    team: '龙岗狼队',
    avgScore: 8.74,
    votes: 486,
    trend: '+0.12',
    trendUp: true,
  ),
  HotRated(
    rank: 2,
    name: '林帅',
    team: 'FC 黑马',
    avgScore: 8.41,
    votes: 412,
    trend: '+0.08',
    trendUp: true,
  ),
  HotRated(
    rank: 3,
    name: 'Kevin',
    team: '平湖闪电',
    avgScore: 8.12,
    votes: 358,
    trend: '-0.03',
    trendUp: false,
  ),
  HotRated(
    rank: 4,
    name: '阿泽',
    team: '坂田联',
    avgScore: 7.88,
    votes: 301,
    trend: '+0.05',
    trendUp: true,
  ),
  HotRated(
    rank: 5,
    name: '江北',
    team: '龙岗狼队',
    avgScore: 7.65,
    votes: 287,
    trend: '-0.09',
    trendUp: false,
  ),
];

// 0-10 分数的分布柱形
const ratingDist = [0, 1, 2, 4, 8, 18, 32, 48, 22, 7, 2];

const topComments = [
  TopComment(
    user: 'Kevin',
    score: 9,
    text: '子睿今天那脚世界波抽射真的绝了，门将毫无反应。',
    likes: 86,
    time: '10分钟前',
  ),
  TopComment(
    user: '老王',
    score: 9,
    text: '配合意识满分，经常跑出空档等我传长球。',
    likes: 54,
    time: '32分钟前',
  ),
  TopComment(
    user: '路人丙',
    score: 6,
    text: '上半场有点独，好在下半场改了过来。',
    likes: 12,
    time: '1小时前',
  ),
];
