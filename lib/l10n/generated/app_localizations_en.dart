// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get app_name => 'GameOn';

  @override
  String get tab_home => 'Home';

  @override
  String get tab_pickup => 'Pickup';

  @override
  String get tab_events => 'Events';

  @override
  String get tab_me => 'Me';

  @override
  String get inbox_title => 'Inbox';

  @override
  String get inbox_tab_messages => 'Messages';

  @override
  String get inbox_tab_notifications => 'Notifications';

  @override
  String get common_back => 'Back';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_save => 'Save';

  @override
  String get common_submit => 'Submit';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_share => 'Share';

  @override
  String get common_close => 'Close';

  @override
  String get common_done => 'Done';

  @override
  String get common_retry => 'Retry';

  @override
  String get common_loading => 'Loading…';

  @override
  String get common_next => 'Next';

  @override
  String get common_prev => 'Back';

  @override
  String get common_finish => 'Finish';

  @override
  String get common_send => 'Send';

  @override
  String get common_search => 'Search';

  @override
  String get common_filter => 'Filter';

  @override
  String get common_more => 'More';

  @override
  String get common_new => 'New';

  @override
  String get common_yes => 'Yes';

  @override
  String get common_no => 'No';

  @override
  String get common_required => 'Required';

  @override
  String get common_optional => 'Optional';

  @override
  String get common_default => 'Default';

  @override
  String get common_follow => 'Follow';

  @override
  String get common_unfollow => 'Following';

  @override
  String get common_favorite => 'Favorite';

  @override
  String get common_unfavorite => 'Favorited';

  @override
  String get common_all => 'All';

  @override
  String get common_today => 'Today';

  @override
  String get common_tomorrow => 'Tomorrow';

  @override
  String get common_this_week => 'This Week';

  @override
  String get common_unread => 'Unread';

  @override
  String get common_pin => 'Pin';

  @override
  String get common_unpin => 'Unpin';

  @override
  String get common_mute => 'Mute';

  @override
  String get common_unmute => 'Unmute';

  @override
  String get common_report => 'Report';

  @override
  String get common_copy => 'Copy';

  @override
  String get common_copied => 'Copied';

  @override
  String get common_version => 'Version';

  @override
  String get error_load_failed => 'Load failed';

  @override
  String get error_network => 'Network error, please retry';

  @override
  String get error_required_field => 'This field is required';

  @override
  String get error_invalid_email => 'Invalid email';

  @override
  String get error_password_too_short =>
      'Password must be at least 6 characters';

  @override
  String get error_not_integer => 'Enter an integer';

  @override
  String get error_invalid_date => 'Invalid date (YYYY-MM-DD)';

  @override
  String get error_please_login => 'Please sign in first';

  @override
  String get error_unknown => 'Something went wrong';

  @override
  String get empty_no_data => 'No data';

  @override
  String get empty_no_events => 'No events yet';

  @override
  String get empty_no_events_sub => 'Tap the plus button to create one';

  @override
  String get empty_no_pickups => 'No pickups yet';

  @override
  String get empty_no_pickups_sub => 'Adjust filters or host a new one';

  @override
  String get empty_no_messages => 'No conversations';

  @override
  String get empty_no_messages_sub => 'Meet more players via pickups & events';

  @override
  String get empty_no_favorites => 'No favorites yet';

  @override
  String get empty_no_favorites_sub =>
      'Tap the favorite button on anything you like';

  @override
  String get empty_no_teams => 'No teams yet';

  @override
  String get empty_no_teams_sub => 'Create your first team';

  @override
  String get empty_no_notifications => 'No notifications';

  @override
  String get empty_no_search => 'No results found';

  @override
  String get empty_no_rating => 'No ratings yet';

  @override
  String get empty_no_rating_sub => 'Rate your latest match';

  @override
  String get home_live_now => 'Live Now';

  @override
  String get home_view_all => 'View all';

  @override
  String get home_local_feed => 'Local Feed';

  @override
  String get home_feed_pickup => 'Pickup';

  @override
  String get home_feed_result => 'Result';

  @override
  String get home_feed_all => 'All';

  @override
  String get home_rate_cta_title => 'You have matches to rate';

  @override
  String home_rate_cta_sub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count teammates waiting',
      one: '1 teammate waiting',
      zero: 'none',
    );
    return '$_temp0';
  }

  @override
  String get home_no_live => 'No live matches';

  @override
  String get home_bottom_of_feed => '— You\'re all caught up —';

  @override
  String get home_loading_pickups => 'Loading pickups…';

  @override
  String get sport_football => 'Football';

  @override
  String get sport_basketball => 'Basketball';

  @override
  String get sport_badminton => 'Badminton';

  @override
  String get sport_pingpong => 'Table Tennis';

  @override
  String get sport_cycling => 'Cycling';

  @override
  String pickup_title(String city) {
    return 'Pickup · $city';
  }

  @override
  String get pickup_filter_today => 'Today';

  @override
  String get pickup_filter_tomorrow => 'Tomorrow';

  @override
  String get pickup_filter_week => 'This Week';

  @override
  String get pickup_filter_mid => 'Mid';

  @override
  String get pickup_filter_cheap => '≤¥50';

  @override
  String get pickup_filter_near => '< 3 km';

  @override
  String get pickup_filter_title => 'Filters';

  @override
  String get pickup_filter_distance => 'Distance';

  @override
  String get pickup_filter_fee => 'Fee';

  @override
  String get pickup_filter_level => 'Level';

  @override
  String get pickup_filter_time => 'Time';

  @override
  String get pickup_filter_apply => 'Apply';

  @override
  String get pickup_filter_reset => 'Reset';

  @override
  String get pickup_status_open => 'Open';

  @override
  String get pickup_status_almost => 'Almost Full';

  @override
  String get pickup_status_full => 'Full';

  @override
  String pickup_city_pickup_count(int n) {
    return '$n pickups nearby';
  }

  @override
  String get pickup_sort_by_distance => 'By distance';

  @override
  String pickup_need_n(int n) {
    return '$n left';
  }

  @override
  String get pickup_detail_organizer => 'Organizer';

  @override
  String get pickup_detail_formation => 'Formation';

  @override
  String get pickup_detail_match_info => 'Match Info';

  @override
  String get pickup_detail_fee => 'Fee';

  @override
  String get pickup_detail_duration => 'Duration';

  @override
  String get pickup_detail_level => 'Level';

  @override
  String get pickup_detail_field_type => 'Field';

  @override
  String get pickup_detail_join_cta => 'Join Now';

  @override
  String get pickup_detail_select_position => 'Pick Position';

  @override
  String pickup_detail_confirm_position(String pos) {
    return 'Confirm $pos';
  }

  @override
  String get pickup_detail_already_joined => 'Joined';

  @override
  String get pickup_detail_full_cta => 'Full';

  @override
  String get pickup_detail_tap_empty_slot =>
      'Tap any empty spot in the formation to pick a position';

  @override
  String get pickup_detail_contact_organizer => 'Contact organizer';

  @override
  String get pickup_create_title => 'Host Pickup';

  @override
  String get pickup_create_venue => 'Venue';

  @override
  String get pickup_create_address => 'Street address (optional)';

  @override
  String get pickup_create_address_hint =>
      'Full address — helps teammates navigate';

  @override
  String get pickup_create_start_at => 'Start time';

  @override
  String get pickup_create_duration_min => 'Duration (min)';

  @override
  String get pickup_create_total => 'Total slots';

  @override
  String get pickup_create_fee => 'Fee (CNY)';

  @override
  String get pickup_create_level => 'Level';

  @override
  String get pickup_create_formation => 'Formation';

  @override
  String get pickup_create_field_type => 'Field type';

  @override
  String get pickup_create_submit => 'Publish Pickup';

  @override
  String get pickup_create_success => 'Pickup published';

  @override
  String get events_title => 'Events';

  @override
  String get events_create => 'Create Event';

  @override
  String get events_tab_ongoing => 'Ongoing';

  @override
  String get events_tab_registering => 'Open';

  @override
  String get events_tab_watch => 'Watch';

  @override
  String get events_watch_today => 'Today · Following';

  @override
  String get events_wc_banner_title => 'FIFA World Cup 2026';

  @override
  String get events_wc_banner_sub =>
      'Group Stage · Round 2 · 5 live matches tonight';

  @override
  String get events_wc_live_now => 'Live now';

  @override
  String get events_wc_predicts => 'Local predicts';

  @override
  String get events_pro => 'Professional';

  @override
  String get event_status_ongoing => 'Ongoing';

  @override
  String get event_status_registering => 'Registering';

  @override
  String get event_status_done => 'Finished';

  @override
  String get event_kpi_teams => 'Teams';

  @override
  String get event_kpi_matches => 'Matches';

  @override
  String get event_kpi_prize => 'Prize';

  @override
  String get event_kpi_viewers => 'Viewers';

  @override
  String get event_tab_overview => 'Overview';

  @override
  String get event_tab_bracket => 'Bracket';

  @override
  String get event_tab_standings => 'Standings';

  @override
  String get event_tab_scorers => 'Scorers';

  @override
  String get event_tab_ratings => 'Ratings';

  @override
  String get event_tab_chat => 'Chat';

  @override
  String get event_overview_rules => 'Rules';

  @override
  String get event_overview_organizer => 'Organizer';

  @override
  String get event_bracket_qf => 'Quarter-finals';

  @override
  String get event_bracket_sf => 'Semi-finals';

  @override
  String get event_bracket_final => 'Final';

  @override
  String get event_bracket_champion => 'Champion';

  @override
  String get event_bracket_tbd => 'TBD';

  @override
  String get event_bracket_empty => 'No matches scheduled yet';

  @override
  String get event_standings_rank => '#';

  @override
  String get event_standings_team => 'Team';

  @override
  String get event_standings_wins => 'W';

  @override
  String get event_standings_draws => 'D';

  @override
  String get event_standings_losses => 'L';

  @override
  String get event_standings_points => 'Pts';

  @override
  String get event_standings_empty => 'No results yet';

  @override
  String get event_cta_watch_live => 'Watch Live';

  @override
  String get event_cta_register => 'Register';

  @override
  String get event_cta_registered => 'Registered';

  @override
  String get event_chat_hint => 'Send a message…';

  @override
  String get event_chat_send => 'Send';

  @override
  String get event_register_form_title => 'Register team';

  @override
  String get event_register_team_name => 'Team name';

  @override
  String get event_register_contact => 'Contact';

  @override
  String get event_register_phone => 'Phone';

  @override
  String get event_register_submit => 'Submit';

  @override
  String get event_register_success => 'Submitted · awaiting review';

  @override
  String get event_rating_team_all => 'All';

  @override
  String get event_rating_mvp => 'MVP';

  @override
  String get event_rating_tap_for_detail => '· Tap a player for details ·';

  @override
  String event_rating_players_voted(int n) {
    return '$n voters';
  }

  @override
  String get event_rating_score_avg => 'Avg';

  @override
  String get event_rating_distribution => 'Distribution · sample';

  @override
  String get event_rating_hot_comments => 'Top comments · sample';

  @override
  String get event_rating_sort_hot => 'By popularity';

  @override
  String get event_rating_reply => 'Reply';

  @override
  String get create_event_title => 'Create Event';

  @override
  String create_event_step_n_of(int cur, int total) {
    return 'Step $cur of $total';
  }

  @override
  String get create_event_step_template => 'Template';

  @override
  String get create_event_step_basic => 'Details';

  @override
  String get create_event_step_registration => 'Registration';

  @override
  String get create_event_step_preview => 'Preview';

  @override
  String get create_event_tpl_title => 'Pick a template';

  @override
  String get create_event_tpl_subtitle => 'Defines your bracket; tweak later';

  @override
  String get create_event_tpl_group8 => '8-team group';

  @override
  String get create_event_tpl_group8_desc => '2 groups × 4 + knockout';

  @override
  String get create_event_tpl_knockout16 => '16-team KO';

  @override
  String get create_event_tpl_knockout16_desc =>
      'Single elimination · 4 rounds';

  @override
  String get create_event_tpl_wc => 'World-Cup style';

  @override
  String get create_event_tpl_wc_desc => '32 teams · 8 groups + knockout';

  @override
  String get create_event_tpl_league => 'League';

  @override
  String get create_event_tpl_league_desc => 'Home & away, round-robin';

  @override
  String get create_event_f_name => 'Event name';

  @override
  String get create_event_f_start => 'Start date';

  @override
  String get create_event_f_end => 'End date';

  @override
  String get create_event_f_venue => 'Venue';

  @override
  String get create_event_f_fee => 'Entry fee / team';

  @override
  String get create_event_f_prize => 'Prize pool';

  @override
  String get create_event_f_deadline => 'Registration deadline';

  @override
  String get create_event_f_teamsize => 'Players per team';

  @override
  String get create_event_f_maxteams => 'Max teams';

  @override
  String get create_event_review_title => 'Review mode';

  @override
  String get create_event_review_auto => 'Auto approve';

  @override
  String get create_event_review_manual => 'Manual review';

  @override
  String get create_event_organizer_tip_title => 'Organizer tip';

  @override
  String get create_event_organizer_tip_body =>
      'Reserve at least 3 days for review. Event config can\'t be edited once started.';

  @override
  String get create_event_preview_subtitle =>
      'Publish and open registration once confirmed';

  @override
  String get create_event_preview_config_ok =>
      'Config complete, ready to publish';

  @override
  String get create_event_cta_next => 'Next';

  @override
  String get create_event_cta_prev => 'Back';

  @override
  String get create_event_cta_publish => 'Publish';

  @override
  String get create_event_cta_publishing => 'Publishing…';

  @override
  String get create_event_save_draft => 'Save draft';

  @override
  String get create_event_draft_saved => 'Draft saved';

  @override
  String get create_event_draft_loaded => 'Draft restored';

  @override
  String get create_event_published => 'Event published';

  @override
  String create_event_publish_failed(String err) {
    return 'Failed: $err';
  }

  @override
  String create_event_preview_registered_of_max(String max, String deadline) {
    return '0/$max registered · closes $deadline';
  }

  @override
  String get wc_title => 'World Cup';

  @override
  String get wc_subtitle => 'Group Stage · Round 2 · 5 matches live tonight';

  @override
  String get wc_focus => 'Featured · Live';

  @override
  String wc_viewers(String v) {
    return '$v viewers';
  }

  @override
  String get wc_predict_bar_title => 'Local predicts · W / D / L';

  @override
  String get wc_today_schedule => 'Today\'s schedule';

  @override
  String get wc_btn_watch_live => 'Watch Live';

  @override
  String get wc_btn_predict => 'Predict';

  @override
  String get wc_btn_remind => 'Remind';

  @override
  String get wc_btn_danmaku_on => 'Danmaku On';

  @override
  String get wc_btn_danmaku_off => 'Danmaku Off';

  @override
  String get wc_remind_set =>
      'Reminder set · we\'ll notify you 10 min before kickoff';

  @override
  String get wc_remind_unset => 'Reminder removed';

  @override
  String get wc_remind_sheet_title => 'Pre-match reminder';

  @override
  String get wc_remind_sheet_sub => 'How far ahead?';

  @override
  String wc_remind_option_min(int n) {
    return '$n min';
  }

  @override
  String wc_remind_option_hour(int n) {
    return '$n hr';
  }

  @override
  String get wc_remind_cancel => 'Cancel reminder';

  @override
  String wc_remind_set_n_min(int n) {
    return 'Reminder set · we\'ll notify you $n min before kickoff';
  }

  @override
  String get wc_remind_default_badge => 'default';

  @override
  String get wc_live_title => 'Live';

  @override
  String get wc_live_input_hint => 'Send a danmu…';

  @override
  String wc_live_viewer_count(String n) {
    return '$n watching';
  }

  @override
  String get wc_live_back_to_feed => 'Back';

  @override
  String get wc_live_half_time => '2nd Half';

  @override
  String get wc_live_comment_ph => 'What\'s happening? Join the chat';

  @override
  String get wc_live_loading => 'Connecting to stream…';

  @override
  String get wc_live_signal_weak => 'Weak stream signal';

  @override
  String get wc_live_tap_retry => 'Tap to retry';

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
  String get wc_predict_title => 'Predict';

  @override
  String get wc_predict_pick_title => 'Your pick?';

  @override
  String get wc_predict_home_win => 'Home Win';

  @override
  String get wc_predict_draw => 'Draw';

  @override
  String get wc_predict_away_win => 'Away Win';

  @override
  String get wc_predict_stake => 'Stake';

  @override
  String get wc_predict_submit => 'Submit Prediction';

  @override
  String get wc_predict_submitted => 'Submitted · settles after match';

  @override
  String wc_predict_change(String choice) {
    return 'Picked: $choice';
  }

  @override
  String get wc_predict_distribution => 'Global distribution';

  @override
  String get wc_predict_you_picked => 'Your pick';

  @override
  String get messages_title => 'Messages';

  @override
  String get messages_empty_title => 'No conversations';

  @override
  String get messages_empty_sub => 'Find more players in Pickup & Events';

  @override
  String get messages_new_sheet_title => 'New';

  @override
  String get messages_new_group => 'New group';

  @override
  String get messages_new_group_title_hint => 'Group name';

  @override
  String get messages_new_created => 'Conversation created';

  @override
  String get messages_new_failed => 'Failed to create';

  @override
  String get messages_long_press_actions_mark_read => 'Mark read';

  @override
  String get messages_long_press_actions_mark_unread => 'Mark unread';

  @override
  String get messages_long_press_actions_delete => 'Delete';

  @override
  String get messages_delete_confirm => 'Delete this conversation?';

  @override
  String get messages_deleted => 'Deleted';

  @override
  String get chat_hint => 'Say something…';

  @override
  String get chat_send_failed => 'Send failed';

  @override
  String get chat_attachment_image => 'Image';

  @override
  String get chat_attachment_location => 'Location';

  @override
  String get chat_attachment_invite => 'Pickup invite';

  @override
  String get chat_attachment_system_placeholder => '[system message]';

  @override
  String get chat_more_members => 'Members';

  @override
  String get chat_more_clear_history => 'Clear history';

  @override
  String get chat_more_mute => 'Mute';

  @override
  String get chat_more_unmute => 'Unmute';

  @override
  String get chat_more_report => 'Report';

  @override
  String get chat_clear_confirm => 'Clear all messages?';

  @override
  String get chat_cleared => 'Cleared';

  @override
  String get profile_title => 'Me';

  @override
  String get profile_edit_btn => 'Edit';

  @override
  String get profile_archive_title => 'Player archive';

  @override
  String get profile_archive_new_badge => 'NEW';

  @override
  String get profile_mini_overall => 'OVR';

  @override
  String get profile_mini_matches => 'MP';

  @override
  String get profile_mini_goals => 'G';

  @override
  String get profile_mini_mvp => 'MVP';

  @override
  String get profile_section_activity => 'Activity';

  @override
  String get profile_section_settings => 'Settings';

  @override
  String get profile_menu_my_events => 'Events I joined';

  @override
  String get profile_menu_my_pickups => 'Pickups I hosted';

  @override
  String get profile_menu_my_teams => 'My teams';

  @override
  String get profile_menu_favorites => 'Favorites';

  @override
  String get profile_menu_account => 'Account';

  @override
  String get profile_menu_notif => 'Notifications';

  @override
  String get profile_menu_help => 'Help & Feedback';

  @override
  String get profile_menu_about => 'About';

  @override
  String get profile_following => 'Following';

  @override
  String get profile_followers => 'Followers';

  @override
  String get me_following_title => 'Following & Followers';

  @override
  String get me_following_empty => 'Not following anyone yet';

  @override
  String get me_following_empty_sub => 'Discover more players';

  @override
  String get me_followers_empty => 'No followers yet';

  @override
  String get me_followers_empty_sub => 'Join more activities to meet players';

  @override
  String get profile_logout => 'Sign out';

  @override
  String get profile_logout_confirm => 'Sign out of GameOn?';

  @override
  String get archive_share => 'Share archive';

  @override
  String get archive_card_profile => 'Player Card · 2026';

  @override
  String get archive_card_overall => 'Overall';

  @override
  String get archive_flip_front => 'Tap card to flip front';

  @override
  String get archive_flip_back => 'Tap card to see radar';

  @override
  String get archive_rating_panel_title => 'My rating · last 30 days';

  @override
  String get archive_rating_rated => 'Votes';

  @override
  String get archive_rating_rank => 'Event rank';

  @override
  String get archive_rating_trend => 'Trend';

  @override
  String get archive_rating_go_rate => 'Rate';

  @override
  String get archive_season_data => 'Season stats';

  @override
  String get archive_goal_trend => 'Goals trend';

  @override
  String get archive_honors_title => 'Honors';

  @override
  String archive_honors_count(int n) {
    return '$n awards';
  }

  @override
  String get archive_teammates_title => 'Teammates';

  @override
  String archive_teammates_sub(int n) {
    return '$n frequent teammates';
  }

  @override
  String get archive_history_title => 'Match history';

  @override
  String get archive_radar_title => 'Attribute radar';

  @override
  String get archive_radar_flip_back => 'Tap to flip back';

  @override
  String archive_teammates_matches(int n) {
    return '$n MP';
  }

  @override
  String get archive_history_mvp => 'MVP';

  @override
  String archive_history_goals_n(int n) {
    return '$n G';
  }

  @override
  String archive_history_assists_n(int n) {
    return '$n A';
  }

  @override
  String get profile_edit_title => 'Edit profile';

  @override
  String get profile_edit_name => 'Display name';

  @override
  String get profile_edit_handle => 'Username';

  @override
  String get profile_edit_city => 'City';

  @override
  String get profile_edit_district => 'District';

  @override
  String get profile_edit_position => 'Position';

  @override
  String get profile_edit_position_full => 'Position name';

  @override
  String get profile_edit_height => 'Height (cm)';

  @override
  String get profile_edit_foot => 'Preferred foot';

  @override
  String get profile_edit_foot_left => 'Left';

  @override
  String get profile_edit_foot_right => 'Right';

  @override
  String get profile_edit_foot_both => 'Both';

  @override
  String get profile_edit_avatar => 'Avatar';

  @override
  String get profile_edit_avatar_hint =>
      'Tap to change (initials used for now)';

  @override
  String get profile_edit_save_ok => 'Saved';

  @override
  String get profile_edit_save_fail => 'Save failed';

  @override
  String get profile_edit_position_opt_gk => 'GK · Goalkeeper';

  @override
  String get profile_edit_position_opt_cb => 'CB · Center Back';

  @override
  String get profile_edit_position_opt_lb => 'LB · Left Back';

  @override
  String get profile_edit_position_opt_rb => 'RB · Right Back';

  @override
  String get profile_edit_position_opt_cm => 'CM · Center Mid';

  @override
  String get profile_edit_position_opt_cam => 'CAM · Attacking Mid';

  @override
  String get profile_edit_position_opt_cdm => 'CDM · Defensive Mid';

  @override
  String get profile_edit_position_opt_lw => 'LW · Left Wing';

  @override
  String get profile_edit_position_opt_rw => 'RW · Right Wing';

  @override
  String get profile_edit_position_opt_cf => 'CF · Center Forward';

  @override
  String get profile_edit_position_opt_st => 'ST · Striker';

  @override
  String get settings_account_title => 'Account';

  @override
  String get settings_account_language => 'Language';

  @override
  String get settings_account_profile => 'Edit profile';

  @override
  String get settings_account_email => 'Email';

  @override
  String get settings_account_password => 'Change password';

  @override
  String get settings_account_password_old => 'Current password';

  @override
  String get settings_account_password_new => 'New password';

  @override
  String get settings_account_password_confirm => 'Confirm new password';

  @override
  String get settings_account_password_updated => 'Password updated';

  @override
  String get settings_account_password_mismatch => 'Passwords don\'t match';

  @override
  String get settings_account_logout => 'Sign out';

  @override
  String get settings_account_delete => 'Delete account';

  @override
  String get settings_account_delete_confirm =>
      'Your data will be permanently removed. Continue?';

  @override
  String get settings_account_delete_done => 'Account deleted';

  @override
  String get settings_lang_title => 'Language';

  @override
  String get settings_lang_zh => 'Chinese (Simplified)';

  @override
  String get settings_lang_en => 'English';

  @override
  String get settings_lang_system => 'Follow system';

  @override
  String get settings_notif_title => 'Notifications';

  @override
  String get settings_notif_push => 'Push notifications';

  @override
  String get settings_notif_push_sub =>
      'Without push you won\'t get system alerts';

  @override
  String get settings_notif_inapp => 'In-app messages';

  @override
  String get settings_notif_inapp_sub => 'Chat, replies, system updates';

  @override
  String get settings_notif_email => 'Email alerts';

  @override
  String get settings_notif_email_sub => 'Critical updates to your inbox';

  @override
  String get settings_notif_match_reminder => 'Match reminders';

  @override
  String get settings_notif_match_reminder_sub => '10 min before kickoff';

  @override
  String get profile_menu_appearance => 'Appearance';

  @override
  String get settings_appearance_title => 'Appearance';

  @override
  String get appearance_theme_mode_section => 'Theme Mode';

  @override
  String get appearance_theme_mode_system => 'Follow System';

  @override
  String get appearance_theme_mode_light => 'Light';

  @override
  String get appearance_theme_mode_dark => 'Dark';

  @override
  String get appearance_accent_section => 'Accent Color';

  @override
  String get appearance_accent_green => 'Classic Green';

  @override
  String get appearance_accent_orange => 'Vibrant Orange';

  @override
  String get appearance_accent_cyan => 'Ocean Cyan';

  @override
  String get appearance_accent_red => 'Passion Red';

  @override
  String get appearance_accent_custom => 'Custom';

  @override
  String get appearance_preview_section => 'Preview';

  @override
  String get appearance_preview_card_title => 'Wed 7:30 PM · 5-a-side Football';

  @override
  String get appearance_preview_card_meta => 'Nanshan, Shenzhen · Starry Park';

  @override
  String get appearance_preview_card_cta => 'Join Now';

  @override
  String get appearance_picker_title => 'Pick Accent Color';

  @override
  String get appearance_picker_confirm => 'Confirm';

  @override
  String get appearance_picker_cancel => 'Cancel';

  @override
  String get settings_help_title => 'Help & Feedback';

  @override
  String get settings_help_faq => 'FAQ';

  @override
  String get settings_help_feedback => 'Tell us anything';

  @override
  String get settings_help_feedback_hint => 'Describe the issue or idea…';

  @override
  String get settings_help_feedback_submit => 'Submit';

  @override
  String get settings_help_feedback_thanks => 'Thanks, we got it';

  @override
  String get settings_help_faq_1_q => 'How do I host a pickup?';

  @override
  String get settings_help_faq_1_a =>
      'Go to the Pickup tab, tap the + at bottom right, fill in venue / time / slots to publish.';

  @override
  String get settings_help_faq_2_q =>
      'Can I withdraw after registering an event?';

  @override
  String get settings_help_faq_2_a =>
      'Withdraw anytime while still under review; contact organizer once approved.';

  @override
  String get settings_help_faq_3_q => 'How does rating work?';

  @override
  String get settings_help_faq_3_a =>
      'Within 72 h after each match, rate teammates/opponents 0–10; the final score is the average.';

  @override
  String get settings_help_faq_4_q => 'How do I claim my player archive?';

  @override
  String get settings_help_faq_4_a =>
      'Complete position / height / preferred foot in Me → Edit to activate the archive.';

  @override
  String get settings_help_faq_5_q => 'Which sports are supported?';

  @override
  String get settings_help_faq_5_a =>
      'Football, basketball, badminton, table tennis and cycling. More coming soon.';

  @override
  String get settings_help_faq_6_q => 'Forgot password?';

  @override
  String get settings_help_faq_6_a =>
      'Tap “Forgot password” on the sign-in page; we\'ll email a reset link.';

  @override
  String get settings_about_title => 'About';

  @override
  String get settings_about_version_label => 'Version';

  @override
  String get settings_about_tagline => 'Amateur sports, taken seriously';

  @override
  String get settings_about_team => 'Team';

  @override
  String get settings_about_team_body =>
      'GameOn is a community made by players who code. We believe amateur sports deserves proper records.';

  @override
  String get settings_about_legal => 'Legal';

  @override
  String get settings_about_terms => 'Terms of Service';

  @override
  String get settings_about_privacy => 'Privacy Policy';

  @override
  String get settings_about_contact => 'Contact';

  @override
  String get settings_about_email => 'hi@kaiqiu.app';

  @override
  String get legal_terms_title => 'Terms of Service';

  @override
  String get legal_privacy_title => 'Privacy Policy';

  @override
  String get legal_terms_body =>
      'Welcome to GameOn (the \"App\"). By registering or using this App you agree to these terms.\n\n1. Conduct: Please behave; illegal or harmful content is prohibited.\n2. Account security: You are responsible for your credentials and all activity under them.\n3. Content ownership: You own what you post, and grant the App a royalty-free license to use it within the service.\n4. Disclaimer: Offline activities carry real risk. Assess your condition and consider insurance.\n5. Updates: We may update these terms; new versions will be posted in-app.\n\nQuestions: hi@kaiqiu.app.';

  @override
  String get legal_privacy_body =>
      'Your privacy matters. A short summary of how GameOn collects and uses data.\n\n1. What we collect: sign-up info (email / name), location (with your permission, for local recommendations), match data you post.\n2. How we use it: to provide the service, improve experience, keep it safe, and analyze usage.\n3. Sharing: we don\'t sell personal data. Any sharing with providers is bound by equivalent confidentiality.\n4. Your rights: access, fix, export, or delete your data anytime.\n5. Security: we use industry-standard encryption and access controls.\n\nQuestions: hi@kaiqiu.app.';

  @override
  String get search_title => 'Search';

  @override
  String get search_hint => 'Search pickups / events / players / venues';

  @override
  String get search_recent => 'Recent';

  @override
  String get search_hot_tags => 'Hot tags';

  @override
  String get search_clear => 'Clear';

  @override
  String get search_result_pickups => 'Pickups';

  @override
  String get search_result_events => 'Events';

  @override
  String search_result_empty(String q) {
    return 'No results for \"$q\"';
  }

  @override
  String get notif_title => 'Notifications';

  @override
  String get notif_all => 'All';

  @override
  String get notif_unread => 'Unread';

  @override
  String get notif_mark_all_read => 'Mark all read';

  @override
  String get notif_group_system => 'System';

  @override
  String get notif_group_match => 'Match';

  @override
  String get notif_group_pickup => 'Pickup';

  @override
  String get notif_group_rating => 'Rating';

  @override
  String get notif_group_follow => 'Follow';

  @override
  String get notif_demo_welcome_t => 'Welcome to GameOn ⚽';

  @override
  String get notif_demo_welcome_b =>
      'Complete your archive to start the season.';

  @override
  String get notif_demo_rate_t => 'A match is waiting for your rating';

  @override
  String get notif_demo_rate_b =>
      'Longgang Cun-Chao · Wolves vs Black Horse FC — 3 teammates waiting.';

  @override
  String get notif_demo_pickup_t => 'Sat 19:30 pickup needs 1 more';

  @override
  String get notif_demo_pickup_b =>
      'Lianhuashan Football Field · Tap to see the formation.';

  @override
  String get notif_demo_event_t =>
      '2026 Longgang Summer Cup registration is open';

  @override
  String get notif_demo_event_b => '16-team KO, 20k prize, closes 05-25.';

  @override
  String get notif_demo_follow_t => 'LaoWang followed you';

  @override
  String get notif_demo_follow_b => 'Follow back to chat.';

  @override
  String get city_picker_title => 'Choose city';

  @override
  String get city_picker_hot => 'Popular';

  @override
  String get city_picker_all => 'All cities';

  @override
  String get city_picker_current => 'Current location';

  @override
  String get me_events_title => 'My events';

  @override
  String get me_events_tab_registered => 'Registered';

  @override
  String get me_events_tab_hosted => 'Hosted';

  @override
  String get me_events_tab_done => 'Finished';

  @override
  String get me_pickups_title => 'My pickups';

  @override
  String get me_pickups_tab_hosted => 'Hosted';

  @override
  String get me_pickups_tab_joined => 'Joined';

  @override
  String get me_teams_title => 'My teams';

  @override
  String get me_teams_create => 'New team';

  @override
  String get me_teams_create_name => 'Team name';

  @override
  String get me_teams_create_city => 'City';

  @override
  String get me_teams_create_sub => 'Bio';

  @override
  String get me_teams_create_submit => 'Create';

  @override
  String get me_teams_remove => 'Disband';

  @override
  String get me_teams_remove_confirm => 'Disband this team?';

  @override
  String get me_favorites_title => 'Favorites';

  @override
  String get me_favorites_tab_pickups => 'Pickups';

  @override
  String get me_favorites_tab_events => 'Events';

  @override
  String get me_favorites_tab_players => 'Players';

  @override
  String get auth_login_title => 'Welcome to GameOn';

  @override
  String get auth_login_sub => 'Let\'s play';

  @override
  String get auth_email => 'Email';

  @override
  String get auth_password => 'Password';

  @override
  String get auth_remember_me => 'Remember me';

  @override
  String get auth_forgot_password => 'Forgot password';

  @override
  String get auth_signup_toggle_new => 'Create account';

  @override
  String get auth_signup_toggle_old => 'Already have an account';

  @override
  String get auth_login_btn => 'Sign in';

  @override
  String get auth_signup_btn => 'Sign up';

  @override
  String get auth_anon_btn => 'Guest Login';

  @override
  String get auth_or => 'OR';

  @override
  String get auth_reset_title => 'Reset password';

  @override
  String get auth_reset_sub => 'Enter your email and we\'ll send a reset link';

  @override
  String get auth_reset_submit => 'Send reset email';

  @override
  String get auth_reset_sent => 'Email sent, please check your inbox';

  @override
  String get auth_reset_failed => 'Failed to send';

  @override
  String get auth_signin_failed => 'Sign in failed';

  @override
  String get auth_signup_failed => 'Sign up failed';

  @override
  String get auth_anon_failed => 'Guest login failed';

  @override
  String get rate_title => 'Post-match Rating';

  @override
  String rate_progress(int cur, int total) {
    return '$cur/$total players';
  }

  @override
  String get rate_comment_hint => 'Say something (optional)…';

  @override
  String get rate_skip => 'Skip';

  @override
  String get rate_submit => 'Submit';

  @override
  String get rate_submit_all => 'Submit all';

  @override
  String get rate_submitting => 'Submitting…';

  @override
  String get rate_done_title => 'Rating complete';

  @override
  String rate_done_sub(int n) {
    return '$n players rated';
  }

  @override
  String get rate_done_more => 'Rate another';

  @override
  String get rate_done_back => 'Back to event';

  @override
  String get time_just_now => 'just now';

  @override
  String time_minutes_ago(int n) {
    return '$n min ago';
  }

  @override
  String time_hours_ago(int n) {
    return '$n h ago';
  }

  @override
  String time_days_ago(int n) {
    return '$n d ago';
  }

  @override
  String get time_yesterday => 'yesterday';

  @override
  String get home_status_open => 'Open';

  @override
  String get home_status_almost => 'Almost full';

  @override
  String get home_status_full => 'Full';

  @override
  String home_need_n(int n) {
    return '$n needed';
  }

  @override
  String get home_full => 'Full';

  @override
  String get home_join_cta => 'Join →';

  @override
  String get home_rate_banner_title => 'Rate yesterday\'s match';

  @override
  String get home_rate_banner_sub =>
      'Longgang Cun-Chao · QF · 9 players to rate';

  @override
  String get home_host_pickup => 'Host pickup';

  @override
  String home_host_pickup_with_time(String time) {
    return 'Host pickup · $time';
  }

  @override
  String get home_event_teaser => 'Upcoming event';

  @override
  String get home_event_registered_label => 'Teams registered';

  @override
  String get home_event_kickoff => 'Kickoff';

  @override
  String get home_event_register_now => 'Register →';

  @override
  String get home_pickups_load_failed => 'Failed to load pickups';

  @override
  String get home_tab_recommend => 'For You';

  @override
  String get home_tab_events => 'Events';

  @override
  String get home_tab_pickup => 'Pickup';

  @override
  String get home_tab_discover => 'Discover';

  @override
  String get home_all_events => 'All events';

  @override
  String get home_events_live => 'Live now';

  @override
  String get home_events_registering => 'Registering';

  @override
  String get home_events_ongoing => 'In progress';

  @override
  String get home_events_upcoming => 'Coming soon';

  @override
  String get home_events_view => 'View';

  @override
  String get home_events_coming_soon => 'Stay tuned';

  @override
  String get home_events_register => 'Register';

  @override
  String get home_pickup_filter_all => 'All';

  @override
  String get home_pickup_filter_distance => 'Distance';

  @override
  String get home_pickup_filter_today => 'Today';

  @override
  String get home_pickup_filter_tomorrow => 'Tomorrow';

  @override
  String get home_pickup_filter_week => 'This week';

  @override
  String get home_pickup_filter_beginner => 'Beginner';

  @override
  String get home_pickup_filter_intermediate => 'Intermediate';

  @override
  String get home_pickup_filter_advanced => 'Advanced';

  @override
  String get home_pickup_slots_available => 'Spots available';

  @override
  String get home_activity_matches => 'Matches';

  @override
  String get home_activity_record => 'Record';

  @override
  String get home_activity_duration => 'Duration';

  @override
  String home_article_read_time(int min) {
    return '$min min read';
  }

  @override
  String home_viewers_count(String count) {
    return '$count watching';
  }

  @override
  String get home_discover_share => 'Share';

  @override
  String get article_detail_title => 'Article';

  @override
  String get article_category_match_report => 'Match Report';

  @override
  String get article_category_preview => 'Preview';

  @override
  String get article_category_tactics => 'Tactics';

  @override
  String get article_category_interview => 'Interview';

  @override
  String get article_category_analysis => 'Analysis';

  @override
  String get article_category_fitness => 'Fitness';

  @override
  String get article_category_gear => 'Gear';

  @override
  String get article_category_pickup_guide => 'Pickup Guide';

  @override
  String get article_no_body => 'No content available';

  @override
  String get post_detail_title => 'Post';

  @override
  String get activity_detail_title => 'Activity';

  @override
  String get post_comments_title => 'Comments';

  @override
  String get post_no_comments => 'No comments yet';

  @override
  String get comment_hint => 'Write a comment…';

  @override
  String get comment_empty_toast => 'Comment cannot be empty';

  @override
  String get comment_send_failed => 'Failed to send, please retry';

  @override
  String get comment_login_required => 'Please sign in to comment';

  @override
  String get rate_panel_title => 'Post-match rating';

  @override
  String get rate_say_optional => 'Say something · optional';

  @override
  String get rate_self_hint => 'Rate yourself?';

  @override
  String get rate_other_hint => 'How did they play today?';

  @override
  String rate_voters_avg(int n) {
    return '$n rated · avg';
  }

  @override
  String get rate_prev => 'Prev';

  @override
  String get rate_next => 'Next →';

  @override
  String get rate_submit_score => 'Submit rating';

  @override
  String rate_submit_failed(String err) {
    return 'Submit failed: $err';
  }

  @override
  String get rate_short_you => 'You';

  @override
  String get rate_level_bad => 'Awful';

  @override
  String get rate_level_meh => 'Meh';

  @override
  String get rate_level_good => 'Good';

  @override
  String get rate_level_god => 'Legend';

  @override
  String get rate_done_header => 'Rating submitted';

  @override
  String rate_done_thanks_body(int n) {
    return 'Thanks for rating $n players.';
  }

  @override
  String get rate_done_view_leaderboard => 'View leaderboard';

  @override
  String event_overview_main_visual(String name) {
    return '$name · hero';
  }

  @override
  String get event_overview_rule_format => '11-a-side · standard pitch';

  @override
  String get event_overview_rule_halves => '2 × 45min + halftime';

  @override
  String get event_overview_rule_subs => '5 subs, rotation allowed';

  @override
  String get event_overview_rule_cards => 'Cards accumulate to suspension';

  @override
  String get event_overview_organizer_label => 'Organizer';

  @override
  String get event_bracket_waiting => 'No schedule yet — awaiting organizer';

  @override
  String get event_standings_empty2 => 'No results yet';

  @override
  String get event_chat_sender_you => 'You';

  @override
  String get event_chat_sender_stranger => 'Player';

  @override
  String get event_scorers_goals => 'Goals';

  @override
  String event_rating_n_voters_inline(int n) {
    return '$n voters';
  }

  @override
  String get event_rating_empty_go_rate => 'No ratings yet · rate a match';

  @override
  String get event_rating_player_detail => 'Player rating detail';

  @override
  String get event_prize_pending => 'Prize TBD';

  @override
  String event_prize_wan(String amount) {
    return 'Prize ¥${amount}0k';
  }

  @override
  String event_deadline_md_suffix(String md) {
    return 'Closes $md';
  }

  @override
  String get event_row_teams_label => 'Teams registered';

  @override
  String get event_row_status_label => 'Status';

  @override
  String get player_card_rating => 'Rating';

  @override
  String get player_card_mp => 'MP';

  @override
  String get team_card_summary => 'Record';

  @override
  String get team_card_gf => 'GF';

  @override
  String get team_card_ga => 'GA';

  @override
  String get team_card_gd => 'GD';

  @override
  String get team_card_matches => 'Matches';

  @override
  String get wc_hero_title => 'World Cup Hub';

  @override
  String get wc_hero_sub => 'Group · R2 · 5 matches live tonight';

  @override
  String get wc_focus_battle => 'Featured · Live';

  @override
  String wc_focus_halftime(String minute) {
    return '$minute · 2nd half';
  }

  @override
  String wc_focus_watch_count(String n) {
    return '$n watching';
  }

  @override
  String get wc_team_argentina => 'Argentina';

  @override
  String get wc_team_brazil => 'Brazil';

  @override
  String get wc_team_argentina_win => 'ARG win';

  @override
  String get wc_team_draw => 'Draw';

  @override
  String get wc_team_brazil_win => 'BRA win';

  @override
  String pickup_map_title_city(String city) {
    return 'Pickup · $city';
  }

  @override
  String get pickup_map_legend_open => 'Open';

  @override
  String get pickup_map_legend_almost => 'Almost full';

  @override
  String get pickup_map_legend_full => 'Full';

  @override
  String get pickup_map_sort_distance => 'By distance';

  @override
  String pickup_map_need_short(int n) {
    return '$n left';
  }

  @override
  String get pickup_map_full_short => 'Full';

  @override
  String get level_any => 'Any';

  @override
  String get level_beginner => 'Beginner';

  @override
  String get level_novice => 'Novice';

  @override
  String get level_mid => 'Mid';

  @override
  String get level_pro => 'Pro';

  @override
  String get field_5 => '5-a-side';

  @override
  String get field_7 => '7-a-side';

  @override
  String get field_8 => '8-a-side';

  @override
  String get field_11 => '11-a-side';

  @override
  String pickup_detail_open_need_n(int n) {
    return 'Open · $n needed';
  }

  @override
  String pickup_detail_formation_title(String formation) {
    return 'Formation · $formation';
  }

  @override
  String pickup_detail_slots_filled_of(int total) {
    return '/$total filled';
  }

  @override
  String get pickup_detail_details => 'Details';

  @override
  String get pickup_detail_detail_level => 'Level';

  @override
  String get pickup_detail_detail_headcount => 'Players';

  @override
  String get pickup_detail_detail_field => 'Field';

  @override
  String get pickup_detail_detail_parking => 'Parking';

  @override
  String get pickup_detail_location => 'Location';

  @override
  String pickup_detail_location_km(String km) {
    return 'Location · ${km}km away';
  }

  @override
  String get pickup_detail_navigate => 'Navigate';

  @override
  String get pickup_detail_nav_chooser_title => 'Choose a map app';

  @override
  String get pickup_detail_nav_amap => 'Amap';

  @override
  String get pickup_detail_nav_baidu => 'Baidu Maps';

  @override
  String get pickup_detail_nav_system => 'System maps';

  @override
  String get pickup_detail_nav_none => 'No map app installed';

  @override
  String get pickup_detail_aa_fee => 'Split fee';

  @override
  String get pickup_detail_not_signed_in => 'Not signed in';

  @override
  String pickup_detail_join_failed(String err) {
    return 'Join failed: $err';
  }

  @override
  String get pickup_detail_formation_load_failed => 'Formation load failed';

  @override
  String pickup_detail_host_stats(int n, int rate) {
    return 'Hosted $n · $rate% on time';
  }

  @override
  String get messages_thread_default_title => 'Conversation';

  @override
  String get messages_kind_group => 'Group';

  @override
  String get messages_kind_dm => 'Direct';

  @override
  String get chat_default_group_title => 'GameOn · Rookie Lobby';

  @override
  String get chat_sender_system => 'system';

  @override
  String get auth_guest_prefix => 'Guest-';

  @override
  String get auth_terms_notice => 'By continuing you agree to Terms & Privacy';

  @override
  String get create_event_tpl_group8_desc_inline => '2 groups × 4 + knockout';

  @override
  String get create_event_hint_not_logged => 'Please sign in first';

  @override
  String create_event_preview_prize_wan(String amount) {
    return '¥${amount}0k';
  }

  @override
  String get rate_pitch_title => 'Rate this match';

  @override
  String rate_pitch_progress(int done, int total) {
    return '$done/$total rated';
  }

  @override
  String get rate_pitch_tap_hint => 'Tap a player to rate';

  @override
  String get rate_pitch_save_next => 'Save · Next';

  @override
  String rate_pitch_submit_n(int n) {
    return 'Submit ($n)';
  }

  @override
  String get rate_pitch_cannot_self => 'You can\'t rate yourself';

  @override
  String get rate_pitch_empty_title => 'No teammates yet';

  @override
  String get rate_pitch_empty_sub => 'Come back when others have joined';

  @override
  String get rate_pitch_empty_back => 'Back to match';

  @override
  String get rate_pitch_goals_label => 'Goals';

  @override
  String get rate_pitch_assists_label => 'Assists';

  @override
  String get rate_pitch_pos_label => 'Position';

  @override
  String get rate_pitch_not_registered => 'Guest player';

  @override
  String rate_pitch_submitted_n(int n) {
    return '$n ratings submitted';
  }

  @override
  String get rate_pitch_rate_teammates_cta => 'Rate this match';

  @override
  String get match_detail_title => 'Match';

  @override
  String get match_status_upcoming => 'Upcoming';

  @override
  String get match_status_live => 'Live';

  @override
  String get match_status_done => 'Finished';

  @override
  String get match_goals_section => 'Goals';

  @override
  String get match_goals_empty => 'No goals recorded';

  @override
  String get match_cta_rate => 'Rate players';

  @override
  String get match_cta_view_ratings => 'View match ratings';

  @override
  String get match_cta_remind => 'Remind me';

  @override
  String get match_cta_reminded => 'Reminder set';

  @override
  String get match_ratings_title => 'Match ratings';

  @override
  String get match_ratings_go_rate => 'Rate this match';

  @override
  String get match_own_goal => 'OG';

  @override
  String get match_penalty => 'Pen.';

  @override
  String match_assist_by(String name) {
    return 'assist $name';
  }

  @override
  String get match_not_found => 'Match not found';

  @override
  String get event_standings_leaders_label => 'League Leaders';

  @override
  String get event_standings_leader_top => '1st';

  @override
  String get event_standings_leader_runner => '2nd';

  @override
  String event_standings_points_diff(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n points apart',
      one: '1 point apart',
    );
    return '$_temp0';
  }

  @override
  String get event_scorers_golden_boot => 'Golden Boot';

  @override
  String event_scorers_per_match(String avg) {
    return '$avg / match';
  }

  @override
  String get messages_new_dm => 'Start DM';

  @override
  String get messages_new_dm_hint => 'Enter the user\'s handle';

  @override
  String get messages_new_dm_not_found => 'User not found';

  @override
  String get messages_new_dm_cant_self => 'Can\'t DM yourself';

  @override
  String get pickup_map_location_disabled => 'Location services are disabled';

  @override
  String get pickup_map_location_denied =>
      'Location permission denied. Please enable it in Settings.';
}
