// projects_model.dart
// features/crud/data/projects_model.dart

// ignore_for_file: prefer_null_aware_operators

// ---------- helpers ----------
String? _s(dynamic v) => v == null ? null : v.toString();
double? _d(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
List<String> _strList(dynamic v) => (v as List? ?? [])
    .map((e) => e.toString())
    .where((e) => e.isNotEmpty)
    .toList();

/// مرجع بسيط {_id, name, isActive} — بيتستخدم للـ developer / city / area / propertyType
/// بيقبل كمان لو الـ API رجّع الـ id كـ String بس (من غير populate)
class RefModel {
  final String? id;
  final String name;
  final bool active;
  const RefModel({this.id, this.name = '', this.active = true});

  static RefModel? tryParse(dynamic j) {
    if (j == null) return null;
    if (j is String) return RefModel(id: j);
    if (j is Map) {
      return RefModel(
        id: _s(j['_id'] ?? j['id']),
        name: _s(j['name']) ?? '',
        active: j['isActive'] != false,
      );
    }
    return null;
  }
}

class ProjectLink {
  final String label, url;
  const ProjectLink({required this.label, required this.url});
  factory ProjectLink.fromJson(Map<String, dynamic> j) =>
      ProjectLink(label: _s(j['label']) ?? '', url: _s(j['url']) ?? '');
  Map<String, dynamic> toJson() => {'label': label, 'url': url};
}

class PaymentPlan {
  final double? downPaymentPercentage;
  final int? installmentYears;
  final String? description;
  const PaymentPlan({
    this.downPaymentPercentage,
    this.installmentYears,
    this.description,
  });

  factory PaymentPlan.fromJson(dynamic j) {
    if (j is! Map) return const PaymentPlan();
    return PaymentPlan(
      downPaymentPercentage: _d(j['downPaymentPercentage']),
      installmentYears: _d(j['installmentYears'])?.toInt(),
      description: _s(j['description']),
    );
  }
}

class ProjectModel {
  final String? id;
  final String name;
  final RefModel? developer, city, area;
  final List<RefModel> propertyTypes;
  final double? startPrice, maxPrice, minArea, maxArea;
  final String? completionStatus;
  final DateTime? deliveryDate;
  final List<String> amenities, images;
  final String? description, brochureUrl, videoUrl;
  final List<ProjectLink> externalLinks;
  final PaymentPlan paymentPlan;
  final double? lat, lng;
  final bool featured;
  final bool active;
  final String addedByName;
  final DateTime? createdAt, updatedAt;

  const ProjectModel({
    this.id,
    this.name = '',
    this.developer,
    this.city,
    this.area,
    this.propertyTypes = const [],
    this.startPrice,
    this.maxPrice,
    this.minArea,
    this.maxArea,
    this.completionStatus,
    this.deliveryDate,
    this.amenities = const [],
    this.images = const [],
    this.description,
    this.brochureUrl,
    this.videoUrl,
    this.externalLinks = const [],
    this.paymentPlan = const PaymentPlan(),
    this.lat,
    this.lng,
    this.featured = false,
    this.active = true,
    this.addedByName = '',
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> j) {
    final coords = j['coordinates'] is Map ? j['coordinates'] as Map : const {};
    final added = j['addedBy'] is Map ? j['addedBy'] as Map : const {};
    return ProjectModel(
      id: _s(j['_id'] ?? j['id']),
      name: _s(j['name']) ?? '',
      developer: RefModel.tryParse(j['developer']),
      city: RefModel.tryParse(j['city']),
      area: RefModel.tryParse(j['area']),
      propertyTypes: (j['propertyTypes'] as List? ?? [])
          .map(RefModel.tryParse)
          .whereType<RefModel>()
          .toList(),
      startPrice: _d(j['startPrice']),
      maxPrice: _d(j['maxPrice']),
      minArea: _d(j['minArea']),
      maxArea: _d(j['maxArea']),
      completionStatus: _s(j['completionStatus']),
      deliveryDate: j['deliveryDate'] == null
          ? null
          : DateTime.tryParse('${j['deliveryDate']}'),
      amenities: _strList(j['amenities']),
      images: _strList(j['images']),
      description: _s(j['description']),
      brochureUrl: _s(j['brochureUrl']),
      videoUrl: _s(j['videoUrl']),
      externalLinks: (j['externalLinks'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ProjectLink.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      paymentPlan: PaymentPlan.fromJson(j['paymentPlan']),
      lat: _d(coords['lat']),
      lng: _d(coords['lng']),
      featured: j['featured'] == true,
      active: j['isActive'] != false,
      addedByName: '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'
          .trim(),
      createdAt: j['createdAt'] == null
          ? null
          : DateTime.tryParse('${j['createdAt']}'),
      updatedAt: j['updatedAt'] == null
          ? null
          : DateTime.tryParse('${j['updatedAt']}'),
    );
  }

  // ---------- helpers للـ UI ----------
  String get displayName => name.isEmpty ? 'Unnamed' : name;
  String get initial => name.isEmpty
      ? '?'
      : name.trim().isEmpty
      ? '?'
      : name.trim()[0].toUpperCase();
  String get thumb => images.isNotEmpty ? images.first : '';

  /// "Downtown Dubai · Dubai"
  String get location => [
    area?.name,
    city?.name,
  ].where((e) => e != null && e.isNotEmpty).join(' · ');

  /// "950K – 2M"
  String get priceRange {
    if (startPrice == null && maxPrice == null) return '—';
    if (maxPrice == null) return 'From ${_fmt(startPrice!)}';
    if (startPrice == null) return 'Up to ${_fmt(maxPrice!)}';
    return '${_fmt(startPrice!)} – ${_fmt(maxPrice!)}';
  }

  static String _fmt(double v) {
    String t(double x) =>
        x == x.roundToDouble() ? x.toInt().toString() : x.toStringAsFixed(1);
    if (v >= 1000000) return '${t(v / 1000000)}M';
    if (v >= 1000) return '${t(v / 1000)}K';
    return t(v);
  }
}

class ProjectsPagination {
  final int totalItems, totalActive, totalInactive;
  const ProjectsPagination({
    this.totalItems = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
  });

  factory ProjectsPagination.fromJson(Map<String, dynamic> j) =>
      ProjectsPagination(
        totalItems: _d(j['totalItems'])?.toInt() ?? 0,
        totalActive: _d(j['totalLeadsActive'])?.toInt() ?? 0,
        totalInactive: _d(j['totalLeadsInactive'])?.toInt() ?? 0,
      );
}

class ProjectsResponse {
  final List<ProjectModel> data;
  final ProjectsPagination? pagination;
  const ProjectsResponse({this.data = const [], this.pagination});

  factory ProjectsResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'] ?? j['pagination'];
    return ProjectsResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ProjectModel.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id != null && p.id!.isNotEmpty)
          .toList(),
      pagination: p is Map
          ? ProjectsPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}
