class GroupMember {
  final int? id;
  final int? remoteId;
  final int groupId;
  final int? userId;
  final String username;
  final String? email;
  final String role;

  /// Why the server refused this member (e.g. no account with that
  /// username). Null when fine or not yet tried.
  final String? syncError;

  GroupMember({
    this.id,
    this.remoteId,
    required this.groupId,
    this.userId,
    required this.username,
    this.email,
    this.role = 'member',
    this.syncError,
  });

  bool get isOwner => role == 'owner';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'remote_id': remoteId,
      'group_id': groupId,
      'user_id': userId,
      'username': username,
      'email': email,
      'role': role,
    };
  }

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      groupId: map['group_id'] as int,
      userId: map['user_id'] as int?,
      username: map['username'] as String,
      email: map['email'] as String?,
      role: map['role'] as String? ?? 'member',
      syncError: map['sync_error'] as String?,
    );
  }

  GroupMember copyWith({int? id, int? remoteId}) {
    return GroupMember(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      groupId: groupId,
      userId: userId,
      username: username,
      email: email,
      role: role,
      syncError: syncError,
    );
  }
}

class Group {
  final int? id;
  final int? remoteId;
  final String name;
  final String icon;
  final DateTime createdAt;
  final List<GroupMember> members;

  Group({
    this.id,
    this.remoteId,
    required this.name,
    this.icon = '💰',
    required this.createdAt,
    this.members = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'remote_id': remoteId,
      'name': name,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Group.fromMap(
    Map<String, dynamic> map, {
    List<GroupMember> members = const [],
  }) {
    return Group(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String? ?? '💰',
      createdAt: DateTime.parse(map['created_at'] as String),
      members: members,
    );
  }

  Group copyWith({int? id, int? remoteId, List<GroupMember>? members}) {
    return Group(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      name: name,
      icon: icon,
      createdAt: createdAt,
      members: members ?? this.members,
    );
  }
}
