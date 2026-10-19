import 'package:cloud_firestore/cloud_firestore.dart';

enum AccessStatus {
  authorized,
  pending,
  blocked;

  static AccessStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'authorized':
      case 'autorizado':
      case 'approved':
      case 'aprovado':
        return AccessStatus.authorized;
      case 'blocked':
      case 'bloqueado':
      case 'revoked':
      case 'revogado':
        return AccessStatus.blocked;
      case 'pending':
      case 'pendente':
      default:
        return AccessStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case AccessStatus.authorized:
        return 'authorized';
      case AccessStatus.blocked:
        return 'blocked';
      case AccessStatus.pending:
        return 'pending';
    }
  }

  String get labelPt {
    switch (this) {
      case AccessStatus.authorized:
        return 'Autorizado';
      case AccessStatus.pending:
        return 'Pendente';
      case AccessStatus.blocked:
        return 'Bloqueado';
    }
  }
}

enum UserRole {
  admin,
  user;

  static UserRole fromString(String? val) {
    if (val?.toLowerCase().trim() == 'admin' ||
        val?.toLowerCase().trim() == 'administrador') {
      return UserRole.admin;
    }
    return UserRole.user;
  }

  String toDbString() => this == UserRole.admin ? 'admin' : 'user';

  String get labelPt => this == UserRole.admin ? 'Administrador Principal' : 'Usuário';
}

class UserAccessInfo {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final AccessStatus status;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? requestedAt;
  final DateTime? lastLogin;
  final DateTime? approvedAt;
  final String? approvedBy;
  final bool isPreAuthorized;

  const UserAccessInfo({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.status,
    required this.role,
    this.createdAt,
    this.requestedAt,
    this.lastLogin,
    this.approvedAt,
    this.approvedBy,
    this.isPreAuthorized = false,
  });

  bool get isAuthorized => status == AccessStatus.authorized;
  bool get isPending => status == AccessStatus.pending;
  bool get isBlocked => status == AccessStatus.blocked;
  bool get isAdmin => role == UserRole.admin;

  factory UserAccessInfo.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserAccessInfo.fromMap(doc.id, data);
  }

  factory UserAccessInfo.fromMap(String uid, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final email = (data['email'] as String? ?? '').trim();
    final isPrimaryAdmin = email.toLowerCase() == 'nivaldo.nilngn@gmail.com';

    final role = isPrimaryAdmin
        ? UserRole.admin
        : UserRole.fromString(data['role'] as String?);

    final status = isPrimaryAdmin
        ? AccessStatus.authorized
        : AccessStatus.fromString(data['status'] as String?);

    return UserAccessInfo(
      uid: uid,
      email: email,
      displayName: (data['name'] as String?) ?? (data['displayName'] as String?),
      photoUrl: data['photoUrl'] as String?,
      status: status,
      role: role,
      createdAt: parseDate(data['createdAt']),
      requestedAt: parseDate(data['requestedAt'] ?? data['createdAt']),
      lastLogin: parseDate(data['lastLogin']),
      approvedAt: parseDate(data['approvedAt']),
      approvedBy: data['approvedBy'] as String?,
      isPreAuthorized: data['isPreAuthorized'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'status': status.toDbString(),
      'role': role.toDbString(),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (requestedAt != null) 'requestedAt': Timestamp.fromDate(requestedAt!),
      if (lastLogin != null) 'lastLogin': Timestamp.fromDate(lastLogin!),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (approvedBy != null) 'approvedBy': approvedBy,
      'isPreAuthorized': isPreAuthorized,
    };
  }

  UserAccessInfo copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    AccessStatus? status,
    UserRole? role,
    DateTime? createdAt,
    DateTime? requestedAt,
    DateTime? lastLogin,
    DateTime? approvedAt,
    String? approvedBy,
    bool? isPreAuthorized,
  }) {
    return UserAccessInfo(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      requestedAt: requestedAt ?? this.requestedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      isPreAuthorized: isPreAuthorized ?? this.isPreAuthorized,
    );
  }
}

class PreAuthorizedEmail {
  final String email;
  final AccessStatus status;
  final DateTime? addedAt;
  final String? addedBy;
  final String? note;

  const PreAuthorizedEmail({
    required this.email,
    this.status = AccessStatus.authorized,
    this.addedAt,
    this.addedBy,
    this.note,
  });

  factory PreAuthorizedEmail.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return PreAuthorizedEmail(
      email: (data['email'] as String? ?? doc.id).trim().toLowerCase(),
      status: AccessStatus.fromString(data['status'] as String?),
      addedAt: parseDate(data['addedAt']),
      addedBy: data['addedBy'] as String?,
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'status': status.toDbString(),
      if (addedAt != null) 'addedAt': Timestamp.fromDate(addedAt!),
      if (addedBy != null) 'addedBy': addedBy,
      if (note != null) 'note': note,
    };
  }
}

class AccessAuditLog {
  final String id;
  final String adminUid;
  final String adminEmail;
  final String targetEmail;
  final String? targetUid;
  final String action; // 'approve', 'block', 'unblock', 'pre_authorize', 'remove_pre_authorize'
  final DateTime timestamp;
  final String? details;

  const AccessAuditLog({
    required this.id,
    required this.adminUid,
    required this.adminEmail,
    required this.targetEmail,
    this.targetUid,
    required this.action,
    required this.timestamp,
    this.details,
  });

  factory AccessAuditLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return AccessAuditLog(
      id: doc.id,
      adminUid: data['adminUid'] as String? ?? '',
      adminEmail: data['adminEmail'] as String? ?? '',
      targetEmail: data['targetEmail'] as String? ?? '',
      targetUid: data['targetUid'] as String?,
      action: data['action'] as String? ?? 'action',
      timestamp: parseDate(data['timestamp']),
      details: data['details'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminUid': adminUid,
      'adminEmail': adminEmail,
      'targetEmail': targetEmail,
      if (targetUid != null) 'targetUid': targetUid,
      'action': action,
      'timestamp': Timestamp.fromDate(timestamp),
      if (details != null) 'details': details,
    };
  }
}
