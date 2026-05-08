import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/data/models/models.dart';

void main() {
  group('ProfileModel Tests', () {
    final now = DateTime.now();
    final profile = ProfileModel(
      id: '1',
      firebaseUid: 'uid_1',
      email: 'test@example.com',
      fullName: 'Test User',
      role: UserRole.public,
      createdAt: now,
    );

    test('displayName should return fullName if present', () {
      expect(profile.displayName, 'Test User');
    });

    test('displayName should return email prefix if fullName is null', () {
      final p2 = ProfileModel(
        id: '2',
        firebaseUid: 'uid_2',
        email: 'john.doe@example.com',
        role: UserRole.public,
        createdAt: now,
      );
      expect(p2.displayName, 'john.doe');
    });

    test('roleLabel should return correct label for public role', () {
      expect(profile.roleLabel, 'Client');
    });

    test('roleLabel should return correct label for admin role', () {
      final admin = profile.copyWith(role: UserRole.admin);
      expect(admin.roleLabel, 'Administrateur');
    });
  });
}
