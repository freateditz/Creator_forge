import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:creator_forge/models/app_settings.dart';
import 'package:creator_forge/services/download/destination_resolver.dart';
import 'package:creator_forge/services/download/file_category_classifier.dart';

void main() {
  group('DestinationResolver Tests', () {
    late Directory tempDir;
    late Directory tempOutputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'creator_forge_dest_resolver_test_',
      );
      tempOutputDir = await Directory.systemTemp.createTemp(
        'creator_forge_dest_output_',
      );
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
      try {
        await tempOutputDir.delete(recursive: true);
      } catch (_) {}
    });

    final resolver = DestinationResolver.instance;

    test('1. Absolute Windows category override is used directly', () async {
      final baseDir = tempOutputDir.path;
      final absoluteOverride = r'D:\Custom\Category\Videos';

      final settings = AppSettings(
        defaultDownloadsDir: baseDir,
        tempDir: tempDir.path,
        autoOrganizeEnabled: true,
        categoryFolderOverrides: {'videos': absoluteOverride},
      );

      final outputDir = await resolver.resolveOutputDirectory(
        category: FileCategory.videos,
        settings: settings,
        customCategoryFolder: null,
      );

      // Absolute override should be used directly, not joined to baseDir
      expect(outputDir.path, equals(absoluteOverride));
      expect(outputDir.path, isNot(equals(p.join(baseDir, absoluteOverride))));
    });

    test(
      '2. Relative category folder override is joined to base directory',
      () async {
        final baseDir = tempOutputDir.path;
        final relativeOverride = 'MyCustomVideos';

        final settings = AppSettings(
          defaultDownloadsDir: baseDir,
          tempDir: tempDir.path,
          autoOrganizeEnabled: true,
          categoryFolderOverrides: {'videos': relativeOverride},
        );

        final outputDir = await resolver.resolveOutputDirectory(
          category: FileCategory.videos,
          settings: settings,
          customCategoryFolder: null,
        );

        expect(outputDir.path, equals(p.join(baseDir, relativeOverride)));
      },
    );

    test('3. Default category folder is joined to base directory', () async {
      final baseDir = tempOutputDir.path;

      final settings = AppSettings(
        defaultDownloadsDir: baseDir,
        tempDir: tempDir.path,
        autoOrganizeEnabled: true,
        categoryFolderOverrides: null,
      );

      final outputDir = await resolver.resolveOutputDirectory(
        category: FileCategory.videos,
        settings: settings,
        customCategoryFolder: null,
      );

      expect(outputDir.path, equals(p.join(baseDir, 'Videos')));
    });

    test('4. Empty override falls back to default category folder', () async {
      final baseDir = tempOutputDir.path;

      final settings = AppSettings(
        defaultDownloadsDir: baseDir,
        tempDir: tempDir.path,
        autoOrganizeEnabled: true,
        categoryFolderOverrides: {'videos': ''},
      );

      final outputDir = await resolver.resolveOutputDirectory(
        category: FileCategory.videos,
        settings: settings,
        customCategoryFolder: null,
      );

      // Empty string should fall back to default
      expect(outputDir.path, equals(p.join(baseDir, 'Videos')));
    });

    test('5. Absolute macOS category override is used directly', () async {
      final baseDir = tempOutputDir.path;
      final absoluteOverride = p.join(tempDir.path, 'AbsoluteVideos');

      final settings = AppSettings(
        defaultDownloadsDir: baseDir,
        tempDir: tempDir.path,
        autoOrganizeEnabled: true,
        categoryFolderOverrides: {'videos': absoluteOverride},
      );

      final outputDir = await resolver.resolveOutputDirectory(
        category: FileCategory.videos,
        settings: settings,
        customCategoryFolder: null,
      );

      // Absolute override should be used directly, not joined to baseDir
      expect(outputDir.path, equals(absoluteOverride));
      expect(outputDir.path, isNot(equals(baseDir)));
    });

    test('6. UNC path category override is used directly', () async {
      final baseDir = tempOutputDir.path;
      final uncOverride = r'\\SERVER\Share\Videos';

      final settings = AppSettings(
        defaultDownloadsDir: baseDir,
        tempDir: tempDir.path,
        autoOrganizeEnabled: true,
        categoryFolderOverrides: {'videos': uncOverride},
      );

      final outputDir = await resolver.resolveOutputDirectory(
        category: FileCategory.videos,
        settings: settings,
        customCategoryFolder: null,
      );

      // UNC path should be used directly
      expect(outputDir.path, equals(uncOverride));
      expect(outputDir.path, isNot(equals(p.join(baseDir, uncOverride))));
    });

    test(
      '7. Custom base directory with auto-organize disabled uses base directly',
      () async {
        final customBaseDir = p.join(tempOutputDir.path, 'CustomBase');

        final settings = AppSettings(
          defaultDownloadsDir: customBaseDir,
          tempDir: tempDir.path,
          autoOrganizeEnabled: false, // Disabled
          categoryFolderOverrides: {'videos': 'ShouldNotBeUsed'},
        );

        final outputDir = await resolver.resolveOutputDirectory(
          category: FileCategory.videos,
          settings: settings,
          customCategoryFolder: null,
        );

        // With auto-organize disabled, base directory should be used directly
        expect(outputDir.path, equals(customBaseDir));
      },
    );

    test(
      '8. Explicit customCategoryFolder absolute path is used directly',
      () async {
        final baseDir = tempOutputDir.path;
        final explicitAbsolute = r'C:\Explicit\Downloads\Audio';

        final settings = AppSettings(
          defaultDownloadsDir: baseDir,
          tempDir: tempDir.path,
          autoOrganizeEnabled: true,
          categoryFolderOverrides: null,
        );

        // This simulates what SegmentedHttpEngine does when outputDirectory != defaultOutputDir
        final result = await resolver.resolve(
          suggestedFilename: 'test.mp3',
          category: FileCategory.music,
          settings: settings,
          customCategoryFolder: explicitAbsolute,
        );

        expect(result.$1.path, equals(explicitAbsolute));
        expect(
          result.$1.path,
          isNot(equals(p.join(baseDir, explicitAbsolute))),
        );
      },
    );

    test('9. No duplicated base directory in resolved paths', () async {
      final baseDir = tempOutputDir.path;
      final relativeFolder = 'Documents';

      final settings = AppSettings(
        defaultDownloadsDir: baseDir,
        tempDir: tempDir.path,
        autoOrganizeEnabled: true,
        categoryFolderOverrides: {'documents': relativeFolder},
      );

      final result = await resolver.resolve(
        suggestedFilename: 'test.pdf',
        category: FileCategory.documents,
        settings: settings,
        customCategoryFolder: null,
      );

      // Path should only contain baseDir once
      final expectedPath = p.join(baseDir, relativeFolder, 'test.pdf');
      expect(result.$3, equals(expectedPath));
      // Verify baseDir doesn't appear twice
      expect(
        result.$3.split(baseDir).length,
        equals(2),
      ); // split produces n+1 parts
    });

    test(
      '10. Windows drive-letter path with forward slashes handled correctly',
      () async {
        final baseDir = tempOutputDir.path;
        final windowsPath = 'E:/Downloads/Music';

        final settings = AppSettings(
          defaultDownloadsDir: baseDir,
          tempDir: tempDir.path,
          autoOrganizeEnabled: true,
          categoryFolderOverrides: {'music': windowsPath},
        );

        final outputDir = await resolver.resolveOutputDirectory(
          category: FileCategory.music,
          settings: settings,
          customCategoryFolder: null,
        );

        expect(outputDir.path, equals(windowsPath));
      },
    );

    test(
      '11. Explicit relative customCategoryFolder is joined to base',
      () async {
        final baseDir = tempOutputDir.path;
        final explicitRelative = 'ExplicitRelative';

        final settings = AppSettings(
          defaultDownloadsDir: baseDir,
          tempDir: tempDir.path,
          autoOrganizeEnabled: true,
          categoryFolderOverrides: null,
        );

        final result = await resolver.resolve(
          suggestedFilename: 'test.mp4',
          category: FileCategory.videos,
          settings: settings,
          customCategoryFolder: explicitRelative,
        );

        expect(result.$1.path, equals(p.join(baseDir, explicitRelative)));
      },
    );

    test('12. Mixed category and explicit customCategoryFolder', () async {
      final baseDir = tempOutputDir.path;
      final explicitAbsolute = r'D:\Explicit\Category';

      final settings = AppSettings(
        defaultDownloadsDir: baseDir,
        tempDir: tempDir.path,
        autoOrganizeEnabled: true,
        categoryFolderOverrides: {'videos': 'ShouldNotBeUsed'},
      );

      // Explicit customCategoryFolder should take precedence over category override
      final result = await resolver.resolve(
        suggestedFilename: 'test.mp4',
        category: FileCategory.videos,
        settings: settings,
        customCategoryFolder: explicitAbsolute,
      );

      expect(result.$1.path, equals(explicitAbsolute));
      expect(result.$1.path, isNot(equals(p.join(baseDir, 'ShouldNotBeUsed'))));
    });
  });
}
