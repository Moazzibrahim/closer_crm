// crud_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException([
    this.message = 'You do not have permission to do this action',
  ]);
  @override
  String toString() => message;
}

/// مصدر واحد للصلاحيات (بيستخدمه الـ service والـ UI)
class CrudPermissions {
  static String _norm(String? r) =>
      (r ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');

  static String _normPath(String p) => p.toLowerCase();

  // الـ resources اللي الـ Marketer يقدر يعدّل فيها
  static final Set<String> _marketerWritable = {
    Endpoints.campaigns,
    Endpoints.channels,
  }.map(_normPath).toSet();

  static bool canWrite(String? role, String path) {
    switch (_norm(role)) {
      case 'admin':
        return true;
      case 'marketer':
        return _marketerWritable.contains(_normPath(path));
      default:
        return false;
    }
  }
}

class CrudService {
  final String path;
  CrudService(this.path);

  final Dio _dio = DioClient.instance.dio;

  Map<String, dynamic> _map(Response r) =>
      Map<String, dynamic>.from(r.data as Map);

  // نفس المفتاح اللي AuthProvider بيحفظه
  Future<void> _requireWrite() async {
    final prefs = await SharedPreferences.getInstance();
    if (!CrudPermissions.canWrite(prefs.getString('role'), path)) {
      throw const PermissionDeniedException();
    }
  }

  // ── Read: مفتوحة للكل ──
  Future<Map<String, dynamic>> getAll({Map<String, dynamic>? params}) async {
    try {
      return _map(await _dio.get(path, queryParameters: params));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> getOne(String id) async {
    try {
      return _map(await _dio.get('$path/$id'));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  // ── Write: محمية ──
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    await _requireWrite();
    try {
      return _map(await _dio.post(path, data: body));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    await _requireWrite();
    try {
      return _map(await _dio.put('$path/$id', data: body));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> bulkSetActive(List<String> ids, {required bool active}) async {
    await _requireWrite();
    try {
      await _dio.put(
        '$path/bulk/${active ? 'activate' : 'deactivate'}',
        data: {'ids': ids},
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> delete(String id) async {
    await _requireWrite();
    try {
      await _dio.delete('$path/$id');
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> bulkDelete(List<String> ids) async {
    await _requireWrite();
    try {
      await _dio.delete('$path/bulk/delete', data: {'ids': ids});
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  // ── Stage type options (الأدمن بس لأن stageTypes مش في قايمة الـ Marketer) ──
  Future<void> setOptionActive(
    String stageTypeId,
    String optionId, {
    required bool active,
  }) async {
    await _requireWrite();
    try {
      // ⚠️ عدّل الـ path/الـ method حسب الـ endpoint الفعلي
      await _dio.put(
        '$path/$stageTypeId/options/$optionId',
        data: {'active': active},
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> deleteOption(String stageTypeId, String optionId) async {
    await _requireWrite();
    try {
      await _dio.delete('$path/$stageTypeId/options/$optionId');
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}
