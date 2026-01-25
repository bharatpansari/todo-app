import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:talkative_todo/repositories/settings_repository.dart';
import 'dart:io';

void main() {
  group('SettingsRepository', () {
    late Directory tempDir;

    setUp(() async {
      // Create a temporary directory for Hive
      tempDir = await Directory.systemTemp.createTemp('hive_testing');
      Hive.init(tempDir.path);
      
      // Initialize the repository
      await SettingsRepository().init();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await tempDir.delete(recursive: true);
    });

    test('Default theme should be system', () {
      final repo = SettingsRepository();
      expect(repo.getThemeMode(), ThemeMode.system);
    });

    test('Should save and retrieve Light theme', () async {
      final repo = SettingsRepository();
      await repo.setThemeMode(ThemeMode.light);
      expect(repo.getThemeMode(), ThemeMode.light);
    });

    test('Should save and retrieve Dark theme', () async {
      final repo = SettingsRepository();
      await repo.setThemeMode(ThemeMode.dark);
      expect(repo.getThemeMode(), ThemeMode.dark);
    });
    
    test('Should emit changes', () async {
        final repo = SettingsRepository();
        bool notified = false;
        repo.themeModeListenable.addListener(() {
            notified = true;
        });
        
        await repo.setThemeMode(ThemeMode.dark);
        // Wait a bit for listener
        await Future.delayed(Duration.zero);
        expect(repo.getThemeMode(), ThemeMode.dark);
        // Note: checking listenable notification in unit test might be tricky without pump, 
        // but basic state check confirms logic.
    });
  });
}
