// api_constants.dart
// الثوابت: الـ URL + كل الـ endpoints. انسخ المحتوى في ملف الثوابت عندك (أو سيبه ملف لوحده).
// baseUrl هنا getter (مش final) عشان يتقري مع كل request،
// وده بيدعم تغيير الدومين لو عندك multi-company.
// ignore_for_file: unnecessary_getters_setters

class ApiConfig {
  static const String defaultBaseUrl =
      'https://closer-crm-api-nt25.onrender.com';
  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;
  static set baseUrl(String value) => _baseUrl = value;

  /// الـ prefix الكامل لكل الـ endpoints
  static String get api => '$_baseUrl/api/v1';

  // مفاتيح SharedPreferences
  static const String tokenKey = 'token';
  static const String deviceIdKey = 'deviceId';

  // Render free tier بيعمل cold start فممكن أول request ياخد وقت
  static const Duration connectTimeout = Duration(seconds: 40);
  static const Duration receiveTimeout = Duration(seconds: 40);
}

/// كل الـ paths في مكان واحد
class Endpoints {
  // Auth
  static const login = '/auth/login';
  static const signup = '/auth/signup';
  static const allUsers = '/auth/All';
  static String user(String id) => '/auth/$id';
  static String changePassword(String id) => '/auth/change-password/$id';
  static const bulkActivateUsers = '/auth/bulk/activate';
  static const bulkDeactivateUsers = '/auth/bulk/deactivate';

  // Sessions & logs
  static const mySessions = '/sessions/my';
  static const allSessions = '/sessions/all';
  static String userSessions(String userId) =>
      '/sessions/user/$userId'; // 👈 جديد
  static const activityLogs = '/activitylogs';
  // في الـ collection مكتوب /activitylogs، اتأكد من الباك

  // Leads
  static const leads = '/Leads';
  static const myLeads = '/Leads/my-leads';
  static const dashboardStages = '/dashboard/stages';
  // inside Endpoints
  static const dashboardFollowUps = '/dashboard/follow-ups';
  static String lead(String id) => '/Leads/$id';
  static String leadStage(String id) => '/Leads/$id/stage';
  static String leadAssign(String id) => '/Leads/$id/assign';
  static const leadsBulkAssign = '/Leads/bulk-assign';
  static const leadsBulkUpdate = '/Leads/bulk/update';
  static const leadsBulkActions = '/Leads/bulk/actions';
  static const leadsExport = '/Leads/export';
  static const leadsBulkActivate = '/Leads/bulk/activate';
  static const leadsBulkDeactivate = '/Leads/bulk-deactivate';
  static String leadCreationDate(String id) => '/Leads/$id/creation-date';
  static String leadClearHistory(String id) => '/Leads/$id/clear-history';
  static String leadSubmissionApply(String id, int n) =>
      '/Leads/$id/submissions/$n/apply';
  static String leadDeals(String id) => '/Leads/$id/deals';
  static String leadDeal(String id, String dealId) =>
      '/Leads/$id/deals/$dealId';
  // Stage Reshuffle Rules
  static const reshuffleRules = '/stage-reshuffle-rules';
  static String reshuffleRule(String id) => '/stage-reshuffle-rules/$id';
  static String reshuffleToggle(String id) =>
      '/stage-reshuffle-rules/$id/toggle';

  // Comments
  static String comments(String leadId) => '/Leads/$leadId/comments';
  static String comment(String leadId, String cId) =>
      '/Leads/$leadId/comments/$cId';
  static String replies(String leadId, String cId) =>
      '/Leads/$leadId/comments/$cId/replies';
  static String reply(String leadId, String cId, String rId) =>
      '/Leads/$leadId/comments/$cId/replies/$rId';
  static String commentVoice(String leadId, String cId) =>
      '/Leads/$leadId/comments/$cId/voice';
  static String replyVoice(String leadId, String cId, String rId) =>
      '/Leads/$leadId/comments/$cId/replies/$rId/voice';

  // Simple CRUD resources (بتستخدم CrudService)
  static const channels = '/channels';
  static const cities = '/cities';
  static const developers = '/developers';
  static const regions = '/region';
  static const areas = '/area';
  static const propertyTypes = '/property-types';
  static const campaigns = '/Campaigns';
  static const stageTypes = '/stagetype';
  static const stages = '/stages';
  static const communicationWays = '/communicationway';
  static const cancelReasons = '/cancelreason';
  static const projects = '/projects';

  // AI chat
  static const aiChat = '/aichat/chat';
  static const aiUsage = '/aichat/usage';
  static const aiUsageAll = '/aichat/usage/all';
  // Dashboard
  static const dashboardTeam = '/dashboard/team';
  static const dashboardDeals = '/dashboard/deals';
  static const dashboardDealsSales = '/dashboard/deals/sales';
  static const dashboardMarketing = '/dashboard/marketing';

  // Me / profile / settings
  static const me = '/auth/me';
  static const usersLookup = '/auth/lookup';
  static const fcmToken = '/auth/fcm-token'; // PUT / DELETE
  static const logout = '/auth/logout';
  static const crmSettingsMe = '/crm-settings/me';
  static const profile = '/profile';
  static const profileActivity = '/profile/activity';
  static String session(String id) => '/sessions/$id';

  // Notifications
  static const notifications = '/notifications';
  static const notifUnread = '/notifications/unread-count';
  static const notifSeen = '/notifications/seen';
  static const notifReadAll = '/notifications/read-all';
  static String notif(String id) => '/notifications/$id';
  static String notifRead(String id) => '/notifications/$id/read';
  static String notifAccess(String id) => '/notifications/$id/access';

  // Leads extras
  static const quickSearch = '/Leads/quick-search';
  static const duplicateCheck = '/Leads/duplicate-check';
  static String leadContact(String id) => '/Leads/$id/contact';
  static String aiUsageLimit(String userId) => '/aichat/usage/$userId/limit';

  // Notifications
  static const notificationTest = '/notifications/test';
}
