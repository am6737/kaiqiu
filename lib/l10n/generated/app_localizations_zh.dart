// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppL10nZh extends AppL10n {
  AppL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get app_name => '开球';

  @override
  String get tab_home => '首页';

  @override
  String get tab_pickup => '约球';

  @override
  String get tab_events => '赛事';

  @override
  String get tab_me => '我的';

  @override
  String get inbox_title => '收件箱';

  @override
  String get inbox_tab_messages => '消息';

  @override
  String get inbox_tab_notifications => '通知';

  @override
  String get common_back => '返回';

  @override
  String get common_cancel => '取消';

  @override
  String get common_confirm => '确认';

  @override
  String get common_save => '保存';

  @override
  String get common_submit => '提交';

  @override
  String get common_delete => '删除';

  @override
  String get common_edit => '编辑';

  @override
  String get common_share => '分享';

  @override
  String get common_close => '关闭';

  @override
  String get common_done => '完成';

  @override
  String get common_retry => '重试';

  @override
  String get common_loading => '加载中…';

  @override
  String get common_next => '下一步';

  @override
  String get common_prev => '上一步';

  @override
  String get common_finish => '完成';

  @override
  String get common_send => '发送';

  @override
  String get common_search => '搜索';

  @override
  String get common_filter => '筛选';

  @override
  String get common_more => '更多';

  @override
  String get common_new => '新建';

  @override
  String get common_yes => '是';

  @override
  String get common_no => '否';

  @override
  String get common_required => '必填';

  @override
  String get common_optional => '选填';

  @override
  String get common_default => '默认';

  @override
  String get common_follow => '关注';

  @override
  String get common_unfollow => '已关注';

  @override
  String get common_favorite => '收藏';

  @override
  String get common_unfavorite => '已收藏';

  @override
  String get common_all => '全部';

  @override
  String get common_today => '今天';

  @override
  String get common_tomorrow => '明天';

  @override
  String get common_this_week => '本周';

  @override
  String get common_unread => '未读';

  @override
  String get common_pin => '置顶';

  @override
  String get common_unpin => '取消置顶';

  @override
  String get common_mute => '静音';

  @override
  String get common_unmute => '取消静音';

  @override
  String get common_report => '举报';

  @override
  String get common_copy => '复制';

  @override
  String get common_copied => '已复制';

  @override
  String get common_version => '版本';

  @override
  String get error_load_failed => '加载失败';

  @override
  String get error_network => '网络异常，请重试';

  @override
  String get error_required_field => '此项不能为空';

  @override
  String get error_invalid_email => '邮箱格式不正确';

  @override
  String get error_password_too_short => '密码至少 6 位';

  @override
  String get error_not_integer => '请输入整数';

  @override
  String get error_invalid_date => '日期格式不正确（YYYY-MM-DD）';

  @override
  String get error_please_login => '请先登录';

  @override
  String get error_unknown => '出错了';

  @override
  String get empty_no_data => '暂无数据';

  @override
  String get empty_no_events => '暂无赛事';

  @override
  String get empty_no_events_sub => '点右上角创建赛事发起一个';

  @override
  String get empty_no_pickups => '暂无球局';

  @override
  String get empty_no_pickups_sub => '试试调整筛选条件，或发起一个新球局';

  @override
  String get empty_no_messages => '暂无消息';

  @override
  String get empty_no_messages_sub => '去约球或赛事页发现更多同好';

  @override
  String get empty_no_favorites => '还没有收藏';

  @override
  String get empty_no_favorites_sub => '看到喜欢的球局或赛事，点击收藏按钮加入';

  @override
  String get empty_no_teams => '还没有队伍';

  @override
  String get empty_no_teams_sub => '创建你的第一支球队';

  @override
  String get empty_no_notifications => '暂无通知';

  @override
  String get empty_no_search => '未找到匹配结果';

  @override
  String get empty_no_rating => '还没有评分';

  @override
  String get empty_no_rating_sub => '去评一场最近的比赛';

  @override
  String get home_live_now => '正在直播';

  @override
  String get home_view_all => '查看全部';

  @override
  String get home_local_feed => '同城动态';

  @override
  String get home_feed_pickup => '约球';

  @override
  String get home_feed_result => '战报';

  @override
  String get home_feed_all => '全部';

  @override
  String get home_rate_cta_title => '你有待评价的比赛';

  @override
  String home_rate_cta_sub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位队友等你评分',
      zero: '暂无',
    );
    return '$_temp0';
  }

  @override
  String get home_no_live => '暂无直播比赛';

  @override
  String get home_bottom_of_feed => '— 到底了 · 今天也是踢球的一天 —';

  @override
  String get home_loading_pickups => '正在加载球局…';

  @override
  String get sport_football => '足球';

  @override
  String get sport_basketball => '篮球';

  @override
  String get sport_badminton => '羽毛球';

  @override
  String get sport_pingpong => '乒乓球';

  @override
  String get sport_cycling => '骑行';

  @override
  String pickup_title(String city) {
    return '约球 · $city';
  }

  @override
  String get pickup_filter_today => '今天';

  @override
  String get pickup_filter_tomorrow => '明天';

  @override
  String get pickup_filter_week => '本周';

  @override
  String get pickup_filter_mid => '中级';

  @override
  String get pickup_filter_cheap => '¥ ≤50';

  @override
  String get pickup_filter_near => '3km内';

  @override
  String get pickup_filter_title => '筛选';

  @override
  String get pickup_filter_distance => '距离';

  @override
  String get pickup_filter_fee => '费用';

  @override
  String get pickup_filter_level => '等级';

  @override
  String get pickup_filter_time => '时段';

  @override
  String get pickup_filter_apply => '应用';

  @override
  String get pickup_filter_reset => '重置';

  @override
  String get pickup_status_open => '招人中';

  @override
  String get pickup_status_almost => '即将满员';

  @override
  String get pickup_status_full => '已满';

  @override
  String pickup_city_pickup_count(int n) {
    return '同城 $n 个球局';
  }

  @override
  String get pickup_sort_by_distance => '按距离排序';

  @override
  String pickup_need_n(int n) {
    return '缺$n';
  }

  @override
  String get pickup_detail_organizer => '组织者';

  @override
  String get pickup_detail_formation => '阵型图';

  @override
  String get pickup_detail_match_info => '比赛详情';

  @override
  String get pickup_detail_fee => '费用';

  @override
  String get pickup_detail_duration => '时长';

  @override
  String get pickup_detail_level => '等级';

  @override
  String get pickup_detail_field_type => '场地类型';

  @override
  String get pickup_detail_join_cta => '一键报名';

  @override
  String get pickup_detail_select_position => '选位置报名';

  @override
  String get pickup_detail_already_joined => '已报名';

  @override
  String get pickup_detail_full_cta => '已满员';

  @override
  String get pickup_detail_tap_empty_slot => '点击阵型图上任一空位选择位置';

  @override
  String get pickup_detail_contact_organizer => '联系组织者';

  @override
  String get pickup_create_title => '发起约球';

  @override
  String get pickup_create_venue => '场地';

  @override
  String get pickup_create_address => '详细地址（可选）';

  @override
  String get pickup_create_address_hint => '街道门牌号，便于队友导航';

  @override
  String get pickup_create_start_at => '开始时间';

  @override
  String get pickup_create_duration_min => '时长（分钟）';

  @override
  String get pickup_create_total => '总人数';

  @override
  String get pickup_create_fee => '费用（元）';

  @override
  String get pickup_create_level => '等级';

  @override
  String get pickup_create_formation => '阵型';

  @override
  String get pickup_create_field_type => '场地类型';

  @override
  String get pickup_create_submit => '发布约球';

  @override
  String get pickup_create_success => '球局已发布';

  @override
  String get events_title => '赛事';

  @override
  String get events_create => '创建赛事';

  @override
  String get events_tab_ongoing => '进行中';

  @override
  String get events_tab_registering => '报名中';

  @override
  String get events_tab_watch => '观看';

  @override
  String get events_watch_today => '今日赛程 · 你关注的';

  @override
  String get events_wc_banner_title => '2026 FIFA 世界杯专区';

  @override
  String get events_wc_banner_sub => '小组赛第 2 轮 · 今晚 5 场同步直播';

  @override
  String get events_wc_live_now => '正在直播';

  @override
  String get events_wc_predicts => '同城竞猜';

  @override
  String get events_pro => '职业赛事';

  @override
  String get event_status_ongoing => '正在进行';

  @override
  String get event_status_registering => '报名中';

  @override
  String get event_status_done => '已结束';

  @override
  String get event_kpi_teams => '队伍';

  @override
  String get event_kpi_matches => '场次';

  @override
  String get event_kpi_prize => '奖金';

  @override
  String get event_kpi_viewers => '观众';

  @override
  String get event_tab_overview => '概览';

  @override
  String get event_tab_bracket => '赛程';

  @override
  String get event_tab_standings => '积分榜';

  @override
  String get event_tab_scorers => '射手榜';

  @override
  String get event_tab_ratings => '评分榜';

  @override
  String get event_tab_chat => '讨论';

  @override
  String get event_overview_rules => '规则';

  @override
  String get event_overview_organizer => '组织方';

  @override
  String get event_bracket_qf => '1/4 决赛';

  @override
  String get event_bracket_sf => '半决赛';

  @override
  String get event_bracket_final => '决赛';

  @override
  String get event_bracket_champion => '冠军';

  @override
  String get event_bracket_tbd => 'TBD';

  @override
  String get event_bracket_empty => '暂无赛程，等待组委会发布';

  @override
  String get event_standings_rank => '#';

  @override
  String get event_standings_team => '队伍';

  @override
  String get event_standings_wins => '胜';

  @override
  String get event_standings_draws => '平';

  @override
  String get event_standings_losses => '负';

  @override
  String get event_standings_points => '积分';

  @override
  String get event_standings_empty => '暂无比赛结果';

  @override
  String get event_cta_watch_live => '观看直播';

  @override
  String get event_cta_register => '报名参赛';

  @override
  String get event_cta_registered => '已报名';

  @override
  String get event_chat_hint => '发条评论…';

  @override
  String get event_chat_send => '发送';

  @override
  String get event_register_form_title => '报名参赛';

  @override
  String get event_register_team_name => '队伍名';

  @override
  String get event_register_contact => '联系人';

  @override
  String get event_register_phone => '电话';

  @override
  String get event_register_submit => '提交报名';

  @override
  String get event_register_success => '报名已提交，等待组委会审核';

  @override
  String get event_rating_team_all => '全部';

  @override
  String get event_rating_mvp => 'MVP';

  @override
  String get event_rating_tap_for_detail => '· 点击球员查看评分详情 ·';

  @override
  String event_rating_players_voted(int n) {
    return '$n 人参与评分';
  }

  @override
  String get event_rating_score_avg => '均分';

  @override
  String get event_rating_distribution => '评分分布 · 样例';

  @override
  String get event_rating_hot_comments => '热门评论 · 样例';

  @override
  String get event_rating_sort_hot => '按热度排序';

  @override
  String get event_rating_reply => '回复';

  @override
  String get create_event_title => '创建赛事';

  @override
  String create_event_step_n_of(int cur, int total) {
    return '第 $cur 步 · 共 $total 步';
  }

  @override
  String get create_event_step_template => '赛事模板';

  @override
  String get create_event_step_basic => '基本信息';

  @override
  String get create_event_step_registration => '报名设置';

  @override
  String get create_event_step_preview => '发布预览';

  @override
  String get create_event_tpl_title => '选择赛事模板';

  @override
  String get create_event_tpl_subtitle => '模板决定赛程结构，稍后可调整';

  @override
  String get create_event_tpl_group8 => '8队小组赛';

  @override
  String get create_event_tpl_group8_desc => '2组4队 单循环 + 交叉淘汰';

  @override
  String get create_event_tpl_knockout16 => '16队淘汰赛';

  @override
  String get create_event_tpl_knockout16_desc => '单败淘汰 4 轮决出冠军';

  @override
  String get create_event_tpl_wc => '世界杯赛制';

  @override
  String get create_event_tpl_wc_desc => '32队 8小组 + 淘汰赛';

  @override
  String get create_event_tpl_league => '联赛赛制';

  @override
  String get create_event_tpl_league_desc => '主客场双循环积分制';

  @override
  String get create_event_f_name => '赛事名称';

  @override
  String get create_event_f_start => '开赛日期';

  @override
  String get create_event_f_end => '结束日期';

  @override
  String get create_event_f_venue => '场地';

  @override
  String get create_event_f_fee => '报名费(每队)';

  @override
  String get create_event_f_prize => '总奖金';

  @override
  String get create_event_f_deadline => '报名截止';

  @override
  String get create_event_f_teamsize => '每队人数';

  @override
  String get create_event_f_maxteams => '队伍上限';

  @override
  String get create_event_review_title => '审核方式';

  @override
  String get create_event_review_auto => '自动通过';

  @override
  String get create_event_review_manual => '组委会审核';

  @override
  String get create_event_organizer_tip_title => '组织者提示';

  @override
  String get create_event_organizer_tip_body =>
      '建议保留至少 3 天审核期以便处理队伍资料。开赛后无法修改赛事配置。';

  @override
  String get create_event_preview_subtitle => '确认无误后即可发布，队伍可以开始报名';

  @override
  String get create_event_preview_config_ok => '配置完整，可以发布';

  @override
  String get create_event_cta_next => '下一步';

  @override
  String get create_event_cta_prev => '上一步';

  @override
  String get create_event_cta_publish => '发布赛事';

  @override
  String get create_event_cta_publishing => '发布中…';

  @override
  String get create_event_save_draft => '保存草稿';

  @override
  String get create_event_draft_saved => '草稿已保存';

  @override
  String get create_event_draft_loaded => '已加载上次的草稿';

  @override
  String get create_event_published => '赛事已发布';

  @override
  String create_event_publish_failed(String err) {
    return '发布失败：$err';
  }

  @override
  String create_event_preview_registered_of_max(String max, String deadline) {
    return '0/$max 已报名 · 截止 $deadline';
  }

  @override
  String get wc_title => '世界杯专区';

  @override
  String get wc_subtitle => '小组赛 · 第 2 轮 · 今晚 5 场直播';

  @override
  String get wc_focus => '焦点之战 · 直播中';

  @override
  String wc_viewers(String v) {
    return '$v 观看';
  }

  @override
  String get wc_predict_bar_title => '你的球友竞猜 · 胜平负';

  @override
  String get wc_today_schedule => '今日赛程';

  @override
  String get wc_btn_watch_live => '观看直播';

  @override
  String get wc_btn_predict => '竞猜';

  @override
  String get wc_btn_remind => '提醒';

  @override
  String get wc_btn_danmaku_on => '弹幕 开';

  @override
  String get wc_btn_danmaku_off => '弹幕 关';

  @override
  String get wc_remind_set => '已设置提醒，比赛开始前 10 分钟通知你';

  @override
  String get wc_remind_unset => '已取消提醒';

  @override
  String get wc_remind_sheet_title => '赛前提醒';

  @override
  String get wc_remind_sheet_sub => '提前多久提醒你？';

  @override
  String wc_remind_option_min(int n) {
    return '$n 分钟';
  }

  @override
  String wc_remind_option_hour(int n) {
    return '$n 小时';
  }

  @override
  String get wc_remind_cancel => '取消提醒';

  @override
  String wc_remind_set_n_min(int n) {
    return '已设置提醒，比赛开始前 $n 分钟通知你';
  }

  @override
  String get wc_remind_default_badge => '默认';

  @override
  String get wc_live_title => '直播中';

  @override
  String get wc_live_input_hint => '发一条弹幕…';

  @override
  String wc_live_viewer_count(String n) {
    return '$n 人观看';
  }

  @override
  String get wc_live_back_to_feed => '返回';

  @override
  String get wc_live_half_time => '下半场';

  @override
  String get wc_live_comment_ph => '赛况如何？发弹幕讨论';

  @override
  String get wc_live_loading => '正在连接直播…';

  @override
  String get wc_live_signal_weak => '直播信号弱';

  @override
  String get wc_live_tap_retry => '点击重试';

  @override
  String wc_live_score_overlay(
    String home,
    String sa,
    String sb,
    String away,
    String min,
  ) {
    return '$home $sa - $sb $away · $min\'';
  }

  @override
  String get wc_predict_title => '竞猜';

  @override
  String get wc_predict_pick_title => '你看好谁？';

  @override
  String get wc_predict_home_win => '主队胜';

  @override
  String get wc_predict_draw => '平局';

  @override
  String get wc_predict_away_win => '客队胜';

  @override
  String get wc_predict_stake => '下注积分';

  @override
  String get wc_predict_submit => '提交竞猜';

  @override
  String get wc_predict_submitted => '已提交 · 赛后结算';

  @override
  String wc_predict_change(String choice) {
    return '已选：$choice';
  }

  @override
  String get wc_predict_distribution => '全站竞猜分布';

  @override
  String get wc_predict_you_picked => '你的选择';

  @override
  String get messages_title => '消息';

  @override
  String get messages_empty_title => '暂无对话';

  @override
  String get messages_empty_sub => '去约球或赛事里，发现更多同城球友';

  @override
  String get messages_new_sheet_title => '新建';

  @override
  String get messages_new_group => '新建群聊';

  @override
  String get messages_new_group_title_hint => '群聊名称';

  @override
  String get messages_new_created => '已创建对话';

  @override
  String get messages_new_failed => '创建失败';

  @override
  String get messages_long_press_actions_mark_read => '标记为已读';

  @override
  String get messages_long_press_actions_mark_unread => '标记为未读';

  @override
  String get messages_long_press_actions_delete => '删除对话';

  @override
  String get messages_delete_confirm => '删除此对话？';

  @override
  String get messages_deleted => '已删除';

  @override
  String get chat_hint => '说点什么…';

  @override
  String get chat_send_failed => '发送失败';

  @override
  String get chat_attachment_image => '图片';

  @override
  String get chat_attachment_location => '位置';

  @override
  String get chat_attachment_invite => '约球邀请';

  @override
  String get chat_attachment_system_placeholder => '[系统消息]';

  @override
  String get chat_more_members => '查看成员';

  @override
  String get chat_more_clear_history => '清空聊天记录';

  @override
  String get chat_more_mute => '静音';

  @override
  String get chat_more_unmute => '取消静音';

  @override
  String get chat_more_report => '举报';

  @override
  String get chat_clear_confirm => '清空所有聊天记录？';

  @override
  String get chat_cleared => '已清空';

  @override
  String get profile_title => '我的';

  @override
  String get profile_edit_btn => '编辑';

  @override
  String get profile_archive_title => '我的球员档案';

  @override
  String get profile_archive_new_badge => 'NEW';

  @override
  String get profile_mini_overall => '综合';

  @override
  String get profile_mini_matches => '场次';

  @override
  String get profile_mini_goals => '进球';

  @override
  String get profile_mini_mvp => 'MVP';

  @override
  String get profile_section_activity => '我的活动';

  @override
  String get profile_section_settings => '设置';

  @override
  String get profile_menu_my_events => '我报名的赛事';

  @override
  String get profile_menu_my_pickups => '我组织的球局';

  @override
  String get profile_menu_my_teams => '我的队伍';

  @override
  String get profile_menu_favorites => '收藏与足迹';

  @override
  String get profile_menu_account => '账号设置';

  @override
  String get profile_menu_notif => '通知与消息';

  @override
  String get profile_menu_help => '帮助与反馈';

  @override
  String get profile_menu_about => '关于开球';

  @override
  String get profile_following => '关注';

  @override
  String get profile_followers => '粉丝';

  @override
  String get profile_logout => '退出登录';

  @override
  String get profile_logout_confirm => '确认退出登录？';

  @override
  String get archive_share => '分享档案';

  @override
  String get archive_card_profile => '球员档案 · 2026';

  @override
  String get archive_card_overall => '综合评分';

  @override
  String get archive_flip_front => '点击卡片查看正面';

  @override
  String get archive_flip_back => '点击卡片查看属性雷达';

  @override
  String get archive_rating_panel_title => '我的评分 · 过去 30 天';

  @override
  String get archive_rating_rated => '被评';

  @override
  String get archive_rating_rank => '赛事排名';

  @override
  String get archive_rating_trend => '趋势';

  @override
  String get archive_rating_go_rate => '去评分';

  @override
  String get archive_season_data => '数据墙 · 赛季';

  @override
  String get archive_goal_trend => '本赛季进球趋势';

  @override
  String get archive_honors_title => '荣誉墙';

  @override
  String archive_honors_count(int n) {
    return '$n 项';
  }

  @override
  String get archive_teammates_title => '队友网络';

  @override
  String archive_teammates_sub(int n) {
    return '常一起踢球的 $n 人';
  }

  @override
  String get archive_history_title => '比赛历史';

  @override
  String get archive_radar_title => '属性雷达';

  @override
  String get archive_radar_flip_back => '点击翻回';

  @override
  String archive_teammates_matches(int n) {
    return '$n场';
  }

  @override
  String get archive_history_mvp => 'MVP';

  @override
  String archive_history_goals_n(int n) {
    return '$n球';
  }

  @override
  String archive_history_assists_n(int n) {
    return '$n助';
  }

  @override
  String get profile_edit_title => '编辑资料';

  @override
  String get profile_edit_name => '昵称';

  @override
  String get profile_edit_handle => '用户名';

  @override
  String get profile_edit_city => '所在城市';

  @override
  String get profile_edit_district => '城区';

  @override
  String get profile_edit_position => '位置';

  @override
  String get profile_edit_position_full => '位置全称';

  @override
  String get profile_edit_height => '身高 (cm)';

  @override
  String get profile_edit_foot => '惯用脚';

  @override
  String get profile_edit_foot_left => '左脚';

  @override
  String get profile_edit_foot_right => '右脚';

  @override
  String get profile_edit_foot_both => '双脚';

  @override
  String get profile_edit_avatar => '头像';

  @override
  String get profile_edit_avatar_hint => '点击更换头像（暂用首字母）';

  @override
  String get profile_edit_save_ok => '已保存';

  @override
  String get profile_edit_save_fail => '保存失败';

  @override
  String get profile_edit_position_opt_gk => 'GK · 门将';

  @override
  String get profile_edit_position_opt_cb => 'CB · 中后卫';

  @override
  String get profile_edit_position_opt_lb => 'LB · 左后卫';

  @override
  String get profile_edit_position_opt_rb => 'RB · 右后卫';

  @override
  String get profile_edit_position_opt_cm => 'CM · 中场';

  @override
  String get profile_edit_position_opt_cam => 'CAM · 前腰';

  @override
  String get profile_edit_position_opt_cdm => 'CDM · 后腰';

  @override
  String get profile_edit_position_opt_lw => 'LW · 左边锋';

  @override
  String get profile_edit_position_opt_rw => 'RW · 右边锋';

  @override
  String get profile_edit_position_opt_cf => 'CF · 中锋';

  @override
  String get profile_edit_position_opt_st => 'ST · 前锋';

  @override
  String get settings_account_title => '账号设置';

  @override
  String get settings_account_language => '语言';

  @override
  String get settings_account_profile => '修改资料';

  @override
  String get settings_account_email => '绑定邮箱';

  @override
  String get settings_account_password => '修改密码';

  @override
  String get settings_account_password_old => '旧密码';

  @override
  String get settings_account_password_new => '新密码';

  @override
  String get settings_account_password_confirm => '确认新密码';

  @override
  String get settings_account_password_updated => '密码已更新';

  @override
  String get settings_account_password_mismatch => '两次密码不一致';

  @override
  String get settings_account_logout => '退出登录';

  @override
  String get settings_account_delete => '注销账号';

  @override
  String get settings_account_delete_confirm => '注销后所有数据将不可恢复，是否继续？';

  @override
  String get settings_account_delete_done => '账号已注销';

  @override
  String get settings_lang_title => '语言 / Language';

  @override
  String get settings_lang_zh => '中文 简体';

  @override
  String get settings_lang_en => 'English';

  @override
  String get settings_lang_system => '跟随系统';

  @override
  String get settings_notif_title => '通知与消息';

  @override
  String get settings_notif_push => '推送通知';

  @override
  String get settings_notif_push_sub => '关闭后将无法收到系统推送';

  @override
  String get settings_notif_inapp => '站内消息';

  @override
  String get settings_notif_inapp_sub => '聊天、评论、系统通知';

  @override
  String get settings_notif_email => '邮件提醒';

  @override
  String get settings_notif_email_sub => '重要通知发送到你的邮箱';

  @override
  String get settings_notif_match_reminder => '赛前提醒';

  @override
  String get settings_notif_match_reminder_sub => '比赛开始前 10 分钟提醒';

  @override
  String get profile_menu_appearance => '外观';

  @override
  String get settings_appearance_title => '外观';

  @override
  String get appearance_theme_mode_section => '主题模式';

  @override
  String get appearance_theme_mode_system => '跟随系统';

  @override
  String get appearance_theme_mode_light => '浅色';

  @override
  String get appearance_theme_mode_dark => '深色';

  @override
  String get appearance_accent_section => '主题色';

  @override
  String get appearance_accent_green => '经典绿';

  @override
  String get appearance_accent_orange => '活力橙';

  @override
  String get appearance_accent_cyan => '海洋青';

  @override
  String get appearance_accent_red => '热情红';

  @override
  String get appearance_accent_custom => '自定义';

  @override
  String get appearance_preview_section => '预览';

  @override
  String get appearance_preview_card_title => '周三晚 7:30  五人足球';

  @override
  String get appearance_preview_card_meta => '南宁青秀·星空足球公园';

  @override
  String get appearance_preview_card_cta => '立即报名';

  @override
  String get appearance_picker_title => '选择主题色';

  @override
  String get appearance_picker_confirm => '确定';

  @override
  String get appearance_picker_cancel => '取消';

  @override
  String get settings_help_title => '帮助与反馈';

  @override
  String get settings_help_faq => '常见问题';

  @override
  String get settings_help_feedback => '写下你的反馈';

  @override
  String get settings_help_feedback_hint => '描述问题或建议，我们会尽快改进…';

  @override
  String get settings_help_feedback_submit => '提交反馈';

  @override
  String get settings_help_feedback_thanks => '已收到，感谢反馈';

  @override
  String get settings_help_faq_1_q => '如何发起一个约球？';

  @override
  String get settings_help_faq_1_a => '进入「约球」Tab，点击右下角 + 按钮，填写场地、时间、人数等信息即可发布。';

  @override
  String get settings_help_faq_2_q => '报名赛事后可以退出吗？';

  @override
  String get settings_help_faq_2_a => '报名审核中可直接退出；审核通过后需联系组委会。';

  @override
  String get settings_help_faq_3_q => '评分规则是怎样的？';

  @override
  String get settings_help_faq_3_a =>
      '每场比赛结束后 72 小时内可对队友/对手打 0-10 分，每位球员的最终评分为所有评分人的平均值。';

  @override
  String get settings_help_faq_4_q => '如何认领球员档案？';

  @override
  String get settings_help_faq_4_a => '在「我的 → 编辑」中补全位置、身高、惯脚即可激活档案。';

  @override
  String get settings_help_faq_5_q => '开球支持哪些运动？';

  @override
  String get settings_help_faq_5_a => '当前支持足球、篮球、羽毛球、乒乓球、骑行，后续将持续扩展。';

  @override
  String get settings_help_faq_6_q => '忘记密码怎么办？';

  @override
  String get settings_help_faq_6_a => '在登录页点击「忘记密码」，输入邮箱后我们会发送重置链接。';

  @override
  String get settings_about_title => '关于开球';

  @override
  String get settings_about_version_label => '版本';

  @override
  String get settings_about_tagline => '业余运动的主场';

  @override
  String get settings_about_team => '团队';

  @override
  String get settings_about_team_body =>
      '开球 · GameOn 是一群踢球、打球、写代码的玩家做的社区。我们相信业余运动也值得被认真记录。';

  @override
  String get settings_about_legal => '法律';

  @override
  String get settings_about_terms => '用户协议';

  @override
  String get settings_about_privacy => '隐私政策';

  @override
  String get settings_about_contact => '联系我们';

  @override
  String get settings_about_email => 'hi@kaiqiu.app';

  @override
  String get legal_terms_title => '用户协议';

  @override
  String get legal_privacy_title => '隐私政策';

  @override
  String get legal_terms_body =>
      '欢迎使用开球（以下简称「本 App」）。通过注册或使用本 App，即表示你同意本协议全部条款。\n\n1. 用户行为：请文明使用，禁止发布违法或侵害他人权益的内容。\n2. 账号与安全：你对自己的账号及密码负责，由此产生的一切活动由你本人承担。\n3. 内容所有权：你发布的内容归你所有，授予本 App 在服务范围内免费使用的权利。\n4. 免责声明：约球与线下活动存在风险，请自行评估身体状况并购买必要的保险。\n5. 协议变更：本 App 有权更新本协议，新版本将在 App 内公示。\n\n如有疑问，请联系 hi@kaiqiu.app。';

  @override
  String get legal_privacy_body =>
      '我们重视你的隐私。以下是关于你如何使用开球 App、我们如何收集与使用信息的简要说明。\n\n1. 收集信息：注册信息（邮箱/昵称）、位置信息（在你允许后用于同城推荐）、比赛数据（你主动发布的内容）。\n2. 使用目的：提供服务、改进体验、安全防护、统计分析。\n3. 信息共享：我们不会出售你的个人信息。必要时与服务提供商共享，且对方受同等保密义务约束。\n4. 你的权利：可随时访问、修正、导出或删除个人信息。\n5. 数据安全：我们使用业界通用的加密与访问控制措施保护你的数据。\n\n如有疑问，请联系 hi@kaiqiu.app。';

  @override
  String get search_title => '搜索';

  @override
  String get search_hint => '搜索约球 / 赛事 / 球员 / 场地';

  @override
  String get search_recent => '最近搜索';

  @override
  String get search_hot_tags => '热门标签';

  @override
  String get search_clear => '清空';

  @override
  String get search_result_pickups => '约球';

  @override
  String get search_result_events => '赛事';

  @override
  String search_result_empty(String q) {
    return '没有找到与「$q」相关的结果';
  }

  @override
  String get notif_title => '通知';

  @override
  String get notif_all => '全部';

  @override
  String get notif_unread => '未读';

  @override
  String get notif_mark_all_read => '全部已读';

  @override
  String get notif_group_system => '系统';

  @override
  String get notif_group_match => '比赛';

  @override
  String get notif_group_pickup => '约球';

  @override
  String get notif_group_rating => '评分';

  @override
  String get notif_group_follow => '关注';

  @override
  String get notif_demo_welcome_t => '欢迎来到开球 ⚽';

  @override
  String get notif_demo_welcome_b => '完善档案，开启你的赛季之旅。';

  @override
  String get notif_demo_rate_t => '你有一场比赛待评分';

  @override
  String get notif_demo_rate_b => '龙岗村超 · 狼队 vs FC 黑马，3 位队友等你打分。';

  @override
  String get notif_demo_pickup_t => '周六 19:30 约球还差 1 人';

  @override
  String get notif_demo_pickup_b => '莲花山足球场 · 点击查看阵型。';

  @override
  String get notif_demo_event_t => '2026 龙岗夏季杯开始报名';

  @override
  String get notif_demo_event_b => '16 队淘汰制，奖金 2 万，截止 05-25。';

  @override
  String get notif_demo_follow_t => '老王 关注了你';

  @override
  String get notif_demo_follow_b => '互相关注后即可私信。';

  @override
  String get city_picker_title => '选择城市';

  @override
  String get city_picker_hot => '热门城市';

  @override
  String get city_picker_all => '全部城市';

  @override
  String get city_picker_current => '当前定位';

  @override
  String get me_events_title => '我的赛事';

  @override
  String get me_events_tab_registered => '我报名的';

  @override
  String get me_events_tab_hosted => '我组织的';

  @override
  String get me_events_tab_done => '已完赛';

  @override
  String get me_pickups_title => '我的球局';

  @override
  String get me_pickups_tab_hosted => '我组织的';

  @override
  String get me_pickups_tab_joined => '我参加的';

  @override
  String get me_teams_title => '我的队伍';

  @override
  String get me_teams_create => '创建球队';

  @override
  String get me_teams_create_name => '球队名';

  @override
  String get me_teams_create_city => '所在城市';

  @override
  String get me_teams_create_sub => '简介';

  @override
  String get me_teams_create_submit => '创建';

  @override
  String get me_teams_remove => '解散';

  @override
  String get me_teams_remove_confirm => '确认解散该队伍？';

  @override
  String get me_favorites_title => '收藏与足迹';

  @override
  String get me_favorites_tab_pickups => '约球';

  @override
  String get me_favorites_tab_events => '赛事';

  @override
  String get me_favorites_tab_players => '球员';

  @override
  String get auth_login_title => '欢迎来到开球';

  @override
  String get auth_login_sub => '一起踢一场';

  @override
  String get auth_email => '邮箱';

  @override
  String get auth_password => '密码';

  @override
  String get auth_remember_me => '记住我';

  @override
  String get auth_forgot_password => '忘记密码';

  @override
  String get auth_signup_toggle_new => '注册新账号';

  @override
  String get auth_signup_toggle_old => '已有账号，去登录';

  @override
  String get auth_login_btn => '登录';

  @override
  String get auth_signup_btn => '注册';

  @override
  String get auth_anon_btn => '游客登录';

  @override
  String get auth_or => '或';

  @override
  String get auth_reset_title => '重置密码';

  @override
  String get auth_reset_sub => '输入你的邮箱，我们会发送重置链接';

  @override
  String get auth_reset_submit => '发送重置邮件';

  @override
  String get auth_reset_sent => '邮件已发送，请前往邮箱查看';

  @override
  String get auth_reset_failed => '发送失败';

  @override
  String get auth_signin_failed => '登录失败';

  @override
  String get auth_signup_failed => '注册失败';

  @override
  String get auth_anon_failed => '游客登录失败';

  @override
  String get rate_title => '赛后评分';

  @override
  String rate_progress(int cur, int total) {
    return '$cur/$total 人';
  }

  @override
  String get rate_comment_hint => '说点什么（选填）…';

  @override
  String get rate_skip => '跳过';

  @override
  String get rate_submit => '提交评分';

  @override
  String get rate_submit_all => '提交全部';

  @override
  String get rate_submitting => '提交中…';

  @override
  String get rate_done_title => '评分完成';

  @override
  String rate_done_sub(int n) {
    return '$n 位球员已评分';
  }

  @override
  String get rate_done_more => '再评一场';

  @override
  String get rate_done_back => '回到赛事';

  @override
  String get time_just_now => '刚刚';

  @override
  String time_minutes_ago(int n) {
    return '$n 分钟前';
  }

  @override
  String time_hours_ago(int n) {
    return '$n 小时前';
  }

  @override
  String time_days_ago(int n) {
    return '$n 天前';
  }

  @override
  String get time_yesterday => '昨天';

  @override
  String get home_status_open => '招人中';

  @override
  String get home_status_almost => '即将满员';

  @override
  String get home_status_full => '已满员';

  @override
  String home_need_n(int n) {
    return '缺 $n人';
  }

  @override
  String get home_full => '已满';

  @override
  String get home_join_cta => '一键报名 →';

  @override
  String get home_rate_banner_title => '给昨天的比赛打个分';

  @override
  String get home_rate_banner_sub => '龙岗村超 · 1/4决赛 · 9 位球员待评';

  @override
  String get home_host_pickup => '发起约球';

  @override
  String home_host_pickup_with_time(String time) {
    return '发起约球 · $time';
  }

  @override
  String get home_event_teaser => '赛事预告';

  @override
  String get home_event_registered_label => '已报名队伍';

  @override
  String get home_event_kickoff => '开赛';

  @override
  String get home_event_register_now => '立即报名 →';

  @override
  String get home_pickups_load_failed => '加载约球数据失败';

  @override
  String get home_tab_recommend => '推荐';

  @override
  String get home_tab_events => '赛事';

  @override
  String get home_tab_pickup => '约球';

  @override
  String get home_tab_discover => '发现';

  @override
  String get home_all_events => '全部赛事';

  @override
  String get home_events_live => '正在直播';

  @override
  String get home_events_registering => '报名中';

  @override
  String get home_events_ongoing => '进行中';

  @override
  String get home_events_upcoming => '即将开始';

  @override
  String get home_events_view => '查看';

  @override
  String get home_events_coming_soon => '敬请期待';

  @override
  String get home_events_register => '报名';

  @override
  String get home_pickup_filter_all => '全部';

  @override
  String get home_pickup_filter_distance => '距离';

  @override
  String get home_pickup_filter_today => '今天';

  @override
  String get home_pickup_filter_tomorrow => '明天';

  @override
  String get home_pickup_filter_week => '本周';

  @override
  String get home_pickup_filter_beginner => '初级';

  @override
  String get home_pickup_filter_intermediate => '中级';

  @override
  String get home_pickup_filter_advanced => '高级';

  @override
  String get home_pickup_slots_available => '名额充足';

  @override
  String get home_activity_matches => '局数';

  @override
  String get home_activity_record => '胜负';

  @override
  String get home_activity_duration => '时长';

  @override
  String home_article_read_time(int min) {
    return '$min分钟阅读';
  }

  @override
  String home_viewers_count(String count) {
    return '$count 观看';
  }

  @override
  String get home_discover_share => '分享';

  @override
  String get rate_panel_title => '赛后评分';

  @override
  String get rate_say_optional => '说两句 · 选填';

  @override
  String get rate_self_hint => '自评一下？';

  @override
  String get rate_other_hint => '说说他今天的表现…';

  @override
  String rate_voters_avg(int n) {
    return '$n 人已评 · 均分';
  }

  @override
  String get rate_prev => '上一位';

  @override
  String get rate_next => '下一位 →';

  @override
  String get rate_submit_score => '提交评分';

  @override
  String rate_submit_failed(String err) {
    return '提交失败：$err';
  }

  @override
  String get rate_short_you => '你';

  @override
  String get rate_level_bad => '拉跨';

  @override
  String get rate_level_meh => '一般';

  @override
  String get rate_level_good => '不错';

  @override
  String get rate_level_god => '封神';

  @override
  String get rate_done_header => '评分已提交';

  @override
  String rate_done_thanks_body(int n) {
    return '感谢你给 $n 位球员打了分。';
  }

  @override
  String get rate_done_view_leaderboard => '查看评分榜';

  @override
  String event_overview_main_visual(String name) {
    return '$name · 主视觉';
  }

  @override
  String get event_overview_rule_format => '11人制 · 标准场地';

  @override
  String get event_overview_rule_halves => '2 × 45min + 半场休息';

  @override
  String get event_overview_rule_subs => '5人换人名额，换下可回';

  @override
  String get event_overview_rule_cards => '红黄牌累积停赛';

  @override
  String get event_overview_organizer_label => '赛事组织方';

  @override
  String get event_bracket_waiting => '暂无赛程，等待组委会发布';

  @override
  String get event_standings_empty2 => '暂无比赛结果';

  @override
  String get event_chat_sender_you => '你';

  @override
  String get event_chat_sender_stranger => '球友';

  @override
  String get event_scorers_goals => '进球';

  @override
  String event_rating_n_voters_inline(int n) {
    return '$n人评';
  }

  @override
  String get event_rating_empty_go_rate => '还没有评分 · 去评赛后场次';

  @override
  String get event_rating_player_detail => '球员评分详情';

  @override
  String get event_prize_pending => '奖金待定';

  @override
  String event_prize_wan(String amount) {
    return '奖金 ¥$amount万';
  }

  @override
  String event_deadline_md_suffix(String md) {
    return '$md 截止';
  }

  @override
  String get event_row_teams_label => '报名队伍';

  @override
  String get event_row_status_label => '状态';

  @override
  String get player_card_rating => '评分';

  @override
  String get player_card_mp => '出场';

  @override
  String get team_card_summary => '战绩';

  @override
  String get team_card_gf => '进球';

  @override
  String get team_card_ga => '失球';

  @override
  String get team_card_gd => '净胜';

  @override
  String get team_card_matches => '比赛';

  @override
  String get wc_hero_title => '世界杯专区';

  @override
  String get wc_hero_sub => '小组赛 · 第 2 轮 · 今晚 5 场直播';

  @override
  String get wc_focus_battle => '焦点之战 · 直播中';

  @override
  String wc_focus_halftime(String minute) {
    return '$minute · 下半场';
  }

  @override
  String wc_focus_watch_count(String n) {
    return '$n 观看';
  }

  @override
  String get wc_team_argentina => '阿根廷';

  @override
  String get wc_team_brazil => '巴西';

  @override
  String get wc_team_argentina_win => '阿根廷胜';

  @override
  String get wc_team_draw => '平';

  @override
  String get wc_team_brazil_win => '巴西胜';

  @override
  String pickup_map_title_city(String city) {
    return '约球 · $city';
  }

  @override
  String get pickup_map_legend_open => '招人中';

  @override
  String get pickup_map_legend_almost => '即将满员';

  @override
  String get pickup_map_legend_full => '已满';

  @override
  String get pickup_map_sort_distance => '按距离排序';

  @override
  String pickup_map_need_short(int n) {
    return '缺$n';
  }

  @override
  String get pickup_map_full_short => '满';

  @override
  String get level_any => '不限';

  @override
  String get level_beginner => '新手';

  @override
  String get level_novice => '初级';

  @override
  String get level_mid => '中级';

  @override
  String get level_pro => '高级';

  @override
  String get field_5 => '5人制';

  @override
  String get field_7 => '7人制';

  @override
  String get field_8 => '8人制';

  @override
  String get field_11 => '11人制';

  @override
  String pickup_detail_open_need_n(int n) {
    return '招人中 · 缺 $n 人';
  }

  @override
  String pickup_detail_formation_title(String formation) {
    return '阵型 · $formation';
  }

  @override
  String pickup_detail_slots_filled_of(int total) {
    return '/$total 已到位';
  }

  @override
  String get pickup_detail_details => '详情';

  @override
  String get pickup_detail_detail_level => '水平要求';

  @override
  String get pickup_detail_detail_headcount => '人数';

  @override
  String get pickup_detail_detail_field => '场地';

  @override
  String get pickup_detail_detail_parking => '停车';

  @override
  String get pickup_detail_location => '位置';

  @override
  String pickup_detail_location_km(String km) {
    return '位置 · 距你 ${km}km';
  }

  @override
  String get pickup_detail_navigate => '导航';

  @override
  String get pickup_detail_nav_chooser_title => '选择导航应用';

  @override
  String get pickup_detail_nav_amap => '高德地图';

  @override
  String get pickup_detail_nav_baidu => '百度地图';

  @override
  String get pickup_detail_nav_system => '系统地图';

  @override
  String get pickup_detail_nav_none => '未找到可用的地图应用';

  @override
  String get pickup_detail_aa_fee => 'AA 费用';

  @override
  String get pickup_detail_not_signed_in => '未登录';

  @override
  String pickup_detail_join_failed(String err) {
    return '报名失败：$err';
  }

  @override
  String get pickup_detail_formation_load_failed => '阵型加载失败';

  @override
  String pickup_detail_host_stats(int n, int rate) {
    return '发起过 $n 场 · 准时率 $rate%';
  }

  @override
  String get messages_thread_default_title => '对话';

  @override
  String get messages_kind_group => '群聊';

  @override
  String get messages_kind_dm => '私信';

  @override
  String get chat_default_group_title => '开球 · 新手大厅';

  @override
  String get chat_sender_system => '系统';

  @override
  String get auth_guest_prefix => '游客-';

  @override
  String get auth_terms_notice => '继续即表示同意服务条款 · 隐私政策';

  @override
  String get create_event_tpl_group8_desc_inline => '2组4队 单循环 + 交叉淘汰';

  @override
  String get create_event_hint_not_logged => '请先登录';

  @override
  String create_event_preview_prize_wan(String amount) {
    return '¥$amount万';
  }

  @override
  String get rate_pitch_title => '给本局打分';

  @override
  String rate_pitch_progress(int done, int total) {
    return '$done/$total 已评';
  }

  @override
  String get rate_pitch_tap_hint => '点球员打分';

  @override
  String get rate_pitch_save_next => '保存 · 下一个';

  @override
  String rate_pitch_submit_n(int n) {
    return '提交 ($n)';
  }

  @override
  String get rate_pitch_cannot_self => '不能给自己打分';

  @override
  String get rate_pitch_empty_title => '还没有队友加入';

  @override
  String get rate_pitch_empty_sub => '等其他人报名后再来打分';

  @override
  String get rate_pitch_empty_back => '返回球局';

  @override
  String get rate_pitch_goals_label => '进球';

  @override
  String get rate_pitch_assists_label => '助攻';

  @override
  String get rate_pitch_pos_label => '位置';

  @override
  String get rate_pitch_not_registered => '未注册球友';

  @override
  String rate_pitch_submitted_n(int n) {
    return '已提交 $n 条评分';
  }

  @override
  String get rate_pitch_rate_teammates_cta => '给本局打分';

  @override
  String get match_detail_title => '比赛详情';

  @override
  String get match_status_upcoming => '未开始';

  @override
  String get match_status_live => '进行中';

  @override
  String get match_status_done => '已结束';

  @override
  String get match_goals_section => '进球';

  @override
  String get match_goals_empty => '暂无进球';

  @override
  String get match_cta_rate => '去评分';

  @override
  String get match_cta_view_ratings => '查看本场评分';

  @override
  String get match_cta_remind => '赛前提醒';

  @override
  String get match_cta_reminded => '已设置提醒';

  @override
  String get match_ratings_title => '本场评分';

  @override
  String get match_ratings_go_rate => '我也来评一下';

  @override
  String get match_own_goal => '乌龙';

  @override
  String get match_penalty => '点球';

  @override
  String match_assist_by(String name) {
    return '助攻 $name';
  }

  @override
  String get match_not_found => '未找到该比赛';

  @override
  String get event_standings_leaders_label => '榜首之争';

  @override
  String get event_standings_leader_top => '榜首';

  @override
  String get event_standings_leader_runner => '次席';

  @override
  String event_standings_points_diff(int n) {
    return '积分差 $n';
  }

  @override
  String get event_scorers_golden_boot => '金靴得主';

  @override
  String event_scorers_per_match(String avg) {
    return '场均 $avg 球';
  }

  @override
  String get messages_new_dm => '发起私聊';

  @override
  String get messages_new_dm_hint => '输入对方 @handle';

  @override
  String get messages_new_dm_not_found => '用户不存在';

  @override
  String get messages_new_dm_cant_self => '不能和自己私聊';

  @override
  String get pickup_map_location_disabled => '定位服务未开启';

  @override
  String get pickup_map_location_denied => '定位权限被拒绝，请在设置中开启';
}
