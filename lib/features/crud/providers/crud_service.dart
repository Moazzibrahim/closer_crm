// crud_service.dart
// الـ resources البسيطة (channels, cities, developers, regions, areas, property-types,
// campaigns, stage-types, stages, communication-ways, cancel-reasons, projects)
// كلها بنفس الـ pattern: list / get / create / update / bulk activate-deactivate / delete.
// فبدل 12 class، فيه class واحد بياخد الـ path.
import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';

class CrudService {
  final String path; // مثال: Endpoints.channels
  CrudService(this.path);

  final Dio _dio = DioClient.instance.dio;

  Map<String, dynamic> _map(Response r) => Map<String, dynamic>.from(r.data as Map);

  /// params: أي فلاتر خاصة بالـ resource (isActive, keyword, name, page, limit, sort, ...)
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

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    try {
      return _map(await _dio.post(path, data: body));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) async {
    try {
      return _map(await _dio.put('$path/$id', data: body));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// Admin فقط
  Future<void> bulkSetActive(List<String> ids, {required bool active}) async {
    try {
      await _dio.put('$path/bulk/${active ? 'activate' : 'deactivate'}', data: {'ids': ids});
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// حذف ناعم (soft delete) — بيروح للـ trash
  Future<void> delete(String id) async {
    try {
      await _dio.delete('$path/$id');
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// حذف نهائي من الداتابيز
  Future<void> bulkDelete(List<String> ids) async {
    try {
      await _dio.delete('$path/bulk/delete', data: {'ids': ids});
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}

// استخدام جاهز:
// final channelsApi   = CrudService(Endpoints.channels);
// final projectsApi   = CrudService(Endpoints.projects);
// final stagesApi     = CrudService(Endpoints.stages);
// final stageTypesApi = CrudService(Endpoints.stageTypes);
// ... إلخ
//
// stageTypes ليها كمان options (Add/Update/Activate/Deactivate/Delete) —
// بتتعمل بـ _dio مباشرة على '/stagetype/{id}/options/{optionId}'.
