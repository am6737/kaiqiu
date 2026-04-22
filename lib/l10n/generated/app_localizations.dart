import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @app_name.
  ///
  /// In zh, this message translates to:
  /// **'开球'**
  String get app_name;

  /// No description provided for @tab_home.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tab_home;

  /// No description provided for @tab_pickup.
  ///
  /// In zh, this message translates to:
  /// **'约球'**
  String get tab_pickup;

  /// No description provided for @tab_events.
  ///
  /// In zh, this message translates to:
  /// **'赛事'**
  String get tab_events;

  /// No description provided for @tab_me.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tab_me;

  /// No description provided for @inbox_title.
  ///
  /// In zh, this message translates to:
  /// **'收件箱'**
  String get inbox_title;

  /// No description provided for @inbox_tab_messages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get inbox_tab_messages;

  /// No description provided for @inbox_tab_notifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get inbox_tab_notifications;

  /// No description provided for @common_back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get common_back;

  /// No description provided for @common_cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get common_cancel;

  /// No description provided for @common_confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get common_confirm;

  /// No description provided for @common_save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get common_save;

  /// No description provided for @common_submit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get common_submit;

  /// No description provided for @common_delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get common_delete;

  /// No description provided for @common_edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get common_edit;

  /// No description provided for @common_share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get common_share;

  /// No description provided for @common_close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get common_close;

  /// No description provided for @common_done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get common_done;

  /// No description provided for @common_retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get common_retry;

  /// No description provided for @common_loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get common_loading;

  /// No description provided for @common_next.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get common_next;

  /// No description provided for @common_prev.
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get common_prev;

  /// No description provided for @common_finish.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get common_finish;

  /// No description provided for @common_send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get common_send;

  /// No description provided for @common_search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get common_search;

  /// No description provided for @common_filter.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get common_filter;

  /// No description provided for @common_more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get common_more;

  /// No description provided for @common_new.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get common_new;

  /// No description provided for @common_yes.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get common_yes;

  /// No description provided for @common_no.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get common_no;

  /// No description provided for @common_required.
  ///
  /// In zh, this message translates to:
  /// **'必填'**
  String get common_required;

  /// No description provided for @common_optional.
  ///
  /// In zh, this message translates to:
  /// **'选填'**
  String get common_optional;

  /// No description provided for @common_default.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get common_default;

  /// No description provided for @common_follow.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get common_follow;

  /// No description provided for @common_unfollow.
  ///
  /// In zh, this message translates to:
  /// **'已关注'**
  String get common_unfollow;

  /// No description provided for @common_favorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get common_favorite;

  /// No description provided for @common_unfavorite.
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get common_unfavorite;

  /// No description provided for @common_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get common_all;

  /// No description provided for @common_today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get common_today;

  /// No description provided for @common_tomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天'**
  String get common_tomorrow;

  /// No description provided for @common_this_week.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get common_this_week;

  /// No description provided for @common_unread.
  ///
  /// In zh, this message translates to:
  /// **'未读'**
  String get common_unread;

  /// No description provided for @common_pin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get common_pin;

  /// No description provided for @common_unpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get common_unpin;

  /// No description provided for @common_mute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get common_mute;

  /// No description provided for @common_unmute.
  ///
  /// In zh, this message translates to:
  /// **'取消静音'**
  String get common_unmute;

  /// No description provided for @common_report.
  ///
  /// In zh, this message translates to:
  /// **'举报'**
  String get common_report;

  /// No description provided for @common_copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get common_copy;

  /// No description provided for @common_copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get common_copied;

  /// No description provided for @common_version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get common_version;

  /// No description provided for @error_load_failed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get error_load_failed;

  /// No description provided for @error_network.
  ///
  /// In zh, this message translates to:
  /// **'网络异常，请重试'**
  String get error_network;

  /// No description provided for @error_required_field.
  ///
  /// In zh, this message translates to:
  /// **'此项不能为空'**
  String get error_required_field;

  /// No description provided for @error_invalid_email.
  ///
  /// In zh, this message translates to:
  /// **'邮箱格式不正确'**
  String get error_invalid_email;

  /// No description provided for @error_password_too_short.
  ///
  /// In zh, this message translates to:
  /// **'密码至少 6 位'**
  String get error_password_too_short;

  /// No description provided for @error_not_integer.
  ///
  /// In zh, this message translates to:
  /// **'请输入整数'**
  String get error_not_integer;

  /// No description provided for @error_invalid_date.
  ///
  /// In zh, this message translates to:
  /// **'日期格式不正确（YYYY-MM-DD）'**
  String get error_invalid_date;

  /// No description provided for @error_please_login.
  ///
  /// In zh, this message translates to:
  /// **'请先登录'**
  String get error_please_login;

  /// No description provided for @error_unknown.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get error_unknown;

  /// No description provided for @empty_no_data.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get empty_no_data;

  /// No description provided for @empty_no_events.
  ///
  /// In zh, this message translates to:
  /// **'暂无赛事'**
  String get empty_no_events;

  /// No description provided for @empty_no_events_sub.
  ///
  /// In zh, this message translates to:
  /// **'点右上角创建赛事发起一个'**
  String get empty_no_events_sub;

  /// No description provided for @empty_no_pickups.
  ///
  /// In zh, this message translates to:
  /// **'暂无球局'**
  String get empty_no_pickups;

  /// No description provided for @empty_no_pickups_sub.
  ///
  /// In zh, this message translates to:
  /// **'试试调整筛选条件，或发起一个新球局'**
  String get empty_no_pickups_sub;

  /// No description provided for @empty_no_messages.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息'**
  String get empty_no_messages;

  /// No description provided for @empty_no_messages_sub.
  ///
  /// In zh, this message translates to:
  /// **'去约球或赛事页发现更多同好'**
  String get empty_no_messages_sub;

  /// No description provided for @empty_no_favorites.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏'**
  String get empty_no_favorites;

  /// No description provided for @empty_no_favorites_sub.
  ///
  /// In zh, this message translates to:
  /// **'看到喜欢的球局或赛事，点击收藏按钮加入'**
  String get empty_no_favorites_sub;

  /// No description provided for @empty_no_teams.
  ///
  /// In zh, this message translates to:
  /// **'还没有队伍'**
  String get empty_no_teams;

  /// No description provided for @empty_no_teams_sub.
  ///
  /// In zh, this message translates to:
  /// **'创建你的第一支球队'**
  String get empty_no_teams_sub;

  /// No description provided for @empty_no_notifications.
  ///
  /// In zh, this message translates to:
  /// **'暂无通知'**
  String get empty_no_notifications;

  /// No description provided for @empty_no_search.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配结果'**
  String get empty_no_search;

  /// No description provided for @empty_no_rating.
  ///
  /// In zh, this message translates to:
  /// **'还没有评分'**
  String get empty_no_rating;

  /// No description provided for @empty_no_rating_sub.
  ///
  /// In zh, this message translates to:
  /// **'去评一场最近的比赛'**
  String get empty_no_rating_sub;

  /// No description provided for @home_live_now.
  ///
  /// In zh, this message translates to:
  /// **'正在直播'**
  String get home_live_now;

  /// No description provided for @home_view_all.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get home_view_all;

  /// No description provided for @home_local_feed.
  ///
  /// In zh, this message translates to:
  /// **'同城动态'**
  String get home_local_feed;

  /// No description provided for @home_feed_pickup.
  ///
  /// In zh, this message translates to:
  /// **'约球'**
  String get home_feed_pickup;

  /// No description provided for @home_feed_result.
  ///
  /// In zh, this message translates to:
  /// **'战报'**
  String get home_feed_result;

  /// No description provided for @home_feed_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get home_feed_all;

  /// No description provided for @home_rate_cta_title.
  ///
  /// In zh, this message translates to:
  /// **'你有待评价的比赛'**
  String get home_rate_cta_title;

  /// No description provided for @home_rate_cta_sub.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =0{暂无} other{{count} 位队友等你评分}}'**
  String home_rate_cta_sub(int count);

  /// No description provided for @home_no_live.
  ///
  /// In zh, this message translates to:
  /// **'暂无直播比赛'**
  String get home_no_live;

  /// No description provided for @home_bottom_of_feed.
  ///
  /// In zh, this message translates to:
  /// **'— 到底了 · 今天也是踢球的一天 —'**
  String get home_bottom_of_feed;

  /// No description provided for @home_loading_pickups.
  ///
  /// In zh, this message translates to:
  /// **'正在加载球局…'**
  String get home_loading_pickups;

  /// No description provided for @sport_football.
  ///
  /// In zh, this message translates to:
  /// **'足球'**
  String get sport_football;

  /// No description provided for @sport_basketball.
  ///
  /// In zh, this message translates to:
  /// **'篮球'**
  String get sport_basketball;

  /// No description provided for @sport_badminton.
  ///
  /// In zh, this message translates to:
  /// **'羽毛球'**
  String get sport_badminton;

  /// No description provided for @sport_pingpong.
  ///
  /// In zh, this message translates to:
  /// **'乒乓球'**
  String get sport_pingpong;

  /// No description provided for @sport_cycling.
  ///
  /// In zh, this message translates to:
  /// **'骑行'**
  String get sport_cycling;

  /// No description provided for @pickup_title.
  ///
  /// In zh, this message translates to:
  /// **'约球 · {city}'**
  String pickup_title(String city);

  /// No description provided for @pickup_filter_today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get pickup_filter_today;

  /// No description provided for @pickup_filter_tomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天'**
  String get pickup_filter_tomorrow;

  /// No description provided for @pickup_filter_week.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get pickup_filter_week;

  /// No description provided for @pickup_filter_mid.
  ///
  /// In zh, this message translates to:
  /// **'中级'**
  String get pickup_filter_mid;

  /// No description provided for @pickup_filter_cheap.
  ///
  /// In zh, this message translates to:
  /// **'¥ ≤50'**
  String get pickup_filter_cheap;

  /// No description provided for @pickup_filter_near.
  ///
  /// In zh, this message translates to:
  /// **'3km内'**
  String get pickup_filter_near;

  /// No description provided for @pickup_filter_title.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get pickup_filter_title;

  /// No description provided for @pickup_filter_distance.
  ///
  /// In zh, this message translates to:
  /// **'距离'**
  String get pickup_filter_distance;

  /// No description provided for @pickup_filter_fee.
  ///
  /// In zh, this message translates to:
  /// **'费用'**
  String get pickup_filter_fee;

  /// No description provided for @pickup_filter_level.
  ///
  /// In zh, this message translates to:
  /// **'等级'**
  String get pickup_filter_level;

  /// No description provided for @pickup_filter_time.
  ///
  /// In zh, this message translates to:
  /// **'时段'**
  String get pickup_filter_time;

  /// No description provided for @pickup_filter_apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get pickup_filter_apply;

  /// No description provided for @pickup_filter_reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get pickup_filter_reset;

  /// No description provided for @pickup_status_open.
  ///
  /// In zh, this message translates to:
  /// **'招人中'**
  String get pickup_status_open;

  /// No description provided for @pickup_status_almost.
  ///
  /// In zh, this message translates to:
  /// **'即将满员'**
  String get pickup_status_almost;

  /// No description provided for @pickup_status_full.
  ///
  /// In zh, this message translates to:
  /// **'已满'**
  String get pickup_status_full;

  /// No description provided for @pickup_city_pickup_count.
  ///
  /// In zh, this message translates to:
  /// **'同城 {n} 个球局'**
  String pickup_city_pickup_count(int n);

  /// No description provided for @pickup_sort_by_distance.
  ///
  /// In zh, this message translates to:
  /// **'按距离排序'**
  String get pickup_sort_by_distance;

  /// No description provided for @pickup_need_n.
  ///
  /// In zh, this message translates to:
  /// **'缺{n}'**
  String pickup_need_n(int n);

  /// No description provided for @pickup_detail_organizer.
  ///
  /// In zh, this message translates to:
  /// **'组织者'**
  String get pickup_detail_organizer;

  /// No description provided for @pickup_detail_formation.
  ///
  /// In zh, this message translates to:
  /// **'阵型图'**
  String get pickup_detail_formation;

  /// No description provided for @pickup_detail_match_info.
  ///
  /// In zh, this message translates to:
  /// **'比赛详情'**
  String get pickup_detail_match_info;

  /// No description provided for @pickup_detail_fee.
  ///
  /// In zh, this message translates to:
  /// **'费用'**
  String get pickup_detail_fee;

  /// No description provided for @pickup_detail_duration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get pickup_detail_duration;

  /// No description provided for @pickup_detail_level.
  ///
  /// In zh, this message translates to:
  /// **'等级'**
  String get pickup_detail_level;

  /// No description provided for @pickup_detail_field_type.
  ///
  /// In zh, this message translates to:
  /// **'场地类型'**
  String get pickup_detail_field_type;

  /// No description provided for @pickup_detail_join_cta.
  ///
  /// In zh, this message translates to:
  /// **'一键报名'**
  String get pickup_detail_join_cta;

  /// No description provided for @pickup_detail_select_position.
  ///
  /// In zh, this message translates to:
  /// **'选位置报名'**
  String get pickup_detail_select_position;

  /// No description provided for @pickup_detail_already_joined.
  ///
  /// In zh, this message translates to:
  /// **'已报名'**
  String get pickup_detail_already_joined;

  /// No description provided for @pickup_detail_full_cta.
  ///
  /// In zh, this message translates to:
  /// **'已满员'**
  String get pickup_detail_full_cta;

  /// No description provided for @pickup_detail_tap_empty_slot.
  ///
  /// In zh, this message translates to:
  /// **'点击阵型图上任一空位选择位置'**
  String get pickup_detail_tap_empty_slot;

  /// No description provided for @pickup_detail_contact_organizer.
  ///
  /// In zh, this message translates to:
  /// **'联系组织者'**
  String get pickup_detail_contact_organizer;

  /// No description provided for @pickup_create_title.
  ///
  /// In zh, this message translates to:
  /// **'发起约球'**
  String get pickup_create_title;

  /// No description provided for @pickup_create_venue.
  ///
  /// In zh, this message translates to:
  /// **'场地'**
  String get pickup_create_venue;

  /// No description provided for @pickup_create_address.
  ///
  /// In zh, this message translates to:
  /// **'详细地址（可选）'**
  String get pickup_create_address;

  /// No description provided for @pickup_create_address_hint.
  ///
  /// In zh, this message translates to:
  /// **'街道门牌号，便于队友导航'**
  String get pickup_create_address_hint;

  /// No description provided for @pickup_create_start_at.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get pickup_create_start_at;

  /// No description provided for @pickup_create_duration_min.
  ///
  /// In zh, this message translates to:
  /// **'时长（分钟）'**
  String get pickup_create_duration_min;

  /// No description provided for @pickup_create_total.
  ///
  /// In zh, this message translates to:
  /// **'总人数'**
  String get pickup_create_total;

  /// No description provided for @pickup_create_fee.
  ///
  /// In zh, this message translates to:
  /// **'费用（元）'**
  String get pickup_create_fee;

  /// No description provided for @pickup_create_level.
  ///
  /// In zh, this message translates to:
  /// **'等级'**
  String get pickup_create_level;

  /// No description provided for @pickup_create_formation.
  ///
  /// In zh, this message translates to:
  /// **'阵型'**
  String get pickup_create_formation;

  /// No description provided for @pickup_create_field_type.
  ///
  /// In zh, this message translates to:
  /// **'场地类型'**
  String get pickup_create_field_type;

  /// No description provided for @pickup_create_submit.
  ///
  /// In zh, this message translates to:
  /// **'发布约球'**
  String get pickup_create_submit;

  /// No description provided for @pickup_create_success.
  ///
  /// In zh, this message translates to:
  /// **'球局已发布'**
  String get pickup_create_success;

  /// No description provided for @events_title.
  ///
  /// In zh, this message translates to:
  /// **'赛事'**
  String get events_title;

  /// No description provided for @events_create.
  ///
  /// In zh, this message translates to:
  /// **'创建赛事'**
  String get events_create;

  /// No description provided for @events_tab_ongoing.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get events_tab_ongoing;

  /// No description provided for @events_tab_registering.
  ///
  /// In zh, this message translates to:
  /// **'报名中'**
  String get events_tab_registering;

  /// No description provided for @events_tab_watch.
  ///
  /// In zh, this message translates to:
  /// **'观看'**
  String get events_tab_watch;

  /// No description provided for @events_watch_today.
  ///
  /// In zh, this message translates to:
  /// **'今日赛程 · 你关注的'**
  String get events_watch_today;

  /// No description provided for @events_wc_banner_title.
  ///
  /// In zh, this message translates to:
  /// **'2026 FIFA 世界杯专区'**
  String get events_wc_banner_title;

  /// No description provided for @events_wc_banner_sub.
  ///
  /// In zh, this message translates to:
  /// **'小组赛第 2 轮 · 今晚 5 场同步直播'**
  String get events_wc_banner_sub;

  /// No description provided for @events_wc_live_now.
  ///
  /// In zh, this message translates to:
  /// **'正在直播'**
  String get events_wc_live_now;

  /// No description provided for @events_wc_predicts.
  ///
  /// In zh, this message translates to:
  /// **'同城竞猜'**
  String get events_wc_predicts;

  /// No description provided for @events_pro.
  ///
  /// In zh, this message translates to:
  /// **'职业赛事'**
  String get events_pro;

  /// No description provided for @event_status_ongoing.
  ///
  /// In zh, this message translates to:
  /// **'正在进行'**
  String get event_status_ongoing;

  /// No description provided for @event_status_registering.
  ///
  /// In zh, this message translates to:
  /// **'报名中'**
  String get event_status_registering;

  /// No description provided for @event_status_done.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get event_status_done;

  /// No description provided for @event_kpi_teams.
  ///
  /// In zh, this message translates to:
  /// **'队伍'**
  String get event_kpi_teams;

  /// No description provided for @event_kpi_matches.
  ///
  /// In zh, this message translates to:
  /// **'场次'**
  String get event_kpi_matches;

  /// No description provided for @event_kpi_prize.
  ///
  /// In zh, this message translates to:
  /// **'奖金'**
  String get event_kpi_prize;

  /// No description provided for @event_kpi_viewers.
  ///
  /// In zh, this message translates to:
  /// **'观众'**
  String get event_kpi_viewers;

  /// No description provided for @event_tab_overview.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get event_tab_overview;

  /// No description provided for @event_tab_bracket.
  ///
  /// In zh, this message translates to:
  /// **'赛程'**
  String get event_tab_bracket;

  /// No description provided for @event_tab_standings.
  ///
  /// In zh, this message translates to:
  /// **'积分榜'**
  String get event_tab_standings;

  /// No description provided for @event_tab_scorers.
  ///
  /// In zh, this message translates to:
  /// **'射手榜'**
  String get event_tab_scorers;

  /// No description provided for @event_tab_ratings.
  ///
  /// In zh, this message translates to:
  /// **'评分榜'**
  String get event_tab_ratings;

  /// No description provided for @event_tab_chat.
  ///
  /// In zh, this message translates to:
  /// **'讨论'**
  String get event_tab_chat;

  /// No description provided for @event_overview_rules.
  ///
  /// In zh, this message translates to:
  /// **'规则'**
  String get event_overview_rules;

  /// No description provided for @event_overview_organizer.
  ///
  /// In zh, this message translates to:
  /// **'组织方'**
  String get event_overview_organizer;

  /// No description provided for @event_bracket_qf.
  ///
  /// In zh, this message translates to:
  /// **'1/4 决赛'**
  String get event_bracket_qf;

  /// No description provided for @event_bracket_sf.
  ///
  /// In zh, this message translates to:
  /// **'半决赛'**
  String get event_bracket_sf;

  /// No description provided for @event_bracket_final.
  ///
  /// In zh, this message translates to:
  /// **'决赛'**
  String get event_bracket_final;

  /// No description provided for @event_bracket_champion.
  ///
  /// In zh, this message translates to:
  /// **'冠军'**
  String get event_bracket_champion;

  /// No description provided for @event_bracket_tbd.
  ///
  /// In zh, this message translates to:
  /// **'TBD'**
  String get event_bracket_tbd;

  /// No description provided for @event_bracket_empty.
  ///
  /// In zh, this message translates to:
  /// **'暂无赛程，等待组委会发布'**
  String get event_bracket_empty;

  /// No description provided for @event_standings_rank.
  ///
  /// In zh, this message translates to:
  /// **'#'**
  String get event_standings_rank;

  /// No description provided for @event_standings_team.
  ///
  /// In zh, this message translates to:
  /// **'队伍'**
  String get event_standings_team;

  /// No description provided for @event_standings_wins.
  ///
  /// In zh, this message translates to:
  /// **'胜'**
  String get event_standings_wins;

  /// No description provided for @event_standings_draws.
  ///
  /// In zh, this message translates to:
  /// **'平'**
  String get event_standings_draws;

  /// No description provided for @event_standings_losses.
  ///
  /// In zh, this message translates to:
  /// **'负'**
  String get event_standings_losses;

  /// No description provided for @event_standings_points.
  ///
  /// In zh, this message translates to:
  /// **'积分'**
  String get event_standings_points;

  /// No description provided for @event_standings_empty.
  ///
  /// In zh, this message translates to:
  /// **'暂无比赛结果'**
  String get event_standings_empty;

  /// No description provided for @event_cta_watch_live.
  ///
  /// In zh, this message translates to:
  /// **'观看直播'**
  String get event_cta_watch_live;

  /// No description provided for @event_cta_register.
  ///
  /// In zh, this message translates to:
  /// **'报名参赛'**
  String get event_cta_register;

  /// No description provided for @event_cta_registered.
  ///
  /// In zh, this message translates to:
  /// **'已报名'**
  String get event_cta_registered;

  /// No description provided for @event_chat_hint.
  ///
  /// In zh, this message translates to:
  /// **'发条弹幕…'**
  String get event_chat_hint;

  /// No description provided for @event_chat_send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get event_chat_send;

  /// No description provided for @event_register_form_title.
  ///
  /// In zh, this message translates to:
  /// **'报名参赛'**
  String get event_register_form_title;

  /// No description provided for @event_register_team_name.
  ///
  /// In zh, this message translates to:
  /// **'队伍名'**
  String get event_register_team_name;

  /// No description provided for @event_register_contact.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get event_register_contact;

  /// No description provided for @event_register_phone.
  ///
  /// In zh, this message translates to:
  /// **'电话'**
  String get event_register_phone;

  /// No description provided for @event_register_submit.
  ///
  /// In zh, this message translates to:
  /// **'提交报名'**
  String get event_register_submit;

  /// No description provided for @event_register_success.
  ///
  /// In zh, this message translates to:
  /// **'报名已提交，等待组委会审核'**
  String get event_register_success;

  /// No description provided for @event_rating_team_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get event_rating_team_all;

  /// No description provided for @event_rating_mvp.
  ///
  /// In zh, this message translates to:
  /// **'MVP'**
  String get event_rating_mvp;

  /// No description provided for @event_rating_tap_for_detail.
  ///
  /// In zh, this message translates to:
  /// **'· 点击球员查看评分详情 ·'**
  String get event_rating_tap_for_detail;

  /// No description provided for @event_rating_players_voted.
  ///
  /// In zh, this message translates to:
  /// **'{n} 人参与评分'**
  String event_rating_players_voted(int n);

  /// No description provided for @event_rating_score_avg.
  ///
  /// In zh, this message translates to:
  /// **'均分'**
  String get event_rating_score_avg;

  /// No description provided for @event_rating_distribution.
  ///
  /// In zh, this message translates to:
  /// **'评分分布 · 样例'**
  String get event_rating_distribution;

  /// No description provided for @event_rating_hot_comments.
  ///
  /// In zh, this message translates to:
  /// **'热门评论 · 样例'**
  String get event_rating_hot_comments;

  /// No description provided for @event_rating_sort_hot.
  ///
  /// In zh, this message translates to:
  /// **'按热度排序'**
  String get event_rating_sort_hot;

  /// No description provided for @event_rating_reply.
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get event_rating_reply;

  /// No description provided for @create_event_title.
  ///
  /// In zh, this message translates to:
  /// **'创建赛事'**
  String get create_event_title;

  /// No description provided for @create_event_step_n_of.
  ///
  /// In zh, this message translates to:
  /// **'第 {cur} 步 · 共 {total} 步'**
  String create_event_step_n_of(int cur, int total);

  /// No description provided for @create_event_step_template.
  ///
  /// In zh, this message translates to:
  /// **'赛事模板'**
  String get create_event_step_template;

  /// No description provided for @create_event_step_basic.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get create_event_step_basic;

  /// No description provided for @create_event_step_registration.
  ///
  /// In zh, this message translates to:
  /// **'报名设置'**
  String get create_event_step_registration;

  /// No description provided for @create_event_step_preview.
  ///
  /// In zh, this message translates to:
  /// **'发布预览'**
  String get create_event_step_preview;

  /// No description provided for @create_event_tpl_title.
  ///
  /// In zh, this message translates to:
  /// **'选择赛事模板'**
  String get create_event_tpl_title;

  /// No description provided for @create_event_tpl_subtitle.
  ///
  /// In zh, this message translates to:
  /// **'模板决定赛程结构，稍后可调整'**
  String get create_event_tpl_subtitle;

  /// No description provided for @create_event_tpl_group8.
  ///
  /// In zh, this message translates to:
  /// **'8队小组赛'**
  String get create_event_tpl_group8;

  /// No description provided for @create_event_tpl_group8_desc.
  ///
  /// In zh, this message translates to:
  /// **'2组4队 单循环 + 交叉淘汰'**
  String get create_event_tpl_group8_desc;

  /// No description provided for @create_event_tpl_knockout16.
  ///
  /// In zh, this message translates to:
  /// **'16队淘汰赛'**
  String get create_event_tpl_knockout16;

  /// No description provided for @create_event_tpl_knockout16_desc.
  ///
  /// In zh, this message translates to:
  /// **'单败淘汰 4 轮决出冠军'**
  String get create_event_tpl_knockout16_desc;

  /// No description provided for @create_event_tpl_wc.
  ///
  /// In zh, this message translates to:
  /// **'世界杯赛制'**
  String get create_event_tpl_wc;

  /// No description provided for @create_event_tpl_wc_desc.
  ///
  /// In zh, this message translates to:
  /// **'32队 8小组 + 淘汰赛'**
  String get create_event_tpl_wc_desc;

  /// No description provided for @create_event_tpl_league.
  ///
  /// In zh, this message translates to:
  /// **'联赛赛制'**
  String get create_event_tpl_league;

  /// No description provided for @create_event_tpl_league_desc.
  ///
  /// In zh, this message translates to:
  /// **'主客场双循环积分制'**
  String get create_event_tpl_league_desc;

  /// No description provided for @create_event_f_name.
  ///
  /// In zh, this message translates to:
  /// **'赛事名称'**
  String get create_event_f_name;

  /// No description provided for @create_event_f_start.
  ///
  /// In zh, this message translates to:
  /// **'开赛日期'**
  String get create_event_f_start;

  /// No description provided for @create_event_f_end.
  ///
  /// In zh, this message translates to:
  /// **'结束日期'**
  String get create_event_f_end;

  /// No description provided for @create_event_f_venue.
  ///
  /// In zh, this message translates to:
  /// **'场地'**
  String get create_event_f_venue;

  /// No description provided for @create_event_f_fee.
  ///
  /// In zh, this message translates to:
  /// **'报名费(每队)'**
  String get create_event_f_fee;

  /// No description provided for @create_event_f_prize.
  ///
  /// In zh, this message translates to:
  /// **'总奖金'**
  String get create_event_f_prize;

  /// No description provided for @create_event_f_deadline.
  ///
  /// In zh, this message translates to:
  /// **'报名截止'**
  String get create_event_f_deadline;

  /// No description provided for @create_event_f_teamsize.
  ///
  /// In zh, this message translates to:
  /// **'每队人数'**
  String get create_event_f_teamsize;

  /// No description provided for @create_event_f_maxteams.
  ///
  /// In zh, this message translates to:
  /// **'队伍上限'**
  String get create_event_f_maxteams;

  /// No description provided for @create_event_review_title.
  ///
  /// In zh, this message translates to:
  /// **'审核方式'**
  String get create_event_review_title;

  /// No description provided for @create_event_review_auto.
  ///
  /// In zh, this message translates to:
  /// **'自动通过'**
  String get create_event_review_auto;

  /// No description provided for @create_event_review_manual.
  ///
  /// In zh, this message translates to:
  /// **'组委会审核'**
  String get create_event_review_manual;

  /// No description provided for @create_event_organizer_tip_title.
  ///
  /// In zh, this message translates to:
  /// **'组织者提示'**
  String get create_event_organizer_tip_title;

  /// No description provided for @create_event_organizer_tip_body.
  ///
  /// In zh, this message translates to:
  /// **'建议保留至少 3 天审核期以便处理队伍资料。开赛后无法修改赛事配置。'**
  String get create_event_organizer_tip_body;

  /// No description provided for @create_event_preview_subtitle.
  ///
  /// In zh, this message translates to:
  /// **'确认无误后即可发布，队伍可以开始报名'**
  String get create_event_preview_subtitle;

  /// No description provided for @create_event_preview_config_ok.
  ///
  /// In zh, this message translates to:
  /// **'配置完整，可以发布'**
  String get create_event_preview_config_ok;

  /// No description provided for @create_event_cta_next.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get create_event_cta_next;

  /// No description provided for @create_event_cta_prev.
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get create_event_cta_prev;

  /// No description provided for @create_event_cta_publish.
  ///
  /// In zh, this message translates to:
  /// **'发布赛事'**
  String get create_event_cta_publish;

  /// No description provided for @create_event_cta_publishing.
  ///
  /// In zh, this message translates to:
  /// **'发布中…'**
  String get create_event_cta_publishing;

  /// No description provided for @create_event_save_draft.
  ///
  /// In zh, this message translates to:
  /// **'保存草稿'**
  String get create_event_save_draft;

  /// No description provided for @create_event_draft_saved.
  ///
  /// In zh, this message translates to:
  /// **'草稿已保存'**
  String get create_event_draft_saved;

  /// No description provided for @create_event_draft_loaded.
  ///
  /// In zh, this message translates to:
  /// **'已加载上次的草稿'**
  String get create_event_draft_loaded;

  /// No description provided for @create_event_published.
  ///
  /// In zh, this message translates to:
  /// **'赛事已发布'**
  String get create_event_published;

  /// No description provided for @create_event_publish_failed.
  ///
  /// In zh, this message translates to:
  /// **'发布失败：{err}'**
  String create_event_publish_failed(String err);

  /// No description provided for @create_event_preview_registered_of_max.
  ///
  /// In zh, this message translates to:
  /// **'0/{max} 已报名 · 截止 {deadline}'**
  String create_event_preview_registered_of_max(String max, String deadline);

  /// No description provided for @wc_title.
  ///
  /// In zh, this message translates to:
  /// **'世界杯专区'**
  String get wc_title;

  /// No description provided for @wc_subtitle.
  ///
  /// In zh, this message translates to:
  /// **'小组赛 · 第 2 轮 · 今晚 5 场直播'**
  String get wc_subtitle;

  /// No description provided for @wc_focus.
  ///
  /// In zh, this message translates to:
  /// **'焦点之战 · 直播中'**
  String get wc_focus;

  /// No description provided for @wc_viewers.
  ///
  /// In zh, this message translates to:
  /// **'{v} 观看'**
  String wc_viewers(String v);

  /// No description provided for @wc_predict_bar_title.
  ///
  /// In zh, this message translates to:
  /// **'你的球友竞猜 · 胜平负'**
  String get wc_predict_bar_title;

  /// No description provided for @wc_today_schedule.
  ///
  /// In zh, this message translates to:
  /// **'今日赛程'**
  String get wc_today_schedule;

  /// No description provided for @wc_btn_watch_live.
  ///
  /// In zh, this message translates to:
  /// **'观看直播'**
  String get wc_btn_watch_live;

  /// No description provided for @wc_btn_predict.
  ///
  /// In zh, this message translates to:
  /// **'竞猜'**
  String get wc_btn_predict;

  /// No description provided for @wc_btn_remind.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get wc_btn_remind;

  /// No description provided for @wc_btn_danmaku_on.
  ///
  /// In zh, this message translates to:
  /// **'弹幕 开'**
  String get wc_btn_danmaku_on;

  /// No description provided for @wc_btn_danmaku_off.
  ///
  /// In zh, this message translates to:
  /// **'弹幕 关'**
  String get wc_btn_danmaku_off;

  /// No description provided for @wc_remind_set.
  ///
  /// In zh, this message translates to:
  /// **'已设置提醒，比赛开始前 10 分钟通知你'**
  String get wc_remind_set;

  /// No description provided for @wc_remind_unset.
  ///
  /// In zh, this message translates to:
  /// **'已取消提醒'**
  String get wc_remind_unset;

  /// No description provided for @wc_remind_sheet_title.
  ///
  /// In zh, this message translates to:
  /// **'赛前提醒'**
  String get wc_remind_sheet_title;

  /// No description provided for @wc_remind_sheet_sub.
  ///
  /// In zh, this message translates to:
  /// **'提前多久提醒你？'**
  String get wc_remind_sheet_sub;

  /// No description provided for @wc_remind_option_min.
  ///
  /// In zh, this message translates to:
  /// **'{n} 分钟'**
  String wc_remind_option_min(int n);

  /// No description provided for @wc_remind_option_hour.
  ///
  /// In zh, this message translates to:
  /// **'{n} 小时'**
  String wc_remind_option_hour(int n);

  /// No description provided for @wc_remind_cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消提醒'**
  String get wc_remind_cancel;

  /// No description provided for @wc_remind_set_n_min.
  ///
  /// In zh, this message translates to:
  /// **'已设置提醒，比赛开始前 {n} 分钟通知你'**
  String wc_remind_set_n_min(int n);

  /// No description provided for @wc_remind_default_badge.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get wc_remind_default_badge;

  /// No description provided for @wc_live_title.
  ///
  /// In zh, this message translates to:
  /// **'直播中'**
  String get wc_live_title;

  /// No description provided for @wc_live_input_hint.
  ///
  /// In zh, this message translates to:
  /// **'发一条弹幕…'**
  String get wc_live_input_hint;

  /// No description provided for @wc_live_viewer_count.
  ///
  /// In zh, this message translates to:
  /// **'{n} 人观看'**
  String wc_live_viewer_count(String n);

  /// No description provided for @wc_live_back_to_feed.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get wc_live_back_to_feed;

  /// No description provided for @wc_live_half_time.
  ///
  /// In zh, this message translates to:
  /// **'下半场'**
  String get wc_live_half_time;

  /// No description provided for @wc_live_comment_ph.
  ///
  /// In zh, this message translates to:
  /// **'赛况如何？发弹幕讨论'**
  String get wc_live_comment_ph;

  /// No description provided for @wc_live_loading.
  ///
  /// In zh, this message translates to:
  /// **'正在连接直播…'**
  String get wc_live_loading;

  /// No description provided for @wc_live_signal_weak.
  ///
  /// In zh, this message translates to:
  /// **'直播信号弱'**
  String get wc_live_signal_weak;

  /// No description provided for @wc_live_tap_retry.
  ///
  /// In zh, this message translates to:
  /// **'点击重试'**
  String get wc_live_tap_retry;

  /// No description provided for @wc_live_score_overlay.
  ///
  /// In zh, this message translates to:
  /// **'{home} {sa} - {sb} {away} · {min}\''**
  String wc_live_score_overlay(
    String home,
    String sa,
    String sb,
    String away,
    String min,
  );

  /// No description provided for @wc_predict_title.
  ///
  /// In zh, this message translates to:
  /// **'竞猜'**
  String get wc_predict_title;

  /// No description provided for @wc_predict_pick_title.
  ///
  /// In zh, this message translates to:
  /// **'你看好谁？'**
  String get wc_predict_pick_title;

  /// No description provided for @wc_predict_home_win.
  ///
  /// In zh, this message translates to:
  /// **'主队胜'**
  String get wc_predict_home_win;

  /// No description provided for @wc_predict_draw.
  ///
  /// In zh, this message translates to:
  /// **'平局'**
  String get wc_predict_draw;

  /// No description provided for @wc_predict_away_win.
  ///
  /// In zh, this message translates to:
  /// **'客队胜'**
  String get wc_predict_away_win;

  /// No description provided for @wc_predict_stake.
  ///
  /// In zh, this message translates to:
  /// **'下注积分'**
  String get wc_predict_stake;

  /// No description provided for @wc_predict_submit.
  ///
  /// In zh, this message translates to:
  /// **'提交竞猜'**
  String get wc_predict_submit;

  /// No description provided for @wc_predict_submitted.
  ///
  /// In zh, this message translates to:
  /// **'已提交 · 赛后结算'**
  String get wc_predict_submitted;

  /// No description provided for @wc_predict_change.
  ///
  /// In zh, this message translates to:
  /// **'已选：{choice}'**
  String wc_predict_change(String choice);

  /// No description provided for @wc_predict_distribution.
  ///
  /// In zh, this message translates to:
  /// **'全站竞猜分布'**
  String get wc_predict_distribution;

  /// No description provided for @wc_predict_you_picked.
  ///
  /// In zh, this message translates to:
  /// **'你的选择'**
  String get wc_predict_you_picked;

  /// No description provided for @messages_title.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messages_title;

  /// No description provided for @messages_empty_title.
  ///
  /// In zh, this message translates to:
  /// **'暂无对话'**
  String get messages_empty_title;

  /// No description provided for @messages_empty_sub.
  ///
  /// In zh, this message translates to:
  /// **'去约球或赛事里，发现更多同城球友'**
  String get messages_empty_sub;

  /// No description provided for @messages_new_sheet_title.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get messages_new_sheet_title;

  /// No description provided for @messages_new_group.
  ///
  /// In zh, this message translates to:
  /// **'新建群聊'**
  String get messages_new_group;

  /// No description provided for @messages_new_group_title_hint.
  ///
  /// In zh, this message translates to:
  /// **'群聊名称'**
  String get messages_new_group_title_hint;

  /// No description provided for @messages_new_created.
  ///
  /// In zh, this message translates to:
  /// **'已创建对话'**
  String get messages_new_created;

  /// No description provided for @messages_new_failed.
  ///
  /// In zh, this message translates to:
  /// **'创建失败'**
  String get messages_new_failed;

  /// No description provided for @messages_long_press_actions_mark_read.
  ///
  /// In zh, this message translates to:
  /// **'标记为已读'**
  String get messages_long_press_actions_mark_read;

  /// No description provided for @messages_long_press_actions_mark_unread.
  ///
  /// In zh, this message translates to:
  /// **'标记为未读'**
  String get messages_long_press_actions_mark_unread;

  /// No description provided for @messages_long_press_actions_delete.
  ///
  /// In zh, this message translates to:
  /// **'删除对话'**
  String get messages_long_press_actions_delete;

  /// No description provided for @messages_delete_confirm.
  ///
  /// In zh, this message translates to:
  /// **'删除此对话？'**
  String get messages_delete_confirm;

  /// No description provided for @messages_deleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get messages_deleted;

  /// No description provided for @chat_hint.
  ///
  /// In zh, this message translates to:
  /// **'说点什么…'**
  String get chat_hint;

  /// No description provided for @chat_send_failed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败'**
  String get chat_send_failed;

  /// No description provided for @chat_attachment_image.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get chat_attachment_image;

  /// No description provided for @chat_attachment_location.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get chat_attachment_location;

  /// No description provided for @chat_attachment_invite.
  ///
  /// In zh, this message translates to:
  /// **'约球邀请'**
  String get chat_attachment_invite;

  /// No description provided for @chat_attachment_system_placeholder.
  ///
  /// In zh, this message translates to:
  /// **'[系统消息]'**
  String get chat_attachment_system_placeholder;

  /// No description provided for @chat_more_members.
  ///
  /// In zh, this message translates to:
  /// **'查看成员'**
  String get chat_more_members;

  /// No description provided for @chat_more_clear_history.
  ///
  /// In zh, this message translates to:
  /// **'清空聊天记录'**
  String get chat_more_clear_history;

  /// No description provided for @chat_more_mute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get chat_more_mute;

  /// No description provided for @chat_more_unmute.
  ///
  /// In zh, this message translates to:
  /// **'取消静音'**
  String get chat_more_unmute;

  /// No description provided for @chat_more_report.
  ///
  /// In zh, this message translates to:
  /// **'举报'**
  String get chat_more_report;

  /// No description provided for @chat_clear_confirm.
  ///
  /// In zh, this message translates to:
  /// **'清空所有聊天记录？'**
  String get chat_clear_confirm;

  /// No description provided for @chat_cleared.
  ///
  /// In zh, this message translates to:
  /// **'已清空'**
  String get chat_cleared;

  /// No description provided for @profile_title.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get profile_title;

  /// No description provided for @profile_edit_btn.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get profile_edit_btn;

  /// No description provided for @profile_archive_title.
  ///
  /// In zh, this message translates to:
  /// **'我的球员档案'**
  String get profile_archive_title;

  /// No description provided for @profile_archive_new_badge.
  ///
  /// In zh, this message translates to:
  /// **'NEW'**
  String get profile_archive_new_badge;

  /// No description provided for @profile_mini_overall.
  ///
  /// In zh, this message translates to:
  /// **'综合'**
  String get profile_mini_overall;

  /// No description provided for @profile_mini_matches.
  ///
  /// In zh, this message translates to:
  /// **'场次'**
  String get profile_mini_matches;

  /// No description provided for @profile_mini_goals.
  ///
  /// In zh, this message translates to:
  /// **'进球'**
  String get profile_mini_goals;

  /// No description provided for @profile_mini_mvp.
  ///
  /// In zh, this message translates to:
  /// **'MVP'**
  String get profile_mini_mvp;

  /// No description provided for @profile_section_activity.
  ///
  /// In zh, this message translates to:
  /// **'我的活动'**
  String get profile_section_activity;

  /// No description provided for @profile_section_settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get profile_section_settings;

  /// No description provided for @profile_menu_my_events.
  ///
  /// In zh, this message translates to:
  /// **'我报名的赛事'**
  String get profile_menu_my_events;

  /// No description provided for @profile_menu_my_pickups.
  ///
  /// In zh, this message translates to:
  /// **'我组织的球局'**
  String get profile_menu_my_pickups;

  /// No description provided for @profile_menu_my_teams.
  ///
  /// In zh, this message translates to:
  /// **'我的队伍'**
  String get profile_menu_my_teams;

  /// No description provided for @profile_menu_favorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏与足迹'**
  String get profile_menu_favorites;

  /// No description provided for @profile_menu_account.
  ///
  /// In zh, this message translates to:
  /// **'账号设置'**
  String get profile_menu_account;

  /// No description provided for @profile_menu_notif.
  ///
  /// In zh, this message translates to:
  /// **'通知与消息'**
  String get profile_menu_notif;

  /// No description provided for @profile_menu_help.
  ///
  /// In zh, this message translates to:
  /// **'帮助与反馈'**
  String get profile_menu_help;

  /// No description provided for @profile_menu_about.
  ///
  /// In zh, this message translates to:
  /// **'关于开球'**
  String get profile_menu_about;

  /// No description provided for @profile_following.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get profile_following;

  /// No description provided for @profile_followers.
  ///
  /// In zh, this message translates to:
  /// **'粉丝'**
  String get profile_followers;

  /// No description provided for @profile_logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get profile_logout;

  /// No description provided for @profile_logout_confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认退出登录？'**
  String get profile_logout_confirm;

  /// No description provided for @archive_share.
  ///
  /// In zh, this message translates to:
  /// **'分享档案'**
  String get archive_share;

  /// No description provided for @archive_card_profile.
  ///
  /// In zh, this message translates to:
  /// **'球员档案 · 2026'**
  String get archive_card_profile;

  /// No description provided for @archive_card_overall.
  ///
  /// In zh, this message translates to:
  /// **'综合评分'**
  String get archive_card_overall;

  /// No description provided for @archive_flip_front.
  ///
  /// In zh, this message translates to:
  /// **'点击卡片查看正面'**
  String get archive_flip_front;

  /// No description provided for @archive_flip_back.
  ///
  /// In zh, this message translates to:
  /// **'点击卡片查看属性雷达'**
  String get archive_flip_back;

  /// No description provided for @archive_rating_panel_title.
  ///
  /// In zh, this message translates to:
  /// **'我的评分 · 过去 30 天'**
  String get archive_rating_panel_title;

  /// No description provided for @archive_rating_rated.
  ///
  /// In zh, this message translates to:
  /// **'被评'**
  String get archive_rating_rated;

  /// No description provided for @archive_rating_rank.
  ///
  /// In zh, this message translates to:
  /// **'赛事排名'**
  String get archive_rating_rank;

  /// No description provided for @archive_rating_trend.
  ///
  /// In zh, this message translates to:
  /// **'趋势'**
  String get archive_rating_trend;

  /// No description provided for @archive_rating_go_rate.
  ///
  /// In zh, this message translates to:
  /// **'去评分'**
  String get archive_rating_go_rate;

  /// No description provided for @archive_season_data.
  ///
  /// In zh, this message translates to:
  /// **'数据墙 · 赛季'**
  String get archive_season_data;

  /// No description provided for @archive_goal_trend.
  ///
  /// In zh, this message translates to:
  /// **'本赛季进球趋势'**
  String get archive_goal_trend;

  /// No description provided for @archive_honors_title.
  ///
  /// In zh, this message translates to:
  /// **'荣誉墙'**
  String get archive_honors_title;

  /// No description provided for @archive_honors_count.
  ///
  /// In zh, this message translates to:
  /// **'{n} 项'**
  String archive_honors_count(int n);

  /// No description provided for @archive_teammates_title.
  ///
  /// In zh, this message translates to:
  /// **'队友网络'**
  String get archive_teammates_title;

  /// No description provided for @archive_teammates_sub.
  ///
  /// In zh, this message translates to:
  /// **'常一起踢球的 {n} 人'**
  String archive_teammates_sub(int n);

  /// No description provided for @archive_history_title.
  ///
  /// In zh, this message translates to:
  /// **'比赛历史'**
  String get archive_history_title;

  /// No description provided for @archive_radar_title.
  ///
  /// In zh, this message translates to:
  /// **'属性雷达'**
  String get archive_radar_title;

  /// No description provided for @archive_radar_flip_back.
  ///
  /// In zh, this message translates to:
  /// **'点击翻回'**
  String get archive_radar_flip_back;

  /// No description provided for @archive_teammates_matches.
  ///
  /// In zh, this message translates to:
  /// **'{n}场'**
  String archive_teammates_matches(int n);

  /// No description provided for @archive_history_mvp.
  ///
  /// In zh, this message translates to:
  /// **'MVP'**
  String get archive_history_mvp;

  /// No description provided for @archive_history_goals_n.
  ///
  /// In zh, this message translates to:
  /// **'{n}球'**
  String archive_history_goals_n(int n);

  /// No description provided for @archive_history_assists_n.
  ///
  /// In zh, this message translates to:
  /// **'{n}助'**
  String archive_history_assists_n(int n);

  /// No description provided for @profile_edit_title.
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get profile_edit_title;

  /// No description provided for @profile_edit_name.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get profile_edit_name;

  /// No description provided for @profile_edit_handle.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get profile_edit_handle;

  /// No description provided for @profile_edit_city.
  ///
  /// In zh, this message translates to:
  /// **'所在城市'**
  String get profile_edit_city;

  /// No description provided for @profile_edit_district.
  ///
  /// In zh, this message translates to:
  /// **'城区'**
  String get profile_edit_district;

  /// No description provided for @profile_edit_position.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get profile_edit_position;

  /// No description provided for @profile_edit_position_full.
  ///
  /// In zh, this message translates to:
  /// **'位置全称'**
  String get profile_edit_position_full;

  /// No description provided for @profile_edit_height.
  ///
  /// In zh, this message translates to:
  /// **'身高 (cm)'**
  String get profile_edit_height;

  /// No description provided for @profile_edit_foot.
  ///
  /// In zh, this message translates to:
  /// **'惯用脚'**
  String get profile_edit_foot;

  /// No description provided for @profile_edit_foot_left.
  ///
  /// In zh, this message translates to:
  /// **'左脚'**
  String get profile_edit_foot_left;

  /// No description provided for @profile_edit_foot_right.
  ///
  /// In zh, this message translates to:
  /// **'右脚'**
  String get profile_edit_foot_right;

  /// No description provided for @profile_edit_foot_both.
  ///
  /// In zh, this message translates to:
  /// **'双脚'**
  String get profile_edit_foot_both;

  /// No description provided for @profile_edit_avatar.
  ///
  /// In zh, this message translates to:
  /// **'头像'**
  String get profile_edit_avatar;

  /// No description provided for @profile_edit_avatar_hint.
  ///
  /// In zh, this message translates to:
  /// **'点击更换头像（暂用首字母）'**
  String get profile_edit_avatar_hint;

  /// No description provided for @profile_edit_save_ok.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get profile_edit_save_ok;

  /// No description provided for @profile_edit_save_fail.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get profile_edit_save_fail;

  /// No description provided for @profile_edit_position_opt_gk.
  ///
  /// In zh, this message translates to:
  /// **'GK · 门将'**
  String get profile_edit_position_opt_gk;

  /// No description provided for @profile_edit_position_opt_cb.
  ///
  /// In zh, this message translates to:
  /// **'CB · 中后卫'**
  String get profile_edit_position_opt_cb;

  /// No description provided for @profile_edit_position_opt_lb.
  ///
  /// In zh, this message translates to:
  /// **'LB · 左后卫'**
  String get profile_edit_position_opt_lb;

  /// No description provided for @profile_edit_position_opt_rb.
  ///
  /// In zh, this message translates to:
  /// **'RB · 右后卫'**
  String get profile_edit_position_opt_rb;

  /// No description provided for @profile_edit_position_opt_cm.
  ///
  /// In zh, this message translates to:
  /// **'CM · 中场'**
  String get profile_edit_position_opt_cm;

  /// No description provided for @profile_edit_position_opt_cam.
  ///
  /// In zh, this message translates to:
  /// **'CAM · 前腰'**
  String get profile_edit_position_opt_cam;

  /// No description provided for @profile_edit_position_opt_cdm.
  ///
  /// In zh, this message translates to:
  /// **'CDM · 后腰'**
  String get profile_edit_position_opt_cdm;

  /// No description provided for @profile_edit_position_opt_lw.
  ///
  /// In zh, this message translates to:
  /// **'LW · 左边锋'**
  String get profile_edit_position_opt_lw;

  /// No description provided for @profile_edit_position_opt_rw.
  ///
  /// In zh, this message translates to:
  /// **'RW · 右边锋'**
  String get profile_edit_position_opt_rw;

  /// No description provided for @profile_edit_position_opt_cf.
  ///
  /// In zh, this message translates to:
  /// **'CF · 中锋'**
  String get profile_edit_position_opt_cf;

  /// No description provided for @profile_edit_position_opt_st.
  ///
  /// In zh, this message translates to:
  /// **'ST · 前锋'**
  String get profile_edit_position_opt_st;

  /// No description provided for @settings_account_title.
  ///
  /// In zh, this message translates to:
  /// **'账号设置'**
  String get settings_account_title;

  /// No description provided for @settings_account_language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settings_account_language;

  /// No description provided for @settings_account_profile.
  ///
  /// In zh, this message translates to:
  /// **'修改资料'**
  String get settings_account_profile;

  /// No description provided for @settings_account_email.
  ///
  /// In zh, this message translates to:
  /// **'绑定邮箱'**
  String get settings_account_email;

  /// No description provided for @settings_account_password.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get settings_account_password;

  /// No description provided for @settings_account_password_old.
  ///
  /// In zh, this message translates to:
  /// **'旧密码'**
  String get settings_account_password_old;

  /// No description provided for @settings_account_password_new.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get settings_account_password_new;

  /// No description provided for @settings_account_password_confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get settings_account_password_confirm;

  /// No description provided for @settings_account_password_updated.
  ///
  /// In zh, this message translates to:
  /// **'密码已更新'**
  String get settings_account_password_updated;

  /// No description provided for @settings_account_password_mismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次密码不一致'**
  String get settings_account_password_mismatch;

  /// No description provided for @settings_account_logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settings_account_logout;

  /// No description provided for @settings_account_delete.
  ///
  /// In zh, this message translates to:
  /// **'注销账号'**
  String get settings_account_delete;

  /// No description provided for @settings_account_delete_confirm.
  ///
  /// In zh, this message translates to:
  /// **'注销后所有数据将不可恢复，是否继续？'**
  String get settings_account_delete_confirm;

  /// No description provided for @settings_account_delete_done.
  ///
  /// In zh, this message translates to:
  /// **'账号已注销'**
  String get settings_account_delete_done;

  /// No description provided for @settings_lang_title.
  ///
  /// In zh, this message translates to:
  /// **'语言 / Language'**
  String get settings_lang_title;

  /// No description provided for @settings_lang_zh.
  ///
  /// In zh, this message translates to:
  /// **'中文 简体'**
  String get settings_lang_zh;

  /// No description provided for @settings_lang_en.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settings_lang_en;

  /// No description provided for @settings_lang_system.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settings_lang_system;

  /// No description provided for @settings_notif_title.
  ///
  /// In zh, this message translates to:
  /// **'通知与消息'**
  String get settings_notif_title;

  /// No description provided for @settings_notif_push.
  ///
  /// In zh, this message translates to:
  /// **'推送通知'**
  String get settings_notif_push;

  /// No description provided for @settings_notif_push_sub.
  ///
  /// In zh, this message translates to:
  /// **'关闭后将无法收到系统推送'**
  String get settings_notif_push_sub;

  /// No description provided for @settings_notif_inapp.
  ///
  /// In zh, this message translates to:
  /// **'站内消息'**
  String get settings_notif_inapp;

  /// No description provided for @settings_notif_inapp_sub.
  ///
  /// In zh, this message translates to:
  /// **'聊天、评论、系统通知'**
  String get settings_notif_inapp_sub;

  /// No description provided for @settings_notif_email.
  ///
  /// In zh, this message translates to:
  /// **'邮件提醒'**
  String get settings_notif_email;

  /// No description provided for @settings_notif_email_sub.
  ///
  /// In zh, this message translates to:
  /// **'重要通知发送到你的邮箱'**
  String get settings_notif_email_sub;

  /// No description provided for @settings_notif_match_reminder.
  ///
  /// In zh, this message translates to:
  /// **'赛前提醒'**
  String get settings_notif_match_reminder;

  /// No description provided for @settings_notif_match_reminder_sub.
  ///
  /// In zh, this message translates to:
  /// **'比赛开始前 10 分钟提醒'**
  String get settings_notif_match_reminder_sub;

  /// No description provided for @profile_menu_appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get profile_menu_appearance;

  /// No description provided for @settings_appearance_title.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settings_appearance_title;

  /// No description provided for @appearance_theme_mode_section.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get appearance_theme_mode_section;

  /// No description provided for @appearance_theme_mode_system.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get appearance_theme_mode_system;

  /// No description provided for @appearance_theme_mode_light.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get appearance_theme_mode_light;

  /// No description provided for @appearance_theme_mode_dark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get appearance_theme_mode_dark;

  /// No description provided for @appearance_accent_section.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get appearance_accent_section;

  /// No description provided for @appearance_accent_green.
  ///
  /// In zh, this message translates to:
  /// **'经典绿'**
  String get appearance_accent_green;

  /// No description provided for @appearance_accent_orange.
  ///
  /// In zh, this message translates to:
  /// **'活力橙'**
  String get appearance_accent_orange;

  /// No description provided for @appearance_accent_cyan.
  ///
  /// In zh, this message translates to:
  /// **'海洋青'**
  String get appearance_accent_cyan;

  /// No description provided for @appearance_accent_red.
  ///
  /// In zh, this message translates to:
  /// **'热情红'**
  String get appearance_accent_red;

  /// No description provided for @appearance_accent_custom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get appearance_accent_custom;

  /// No description provided for @appearance_preview_section.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get appearance_preview_section;

  /// No description provided for @appearance_preview_card_title.
  ///
  /// In zh, this message translates to:
  /// **'周三晚 7:30  五人足球'**
  String get appearance_preview_card_title;

  /// No description provided for @appearance_preview_card_meta.
  ///
  /// In zh, this message translates to:
  /// **'南宁青秀·星空足球公园'**
  String get appearance_preview_card_meta;

  /// No description provided for @appearance_preview_card_cta.
  ///
  /// In zh, this message translates to:
  /// **'立即报名'**
  String get appearance_preview_card_cta;

  /// No description provided for @appearance_picker_title.
  ///
  /// In zh, this message translates to:
  /// **'选择主题色'**
  String get appearance_picker_title;

  /// No description provided for @appearance_picker_confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get appearance_picker_confirm;

  /// No description provided for @appearance_picker_cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get appearance_picker_cancel;

  /// No description provided for @settings_help_title.
  ///
  /// In zh, this message translates to:
  /// **'帮助与反馈'**
  String get settings_help_title;

  /// No description provided for @settings_help_faq.
  ///
  /// In zh, this message translates to:
  /// **'常见问题'**
  String get settings_help_faq;

  /// No description provided for @settings_help_feedback.
  ///
  /// In zh, this message translates to:
  /// **'写下你的反馈'**
  String get settings_help_feedback;

  /// No description provided for @settings_help_feedback_hint.
  ///
  /// In zh, this message translates to:
  /// **'描述问题或建议，我们会尽快改进…'**
  String get settings_help_feedback_hint;

  /// No description provided for @settings_help_feedback_submit.
  ///
  /// In zh, this message translates to:
  /// **'提交反馈'**
  String get settings_help_feedback_submit;

  /// No description provided for @settings_help_feedback_thanks.
  ///
  /// In zh, this message translates to:
  /// **'已收到，感谢反馈'**
  String get settings_help_feedback_thanks;

  /// No description provided for @settings_help_faq_1_q.
  ///
  /// In zh, this message translates to:
  /// **'如何发起一个约球？'**
  String get settings_help_faq_1_q;

  /// No description provided for @settings_help_faq_1_a.
  ///
  /// In zh, this message translates to:
  /// **'进入「约球」Tab，点击右下角 + 按钮，填写场地、时间、人数等信息即可发布。'**
  String get settings_help_faq_1_a;

  /// No description provided for @settings_help_faq_2_q.
  ///
  /// In zh, this message translates to:
  /// **'报名赛事后可以退出吗？'**
  String get settings_help_faq_2_q;

  /// No description provided for @settings_help_faq_2_a.
  ///
  /// In zh, this message translates to:
  /// **'报名审核中可直接退出；审核通过后需联系组委会。'**
  String get settings_help_faq_2_a;

  /// No description provided for @settings_help_faq_3_q.
  ///
  /// In zh, this message translates to:
  /// **'评分规则是怎样的？'**
  String get settings_help_faq_3_q;

  /// No description provided for @settings_help_faq_3_a.
  ///
  /// In zh, this message translates to:
  /// **'每场比赛结束后 72 小时内可对队友/对手打 0-10 分，每位球员的最终评分为所有评分人的平均值。'**
  String get settings_help_faq_3_a;

  /// No description provided for @settings_help_faq_4_q.
  ///
  /// In zh, this message translates to:
  /// **'如何认领球员档案？'**
  String get settings_help_faq_4_q;

  /// No description provided for @settings_help_faq_4_a.
  ///
  /// In zh, this message translates to:
  /// **'在「我的 → 编辑」中补全位置、身高、惯脚即可激活档案。'**
  String get settings_help_faq_4_a;

  /// No description provided for @settings_help_faq_5_q.
  ///
  /// In zh, this message translates to:
  /// **'开球支持哪些运动？'**
  String get settings_help_faq_5_q;

  /// No description provided for @settings_help_faq_5_a.
  ///
  /// In zh, this message translates to:
  /// **'当前支持足球、篮球、羽毛球、乒乓球、骑行，后续将持续扩展。'**
  String get settings_help_faq_5_a;

  /// No description provided for @settings_help_faq_6_q.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码怎么办？'**
  String get settings_help_faq_6_q;

  /// No description provided for @settings_help_faq_6_a.
  ///
  /// In zh, this message translates to:
  /// **'在登录页点击「忘记密码」，输入邮箱后我们会发送重置链接。'**
  String get settings_help_faq_6_a;

  /// No description provided for @settings_about_title.
  ///
  /// In zh, this message translates to:
  /// **'关于开球'**
  String get settings_about_title;

  /// No description provided for @settings_about_version_label.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settings_about_version_label;

  /// No description provided for @settings_about_tagline.
  ///
  /// In zh, this message translates to:
  /// **'业余运动的主场'**
  String get settings_about_tagline;

  /// No description provided for @settings_about_team.
  ///
  /// In zh, this message translates to:
  /// **'团队'**
  String get settings_about_team;

  /// No description provided for @settings_about_team_body.
  ///
  /// In zh, this message translates to:
  /// **'开球 · GameOn 是一群踢球、打球、写代码的玩家做的社区。我们相信业余运动也值得被认真记录。'**
  String get settings_about_team_body;

  /// No description provided for @settings_about_legal.
  ///
  /// In zh, this message translates to:
  /// **'法律'**
  String get settings_about_legal;

  /// No description provided for @settings_about_terms.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get settings_about_terms;

  /// No description provided for @settings_about_privacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get settings_about_privacy;

  /// No description provided for @settings_about_contact.
  ///
  /// In zh, this message translates to:
  /// **'联系我们'**
  String get settings_about_contact;

  /// No description provided for @settings_about_email.
  ///
  /// In zh, this message translates to:
  /// **'hi@kaiqiu.app'**
  String get settings_about_email;

  /// No description provided for @legal_terms_title.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get legal_terms_title;

  /// No description provided for @legal_privacy_title.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get legal_privacy_title;

  /// No description provided for @legal_terms_body.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用开球（以下简称「本 App」）。通过注册或使用本 App，即表示你同意本协议全部条款。\n\n1. 用户行为：请文明使用，禁止发布违法或侵害他人权益的内容。\n2. 账号与安全：你对自己的账号及密码负责，由此产生的一切活动由你本人承担。\n3. 内容所有权：你发布的内容归你所有，授予本 App 在服务范围内免费使用的权利。\n4. 免责声明：约球与线下活动存在风险，请自行评估身体状况并购买必要的保险。\n5. 协议变更：本 App 有权更新本协议，新版本将在 App 内公示。\n\n如有疑问，请联系 hi@kaiqiu.app。'**
  String get legal_terms_body;

  /// No description provided for @legal_privacy_body.
  ///
  /// In zh, this message translates to:
  /// **'我们重视你的隐私。以下是关于你如何使用开球 App、我们如何收集与使用信息的简要说明。\n\n1. 收集信息：注册信息（邮箱/昵称）、位置信息（在你允许后用于同城推荐）、比赛数据（你主动发布的内容）。\n2. 使用目的：提供服务、改进体验、安全防护、统计分析。\n3. 信息共享：我们不会出售你的个人信息。必要时与服务提供商共享，且对方受同等保密义务约束。\n4. 你的权利：可随时访问、修正、导出或删除个人信息。\n5. 数据安全：我们使用业界通用的加密与访问控制措施保护你的数据。\n\n如有疑问，请联系 hi@kaiqiu.app。'**
  String get legal_privacy_body;

  /// No description provided for @search_title.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search_title;

  /// No description provided for @search_hint.
  ///
  /// In zh, this message translates to:
  /// **'搜索约球 / 赛事 / 球员 / 场地'**
  String get search_hint;

  /// No description provided for @search_recent.
  ///
  /// In zh, this message translates to:
  /// **'最近搜索'**
  String get search_recent;

  /// No description provided for @search_hot_tags.
  ///
  /// In zh, this message translates to:
  /// **'热门标签'**
  String get search_hot_tags;

  /// No description provided for @search_clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get search_clear;

  /// No description provided for @search_result_pickups.
  ///
  /// In zh, this message translates to:
  /// **'约球'**
  String get search_result_pickups;

  /// No description provided for @search_result_events.
  ///
  /// In zh, this message translates to:
  /// **'赛事'**
  String get search_result_events;

  /// No description provided for @search_result_empty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到与「{q}」相关的结果'**
  String search_result_empty(String q);

  /// No description provided for @notif_title.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get notif_title;

  /// No description provided for @notif_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get notif_all;

  /// No description provided for @notif_unread.
  ///
  /// In zh, this message translates to:
  /// **'未读'**
  String get notif_unread;

  /// No description provided for @notif_mark_all_read.
  ///
  /// In zh, this message translates to:
  /// **'全部已读'**
  String get notif_mark_all_read;

  /// No description provided for @notif_group_system.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get notif_group_system;

  /// No description provided for @notif_group_match.
  ///
  /// In zh, this message translates to:
  /// **'比赛'**
  String get notif_group_match;

  /// No description provided for @notif_group_pickup.
  ///
  /// In zh, this message translates to:
  /// **'约球'**
  String get notif_group_pickup;

  /// No description provided for @notif_group_rating.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get notif_group_rating;

  /// No description provided for @notif_group_follow.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get notif_group_follow;

  /// No description provided for @notif_demo_welcome_t.
  ///
  /// In zh, this message translates to:
  /// **'欢迎来到开球 ⚽'**
  String get notif_demo_welcome_t;

  /// No description provided for @notif_demo_welcome_b.
  ///
  /// In zh, this message translates to:
  /// **'完善档案，开启你的赛季之旅。'**
  String get notif_demo_welcome_b;

  /// No description provided for @notif_demo_rate_t.
  ///
  /// In zh, this message translates to:
  /// **'你有一场比赛待评分'**
  String get notif_demo_rate_t;

  /// No description provided for @notif_demo_rate_b.
  ///
  /// In zh, this message translates to:
  /// **'龙岗村超 · 狼队 vs FC 黑马，3 位队友等你打分。'**
  String get notif_demo_rate_b;

  /// No description provided for @notif_demo_pickup_t.
  ///
  /// In zh, this message translates to:
  /// **'周六 19:30 约球还差 1 人'**
  String get notif_demo_pickup_t;

  /// No description provided for @notif_demo_pickup_b.
  ///
  /// In zh, this message translates to:
  /// **'莲花山足球场 · 点击查看阵型。'**
  String get notif_demo_pickup_b;

  /// No description provided for @notif_demo_event_t.
  ///
  /// In zh, this message translates to:
  /// **'2026 龙岗夏季杯开始报名'**
  String get notif_demo_event_t;

  /// No description provided for @notif_demo_event_b.
  ///
  /// In zh, this message translates to:
  /// **'16 队淘汰制，奖金 2 万，截止 05-25。'**
  String get notif_demo_event_b;

  /// No description provided for @notif_demo_follow_t.
  ///
  /// In zh, this message translates to:
  /// **'老王 关注了你'**
  String get notif_demo_follow_t;

  /// No description provided for @notif_demo_follow_b.
  ///
  /// In zh, this message translates to:
  /// **'互相关注后即可私信。'**
  String get notif_demo_follow_b;

  /// No description provided for @city_picker_title.
  ///
  /// In zh, this message translates to:
  /// **'选择城市'**
  String get city_picker_title;

  /// No description provided for @city_picker_hot.
  ///
  /// In zh, this message translates to:
  /// **'热门城市'**
  String get city_picker_hot;

  /// No description provided for @city_picker_all.
  ///
  /// In zh, this message translates to:
  /// **'全部城市'**
  String get city_picker_all;

  /// No description provided for @city_picker_current.
  ///
  /// In zh, this message translates to:
  /// **'当前定位'**
  String get city_picker_current;

  /// No description provided for @me_events_title.
  ///
  /// In zh, this message translates to:
  /// **'我的赛事'**
  String get me_events_title;

  /// No description provided for @me_events_tab_registered.
  ///
  /// In zh, this message translates to:
  /// **'我报名的'**
  String get me_events_tab_registered;

  /// No description provided for @me_events_tab_hosted.
  ///
  /// In zh, this message translates to:
  /// **'我组织的'**
  String get me_events_tab_hosted;

  /// No description provided for @me_events_tab_done.
  ///
  /// In zh, this message translates to:
  /// **'已完赛'**
  String get me_events_tab_done;

  /// No description provided for @me_pickups_title.
  ///
  /// In zh, this message translates to:
  /// **'我的球局'**
  String get me_pickups_title;

  /// No description provided for @me_pickups_tab_hosted.
  ///
  /// In zh, this message translates to:
  /// **'我组织的'**
  String get me_pickups_tab_hosted;

  /// No description provided for @me_pickups_tab_joined.
  ///
  /// In zh, this message translates to:
  /// **'我参加的'**
  String get me_pickups_tab_joined;

  /// No description provided for @me_teams_title.
  ///
  /// In zh, this message translates to:
  /// **'我的队伍'**
  String get me_teams_title;

  /// No description provided for @me_teams_create.
  ///
  /// In zh, this message translates to:
  /// **'创建球队'**
  String get me_teams_create;

  /// No description provided for @me_teams_create_name.
  ///
  /// In zh, this message translates to:
  /// **'球队名'**
  String get me_teams_create_name;

  /// No description provided for @me_teams_create_city.
  ///
  /// In zh, this message translates to:
  /// **'所在城市'**
  String get me_teams_create_city;

  /// No description provided for @me_teams_create_sub.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get me_teams_create_sub;

  /// No description provided for @me_teams_create_submit.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get me_teams_create_submit;

  /// No description provided for @me_teams_remove.
  ///
  /// In zh, this message translates to:
  /// **'解散'**
  String get me_teams_remove;

  /// No description provided for @me_teams_remove_confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认解散该队伍？'**
  String get me_teams_remove_confirm;

  /// No description provided for @me_favorites_title.
  ///
  /// In zh, this message translates to:
  /// **'收藏与足迹'**
  String get me_favorites_title;

  /// No description provided for @me_favorites_tab_pickups.
  ///
  /// In zh, this message translates to:
  /// **'约球'**
  String get me_favorites_tab_pickups;

  /// No description provided for @me_favorites_tab_events.
  ///
  /// In zh, this message translates to:
  /// **'赛事'**
  String get me_favorites_tab_events;

  /// No description provided for @me_favorites_tab_players.
  ///
  /// In zh, this message translates to:
  /// **'球员'**
  String get me_favorites_tab_players;

  /// No description provided for @auth_login_title.
  ///
  /// In zh, this message translates to:
  /// **'欢迎来到开球'**
  String get auth_login_title;

  /// No description provided for @auth_login_sub.
  ///
  /// In zh, this message translates to:
  /// **'一起踢一场'**
  String get auth_login_sub;

  /// No description provided for @auth_email.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get auth_email;

  /// No description provided for @auth_password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get auth_password;

  /// No description provided for @auth_remember_me.
  ///
  /// In zh, this message translates to:
  /// **'记住我'**
  String get auth_remember_me;

  /// No description provided for @auth_forgot_password.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码'**
  String get auth_forgot_password;

  /// No description provided for @auth_signup_toggle_new.
  ///
  /// In zh, this message translates to:
  /// **'注册新账号'**
  String get auth_signup_toggle_new;

  /// No description provided for @auth_signup_toggle_old.
  ///
  /// In zh, this message translates to:
  /// **'已有账号，去登录'**
  String get auth_signup_toggle_old;

  /// No description provided for @auth_login_btn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get auth_login_btn;

  /// No description provided for @auth_signup_btn.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get auth_signup_btn;

  /// No description provided for @auth_anon_btn.
  ///
  /// In zh, this message translates to:
  /// **'游客登录'**
  String get auth_anon_btn;

  /// No description provided for @auth_or.
  ///
  /// In zh, this message translates to:
  /// **'或'**
  String get auth_or;

  /// No description provided for @auth_reset_title.
  ///
  /// In zh, this message translates to:
  /// **'重置密码'**
  String get auth_reset_title;

  /// No description provided for @auth_reset_sub.
  ///
  /// In zh, this message translates to:
  /// **'输入你的邮箱，我们会发送重置链接'**
  String get auth_reset_sub;

  /// No description provided for @auth_reset_submit.
  ///
  /// In zh, this message translates to:
  /// **'发送重置邮件'**
  String get auth_reset_submit;

  /// No description provided for @auth_reset_sent.
  ///
  /// In zh, this message translates to:
  /// **'邮件已发送，请前往邮箱查看'**
  String get auth_reset_sent;

  /// No description provided for @auth_reset_failed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败'**
  String get auth_reset_failed;

  /// No description provided for @auth_signin_failed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败'**
  String get auth_signin_failed;

  /// No description provided for @auth_signup_failed.
  ///
  /// In zh, this message translates to:
  /// **'注册失败'**
  String get auth_signup_failed;

  /// No description provided for @auth_anon_failed.
  ///
  /// In zh, this message translates to:
  /// **'游客登录失败'**
  String get auth_anon_failed;

  /// No description provided for @rate_title.
  ///
  /// In zh, this message translates to:
  /// **'赛后评分'**
  String get rate_title;

  /// No description provided for @rate_progress.
  ///
  /// In zh, this message translates to:
  /// **'{cur}/{total} 人'**
  String rate_progress(int cur, int total);

  /// No description provided for @rate_comment_hint.
  ///
  /// In zh, this message translates to:
  /// **'说点什么（选填）…'**
  String get rate_comment_hint;

  /// No description provided for @rate_skip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get rate_skip;

  /// No description provided for @rate_submit.
  ///
  /// In zh, this message translates to:
  /// **'提交评分'**
  String get rate_submit;

  /// No description provided for @rate_submit_all.
  ///
  /// In zh, this message translates to:
  /// **'提交全部'**
  String get rate_submit_all;

  /// No description provided for @rate_submitting.
  ///
  /// In zh, this message translates to:
  /// **'提交中…'**
  String get rate_submitting;

  /// No description provided for @rate_done_title.
  ///
  /// In zh, this message translates to:
  /// **'评分完成'**
  String get rate_done_title;

  /// No description provided for @rate_done_sub.
  ///
  /// In zh, this message translates to:
  /// **'{n} 位球员已评分'**
  String rate_done_sub(int n);

  /// No description provided for @rate_done_more.
  ///
  /// In zh, this message translates to:
  /// **'再评一场'**
  String get rate_done_more;

  /// No description provided for @rate_done_back.
  ///
  /// In zh, this message translates to:
  /// **'回到赛事'**
  String get rate_done_back;

  /// No description provided for @time_just_now.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get time_just_now;

  /// No description provided for @time_minutes_ago.
  ///
  /// In zh, this message translates to:
  /// **'{n} 分钟前'**
  String time_minutes_ago(int n);

  /// No description provided for @time_hours_ago.
  ///
  /// In zh, this message translates to:
  /// **'{n} 小时前'**
  String time_hours_ago(int n);

  /// No description provided for @time_days_ago.
  ///
  /// In zh, this message translates to:
  /// **'{n} 天前'**
  String time_days_ago(int n);

  /// No description provided for @time_yesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get time_yesterday;

  /// No description provided for @home_status_open.
  ///
  /// In zh, this message translates to:
  /// **'招人中'**
  String get home_status_open;

  /// No description provided for @home_status_almost.
  ///
  /// In zh, this message translates to:
  /// **'即将满员'**
  String get home_status_almost;

  /// No description provided for @home_status_full.
  ///
  /// In zh, this message translates to:
  /// **'已满员'**
  String get home_status_full;

  /// No description provided for @home_need_n.
  ///
  /// In zh, this message translates to:
  /// **'缺 {n}人'**
  String home_need_n(int n);

  /// No description provided for @home_full.
  ///
  /// In zh, this message translates to:
  /// **'已满'**
  String get home_full;

  /// No description provided for @home_join_cta.
  ///
  /// In zh, this message translates to:
  /// **'一键报名 →'**
  String get home_join_cta;

  /// No description provided for @home_rate_banner_title.
  ///
  /// In zh, this message translates to:
  /// **'给昨天的比赛打个分'**
  String get home_rate_banner_title;

  /// No description provided for @home_rate_banner_sub.
  ///
  /// In zh, this message translates to:
  /// **'龙岗村超 · 1/4决赛 · 9 位球员待评'**
  String get home_rate_banner_sub;

  /// No description provided for @home_host_pickup.
  ///
  /// In zh, this message translates to:
  /// **'发起约球'**
  String get home_host_pickup;

  /// No description provided for @home_host_pickup_with_time.
  ///
  /// In zh, this message translates to:
  /// **'发起约球 · {time}'**
  String home_host_pickup_with_time(String time);

  /// No description provided for @home_event_teaser.
  ///
  /// In zh, this message translates to:
  /// **'赛事预告'**
  String get home_event_teaser;

  /// No description provided for @home_event_registered_label.
  ///
  /// In zh, this message translates to:
  /// **'已报名队伍'**
  String get home_event_registered_label;

  /// No description provided for @home_event_kickoff.
  ///
  /// In zh, this message translates to:
  /// **'开赛'**
  String get home_event_kickoff;

  /// No description provided for @home_event_register_now.
  ///
  /// In zh, this message translates to:
  /// **'立即报名 →'**
  String get home_event_register_now;

  /// No description provided for @home_pickups_load_failed.
  ///
  /// In zh, this message translates to:
  /// **'加载约球数据失败'**
  String get home_pickups_load_failed;

  /// No description provided for @home_tab_recommend.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get home_tab_recommend;

  /// No description provided for @home_tab_events.
  ///
  /// In zh, this message translates to:
  /// **'赛事'**
  String get home_tab_events;

  /// No description provided for @home_tab_pickup.
  ///
  /// In zh, this message translates to:
  /// **'约球'**
  String get home_tab_pickup;

  /// No description provided for @home_tab_discover.
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get home_tab_discover;

  /// No description provided for @home_all_events.
  ///
  /// In zh, this message translates to:
  /// **'全部赛事'**
  String get home_all_events;

  /// No description provided for @home_events_live.
  ///
  /// In zh, this message translates to:
  /// **'正在直播'**
  String get home_events_live;

  /// No description provided for @home_events_registering.
  ///
  /// In zh, this message translates to:
  /// **'报名中'**
  String get home_events_registering;

  /// No description provided for @home_events_ongoing.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get home_events_ongoing;

  /// No description provided for @home_events_upcoming.
  ///
  /// In zh, this message translates to:
  /// **'即将开始'**
  String get home_events_upcoming;

  /// No description provided for @home_events_view.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get home_events_view;

  /// No description provided for @home_events_coming_soon.
  ///
  /// In zh, this message translates to:
  /// **'敬请期待'**
  String get home_events_coming_soon;

  /// No description provided for @home_events_register.
  ///
  /// In zh, this message translates to:
  /// **'报名'**
  String get home_events_register;

  /// No description provided for @home_pickup_filter_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get home_pickup_filter_all;

  /// No description provided for @home_pickup_filter_distance.
  ///
  /// In zh, this message translates to:
  /// **'距离'**
  String get home_pickup_filter_distance;

  /// No description provided for @home_pickup_filter_today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get home_pickup_filter_today;

  /// No description provided for @home_pickup_filter_tomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天'**
  String get home_pickup_filter_tomorrow;

  /// No description provided for @home_pickup_filter_week.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get home_pickup_filter_week;

  /// No description provided for @home_pickup_filter_beginner.
  ///
  /// In zh, this message translates to:
  /// **'初级'**
  String get home_pickup_filter_beginner;

  /// No description provided for @home_pickup_filter_intermediate.
  ///
  /// In zh, this message translates to:
  /// **'中级'**
  String get home_pickup_filter_intermediate;

  /// No description provided for @home_pickup_filter_advanced.
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get home_pickup_filter_advanced;

  /// No description provided for @home_pickup_slots_available.
  ///
  /// In zh, this message translates to:
  /// **'名额充足'**
  String get home_pickup_slots_available;

  /// No description provided for @home_activity_matches.
  ///
  /// In zh, this message translates to:
  /// **'局数'**
  String get home_activity_matches;

  /// No description provided for @home_activity_record.
  ///
  /// In zh, this message translates to:
  /// **'胜负'**
  String get home_activity_record;

  /// No description provided for @home_activity_duration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get home_activity_duration;

  /// No description provided for @home_article_read_time.
  ///
  /// In zh, this message translates to:
  /// **'{min}分钟阅读'**
  String home_article_read_time(int min);

  /// No description provided for @home_viewers_count.
  ///
  /// In zh, this message translates to:
  /// **'{count} 观看'**
  String home_viewers_count(String count);

  /// No description provided for @home_discover_share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get home_discover_share;

  /// No description provided for @rate_panel_title.
  ///
  /// In zh, this message translates to:
  /// **'赛后评分'**
  String get rate_panel_title;

  /// No description provided for @rate_say_optional.
  ///
  /// In zh, this message translates to:
  /// **'说两句 · 选填'**
  String get rate_say_optional;

  /// No description provided for @rate_self_hint.
  ///
  /// In zh, this message translates to:
  /// **'自评一下？'**
  String get rate_self_hint;

  /// No description provided for @rate_other_hint.
  ///
  /// In zh, this message translates to:
  /// **'说说他今天的表现…'**
  String get rate_other_hint;

  /// No description provided for @rate_voters_avg.
  ///
  /// In zh, this message translates to:
  /// **'{n} 人已评 · 均分'**
  String rate_voters_avg(int n);

  /// No description provided for @rate_prev.
  ///
  /// In zh, this message translates to:
  /// **'上一位'**
  String get rate_prev;

  /// No description provided for @rate_next.
  ///
  /// In zh, this message translates to:
  /// **'下一位 →'**
  String get rate_next;

  /// No description provided for @rate_submit_score.
  ///
  /// In zh, this message translates to:
  /// **'提交评分'**
  String get rate_submit_score;

  /// No description provided for @rate_submit_failed.
  ///
  /// In zh, this message translates to:
  /// **'提交失败：{err}'**
  String rate_submit_failed(String err);

  /// No description provided for @rate_short_you.
  ///
  /// In zh, this message translates to:
  /// **'你'**
  String get rate_short_you;

  /// No description provided for @rate_level_bad.
  ///
  /// In zh, this message translates to:
  /// **'拉跨'**
  String get rate_level_bad;

  /// No description provided for @rate_level_meh.
  ///
  /// In zh, this message translates to:
  /// **'一般'**
  String get rate_level_meh;

  /// No description provided for @rate_level_good.
  ///
  /// In zh, this message translates to:
  /// **'不错'**
  String get rate_level_good;

  /// No description provided for @rate_level_god.
  ///
  /// In zh, this message translates to:
  /// **'封神'**
  String get rate_level_god;

  /// No description provided for @rate_done_header.
  ///
  /// In zh, this message translates to:
  /// **'评分已提交'**
  String get rate_done_header;

  /// No description provided for @rate_done_thanks_body.
  ///
  /// In zh, this message translates to:
  /// **'感谢你给 {n} 位球员打了分。'**
  String rate_done_thanks_body(int n);

  /// No description provided for @rate_done_view_leaderboard.
  ///
  /// In zh, this message translates to:
  /// **'查看评分榜'**
  String get rate_done_view_leaderboard;

  /// No description provided for @event_overview_main_visual.
  ///
  /// In zh, this message translates to:
  /// **'{name} · 主视觉'**
  String event_overview_main_visual(String name);

  /// No description provided for @event_overview_rule_format.
  ///
  /// In zh, this message translates to:
  /// **'11人制 · 标准场地'**
  String get event_overview_rule_format;

  /// No description provided for @event_overview_rule_halves.
  ///
  /// In zh, this message translates to:
  /// **'2 × 45min + 半场休息'**
  String get event_overview_rule_halves;

  /// No description provided for @event_overview_rule_subs.
  ///
  /// In zh, this message translates to:
  /// **'5人换人名额，换下可回'**
  String get event_overview_rule_subs;

  /// No description provided for @event_overview_rule_cards.
  ///
  /// In zh, this message translates to:
  /// **'红黄牌累积停赛'**
  String get event_overview_rule_cards;

  /// No description provided for @event_overview_organizer_label.
  ///
  /// In zh, this message translates to:
  /// **'赛事组织方'**
  String get event_overview_organizer_label;

  /// No description provided for @event_bracket_waiting.
  ///
  /// In zh, this message translates to:
  /// **'暂无赛程，等待组委会发布'**
  String get event_bracket_waiting;

  /// No description provided for @event_standings_empty2.
  ///
  /// In zh, this message translates to:
  /// **'暂无比赛结果'**
  String get event_standings_empty2;

  /// No description provided for @event_chat_sender_you.
  ///
  /// In zh, this message translates to:
  /// **'你'**
  String get event_chat_sender_you;

  /// No description provided for @event_chat_sender_stranger.
  ///
  /// In zh, this message translates to:
  /// **'球友'**
  String get event_chat_sender_stranger;

  /// No description provided for @event_scorers_goals.
  ///
  /// In zh, this message translates to:
  /// **'进球'**
  String get event_scorers_goals;

  /// No description provided for @event_rating_n_voters_inline.
  ///
  /// In zh, this message translates to:
  /// **'{n}人评'**
  String event_rating_n_voters_inline(int n);

  /// No description provided for @event_rating_empty_go_rate.
  ///
  /// In zh, this message translates to:
  /// **'还没有评分 · 去评赛后场次'**
  String get event_rating_empty_go_rate;

  /// No description provided for @event_rating_player_detail.
  ///
  /// In zh, this message translates to:
  /// **'球员评分详情'**
  String get event_rating_player_detail;

  /// No description provided for @event_prize_pending.
  ///
  /// In zh, this message translates to:
  /// **'奖金待定'**
  String get event_prize_pending;

  /// No description provided for @event_prize_wan.
  ///
  /// In zh, this message translates to:
  /// **'奖金 ¥{amount}万'**
  String event_prize_wan(String amount);

  /// No description provided for @event_deadline_md_suffix.
  ///
  /// In zh, this message translates to:
  /// **'{md} 截止'**
  String event_deadline_md_suffix(String md);

  /// No description provided for @event_row_teams_label.
  ///
  /// In zh, this message translates to:
  /// **'报名队伍'**
  String get event_row_teams_label;

  /// No description provided for @event_row_status_label.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get event_row_status_label;

  /// No description provided for @player_card_rating.
  ///
  /// In zh, this message translates to:
  /// **'评分'**
  String get player_card_rating;

  /// No description provided for @player_card_mp.
  ///
  /// In zh, this message translates to:
  /// **'出场'**
  String get player_card_mp;

  /// No description provided for @team_card_summary.
  ///
  /// In zh, this message translates to:
  /// **'战绩'**
  String get team_card_summary;

  /// No description provided for @team_card_gf.
  ///
  /// In zh, this message translates to:
  /// **'进球'**
  String get team_card_gf;

  /// No description provided for @team_card_ga.
  ///
  /// In zh, this message translates to:
  /// **'失球'**
  String get team_card_ga;

  /// No description provided for @team_card_gd.
  ///
  /// In zh, this message translates to:
  /// **'净胜'**
  String get team_card_gd;

  /// No description provided for @team_card_matches.
  ///
  /// In zh, this message translates to:
  /// **'比赛'**
  String get team_card_matches;

  /// No description provided for @wc_hero_title.
  ///
  /// In zh, this message translates to:
  /// **'世界杯专区'**
  String get wc_hero_title;

  /// No description provided for @wc_hero_sub.
  ///
  /// In zh, this message translates to:
  /// **'小组赛 · 第 2 轮 · 今晚 5 场直播'**
  String get wc_hero_sub;

  /// No description provided for @wc_focus_battle.
  ///
  /// In zh, this message translates to:
  /// **'焦点之战 · 直播中'**
  String get wc_focus_battle;

  /// No description provided for @wc_focus_halftime.
  ///
  /// In zh, this message translates to:
  /// **'{minute} · 下半场'**
  String wc_focus_halftime(String minute);

  /// No description provided for @wc_focus_watch_count.
  ///
  /// In zh, this message translates to:
  /// **'{n} 观看'**
  String wc_focus_watch_count(String n);

  /// No description provided for @wc_team_argentina.
  ///
  /// In zh, this message translates to:
  /// **'阿根廷'**
  String get wc_team_argentina;

  /// No description provided for @wc_team_brazil.
  ///
  /// In zh, this message translates to:
  /// **'巴西'**
  String get wc_team_brazil;

  /// No description provided for @wc_team_argentina_win.
  ///
  /// In zh, this message translates to:
  /// **'阿根廷胜'**
  String get wc_team_argentina_win;

  /// No description provided for @wc_team_draw.
  ///
  /// In zh, this message translates to:
  /// **'平'**
  String get wc_team_draw;

  /// No description provided for @wc_team_brazil_win.
  ///
  /// In zh, this message translates to:
  /// **'巴西胜'**
  String get wc_team_brazil_win;

  /// No description provided for @pickup_map_title_city.
  ///
  /// In zh, this message translates to:
  /// **'约球 · {city}'**
  String pickup_map_title_city(String city);

  /// No description provided for @pickup_map_legend_open.
  ///
  /// In zh, this message translates to:
  /// **'招人中'**
  String get pickup_map_legend_open;

  /// No description provided for @pickup_map_legend_almost.
  ///
  /// In zh, this message translates to:
  /// **'即将满员'**
  String get pickup_map_legend_almost;

  /// No description provided for @pickup_map_legend_full.
  ///
  /// In zh, this message translates to:
  /// **'已满'**
  String get pickup_map_legend_full;

  /// No description provided for @pickup_map_sort_distance.
  ///
  /// In zh, this message translates to:
  /// **'按距离排序'**
  String get pickup_map_sort_distance;

  /// No description provided for @pickup_map_need_short.
  ///
  /// In zh, this message translates to:
  /// **'缺{n}'**
  String pickup_map_need_short(int n);

  /// No description provided for @pickup_map_full_short.
  ///
  /// In zh, this message translates to:
  /// **'满'**
  String get pickup_map_full_short;

  /// No description provided for @level_any.
  ///
  /// In zh, this message translates to:
  /// **'不限'**
  String get level_any;

  /// No description provided for @level_beginner.
  ///
  /// In zh, this message translates to:
  /// **'新手'**
  String get level_beginner;

  /// No description provided for @level_novice.
  ///
  /// In zh, this message translates to:
  /// **'初级'**
  String get level_novice;

  /// No description provided for @level_mid.
  ///
  /// In zh, this message translates to:
  /// **'中级'**
  String get level_mid;

  /// No description provided for @level_pro.
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get level_pro;

  /// No description provided for @field_5.
  ///
  /// In zh, this message translates to:
  /// **'5人制'**
  String get field_5;

  /// No description provided for @field_7.
  ///
  /// In zh, this message translates to:
  /// **'7人制'**
  String get field_7;

  /// No description provided for @field_8.
  ///
  /// In zh, this message translates to:
  /// **'8人制'**
  String get field_8;

  /// No description provided for @field_11.
  ///
  /// In zh, this message translates to:
  /// **'11人制'**
  String get field_11;

  /// No description provided for @pickup_detail_open_need_n.
  ///
  /// In zh, this message translates to:
  /// **'招人中 · 缺 {n} 人'**
  String pickup_detail_open_need_n(int n);

  /// No description provided for @pickup_detail_formation_title.
  ///
  /// In zh, this message translates to:
  /// **'阵型 · {formation}'**
  String pickup_detail_formation_title(String formation);

  /// No description provided for @pickup_detail_slots_filled_of.
  ///
  /// In zh, this message translates to:
  /// **'/{total} 已到位'**
  String pickup_detail_slots_filled_of(int total);

  /// No description provided for @pickup_detail_details.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get pickup_detail_details;

  /// No description provided for @pickup_detail_detail_level.
  ///
  /// In zh, this message translates to:
  /// **'水平要求'**
  String get pickup_detail_detail_level;

  /// No description provided for @pickup_detail_detail_headcount.
  ///
  /// In zh, this message translates to:
  /// **'人数'**
  String get pickup_detail_detail_headcount;

  /// No description provided for @pickup_detail_detail_field.
  ///
  /// In zh, this message translates to:
  /// **'场地'**
  String get pickup_detail_detail_field;

  /// No description provided for @pickup_detail_detail_parking.
  ///
  /// In zh, this message translates to:
  /// **'停车'**
  String get pickup_detail_detail_parking;

  /// No description provided for @pickup_detail_location.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get pickup_detail_location;

  /// No description provided for @pickup_detail_location_km.
  ///
  /// In zh, this message translates to:
  /// **'位置 · 距你 {km}km'**
  String pickup_detail_location_km(String km);

  /// No description provided for @pickup_detail_navigate.
  ///
  /// In zh, this message translates to:
  /// **'导航'**
  String get pickup_detail_navigate;

  /// No description provided for @pickup_detail_nav_chooser_title.
  ///
  /// In zh, this message translates to:
  /// **'选择导航应用'**
  String get pickup_detail_nav_chooser_title;

  /// No description provided for @pickup_detail_nav_amap.
  ///
  /// In zh, this message translates to:
  /// **'高德地图'**
  String get pickup_detail_nav_amap;

  /// No description provided for @pickup_detail_nav_baidu.
  ///
  /// In zh, this message translates to:
  /// **'百度地图'**
  String get pickup_detail_nav_baidu;

  /// No description provided for @pickup_detail_nav_system.
  ///
  /// In zh, this message translates to:
  /// **'系统地图'**
  String get pickup_detail_nav_system;

  /// No description provided for @pickup_detail_nav_none.
  ///
  /// In zh, this message translates to:
  /// **'未找到可用的地图应用'**
  String get pickup_detail_nav_none;

  /// No description provided for @pickup_detail_aa_fee.
  ///
  /// In zh, this message translates to:
  /// **'AA 费用'**
  String get pickup_detail_aa_fee;

  /// No description provided for @pickup_detail_not_signed_in.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get pickup_detail_not_signed_in;

  /// No description provided for @pickup_detail_join_failed.
  ///
  /// In zh, this message translates to:
  /// **'报名失败：{err}'**
  String pickup_detail_join_failed(String err);

  /// No description provided for @pickup_detail_formation_load_failed.
  ///
  /// In zh, this message translates to:
  /// **'阵型加载失败'**
  String get pickup_detail_formation_load_failed;

  /// No description provided for @pickup_detail_host_stats.
  ///
  /// In zh, this message translates to:
  /// **'发起过 {n} 场 · 准时率 {rate}%'**
  String pickup_detail_host_stats(int n, int rate);

  /// No description provided for @messages_thread_default_title.
  ///
  /// In zh, this message translates to:
  /// **'对话'**
  String get messages_thread_default_title;

  /// No description provided for @messages_kind_group.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get messages_kind_group;

  /// No description provided for @messages_kind_dm.
  ///
  /// In zh, this message translates to:
  /// **'私信'**
  String get messages_kind_dm;

  /// No description provided for @chat_default_group_title.
  ///
  /// In zh, this message translates to:
  /// **'开球 · 新手大厅'**
  String get chat_default_group_title;

  /// No description provided for @chat_sender_system.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get chat_sender_system;

  /// No description provided for @auth_guest_prefix.
  ///
  /// In zh, this message translates to:
  /// **'游客-'**
  String get auth_guest_prefix;

  /// No description provided for @auth_terms_notice.
  ///
  /// In zh, this message translates to:
  /// **'继续即表示同意服务条款 · 隐私政策'**
  String get auth_terms_notice;

  /// No description provided for @create_event_tpl_group8_desc_inline.
  ///
  /// In zh, this message translates to:
  /// **'2组4队 单循环 + 交叉淘汰'**
  String get create_event_tpl_group8_desc_inline;

  /// No description provided for @create_event_hint_not_logged.
  ///
  /// In zh, this message translates to:
  /// **'请先登录'**
  String get create_event_hint_not_logged;

  /// No description provided for @create_event_preview_prize_wan.
  ///
  /// In zh, this message translates to:
  /// **'¥{amount}万'**
  String create_event_preview_prize_wan(String amount);

  /// No description provided for @rate_pitch_title.
  ///
  /// In zh, this message translates to:
  /// **'给本局打分'**
  String get rate_pitch_title;

  /// No description provided for @rate_pitch_progress.
  ///
  /// In zh, this message translates to:
  /// **'{done}/{total} 已评'**
  String rate_pitch_progress(int done, int total);

  /// No description provided for @rate_pitch_tap_hint.
  ///
  /// In zh, this message translates to:
  /// **'点球员打分'**
  String get rate_pitch_tap_hint;

  /// No description provided for @rate_pitch_save_next.
  ///
  /// In zh, this message translates to:
  /// **'保存 · 下一个'**
  String get rate_pitch_save_next;

  /// No description provided for @rate_pitch_submit_n.
  ///
  /// In zh, this message translates to:
  /// **'提交 ({n})'**
  String rate_pitch_submit_n(int n);

  /// No description provided for @rate_pitch_cannot_self.
  ///
  /// In zh, this message translates to:
  /// **'不能给自己打分'**
  String get rate_pitch_cannot_self;

  /// No description provided for @rate_pitch_empty_title.
  ///
  /// In zh, this message translates to:
  /// **'还没有队友加入'**
  String get rate_pitch_empty_title;

  /// No description provided for @rate_pitch_empty_sub.
  ///
  /// In zh, this message translates to:
  /// **'等其他人报名后再来打分'**
  String get rate_pitch_empty_sub;

  /// No description provided for @rate_pitch_empty_back.
  ///
  /// In zh, this message translates to:
  /// **'返回球局'**
  String get rate_pitch_empty_back;

  /// No description provided for @rate_pitch_goals_label.
  ///
  /// In zh, this message translates to:
  /// **'进球'**
  String get rate_pitch_goals_label;

  /// No description provided for @rate_pitch_assists_label.
  ///
  /// In zh, this message translates to:
  /// **'助攻'**
  String get rate_pitch_assists_label;

  /// No description provided for @rate_pitch_pos_label.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get rate_pitch_pos_label;

  /// No description provided for @rate_pitch_not_registered.
  ///
  /// In zh, this message translates to:
  /// **'未注册球友'**
  String get rate_pitch_not_registered;

  /// No description provided for @rate_pitch_submitted_n.
  ///
  /// In zh, this message translates to:
  /// **'已提交 {n} 条评分'**
  String rate_pitch_submitted_n(int n);

  /// No description provided for @rate_pitch_rate_teammates_cta.
  ///
  /// In zh, this message translates to:
  /// **'给本局打分'**
  String get rate_pitch_rate_teammates_cta;

  /// No description provided for @match_detail_title.
  ///
  /// In zh, this message translates to:
  /// **'比赛详情'**
  String get match_detail_title;

  /// No description provided for @match_status_upcoming.
  ///
  /// In zh, this message translates to:
  /// **'未开始'**
  String get match_status_upcoming;

  /// No description provided for @match_status_live.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get match_status_live;

  /// No description provided for @match_status_done.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get match_status_done;

  /// No description provided for @match_goals_section.
  ///
  /// In zh, this message translates to:
  /// **'进球'**
  String get match_goals_section;

  /// No description provided for @match_goals_empty.
  ///
  /// In zh, this message translates to:
  /// **'暂无进球'**
  String get match_goals_empty;

  /// No description provided for @match_cta_rate.
  ///
  /// In zh, this message translates to:
  /// **'去评分'**
  String get match_cta_rate;

  /// No description provided for @match_cta_view_ratings.
  ///
  /// In zh, this message translates to:
  /// **'查看本场评分'**
  String get match_cta_view_ratings;

  /// No description provided for @match_cta_remind.
  ///
  /// In zh, this message translates to:
  /// **'赛前提醒'**
  String get match_cta_remind;

  /// No description provided for @match_cta_reminded.
  ///
  /// In zh, this message translates to:
  /// **'已设置提醒'**
  String get match_cta_reminded;

  /// No description provided for @match_ratings_title.
  ///
  /// In zh, this message translates to:
  /// **'本场评分'**
  String get match_ratings_title;

  /// No description provided for @match_ratings_go_rate.
  ///
  /// In zh, this message translates to:
  /// **'我也来评一下'**
  String get match_ratings_go_rate;

  /// No description provided for @match_own_goal.
  ///
  /// In zh, this message translates to:
  /// **'乌龙'**
  String get match_own_goal;

  /// No description provided for @match_penalty.
  ///
  /// In zh, this message translates to:
  /// **'点球'**
  String get match_penalty;

  /// No description provided for @match_assist_by.
  ///
  /// In zh, this message translates to:
  /// **'助攻 {name}'**
  String match_assist_by(String name);

  /// No description provided for @match_not_found.
  ///
  /// In zh, this message translates to:
  /// **'未找到该比赛'**
  String get match_not_found;

  /// No description provided for @event_standings_leaders_label.
  ///
  /// In zh, this message translates to:
  /// **'榜首之争'**
  String get event_standings_leaders_label;

  /// No description provided for @event_standings_leader_top.
  ///
  /// In zh, this message translates to:
  /// **'榜首'**
  String get event_standings_leader_top;

  /// No description provided for @event_standings_leader_runner.
  ///
  /// In zh, this message translates to:
  /// **'次席'**
  String get event_standings_leader_runner;

  /// No description provided for @event_standings_points_diff.
  ///
  /// In zh, this message translates to:
  /// **'积分差 {n}'**
  String event_standings_points_diff(int n);

  /// No description provided for @event_scorers_golden_boot.
  ///
  /// In zh, this message translates to:
  /// **'金靴得主'**
  String get event_scorers_golden_boot;

  /// No description provided for @event_scorers_per_match.
  ///
  /// In zh, this message translates to:
  /// **'场均 {avg} 球'**
  String event_scorers_per_match(String avg);

  /// No description provided for @messages_new_dm.
  ///
  /// In zh, this message translates to:
  /// **'发起私聊'**
  String get messages_new_dm;

  /// No description provided for @messages_new_dm_hint.
  ///
  /// In zh, this message translates to:
  /// **'输入对方 @handle'**
  String get messages_new_dm_hint;

  /// No description provided for @messages_new_dm_not_found.
  ///
  /// In zh, this message translates to:
  /// **'用户不存在'**
  String get messages_new_dm_not_found;

  /// No description provided for @messages_new_dm_cant_self.
  ///
  /// In zh, this message translates to:
  /// **'不能和自己私聊'**
  String get messages_new_dm_cant_self;

  /// No description provided for @pickup_map_location_disabled.
  ///
  /// In zh, this message translates to:
  /// **'定位服务未开启'**
  String get pickup_map_location_disabled;

  /// No description provided for @pickup_map_location_denied.
  ///
  /// In zh, this message translates to:
  /// **'定位权限被拒绝，请在设置中开启'**
  String get pickup_map_location_denied;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'zh':
      return AppL10nZh();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
