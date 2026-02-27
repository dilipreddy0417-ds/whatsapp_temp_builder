class InternalTemplate {
  final String id;
  final String name;
  final String? subject;
  final String body;
  final Map<String, dynamic>? variables;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? userId;

  InternalTemplate({
    required this.id,
    required this.name,
    this.subject,
    required this.body,
    this.variables,
    required this.createdAt,
    this.updatedAt,
    this.userId,
  });

  factory InternalTemplate.fromJson(Map<String, dynamic> json) {
    return InternalTemplate(
      id: json['id'],
      name: json['name'],
      subject: json['subject'],
      body: json['body'],
      variables: json['variables'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'body': body,
      'variables': variables,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'user_id': userId,
    };
  }
}
