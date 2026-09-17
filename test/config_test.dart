import 'package:flutter_test/flutter_test.dart';
import 'package:healthconnect_dashboard/core/config/app_config.dart';

void main() {
  group('AppConfig & Anti-Plagiarism SALT', () {
    test('verifies deterministic SALT matches packageName:firstGitCommitHash',
        () {
      final expectedSalt = AppConfig.computeSalt(
        pkgName: AppConfig.packageName,
        commitHash: AppConfig.firstGitCommitHash,
      );

      expect(AppConfig.salt, equals(expectedSalt));
      expect(AppConfig.verifyIntegrity(), isTrue);
    });

    test('package name and initial commit hash are not empty', () {
      expect(AppConfig.packageName,
          equals('com.archlelabs.healthconnect_dashboard'));
      expect(AppConfig.firstGitCommitHash, hasLength(40));
      expect(AppConfig.salt, hasLength(64));
    });
  });
}
