import '../models/mission.dart';

/// Approved Missions catalog.
///
/// RECURRING budget (unchanged): daily total (all 7) = 400 coins, weekly total
/// (all 12 × 3 tiers) = 47,200, full week incl. daily = 50,000. Do NOT change
/// the recurring reward sources beyond these.
///
/// One-time [kMilestoneMissions] (below) sit OUTSIDE this recurring budget —
/// they pay out once ever (9,000 coins total + one free avatar) and never
/// reset, so they do not inflate the weekly economy.
///
/// Mission ids are unique across daily/weekly/milestone even when they share an
/// `eventKey` (e.g. a single AI-easy win increments BOTH `daily_ai_easy` and
/// `weekly_ai_easy`).

// ── Daily (exactly 7) ──────────────────────────────────────────────────────
const List<MissionDef> kDailyMissions = [
  MissionDef(
    id: 'daily_login',
    type: MissionType.daily,
    eventKey: 'daily_login',
    route: MissionRoute.none,
    titleAr: 'افتح اللعبة اليوم',
    titleEn: 'Open the game today',
    target: 1,
    rewardCoins: 50,
  ),
  MissionDef(
    id: 'daily_play3',
    type: MissionType.daily,
    eventKey: 'any_match_completed',
    route: MissionRoute.home,
    titleAr: 'العب 3 مباريات',
    titleEn: 'Play 3 matches',
    target: 3,
    rewardCoins: 60,
  ),
  MissionDef(
    id: 'daily_ai_easy',
    type: MissionType.daily,
    eventKey: 'ai_win_easy',
    route: MissionRoute.vsAi,
    titleAr: 'اكسب ضد AI سهل',
    titleEn: 'Win against Easy AI',
    target: 1,
    rewardCoins: 30,
  ),
  MissionDef(
    id: 'daily_ai_medium',
    type: MissionType.daily,
    eventKey: 'ai_win_medium',
    route: MissionRoute.vsAi,
    titleAr: 'اكسب ضد AI متوسط',
    titleEn: 'Win against Medium AI',
    target: 1,
    rewardCoins: 60,
  ),
  MissionDef(
    id: 'daily_ai_hard',
    type: MissionType.daily,
    eventKey: 'ai_win_hard',
    route: MissionRoute.vsAi,
    titleAr: 'اكسب ضد AI صعب',
    titleEn: 'Win against Hard AI',
    target: 1,
    rewardCoins: 120,
  ),
  MissionDef(
    id: 'daily_create_room',
    type: MissionType.daily,
    eventKey: 'online_room_created',
    route: MissionRoute.onlineCreate,
    titleAr: 'أنشئ غرفة أونلاين',
    titleEn: 'Create an online room',
    target: 1,
    rewardCoins: 40,
  ),
  MissionDef(
    id: 'daily_join_room',
    type: MissionType.daily,
    eventKey: 'online_room_joined_by_code',
    route: MissionRoute.onlineJoin,
    titleAr: 'ادخل غرفة بكود',
    titleEn: 'Join a room by code',
    target: 1,
    rewardCoins: 40,
  ),
];

// ── Weekly (exactly 12, each 3 tiers) ──────────────────────────────────────
const List<MissionDef> kWeeklyMissions = [
  MissionDef(
    id: 'weekly_play',
    type: MissionType.weekly,
    eventKey: 'any_match_completed',
    route: MissionRoute.home,
    titleAr: 'العب مباريات',
    titleEn: 'Play matches',
    tiers: [
      MissionTier(target: 10, rewardCoins: 900),
      MissionTier(target: 25, rewardCoins: 1900),
      MissionTier(target: 50, rewardCoins: 3200),
    ],
  ),
  MissionDef(
    id: 'weekly_win',
    type: MissionType.weekly,
    eventKey: 'any_match_won',
    route: MissionRoute.home,
    titleAr: 'اكسب مباريات',
    titleEn: 'Win matches',
    tiers: [
      MissionTier(target: 5, rewardCoins: 900),
      MissionTier(target: 10, rewardCoins: 1800),
      MissionTier(target: 20, rewardCoins: 2800),
    ],
  ),
  MissionDef(
    id: 'weekly_friend',
    type: MissionType.weekly,
    eventKey: 'friend_match_completed',
    route: MissionRoute.vsFriend,
    titleAr: 'العب ضد صديق',
    titleEn: 'Play vs Friend',
    tiers: [
      MissionTier(target: 5, rewardCoins: 400),
      MissionTier(target: 15, rewardCoins: 800),
      MissionTier(target: 30, rewardCoins: 1300),
    ],
  ),
  MissionDef(
    id: 'weekly_ai_play',
    type: MissionType.weekly,
    eventKey: 'ai_match_completed',
    route: MissionRoute.vsAi,
    titleAr: 'العب ضد AI',
    titleEn: 'Play vs AI',
    tiers: [
      MissionTier(target: 10, rewardCoins: 600),
      MissionTier(target: 25, rewardCoins: 1400),
      MissionTier(target: 50, rewardCoins: 2000),
    ],
  ),
  MissionDef(
    id: 'weekly_ai_easy',
    type: MissionType.weekly,
    eventKey: 'ai_win_easy',
    route: MissionRoute.vsAi,
    titleAr: 'اكسب ضد AI سهل',
    titleEn: 'Win vs Easy AI',
    tiers: [
      MissionTier(target: 5, rewardCoins: 300),
      MissionTier(target: 10, rewardCoins: 700),
      MissionTier(target: 20, rewardCoins: 1500),
    ],
  ),
  MissionDef(
    id: 'weekly_ai_medium',
    type: MissionType.weekly,
    eventKey: 'ai_win_medium',
    route: MissionRoute.vsAi,
    titleAr: 'اكسب ضد AI متوسط',
    titleEn: 'Win vs Medium AI',
    tiers: [
      MissionTier(target: 3, rewardCoins: 500),
      MissionTier(target: 7, rewardCoins: 1000),
      MissionTier(target: 15, rewardCoins: 2000),
    ],
  ),
  MissionDef(
    id: 'weekly_ai_hard',
    type: MissionType.weekly,
    eventKey: 'ai_win_hard',
    route: MissionRoute.vsAi,
    titleAr: 'اكسب ضد AI صعب',
    titleEn: 'Win vs Hard AI',
    tiers: [
      MissionTier(target: 1, rewardCoins: 800),
      MissionTier(target: 3, rewardCoins: 1500),
      MissionTier(target: 6, rewardCoins: 2500),
    ],
  ),
  MissionDef(
    id: 'weekly_create_room',
    type: MissionType.weekly,
    eventKey: 'online_room_created',
    route: MissionRoute.onlineCreate,
    titleAr: 'أنشئ غرف أونلاين',
    titleEn: 'Create online rooms',
    tiers: [
      MissionTier(target: 3, rewardCoins: 400),
      MissionTier(target: 7, rewardCoins: 800),
      MissionTier(target: 12, rewardCoins: 1300),
    ],
  ),
  MissionDef(
    id: 'weekly_join_room',
    type: MissionType.weekly,
    eventKey: 'online_room_joined_by_code',
    route: MissionRoute.onlineJoin,
    titleAr: 'ادخل غرف بكود',
    titleEn: 'Join rooms by code',
    tiers: [
      MissionTier(target: 3, rewardCoins: 400),
      MissionTier(target: 7, rewardCoins: 800),
      MissionTier(target: 12, rewardCoins: 1300),
    ],
  ),
  MissionDef(
    id: 'weekly_online_complete',
    type: MissionType.weekly,
    eventKey: 'online_match_completed',
    route: MissionRoute.online,
    titleAr: 'العب مباريات أونلاين كاملة',
    titleEn: 'Complete online matches',
    tiers: [
      MissionTier(target: 3, rewardCoins: 600),
      MissionTier(target: 7, rewardCoins: 1400),
      MissionTier(target: 12, rewardCoins: 2000),
    ],
  ),
  MissionDef(
    id: 'weekly_online_win',
    type: MissionType.weekly,
    eventKey: 'online_match_won',
    route: MissionRoute.online,
    titleAr: 'اكسب مباريات أونلاين',
    titleEn: 'Win online matches',
    tiers: [
      MissionTier(target: 1, rewardCoins: 1000),
      MissionTier(target: 3, rewardCoins: 1700),
      MissionTier(target: 6, rewardCoins: 2600),
    ],
  ),
  MissionDef(
    id: 'weekly_level',
    type: MissionType.weekly,
    eventKey: 'level_completed',
    route: MissionRoute.levels,
    titleAr: 'اكمل مستويات',
    titleEn: 'Complete levels',
    tiers: [
      MissionTier(target: 3, rewardCoins: 700),
      MissionTier(target: 6, rewardCoins: 1300),
      MissionTier(target: 10, rewardCoins: 2100),
    ],
  ),
];

// ── Milestones (one-time achievements — never reset) ───────────────────────
//
// These pay out ONCE, so they do not touch the recurring daily(400)/weekly
// (47,200) budget. Coin total across all milestones = 9,000 one-time, plus the
// free `Avatar__7` frame from the 7-day login streak.
const List<MissionDef> kMilestoneMissions = [
  MissionDef(
    id: 'milestone_login_7day',
    type: MissionType.milestone,
    eventKey: 'login_streak',
    route: MissionRoute.none,
    titleAr: 'افتح اللعبة 7 أيام',
    titleEn: 'Open the game for 7 days',
    target: 7,
    rewardCoins: 0,
    rewardAvatarId: 7, // free Avatar__7 (Riot) frame
  ),
  MissionDef(
    id: 'milestone_spend_coins',
    type: MissionType.milestone,
    eventKey: 'coins_spent',
    route: MissionRoute.store,
    titleAr: 'أنفق 10,000 عملة',
    titleEn: 'Spend 10,000 coins',
    target: 10000,
    rewardCoins: 3000,
  ),
  MissionDef(
    id: 'milestone_buy_theme',
    type: MissionType.milestone,
    eventKey: 'theme_bought',
    route: MissionRoute.store,
    titleAr: 'اشترِ أي ثيم X أو O',
    titleEn: 'Buy any X or O theme',
    target: 1,
    rewardCoins: 2000,
  ),
  MissionDef(
    id: 'milestone_buy_premium_avatar',
    type: MissionType.milestone,
    eventKey: 'premium_avatar_bought',
    route: MissionRoute.store,
    titleAr: 'اشترِ أفاتار مميز',
    titleEn: 'Buy a premium avatar',
    target: 1,
    rewardCoins: 2500,
  ),
  MissionDef(
    id: 'milestone_equip_avatar',
    type: MissionType.milestone,
    eventKey: 'avatar_equipped',
    route: MissionRoute.store,
    titleAr: 'جهّز إطار أفاتار',
    titleEn: 'Equip an avatar frame',
    target: 1,
    rewardCoins: 500,
  ),
  MissionDef(
    id: 'milestone_invite_friend',
    type: MissionType.milestone,
    eventKey: 'friend_invited',
    route: MissionRoute.none,
    titleAr: 'ادعُ صديقاً',
    titleEn: 'Invite a friend',
    target: 1,
    rewardCoins: 1000,
  ),
];

/// All missions (daily, then weekly, then one-time milestones).
final List<MissionDef> kAllMissions = [
  ...kDailyMissions,
  ...kWeeklyMissions,
  ...kMilestoneMissions,
];
