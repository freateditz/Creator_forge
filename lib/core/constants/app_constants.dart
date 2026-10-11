class AppConstants {
  AppConstants._();

  static const appName = 'CreatorForge';
  static const appVersion = '1.0.0';
  static const appBuildNumber = 1;

  static const defaultWindowWidth = 1280.0;
  static const defaultWindowHeight = 800.0;
  static const minWindowWidth = 900.0;
  static const minWindowHeight = 600.0;

  static const sidebarWidth = 220.0;
  static const sidebarCollapsedWidth = 60.0;

  static const defaultConcurrentDownloads = 3;
  static const defaultConcurrentJobs = 2;
  static const maxConcurrentDownloads = 10;

  static const thumbnailCacheSize = 100;
  static const metadataCacheDuration = Duration(minutes: 30);

  static const tempDirName = 'creator_forge_temp';
  static const dbFileName = 'creator_forge.db';
  static const logFileName = 'creator_forge.log';

  static const supportedVideoExtensions = [
    'mp4',
    'mkv',
    'webm',
    'mov',
    'avi',
    'flv',
    'wmv',
    'm4v',
    'ts',
  ];
  static const supportedAudioExtensions = [
    'mp3',
    'wav',
    'aac',
    'm4a',
    'flac',
    'ogg',
    'opus',
    'wma',
  ];
  static const supportedImageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
    'tiff',
    'heic',
  ];
}
