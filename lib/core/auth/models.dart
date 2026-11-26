/// Profil pengguna dari GET /me dan POST /auth/login.
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.employee,
    required this.isLeader,
  });

  final int id;
  final String name;
  final String? email;
  final EmployeeInfo employee;

  /// Punya bawahan (manager_id) — menu atasan di Profil.
  final bool isLeader;

  String get firstName => employee.fullName.split(' ').first;

  String get initials {
    final parts = employee.fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      employee: EmployeeInfo.fromJson((json['employee'] as Map).cast<String, dynamic>()),
      isLeader: json['is_leader'] as bool? ?? false,
    );
  }
}

class EmployeeInfo {
  EmployeeInfo({
    required this.id,
    required this.number,
    required this.fullName,
    this.photoUrl,
    this.phone,
    this.branchId,
    this.branchName,
    this.department,
    this.jobPosition,
    this.managerName,
  });

  final int id;
  final String? number;
  final String fullName;
  final String? photoUrl;
  final String? phone;
  final int? branchId;
  final String? branchName;
  final String? department;
  final String? jobPosition;
  final String? managerName;

  factory EmployeeInfo.fromJson(Map<String, dynamic> json) {
    final branch = (json['branch'] as Map?)?.cast<String, dynamic>();
    final manager = (json['manager'] as Map?)?.cast<String, dynamic>();
    return EmployeeInfo(
      id: json['id'] as int,
      number: json['number'] as String?,
      fullName: json['full_name'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      phone: json['phone'] as String?,
      branchId: branch?['id'] as int?,
      branchName: branch?['name'] as String?,
      department: json['department'] as String?,
      jobPosition: json['job_position'] as String?,
      managerName: manager?['full_name'] as String?,
    );
  }
}
