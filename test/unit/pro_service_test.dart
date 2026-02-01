import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:talkative_todo/services/pro_service.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('ProService Tests', () {
    late ProService proService;

    setUp(() async {
      // Initialize Hive for testing in a temp directory
      // Note: In a real flutter test environment, path_provider acts differently.
      // We will use a unique sub-directory in the current directory for the test environment.
      
      final path = 'test/hive_db';
      Hive.init(path);
      
      if (await Hive.boxExists('pro_status')) {
         await Hive.deleteBoxFromDisk('pro_status');
      }
      
      proService = ProService();
      // Allow async init to complete
      await Future.delayed(const Duration(milliseconds: 200));
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('pro_status');
    });

    test('Default status is Free', () {
      expect(proService.isPro, false);
      expect(proService.canUseVoice, false);
      expect(proService.canUseTemplates, false);
    });

    test('Purchase unlocks Pro features', () async {
      await proService.purchasePro();
      // Allow Hive to write
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(proService.isPro, true);
      expect(proService.canUseVoice, true);
      expect(proService.canUseBoardView, true);
    });

    test('Category limits respect status', () {
      // Free limit is 5
      expect(proService.canAddMoreCategories(4), true); // 4 < 5
      expect(proService.canAddMoreCategories(5), false); // 5 is max
      expect(proService.canAddMoreCategories(6), false);
    });

    test('Category limits unlocked for Pro', () async {
      await proService.purchasePro();
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(proService.canAddMoreCategories(5), true);
      expect(proService.canAddMoreCategories(100), true);
    });
  });
}
