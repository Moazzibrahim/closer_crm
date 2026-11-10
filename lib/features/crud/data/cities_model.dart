// cities_model.dart
// الموديل بتاع الـ cities — بيطابق رد الـ GET all:
// { status, results, paginationResult: {...}, data: [ {_id, name, isActive, addedBy, createdAt, updatedAt} ] }

class CityModel {
  final String? id;
  final String name;
  final bool active;
  final String? addedByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CityModel({
    this.id,
    required this.name,
    this.active = true,
    this.addedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory CityModel.fromJson(Map<String, dynamic> j) {
    final by = j['addedBy'];
    String? byName;
    if (by is Map) {
      byName = [by['firstName'], by['lastName']]
          .where((e) => e != null && '$e'.trim().isNotEmpty)
          .join(' ');
      if (byName.isEmpty) byName = null;
    }
    return CityModel(
      id: j['_id']?.toString(),
      name: (j['name'] ?? '').toString(),
      active: j['isActive'] != false,
      addedByName: byName,
      createdAt: DateTime.tryParse('${j['createdAt']}')?.toLocal(),
      updatedAt: DateTime.tryParse('${j['updatedAt']}')?.toLocal(),
    );
  }

  /// الاسم بحرف أول كبير (shrj → Shrj)
  String get displayName {
    final n = name.trim();
    return n.isEmpty ? '—' : n[0].toUpperCase() + n.substring(1);
  }

  String get initial => displayName == '—' ? '?' : displayName[0];
}

class CitiesPagination {
  final int currentPage, limit, numberOfPages;
  final int totalItems, totalActive, totalInactive;
  final num activePercentage, inactivePercentage;

  const CitiesPagination({
    this.currentPage = 1,
    this.limit = 50,
    this.numberOfPages = 1,
    this.totalItems = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
    this.activePercentage = 0,
    this.inactivePercentage = 0,
  });

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory CitiesPagination.fromJson(Map<String, dynamic> j) => CitiesPagination(
    currentPage: _i(j['currentPage']),
    limit: _i(j['limit']),
    numberOfPages: _i(j['NumberOfPages']),
    totalItems: _i(j['totalItems']),
    totalActive: _i(j['totalLeadsActive']),
    totalInactive: _i(j['totalLeadsInactive']),
    activePercentage: j['activePercentage'] is num ? j['activePercentage'] : 0,
    inactivePercentage:
        j['inactivePercentage'] is num ? j['inactivePercentage'] : 0,
  );
}

class CitiesResponse {
  final List<CityModel> data;
  final CitiesPagination? pagination;

  const CitiesResponse({required this.data, this.pagination});

  factory CitiesResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'];
    return CitiesResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CityModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pagination: p is Map
          ? CitiesPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}