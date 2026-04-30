// lib/models/show_model.dart

class ShowModel {
  final String id;
  final String userId;
  final String local;
  final DateTime showDate;
  final double value;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShowModel({
    required this.id,
    required this.userId,
    required this.local,
    required this.showDate,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShowModel.fromMap(Map<String, dynamic> map) {
    return ShowModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      local: map['local'] as String,
      showDate: DateTime.parse(map['show_date'] as String),
      value: (map['value'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'local': local,
      'show_date': showDate.toIso8601String().split('T').first,
      'value': value,
    };
  }

  ShowModel copyWith({
    String? id,
    String? userId,
    String? local,
    DateTime? showDate,
    double? value,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShowModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      local: local ?? this.local,
      showDate: showDate ?? this.showDate,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}