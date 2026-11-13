// users_lookup_service.dart
// ignore_for_file: use_null_aware_elements

import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';

class LookupUser {
  final String id, name, email, role;
  final String? avatar, managerId, teamLeaderId;
  final bool isActive;

  const LookupUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.avatar,
    this.managerId,
    this.teamLeaderId,
  });

  factory LookupUser.fromJson(Map<String, dynamic> j) => LookupUser(
    id: '${j['_id']}',
    name: (j['name'] ?? '${j['firstName'] ?? ''} ${j['lastName'] ?? ''}')
        .toString()
        .trim(),
    email: '${j['email'] ?? ''}',
    role: '${j['role'] ?? ''}',
    isActive: j['isActive'] != false,
    avatar: j['avatar']?.toString(),
    managerId: j['manager']?.toString(),
    teamLeaderId: j['teamLeader']?.toString(),
  );
}

class UsersLookupService {
  final Dio _dio = DioClient.instance.dio;

  /// صفحة واحدة من GET /auth/lookup
  Future<({List<LookupUser> users, int pages})> lookupPage({
    List<String>? roles, // ['Sales', 'Team Leader']
    bool? isActive,
    String? manager,
    String? teamLeader,
    String? keyword,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final res = await _dio.get(
        Endpoints.usersLookup,
        queryParameters: {
          if (roles != null && roles.isNotEmpty) 'role': roles.join(','),
          if (isActive != null) 'isActive': isActive,
          if (manager != null && manager.isNotEmpty) 'manager': manager,
          if (teamLeader != null && teamLeader.isNotEmpty)
            'teamLeader': teamLeader,
          if (keyword != null && keyword.trim().isNotEmpty)
            'keyword': keyword.trim(),
          'page': page,
          'limit': limit,
        },
      );
      final body = Map<String, dynamic>.from(res.data as Map);
      final users = (body['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => LookupUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final pages =
          (body['paginationResult']?['NumberOfPages'] as num?)?.toInt() ?? 1;
      return (users: users, pages: pages);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
  /// بيجيب كل الصفحات (للـ pickers/الفلاتر)
  Future<List<LookupUser>> lookupAll({
    List<String>? roles,
    bool? isActive,
    String? manager,
    String? teamLeader,
    String? keyword,
  }) async {
    final all = <LookupUser>[];
    var page = 1, pages = 1;
    do {
      final r = await lookupPage(
        roles: roles,
        isActive: isActive,
        manager: manager,
        teamLeader: teamLeader,
        keyword: keyword,
        page: page,
        limit: 100,
      );
      all.addAll(r.users);
      pages = r.pages;
      page++;
    } while (page <= pages);
    return all;
  }

  /// اليوزرز التابعين للمانجر أو التيم ليدر
  /// - manager     → manager: id
  /// - teamLeader  → teamLeader: id
  Future<List<LookupUser>> myTeam({
    required bool isManager,
    required String userId,
    bool activeOnly = true,
    String? keyword,
  }) => lookupAll(
    roles: const ['Sales', 'Team Leader'],
    isActive: activeOnly ? true : null,
    manager: isManager ? userId : null,
    teamLeader: isManager ? null : userId,
    keyword: keyword,
  );
}