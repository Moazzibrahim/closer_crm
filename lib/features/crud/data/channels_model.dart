import 'package:flutter/material.dart';

class ChannelAddedBy {
  final String? id;
  final String? firstName;
  final String? lastName;

  const ChannelAddedBy({this.id, this.firstName, this.lastName});

  factory ChannelAddedBy.fromJson(Map<String, dynamic> j) => ChannelAddedBy(
    id: j['_id']?.toString(),
    firstName: j['firstName']?.toString(),
    lastName: j['lastName']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'firstName': firstName,
    'lastName': lastName,
  };

  String get fullName =>
      [firstName, lastName].where((e) => e != null && e.isNotEmpty).join(' ');
}

class ChannelModel {
  final String? id;
  final String? name;
  final String? code;
  final bool? isActive;
  final ChannelAddedBy? addedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChannelModel({
    this.id,
    this.name,
    this.code,
    this.isActive,
    this.addedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> j) => ChannelModel(
    id: j['_id']?.toString(),
    name: j['name']?.toString(),
    code: j['code']?.toString(),
    isActive: j['isActive'] as bool?,
    addedBy: j['addedBy'] is Map
        ? ChannelAddedBy.fromJson(
            Map<String, dynamic>.from(j['addedBy'] as Map),
          )
        : null,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(j['updatedAt']?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'code': code,
    'isActive': isActive,
    'addedBy': addedBy?.toJson(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  ChannelModel copyWith({String? name, String? code, bool? isActive}) =>
      ChannelModel(
        id: id,
        name: name ?? this.name,
        code: code ?? this.code,
        isActive: isActive ?? this.isActive,
        addedBy: addedBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  // helpers
  bool get active => isActive ?? false;
  String get displayName =>
      (name == null || name!.trim().isEmpty) ? 'Unnamed' : name!;
  String get initial => displayName.characters.first.toUpperCase();
}

class ChannelsPagination {
  final int? currentPage;
  final int? limit;
  final int? numberOfPages;
  final int? totalItems;
  final int? totalAllLeads;
  final int? totalLeadsActive;
  final int? totalLeadsInactive;
  final int? numberOfPagesInactive;
  final num? activePercentage;
  final num? inactivePercentage;

  const ChannelsPagination({
    this.currentPage,
    this.limit,
    this.numberOfPages,
    this.totalItems,
    this.totalAllLeads,
    this.totalLeadsActive,
    this.totalLeadsInactive,
    this.numberOfPagesInactive,
    this.activePercentage,
    this.inactivePercentage,
  });

  factory ChannelsPagination.fromJson(Map<String, dynamic> j) =>
      ChannelsPagination(
        currentPage: (j['currentPage'] as num?)?.toInt(),
        limit: (j['limit'] as num?)?.toInt(),
        numberOfPages: (j['NumberOfPages'] as num?)?.toInt(),
        totalItems: (j['totalItems'] as num?)?.toInt(),
        totalAllLeads: (j['totalAllLeads'] as num?)?.toInt(),
        totalLeadsActive: (j['totalLeadsActive'] as num?)?.toInt(),
        totalLeadsInactive: (j['totalLeadsInactive'] as num?)?.toInt(),
        numberOfPagesInactive: (j['NumberOfPagesInactive'] as num?)?.toInt(),
        activePercentage: j['activePercentage'] as num?,
        inactivePercentage: j['inactivePercentage'] as num?,
      );
}

class ChannelsResponse {
  final String? status;
  final int? results;
  final ChannelsPagination? pagination;
  final List<ChannelModel> data;

  const ChannelsResponse({
    this.status,
    this.results,
    this.pagination,
    this.data = const [],
  });

  factory ChannelsResponse.fromJson(Map<String, dynamic> j) => ChannelsResponse(
    status: j['status']?.toString(),
    results: (j['results'] as num?)?.toInt(),
    pagination: j['paginationResult'] is Map
        ? ChannelsPagination.fromJson(
            Map<String, dynamic>.from(j['paginationResult'] as Map),
          )
        : null,
    data: (j['data'] as List? ?? [])
        .map((e) => ChannelModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.id != null && c.id!.isNotEmpty)
        .toList(),
  );
}
