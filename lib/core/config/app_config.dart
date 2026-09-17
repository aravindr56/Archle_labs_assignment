import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Global application configuration and anti-plagiarism verification metadata.
class AppConfig {
  static const String appName = 'Health Connect Realtime Dashboard';
  static const String packageName = 'com.archlelabs.healthconnect_dashboard';
  static const String firstGitCommitHash =
      '36896d3de6061cc5d6475a510305b503dec184e1';

  /// Deterministic Anti-Plagiarism SALT:
  /// SALT = SHA256("${packageName}:${firstGitCommitHash}") (hex lowercase)
  static const String salt =
      '5da55bbb5daa88d33d00a9ce0bfa055d719aebd0918c66f641e1fb17c6fa8072';

  /// Helper to verify and recompute SALT programmatically.
  static String computeSalt({
    required String pkgName,
    required String commitHash,
  }) {
    final raw = '$pkgName:$commitHash';
    return sha256.convert(utf8.encode(raw)).toString().toLowerCase();
  }

  /// Validates that the statically embedded salt matches runtime computation.
  static bool verifyIntegrity() {
    return computeSalt(
          pkgName: packageName,
          commitHash: firstGitCommitHash,
        ) ==
        salt;
  }
}
