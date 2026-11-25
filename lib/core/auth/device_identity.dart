import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Identitas HP yang dikirim saat login (untuk daftar HP di HR).
class DeviceIdentity {
  DeviceIdentity({required this.platform, this.model, this.osVersion, this.appVersion});

  final String platform;
  final String? model;
  final String? osVersion;
  final String? appVersion;

  static Future<DeviceIdentity> load() async {
    final info = DeviceInfoPlugin();
    final package = await PackageInfo.fromPlatform();
    final appVersion = '${package.version}+${package.buildNumber}';

    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      return DeviceIdentity(
        platform: 'android',
        model: '${a.manufacturer} ${a.model}'.trim(),
        osVersion: 'Android ${a.version.release}',
        appVersion: appVersion,
      );
    }
    if (Platform.isIOS) {
      final i = await info.iosInfo;
      return DeviceIdentity(
        platform: 'ios',
        model: i.utsname.machine,
        osVersion: 'iOS ${i.systemVersion}',
        appVersion: appVersion,
      );
    }
    return DeviceIdentity(platform: 'android', appVersion: appVersion);
  }

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'model': model,
        'os_version': osVersion,
        'app_version': appVersion,
      };
}
