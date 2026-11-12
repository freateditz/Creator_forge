// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DownloadHistoryTableTable extends DownloadHistoryTable
    with TableInfo<$DownloadHistoryTableTable, DownloadHistoryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Untitled'),
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelNameMeta = const VerificationMeta(
    'channelName',
  );
  @override
  late final GeneratedColumn<String> channelName = GeneratedColumn<String>(
    'channel_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputPathMeta = const VerificationMeta(
    'outputPath',
  );
  @override
  late final GeneratedColumn<String> outputPath = GeneratedColumn<String>(
    'output_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('completed'),
  );
  static const VerificationMeta _eTagMeta = const VerificationMeta('eTag');
  @override
  late final GeneratedColumn<String> eTag = GeneratedColumn<String>(
    'e_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<String> lastModified = GeneratedColumn<String>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileMeta = const VerificationMeta(
    'profile',
  );
  @override
  late final GeneratedColumn<String> profile = GeneratedColumn<String>(
    'profile',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    url,
    title,
    thumbnailUrl,
    channelName,
    outputPath,
    format,
    fileSizeBytes,
    durationSeconds,
    status,
    eTag,
    lastModified,
    profile,
    metadataJson,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadHistoryTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('channel_name')) {
      context.handle(
        _channelNameMeta,
        channelName.isAcceptableOrUnknown(
          data['channel_name']!,
          _channelNameMeta,
        ),
      );
    }
    if (data.containsKey('output_path')) {
      context.handle(
        _outputPathMeta,
        outputPath.isAcceptableOrUnknown(data['output_path']!, _outputPathMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('e_tag')) {
      context.handle(
        _eTagMeta,
        eTag.isAcceptableOrUnknown(data['e_tag']!, _eTagMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('profile')) {
      context.handle(
        _profileMeta,
        profile.isAcceptableOrUnknown(data['profile']!, _profileMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadHistoryTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadHistoryTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      channelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_name'],
      ),
      outputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_path'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      eTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}e_tag'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified'],
      ),
      profile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadHistoryTableTable createAlias(String alias) {
    return $DownloadHistoryTableTable(attachedDatabase, alias);
  }
}

class DownloadHistoryTableData extends DataClass
    implements Insertable<DownloadHistoryTableData> {
  final int id;
  final String taskId;
  final String url;
  final String title;
  final String? thumbnailUrl;
  final String? channelName;
  final String outputPath;
  final String format;
  final int? fileSizeBytes;
  final int? durationSeconds;
  final String status;
  final String? eTag;
  final String? lastModified;
  final String? profile;
  final String? metadataJson;
  final DateTime createdAt;
  final DateTime? completedAt;
  const DownloadHistoryTableData({
    required this.id,
    required this.taskId,
    required this.url,
    required this.title,
    this.thumbnailUrl,
    this.channelName,
    required this.outputPath,
    required this.format,
    this.fileSizeBytes,
    this.durationSeconds,
    required this.status,
    this.eTag,
    this.lastModified,
    this.profile,
    this.metadataJson,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_id'] = Variable<String>(taskId);
    map['url'] = Variable<String>(url);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || channelName != null) {
      map['channel_name'] = Variable<String>(channelName);
    }
    map['output_path'] = Variable<String>(outputPath);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || fileSizeBytes != null) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || eTag != null) {
      map['e_tag'] = Variable<String>(eTag);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<String>(lastModified);
    }
    if (!nullToAbsent || profile != null) {
      map['profile'] = Variable<String>(profile);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return DownloadHistoryTableCompanion(
      id: Value(id),
      taskId: Value(taskId),
      url: Value(url),
      title: Value(title),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      channelName: channelName == null && nullToAbsent
          ? const Value.absent()
          : Value(channelName),
      outputPath: Value(outputPath),
      format: Value(format),
      fileSizeBytes: fileSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSizeBytes),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      status: Value(status),
      eTag: eTag == null && nullToAbsent ? const Value.absent() : Value(eTag),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      profile: profile == null && nullToAbsent
          ? const Value.absent()
          : Value(profile),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadHistoryTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadHistoryTableData(
      id: serializer.fromJson<int>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      url: serializer.fromJson<String>(json['url']),
      title: serializer.fromJson<String>(json['title']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      channelName: serializer.fromJson<String?>(json['channelName']),
      outputPath: serializer.fromJson<String>(json['outputPath']),
      format: serializer.fromJson<String>(json['format']),
      fileSizeBytes: serializer.fromJson<int?>(json['fileSizeBytes']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      status: serializer.fromJson<String>(json['status']),
      eTag: serializer.fromJson<String?>(json['eTag']),
      lastModified: serializer.fromJson<String?>(json['lastModified']),
      profile: serializer.fromJson<String?>(json['profile']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskId': serializer.toJson<String>(taskId),
      'url': serializer.toJson<String>(url),
      'title': serializer.toJson<String>(title),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'channelName': serializer.toJson<String?>(channelName),
      'outputPath': serializer.toJson<String>(outputPath),
      'format': serializer.toJson<String>(format),
      'fileSizeBytes': serializer.toJson<int?>(fileSizeBytes),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'status': serializer.toJson<String>(status),
      'eTag': serializer.toJson<String?>(eTag),
      'lastModified': serializer.toJson<String?>(lastModified),
      'profile': serializer.toJson<String?>(profile),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadHistoryTableData copyWith({
    int? id,
    String? taskId,
    String? url,
    String? title,
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<String?> channelName = const Value.absent(),
    String? outputPath,
    String? format,
    Value<int?> fileSizeBytes = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    String? status,
    Value<String?> eTag = const Value.absent(),
    Value<String?> lastModified = const Value.absent(),
    Value<String?> profile = const Value.absent(),
    Value<String?> metadataJson = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadHistoryTableData(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    url: url ?? this.url,
    title: title ?? this.title,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    channelName: channelName.present ? channelName.value : this.channelName,
    outputPath: outputPath ?? this.outputPath,
    format: format ?? this.format,
    fileSizeBytes: fileSizeBytes.present
        ? fileSizeBytes.value
        : this.fileSizeBytes,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    status: status ?? this.status,
    eTag: eTag.present ? eTag.value : this.eTag,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    profile: profile.present ? profile.value : this.profile,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadHistoryTableData copyWithCompanion(
    DownloadHistoryTableCompanion data,
  ) {
    return DownloadHistoryTableData(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      url: data.url.present ? data.url.value : this.url,
      title: data.title.present ? data.title.value : this.title,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      channelName: data.channelName.present
          ? data.channelName.value
          : this.channelName,
      outputPath: data.outputPath.present
          ? data.outputPath.value
          : this.outputPath,
      format: data.format.present ? data.format.value : this.format,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      status: data.status.present ? data.status.value : this.status,
      eTag: data.eTag.present ? data.eTag.value : this.eTag,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      profile: data.profile.present ? data.profile.value : this.profile,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadHistoryTableData(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('channelName: $channelName, ')
          ..write('outputPath: $outputPath, ')
          ..write('format: $format, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('status: $status, ')
          ..write('eTag: $eTag, ')
          ..write('lastModified: $lastModified, ')
          ..write('profile: $profile, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    url,
    title,
    thumbnailUrl,
    channelName,
    outputPath,
    format,
    fileSizeBytes,
    durationSeconds,
    status,
    eTag,
    lastModified,
    profile,
    metadataJson,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadHistoryTableData &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.url == this.url &&
          other.title == this.title &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.channelName == this.channelName &&
          other.outputPath == this.outputPath &&
          other.format == this.format &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.durationSeconds == this.durationSeconds &&
          other.status == this.status &&
          other.eTag == this.eTag &&
          other.lastModified == this.lastModified &&
          other.profile == this.profile &&
          other.metadataJson == this.metadataJson &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class DownloadHistoryTableCompanion
    extends UpdateCompanion<DownloadHistoryTableData> {
  final Value<int> id;
  final Value<String> taskId;
  final Value<String> url;
  final Value<String> title;
  final Value<String?> thumbnailUrl;
  final Value<String?> channelName;
  final Value<String> outputPath;
  final Value<String> format;
  final Value<int?> fileSizeBytes;
  final Value<int?> durationSeconds;
  final Value<String> status;
  final Value<String?> eTag;
  final Value<String?> lastModified;
  final Value<String?> profile;
  final Value<String?> metadataJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  const DownloadHistoryTableCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.channelName = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.format = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.status = const Value.absent(),
    this.eTag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.profile = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  DownloadHistoryTableCompanion.insert({
    this.id = const Value.absent(),
    required String taskId,
    required String url,
    this.title = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.channelName = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.format = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.status = const Value.absent(),
    this.eTag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.profile = const Value.absent(),
    this.metadataJson = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
  }) : taskId = Value(taskId),
       url = Value(url),
       createdAt = Value(createdAt);
  static Insertable<DownloadHistoryTableData> custom({
    Expression<int>? id,
    Expression<String>? taskId,
    Expression<String>? url,
    Expression<String>? title,
    Expression<String>? thumbnailUrl,
    Expression<String>? channelName,
    Expression<String>? outputPath,
    Expression<String>? format,
    Expression<int>? fileSizeBytes,
    Expression<int>? durationSeconds,
    Expression<String>? status,
    Expression<String>? eTag,
    Expression<String>? lastModified,
    Expression<String>? profile,
    Expression<String>? metadataJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (channelName != null) 'channel_name': channelName,
      if (outputPath != null) 'output_path': outputPath,
      if (format != null) 'format': format,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (status != null) 'status': status,
      if (eTag != null) 'e_tag': eTag,
      if (lastModified != null) 'last_modified': lastModified,
      if (profile != null) 'profile': profile,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  DownloadHistoryTableCompanion copyWith({
    Value<int>? id,
    Value<String>? taskId,
    Value<String>? url,
    Value<String>? title,
    Value<String?>? thumbnailUrl,
    Value<String?>? channelName,
    Value<String>? outputPath,
    Value<String>? format,
    Value<int?>? fileSizeBytes,
    Value<int?>? durationSeconds,
    Value<String>? status,
    Value<String?>? eTag,
    Value<String?>? lastModified,
    Value<String?>? profile,
    Value<String?>? metadataJson,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
  }) {
    return DownloadHistoryTableCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channelName: channelName ?? this.channelName,
      outputPath: outputPath ?? this.outputPath,
      format: format ?? this.format,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      eTag: eTag ?? this.eTag,
      lastModified: lastModified ?? this.lastModified,
      profile: profile ?? this.profile,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (channelName.present) {
      map['channel_name'] = Variable<String>(channelName.value);
    }
    if (outputPath.present) {
      map['output_path'] = Variable<String>(outputPath.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (eTag.present) {
      map['e_tag'] = Variable<String>(eTag.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<String>(lastModified.value);
    }
    if (profile.present) {
      map['profile'] = Variable<String>(profile.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadHistoryTableCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('channelName: $channelName, ')
          ..write('outputPath: $outputPath, ')
          ..write('format: $format, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('status: $status, ')
          ..write('eTag: $eTag, ')
          ..write('lastModified: $lastModified, ')
          ..write('profile: $profile, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadSegmentsTableTable extends DownloadSegmentsTable
    with TableInfo<$DownloadSegmentsTableTable, DownloadSegmentsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadSegmentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES download_history (task_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _segmentIndexMeta = const VerificationMeta(
    'segmentIndex',
  );
  @override
  late final GeneratedColumn<int> segmentIndex = GeneratedColumn<int>(
    'segment_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesDownloadedMeta = const VerificationMeta(
    'bytesDownloaded',
  );
  @override
  late final GeneratedColumn<int> bytesDownloaded = GeneratedColumn<int>(
    'bytes_downloaded',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _lastUpdatedAtMeta = const VerificationMeta(
    'lastUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdatedAt =
      GeneratedColumn<DateTime>(
        'last_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    segmentIndex,
    startOffset,
    endOffset,
    bytesDownloaded,
    status,
    lastUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadSegmentsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('segment_index')) {
      context.handle(
        _segmentIndexMeta,
        segmentIndex.isAcceptableOrUnknown(
          data['segment_index']!,
          _segmentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentIndexMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('bytes_downloaded')) {
      context.handle(
        _bytesDownloadedMeta,
        bytesDownloaded.isAcceptableOrUnknown(
          data['bytes_downloaded']!,
          _bytesDownloadedMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('last_updated_at')) {
      context.handle(
        _lastUpdatedAtMeta,
        lastUpdatedAt.isAcceptableOrUnknown(
          data['last_updated_at']!,
          _lastUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {taskId, segmentIndex},
  ];
  @override
  DownloadSegmentsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadSegmentsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      segmentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_index'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      bytesDownloaded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_downloaded'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated_at'],
      )!,
    );
  }

  @override
  $DownloadSegmentsTableTable createAlias(String alias) {
    return $DownloadSegmentsTableTable(attachedDatabase, alias);
  }
}

class DownloadSegmentsTableData extends DataClass
    implements Insertable<DownloadSegmentsTableData> {
  final int id;
  final String taskId;
  final int segmentIndex;
  final int startOffset;
  final int endOffset;
  final int bytesDownloaded;
  final String status;
  final DateTime lastUpdatedAt;
  const DownloadSegmentsTableData({
    required this.id,
    required this.taskId,
    required this.segmentIndex,
    required this.startOffset,
    required this.endOffset,
    required this.bytesDownloaded,
    required this.status,
    required this.lastUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_id'] = Variable<String>(taskId);
    map['segment_index'] = Variable<int>(segmentIndex);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['bytes_downloaded'] = Variable<int>(bytesDownloaded);
    map['status'] = Variable<String>(status);
    map['last_updated_at'] = Variable<DateTime>(lastUpdatedAt);
    return map;
  }

  DownloadSegmentsTableCompanion toCompanion(bool nullToAbsent) {
    return DownloadSegmentsTableCompanion(
      id: Value(id),
      taskId: Value(taskId),
      segmentIndex: Value(segmentIndex),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      bytesDownloaded: Value(bytesDownloaded),
      status: Value(status),
      lastUpdatedAt: Value(lastUpdatedAt),
    );
  }

  factory DownloadSegmentsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadSegmentsTableData(
      id: serializer.fromJson<int>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      segmentIndex: serializer.fromJson<int>(json['segmentIndex']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      bytesDownloaded: serializer.fromJson<int>(json['bytesDownloaded']),
      status: serializer.fromJson<String>(json['status']),
      lastUpdatedAt: serializer.fromJson<DateTime>(json['lastUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskId': serializer.toJson<String>(taskId),
      'segmentIndex': serializer.toJson<int>(segmentIndex),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'bytesDownloaded': serializer.toJson<int>(bytesDownloaded),
      'status': serializer.toJson<String>(status),
      'lastUpdatedAt': serializer.toJson<DateTime>(lastUpdatedAt),
    };
  }

  DownloadSegmentsTableData copyWith({
    int? id,
    String? taskId,
    int? segmentIndex,
    int? startOffset,
    int? endOffset,
    int? bytesDownloaded,
    String? status,
    DateTime? lastUpdatedAt,
  }) => DownloadSegmentsTableData(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    segmentIndex: segmentIndex ?? this.segmentIndex,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
    status: status ?? this.status,
    lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
  );
  DownloadSegmentsTableData copyWithCompanion(
    DownloadSegmentsTableCompanion data,
  ) {
    return DownloadSegmentsTableData(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      segmentIndex: data.segmentIndex.present
          ? data.segmentIndex.value
          : this.segmentIndex,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      bytesDownloaded: data.bytesDownloaded.present
          ? data.bytesDownloaded.value
          : this.bytesDownloaded,
      status: data.status.present ? data.status.value : this.status,
      lastUpdatedAt: data.lastUpdatedAt.present
          ? data.lastUpdatedAt.value
          : this.lastUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadSegmentsTableData(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('status: $status, ')
          ..write('lastUpdatedAt: $lastUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    segmentIndex,
    startOffset,
    endOffset,
    bytesDownloaded,
    status,
    lastUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadSegmentsTableData &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.segmentIndex == this.segmentIndex &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.bytesDownloaded == this.bytesDownloaded &&
          other.status == this.status &&
          other.lastUpdatedAt == this.lastUpdatedAt);
}

class DownloadSegmentsTableCompanion
    extends UpdateCompanion<DownloadSegmentsTableData> {
  final Value<int> id;
  final Value<String> taskId;
  final Value<int> segmentIndex;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<int> bytesDownloaded;
  final Value<String> status;
  final Value<DateTime> lastUpdatedAt;
  const DownloadSegmentsTableCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.segmentIndex = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.bytesDownloaded = const Value.absent(),
    this.status = const Value.absent(),
    this.lastUpdatedAt = const Value.absent(),
  });
  DownloadSegmentsTableCompanion.insert({
    this.id = const Value.absent(),
    required String taskId,
    required int segmentIndex,
    required int startOffset,
    required int endOffset,
    this.bytesDownloaded = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime lastUpdatedAt,
  }) : taskId = Value(taskId),
       segmentIndex = Value(segmentIndex),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset),
       lastUpdatedAt = Value(lastUpdatedAt);
  static Insertable<DownloadSegmentsTableData> custom({
    Expression<int>? id,
    Expression<String>? taskId,
    Expression<int>? segmentIndex,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<int>? bytesDownloaded,
    Expression<String>? status,
    Expression<DateTime>? lastUpdatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (segmentIndex != null) 'segment_index': segmentIndex,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (bytesDownloaded != null) 'bytes_downloaded': bytesDownloaded,
      if (status != null) 'status': status,
      if (lastUpdatedAt != null) 'last_updated_at': lastUpdatedAt,
    });
  }

  DownloadSegmentsTableCompanion copyWith({
    Value<int>? id,
    Value<String>? taskId,
    Value<int>? segmentIndex,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<int>? bytesDownloaded,
    Value<String>? status,
    Value<DateTime>? lastUpdatedAt,
  }) {
    return DownloadSegmentsTableCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      status: status ?? this.status,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (segmentIndex.present) {
      map['segment_index'] = Variable<int>(segmentIndex.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (bytesDownloaded.present) {
      map['bytes_downloaded'] = Variable<int>(bytesDownloaded.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastUpdatedAt.present) {
      map['last_updated_at'] = Variable<DateTime>(lastUpdatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadSegmentsTableCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('status: $status, ')
          ..write('lastUpdatedAt: $lastUpdatedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTableTable extends SettingsTable
    with TableInfo<$SettingsTableTable, SettingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsTableData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTableTable createAlias(String alias) {
    return $SettingsTableTable(attachedDatabase, alias);
  }
}

class SettingsTableData extends DataClass
    implements Insertable<SettingsTableData> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const SettingsTableData({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsTableCompanion toCompanion(bool nullToAbsent) {
    return SettingsTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettingsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsTableData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SettingsTableData copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => SettingsTableData(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SettingsTableData copyWithCompanion(SettingsTableCompanion data) {
    return SettingsTableData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsTableData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsTableData &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsTableCompanion extends UpdateCompanion<SettingsTableData> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsTableCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<SettingsTableData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProcessingJobsTableTable extends ProcessingJobsTable
    with TableInfo<$ProcessingJobsTableTable, ProcessingJobsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessingJobsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _jobTypeMeta = const VerificationMeta(
    'jobType',
  );
  @override
  late final GeneratedColumn<String> jobType = GeneratedColumn<String>(
    'job_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputPathMeta = const VerificationMeta(
    'inputPath',
  );
  @override
  late final GeneratedColumn<String> inputPath = GeneratedColumn<String>(
    'input_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputPathMeta = const VerificationMeta(
    'outputPath',
  );
  @override
  late final GeneratedColumn<String> outputPath = GeneratedColumn<String>(
    'output_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _paramsJsonMeta = const VerificationMeta(
    'paramsJson',
  );
  @override
  late final GeneratedColumn<String> paramsJson = GeneratedColumn<String>(
    'params_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    jobId,
    jobType,
    inputPath,
    outputPath,
    status,
    paramsJson,
    errorMessage,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processing_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProcessingJobsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('job_type')) {
      context.handle(
        _jobTypeMeta,
        jobType.isAcceptableOrUnknown(data['job_type']!, _jobTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_jobTypeMeta);
    }
    if (data.containsKey('input_path')) {
      context.handle(
        _inputPathMeta,
        inputPath.isAcceptableOrUnknown(data['input_path']!, _inputPathMeta),
      );
    } else if (isInserting) {
      context.missing(_inputPathMeta);
    }
    if (data.containsKey('output_path')) {
      context.handle(
        _outputPathMeta,
        outputPath.isAcceptableOrUnknown(data['output_path']!, _outputPathMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('params_json')) {
      context.handle(
        _paramsJsonMeta,
        paramsJson.isAcceptableOrUnknown(data['params_json']!, _paramsJsonMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProcessingJobsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessingJobsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      jobType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_type'],
      )!,
      inputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_path'],
      )!,
      outputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_path'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      paramsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}params_json'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $ProcessingJobsTableTable createAlias(String alias) {
    return $ProcessingJobsTableTable(attachedDatabase, alias);
  }
}

class ProcessingJobsTableData extends DataClass
    implements Insertable<ProcessingJobsTableData> {
  final int id;
  final String jobId;
  final String jobType;
  final String inputPath;
  final String? outputPath;
  final String status;
  final String? paramsJson;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  const ProcessingJobsTableData({
    required this.id,
    required this.jobId,
    required this.jobType,
    required this.inputPath,
    this.outputPath,
    required this.status,
    this.paramsJson,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['job_id'] = Variable<String>(jobId);
    map['job_type'] = Variable<String>(jobType);
    map['input_path'] = Variable<String>(inputPath);
    if (!nullToAbsent || outputPath != null) {
      map['output_path'] = Variable<String>(outputPath);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || paramsJson != null) {
      map['params_json'] = Variable<String>(paramsJson);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  ProcessingJobsTableCompanion toCompanion(bool nullToAbsent) {
    return ProcessingJobsTableCompanion(
      id: Value(id),
      jobId: Value(jobId),
      jobType: Value(jobType),
      inputPath: Value(inputPath),
      outputPath: outputPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPath),
      status: Value(status),
      paramsJson: paramsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(paramsJson),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory ProcessingJobsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessingJobsTableData(
      id: serializer.fromJson<int>(json['id']),
      jobId: serializer.fromJson<String>(json['jobId']),
      jobType: serializer.fromJson<String>(json['jobType']),
      inputPath: serializer.fromJson<String>(json['inputPath']),
      outputPath: serializer.fromJson<String?>(json['outputPath']),
      status: serializer.fromJson<String>(json['status']),
      paramsJson: serializer.fromJson<String?>(json['paramsJson']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'jobId': serializer.toJson<String>(jobId),
      'jobType': serializer.toJson<String>(jobType),
      'inputPath': serializer.toJson<String>(inputPath),
      'outputPath': serializer.toJson<String?>(outputPath),
      'status': serializer.toJson<String>(status),
      'paramsJson': serializer.toJson<String?>(paramsJson),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  ProcessingJobsTableData copyWith({
    int? id,
    String? jobId,
    String? jobType,
    String? inputPath,
    Value<String?> outputPath = const Value.absent(),
    String? status,
    Value<String?> paramsJson = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => ProcessingJobsTableData(
    id: id ?? this.id,
    jobId: jobId ?? this.jobId,
    jobType: jobType ?? this.jobType,
    inputPath: inputPath ?? this.inputPath,
    outputPath: outputPath.present ? outputPath.value : this.outputPath,
    status: status ?? this.status,
    paramsJson: paramsJson.present ? paramsJson.value : this.paramsJson,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  ProcessingJobsTableData copyWithCompanion(ProcessingJobsTableCompanion data) {
    return ProcessingJobsTableData(
      id: data.id.present ? data.id.value : this.id,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      jobType: data.jobType.present ? data.jobType.value : this.jobType,
      inputPath: data.inputPath.present ? data.inputPath.value : this.inputPath,
      outputPath: data.outputPath.present
          ? data.outputPath.value
          : this.outputPath,
      status: data.status.present ? data.status.value : this.status,
      paramsJson: data.paramsJson.present
          ? data.paramsJson.value
          : this.paramsJson,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJobsTableData(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('jobType: $jobType, ')
          ..write('inputPath: $inputPath, ')
          ..write('outputPath: $outputPath, ')
          ..write('status: $status, ')
          ..write('paramsJson: $paramsJson, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    jobId,
    jobType,
    inputPath,
    outputPath,
    status,
    paramsJson,
    errorMessage,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessingJobsTableData &&
          other.id == this.id &&
          other.jobId == this.jobId &&
          other.jobType == this.jobType &&
          other.inputPath == this.inputPath &&
          other.outputPath == this.outputPath &&
          other.status == this.status &&
          other.paramsJson == this.paramsJson &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class ProcessingJobsTableCompanion
    extends UpdateCompanion<ProcessingJobsTableData> {
  final Value<int> id;
  final Value<String> jobId;
  final Value<String> jobType;
  final Value<String> inputPath;
  final Value<String?> outputPath;
  final Value<String> status;
  final Value<String?> paramsJson;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  const ProcessingJobsTableCompanion({
    this.id = const Value.absent(),
    this.jobId = const Value.absent(),
    this.jobType = const Value.absent(),
    this.inputPath = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.status = const Value.absent(),
    this.paramsJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  ProcessingJobsTableCompanion.insert({
    this.id = const Value.absent(),
    required String jobId,
    required String jobType,
    required String inputPath,
    this.outputPath = const Value.absent(),
    this.status = const Value.absent(),
    this.paramsJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
  }) : jobId = Value(jobId),
       jobType = Value(jobType),
       inputPath = Value(inputPath),
       createdAt = Value(createdAt);
  static Insertable<ProcessingJobsTableData> custom({
    Expression<int>? id,
    Expression<String>? jobId,
    Expression<String>? jobType,
    Expression<String>? inputPath,
    Expression<String>? outputPath,
    Expression<String>? status,
    Expression<String>? paramsJson,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jobId != null) 'job_id': jobId,
      if (jobType != null) 'job_type': jobType,
      if (inputPath != null) 'input_path': inputPath,
      if (outputPath != null) 'output_path': outputPath,
      if (status != null) 'status': status,
      if (paramsJson != null) 'params_json': paramsJson,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  ProcessingJobsTableCompanion copyWith({
    Value<int>? id,
    Value<String>? jobId,
    Value<String>? jobType,
    Value<String>? inputPath,
    Value<String?>? outputPath,
    Value<String>? status,
    Value<String?>? paramsJson,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
  }) {
    return ProcessingJobsTableCompanion(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      jobType: jobType ?? this.jobType,
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      status: status ?? this.status,
      paramsJson: paramsJson ?? this.paramsJson,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (jobType.present) {
      map['job_type'] = Variable<String>(jobType.value);
    }
    if (inputPath.present) {
      map['input_path'] = Variable<String>(inputPath.value);
    }
    if (outputPath.present) {
      map['output_path'] = Variable<String>(outputPath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (paramsJson.present) {
      map['params_json'] = Variable<String>(paramsJson.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJobsTableCompanion(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('jobType: $jobType, ')
          ..write('inputPath: $inputPath, ')
          ..write('outputPath: $outputPath, ')
          ..write('status: $status, ')
          ..write('paramsJson: $paramsJson, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DownloadHistoryTableTable downloadHistoryTable =
      $DownloadHistoryTableTable(this);
  late final $DownloadSegmentsTableTable downloadSegmentsTable =
      $DownloadSegmentsTableTable(this);
  late final $SettingsTableTable settingsTable = $SettingsTableTable(this);
  late final $ProcessingJobsTableTable processingJobsTable =
      $ProcessingJobsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    downloadHistoryTable,
    downloadSegmentsTable,
    settingsTable,
    processingJobsTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'download_history',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('download_segments', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DownloadHistoryTableTableCreateCompanionBuilder =
    DownloadHistoryTableCompanion Function({
      Value<int> id,
      required String taskId,
      required String url,
      Value<String> title,
      Value<String?> thumbnailUrl,
      Value<String?> channelName,
      Value<String> outputPath,
      Value<String> format,
      Value<int?> fileSizeBytes,
      Value<int?> durationSeconds,
      Value<String> status,
      Value<String?> eTag,
      Value<String?> lastModified,
      Value<String?> profile,
      Value<String?> metadataJson,
      required DateTime createdAt,
      Value<DateTime?> completedAt,
    });
typedef $$DownloadHistoryTableTableUpdateCompanionBuilder =
    DownloadHistoryTableCompanion Function({
      Value<int> id,
      Value<String> taskId,
      Value<String> url,
      Value<String> title,
      Value<String?> thumbnailUrl,
      Value<String?> channelName,
      Value<String> outputPath,
      Value<String> format,
      Value<int?> fileSizeBytes,
      Value<int?> durationSeconds,
      Value<String> status,
      Value<String?> eTag,
      Value<String?> lastModified,
      Value<String?> profile,
      Value<String?> metadataJson,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
    });

final class $$DownloadHistoryTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DownloadHistoryTableTable,
          DownloadHistoryTableData
        > {
  $$DownloadHistoryTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $DownloadSegmentsTableTable,
    List<DownloadSegmentsTableData>
  >
  _downloadSegmentsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.downloadSegmentsTable,
        aliasName: 'download_history__task_id__download_segments__task_id',
      );

  $$DownloadSegmentsTableTableProcessedTableManager
  get downloadSegmentsTableRefs {
    final manager =
        $$DownloadSegmentsTableTableTableManager(
          $_db,
          $_db.downloadSegmentsTable,
        ).filter(
          (f) => f.taskId.taskId.sqlEquals($_itemColumn<String>('task_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _downloadSegmentsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DownloadHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadHistoryTableTable> {
  $$DownloadHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eTag => $composableBuilder(
    column: $table.eTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profile => $composableBuilder(
    column: $table.profile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> downloadSegmentsTableRefs(
    Expression<bool> Function($$DownloadSegmentsTableTableFilterComposer f) f,
  ) {
    final $$DownloadSegmentsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.taskId,
          referencedTable: $db.downloadSegmentsTable,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DownloadSegmentsTableTableFilterComposer(
                $db: $db,
                $table: $db.downloadSegmentsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DownloadHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadHistoryTableTable> {
  $$DownloadHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eTag => $composableBuilder(
    column: $table.eTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profile => $composableBuilder(
    column: $table.profile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadHistoryTableTable> {
  $$DownloadHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get eTag =>
      $composableBuilder(column: $table.eTag, builder: (column) => column);

  GeneratedColumn<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profile =>
      $composableBuilder(column: $table.profile, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  Expression<T> downloadSegmentsTableRefs<T extends Object>(
    Expression<T> Function($$DownloadSegmentsTableTableAnnotationComposer a) f,
  ) {
    final $$DownloadSegmentsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.taskId,
          referencedTable: $db.downloadSegmentsTable,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DownloadSegmentsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.downloadSegmentsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DownloadHistoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadHistoryTableTable,
          DownloadHistoryTableData,
          $$DownloadHistoryTableTableFilterComposer,
          $$DownloadHistoryTableTableOrderingComposer,
          $$DownloadHistoryTableTableAnnotationComposer,
          $$DownloadHistoryTableTableCreateCompanionBuilder,
          $$DownloadHistoryTableTableUpdateCompanionBuilder,
          (DownloadHistoryTableData, $$DownloadHistoryTableTableReferences),
          DownloadHistoryTableData,
          PrefetchHooks Function({bool downloadSegmentsTableRefs})
        > {
  $$DownloadHistoryTableTableTableManager(
    _$AppDatabase db,
    $DownloadHistoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadHistoryTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadHistoryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> channelName = const Value.absent(),
                Value<String> outputPath = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int?> fileSizeBytes = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> eTag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<String?> profile = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadHistoryTableCompanion(
                id: id,
                taskId: taskId,
                url: url,
                title: title,
                thumbnailUrl: thumbnailUrl,
                channelName: channelName,
                outputPath: outputPath,
                format: format,
                fileSizeBytes: fileSizeBytes,
                durationSeconds: durationSeconds,
                status: status,
                eTag: eTag,
                lastModified: lastModified,
                profile: profile,
                metadataJson: metadataJson,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String taskId,
                required String url,
                Value<String> title = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> channelName = const Value.absent(),
                Value<String> outputPath = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int?> fileSizeBytes = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> eTag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<String?> profile = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadHistoryTableCompanion.insert(
                id: id,
                taskId: taskId,
                url: url,
                title: title,
                thumbnailUrl: thumbnailUrl,
                channelName: channelName,
                outputPath: outputPath,
                format: format,
                fileSizeBytes: fileSizeBytes,
                durationSeconds: durationSeconds,
                status: status,
                eTag: eTag,
                lastModified: lastModified,
                profile: profile,
                metadataJson: metadataJson,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $DownloadHistoryTableTable,
                    DownloadHistoryTableData
                  >(table),
                  $$DownloadHistoryTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({downloadSegmentsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (downloadSegmentsTableRefs) db.downloadSegmentsTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (downloadSegmentsTableRefs)
                    await $_getPrefetchedData<
                      DownloadHistoryTableData,
                      $DownloadHistoryTableTable,
                      DownloadSegmentsTableData
                    >(
                      currentTable: table,
                      referencedTable: $$DownloadHistoryTableTableReferences
                          ._downloadSegmentsTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DownloadHistoryTableTableReferences(
                            db,
                            table,
                            p0,
                          ).downloadSegmentsTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.taskId == item.taskId),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DownloadHistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadHistoryTableTable,
      DownloadHistoryTableData,
      $$DownloadHistoryTableTableFilterComposer,
      $$DownloadHistoryTableTableOrderingComposer,
      $$DownloadHistoryTableTableAnnotationComposer,
      $$DownloadHistoryTableTableCreateCompanionBuilder,
      $$DownloadHistoryTableTableUpdateCompanionBuilder,
      (DownloadHistoryTableData, $$DownloadHistoryTableTableReferences),
      DownloadHistoryTableData,
      PrefetchHooks Function({bool downloadSegmentsTableRefs})
    >;
typedef $$DownloadSegmentsTableTableCreateCompanionBuilder =
    DownloadSegmentsTableCompanion Function({
      Value<int> id,
      required String taskId,
      required int segmentIndex,
      required int startOffset,
      required int endOffset,
      Value<int> bytesDownloaded,
      Value<String> status,
      required DateTime lastUpdatedAt,
    });
typedef $$DownloadSegmentsTableTableUpdateCompanionBuilder =
    DownloadSegmentsTableCompanion Function({
      Value<int> id,
      Value<String> taskId,
      Value<int> segmentIndex,
      Value<int> startOffset,
      Value<int> endOffset,
      Value<int> bytesDownloaded,
      Value<String> status,
      Value<DateTime> lastUpdatedAt,
    });

final class $$DownloadSegmentsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DownloadSegmentsTableTable,
          DownloadSegmentsTableData
        > {
  $$DownloadSegmentsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DownloadHistoryTableTable _taskIdTable(_$AppDatabase db) => db
      .downloadHistoryTable
      .createAlias('download_segments__task_id__download_history__task_id');

  $$DownloadHistoryTableTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$DownloadHistoryTableTableTableManager(
      $_db,
      $_db.downloadHistoryTable,
    ).filter((f) => f.taskId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadSegmentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadSegmentsTableTable> {
  $$DownloadSegmentsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesDownloaded => $composableBuilder(
    column: $table.bytesDownloaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdatedAt => $composableBuilder(
    column: $table.lastUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DownloadHistoryTableTableFilterComposer get taskId {
    final $$DownloadHistoryTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadHistoryTable,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadHistoryTableTableFilterComposer(
            $db: $db,
            $table: $db.downloadHistoryTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadSegmentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadSegmentsTableTable> {
  $$DownloadSegmentsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesDownloaded => $composableBuilder(
    column: $table.bytesDownloaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdatedAt => $composableBuilder(
    column: $table.lastUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DownloadHistoryTableTableOrderingComposer get taskId {
    final $$DownloadHistoryTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.taskId,
          referencedTable: $db.downloadHistoryTable,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DownloadHistoryTableTableOrderingComposer(
                $db: $db,
                $table: $db.downloadHistoryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DownloadSegmentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadSegmentsTableTable> {
  $$DownloadSegmentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<int> get bytesDownloaded => $composableBuilder(
    column: $table.bytesDownloaded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdatedAt => $composableBuilder(
    column: $table.lastUpdatedAt,
    builder: (column) => column,
  );

  $$DownloadHistoryTableTableAnnotationComposer get taskId {
    final $$DownloadHistoryTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.taskId,
          referencedTable: $db.downloadHistoryTable,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DownloadHistoryTableTableAnnotationComposer(
                $db: $db,
                $table: $db.downloadHistoryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DownloadSegmentsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadSegmentsTableTable,
          DownloadSegmentsTableData,
          $$DownloadSegmentsTableTableFilterComposer,
          $$DownloadSegmentsTableTableOrderingComposer,
          $$DownloadSegmentsTableTableAnnotationComposer,
          $$DownloadSegmentsTableTableCreateCompanionBuilder,
          $$DownloadSegmentsTableTableUpdateCompanionBuilder,
          (DownloadSegmentsTableData, $$DownloadSegmentsTableTableReferences),
          DownloadSegmentsTableData,
          PrefetchHooks Function({bool taskId})
        > {
  $$DownloadSegmentsTableTableTableManager(
    _$AppDatabase db,
    $DownloadSegmentsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadSegmentsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DownloadSegmentsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadSegmentsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<int> segmentIndex = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<int> bytesDownloaded = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> lastUpdatedAt = const Value.absent(),
              }) => DownloadSegmentsTableCompanion(
                id: id,
                taskId: taskId,
                segmentIndex: segmentIndex,
                startOffset: startOffset,
                endOffset: endOffset,
                bytesDownloaded: bytesDownloaded,
                status: status,
                lastUpdatedAt: lastUpdatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String taskId,
                required int segmentIndex,
                required int startOffset,
                required int endOffset,
                Value<int> bytesDownloaded = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime lastUpdatedAt,
              }) => DownloadSegmentsTableCompanion.insert(
                id: id,
                taskId: taskId,
                segmentIndex: segmentIndex,
                startOffset: startOffset,
                endOffset: endOffset,
                bytesDownloaded: bytesDownloaded,
                status: status,
                lastUpdatedAt: lastUpdatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $DownloadSegmentsTableTable,
                    DownloadSegmentsTableData
                  >(table),
                  $$DownloadSegmentsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$DownloadSegmentsTableTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$DownloadSegmentsTableTableReferences
                            ._taskIdTable(db)
                            .taskId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadSegmentsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadSegmentsTableTable,
      DownloadSegmentsTableData,
      $$DownloadSegmentsTableTableFilterComposer,
      $$DownloadSegmentsTableTableOrderingComposer,
      $$DownloadSegmentsTableTableAnnotationComposer,
      $$DownloadSegmentsTableTableCreateCompanionBuilder,
      $$DownloadSegmentsTableTableUpdateCompanionBuilder,
      (DownloadSegmentsTableData, $$DownloadSegmentsTableTableReferences),
      DownloadSegmentsTableData,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$SettingsTableTableCreateCompanionBuilder =
    SettingsTableCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SettingsTableTableUpdateCompanionBuilder =
    SettingsTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTableTable> {
  $$SettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTableTable> {
  $$SettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTableTable> {
  $$SettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTableTable,
          SettingsTableData,
          $$SettingsTableTableFilterComposer,
          $$SettingsTableTableOrderingComposer,
          $$SettingsTableTableAnnotationComposer,
          $$SettingsTableTableCreateCompanionBuilder,
          $$SettingsTableTableUpdateCompanionBuilder,
          (
            SettingsTableData,
            BaseReferences<
              _$AppDatabase,
              $SettingsTableTable,
              SettingsTableData
            >,
          ),
          SettingsTableData,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableTableManager(_$AppDatabase db, $SettingsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsTableCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SettingsTableCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTableTable, SettingsTableData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SettingsTableTable,
                    SettingsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTableTable,
      SettingsTableData,
      $$SettingsTableTableFilterComposer,
      $$SettingsTableTableOrderingComposer,
      $$SettingsTableTableAnnotationComposer,
      $$SettingsTableTableCreateCompanionBuilder,
      $$SettingsTableTableUpdateCompanionBuilder,
      (
        SettingsTableData,
        BaseReferences<_$AppDatabase, $SettingsTableTable, SettingsTableData>,
      ),
      SettingsTableData,
      PrefetchHooks Function()
    >;
typedef $$ProcessingJobsTableTableCreateCompanionBuilder =
    ProcessingJobsTableCompanion Function({
      Value<int> id,
      required String jobId,
      required String jobType,
      required String inputPath,
      Value<String?> outputPath,
      Value<String> status,
      Value<String?> paramsJson,
      Value<String?> errorMessage,
      required DateTime createdAt,
      Value<DateTime?> completedAt,
    });
typedef $$ProcessingJobsTableTableUpdateCompanionBuilder =
    ProcessingJobsTableCompanion Function({
      Value<int> id,
      Value<String> jobId,
      Value<String> jobType,
      Value<String> inputPath,
      Value<String?> outputPath,
      Value<String> status,
      Value<String?> paramsJson,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
    });

class $$ProcessingJobsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTableTable> {
  $$ProcessingJobsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputPath => $composableBuilder(
    column: $table.inputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paramsJson => $composableBuilder(
    column: $table.paramsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProcessingJobsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTableTable> {
  $$ProcessingJobsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputPath => $composableBuilder(
    column: $table.inputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paramsJson => $composableBuilder(
    column: $table.paramsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProcessingJobsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTableTable> {
  $$ProcessingJobsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get jobType =>
      $composableBuilder(column: $table.jobType, builder: (column) => column);

  GeneratedColumn<String> get inputPath =>
      $composableBuilder(column: $table.inputPath, builder: (column) => column);

  GeneratedColumn<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get paramsJson => $composableBuilder(
    column: $table.paramsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$ProcessingJobsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProcessingJobsTableTable,
          ProcessingJobsTableData,
          $$ProcessingJobsTableTableFilterComposer,
          $$ProcessingJobsTableTableOrderingComposer,
          $$ProcessingJobsTableTableAnnotationComposer,
          $$ProcessingJobsTableTableCreateCompanionBuilder,
          $$ProcessingJobsTableTableUpdateCompanionBuilder,
          (
            ProcessingJobsTableData,
            BaseReferences<
              _$AppDatabase,
              $ProcessingJobsTableTable,
              ProcessingJobsTableData
            >,
          ),
          ProcessingJobsTableData,
          PrefetchHooks Function()
        > {
  $$ProcessingJobsTableTableTableManager(
    _$AppDatabase db,
    $ProcessingJobsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProcessingJobsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProcessingJobsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProcessingJobsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> jobId = const Value.absent(),
                Value<String> jobType = const Value.absent(),
                Value<String> inputPath = const Value.absent(),
                Value<String?> outputPath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> paramsJson = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => ProcessingJobsTableCompanion(
                id: id,
                jobId: jobId,
                jobType: jobType,
                inputPath: inputPath,
                outputPath: outputPath,
                status: status,
                paramsJson: paramsJson,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String jobId,
                required String jobType,
                required String inputPath,
                Value<String?> outputPath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> paramsJson = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
              }) => ProcessingJobsTableCompanion.insert(
                id: id,
                jobId: jobId,
                jobType: jobType,
                inputPath: inputPath,
                outputPath: outputPath,
                status: status,
                paramsJson: paramsJson,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ProcessingJobsTableTable,
                    ProcessingJobsTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ProcessingJobsTableTable,
                    ProcessingJobsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProcessingJobsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProcessingJobsTableTable,
      ProcessingJobsTableData,
      $$ProcessingJobsTableTableFilterComposer,
      $$ProcessingJobsTableTableOrderingComposer,
      $$ProcessingJobsTableTableAnnotationComposer,
      $$ProcessingJobsTableTableCreateCompanionBuilder,
      $$ProcessingJobsTableTableUpdateCompanionBuilder,
      (
        ProcessingJobsTableData,
        BaseReferences<
          _$AppDatabase,
          $ProcessingJobsTableTable,
          ProcessingJobsTableData
        >,
      ),
      ProcessingJobsTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DownloadHistoryTableTableTableManager get downloadHistoryTable =>
      $$DownloadHistoryTableTableTableManager(_db, _db.downloadHistoryTable);
  $$DownloadSegmentsTableTableTableManager get downloadSegmentsTable =>
      $$DownloadSegmentsTableTableTableManager(_db, _db.downloadSegmentsTable);
  $$SettingsTableTableTableManager get settingsTable =>
      $$SettingsTableTableTableManager(_db, _db.settingsTable);
  $$ProcessingJobsTableTableTableManager get processingJobsTable =>
      $$ProcessingJobsTableTableTableManager(_db, _db.processingJobsTable);
}
