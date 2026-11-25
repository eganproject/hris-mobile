/// Profil pengguna dari GET /me dan POST /auth/login.
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.employee,
    required this.isLeader,
    this.device,
  });

  final int id;
  final String name;
  final String? email;
  final EmployeeInfo employee;

  /// Punya bawahan (manager_id) — menu atasan di Profil.
  final bool isLeader;
  final DeviceInfoDto? device;

  String get firstName => employee.fullName.split(' ').first;

  String get initials {
    final parts = employee.fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? device}) {
    final dev = device ?? (json['device'] as Map?)?.cast<String, dynamic>();
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      employee: EmployeeInfo.fromJson((json['employee'] as Map).cast<String, dynamic>()),
      isLeader: json['is_leader'] as bool? ?? false,
      device: dev == null ? null : DeviceInfoDto.fromJson(dev),
    );
  }

  AppUser copyWith({DeviceInfoDto? device}) => AppUser(
        id: id,
        name: name,
        email: email,
        employee: employee,
        isLeader: isLeader,
        device: device ?? this.device,
      );
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

class DeviceInfoDto {
  DeviceInfoDto({required this.id, required this.status, this.model, this.platform, required this.consented});

  final int id;
  final String status;
  final String? model;
  final String? platform;
  final bool consented;

  factory DeviceInfoDto.fromJson(Map<String, dynamic> json) => DeviceInfoDto(
        id: json['id'] as int,
        status: json['status'] as String? ?? 'active',
        model: json['model'] as String?,
        platform: json['platform'] as String?,
        consented: json['consented'] as bool? ?? false,
      );
}
