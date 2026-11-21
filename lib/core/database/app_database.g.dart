// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NovelsTable extends Novels with TableInfo<$NovelsTable, Novel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NovelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _synopsisMeta = const VerificationMeta(
    'synopsis',
  );
  @override
  late final GeneratedColumn<String> synopsis = GeneratedColumn<String>(
    'synopsis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _perspectiveMeta = const VerificationMeta(
    'perspective',
  );
  @override
  late final GeneratedColumn<String> perspective = GeneratedColumn<String>(
    'perspective',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _styleGuideMeta = const VerificationMeta(
    'styleGuide',
  );
  @override
  late final GeneratedColumn<String> styleGuide = GeneratedColumn<String>(
    'style_guide',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accentColorHexMeta = const VerificationMeta(
    'accentColorHex',
  );
  @override
  late final GeneratedColumn<String> accentColorHex = GeneratedColumn<String>(
    'accent_color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledTagIdsJsonMeta = const VerificationMeta(
    'enabledTagIdsJson',
  );
  @override
  late final GeneratedColumn<String> enabledTagIdsJson =
      GeneratedColumn<String>(
        'enabled_tag_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _r18EnabledMeta = const VerificationMeta(
    'r18Enabled',
  );
  @override
  late final GeneratedColumn<bool> r18Enabled = GeneratedColumn<bool>(
    'r18_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("r18_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _activeStyleProfileIdMeta =
      const VerificationMeta('activeStyleProfileId');
  @override
  late final GeneratedColumn<String> activeStyleProfileId =
      GeneratedColumn<String>(
        'active_style_profile_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sourceProfileIdMeta = const VerificationMeta(
    'sourceProfileId',
  );
  @override
  late final GeneratedColumn<String> sourceProfileId = GeneratedColumn<String>(
    'source_profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastStatsDateMeta = const VerificationMeta(
    'lastStatsDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastStatsDate =
      GeneratedColumn<DateTime>(
        'last_stats_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastTotalWordCountMeta =
      const VerificationMeta('lastTotalWordCount');
  @override
  late final GeneratedColumn<int> lastTotalWordCount = GeneratedColumn<int>(
    'last_total_word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  List<GeneratedColumn> get $columns => [
    id,
    title,
    synopsis,
    genre,
    perspective,
    styleGuide,
    accentColorHex,
    enabledTagIdsJson,
    r18Enabled,
    activeStyleProfileId,
    sourceProfileId,
    lastStatsDate,
    lastTotalWordCount,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'novels';
  @override
  VerificationContext validateIntegrity(
    Insertable<Novel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('synopsis')) {
      context.handle(
        _synopsisMeta,
        synopsis.isAcceptableOrUnknown(data['synopsis']!, _synopsisMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('perspective')) {
      context.handle(
        _perspectiveMeta,
        perspective.isAcceptableOrUnknown(
          data['perspective']!,
          _perspectiveMeta,
        ),
      );
    }
    if (data.containsKey('style_guide')) {
      context.handle(
        _styleGuideMeta,
        styleGuide.isAcceptableOrUnknown(data['style_guide']!, _styleGuideMeta),
      );
    }
    if (data.containsKey('accent_color_hex')) {
      context.handle(
        _accentColorHexMeta,
        accentColorHex.isAcceptableOrUnknown(
          data['accent_color_hex']!,
          _accentColorHexMeta,
        ),
      );
    }
    if (data.containsKey('enabled_tag_ids_json')) {
      context.handle(
        _enabledTagIdsJsonMeta,
        enabledTagIdsJson.isAcceptableOrUnknown(
          data['enabled_tag_ids_json']!,
          _enabledTagIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('r18_enabled')) {
      context.handle(
        _r18EnabledMeta,
        r18Enabled.isAcceptableOrUnknown(data['r18_enabled']!, _r18EnabledMeta),
      );
    }
    if (data.containsKey('active_style_profile_id')) {
      context.handle(
        _activeStyleProfileIdMeta,
        activeStyleProfileId.isAcceptableOrUnknown(
          data['active_style_profile_id']!,
          _activeStyleProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('source_profile_id')) {
      context.handle(
        _sourceProfileIdMeta,
        sourceProfileId.isAcceptableOrUnknown(
          data['source_profile_id']!,
          _sourceProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('last_stats_date')) {
      context.handle(
        _lastStatsDateMeta,
        lastStatsDate.isAcceptableOrUnknown(
          data['last_stats_date']!,
          _lastStatsDateMeta,
        ),
      );
    }
    if (data.containsKey('last_total_word_count')) {
      context.handle(
        _lastTotalWordCountMeta,
        lastTotalWordCount.isAcceptableOrUnknown(
          data['last_total_word_count']!,
          _lastTotalWordCountMeta,
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Novel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Novel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      synopsis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synopsis'],
      )!,
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      perspective: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}perspective'],
      ),
      styleGuide: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style_guide'],
      ),
      accentColorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accent_color_hex'],
      ),
      enabledTagIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enabled_tag_ids_json'],
      )!,
      r18Enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}r18_enabled'],
      )!,
      activeStyleProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_style_profile_id'],
      ),
      sourceProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_profile_id'],
      ),
      lastStatsDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_stats_date'],
      ),
      lastTotalWordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_total_word_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NovelsTable createAlias(String alias) {
    return $NovelsTable(attachedDatabase, alias);
  }
}

class Novel extends DataClass implements Insertable<Novel> {
  final String id;
  final String title;
  final String synopsis;
  final String? genre;
  final String? perspective;
  final String? styleGuide;
  final String? accentColorHex;
  final String enabledTagIdsJson;
  final bool r18Enabled;
  final String? activeStyleProfileId;
  final String? sourceProfileId;
  final DateTime? lastStatsDate;
  final int lastTotalWordCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Novel({
    required this.id,
    required this.title,
    required this.synopsis,
    this.genre,
    this.perspective,
    this.styleGuide,
    this.accentColorHex,
    required this.enabledTagIdsJson,
    required this.r18Enabled,
    this.activeStyleProfileId,
    this.sourceProfileId,
    this.lastStatsDate,
    required this.lastTotalWordCount,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['synopsis'] = Variable<String>(synopsis);
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || perspective != null) {
      map['perspective'] = Variable<String>(perspective);
    }
    if (!nullToAbsent || styleGuide != null) {
      map['style_guide'] = Variable<String>(styleGuide);
    }
    if (!nullToAbsent || accentColorHex != null) {
      map['accent_color_hex'] = Variable<String>(accentColorHex);
    }
    map['enabled_tag_ids_json'] = Variable<String>(enabledTagIdsJson);
    map['r18_enabled'] = Variable<bool>(r18Enabled);
    if (!nullToAbsent || activeStyleProfileId != null) {
      map['active_style_profile_id'] = Variable<String>(activeStyleProfileId);
    }
    if (!nullToAbsent || sourceProfileId != null) {
      map['source_profile_id'] = Variable<String>(sourceProfileId);
    }
    if (!nullToAbsent || lastStatsDate != null) {
      map['last_stats_date'] = Variable<DateTime>(lastStatsDate);
    }
    map['last_total_word_count'] = Variable<int>(lastTotalWordCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NovelsCompanion toCompanion(bool nullToAbsent) {
    return NovelsCompanion(
      id: Value(id),
      title: Value(title),
      synopsis: Value(synopsis),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      perspective: perspective == null && nullToAbsent
          ? const Value.absent()
          : Value(perspective),
      styleGuide: styleGuide == null && nullToAbsent
          ? const Value.absent()
          : Value(styleGuide),
      accentColorHex: accentColorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(accentColorHex),
      enabledTagIdsJson: Value(enabledTagIdsJson),
      r18Enabled: Value(r18Enabled),
      activeStyleProfileId: activeStyleProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeStyleProfileId),
      sourceProfileId: sourceProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceProfileId),
      lastStatsDate: lastStatsDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStatsDate),
      lastTotalWordCount: Value(lastTotalWordCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Novel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Novel(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      synopsis: serializer.fromJson<String>(json['synopsis']),
      genre: serializer.fromJson<String?>(json['genre']),
      perspective: serializer.fromJson<String?>(json['perspective']),
      styleGuide: serializer.fromJson<String?>(json['styleGuide']),
      accentColorHex: serializer.fromJson<String?>(json['accentColorHex']),
      enabledTagIdsJson: serializer.fromJson<String>(json['enabledTagIdsJson']),
      r18Enabled: serializer.fromJson<bool>(json['r18Enabled']),
      activeStyleProfileId: serializer.fromJson<String?>(
        json['activeStyleProfileId'],
      ),
      sourceProfileId: serializer.fromJson<String?>(json['sourceProfileId']),
      lastStatsDate: serializer.fromJson<DateTime?>(json['lastStatsDate']),
      lastTotalWordCount: serializer.fromJson<int>(json['lastTotalWordCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'synopsis': serializer.toJson<String>(synopsis),
      'genre': serializer.toJson<String?>(genre),
      'perspective': serializer.toJson<String?>(perspective),
      'styleGuide': serializer.toJson<String?>(styleGuide),
      'accentColorHex': serializer.toJson<String?>(accentColorHex),
      'enabledTagIdsJson': serializer.toJson<String>(enabledTagIdsJson),
      'r18Enabled': serializer.toJson<bool>(r18Enabled),
      'activeStyleProfileId': serializer.toJson<String?>(activeStyleProfileId),
      'sourceProfileId': serializer.toJson<String?>(sourceProfileId),
      'lastStatsDate': serializer.toJson<DateTime?>(lastStatsDate),
      'lastTotalWordCount': serializer.toJson<int>(lastTotalWordCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Novel copyWith({
    String? id,
    String? title,
    String? synopsis,
    Value<String?> genre = const Value.absent(),
    Value<String?> perspective = const Value.absent(),
    Value<String?> styleGuide = const Value.absent(),
    Value<String?> accentColorHex = const Value.absent(),
    String? enabledTagIdsJson,
    bool? r18Enabled,
    Value<String?> activeStyleProfileId = const Value.absent(),
    Value<String?> sourceProfileId = const Value.absent(),
    Value<DateTime?> lastStatsDate = const Value.absent(),
    int? lastTotalWordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Novel(
    id: id ?? this.id,
    title: title ?? this.title,
    synopsis: synopsis ?? this.synopsis,
    genre: genre.present ? genre.value : this.genre,
    perspective: perspective.present ? perspective.value : this.perspective,
    styleGuide: styleGuide.present ? styleGuide.value : this.styleGuide,
    accentColorHex: accentColorHex.present
        ? accentColorHex.value
        : this.accentColorHex,
    enabledTagIdsJson: enabledTagIdsJson ?? this.enabledTagIdsJson,
    r18Enabled: r18Enabled ?? this.r18Enabled,
    activeStyleProfileId: activeStyleProfileId.present
        ? activeStyleProfileId.value
        : this.activeStyleProfileId,
    sourceProfileId: sourceProfileId.present
        ? sourceProfileId.value
        : this.sourceProfileId,
    lastStatsDate: lastStatsDate.present
        ? lastStatsDate.value
        : this.lastStatsDate,
    lastTotalWordCount: lastTotalWordCount ?? this.lastTotalWordCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Novel copyWithCompanion(NovelsCompanion data) {
    return Novel(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      synopsis: data.synopsis.present ? data.synopsis.value : this.synopsis,
      genre: data.genre.present ? data.genre.value : this.genre,
      perspective: data.perspective.present
          ? data.perspective.value
          : this.perspective,
      styleGuide: data.styleGuide.present
          ? data.styleGuide.value
          : this.styleGuide,
      accentColorHex: data.accentColorHex.present
          ? data.accentColorHex.value
          : this.accentColorHex,
      enabledTagIdsJson: data.enabledTagIdsJson.present
          ? data.enabledTagIdsJson.value
          : this.enabledTagIdsJson,
      r18Enabled: data.r18Enabled.present
          ? data.r18Enabled.value
          : this.r18Enabled,
      activeStyleProfileId: data.activeStyleProfileId.present
          ? data.activeStyleProfileId.value
          : this.activeStyleProfileId,
      sourceProfileId: data.sourceProfileId.present
          ? data.sourceProfileId.value
          : this.sourceProfileId,
      lastStatsDate: data.lastStatsDate.present
          ? data.lastStatsDate.value
          : this.lastStatsDate,
      lastTotalWordCount: data.lastTotalWordCount.present
          ? data.lastTotalWordCount.value
          : this.lastTotalWordCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Novel(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('synopsis: $synopsis, ')
          ..write('genre: $genre, ')
          ..write('perspective: $perspective, ')
          ..write('styleGuide: $styleGuide, ')
          ..write('accentColorHex: $accentColorHex, ')
          ..write('enabledTagIdsJson: $enabledTagIdsJson, ')
          ..write('r18Enabled: $r18Enabled, ')
          ..write('activeStyleProfileId: $activeStyleProfileId, ')
          ..write('sourceProfileId: $sourceProfileId, ')
          ..write('lastStatsDate: $lastStatsDate, ')
          ..write('lastTotalWordCount: $lastTotalWordCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    synopsis,
    genre,
    perspective,
    styleGuide,
    accentColorHex,
    enabledTagIdsJson,
    r18Enabled,
    activeStyleProfileId,
    sourceProfileId,
    lastStatsDate,
    lastTotalWordCount,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Novel &&
          other.id == this.id &&
          other.title == this.title &&
          other.synopsis == this.synopsis &&
          other.genre == this.genre &&
          other.perspective == this.perspective &&
          other.styleGuide == this.styleGuide &&
          other.accentColorHex == this.accentColorHex &&
          other.enabledTagIdsJson == this.enabledTagIdsJson &&
          other.r18Enabled == this.r18Enabled &&
          other.activeStyleProfileId == this.activeStyleProfileId &&
          other.sourceProfileId == this.sourceProfileId &&
          other.lastStatsDate == this.lastStatsDate &&
          other.lastTotalWordCount == this.lastTotalWordCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NovelsCompanion extends UpdateCompanion<Novel> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> synopsis;
  final Value<String?> genre;
  final Value<String?> perspective;
  final Value<String?> styleGuide;
  final Value<String?> accentColorHex;
  final Value<String> enabledTagIdsJson;
  final Value<bool> r18Enabled;
  final Value<String?> activeStyleProfileId;
  final Value<String?> sourceProfileId;
  final Value<DateTime?> lastStatsDate;
  final Value<int> lastTotalWordCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NovelsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.synopsis = const Value.absent(),
    this.genre = const Value.absent(),
    this.perspective = const Value.absent(),
    this.styleGuide = const Value.absent(),
    this.accentColorHex = const Value.absent(),
    this.enabledTagIdsJson = const Value.absent(),
    this.r18Enabled = const Value.absent(),
    this.activeStyleProfileId = const Value.absent(),
    this.sourceProfileId = const Value.absent(),
    this.lastStatsDate = const Value.absent(),
    this.lastTotalWordCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NovelsCompanion.insert({
    required String id,
    required String title,
    this.synopsis = const Value.absent(),
    this.genre = const Value.absent(),
    this.perspective = const Value.absent(),
    this.styleGuide = const Value.absent(),
    this.accentColorHex = const Value.absent(),
    this.enabledTagIdsJson = const Value.absent(),
    this.r18Enabled = const Value.absent(),
    this.activeStyleProfileId = const Value.absent(),
    this.sourceProfileId = const Value.absent(),
    this.lastStatsDate = const Value.absent(),
    this.lastTotalWordCount = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Novel> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? synopsis,
    Expression<String>? genre,
    Expression<String>? perspective,
    Expression<String>? styleGuide,
    Expression<String>? accentColorHex,
    Expression<String>? enabledTagIdsJson,
    Expression<bool>? r18Enabled,
    Expression<String>? activeStyleProfileId,
    Expression<String>? sourceProfileId,
    Expression<DateTime>? lastStatsDate,
    Expression<int>? lastTotalWordCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (synopsis != null) 'synopsis': synopsis,
      if (genre != null) 'genre': genre,
      if (perspective != null) 'perspective': perspective,
      if (styleGuide != null) 'style_guide': styleGuide,
      if (accentColorHex != null) 'accent_color_hex': accentColorHex,
      if (enabledTagIdsJson != null) 'enabled_tag_ids_json': enabledTagIdsJson,
      if (r18Enabled != null) 'r18_enabled': r18Enabled,
      if (activeStyleProfileId != null)
        'active_style_profile_id': activeStyleProfileId,
      if (sourceProfileId != null) 'source_profile_id': sourceProfileId,
      if (lastStatsDate != null) 'last_stats_date': lastStatsDate,
      if (lastTotalWordCount != null)
        'last_total_word_count': lastTotalWordCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NovelsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? synopsis,
    Value<String?>? genre,
    Value<String?>? perspective,
    Value<String?>? styleGuide,
    Value<String?>? accentColorHex,
    Value<String>? enabledTagIdsJson,
    Value<bool>? r18Enabled,
    Value<String?>? activeStyleProfileId,
    Value<String?>? sourceProfileId,
    Value<DateTime?>? lastStatsDate,
    Value<int>? lastTotalWordCount,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NovelsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      genre: genre ?? this.genre,
      perspective: perspective ?? this.perspective,
      styleGuide: styleGuide ?? this.styleGuide,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      enabledTagIdsJson: enabledTagIdsJson ?? this.enabledTagIdsJson,
      r18Enabled: r18Enabled ?? this.r18Enabled,
      activeStyleProfileId: activeStyleProfileId ?? this.activeStyleProfileId,
      sourceProfileId: sourceProfileId ?? this.sourceProfileId,
      lastStatsDate: lastStatsDate ?? this.lastStatsDate,
      lastTotalWordCount: lastTotalWordCount ?? this.lastTotalWordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (synopsis.present) {
      map['synopsis'] = Variable<String>(synopsis.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (perspective.present) {
      map['perspective'] = Variable<String>(perspective.value);
    }
    if (styleGuide.present) {
      map['style_guide'] = Variable<String>(styleGuide.value);
    }
    if (accentColorHex.present) {
      map['accent_color_hex'] = Variable<String>(accentColorHex.value);
    }
    if (enabledTagIdsJson.present) {
      map['enabled_tag_ids_json'] = Variable<String>(enabledTagIdsJson.value);
    }
    if (r18Enabled.present) {
      map['r18_enabled'] = Variable<bool>(r18Enabled.value);
    }
    if (activeStyleProfileId.present) {
      map['active_style_profile_id'] = Variable<String>(
        activeStyleProfileId.value,
      );
    }
    if (sourceProfileId.present) {
      map['source_profile_id'] = Variable<String>(sourceProfileId.value);
    }
    if (lastStatsDate.present) {
      map['last_stats_date'] = Variable<DateTime>(lastStatsDate.value);
    }
    if (lastTotalWordCount.present) {
      map['last_total_word_count'] = Variable<int>(lastTotalWordCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('NovelsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('synopsis: $synopsis, ')
          ..write('genre: $genre, ')
          ..write('perspective: $perspective, ')
          ..write('styleGuide: $styleGuide, ')
          ..write('accentColorHex: $accentColorHex, ')
          ..write('enabledTagIdsJson: $enabledTagIdsJson, ')
          ..write('r18Enabled: $r18Enabled, ')
          ..write('activeStyleProfileId: $activeStyleProfileId, ')
          ..write('sourceProfileId: $sourceProfileId, ')
          ..write('lastStatsDate: $lastStatsDate, ')
          ..write('lastTotalWordCount: $lastTotalWordCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VolumesTable extends Volumes with TableInfo<$VolumesTable, Volume> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VolumesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _novelIdMeta = const VerificationMeta(
    'novelId',
  );
  @override
  late final GeneratedColumn<String> novelId = GeneratedColumn<String>(
    'novel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES novels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outlineMeta = const VerificationMeta(
    'outline',
  );
  @override
  late final GeneratedColumn<String> outline = GeneratedColumn<String>(
    'outline',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emotionArcJsonMeta = const VerificationMeta(
    'emotionArcJson',
  );
  @override
  late final GeneratedColumn<String> emotionArcJson = GeneratedColumn<String>(
    'emotion_arc_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictLadderJsonMeta =
      const VerificationMeta('conflictLadderJson');
  @override
  late final GeneratedColumn<String> conflictLadderJson =
      GeneratedColumn<String>(
        'conflict_ladder_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _infoGapJsonMeta = const VerificationMeta(
    'infoGapJson',
  );
  @override
  late final GeneratedColumn<String> infoGapJson = GeneratedColumn<String>(
    'info_gap_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    novelId,
    name,
    outline,
    emotionArcJson,
    conflictLadderJson,
    infoGapJson,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'volumes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Volume> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('novel_id')) {
      context.handle(
        _novelIdMeta,
        novelId.isAcceptableOrUnknown(data['novel_id']!, _novelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_novelIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('outline')) {
      context.handle(
        _outlineMeta,
        outline.isAcceptableOrUnknown(data['outline']!, _outlineMeta),
      );
    }
    if (data.containsKey('emotion_arc_json')) {
      context.handle(
        _emotionArcJsonMeta,
        emotionArcJson.isAcceptableOrUnknown(
          data['emotion_arc_json']!,
          _emotionArcJsonMeta,
        ),
      );
    }
    if (data.containsKey('conflict_ladder_json')) {
      context.handle(
        _conflictLadderJsonMeta,
        conflictLadderJson.isAcceptableOrUnknown(
          data['conflict_ladder_json']!,
          _conflictLadderJsonMeta,
        ),
      );
    }
    if (data.containsKey('info_gap_json')) {
      context.handle(
        _infoGapJsonMeta,
        infoGapJson.isAcceptableOrUnknown(
          data['info_gap_json']!,
          _infoGapJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Volume map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Volume(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      novelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}novel_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      outline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outline'],
      ),
      emotionArcJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emotion_arc_json'],
      ),
      conflictLadderJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_ladder_json'],
      ),
      infoGapJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info_gap_json'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $VolumesTable createAlias(String alias) {
    return $VolumesTable(attachedDatabase, alias);
  }
}

class Volume extends DataClass implements Insertable<Volume> {
  final String id;
  final String novelId;
  final String name;
  final String? outline;
  final String? emotionArcJson;
  final String? conflictLadderJson;
  final String? infoGapJson;
  final int sortOrder;
  const Volume({
    required this.id,
    required this.novelId,
    required this.name,
    this.outline,
    this.emotionArcJson,
    this.conflictLadderJson,
    this.infoGapJson,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['novel_id'] = Variable<String>(novelId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || outline != null) {
      map['outline'] = Variable<String>(outline);
    }
    if (!nullToAbsent || emotionArcJson != null) {
      map['emotion_arc_json'] = Variable<String>(emotionArcJson);
    }
    if (!nullToAbsent || conflictLadderJson != null) {
      map['conflict_ladder_json'] = Variable<String>(conflictLadderJson);
    }
    if (!nullToAbsent || infoGapJson != null) {
      map['info_gap_json'] = Variable<String>(infoGapJson);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  VolumesCompanion toCompanion(bool nullToAbsent) {
    return VolumesCompanion(
      id: Value(id),
      novelId: Value(novelId),
      name: Value(name),
      outline: outline == null && nullToAbsent
          ? const Value.absent()
          : Value(outline),
      emotionArcJson: emotionArcJson == null && nullToAbsent
          ? const Value.absent()
          : Value(emotionArcJson),
      conflictLadderJson: conflictLadderJson == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictLadderJson),
      infoGapJson: infoGapJson == null && nullToAbsent
          ? const Value.absent()
          : Value(infoGapJson),
      sortOrder: Value(sortOrder),
    );
  }

  factory Volume.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Volume(
      id: serializer.fromJson<String>(json['id']),
      novelId: serializer.fromJson<String>(json['novelId']),
      name: serializer.fromJson<String>(json['name']),
      outline: serializer.fromJson<String?>(json['outline']),
      emotionArcJson: serializer.fromJson<String?>(json['emotionArcJson']),
      conflictLadderJson: serializer.fromJson<String?>(
        json['conflictLadderJson'],
      ),
      infoGapJson: serializer.fromJson<String?>(json['infoGapJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'novelId': serializer.toJson<String>(novelId),
      'name': serializer.toJson<String>(name),
      'outline': serializer.toJson<String?>(outline),
      'emotionArcJson': serializer.toJson<String?>(emotionArcJson),
      'conflictLadderJson': serializer.toJson<String?>(conflictLadderJson),
      'infoGapJson': serializer.toJson<String?>(infoGapJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Volume copyWith({
    String? id,
    String? novelId,
    String? name,
    Value<String?> outline = const Value.absent(),
    Value<String?> emotionArcJson = const Value.absent(),
    Value<String?> conflictLadderJson = const Value.absent(),
    Value<String?> infoGapJson = const Value.absent(),
    int? sortOrder,
  }) => Volume(
    id: id ?? this.id,
    novelId: novelId ?? this.novelId,
    name: name ?? this.name,
    outline: outline.present ? outline.value : this.outline,
    emotionArcJson: emotionArcJson.present
        ? emotionArcJson.value
        : this.emotionArcJson,
    conflictLadderJson: conflictLadderJson.present
        ? conflictLadderJson.value
        : this.conflictLadderJson,
    infoGapJson: infoGapJson.present ? infoGapJson.value : this.infoGapJson,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Volume copyWithCompanion(VolumesCompanion data) {
    return Volume(
      id: data.id.present ? data.id.value : this.id,
      novelId: data.novelId.present ? data.novelId.value : this.novelId,
      name: data.name.present ? data.name.value : this.name,
      outline: data.outline.present ? data.outline.value : this.outline,
      emotionArcJson: data.emotionArcJson.present
          ? data.emotionArcJson.value
          : this.emotionArcJson,
      conflictLadderJson: data.conflictLadderJson.present
          ? data.conflictLadderJson.value
          : this.conflictLadderJson,
      infoGapJson: data.infoGapJson.present
          ? data.infoGapJson.value
          : this.infoGapJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Volume(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('name: $name, ')
          ..write('outline: $outline, ')
          ..write('emotionArcJson: $emotionArcJson, ')
          ..write('conflictLadderJson: $conflictLadderJson, ')
          ..write('infoGapJson: $infoGapJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    novelId,
    name,
    outline,
    emotionArcJson,
    conflictLadderJson,
    infoGapJson,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Volume &&
          other.id == this.id &&
          other.novelId == this.novelId &&
          other.name == this.name &&
          other.outline == this.outline &&
          other.emotionArcJson == this.emotionArcJson &&
          other.conflictLadderJson == this.conflictLadderJson &&
          other.infoGapJson == this.infoGapJson &&
          other.sortOrder == this.sortOrder);
}

class VolumesCompanion extends UpdateCompanion<Volume> {
  final Value<String> id;
  final Value<String> novelId;
  final Value<String> name;
  final Value<String?> outline;
  final Value<String?> emotionArcJson;
  final Value<String?> conflictLadderJson;
  final Value<String?> infoGapJson;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const VolumesCompanion({
    this.id = const Value.absent(),
    this.novelId = const Value.absent(),
    this.name = const Value.absent(),
    this.outline = const Value.absent(),
    this.emotionArcJson = const Value.absent(),
    this.conflictLadderJson = const Value.absent(),
    this.infoGapJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VolumesCompanion.insert({
    required String id,
    required String novelId,
    required String name,
    this.outline = const Value.absent(),
    this.emotionArcJson = const Value.absent(),
    this.conflictLadderJson = const Value.absent(),
    this.infoGapJson = const Value.absent(),
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       novelId = Value(novelId),
       name = Value(name),
       sortOrder = Value(sortOrder);
  static Insertable<Volume> custom({
    Expression<String>? id,
    Expression<String>? novelId,
    Expression<String>? name,
    Expression<String>? outline,
    Expression<String>? emotionArcJson,
    Expression<String>? conflictLadderJson,
    Expression<String>? infoGapJson,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (novelId != null) 'novel_id': novelId,
      if (name != null) 'name': name,
      if (outline != null) 'outline': outline,
      if (emotionArcJson != null) 'emotion_arc_json': emotionArcJson,
      if (conflictLadderJson != null)
        'conflict_ladder_json': conflictLadderJson,
      if (infoGapJson != null) 'info_gap_json': infoGapJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VolumesCompanion copyWith({
    Value<String>? id,
    Value<String>? novelId,
    Value<String>? name,
    Value<String?>? outline,
    Value<String?>? emotionArcJson,
    Value<String?>? conflictLadderJson,
    Value<String?>? infoGapJson,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return VolumesCompanion(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      name: name ?? this.name,
      outline: outline ?? this.outline,
      emotionArcJson: emotionArcJson ?? this.emotionArcJson,
      conflictLadderJson: conflictLadderJson ?? this.conflictLadderJson,
      infoGapJson: infoGapJson ?? this.infoGapJson,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (novelId.present) {
      map['novel_id'] = Variable<String>(novelId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (outline.present) {
      map['outline'] = Variable<String>(outline.value);
    }
    if (emotionArcJson.present) {
      map['emotion_arc_json'] = Variable<String>(emotionArcJson.value);
    }
    if (conflictLadderJson.present) {
      map['conflict_ladder_json'] = Variable<String>(conflictLadderJson.value);
    }
    if (infoGapJson.present) {
      map['info_gap_json'] = Variable<String>(infoGapJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VolumesCompanion(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('name: $name, ')
          ..write('outline: $outline, ')
          ..write('emotionArcJson: $emotionArcJson, ')
          ..write('conflictLadderJson: $conflictLadderJson, ')
          ..write('infoGapJson: $infoGapJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _volumeIdMeta = const VerificationMeta(
    'volumeId',
  );
  @override
  late final GeneratedColumn<String> volumeId = GeneratedColumn<String>(
    'volume_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES volumes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailedOutlineMeta = const VerificationMeta(
    'detailedOutline',
  );
  @override
  late final GeneratedColumn<String> detailedOutline = GeneratedColumn<String>(
    'detailed_outline',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sceneCardsJsonMeta = const VerificationMeta(
    'sceneCardsJson',
  );
  @override
  late final GeneratedColumn<String> sceneCardsJson = GeneratedColumn<String>(
    'scene_cards_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isOriginalMeta = const VerificationMeta(
    'isOriginal',
  );
  @override
  late final GeneratedColumn<bool> isOriginal = GeneratedColumn<bool>(
    'is_original',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_original" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  List<GeneratedColumn> get $columns => [
    id,
    volumeId,
    title,
    detailedOutline,
    sceneCardsJson,
    content,
    sortOrder,
    wordCount,
    isOriginal,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('volume_id')) {
      context.handle(
        _volumeIdMeta,
        volumeId.isAcceptableOrUnknown(data['volume_id']!, _volumeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_volumeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('detailed_outline')) {
      context.handle(
        _detailedOutlineMeta,
        detailedOutline.isAcceptableOrUnknown(
          data['detailed_outline']!,
          _detailedOutlineMeta,
        ),
      );
    }
    if (data.containsKey('scene_cards_json')) {
      context.handle(
        _sceneCardsJsonMeta,
        sceneCardsJson.isAcceptableOrUnknown(
          data['scene_cards_json']!,
          _sceneCardsJsonMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('is_original')) {
      context.handle(
        _isOriginalMeta,
        isOriginal.isAcceptableOrUnknown(data['is_original']!, _isOriginalMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      volumeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}volume_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      detailedOutline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detailed_outline'],
      ),
      sceneCardsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scene_cards_json'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      isOriginal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_original'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final String id;
  final String volumeId;
  final String title;
  final String? detailedOutline;
  final String? sceneCardsJson;
  final String content;
  final int sortOrder;
  final int wordCount;
  final bool isOriginal;
  final DateTime updatedAt;
  const Chapter({
    required this.id,
    required this.volumeId,
    required this.title,
    this.detailedOutline,
    this.sceneCardsJson,
    required this.content,
    required this.sortOrder,
    required this.wordCount,
    required this.isOriginal,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['volume_id'] = Variable<String>(volumeId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || detailedOutline != null) {
      map['detailed_outline'] = Variable<String>(detailedOutline);
    }
    if (!nullToAbsent || sceneCardsJson != null) {
      map['scene_cards_json'] = Variable<String>(sceneCardsJson);
    }
    map['content'] = Variable<String>(content);
    map['sort_order'] = Variable<int>(sortOrder);
    map['word_count'] = Variable<int>(wordCount);
    map['is_original'] = Variable<bool>(isOriginal);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      volumeId: Value(volumeId),
      title: Value(title),
      detailedOutline: detailedOutline == null && nullToAbsent
          ? const Value.absent()
          : Value(detailedOutline),
      sceneCardsJson: sceneCardsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(sceneCardsJson),
      content: Value(content),
      sortOrder: Value(sortOrder),
      wordCount: Value(wordCount),
      isOriginal: Value(isOriginal),
      updatedAt: Value(updatedAt),
    );
  }

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<String>(json['id']),
      volumeId: serializer.fromJson<String>(json['volumeId']),
      title: serializer.fromJson<String>(json['title']),
      detailedOutline: serializer.fromJson<String?>(json['detailedOutline']),
      sceneCardsJson: serializer.fromJson<String?>(json['sceneCardsJson']),
      content: serializer.fromJson<String>(json['content']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      isOriginal: serializer.fromJson<bool>(json['isOriginal']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'volumeId': serializer.toJson<String>(volumeId),
      'title': serializer.toJson<String>(title),
      'detailedOutline': serializer.toJson<String?>(detailedOutline),
      'sceneCardsJson': serializer.toJson<String?>(sceneCardsJson),
      'content': serializer.toJson<String>(content),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'wordCount': serializer.toJson<int>(wordCount),
      'isOriginal': serializer.toJson<bool>(isOriginal),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Chapter copyWith({
    String? id,
    String? volumeId,
    String? title,
    Value<String?> detailedOutline = const Value.absent(),
    Value<String?> sceneCardsJson = const Value.absent(),
    String? content,
    int? sortOrder,
    int? wordCount,
    bool? isOriginal,
    DateTime? updatedAt,
  }) => Chapter(
    id: id ?? this.id,
    volumeId: volumeId ?? this.volumeId,
    title: title ?? this.title,
    detailedOutline: detailedOutline.present
        ? detailedOutline.value
        : this.detailedOutline,
    sceneCardsJson: sceneCardsJson.present
        ? sceneCardsJson.value
        : this.sceneCardsJson,
    content: content ?? this.content,
    sortOrder: sortOrder ?? this.sortOrder,
    wordCount: wordCount ?? this.wordCount,
    isOriginal: isOriginal ?? this.isOriginal,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      volumeId: data.volumeId.present ? data.volumeId.value : this.volumeId,
      title: data.title.present ? data.title.value : this.title,
      detailedOutline: data.detailedOutline.present
          ? data.detailedOutline.value
          : this.detailedOutline,
      sceneCardsJson: data.sceneCardsJson.present
          ? data.sceneCardsJson.value
          : this.sceneCardsJson,
      content: data.content.present ? data.content.value : this.content,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      isOriginal: data.isOriginal.present
          ? data.isOriginal.value
          : this.isOriginal,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('volumeId: $volumeId, ')
          ..write('title: $title, ')
          ..write('detailedOutline: $detailedOutline, ')
          ..write('sceneCardsJson: $sceneCardsJson, ')
          ..write('content: $content, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('wordCount: $wordCount, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    volumeId,
    title,
    detailedOutline,
    sceneCardsJson,
    content,
    sortOrder,
    wordCount,
    isOriginal,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.volumeId == this.volumeId &&
          other.title == this.title &&
          other.detailedOutline == this.detailedOutline &&
          other.sceneCardsJson == this.sceneCardsJson &&
          other.content == this.content &&
          other.sortOrder == this.sortOrder &&
          other.wordCount == this.wordCount &&
          other.isOriginal == this.isOriginal &&
          other.updatedAt == this.updatedAt);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<String> id;
  final Value<String> volumeId;
  final Value<String> title;
  final Value<String?> detailedOutline;
  final Value<String?> sceneCardsJson;
  final Value<String> content;
  final Value<int> sortOrder;
  final Value<int> wordCount;
  final Value<bool> isOriginal;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.volumeId = const Value.absent(),
    this.title = const Value.absent(),
    this.detailedOutline = const Value.absent(),
    this.sceneCardsJson = const Value.absent(),
    this.content = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.isOriginal = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChaptersCompanion.insert({
    required String id,
    required String volumeId,
    required String title,
    this.detailedOutline = const Value.absent(),
    this.sceneCardsJson = const Value.absent(),
    this.content = const Value.absent(),
    required int sortOrder,
    this.wordCount = const Value.absent(),
    this.isOriginal = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       volumeId = Value(volumeId),
       title = Value(title),
       sortOrder = Value(sortOrder),
       updatedAt = Value(updatedAt);
  static Insertable<Chapter> custom({
    Expression<String>? id,
    Expression<String>? volumeId,
    Expression<String>? title,
    Expression<String>? detailedOutline,
    Expression<String>? sceneCardsJson,
    Expression<String>? content,
    Expression<int>? sortOrder,
    Expression<int>? wordCount,
    Expression<bool>? isOriginal,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (volumeId != null) 'volume_id': volumeId,
      if (title != null) 'title': title,
      if (detailedOutline != null) 'detailed_outline': detailedOutline,
      if (sceneCardsJson != null) 'scene_cards_json': sceneCardsJson,
      if (content != null) 'content': content,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (wordCount != null) 'word_count': wordCount,
      if (isOriginal != null) 'is_original': isOriginal,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChaptersCompanion copyWith({
    Value<String>? id,
    Value<String>? volumeId,
    Value<String>? title,
    Value<String?>? detailedOutline,
    Value<String?>? sceneCardsJson,
    Value<String>? content,
    Value<int>? sortOrder,
    Value<int>? wordCount,
    Value<bool>? isOriginal,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      volumeId: volumeId ?? this.volumeId,
      title: title ?? this.title,
      detailedOutline: detailedOutline ?? this.detailedOutline,
      sceneCardsJson: sceneCardsJson ?? this.sceneCardsJson,
      content: content ?? this.content,
      sortOrder: sortOrder ?? this.sortOrder,
      wordCount: wordCount ?? this.wordCount,
      isOriginal: isOriginal ?? this.isOriginal,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (volumeId.present) {
      map['volume_id'] = Variable<String>(volumeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (detailedOutline.present) {
      map['detailed_outline'] = Variable<String>(detailedOutline.value);
    }
    if (sceneCardsJson.present) {
      map['scene_cards_json'] = Variable<String>(sceneCardsJson.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (isOriginal.present) {
      map['is_original'] = Variable<bool>(isOriginal.value);
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
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('volumeId: $volumeId, ')
          ..write('title: $title, ')
          ..write('detailedOutline: $detailedOutline, ')
          ..write('sceneCardsJson: $sceneCardsJson, ')
          ..write('content: $content, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('wordCount: $wordCount, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChapterSummariesTable extends ChapterSummaries
    with TableInfo<$ChapterSummariesTable, ChapterSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chapters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _summaryTextMeta = const VerificationMeta(
    'summaryText',
  );
  @override
  late final GeneratedColumn<String> summaryText = GeneratedColumn<String>(
    'summary_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyFactsJsonMeta = const VerificationMeta(
    'keyFactsJson',
  );
  @override
  late final GeneratedColumn<String> keyFactsJson = GeneratedColumn<String>(
    'key_facts_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
  List<GeneratedColumn> get $columns => [
    chapterId,
    summaryText,
    keyFactsJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterSummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('summary_text')) {
      context.handle(
        _summaryTextMeta,
        summaryText.isAcceptableOrUnknown(
          data['summary_text']!,
          _summaryTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryTextMeta);
    }
    if (data.containsKey('key_facts_json')) {
      context.handle(
        _keyFactsJsonMeta,
        keyFactsJson.isAcceptableOrUnknown(
          data['key_facts_json']!,
          _keyFactsJsonMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {chapterId};
  @override
  ChapterSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterSummary(
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      summaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_text'],
      )!,
      keyFactsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_facts_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChapterSummariesTable createAlias(String alias) {
    return $ChapterSummariesTable(attachedDatabase, alias);
  }
}

class ChapterSummary extends DataClass implements Insertable<ChapterSummary> {
  final String chapterId;
  final String summaryText;
  final String keyFactsJson;
  final DateTime updatedAt;
  const ChapterSummary({
    required this.chapterId,
    required this.summaryText,
    required this.keyFactsJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chapter_id'] = Variable<String>(chapterId);
    map['summary_text'] = Variable<String>(summaryText);
    map['key_facts_json'] = Variable<String>(keyFactsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChapterSummariesCompanion toCompanion(bool nullToAbsent) {
    return ChapterSummariesCompanion(
      chapterId: Value(chapterId),
      summaryText: Value(summaryText),
      keyFactsJson: Value(keyFactsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChapterSummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterSummary(
      chapterId: serializer.fromJson<String>(json['chapterId']),
      summaryText: serializer.fromJson<String>(json['summaryText']),
      keyFactsJson: serializer.fromJson<String>(json['keyFactsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chapterId': serializer.toJson<String>(chapterId),
      'summaryText': serializer.toJson<String>(summaryText),
      'keyFactsJson': serializer.toJson<String>(keyFactsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChapterSummary copyWith({
    String? chapterId,
    String? summaryText,
    String? keyFactsJson,
    DateTime? updatedAt,
  }) => ChapterSummary(
    chapterId: chapterId ?? this.chapterId,
    summaryText: summaryText ?? this.summaryText,
    keyFactsJson: keyFactsJson ?? this.keyFactsJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChapterSummary copyWithCompanion(ChapterSummariesCompanion data) {
    return ChapterSummary(
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      summaryText: data.summaryText.present
          ? data.summaryText.value
          : this.summaryText,
      keyFactsJson: data.keyFactsJson.present
          ? data.keyFactsJson.value
          : this.keyFactsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterSummary(')
          ..write('chapterId: $chapterId, ')
          ..write('summaryText: $summaryText, ')
          ..write('keyFactsJson: $keyFactsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(chapterId, summaryText, keyFactsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterSummary &&
          other.chapterId == this.chapterId &&
          other.summaryText == this.summaryText &&
          other.keyFactsJson == this.keyFactsJson &&
          other.updatedAt == this.updatedAt);
}

class ChapterSummariesCompanion extends UpdateCompanion<ChapterSummary> {
  final Value<String> chapterId;
  final Value<String> summaryText;
  final Value<String> keyFactsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChapterSummariesCompanion({
    this.chapterId = const Value.absent(),
    this.summaryText = const Value.absent(),
    this.keyFactsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChapterSummariesCompanion.insert({
    required String chapterId,
    required String summaryText,
    this.keyFactsJson = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : chapterId = Value(chapterId),
       summaryText = Value(summaryText),
       updatedAt = Value(updatedAt);
  static Insertable<ChapterSummary> custom({
    Expression<String>? chapterId,
    Expression<String>? summaryText,
    Expression<String>? keyFactsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chapterId != null) 'chapter_id': chapterId,
      if (summaryText != null) 'summary_text': summaryText,
      if (keyFactsJson != null) 'key_facts_json': keyFactsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChapterSummariesCompanion copyWith({
    Value<String>? chapterId,
    Value<String>? summaryText,
    Value<String>? keyFactsJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChapterSummariesCompanion(
      chapterId: chapterId ?? this.chapterId,
      summaryText: summaryText ?? this.summaryText,
      keyFactsJson: keyFactsJson ?? this.keyFactsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (summaryText.present) {
      map['summary_text'] = Variable<String>(summaryText.value);
    }
    if (keyFactsJson.present) {
      map['key_facts_json'] = Variable<String>(keyFactsJson.value);
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
    return (StringBuffer('ChapterSummariesCompanion(')
          ..write('chapterId: $chapterId, ')
          ..write('summaryText: $summaryText, ')
          ..write('keyFactsJson: $keyFactsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChapterSnapshotsTable extends ChapterSnapshots
    with TableInfo<$ChapterSnapshotsTable, ChapterSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chapters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _versionNumberMeta = const VerificationMeta(
    'versionNumber',
  );
  @override
  late final GeneratedColumn<int> versionNumber = GeneratedColumn<int>(
    'version_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triggerTypeMeta = const VerificationMeta(
    'triggerType',
  );
  @override
  late final GeneratedColumn<String> triggerType = GeneratedColumn<String>(
    'trigger_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chapterId,
    versionNumber,
    content,
    triggerType,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('version_number')) {
      context.handle(
        _versionNumberMeta,
        versionNumber.isAcceptableOrUnknown(
          data['version_number']!,
          _versionNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionNumberMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('trigger_type')) {
      context.handle(
        _triggerTypeMeta,
        triggerType.isAcceptableOrUnknown(
          data['trigger_type']!,
          _triggerTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_triggerTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChapterSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      versionNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version_number'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      triggerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChapterSnapshotsTable createAlias(String alias) {
    return $ChapterSnapshotsTable(attachedDatabase, alias);
  }
}

class ChapterSnapshot extends DataClass implements Insertable<ChapterSnapshot> {
  final String id;
  final String chapterId;
  final int versionNumber;
  final String content;
  final String triggerType;
  final DateTime createdAt;
  const ChapterSnapshot({
    required this.id,
    required this.chapterId,
    required this.versionNumber,
    required this.content,
    required this.triggerType,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chapter_id'] = Variable<String>(chapterId);
    map['version_number'] = Variable<int>(versionNumber);
    map['content'] = Variable<String>(content);
    map['trigger_type'] = Variable<String>(triggerType);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChapterSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ChapterSnapshotsCompanion(
      id: Value(id),
      chapterId: Value(chapterId),
      versionNumber: Value(versionNumber),
      content: Value(content),
      triggerType: Value(triggerType),
      createdAt: Value(createdAt),
    );
  }

  factory ChapterSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterSnapshot(
      id: serializer.fromJson<String>(json['id']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      versionNumber: serializer.fromJson<int>(json['versionNumber']),
      content: serializer.fromJson<String>(json['content']),
      triggerType: serializer.fromJson<String>(json['triggerType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chapterId': serializer.toJson<String>(chapterId),
      'versionNumber': serializer.toJson<int>(versionNumber),
      'content': serializer.toJson<String>(content),
      'triggerType': serializer.toJson<String>(triggerType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChapterSnapshot copyWith({
    String? id,
    String? chapterId,
    int? versionNumber,
    String? content,
    String? triggerType,
    DateTime? createdAt,
  }) => ChapterSnapshot(
    id: id ?? this.id,
    chapterId: chapterId ?? this.chapterId,
    versionNumber: versionNumber ?? this.versionNumber,
    content: content ?? this.content,
    triggerType: triggerType ?? this.triggerType,
    createdAt: createdAt ?? this.createdAt,
  );
  ChapterSnapshot copyWithCompanion(ChapterSnapshotsCompanion data) {
    return ChapterSnapshot(
      id: data.id.present ? data.id.value : this.id,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      versionNumber: data.versionNumber.present
          ? data.versionNumber.value
          : this.versionNumber,
      content: data.content.present ? data.content.value : this.content,
      triggerType: data.triggerType.present
          ? data.triggerType.value
          : this.triggerType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterSnapshot(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('content: $content, ')
          ..write('triggerType: $triggerType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chapterId,
    versionNumber,
    content,
    triggerType,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterSnapshot &&
          other.id == this.id &&
          other.chapterId == this.chapterId &&
          other.versionNumber == this.versionNumber &&
          other.content == this.content &&
          other.triggerType == this.triggerType &&
          other.createdAt == this.createdAt);
}

class ChapterSnapshotsCompanion extends UpdateCompanion<ChapterSnapshot> {
  final Value<String> id;
  final Value<String> chapterId;
  final Value<int> versionNumber;
  final Value<String> content;
  final Value<String> triggerType;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChapterSnapshotsCompanion({
    this.id = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.versionNumber = const Value.absent(),
    this.content = const Value.absent(),
    this.triggerType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChapterSnapshotsCompanion.insert({
    required String id,
    required String chapterId,
    required int versionNumber,
    required String content,
    required String triggerType,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chapterId = Value(chapterId),
       versionNumber = Value(versionNumber),
       content = Value(content),
       triggerType = Value(triggerType),
       createdAt = Value(createdAt);
  static Insertable<ChapterSnapshot> custom({
    Expression<String>? id,
    Expression<String>? chapterId,
    Expression<int>? versionNumber,
    Expression<String>? content,
    Expression<String>? triggerType,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chapterId != null) 'chapter_id': chapterId,
      if (versionNumber != null) 'version_number': versionNumber,
      if (content != null) 'content': content,
      if (triggerType != null) 'trigger_type': triggerType,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChapterSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? chapterId,
    Value<int>? versionNumber,
    Value<String>? content,
    Value<String>? triggerType,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ChapterSnapshotsCompanion(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      versionNumber: versionNumber ?? this.versionNumber,
      content: content ?? this.content,
      triggerType: triggerType ?? this.triggerType,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (versionNumber.present) {
      map['version_number'] = Variable<int>(versionNumber.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (triggerType.present) {
      map['trigger_type'] = Variable<String>(triggerType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChapterSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('versionNumber: $versionNumber, ')
          ..write('content: $content, ')
          ..write('triggerType: $triggerType, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CharactersTable extends Characters
    with TableInfo<$CharactersTable, Character> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _novelIdMeta = const VerificationMeta(
    'novelId',
  );
  @override
  late final GeneratedColumn<String> novelId = GeneratedColumn<String>(
    'novel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES novels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasesJsonMeta = const VerificationMeta(
    'aliasesJson',
  );
  @override
  late final GeneratedColumn<String> aliasesJson = GeneratedColumn<String>(
    'aliases_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _appearanceMeta = const VerificationMeta(
    'appearance',
  );
  @override
  late final GeneratedColumn<String> appearance = GeneratedColumn<String>(
    'appearance',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _personalityMeta = const VerificationMeta(
    'personality',
  );
  @override
  late final GeneratedColumn<String> personality = GeneratedColumn<String>(
    'personality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backgroundMeta = const VerificationMeta(
    'background',
  );
  @override
  late final GeneratedColumn<String> background = GeneratedColumn<String>(
    'background',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentGoalMeta = const VerificationMeta(
    'currentGoal',
  );
  @override
  late final GeneratedColumn<String> currentGoal = GeneratedColumn<String>(
    'current_goal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentLocationMeta = const VerificationMeta(
    'currentLocation',
  );
  @override
  late final GeneratedColumn<String> currentLocation = GeneratedColumn<String>(
    'current_location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _physicalStateMeta = const VerificationMeta(
    'physicalState',
  );
  @override
  late final GeneratedColumn<String> physicalState = GeneratedColumn<String>(
    'physical_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mentalStateMeta = const VerificationMeta(
    'mentalState',
  );
  @override
  late final GeneratedColumn<String> mentalState = GeneratedColumn<String>(
    'mental_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenChapterTitleMeta =
      const VerificationMeta('lastSeenChapterTitle');
  @override
  late final GeneratedColumn<String> lastSeenChapterTitle =
      GeneratedColumn<String>(
        'last_seen_chapter_title',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isSceneRelevantMeta = const VerificationMeta(
    'isSceneRelevant',
  );
  @override
  late final GeneratedColumn<bool> isSceneRelevant = GeneratedColumn<bool>(
    'is_scene_relevant',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_scene_relevant" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    novelId,
    name,
    aliasesJson,
    appearance,
    personality,
    background,
    currentGoal,
    currentLocation,
    physicalState,
    mentalState,
    lastSeenChapterTitle,
    isSceneRelevant,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Character> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('novel_id')) {
      context.handle(
        _novelIdMeta,
        novelId.isAcceptableOrUnknown(data['novel_id']!, _novelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_novelIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('aliases_json')) {
      context.handle(
        _aliasesJsonMeta,
        aliasesJson.isAcceptableOrUnknown(
          data['aliases_json']!,
          _aliasesJsonMeta,
        ),
      );
    }
    if (data.containsKey('appearance')) {
      context.handle(
        _appearanceMeta,
        appearance.isAcceptableOrUnknown(data['appearance']!, _appearanceMeta),
      );
    }
    if (data.containsKey('personality')) {
      context.handle(
        _personalityMeta,
        personality.isAcceptableOrUnknown(
          data['personality']!,
          _personalityMeta,
        ),
      );
    }
    if (data.containsKey('background')) {
      context.handle(
        _backgroundMeta,
        background.isAcceptableOrUnknown(data['background']!, _backgroundMeta),
      );
    }
    if (data.containsKey('current_goal')) {
      context.handle(
        _currentGoalMeta,
        currentGoal.isAcceptableOrUnknown(
          data['current_goal']!,
          _currentGoalMeta,
        ),
      );
    }
    if (data.containsKey('current_location')) {
      context.handle(
        _currentLocationMeta,
        currentLocation.isAcceptableOrUnknown(
          data['current_location']!,
          _currentLocationMeta,
        ),
      );
    }
    if (data.containsKey('physical_state')) {
      context.handle(
        _physicalStateMeta,
        physicalState.isAcceptableOrUnknown(
          data['physical_state']!,
          _physicalStateMeta,
        ),
      );
    }
    if (data.containsKey('mental_state')) {
      context.handle(
        _mentalStateMeta,
        mentalState.isAcceptableOrUnknown(
          data['mental_state']!,
          _mentalStateMeta,
        ),
      );
    }
    if (data.containsKey('last_seen_chapter_title')) {
      context.handle(
        _lastSeenChapterTitleMeta,
        lastSeenChapterTitle.isAcceptableOrUnknown(
          data['last_seen_chapter_title']!,
          _lastSeenChapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('is_scene_relevant')) {
      context.handle(
        _isSceneRelevantMeta,
        isSceneRelevant.isAcceptableOrUnknown(
          data['is_scene_relevant']!,
          _isSceneRelevantMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Character map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Character(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      novelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}novel_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      aliasesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases_json'],
      )!,
      appearance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}appearance'],
      ),
      personality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personality'],
      ),
      background: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background'],
      ),
      currentGoal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_goal'],
      ),
      currentLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_location'],
      ),
      physicalState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}physical_state'],
      ),
      mentalState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mental_state'],
      ),
      lastSeenChapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_seen_chapter_title'],
      ),
      isSceneRelevant: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_scene_relevant'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CharactersTable createAlias(String alias) {
    return $CharactersTable(attachedDatabase, alias);
  }
}

class Character extends DataClass implements Insertable<Character> {
  final String id;
  final String novelId;
  final String name;
  final String aliasesJson;
  final String? appearance;
  final String? personality;
  final String? background;
  final String? currentGoal;
  final String? currentLocation;
  final String? physicalState;
  final String? mentalState;
  final String? lastSeenChapterTitle;
  final bool isSceneRelevant;
  final int sortOrder;
  const Character({
    required this.id,
    required this.novelId,
    required this.name,
    required this.aliasesJson,
    this.appearance,
    this.personality,
    this.background,
    this.currentGoal,
    this.currentLocation,
    this.physicalState,
    this.mentalState,
    this.lastSeenChapterTitle,
    required this.isSceneRelevant,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['novel_id'] = Variable<String>(novelId);
    map['name'] = Variable<String>(name);
    map['aliases_json'] = Variable<String>(aliasesJson);
    if (!nullToAbsent || appearance != null) {
      map['appearance'] = Variable<String>(appearance);
    }
    if (!nullToAbsent || personality != null) {
      map['personality'] = Variable<String>(personality);
    }
    if (!nullToAbsent || background != null) {
      map['background'] = Variable<String>(background);
    }
    if (!nullToAbsent || currentGoal != null) {
      map['current_goal'] = Variable<String>(currentGoal);
    }
    if (!nullToAbsent || currentLocation != null) {
      map['current_location'] = Variable<String>(currentLocation);
    }
    if (!nullToAbsent || physicalState != null) {
      map['physical_state'] = Variable<String>(physicalState);
    }
    if (!nullToAbsent || mentalState != null) {
      map['mental_state'] = Variable<String>(mentalState);
    }
    if (!nullToAbsent || lastSeenChapterTitle != null) {
      map['last_seen_chapter_title'] = Variable<String>(lastSeenChapterTitle);
    }
    map['is_scene_relevant'] = Variable<bool>(isSceneRelevant);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CharactersCompanion toCompanion(bool nullToAbsent) {
    return CharactersCompanion(
      id: Value(id),
      novelId: Value(novelId),
      name: Value(name),
      aliasesJson: Value(aliasesJson),
      appearance: appearance == null && nullToAbsent
          ? const Value.absent()
          : Value(appearance),
      personality: personality == null && nullToAbsent
          ? const Value.absent()
          : Value(personality),
      background: background == null && nullToAbsent
          ? const Value.absent()
          : Value(background),
      currentGoal: currentGoal == null && nullToAbsent
          ? const Value.absent()
          : Value(currentGoal),
      currentLocation: currentLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(currentLocation),
      physicalState: physicalState == null && nullToAbsent
          ? const Value.absent()
          : Value(physicalState),
      mentalState: mentalState == null && nullToAbsent
          ? const Value.absent()
          : Value(mentalState),
      lastSeenChapterTitle: lastSeenChapterTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenChapterTitle),
      isSceneRelevant: Value(isSceneRelevant),
      sortOrder: Value(sortOrder),
    );
  }

  factory Character.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Character(
      id: serializer.fromJson<String>(json['id']),
      novelId: serializer.fromJson<String>(json['novelId']),
      name: serializer.fromJson<String>(json['name']),
      aliasesJson: serializer.fromJson<String>(json['aliasesJson']),
      appearance: serializer.fromJson<String?>(json['appearance']),
      personality: serializer.fromJson<String?>(json['personality']),
      background: serializer.fromJson<String?>(json['background']),
      currentGoal: serializer.fromJson<String?>(json['currentGoal']),
      currentLocation: serializer.fromJson<String?>(json['currentLocation']),
      physicalState: serializer.fromJson<String?>(json['physicalState']),
      mentalState: serializer.fromJson<String?>(json['mentalState']),
      lastSeenChapterTitle: serializer.fromJson<String?>(
        json['lastSeenChapterTitle'],
      ),
      isSceneRelevant: serializer.fromJson<bool>(json['isSceneRelevant']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'novelId': serializer.toJson<String>(novelId),
      'name': serializer.toJson<String>(name),
      'aliasesJson': serializer.toJson<String>(aliasesJson),
      'appearance': serializer.toJson<String?>(appearance),
      'personality': serializer.toJson<String?>(personality),
      'background': serializer.toJson<String?>(background),
      'currentGoal': serializer.toJson<String?>(currentGoal),
      'currentLocation': serializer.toJson<String?>(currentLocation),
      'physicalState': serializer.toJson<String?>(physicalState),
      'mentalState': serializer.toJson<String?>(mentalState),
      'lastSeenChapterTitle': serializer.toJson<String?>(lastSeenChapterTitle),
      'isSceneRelevant': serializer.toJson<bool>(isSceneRelevant),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Character copyWith({
    String? id,
    String? novelId,
    String? name,
    String? aliasesJson,
    Value<String?> appearance = const Value.absent(),
    Value<String?> personality = const Value.absent(),
    Value<String?> background = const Value.absent(),
    Value<String?> currentGoal = const Value.absent(),
    Value<String?> currentLocation = const Value.absent(),
    Value<String?> physicalState = const Value.absent(),
    Value<String?> mentalState = const Value.absent(),
    Value<String?> lastSeenChapterTitle = const Value.absent(),
    bool? isSceneRelevant,
    int? sortOrder,
  }) => Character(
    id: id ?? this.id,
    novelId: novelId ?? this.novelId,
    name: name ?? this.name,
    aliasesJson: aliasesJson ?? this.aliasesJson,
    appearance: appearance.present ? appearance.value : this.appearance,
    personality: personality.present ? personality.value : this.personality,
    background: background.present ? background.value : this.background,
    currentGoal: currentGoal.present ? currentGoal.value : this.currentGoal,
    currentLocation: currentLocation.present
        ? currentLocation.value
        : this.currentLocation,
    physicalState: physicalState.present
        ? physicalState.value
        : this.physicalState,
    mentalState: mentalState.present ? mentalState.value : this.mentalState,
    lastSeenChapterTitle: lastSeenChapterTitle.present
        ? lastSeenChapterTitle.value
        : this.lastSeenChapterTitle,
    isSceneRelevant: isSceneRelevant ?? this.isSceneRelevant,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Character copyWithCompanion(CharactersCompanion data) {
    return Character(
      id: data.id.present ? data.id.value : this.id,
      novelId: data.novelId.present ? data.novelId.value : this.novelId,
      name: data.name.present ? data.name.value : this.name,
      aliasesJson: data.aliasesJson.present
          ? data.aliasesJson.value
          : this.aliasesJson,
      appearance: data.appearance.present
          ? data.appearance.value
          : this.appearance,
      personality: data.personality.present
          ? data.personality.value
          : this.personality,
      background: data.background.present
          ? data.background.value
          : this.background,
      currentGoal: data.currentGoal.present
          ? data.currentGoal.value
          : this.currentGoal,
      currentLocation: data.currentLocation.present
          ? data.currentLocation.value
          : this.currentLocation,
      physicalState: data.physicalState.present
          ? data.physicalState.value
          : this.physicalState,
      mentalState: data.mentalState.present
          ? data.mentalState.value
          : this.mentalState,
      lastSeenChapterTitle: data.lastSeenChapterTitle.present
          ? data.lastSeenChapterTitle.value
          : this.lastSeenChapterTitle,
      isSceneRelevant: data.isSceneRelevant.present
          ? data.isSceneRelevant.value
          : this.isSceneRelevant,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Character(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('name: $name, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('appearance: $appearance, ')
          ..write('personality: $personality, ')
          ..write('background: $background, ')
          ..write('currentGoal: $currentGoal, ')
          ..write('currentLocation: $currentLocation, ')
          ..write('physicalState: $physicalState, ')
          ..write('mentalState: $mentalState, ')
          ..write('lastSeenChapterTitle: $lastSeenChapterTitle, ')
          ..write('isSceneRelevant: $isSceneRelevant, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    novelId,
    name,
    aliasesJson,
    appearance,
    personality,
    background,
    currentGoal,
    currentLocation,
    physicalState,
    mentalState,
    lastSeenChapterTitle,
    isSceneRelevant,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Character &&
          other.id == this.id &&
          other.novelId == this.novelId &&
          other.name == this.name &&
          other.aliasesJson == this.aliasesJson &&
          other.appearance == this.appearance &&
          other.personality == this.personality &&
          other.background == this.background &&
          other.currentGoal == this.currentGoal &&
          other.currentLocation == this.currentLocation &&
          other.physicalState == this.physicalState &&
          other.mentalState == this.mentalState &&
          other.lastSeenChapterTitle == this.lastSeenChapterTitle &&
          other.isSceneRelevant == this.isSceneRelevant &&
          other.sortOrder == this.sortOrder);
}

class CharactersCompanion extends UpdateCompanion<Character> {
  final Value<String> id;
  final Value<String> novelId;
  final Value<String> name;
  final Value<String> aliasesJson;
  final Value<String?> appearance;
  final Value<String?> personality;
  final Value<String?> background;
  final Value<String?> currentGoal;
  final Value<String?> currentLocation;
  final Value<String?> physicalState;
  final Value<String?> mentalState;
  final Value<String?> lastSeenChapterTitle;
  final Value<bool> isSceneRelevant;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CharactersCompanion({
    this.id = const Value.absent(),
    this.novelId = const Value.absent(),
    this.name = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.appearance = const Value.absent(),
    this.personality = const Value.absent(),
    this.background = const Value.absent(),
    this.currentGoal = const Value.absent(),
    this.currentLocation = const Value.absent(),
    this.physicalState = const Value.absent(),
    this.mentalState = const Value.absent(),
    this.lastSeenChapterTitle = const Value.absent(),
    this.isSceneRelevant = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CharactersCompanion.insert({
    required String id,
    required String novelId,
    required String name,
    this.aliasesJson = const Value.absent(),
    this.appearance = const Value.absent(),
    this.personality = const Value.absent(),
    this.background = const Value.absent(),
    this.currentGoal = const Value.absent(),
    this.currentLocation = const Value.absent(),
    this.physicalState = const Value.absent(),
    this.mentalState = const Value.absent(),
    this.lastSeenChapterTitle = const Value.absent(),
    this.isSceneRelevant = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       novelId = Value(novelId),
       name = Value(name);
  static Insertable<Character> custom({
    Expression<String>? id,
    Expression<String>? novelId,
    Expression<String>? name,
    Expression<String>? aliasesJson,
    Expression<String>? appearance,
    Expression<String>? personality,
    Expression<String>? background,
    Expression<String>? currentGoal,
    Expression<String>? currentLocation,
    Expression<String>? physicalState,
    Expression<String>? mentalState,
    Expression<String>? lastSeenChapterTitle,
    Expression<bool>? isSceneRelevant,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (novelId != null) 'novel_id': novelId,
      if (name != null) 'name': name,
      if (aliasesJson != null) 'aliases_json': aliasesJson,
      if (appearance != null) 'appearance': appearance,
      if (personality != null) 'personality': personality,
      if (background != null) 'background': background,
      if (currentGoal != null) 'current_goal': currentGoal,
      if (currentLocation != null) 'current_location': currentLocation,
      if (physicalState != null) 'physical_state': physicalState,
      if (mentalState != null) 'mental_state': mentalState,
      if (lastSeenChapterTitle != null)
        'last_seen_chapter_title': lastSeenChapterTitle,
      if (isSceneRelevant != null) 'is_scene_relevant': isSceneRelevant,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CharactersCompanion copyWith({
    Value<String>? id,
    Value<String>? novelId,
    Value<String>? name,
    Value<String>? aliasesJson,
    Value<String?>? appearance,
    Value<String?>? personality,
    Value<String?>? background,
    Value<String?>? currentGoal,
    Value<String?>? currentLocation,
    Value<String?>? physicalState,
    Value<String?>? mentalState,
    Value<String?>? lastSeenChapterTitle,
    Value<bool>? isSceneRelevant,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return CharactersCompanion(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      name: name ?? this.name,
      aliasesJson: aliasesJson ?? this.aliasesJson,
      appearance: appearance ?? this.appearance,
      personality: personality ?? this.personality,
      background: background ?? this.background,
      currentGoal: currentGoal ?? this.currentGoal,
      currentLocation: currentLocation ?? this.currentLocation,
      physicalState: physicalState ?? this.physicalState,
      mentalState: mentalState ?? this.mentalState,
      lastSeenChapterTitle: lastSeenChapterTitle ?? this.lastSeenChapterTitle,
      isSceneRelevant: isSceneRelevant ?? this.isSceneRelevant,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (novelId.present) {
      map['novel_id'] = Variable<String>(novelId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (aliasesJson.present) {
      map['aliases_json'] = Variable<String>(aliasesJson.value);
    }
    if (appearance.present) {
      map['appearance'] = Variable<String>(appearance.value);
    }
    if (personality.present) {
      map['personality'] = Variable<String>(personality.value);
    }
    if (background.present) {
      map['background'] = Variable<String>(background.value);
    }
    if (currentGoal.present) {
      map['current_goal'] = Variable<String>(currentGoal.value);
    }
    if (currentLocation.present) {
      map['current_location'] = Variable<String>(currentLocation.value);
    }
    if (physicalState.present) {
      map['physical_state'] = Variable<String>(physicalState.value);
    }
    if (mentalState.present) {
      map['mental_state'] = Variable<String>(mentalState.value);
    }
    if (lastSeenChapterTitle.present) {
      map['last_seen_chapter_title'] = Variable<String>(
        lastSeenChapterTitle.value,
      );
    }
    if (isSceneRelevant.present) {
      map['is_scene_relevant'] = Variable<bool>(isSceneRelevant.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharactersCompanion(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('name: $name, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('appearance: $appearance, ')
          ..write('personality: $personality, ')
          ..write('background: $background, ')
          ..write('currentGoal: $currentGoal, ')
          ..write('currentLocation: $currentLocation, ')
          ..write('physicalState: $physicalState, ')
          ..write('mentalState: $mentalState, ')
          ..write('lastSeenChapterTitle: $lastSeenChapterTitle, ')
          ..write('isSceneRelevant: $isSceneRelevant, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorldEntriesTable extends WorldEntries
    with TableInfo<$WorldEntriesTable, WorldEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorldEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _novelIdMeta = const VerificationMeta(
    'novelId',
  );
  @override
  late final GeneratedColumn<String> novelId = GeneratedColumn<String>(
    'novel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES novels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _keywordsJsonMeta = const VerificationMeta(
    'keywordsJson',
  );
  @override
  late final GeneratedColumn<String> keywordsJson = GeneratedColumn<String>(
    'keywords_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _isAlwaysOnMeta = const VerificationMeta(
    'isAlwaysOn',
  );
  @override
  late final GeneratedColumn<bool> isAlwaysOn = GeneratedColumn<bool>(
    'is_always_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_always_on" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    novelId,
    category,
    name,
    content,
    keywordsJson,
    isAlwaysOn,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'world_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorldEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('novel_id')) {
      context.handle(
        _novelIdMeta,
        novelId.isAcceptableOrUnknown(data['novel_id']!, _novelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_novelIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('keywords_json')) {
      context.handle(
        _keywordsJsonMeta,
        keywordsJson.isAcceptableOrUnknown(
          data['keywords_json']!,
          _keywordsJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_always_on')) {
      context.handle(
        _isAlwaysOnMeta,
        isAlwaysOn.isAcceptableOrUnknown(
          data['is_always_on']!,
          _isAlwaysOnMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorldEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorldEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      novelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}novel_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      keywordsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keywords_json'],
      )!,
      isAlwaysOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_always_on'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $WorldEntriesTable createAlias(String alias) {
    return $WorldEntriesTable(attachedDatabase, alias);
  }
}

class WorldEntry extends DataClass implements Insertable<WorldEntry> {
  final String id;
  final String novelId;
  final String category;
  final String name;
  final String content;
  final String keywordsJson;
  final bool isAlwaysOn;
  final int sortOrder;
  const WorldEntry({
    required this.id,
    required this.novelId,
    required this.category,
    required this.name,
    required this.content,
    required this.keywordsJson,
    required this.isAlwaysOn,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['novel_id'] = Variable<String>(novelId);
    map['category'] = Variable<String>(category);
    map['name'] = Variable<String>(name);
    map['content'] = Variable<String>(content);
    map['keywords_json'] = Variable<String>(keywordsJson);
    map['is_always_on'] = Variable<bool>(isAlwaysOn);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  WorldEntriesCompanion toCompanion(bool nullToAbsent) {
    return WorldEntriesCompanion(
      id: Value(id),
      novelId: Value(novelId),
      category: Value(category),
      name: Value(name),
      content: Value(content),
      keywordsJson: Value(keywordsJson),
      isAlwaysOn: Value(isAlwaysOn),
      sortOrder: Value(sortOrder),
    );
  }

  factory WorldEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorldEntry(
      id: serializer.fromJson<String>(json['id']),
      novelId: serializer.fromJson<String>(json['novelId']),
      category: serializer.fromJson<String>(json['category']),
      name: serializer.fromJson<String>(json['name']),
      content: serializer.fromJson<String>(json['content']),
      keywordsJson: serializer.fromJson<String>(json['keywordsJson']),
      isAlwaysOn: serializer.fromJson<bool>(json['isAlwaysOn']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'novelId': serializer.toJson<String>(novelId),
      'category': serializer.toJson<String>(category),
      'name': serializer.toJson<String>(name),
      'content': serializer.toJson<String>(content),
      'keywordsJson': serializer.toJson<String>(keywordsJson),
      'isAlwaysOn': serializer.toJson<bool>(isAlwaysOn),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  WorldEntry copyWith({
    String? id,
    String? novelId,
    String? category,
    String? name,
    String? content,
    String? keywordsJson,
    bool? isAlwaysOn,
    int? sortOrder,
  }) => WorldEntry(
    id: id ?? this.id,
    novelId: novelId ?? this.novelId,
    category: category ?? this.category,
    name: name ?? this.name,
    content: content ?? this.content,
    keywordsJson: keywordsJson ?? this.keywordsJson,
    isAlwaysOn: isAlwaysOn ?? this.isAlwaysOn,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  WorldEntry copyWithCompanion(WorldEntriesCompanion data) {
    return WorldEntry(
      id: data.id.present ? data.id.value : this.id,
      novelId: data.novelId.present ? data.novelId.value : this.novelId,
      category: data.category.present ? data.category.value : this.category,
      name: data.name.present ? data.name.value : this.name,
      content: data.content.present ? data.content.value : this.content,
      keywordsJson: data.keywordsJson.present
          ? data.keywordsJson.value
          : this.keywordsJson,
      isAlwaysOn: data.isAlwaysOn.present
          ? data.isAlwaysOn.value
          : this.isAlwaysOn,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorldEntry(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('category: $category, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('keywordsJson: $keywordsJson, ')
          ..write('isAlwaysOn: $isAlwaysOn, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    novelId,
    category,
    name,
    content,
    keywordsJson,
    isAlwaysOn,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorldEntry &&
          other.id == this.id &&
          other.novelId == this.novelId &&
          other.category == this.category &&
          other.name == this.name &&
          other.content == this.content &&
          other.keywordsJson == this.keywordsJson &&
          other.isAlwaysOn == this.isAlwaysOn &&
          other.sortOrder == this.sortOrder);
}

class WorldEntriesCompanion extends UpdateCompanion<WorldEntry> {
  final Value<String> id;
  final Value<String> novelId;
  final Value<String> category;
  final Value<String> name;
  final Value<String> content;
  final Value<String> keywordsJson;
  final Value<bool> isAlwaysOn;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const WorldEntriesCompanion({
    this.id = const Value.absent(),
    this.novelId = const Value.absent(),
    this.category = const Value.absent(),
    this.name = const Value.absent(),
    this.content = const Value.absent(),
    this.keywordsJson = const Value.absent(),
    this.isAlwaysOn = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorldEntriesCompanion.insert({
    required String id,
    required String novelId,
    required String category,
    required String name,
    this.content = const Value.absent(),
    this.keywordsJson = const Value.absent(),
    this.isAlwaysOn = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       novelId = Value(novelId),
       category = Value(category),
       name = Value(name);
  static Insertable<WorldEntry> custom({
    Expression<String>? id,
    Expression<String>? novelId,
    Expression<String>? category,
    Expression<String>? name,
    Expression<String>? content,
    Expression<String>? keywordsJson,
    Expression<bool>? isAlwaysOn,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (novelId != null) 'novel_id': novelId,
      if (category != null) 'category': category,
      if (name != null) 'name': name,
      if (content != null) 'content': content,
      if (keywordsJson != null) 'keywords_json': keywordsJson,
      if (isAlwaysOn != null) 'is_always_on': isAlwaysOn,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorldEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? novelId,
    Value<String>? category,
    Value<String>? name,
    Value<String>? content,
    Value<String>? keywordsJson,
    Value<bool>? isAlwaysOn,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return WorldEntriesCompanion(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      category: category ?? this.category,
      name: name ?? this.name,
      content: content ?? this.content,
      keywordsJson: keywordsJson ?? this.keywordsJson,
      isAlwaysOn: isAlwaysOn ?? this.isAlwaysOn,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (novelId.present) {
      map['novel_id'] = Variable<String>(novelId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (keywordsJson.present) {
      map['keywords_json'] = Variable<String>(keywordsJson.value);
    }
    if (isAlwaysOn.present) {
      map['is_always_on'] = Variable<bool>(isAlwaysOn.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorldEntriesCompanion(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('category: $category, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('keywordsJson: $keywordsJson, ')
          ..write('isAlwaysOn: $isAlwaysOn, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ForeshadowingsTable extends Foreshadowings
    with TableInfo<$ForeshadowingsTable, Foreshadowing> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ForeshadowingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _novelIdMeta = const VerificationMeta(
    'novelId',
  );
  @override
  late final GeneratedColumn<String> novelId = GeneratedColumn<String>(
    'novel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES novels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plantedVolumeIndexMeta =
      const VerificationMeta('plantedVolumeIndex');
  @override
  late final GeneratedColumn<int> plantedVolumeIndex = GeneratedColumn<int>(
    'planted_volume_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plantedChapterOrderMeta =
      const VerificationMeta('plantedChapterOrder');
  @override
  late final GeneratedColumn<int> plantedChapterOrder = GeneratedColumn<int>(
    'planted_chapter_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedResolveMeta = const VerificationMeta(
    'plannedResolve',
  );
  @override
  late final GeneratedColumn<String> plannedResolve = GeneratedColumn<String>(
    'planned_resolve',
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
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suggestedResolvedMeta = const VerificationMeta(
    'suggestedResolved',
  );
  @override
  late final GeneratedColumn<bool> suggestedResolved = GeneratedColumn<bool>(
    'suggested_resolved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("suggested_resolved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    novelId,
    title,
    detail,
    plantedVolumeIndex,
    plantedChapterOrder,
    plannedResolve,
    status,
    note,
    suggestedResolved,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foreshadowings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Foreshadowing> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('novel_id')) {
      context.handle(
        _novelIdMeta,
        novelId.isAcceptableOrUnknown(data['novel_id']!, _novelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_novelIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('planted_volume_index')) {
      context.handle(
        _plantedVolumeIndexMeta,
        plantedVolumeIndex.isAcceptableOrUnknown(
          data['planted_volume_index']!,
          _plantedVolumeIndexMeta,
        ),
      );
    }
    if (data.containsKey('planted_chapter_order')) {
      context.handle(
        _plantedChapterOrderMeta,
        plantedChapterOrder.isAcceptableOrUnknown(
          data['planted_chapter_order']!,
          _plantedChapterOrderMeta,
        ),
      );
    }
    if (data.containsKey('planned_resolve')) {
      context.handle(
        _plannedResolveMeta,
        plannedResolve.isAcceptableOrUnknown(
          data['planned_resolve']!,
          _plannedResolveMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('suggested_resolved')) {
      context.handle(
        _suggestedResolvedMeta,
        suggestedResolved.isAcceptableOrUnknown(
          data['suggested_resolved']!,
          _suggestedResolvedMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Foreshadowing map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Foreshadowing(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      novelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}novel_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      plantedVolumeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planted_volume_index'],
      ),
      plantedChapterOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planted_chapter_order'],
      ),
      plannedResolve: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}planned_resolve'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      suggestedResolved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}suggested_resolved'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ForeshadowingsTable createAlias(String alias) {
    return $ForeshadowingsTable(attachedDatabase, alias);
  }
}

class Foreshadowing extends DataClass implements Insertable<Foreshadowing> {
  final String id;
  final String novelId;
  final String title;
  final String? detail;
  final int? plantedVolumeIndex;
  final int? plantedChapterOrder;
  final String? plannedResolve;
  final String status;
  final String? note;
  final bool suggestedResolved;
  final DateTime createdAt;
  const Foreshadowing({
    required this.id,
    required this.novelId,
    required this.title,
    this.detail,
    this.plantedVolumeIndex,
    this.plantedChapterOrder,
    this.plannedResolve,
    required this.status,
    this.note,
    required this.suggestedResolved,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['novel_id'] = Variable<String>(novelId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    if (!nullToAbsent || plantedVolumeIndex != null) {
      map['planted_volume_index'] = Variable<int>(plantedVolumeIndex);
    }
    if (!nullToAbsent || plantedChapterOrder != null) {
      map['planted_chapter_order'] = Variable<int>(plantedChapterOrder);
    }
    if (!nullToAbsent || plannedResolve != null) {
      map['planned_resolve'] = Variable<String>(plannedResolve);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['suggested_resolved'] = Variable<bool>(suggestedResolved);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ForeshadowingsCompanion toCompanion(bool nullToAbsent) {
    return ForeshadowingsCompanion(
      id: Value(id),
      novelId: Value(novelId),
      title: Value(title),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      plantedVolumeIndex: plantedVolumeIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(plantedVolumeIndex),
      plantedChapterOrder: plantedChapterOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(plantedChapterOrder),
      plannedResolve: plannedResolve == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedResolve),
      status: Value(status),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      suggestedResolved: Value(suggestedResolved),
      createdAt: Value(createdAt),
    );
  }

  factory Foreshadowing.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Foreshadowing(
      id: serializer.fromJson<String>(json['id']),
      novelId: serializer.fromJson<String>(json['novelId']),
      title: serializer.fromJson<String>(json['title']),
      detail: serializer.fromJson<String?>(json['detail']),
      plantedVolumeIndex: serializer.fromJson<int?>(json['plantedVolumeIndex']),
      plantedChapterOrder: serializer.fromJson<int?>(
        json['plantedChapterOrder'],
      ),
      plannedResolve: serializer.fromJson<String?>(json['plannedResolve']),
      status: serializer.fromJson<String>(json['status']),
      note: serializer.fromJson<String?>(json['note']),
      suggestedResolved: serializer.fromJson<bool>(json['suggestedResolved']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'novelId': serializer.toJson<String>(novelId),
      'title': serializer.toJson<String>(title),
      'detail': serializer.toJson<String?>(detail),
      'plantedVolumeIndex': serializer.toJson<int?>(plantedVolumeIndex),
      'plantedChapterOrder': serializer.toJson<int?>(plantedChapterOrder),
      'plannedResolve': serializer.toJson<String?>(plannedResolve),
      'status': serializer.toJson<String>(status),
      'note': serializer.toJson<String?>(note),
      'suggestedResolved': serializer.toJson<bool>(suggestedResolved),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Foreshadowing copyWith({
    String? id,
    String? novelId,
    String? title,
    Value<String?> detail = const Value.absent(),
    Value<int?> plantedVolumeIndex = const Value.absent(),
    Value<int?> plantedChapterOrder = const Value.absent(),
    Value<String?> plannedResolve = const Value.absent(),
    String? status,
    Value<String?> note = const Value.absent(),
    bool? suggestedResolved,
    DateTime? createdAt,
  }) => Foreshadowing(
    id: id ?? this.id,
    novelId: novelId ?? this.novelId,
    title: title ?? this.title,
    detail: detail.present ? detail.value : this.detail,
    plantedVolumeIndex: plantedVolumeIndex.present
        ? plantedVolumeIndex.value
        : this.plantedVolumeIndex,
    plantedChapterOrder: plantedChapterOrder.present
        ? plantedChapterOrder.value
        : this.plantedChapterOrder,
    plannedResolve: plannedResolve.present
        ? plannedResolve.value
        : this.plannedResolve,
    status: status ?? this.status,
    note: note.present ? note.value : this.note,
    suggestedResolved: suggestedResolved ?? this.suggestedResolved,
    createdAt: createdAt ?? this.createdAt,
  );
  Foreshadowing copyWithCompanion(ForeshadowingsCompanion data) {
    return Foreshadowing(
      id: data.id.present ? data.id.value : this.id,
      novelId: data.novelId.present ? data.novelId.value : this.novelId,
      title: data.title.present ? data.title.value : this.title,
      detail: data.detail.present ? data.detail.value : this.detail,
      plantedVolumeIndex: data.plantedVolumeIndex.present
          ? data.plantedVolumeIndex.value
          : this.plantedVolumeIndex,
      plantedChapterOrder: data.plantedChapterOrder.present
          ? data.plantedChapterOrder.value
          : this.plantedChapterOrder,
      plannedResolve: data.plannedResolve.present
          ? data.plannedResolve.value
          : this.plannedResolve,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      suggestedResolved: data.suggestedResolved.present
          ? data.suggestedResolved.value
          : this.suggestedResolved,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Foreshadowing(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('plantedVolumeIndex: $plantedVolumeIndex, ')
          ..write('plantedChapterOrder: $plantedChapterOrder, ')
          ..write('plannedResolve: $plannedResolve, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('suggestedResolved: $suggestedResolved, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    novelId,
    title,
    detail,
    plantedVolumeIndex,
    plantedChapterOrder,
    plannedResolve,
    status,
    note,
    suggestedResolved,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Foreshadowing &&
          other.id == this.id &&
          other.novelId == this.novelId &&
          other.title == this.title &&
          other.detail == this.detail &&
          other.plantedVolumeIndex == this.plantedVolumeIndex &&
          other.plantedChapterOrder == this.plantedChapterOrder &&
          other.plannedResolve == this.plannedResolve &&
          other.status == this.status &&
          other.note == this.note &&
          other.suggestedResolved == this.suggestedResolved &&
          other.createdAt == this.createdAt);
}

class ForeshadowingsCompanion extends UpdateCompanion<Foreshadowing> {
  final Value<String> id;
  final Value<String> novelId;
  final Value<String> title;
  final Value<String?> detail;
  final Value<int?> plantedVolumeIndex;
  final Value<int?> plantedChapterOrder;
  final Value<String?> plannedResolve;
  final Value<String> status;
  final Value<String?> note;
  final Value<bool> suggestedResolved;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ForeshadowingsCompanion({
    this.id = const Value.absent(),
    this.novelId = const Value.absent(),
    this.title = const Value.absent(),
    this.detail = const Value.absent(),
    this.plantedVolumeIndex = const Value.absent(),
    this.plantedChapterOrder = const Value.absent(),
    this.plannedResolve = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.suggestedResolved = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ForeshadowingsCompanion.insert({
    required String id,
    required String novelId,
    required String title,
    this.detail = const Value.absent(),
    this.plantedVolumeIndex = const Value.absent(),
    this.plantedChapterOrder = const Value.absent(),
    this.plannedResolve = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.suggestedResolved = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       novelId = Value(novelId),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<Foreshadowing> custom({
    Expression<String>? id,
    Expression<String>? novelId,
    Expression<String>? title,
    Expression<String>? detail,
    Expression<int>? plantedVolumeIndex,
    Expression<int>? plantedChapterOrder,
    Expression<String>? plannedResolve,
    Expression<String>? status,
    Expression<String>? note,
    Expression<bool>? suggestedResolved,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (novelId != null) 'novel_id': novelId,
      if (title != null) 'title': title,
      if (detail != null) 'detail': detail,
      if (plantedVolumeIndex != null)
        'planted_volume_index': plantedVolumeIndex,
      if (plantedChapterOrder != null)
        'planted_chapter_order': plantedChapterOrder,
      if (plannedResolve != null) 'planned_resolve': plannedResolve,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (suggestedResolved != null) 'suggested_resolved': suggestedResolved,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ForeshadowingsCompanion copyWith({
    Value<String>? id,
    Value<String>? novelId,
    Value<String>? title,
    Value<String?>? detail,
    Value<int?>? plantedVolumeIndex,
    Value<int?>? plantedChapterOrder,
    Value<String?>? plannedResolve,
    Value<String>? status,
    Value<String?>? note,
    Value<bool>? suggestedResolved,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ForeshadowingsCompanion(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      plantedVolumeIndex: plantedVolumeIndex ?? this.plantedVolumeIndex,
      plantedChapterOrder: plantedChapterOrder ?? this.plantedChapterOrder,
      plannedResolve: plannedResolve ?? this.plannedResolve,
      status: status ?? this.status,
      note: note ?? this.note,
      suggestedResolved: suggestedResolved ?? this.suggestedResolved,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (novelId.present) {
      map['novel_id'] = Variable<String>(novelId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (plantedVolumeIndex.present) {
      map['planted_volume_index'] = Variable<int>(plantedVolumeIndex.value);
    }
    if (plantedChapterOrder.present) {
      map['planted_chapter_order'] = Variable<int>(plantedChapterOrder.value);
    }
    if (plannedResolve.present) {
      map['planned_resolve'] = Variable<String>(plannedResolve.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (suggestedResolved.present) {
      map['suggested_resolved'] = Variable<bool>(suggestedResolved.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ForeshadowingsCompanion(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('plantedVolumeIndex: $plantedVolumeIndex, ')
          ..write('plantedChapterOrder: $plantedChapterOrder, ')
          ..write('plannedResolve: $plannedResolve, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('suggestedResolved: $suggestedResolved, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatThreadsTable extends ChatThreads
    with TableInfo<$ChatThreadsTable, ChatThread> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatThreadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _novelIdMeta = const VerificationMeta(
    'novelId',
  );
  @override
  late final GeneratedColumn<String> novelId = GeneratedColumn<String>(
    'novel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES novels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skipsClarificationMeta =
      const VerificationMeta('skipsClarification');
  @override
  late final GeneratedColumn<bool> skipsClarification = GeneratedColumn<bool>(
    'skips_clarification',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("skips_clarification" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    novelId,
    purpose,
    skipsClarification,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_threads';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatThread> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('novel_id')) {
      context.handle(
        _novelIdMeta,
        novelId.isAcceptableOrUnknown(data['novel_id']!, _novelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_novelIdMeta);
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    } else if (isInserting) {
      context.missing(_purposeMeta);
    }
    if (data.containsKey('skips_clarification')) {
      context.handle(
        _skipsClarificationMeta,
        skipsClarification.isAcceptableOrUnknown(
          data['skips_clarification']!,
          _skipsClarificationMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatThread map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatThread(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      novelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}novel_id'],
      )!,
      purpose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose'],
      )!,
      skipsClarification: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}skips_clarification'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChatThreadsTable createAlias(String alias) {
    return $ChatThreadsTable(attachedDatabase, alias);
  }
}

class ChatThread extends DataClass implements Insertable<ChatThread> {
  final String id;
  final String novelId;
  final String purpose;
  final bool skipsClarification;
  final DateTime createdAt;
  const ChatThread({
    required this.id,
    required this.novelId,
    required this.purpose,
    required this.skipsClarification,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['novel_id'] = Variable<String>(novelId);
    map['purpose'] = Variable<String>(purpose);
    map['skips_clarification'] = Variable<bool>(skipsClarification);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatThreadsCompanion toCompanion(bool nullToAbsent) {
    return ChatThreadsCompanion(
      id: Value(id),
      novelId: Value(novelId),
      purpose: Value(purpose),
      skipsClarification: Value(skipsClarification),
      createdAt: Value(createdAt),
    );
  }

  factory ChatThread.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatThread(
      id: serializer.fromJson<String>(json['id']),
      novelId: serializer.fromJson<String>(json['novelId']),
      purpose: serializer.fromJson<String>(json['purpose']),
      skipsClarification: serializer.fromJson<bool>(json['skipsClarification']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'novelId': serializer.toJson<String>(novelId),
      'purpose': serializer.toJson<String>(purpose),
      'skipsClarification': serializer.toJson<bool>(skipsClarification),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatThread copyWith({
    String? id,
    String? novelId,
    String? purpose,
    bool? skipsClarification,
    DateTime? createdAt,
  }) => ChatThread(
    id: id ?? this.id,
    novelId: novelId ?? this.novelId,
    purpose: purpose ?? this.purpose,
    skipsClarification: skipsClarification ?? this.skipsClarification,
    createdAt: createdAt ?? this.createdAt,
  );
  ChatThread copyWithCompanion(ChatThreadsCompanion data) {
    return ChatThread(
      id: data.id.present ? data.id.value : this.id,
      novelId: data.novelId.present ? data.novelId.value : this.novelId,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      skipsClarification: data.skipsClarification.present
          ? data.skipsClarification.value
          : this.skipsClarification,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatThread(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('purpose: $purpose, ')
          ..write('skipsClarification: $skipsClarification, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, novelId, purpose, skipsClarification, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatThread &&
          other.id == this.id &&
          other.novelId == this.novelId &&
          other.purpose == this.purpose &&
          other.skipsClarification == this.skipsClarification &&
          other.createdAt == this.createdAt);
}

class ChatThreadsCompanion extends UpdateCompanion<ChatThread> {
  final Value<String> id;
  final Value<String> novelId;
  final Value<String> purpose;
  final Value<bool> skipsClarification;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChatThreadsCompanion({
    this.id = const Value.absent(),
    this.novelId = const Value.absent(),
    this.purpose = const Value.absent(),
    this.skipsClarification = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatThreadsCompanion.insert({
    required String id,
    required String novelId,
    required String purpose,
    this.skipsClarification = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       novelId = Value(novelId),
       purpose = Value(purpose),
       createdAt = Value(createdAt);
  static Insertable<ChatThread> custom({
    Expression<String>? id,
    Expression<String>? novelId,
    Expression<String>? purpose,
    Expression<bool>? skipsClarification,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (novelId != null) 'novel_id': novelId,
      if (purpose != null) 'purpose': purpose,
      if (skipsClarification != null) 'skips_clarification': skipsClarification,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatThreadsCompanion copyWith({
    Value<String>? id,
    Value<String>? novelId,
    Value<String>? purpose,
    Value<bool>? skipsClarification,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ChatThreadsCompanion(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      purpose: purpose ?? this.purpose,
      skipsClarification: skipsClarification ?? this.skipsClarification,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (novelId.present) {
      map['novel_id'] = Variable<String>(novelId.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (skipsClarification.present) {
      map['skips_clarification'] = Variable<bool>(skipsClarification.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatThreadsCompanion(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('purpose: $purpose, ')
          ..write('skipsClarification: $skipsClarification, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_threads (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    threadId,
    role,
    content,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_threadIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String id;
  final String threadId;
  final String role;
  final String content;
  final DateTime createdAt;
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.content,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['thread_id'] = Variable<String>(threadId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      threadId: Value(threadId),
      role: Value(role),
      content: Value(content),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<String>(json['id']),
      threadId: serializer.fromJson<String>(json['threadId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'threadId': serializer.toJson<String>(threadId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? threadId,
    String? role,
    String? content,
    DateTime? createdAt,
  }) => ChatMessage(
    id: id ?? this.id,
    threadId: threadId ?? this.threadId,
    role: role ?? this.role,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, threadId, role, content, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.threadId == this.threadId &&
          other.role == this.role &&
          other.content == this.content &&
          other.createdAt == this.createdAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> id;
  final Value<String> threadId;
  final Value<String> role;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.threadId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required String threadId,
    required String role,
    required String content,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       threadId = Value(threadId),
       role = Value(role),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<ChatMessage> custom({
    Expression<String>? id,
    Expression<String>? threadId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (threadId != null) 'thread_id': threadId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? threadId,
    Value<String>? role,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProvidersTable extends Providers
    with TableInfo<$ProvidersTable, ProviderRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apiKeyIdMeta = const VerificationMeta(
    'apiKeyId',
  );
  @override
  late final GeneratedColumn<String> apiKeyId = GeneratedColumn<String>(
    'api_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelNameMeta = const VerificationMeta(
    'modelName',
  );
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
    'model_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
    'temperature',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.8),
  );
  static const VerificationMeta _maxTokensMeta = const VerificationMeta(
    'maxTokens',
  );
  @override
  late final GeneratedColumn<int> maxTokens = GeneratedColumn<int>(
    'max_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(16384),
  );
  static const VerificationMeta _contextBudgetCharsMeta =
      const VerificationMeta('contextBudgetChars');
  @override
  late final GeneratedColumn<int> contextBudgetChars = GeneratedColumn<int>(
    'context_budget_chars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60000),
  );
  static const VerificationMeta _systemPromptExtraMeta = const VerificationMeta(
    'systemPromptExtra',
  );
  @override
  late final GeneratedColumn<String> systemPromptExtra =
      GeneratedColumn<String>(
        'system_prompt_extra',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _proxyUrlMeta = const VerificationMeta(
    'proxyUrl',
  );
  @override
  late final GeneratedColumn<String> proxyUrl = GeneratedColumn<String>(
    'proxy_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    baseUrl,
    apiKeyId,
    modelName,
    temperature,
    maxTokens,
    contextBudgetChars,
    systemPromptExtra,
    proxyUrl,
    isDefault,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('api_key_id')) {
      context.handle(
        _apiKeyIdMeta,
        apiKeyId.isAcceptableOrUnknown(data['api_key_id']!, _apiKeyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_apiKeyIdMeta);
    }
    if (data.containsKey('model_name')) {
      context.handle(
        _modelNameMeta,
        modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta),
      );
    } else if (isInserting) {
      context.missing(_modelNameMeta);
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    }
    if (data.containsKey('max_tokens')) {
      context.handle(
        _maxTokensMeta,
        maxTokens.isAcceptableOrUnknown(data['max_tokens']!, _maxTokensMeta),
      );
    }
    if (data.containsKey('context_budget_chars')) {
      context.handle(
        _contextBudgetCharsMeta,
        contextBudgetChars.isAcceptableOrUnknown(
          data['context_budget_chars']!,
          _contextBudgetCharsMeta,
        ),
      );
    }
    if (data.containsKey('system_prompt_extra')) {
      context.handle(
        _systemPromptExtraMeta,
        systemPromptExtra.isAcceptableOrUnknown(
          data['system_prompt_extra']!,
          _systemPromptExtraMeta,
        ),
      );
    }
    if (data.containsKey('proxy_url')) {
      context.handle(
        _proxyUrlMeta,
        proxyUrl.isAcceptableOrUnknown(data['proxy_url']!, _proxyUrlMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      apiKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_key_id'],
      )!,
      modelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_name'],
      )!,
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature'],
      )!,
      maxTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_tokens'],
      )!,
      contextBudgetChars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}context_budget_chars'],
      )!,
      systemPromptExtra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt_extra'],
      ),
      proxyUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proxy_url'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProvidersTable createAlias(String alias) {
    return $ProvidersTable(attachedDatabase, alias);
  }
}

class ProviderRecord extends DataClass implements Insertable<ProviderRecord> {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKeyId;
  final String modelName;
  final double temperature;
  final int maxTokens;
  final int contextBudgetChars;
  final String? systemPromptExtra;
  final String? proxyUrl;
  final bool isDefault;
  final DateTime createdAt;
  const ProviderRecord({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKeyId,
    required this.modelName,
    required this.temperature,
    required this.maxTokens,
    required this.contextBudgetChars,
    this.systemPromptExtra,
    this.proxyUrl,
    required this.isDefault,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['api_key_id'] = Variable<String>(apiKeyId);
    map['model_name'] = Variable<String>(modelName);
    map['temperature'] = Variable<double>(temperature);
    map['max_tokens'] = Variable<int>(maxTokens);
    map['context_budget_chars'] = Variable<int>(contextBudgetChars);
    if (!nullToAbsent || systemPromptExtra != null) {
      map['system_prompt_extra'] = Variable<String>(systemPromptExtra);
    }
    if (!nullToAbsent || proxyUrl != null) {
      map['proxy_url'] = Variable<String>(proxyUrl);
    }
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProvidersCompanion toCompanion(bool nullToAbsent) {
    return ProvidersCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      apiKeyId: Value(apiKeyId),
      modelName: Value(modelName),
      temperature: Value(temperature),
      maxTokens: Value(maxTokens),
      contextBudgetChars: Value(contextBudgetChars),
      systemPromptExtra: systemPromptExtra == null && nullToAbsent
          ? const Value.absent()
          : Value(systemPromptExtra),
      proxyUrl: proxyUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(proxyUrl),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
    );
  }

  factory ProviderRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderRecord(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      apiKeyId: serializer.fromJson<String>(json['apiKeyId']),
      modelName: serializer.fromJson<String>(json['modelName']),
      temperature: serializer.fromJson<double>(json['temperature']),
      maxTokens: serializer.fromJson<int>(json['maxTokens']),
      contextBudgetChars: serializer.fromJson<int>(json['contextBudgetChars']),
      systemPromptExtra: serializer.fromJson<String?>(
        json['systemPromptExtra'],
      ),
      proxyUrl: serializer.fromJson<String?>(json['proxyUrl']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'apiKeyId': serializer.toJson<String>(apiKeyId),
      'modelName': serializer.toJson<String>(modelName),
      'temperature': serializer.toJson<double>(temperature),
      'maxTokens': serializer.toJson<int>(maxTokens),
      'contextBudgetChars': serializer.toJson<int>(contextBudgetChars),
      'systemPromptExtra': serializer.toJson<String?>(systemPromptExtra),
      'proxyUrl': serializer.toJson<String?>(proxyUrl),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProviderRecord copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKeyId,
    String? modelName,
    double? temperature,
    int? maxTokens,
    int? contextBudgetChars,
    Value<String?> systemPromptExtra = const Value.absent(),
    Value<String?> proxyUrl = const Value.absent(),
    bool? isDefault,
    DateTime? createdAt,
  }) => ProviderRecord(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    apiKeyId: apiKeyId ?? this.apiKeyId,
    modelName: modelName ?? this.modelName,
    temperature: temperature ?? this.temperature,
    maxTokens: maxTokens ?? this.maxTokens,
    contextBudgetChars: contextBudgetChars ?? this.contextBudgetChars,
    systemPromptExtra: systemPromptExtra.present
        ? systemPromptExtra.value
        : this.systemPromptExtra,
    proxyUrl: proxyUrl.present ? proxyUrl.value : this.proxyUrl,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
  );
  ProviderRecord copyWithCompanion(ProvidersCompanion data) {
    return ProviderRecord(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      apiKeyId: data.apiKeyId.present ? data.apiKeyId.value : this.apiKeyId,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      maxTokens: data.maxTokens.present ? data.maxTokens.value : this.maxTokens,
      contextBudgetChars: data.contextBudgetChars.present
          ? data.contextBudgetChars.value
          : this.contextBudgetChars,
      systemPromptExtra: data.systemPromptExtra.present
          ? data.systemPromptExtra.value
          : this.systemPromptExtra,
      proxyUrl: data.proxyUrl.present ? data.proxyUrl.value : this.proxyUrl,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderRecord(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKeyId: $apiKeyId, ')
          ..write('modelName: $modelName, ')
          ..write('temperature: $temperature, ')
          ..write('maxTokens: $maxTokens, ')
          ..write('contextBudgetChars: $contextBudgetChars, ')
          ..write('systemPromptExtra: $systemPromptExtra, ')
          ..write('proxyUrl: $proxyUrl, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    baseUrl,
    apiKeyId,
    modelName,
    temperature,
    maxTokens,
    contextBudgetChars,
    systemPromptExtra,
    proxyUrl,
    isDefault,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderRecord &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.apiKeyId == this.apiKeyId &&
          other.modelName == this.modelName &&
          other.temperature == this.temperature &&
          other.maxTokens == this.maxTokens &&
          other.contextBudgetChars == this.contextBudgetChars &&
          other.systemPromptExtra == this.systemPromptExtra &&
          other.proxyUrl == this.proxyUrl &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt);
}

class ProvidersCompanion extends UpdateCompanion<ProviderRecord> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String> apiKeyId;
  final Value<String> modelName;
  final Value<double> temperature;
  final Value<int> maxTokens;
  final Value<int> contextBudgetChars;
  final Value<String?> systemPromptExtra;
  final Value<String?> proxyUrl;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProvidersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.apiKeyId = const Value.absent(),
    this.modelName = const Value.absent(),
    this.temperature = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.contextBudgetChars = const Value.absent(),
    this.systemPromptExtra = const Value.absent(),
    this.proxyUrl = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProvidersCompanion.insert({
    required String id,
    required String name,
    required String baseUrl,
    required String apiKeyId,
    required String modelName,
    this.temperature = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.contextBudgetChars = const Value.absent(),
    this.systemPromptExtra = const Value.absent(),
    this.proxyUrl = const Value.absent(),
    this.isDefault = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       baseUrl = Value(baseUrl),
       apiKeyId = Value(apiKeyId),
       modelName = Value(modelName),
       createdAt = Value(createdAt);
  static Insertable<ProviderRecord> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? apiKeyId,
    Expression<String>? modelName,
    Expression<double>? temperature,
    Expression<int>? maxTokens,
    Expression<int>? contextBudgetChars,
    Expression<String>? systemPromptExtra,
    Expression<String>? proxyUrl,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (apiKeyId != null) 'api_key_id': apiKeyId,
      if (modelName != null) 'model_name': modelName,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (contextBudgetChars != null)
        'context_budget_chars': contextBudgetChars,
      if (systemPromptExtra != null) 'system_prompt_extra': systemPromptExtra,
      if (proxyUrl != null) 'proxy_url': proxyUrl,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProvidersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<String>? apiKeyId,
    Value<String>? modelName,
    Value<double>? temperature,
    Value<int>? maxTokens,
    Value<int>? contextBudgetChars,
    Value<String?>? systemPromptExtra,
    Value<String?>? proxyUrl,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProvidersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKeyId: apiKeyId ?? this.apiKeyId,
      modelName: modelName ?? this.modelName,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      contextBudgetChars: contextBudgetChars ?? this.contextBudgetChars,
      systemPromptExtra: systemPromptExtra ?? this.systemPromptExtra,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (apiKeyId.present) {
      map['api_key_id'] = Variable<String>(apiKeyId.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (maxTokens.present) {
      map['max_tokens'] = Variable<int>(maxTokens.value);
    }
    if (contextBudgetChars.present) {
      map['context_budget_chars'] = Variable<int>(contextBudgetChars.value);
    }
    if (systemPromptExtra.present) {
      map['system_prompt_extra'] = Variable<String>(systemPromptExtra.value);
    }
    if (proxyUrl.present) {
      map['proxy_url'] = Variable<String>(proxyUrl.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProvidersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKeyId: $apiKeyId, ')
          ..write('modelName: $modelName, ')
          ..write('temperature: $temperature, ')
          ..write('maxTokens: $maxTokens, ')
          ..write('contextBudgetChars: $contextBudgetChars, ')
          ..write('systemPromptExtra: $systemPromptExtra, ')
          ..write('proxyUrl: $proxyUrl, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StyleProfilesTable extends StyleProfiles
    with TableInfo<$StyleProfilesTable, StyleProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StyleProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
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
  List<GeneratedColumn> get $columns => [id, name, payloadJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'style_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<StyleProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StyleProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StyleProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StyleProfilesTable createAlias(String alias) {
    return $StyleProfilesTable(attachedDatabase, alias);
  }
}

class StyleProfile extends DataClass implements Insertable<StyleProfile> {
  final String id;
  final String name;
  final String payloadJson;
  final DateTime updatedAt;
  const StyleProfile({
    required this.id,
    required this.name,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StyleProfilesCompanion toCompanion(bool nullToAbsent) {
    return StyleProfilesCompanion(
      id: Value(id),
      name: Value(name),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory StyleProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StyleProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StyleProfile copyWith({
    String? id,
    String? name,
    String? payloadJson,
    DateTime? updatedAt,
  }) => StyleProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StyleProfile copyWithCompanion(StyleProfilesCompanion data) {
    return StyleProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StyleProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StyleProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class StyleProfilesCompanion extends UpdateCompanion<StyleProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StyleProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StyleProfilesCompanion.insert({
    required String id,
    required String name,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<StyleProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StyleProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StyleProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
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
    return (StringBuffer('StyleProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourceProfilesTable extends SourceProfiles
    with TableInfo<$SourceProfilesTable, SourceProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    author,
    payloadJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SourceProfilesTable createAlias(String alias) {
    return $SourceProfilesTable(attachedDatabase, alias);
  }
}

class SourceProfile extends DataClass implements Insertable<SourceProfile> {
  final String id;
  final String title;
  final String? author;
  final String payloadJson;
  final DateTime createdAt;
  const SourceProfile({
    required this.id,
    required this.title,
    this.author,
    required this.payloadJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SourceProfilesCompanion toCompanion(bool nullToAbsent) {
    return SourceProfilesCompanion(
      id: Value(id),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
    );
  }

  factory SourceProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceProfile(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SourceProfile copyWith({
    String? id,
    String? title,
    Value<String?> author = const Value.absent(),
    String? payloadJson,
    DateTime? createdAt,
  }) => SourceProfile(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
  );
  SourceProfile copyWithCompanion(SourceProfilesCompanion data) {
    return SourceProfile(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceProfile(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, author, payloadJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceProfile &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt);
}

class SourceProfilesCompanion extends UpdateCompanion<SourceProfile> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> author;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SourceProfilesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceProfilesCompanion.insert({
    required String id,
    required String title,
    this.author = const Value.absent(),
    required String payloadJson,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<SourceProfile> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? author,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SourceProfilesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceProfilesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PromptOverridesTable extends PromptOverrides
    with TableInfo<$PromptOverridesTable, PromptOverride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PromptOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _promptIdMeta = const VerificationMeta(
    'promptId',
  );
  @override
  late final GeneratedColumn<String> promptId = GeneratedColumn<String>(
    'prompt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
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
  List<GeneratedColumn> get $columns => [promptId, content, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prompt_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<PromptOverride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('prompt_id')) {
      context.handle(
        _promptIdMeta,
        promptId.isAcceptableOrUnknown(data['prompt_id']!, _promptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_promptIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
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
  Set<GeneratedColumn> get $primaryKey => {promptId};
  @override
  PromptOverride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PromptOverride(
      promptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PromptOverridesTable createAlias(String alias) {
    return $PromptOverridesTable(attachedDatabase, alias);
  }
}

class PromptOverride extends DataClass implements Insertable<PromptOverride> {
  final String promptId;
  final String content;
  final DateTime updatedAt;
  const PromptOverride({
    required this.promptId,
    required this.content,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['prompt_id'] = Variable<String>(promptId);
    map['content'] = Variable<String>(content);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PromptOverridesCompanion toCompanion(bool nullToAbsent) {
    return PromptOverridesCompanion(
      promptId: Value(promptId),
      content: Value(content),
      updatedAt: Value(updatedAt),
    );
  }

  factory PromptOverride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PromptOverride(
      promptId: serializer.fromJson<String>(json['promptId']),
      content: serializer.fromJson<String>(json['content']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'promptId': serializer.toJson<String>(promptId),
      'content': serializer.toJson<String>(content),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PromptOverride copyWith({
    String? promptId,
    String? content,
    DateTime? updatedAt,
  }) => PromptOverride(
    promptId: promptId ?? this.promptId,
    content: content ?? this.content,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PromptOverride copyWithCompanion(PromptOverridesCompanion data) {
    return PromptOverride(
      promptId: data.promptId.present ? data.promptId.value : this.promptId,
      content: data.content.present ? data.content.value : this.content,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PromptOverride(')
          ..write('promptId: $promptId, ')
          ..write('content: $content, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(promptId, content, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptOverride &&
          other.promptId == this.promptId &&
          other.content == this.content &&
          other.updatedAt == this.updatedAt);
}

class PromptOverridesCompanion extends UpdateCompanion<PromptOverride> {
  final Value<String> promptId;
  final Value<String> content;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PromptOverridesCompanion({
    this.promptId = const Value.absent(),
    this.content = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PromptOverridesCompanion.insert({
    required String promptId,
    required String content,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : promptId = Value(promptId),
       content = Value(content),
       updatedAt = Value(updatedAt);
  static Insertable<PromptOverride> custom({
    Expression<String>? promptId,
    Expression<String>? content,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (promptId != null) 'prompt_id': promptId,
      if (content != null) 'content': content,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PromptOverridesCompanion copyWith({
    Value<String>? promptId,
    Value<String>? content,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PromptOverridesCompanion(
      promptId: promptId ?? this.promptId,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (promptId.present) {
      map['prompt_id'] = Variable<String>(promptId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
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
    return (StringBuffer('PromptOverridesCompanion(')
          ..write('promptId: $promptId, ')
          ..write('content: $content, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PromptTagCategoriesTable extends PromptTagCategories
    with TableInfo<$PromptTagCategoriesTable, PromptTagCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PromptTagCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, tagsJson, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prompt_tag_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<PromptTagCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsJsonMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PromptTagCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PromptTagCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $PromptTagCategoriesTable createAlias(String alias) {
    return $PromptTagCategoriesTable(attachedDatabase, alias);
  }
}

class PromptTagCategory extends DataClass
    implements Insertable<PromptTagCategory> {
  final String id;
  final String name;
  final String tagsJson;
  final int sortOrder;
  const PromptTagCategory({
    required this.id,
    required this.name,
    required this.tagsJson,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['tags_json'] = Variable<String>(tagsJson);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  PromptTagCategoriesCompanion toCompanion(bool nullToAbsent) {
    return PromptTagCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      tagsJson: Value(tagsJson),
      sortOrder: Value(sortOrder),
    );
  }

  factory PromptTagCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PromptTagCategory(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  PromptTagCategory copyWith({
    String? id,
    String? name,
    String? tagsJson,
    int? sortOrder,
  }) => PromptTagCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    tagsJson: tagsJson ?? this.tagsJson,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  PromptTagCategory copyWithCompanion(PromptTagCategoriesCompanion data) {
    return PromptTagCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PromptTagCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, tagsJson, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptTagCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.tagsJson == this.tagsJson &&
          other.sortOrder == this.sortOrder);
}

class PromptTagCategoriesCompanion extends UpdateCompanion<PromptTagCategory> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> tagsJson;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const PromptTagCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PromptTagCategoriesCompanion.insert({
    required String id,
    required String name,
    required String tagsJson,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       tagsJson = Value(tagsJson);
  static Insertable<PromptTagCategory> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? tagsJson,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PromptTagCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? tagsJson,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return PromptTagCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      tagsJson: tagsJson ?? this.tagsJson,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PromptTagCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CreationSessionCachesTable extends CreationSessionCaches
    with TableInfo<$CreationSessionCachesTable, CreationSessionCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CreationSessionCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_threads (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
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
  List<GeneratedColumn> get $columns => [threadId, payloadJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'creation_session_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<CreationSessionCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_threadIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {threadId};
  @override
  CreationSessionCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CreationSessionCache(
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CreationSessionCachesTable createAlias(String alias) {
    return $CreationSessionCachesTable(attachedDatabase, alias);
  }
}

class CreationSessionCache extends DataClass
    implements Insertable<CreationSessionCache> {
  final String threadId;
  final String payloadJson;
  final DateTime updatedAt;
  const CreationSessionCache({
    required this.threadId,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['thread_id'] = Variable<String>(threadId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CreationSessionCachesCompanion toCompanion(bool nullToAbsent) {
    return CreationSessionCachesCompanion(
      threadId: Value(threadId),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory CreationSessionCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CreationSessionCache(
      threadId: serializer.fromJson<String>(json['threadId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'threadId': serializer.toJson<String>(threadId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CreationSessionCache copyWith({
    String? threadId,
    String? payloadJson,
    DateTime? updatedAt,
  }) => CreationSessionCache(
    threadId: threadId ?? this.threadId,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CreationSessionCache copyWithCompanion(CreationSessionCachesCompanion data) {
    return CreationSessionCache(
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CreationSessionCache(')
          ..write('threadId: $threadId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(threadId, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreationSessionCache &&
          other.threadId == this.threadId &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class CreationSessionCachesCompanion
    extends UpdateCompanion<CreationSessionCache> {
  final Value<String> threadId;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CreationSessionCachesCompanion({
    this.threadId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CreationSessionCachesCompanion.insert({
    required String threadId,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : threadId = Value(threadId),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<CreationSessionCache> custom({
    Expression<String>? threadId,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (threadId != null) 'thread_id': threadId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CreationSessionCachesCompanion copyWith({
    Value<String>? threadId,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CreationSessionCachesCompanion(
      threadId: threadId ?? this.threadId,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
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
    return (StringBuffer('CreationSessionCachesCompanion(')
          ..write('threadId: $threadId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StyleDistillCachesTable extends StyleDistillCaches
    with TableInfo<$StyleDistillCachesTable, StyleDistillCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StyleDistillCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
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
  List<GeneratedColumn> get $columns => [slot, payloadJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'style_distill_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<StyleDistillCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  StyleDistillCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StyleDistillCache(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StyleDistillCachesTable createAlias(String alias) {
    return $StyleDistillCachesTable(attachedDatabase, alias);
  }
}

class StyleDistillCache extends DataClass
    implements Insertable<StyleDistillCache> {
  final String slot;
  final String payloadJson;
  final DateTime updatedAt;
  const StyleDistillCache({
    required this.slot,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<String>(slot);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StyleDistillCachesCompanion toCompanion(bool nullToAbsent) {
    return StyleDistillCachesCompanion(
      slot: Value(slot),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory StyleDistillCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StyleDistillCache(
      slot: serializer.fromJson<String>(json['slot']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<String>(slot),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StyleDistillCache copyWith({
    String? slot,
    String? payloadJson,
    DateTime? updatedAt,
  }) => StyleDistillCache(
    slot: slot ?? this.slot,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StyleDistillCache copyWithCompanion(StyleDistillCachesCompanion data) {
    return StyleDistillCache(
      slot: data.slot.present ? data.slot.value : this.slot,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StyleDistillCache(')
          ..write('slot: $slot, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StyleDistillCache &&
          other.slot == this.slot &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class StyleDistillCachesCompanion extends UpdateCompanion<StyleDistillCache> {
  final Value<String> slot;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StyleDistillCachesCompanion({
    this.slot = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StyleDistillCachesCompanion.insert({
    required String slot,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : slot = Value(slot),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<StyleDistillCache> custom({
    Expression<String>? slot,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StyleDistillCachesCompanion copyWith({
    Value<String>? slot,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StyleDistillCachesCompanion(
      slot: slot ?? this.slot,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
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
    return (StringBuffer('StyleDistillCachesCompanion(')
          ..write('slot: $slot, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanTasksTable extends ScanTasks
    with TableInfo<$ScanTasksTable, ScanTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchSizeMeta = const VerificationMeta(
    'batchSize',
  );
  @override
  late final GeneratedColumn<int> batchSize = GeneratedColumn<int>(
    'batch_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isContinuationMeta = const VerificationMeta(
    'isContinuation',
  );
  @override
  late final GeneratedColumn<bool> isContinuation = GeneratedColumn<bool>(
    'is_continuation',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_continuation" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _totalChunksMeta = const VerificationMeta(
    'totalChunks',
  );
  @override
  late final GeneratedColumn<int> totalChunks = GeneratedColumn<int>(
    'total_chunks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerNameMeta = const VerificationMeta(
    'providerName',
  );
  @override
  late final GeneratedColumn<String> providerName = GeneratedColumn<String>(
    'provider_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerBaseUrlMeta = const VerificationMeta(
    'providerBaseUrl',
  );
  @override
  late final GeneratedColumn<String> providerBaseUrl = GeneratedColumn<String>(
    'provider_base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerModelMeta = const VerificationMeta(
    'providerModel',
  );
  @override
  late final GeneratedColumn<String> providerModel = GeneratedColumn<String>(
    'provider_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerKeyIdMeta = const VerificationMeta(
    'providerKeyId',
  );
  @override
  late final GeneratedColumn<String> providerKeyId = GeneratedColumn<String>(
    'provider_key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    title,
    mode,
    batchSize,
    isContinuation,
    totalChunks,
    providerName,
    providerBaseUrl,
    providerModel,
    providerKeyId,
    startedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('batch_size')) {
      context.handle(
        _batchSizeMeta,
        batchSize.isAcceptableOrUnknown(data['batch_size']!, _batchSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_batchSizeMeta);
    }
    if (data.containsKey('is_continuation')) {
      context.handle(
        _isContinuationMeta,
        isContinuation.isAcceptableOrUnknown(
          data['is_continuation']!,
          _isContinuationMeta,
        ),
      );
    }
    if (data.containsKey('total_chunks')) {
      context.handle(
        _totalChunksMeta,
        totalChunks.isAcceptableOrUnknown(
          data['total_chunks']!,
          _totalChunksMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalChunksMeta);
    }
    if (data.containsKey('provider_name')) {
      context.handle(
        _providerNameMeta,
        providerName.isAcceptableOrUnknown(
          data['provider_name']!,
          _providerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerNameMeta);
    }
    if (data.containsKey('provider_base_url')) {
      context.handle(
        _providerBaseUrlMeta,
        providerBaseUrl.isAcceptableOrUnknown(
          data['provider_base_url']!,
          _providerBaseUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerBaseUrlMeta);
    }
    if (data.containsKey('provider_model')) {
      context.handle(
        _providerModelMeta,
        providerModel.isAcceptableOrUnknown(
          data['provider_model']!,
          _providerModelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerModelMeta);
    }
    if (data.containsKey('provider_key_id')) {
      context.handle(
        _providerKeyIdMeta,
        providerKeyId.isAcceptableOrUnknown(
          data['provider_key_id']!,
          _providerKeyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerKeyIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId};
  @override
  ScanTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanTask(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      batchSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}batch_size'],
      )!,
      isContinuation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_continuation'],
      )!,
      totalChunks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chunks'],
      )!,
      providerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_name'],
      )!,
      providerBaseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_base_url'],
      )!,
      providerModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_model'],
      )!,
      providerKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_key_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
    );
  }

  @override
  $ScanTasksTable createAlias(String alias) {
    return $ScanTasksTable(attachedDatabase, alias);
  }
}

class ScanTask extends DataClass implements Insertable<ScanTask> {
  final String profileId;
  final String title;
  final String mode;
  final int batchSize;
  final bool isContinuation;
  final int totalChunks;
  final String providerName;
  final String providerBaseUrl;
  final String providerModel;
  final String providerKeyId;
  final DateTime startedAt;
  const ScanTask({
    required this.profileId,
    required this.title,
    required this.mode,
    required this.batchSize,
    required this.isContinuation,
    required this.totalChunks,
    required this.providerName,
    required this.providerBaseUrl,
    required this.providerModel,
    required this.providerKeyId,
    required this.startedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['title'] = Variable<String>(title);
    map['mode'] = Variable<String>(mode);
    map['batch_size'] = Variable<int>(batchSize);
    map['is_continuation'] = Variable<bool>(isContinuation);
    map['total_chunks'] = Variable<int>(totalChunks);
    map['provider_name'] = Variable<String>(providerName);
    map['provider_base_url'] = Variable<String>(providerBaseUrl);
    map['provider_model'] = Variable<String>(providerModel);
    map['provider_key_id'] = Variable<String>(providerKeyId);
    map['started_at'] = Variable<DateTime>(startedAt);
    return map;
  }

  ScanTasksCompanion toCompanion(bool nullToAbsent) {
    return ScanTasksCompanion(
      profileId: Value(profileId),
      title: Value(title),
      mode: Value(mode),
      batchSize: Value(batchSize),
      isContinuation: Value(isContinuation),
      totalChunks: Value(totalChunks),
      providerName: Value(providerName),
      providerBaseUrl: Value(providerBaseUrl),
      providerModel: Value(providerModel),
      providerKeyId: Value(providerKeyId),
      startedAt: Value(startedAt),
    );
  }

  factory ScanTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanTask(
      profileId: serializer.fromJson<String>(json['profileId']),
      title: serializer.fromJson<String>(json['title']),
      mode: serializer.fromJson<String>(json['mode']),
      batchSize: serializer.fromJson<int>(json['batchSize']),
      isContinuation: serializer.fromJson<bool>(json['isContinuation']),
      totalChunks: serializer.fromJson<int>(json['totalChunks']),
      providerName: serializer.fromJson<String>(json['providerName']),
      providerBaseUrl: serializer.fromJson<String>(json['providerBaseUrl']),
      providerModel: serializer.fromJson<String>(json['providerModel']),
      providerKeyId: serializer.fromJson<String>(json['providerKeyId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'title': serializer.toJson<String>(title),
      'mode': serializer.toJson<String>(mode),
      'batchSize': serializer.toJson<int>(batchSize),
      'isContinuation': serializer.toJson<bool>(isContinuation),
      'totalChunks': serializer.toJson<int>(totalChunks),
      'providerName': serializer.toJson<String>(providerName),
      'providerBaseUrl': serializer.toJson<String>(providerBaseUrl),
      'providerModel': serializer.toJson<String>(providerModel),
      'providerKeyId': serializer.toJson<String>(providerKeyId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
    };
  }

  ScanTask copyWith({
    String? profileId,
    String? title,
    String? mode,
    int? batchSize,
    bool? isContinuation,
    int? totalChunks,
    String? providerName,
    String? providerBaseUrl,
    String? providerModel,
    String? providerKeyId,
    DateTime? startedAt,
  }) => ScanTask(
    profileId: profileId ?? this.profileId,
    title: title ?? this.title,
    mode: mode ?? this.mode,
    batchSize: batchSize ?? this.batchSize,
    isContinuation: isContinuation ?? this.isContinuation,
    totalChunks: totalChunks ?? this.totalChunks,
    providerName: providerName ?? this.providerName,
    providerBaseUrl: providerBaseUrl ?? this.providerBaseUrl,
    providerModel: providerModel ?? this.providerModel,
    providerKeyId: providerKeyId ?? this.providerKeyId,
    startedAt: startedAt ?? this.startedAt,
  );
  ScanTask copyWithCompanion(ScanTasksCompanion data) {
    return ScanTask(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      title: data.title.present ? data.title.value : this.title,
      mode: data.mode.present ? data.mode.value : this.mode,
      batchSize: data.batchSize.present ? data.batchSize.value : this.batchSize,
      isContinuation: data.isContinuation.present
          ? data.isContinuation.value
          : this.isContinuation,
      totalChunks: data.totalChunks.present
          ? data.totalChunks.value
          : this.totalChunks,
      providerName: data.providerName.present
          ? data.providerName.value
          : this.providerName,
      providerBaseUrl: data.providerBaseUrl.present
          ? data.providerBaseUrl.value
          : this.providerBaseUrl,
      providerModel: data.providerModel.present
          ? data.providerModel.value
          : this.providerModel,
      providerKeyId: data.providerKeyId.present
          ? data.providerKeyId.value
          : this.providerKeyId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanTask(')
          ..write('profileId: $profileId, ')
          ..write('title: $title, ')
          ..write('mode: $mode, ')
          ..write('batchSize: $batchSize, ')
          ..write('isContinuation: $isContinuation, ')
          ..write('totalChunks: $totalChunks, ')
          ..write('providerName: $providerName, ')
          ..write('providerBaseUrl: $providerBaseUrl, ')
          ..write('providerModel: $providerModel, ')
          ..write('providerKeyId: $providerKeyId, ')
          ..write('startedAt: $startedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    title,
    mode,
    batchSize,
    isContinuation,
    totalChunks,
    providerName,
    providerBaseUrl,
    providerModel,
    providerKeyId,
    startedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanTask &&
          other.profileId == this.profileId &&
          other.title == this.title &&
          other.mode == this.mode &&
          other.batchSize == this.batchSize &&
          other.isContinuation == this.isContinuation &&
          other.totalChunks == this.totalChunks &&
          other.providerName == this.providerName &&
          other.providerBaseUrl == this.providerBaseUrl &&
          other.providerModel == this.providerModel &&
          other.providerKeyId == this.providerKeyId &&
          other.startedAt == this.startedAt);
}

class ScanTasksCompanion extends UpdateCompanion<ScanTask> {
  final Value<String> profileId;
  final Value<String> title;
  final Value<String> mode;
  final Value<int> batchSize;
  final Value<bool> isContinuation;
  final Value<int> totalChunks;
  final Value<String> providerName;
  final Value<String> providerBaseUrl;
  final Value<String> providerModel;
  final Value<String> providerKeyId;
  final Value<DateTime> startedAt;
  final Value<int> rowid;
  const ScanTasksCompanion({
    this.profileId = const Value.absent(),
    this.title = const Value.absent(),
    this.mode = const Value.absent(),
    this.batchSize = const Value.absent(),
    this.isContinuation = const Value.absent(),
    this.totalChunks = const Value.absent(),
    this.providerName = const Value.absent(),
    this.providerBaseUrl = const Value.absent(),
    this.providerModel = const Value.absent(),
    this.providerKeyId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanTasksCompanion.insert({
    required String profileId,
    required String title,
    required String mode,
    required int batchSize,
    this.isContinuation = const Value.absent(),
    required int totalChunks,
    required String providerName,
    required String providerBaseUrl,
    required String providerModel,
    required String providerKeyId,
    required DateTime startedAt,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       title = Value(title),
       mode = Value(mode),
       batchSize = Value(batchSize),
       totalChunks = Value(totalChunks),
       providerName = Value(providerName),
       providerBaseUrl = Value(providerBaseUrl),
       providerModel = Value(providerModel),
       providerKeyId = Value(providerKeyId),
       startedAt = Value(startedAt);
  static Insertable<ScanTask> custom({
    Expression<String>? profileId,
    Expression<String>? title,
    Expression<String>? mode,
    Expression<int>? batchSize,
    Expression<bool>? isContinuation,
    Expression<int>? totalChunks,
    Expression<String>? providerName,
    Expression<String>? providerBaseUrl,
    Expression<String>? providerModel,
    Expression<String>? providerKeyId,
    Expression<DateTime>? startedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (title != null) 'title': title,
      if (mode != null) 'mode': mode,
      if (batchSize != null) 'batch_size': batchSize,
      if (isContinuation != null) 'is_continuation': isContinuation,
      if (totalChunks != null) 'total_chunks': totalChunks,
      if (providerName != null) 'provider_name': providerName,
      if (providerBaseUrl != null) 'provider_base_url': providerBaseUrl,
      if (providerModel != null) 'provider_model': providerModel,
      if (providerKeyId != null) 'provider_key_id': providerKeyId,
      if (startedAt != null) 'started_at': startedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanTasksCompanion copyWith({
    Value<String>? profileId,
    Value<String>? title,
    Value<String>? mode,
    Value<int>? batchSize,
    Value<bool>? isContinuation,
    Value<int>? totalChunks,
    Value<String>? providerName,
    Value<String>? providerBaseUrl,
    Value<String>? providerModel,
    Value<String>? providerKeyId,
    Value<DateTime>? startedAt,
    Value<int>? rowid,
  }) {
    return ScanTasksCompanion(
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      mode: mode ?? this.mode,
      batchSize: batchSize ?? this.batchSize,
      isContinuation: isContinuation ?? this.isContinuation,
      totalChunks: totalChunks ?? this.totalChunks,
      providerName: providerName ?? this.providerName,
      providerBaseUrl: providerBaseUrl ?? this.providerBaseUrl,
      providerModel: providerModel ?? this.providerModel,
      providerKeyId: providerKeyId ?? this.providerKeyId,
      startedAt: startedAt ?? this.startedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (batchSize.present) {
      map['batch_size'] = Variable<int>(batchSize.value);
    }
    if (isContinuation.present) {
      map['is_continuation'] = Variable<bool>(isContinuation.value);
    }
    if (totalChunks.present) {
      map['total_chunks'] = Variable<int>(totalChunks.value);
    }
    if (providerName.present) {
      map['provider_name'] = Variable<String>(providerName.value);
    }
    if (providerBaseUrl.present) {
      map['provider_base_url'] = Variable<String>(providerBaseUrl.value);
    }
    if (providerModel.present) {
      map['provider_model'] = Variable<String>(providerModel.value);
    }
    if (providerKeyId.present) {
      map['provider_key_id'] = Variable<String>(providerKeyId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanTasksCompanion(')
          ..write('profileId: $profileId, ')
          ..write('title: $title, ')
          ..write('mode: $mode, ')
          ..write('batchSize: $batchSize, ')
          ..write('isContinuation: $isContinuation, ')
          ..write('totalChunks: $totalChunks, ')
          ..write('providerName: $providerName, ')
          ..write('providerBaseUrl: $providerBaseUrl, ')
          ..write('providerModel: $providerModel, ')
          ..write('providerKeyId: $providerKeyId, ')
          ..write('startedAt: $startedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanChunksTable extends ScanChunks
    with TableInfo<$ScanChunksTable, ScanChunk> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
    'idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tokensInMeta = const VerificationMeta(
    'tokensIn',
  );
  @override
  late final GeneratedColumn<int> tokensIn = GeneratedColumn<int>(
    'tokens_in',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tokensOutMeta = const VerificationMeta(
    'tokensOut',
  );
  @override
  late final GeneratedColumn<int> tokensOut = GeneratedColumn<int>(
    'tokens_out',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  List<GeneratedColumn> get $columns => [
    profileId,
    idx,
    status,
    payloadJson,
    tokensIn,
    tokensOut,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanChunk> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('idx')) {
      context.handle(
        _idxMeta,
        idx.isAcceptableOrUnknown(data['idx']!, _idxMeta),
      );
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('tokens_in')) {
      context.handle(
        _tokensInMeta,
        tokensIn.isAcceptableOrUnknown(data['tokens_in']!, _tokensInMeta),
      );
    }
    if (data.containsKey('tokens_out')) {
      context.handle(
        _tokensOutMeta,
        tokensOut.isAcceptableOrUnknown(data['tokens_out']!, _tokensOutMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {profileId, idx};
  @override
  ScanChunk map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanChunk(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      idx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idx'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      tokensIn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tokens_in'],
      )!,
      tokensOut: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tokens_out'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ScanChunksTable createAlias(String alias) {
    return $ScanChunksTable(attachedDatabase, alias);
  }
}

class ScanChunk extends DataClass implements Insertable<ScanChunk> {
  final String profileId;
  final int idx;
  final String status;
  final String? payloadJson;
  final int tokensIn;
  final int tokensOut;
  final DateTime updatedAt;
  const ScanChunk({
    required this.profileId,
    required this.idx,
    required this.status,
    this.payloadJson,
    required this.tokensIn,
    required this.tokensOut,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['idx'] = Variable<int>(idx);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['tokens_in'] = Variable<int>(tokensIn);
    map['tokens_out'] = Variable<int>(tokensOut);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScanChunksCompanion toCompanion(bool nullToAbsent) {
    return ScanChunksCompanion(
      profileId: Value(profileId),
      idx: Value(idx),
      status: Value(status),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      tokensIn: Value(tokensIn),
      tokensOut: Value(tokensOut),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScanChunk.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanChunk(
      profileId: serializer.fromJson<String>(json['profileId']),
      idx: serializer.fromJson<int>(json['idx']),
      status: serializer.fromJson<String>(json['status']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      tokensIn: serializer.fromJson<int>(json['tokensIn']),
      tokensOut: serializer.fromJson<int>(json['tokensOut']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'idx': serializer.toJson<int>(idx),
      'status': serializer.toJson<String>(status),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'tokensIn': serializer.toJson<int>(tokensIn),
      'tokensOut': serializer.toJson<int>(tokensOut),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ScanChunk copyWith({
    String? profileId,
    int? idx,
    String? status,
    Value<String?> payloadJson = const Value.absent(),
    int? tokensIn,
    int? tokensOut,
    DateTime? updatedAt,
  }) => ScanChunk(
    profileId: profileId ?? this.profileId,
    idx: idx ?? this.idx,
    status: status ?? this.status,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    tokensIn: tokensIn ?? this.tokensIn,
    tokensOut: tokensOut ?? this.tokensOut,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ScanChunk copyWithCompanion(ScanChunksCompanion data) {
    return ScanChunk(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      idx: data.idx.present ? data.idx.value : this.idx,
      status: data.status.present ? data.status.value : this.status,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      tokensIn: data.tokensIn.present ? data.tokensIn.value : this.tokensIn,
      tokensOut: data.tokensOut.present ? data.tokensOut.value : this.tokensOut,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanChunk(')
          ..write('profileId: $profileId, ')
          ..write('idx: $idx, ')
          ..write('status: $status, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('tokensIn: $tokensIn, ')
          ..write('tokensOut: $tokensOut, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    idx,
    status,
    payloadJson,
    tokensIn,
    tokensOut,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanChunk &&
          other.profileId == this.profileId &&
          other.idx == this.idx &&
          other.status == this.status &&
          other.payloadJson == this.payloadJson &&
          other.tokensIn == this.tokensIn &&
          other.tokensOut == this.tokensOut &&
          other.updatedAt == this.updatedAt);
}

class ScanChunksCompanion extends UpdateCompanion<ScanChunk> {
  final Value<String> profileId;
  final Value<int> idx;
  final Value<String> status;
  final Value<String?> payloadJson;
  final Value<int> tokensIn;
  final Value<int> tokensOut;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ScanChunksCompanion({
    this.profileId = const Value.absent(),
    this.idx = const Value.absent(),
    this.status = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.tokensIn = const Value.absent(),
    this.tokensOut = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanChunksCompanion.insert({
    required String profileId,
    required int idx,
    required String status,
    this.payloadJson = const Value.absent(),
    this.tokensIn = const Value.absent(),
    this.tokensOut = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       idx = Value(idx),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<ScanChunk> custom({
    Expression<String>? profileId,
    Expression<int>? idx,
    Expression<String>? status,
    Expression<String>? payloadJson,
    Expression<int>? tokensIn,
    Expression<int>? tokensOut,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (idx != null) 'idx': idx,
      if (status != null) 'status': status,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (tokensIn != null) 'tokens_in': tokensIn,
      if (tokensOut != null) 'tokens_out': tokensOut,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanChunksCompanion copyWith({
    Value<String>? profileId,
    Value<int>? idx,
    Value<String>? status,
    Value<String?>? payloadJson,
    Value<int>? tokensIn,
    Value<int>? tokensOut,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ScanChunksCompanion(
      profileId: profileId ?? this.profileId,
      idx: idx ?? this.idx,
      status: status ?? this.status,
      payloadJson: payloadJson ?? this.payloadJson,
      tokensIn: tokensIn ?? this.tokensIn,
      tokensOut: tokensOut ?? this.tokensOut,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (tokensIn.present) {
      map['tokens_in'] = Variable<int>(tokensIn.value);
    }
    if (tokensOut.present) {
      map['tokens_out'] = Variable<int>(tokensOut.value);
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
    return (StringBuffer('ScanChunksCompanion(')
          ..write('profileId: $profileId, ')
          ..write('idx: $idx, ')
          ..write('status: $status, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('tokensIn: $tokensIn, ')
          ..write('tokensOut: $tokensOut, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanReducesTable extends ScanReduces
    with TableInfo<$ScanReducesTable, ScanReduce> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanReducesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryTextMeta = const VerificationMeta(
    'summaryText',
  );
  @override
  late final GeneratedColumn<String> summaryText = GeneratedColumn<String>(
    'summary_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [profileId, seq, summaryText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_reduces';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanReduce> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('summary_text')) {
      context.handle(
        _summaryTextMeta,
        summaryText.isAcceptableOrUnknown(
          data['summary_text']!,
          _summaryTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, seq};
  @override
  ScanReduce map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanReduce(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      summaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_text'],
      )!,
    );
  }

  @override
  $ScanReducesTable createAlias(String alias) {
    return $ScanReducesTable(attachedDatabase, alias);
  }
}

class ScanReduce extends DataClass implements Insertable<ScanReduce> {
  final String profileId;
  final int seq;
  final String summaryText;
  const ScanReduce({
    required this.profileId,
    required this.seq,
    required this.summaryText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['seq'] = Variable<int>(seq);
    map['summary_text'] = Variable<String>(summaryText);
    return map;
  }

  ScanReducesCompanion toCompanion(bool nullToAbsent) {
    return ScanReducesCompanion(
      profileId: Value(profileId),
      seq: Value(seq),
      summaryText: Value(summaryText),
    );
  }

  factory ScanReduce.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanReduce(
      profileId: serializer.fromJson<String>(json['profileId']),
      seq: serializer.fromJson<int>(json['seq']),
      summaryText: serializer.fromJson<String>(json['summaryText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'seq': serializer.toJson<int>(seq),
      'summaryText': serializer.toJson<String>(summaryText),
    };
  }

  ScanReduce copyWith({String? profileId, int? seq, String? summaryText}) =>
      ScanReduce(
        profileId: profileId ?? this.profileId,
        seq: seq ?? this.seq,
        summaryText: summaryText ?? this.summaryText,
      );
  ScanReduce copyWithCompanion(ScanReducesCompanion data) {
    return ScanReduce(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      seq: data.seq.present ? data.seq.value : this.seq,
      summaryText: data.summaryText.present
          ? data.summaryText.value
          : this.summaryText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanReduce(')
          ..write('profileId: $profileId, ')
          ..write('seq: $seq, ')
          ..write('summaryText: $summaryText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, seq, summaryText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanReduce &&
          other.profileId == this.profileId &&
          other.seq == this.seq &&
          other.summaryText == this.summaryText);
}

class ScanReducesCompanion extends UpdateCompanion<ScanReduce> {
  final Value<String> profileId;
  final Value<int> seq;
  final Value<String> summaryText;
  final Value<int> rowid;
  const ScanReducesCompanion({
    this.profileId = const Value.absent(),
    this.seq = const Value.absent(),
    this.summaryText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanReducesCompanion.insert({
    required String profileId,
    required int seq,
    required String summaryText,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       seq = Value(seq),
       summaryText = Value(summaryText);
  static Insertable<ScanReduce> custom({
    Expression<String>? profileId,
    Expression<int>? seq,
    Expression<String>? summaryText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (seq != null) 'seq': seq,
      if (summaryText != null) 'summary_text': summaryText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanReducesCompanion copyWith({
    Value<String>? profileId,
    Value<int>? seq,
    Value<String>? summaryText,
    Value<int>? rowid,
  }) {
    return ScanReducesCompanion(
      profileId: profileId ?? this.profileId,
      seq: seq ?? this.seq,
      summaryText: summaryText ?? this.summaryText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (summaryText.present) {
      map['summary_text'] = Variable<String>(summaryText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanReducesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('seq: $seq, ')
          ..write('summaryText: $summaryText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanMetasTable extends ScanMetas
    with TableInfo<$ScanMetasTable, ScanMeta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanMetasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metaKeyMeta = const VerificationMeta(
    'metaKey',
  );
  @override
  late final GeneratedColumn<String> metaKey = GeneratedColumn<String>(
    'meta_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metaValueMeta = const VerificationMeta(
    'metaValue',
  );
  @override
  late final GeneratedColumn<int> metaValue = GeneratedColumn<int>(
    'meta_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [profileId, metaKey, metaValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_metas';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanMeta> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('meta_key')) {
      context.handle(
        _metaKeyMeta,
        metaKey.isAcceptableOrUnknown(data['meta_key']!, _metaKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_metaKeyMeta);
    }
    if (data.containsKey('meta_value')) {
      context.handle(
        _metaValueMeta,
        metaValue.isAcceptableOrUnknown(data['meta_value']!, _metaValueMeta),
      );
    } else if (isInserting) {
      context.missing(_metaValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, metaKey};
  @override
  ScanMeta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanMeta(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      metaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_key'],
      )!,
      metaValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meta_value'],
      )!,
    );
  }

  @override
  $ScanMetasTable createAlias(String alias) {
    return $ScanMetasTable(attachedDatabase, alias);
  }
}

class ScanMeta extends DataClass implements Insertable<ScanMeta> {
  final String profileId;
  final String metaKey;
  final int metaValue;
  const ScanMeta({
    required this.profileId,
    required this.metaKey,
    required this.metaValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['meta_key'] = Variable<String>(metaKey);
    map['meta_value'] = Variable<int>(metaValue);
    return map;
  }

  ScanMetasCompanion toCompanion(bool nullToAbsent) {
    return ScanMetasCompanion(
      profileId: Value(profileId),
      metaKey: Value(metaKey),
      metaValue: Value(metaValue),
    );
  }

  factory ScanMeta.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanMeta(
      profileId: serializer.fromJson<String>(json['profileId']),
      metaKey: serializer.fromJson<String>(json['metaKey']),
      metaValue: serializer.fromJson<int>(json['metaValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'metaKey': serializer.toJson<String>(metaKey),
      'metaValue': serializer.toJson<int>(metaValue),
    };
  }

  ScanMeta copyWith({String? profileId, String? metaKey, int? metaValue}) =>
      ScanMeta(
        profileId: profileId ?? this.profileId,
        metaKey: metaKey ?? this.metaKey,
        metaValue: metaValue ?? this.metaValue,
      );
  ScanMeta copyWithCompanion(ScanMetasCompanion data) {
    return ScanMeta(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      metaKey: data.metaKey.present ? data.metaKey.value : this.metaKey,
      metaValue: data.metaValue.present ? data.metaValue.value : this.metaValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanMeta(')
          ..write('profileId: $profileId, ')
          ..write('metaKey: $metaKey, ')
          ..write('metaValue: $metaValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, metaKey, metaValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanMeta &&
          other.profileId == this.profileId &&
          other.metaKey == this.metaKey &&
          other.metaValue == this.metaValue);
}

class ScanMetasCompanion extends UpdateCompanion<ScanMeta> {
  final Value<String> profileId;
  final Value<String> metaKey;
  final Value<int> metaValue;
  final Value<int> rowid;
  const ScanMetasCompanion({
    this.profileId = const Value.absent(),
    this.metaKey = const Value.absent(),
    this.metaValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanMetasCompanion.insert({
    required String profileId,
    required String metaKey,
    required int metaValue,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       metaKey = Value(metaKey),
       metaValue = Value(metaValue);
  static Insertable<ScanMeta> custom({
    Expression<String>? profileId,
    Expression<String>? metaKey,
    Expression<int>? metaValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (metaKey != null) 'meta_key': metaKey,
      if (metaValue != null) 'meta_value': metaValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanMetasCompanion copyWith({
    Value<String>? profileId,
    Value<String>? metaKey,
    Value<int>? metaValue,
    Value<int>? rowid,
  }) {
    return ScanMetasCompanion(
      profileId: profileId ?? this.profileId,
      metaKey: metaKey ?? this.metaKey,
      metaValue: metaValue ?? this.metaValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (metaKey.present) {
      map['meta_key'] = Variable<String>(metaKey.value);
    }
    if (metaValue.present) {
      map['meta_value'] = Variable<int>(metaValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanMetasCompanion(')
          ..write('profileId: $profileId, ')
          ..write('metaKey: $metaKey, ')
          ..write('metaValue: $metaValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NovelsTable novels = $NovelsTable(this);
  late final $VolumesTable volumes = $VolumesTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $ChapterSummariesTable chapterSummaries = $ChapterSummariesTable(
    this,
  );
  late final $ChapterSnapshotsTable chapterSnapshots = $ChapterSnapshotsTable(
    this,
  );
  late final $CharactersTable characters = $CharactersTable(this);
  late final $WorldEntriesTable worldEntries = $WorldEntriesTable(this);
  late final $ForeshadowingsTable foreshadowings = $ForeshadowingsTable(this);
  late final $ChatThreadsTable chatThreads = $ChatThreadsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $ProvidersTable providers = $ProvidersTable(this);
  late final $StyleProfilesTable styleProfiles = $StyleProfilesTable(this);
  late final $SourceProfilesTable sourceProfiles = $SourceProfilesTable(this);
  late final $PromptOverridesTable promptOverrides = $PromptOverridesTable(
    this,
  );
  late final $PromptTagCategoriesTable promptTagCategories =
      $PromptTagCategoriesTable(this);
  late final $CreationSessionCachesTable creationSessionCaches =
      $CreationSessionCachesTable(this);
  late final $StyleDistillCachesTable styleDistillCaches =
      $StyleDistillCachesTable(this);
  late final $ScanTasksTable scanTasks = $ScanTasksTable(this);
  late final $ScanChunksTable scanChunks = $ScanChunksTable(this);
  late final $ScanReducesTable scanReduces = $ScanReducesTable(this);
  late final $ScanMetasTable scanMetas = $ScanMetasTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    novels,
    volumes,
    chapters,
    chapterSummaries,
    chapterSnapshots,
    characters,
    worldEntries,
    foreshadowings,
    chatThreads,
    chatMessages,
    providers,
    styleProfiles,
    sourceProfiles,
    promptOverrides,
    promptTagCategories,
    creationSessionCaches,
    styleDistillCaches,
    scanTasks,
    scanChunks,
    scanReduces,
    scanMetas,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'novels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('volumes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'volumes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chapters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chapters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chapter_summaries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chapters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chapter_snapshots', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'novels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('characters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'novels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('world_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'novels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('foreshadowings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'novels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chat_threads', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_threads',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chat_messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_threads',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('creation_session_caches', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$NovelsTableCreateCompanionBuilder = NovelsCompanion Function({
  required String id,
  required String title,
  Value<String> synopsis,
  Value<String?> genre,
  Value<String?> perspective,
  Value<String?> styleGuide,
  Value<String?> accentColorHex,
  Value<String> enabledTagIdsJson,
  Value<bool> r18Enabled,
  Value<String?> activeStyleProfileId,
  Value<String?> sourceProfileId,
  Value<DateTime?> lastStatsDate,
  Value<int> lastTotalWordCount,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$NovelsTableUpdateCompanionBuilder = NovelsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> synopsis,
  Value<String?> genre,
  Value<String?> perspective,
  Value<String?> styleGuide,
  Value<String?> accentColorHex,
  Value<String> enabledTagIdsJson,
  Value<bool> r18Enabled,
  Value<String?> activeStyleProfileId,
  Value<String?> sourceProfileId,
  Value<DateTime?> lastStatsDate,
  Value<int> lastTotalWordCount,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$NovelsTableReferences
    extends BaseReferences<_$AppDatabase, $NovelsTable, Novel> {
  $$NovelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VolumesTable, List<Volume>> _volumesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.volumes,
    aliasName: 'novels__id__volumes__novel_id',
  );

  $$VolumesTableProcessedTableManager get volumesRefs {
    final manager = $$VolumesTableTableManager(
      $_db,
      $_db.volumes,
    ).filter((f) => f.novelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_volumesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CharactersTable, List<Character>>
  _charactersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.characters,
    aliasName: 'novels__id__characters__novel_id',
  );

  $$CharactersTableProcessedTableManager get charactersRefs {
    final manager = $$CharactersTableTableManager(
      $_db,
      $_db.characters,
    ).filter((f) => f.novelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_charactersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorldEntriesTable, List<WorldEntry>>
  _worldEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.worldEntries,
    aliasName: 'novels__id__world_entries__novel_id',
  );

  $$WorldEntriesTableProcessedTableManager get worldEntriesRefs {
    final manager = $$WorldEntriesTableTableManager(
      $_db,
      $_db.worldEntries,
    ).filter((f) => f.novelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_worldEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ForeshadowingsTable, List<Foreshadowing>>
  _foreshadowingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.foreshadowings,
    aliasName: 'novels__id__foreshadowings__novel_id',
  );

  $$ForeshadowingsTableProcessedTableManager get foreshadowingsRefs {
    final manager = $$ForeshadowingsTableTableManager(
      $_db,
      $_db.foreshadowings,
    ).filter((f) => f.novelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_foreshadowingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChatThreadsTable, List<ChatThread>>
  _chatThreadsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.chatThreads,
    aliasName: 'novels__id__chat_threads__novel_id',
  );

  $$ChatThreadsTableProcessedTableManager get chatThreadsRefs {
    final manager = $$ChatThreadsTableTableManager(
      $_db,
      $_db.chatThreads,
    ).filter((f) => f.novelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_chatThreadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NovelsTableFilterComposer
    extends Composer<_$AppDatabase, $NovelsTable> {
  $$NovelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get synopsis => $composableBuilder(
    column: $table.synopsis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get perspective => $composableBuilder(
    column: $table.perspective,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get styleGuide => $composableBuilder(
    column: $table.styleGuide,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accentColorHex => $composableBuilder(
    column: $table.accentColorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabledTagIdsJson => $composableBuilder(
    column: $table.enabledTagIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get r18Enabled => $composableBuilder(
    column: $table.r18Enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeStyleProfileId => $composableBuilder(
    column: $table.activeStyleProfileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceProfileId => $composableBuilder(
    column: $table.sourceProfileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastStatsDate => $composableBuilder(
    column: $table.lastStatsDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTotalWordCount => $composableBuilder(
    column: $table.lastTotalWordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> volumesRefs(
    Expression<bool> Function($$VolumesTableFilterComposer f) f,
  ) {
    final $$VolumesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.volumes,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VolumesTableFilterComposer(
            $db: $db,
            $table: $db.volumes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> charactersRefs(
    Expression<bool> Function($$CharactersTableFilterComposer f) f,
  ) {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableFilterComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> worldEntriesRefs(
    Expression<bool> Function($$WorldEntriesTableFilterComposer f) f,
  ) {
    final $$WorldEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.worldEntries,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldEntriesTableFilterComposer(
            $db: $db,
            $table: $db.worldEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> foreshadowingsRefs(
    Expression<bool> Function($$ForeshadowingsTableFilterComposer f) f,
  ) {
    final $$ForeshadowingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foreshadowings,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ForeshadowingsTableFilterComposer(
            $db: $db,
            $table: $db.foreshadowings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> chatThreadsRefs(
    Expression<bool> Function($$ChatThreadsTableFilterComposer f) f,
  ) {
    final $$ChatThreadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chatThreads,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatThreadsTableFilterComposer(
            $db: $db,
            $table: $db.chatThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NovelsTableOrderingComposer
    extends Composer<_$AppDatabase, $NovelsTable> {
  $$NovelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get synopsis => $composableBuilder(
    column: $table.synopsis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get perspective => $composableBuilder(
    column: $table.perspective,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get styleGuide => $composableBuilder(
    column: $table.styleGuide,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accentColorHex => $composableBuilder(
    column: $table.accentColorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabledTagIdsJson => $composableBuilder(
    column: $table.enabledTagIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get r18Enabled => $composableBuilder(
    column: $table.r18Enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeStyleProfileId => $composableBuilder(
    column: $table.activeStyleProfileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceProfileId => $composableBuilder(
    column: $table.sourceProfileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastStatsDate => $composableBuilder(
    column: $table.lastStatsDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTotalWordCount => $composableBuilder(
    column: $table.lastTotalWordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NovelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NovelsTable> {
  $$NovelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get synopsis =>
      $composableBuilder(column: $table.synopsis, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get perspective => $composableBuilder(
    column: $table.perspective,
    builder: (column) => column,
  );

  GeneratedColumn<String> get styleGuide => $composableBuilder(
    column: $table.styleGuide,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accentColorHex => $composableBuilder(
    column: $table.accentColorHex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enabledTagIdsJson => $composableBuilder(
    column: $table.enabledTagIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get r18Enabled => $composableBuilder(
    column: $table.r18Enabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeStyleProfileId => $composableBuilder(
    column: $table.activeStyleProfileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceProfileId => $composableBuilder(
    column: $table.sourceProfileId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastStatsDate => $composableBuilder(
    column: $table.lastStatsDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastTotalWordCount => $composableBuilder(
    column: $table.lastTotalWordCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> volumesRefs<T extends Object>(
    Expression<T> Function($$VolumesTableAnnotationComposer a) f,
  ) {
    final $$VolumesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.volumes,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VolumesTableAnnotationComposer(
            $db: $db,
            $table: $db.volumes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> charactersRefs<T extends Object>(
    Expression<T> Function($$CharactersTableAnnotationComposer a) f,
  ) {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> worldEntriesRefs<T extends Object>(
    Expression<T> Function($$WorldEntriesTableAnnotationComposer a) f,
  ) {
    final $$WorldEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.worldEntries,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.worldEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> foreshadowingsRefs<T extends Object>(
    Expression<T> Function($$ForeshadowingsTableAnnotationComposer a) f,
  ) {
    final $$ForeshadowingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foreshadowings,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ForeshadowingsTableAnnotationComposer(
            $db: $db,
            $table: $db.foreshadowings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> chatThreadsRefs<T extends Object>(
    Expression<T> Function($$ChatThreadsTableAnnotationComposer a) f,
  ) {
    final $$ChatThreadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chatThreads,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatThreadsTableAnnotationComposer(
            $db: $db,
            $table: $db.chatThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NovelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NovelsTable,
          Novel,
          $$NovelsTableFilterComposer,
          $$NovelsTableOrderingComposer,
          $$NovelsTableAnnotationComposer,
          $$NovelsTableCreateCompanionBuilder,
          $$NovelsTableUpdateCompanionBuilder,
          (Novel, $$NovelsTableReferences),
          Novel,
          PrefetchHooks Function({
            bool volumesRefs,
            bool charactersRefs,
            bool worldEntriesRefs,
            bool foreshadowingsRefs,
            bool chatThreadsRefs,
          })
        > {
  $$NovelsTableTableManager(_$AppDatabase db, $NovelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NovelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NovelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NovelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> synopsis = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> perspective = const Value.absent(),
                Value<String?> styleGuide = const Value.absent(),
                Value<String?> accentColorHex = const Value.absent(),
                Value<String> enabledTagIdsJson = const Value.absent(),
                Value<bool> r18Enabled = const Value.absent(),
                Value<String?> activeStyleProfileId = const Value.absent(),
                Value<String?> sourceProfileId = const Value.absent(),
                Value<DateTime?> lastStatsDate = const Value.absent(),
                Value<int> lastTotalWordCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NovelsCompanion(
                id: id,
                title: title,
                synopsis: synopsis,
                genre: genre,
                perspective: perspective,
                styleGuide: styleGuide,
                accentColorHex: accentColorHex,
                enabledTagIdsJson: enabledTagIdsJson,
                r18Enabled: r18Enabled,
                activeStyleProfileId: activeStyleProfileId,
                sourceProfileId: sourceProfileId,
                lastStatsDate: lastStatsDate,
                lastTotalWordCount: lastTotalWordCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> synopsis = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> perspective = const Value.absent(),
                Value<String?> styleGuide = const Value.absent(),
                Value<String?> accentColorHex = const Value.absent(),
                Value<String> enabledTagIdsJson = const Value.absent(),
                Value<bool> r18Enabled = const Value.absent(),
                Value<String?> activeStyleProfileId = const Value.absent(),
                Value<String?> sourceProfileId = const Value.absent(),
                Value<DateTime?> lastStatsDate = const Value.absent(),
                Value<int> lastTotalWordCount = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NovelsCompanion.insert(
                id: id,
                title: title,
                synopsis: synopsis,
                genre: genre,
                perspective: perspective,
                styleGuide: styleGuide,
                accentColorHex: accentColorHex,
                enabledTagIdsJson: enabledTagIdsJson,
                r18Enabled: r18Enabled,
                activeStyleProfileId: activeStyleProfileId,
                sourceProfileId: sourceProfileId,
                lastStatsDate: lastStatsDate,
                lastTotalWordCount: lastTotalWordCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NovelsTable, Novel>(table),
                  $$NovelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                volumesRefs = false,
                charactersRefs = false,
                worldEntriesRefs = false,
                foreshadowingsRefs = false,
                chatThreadsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (volumesRefs) db.volumes,
                    if (charactersRefs) db.characters,
                    if (worldEntriesRefs) db.worldEntries,
                    if (foreshadowingsRefs) db.foreshadowings,
                    if (chatThreadsRefs) db.chatThreads,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (volumesRefs)
                        await $_getPrefetchedDataByColumns<
                          Novel,
                          $NovelsTable,
                          Volume,
                          $VolumesTable
                        >(
                          currentTable: table,
                          referencedTable: $$NovelsTableReferences
                              ._volumesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NovelsTableReferences(
                                db,
                                table,
                                p0,
                              ).volumesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'novel_id',
                          typedResults: items,
                        ),
                      if (charactersRefs)
                        await $_getPrefetchedDataByColumns<
                          Novel,
                          $NovelsTable,
                          Character,
                          $CharactersTable
                        >(
                          currentTable: table,
                          referencedTable: $$NovelsTableReferences
                              ._charactersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NovelsTableReferences(
                                db,
                                table,
                                p0,
                              ).charactersRefs,
                          currentColumn: 'id',
                          referencedColumn: 'novel_id',
                          typedResults: items,
                        ),
                      if (worldEntriesRefs)
                        await $_getPrefetchedDataByColumns<
                          Novel,
                          $NovelsTable,
                          WorldEntry,
                          $WorldEntriesTable
                        >(
                          currentTable: table,
                          referencedTable: $$NovelsTableReferences
                              ._worldEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NovelsTableReferences(
                                db,
                                table,
                                p0,
                              ).worldEntriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'novel_id',
                          typedResults: items,
                        ),
                      if (foreshadowingsRefs)
                        await $_getPrefetchedDataByColumns<
                          Novel,
                          $NovelsTable,
                          Foreshadowing,
                          $ForeshadowingsTable
                        >(
                          currentTable: table,
                          referencedTable: $$NovelsTableReferences
                              ._foreshadowingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NovelsTableReferences(
                                db,
                                table,
                                p0,
                              ).foreshadowingsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'novel_id',
                          typedResults: items,
                        ),
                      if (chatThreadsRefs)
                        await $_getPrefetchedDataByColumns<
                          Novel,
                          $NovelsTable,
                          ChatThread,
                          $ChatThreadsTable
                        >(
                          currentTable: table,
                          referencedTable: $$NovelsTableReferences
                              ._chatThreadsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NovelsTableReferences(
                                db,
                                table,
                                p0,
                              ).chatThreadsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'novel_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NovelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NovelsTable,
      Novel,
      $$NovelsTableFilterComposer,
      $$NovelsTableOrderingComposer,
      $$NovelsTableAnnotationComposer,
      $$NovelsTableCreateCompanionBuilder,
      $$NovelsTableUpdateCompanionBuilder,
      (Novel, $$NovelsTableReferences),
      Novel,
      PrefetchHooks Function({
        bool volumesRefs,
        bool charactersRefs,
        bool worldEntriesRefs,
        bool foreshadowingsRefs,
        bool chatThreadsRefs,
      })
    >;
typedef $$VolumesTableCreateCompanionBuilder = VolumesCompanion Function({
  required String id,
  required String novelId,
  required String name,
  Value<String?> outline,
  Value<String?> emotionArcJson,
  Value<String?> conflictLadderJson,
  Value<String?> infoGapJson,
  required int sortOrder,
  Value<int> rowid,
});
typedef $$VolumesTableUpdateCompanionBuilder = VolumesCompanion Function({
  Value<String> id,
  Value<String> novelId,
  Value<String> name,
  Value<String?> outline,
  Value<String?> emotionArcJson,
  Value<String?> conflictLadderJson,
  Value<String?> infoGapJson,
  Value<int> sortOrder,
  Value<int> rowid,
});

final class $$VolumesTableReferences
    extends BaseReferences<_$AppDatabase, $VolumesTable, Volume> {
  $$VolumesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NovelsTable _novelIdTable(_$AppDatabase db) =>
      db.novels.createAlias('volumes__novel_id__novels__id');

  $$NovelsTableProcessedTableManager get novelId {
    final $_column = $_itemColumn<String>('novel_id')!;

    final manager = $$NovelsTableTableManager(
      $_db,
      $_db.novels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_novelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ChaptersTable, List<Chapter>> _chaptersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.chapters,
    aliasName: 'volumes__id__chapters__volume_id',
  );

  $$ChaptersTableProcessedTableManager get chaptersRefs {
    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.volumeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_chaptersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VolumesTableFilterComposer
    extends Composer<_$AppDatabase, $VolumesTable> {
  $$VolumesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outline => $composableBuilder(
    column: $table.outline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emotionArcJson => $composableBuilder(
    column: $table.emotionArcJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictLadderJson => $composableBuilder(
    column: $table.conflictLadderJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get infoGapJson => $composableBuilder(
    column: $table.infoGapJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$NovelsTableFilterComposer get novelId {
    final $$NovelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableFilterComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> chaptersRefs(
    Expression<bool> Function($$ChaptersTableFilterComposer f) f,
  ) {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.volumeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VolumesTableOrderingComposer
    extends Composer<_$AppDatabase, $VolumesTable> {
  $$VolumesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outline => $composableBuilder(
    column: $table.outline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emotionArcJson => $composableBuilder(
    column: $table.emotionArcJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictLadderJson => $composableBuilder(
    column: $table.conflictLadderJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get infoGapJson => $composableBuilder(
    column: $table.infoGapJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$NovelsTableOrderingComposer get novelId {
    final $$NovelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableOrderingComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VolumesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VolumesTable> {
  $$VolumesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get outline =>
      $composableBuilder(column: $table.outline, builder: (column) => column);

  GeneratedColumn<String> get emotionArcJson => $composableBuilder(
    column: $table.emotionArcJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictLadderJson => $composableBuilder(
    column: $table.conflictLadderJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get infoGapJson => $composableBuilder(
    column: $table.infoGapJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$NovelsTableAnnotationComposer get novelId {
    final $$NovelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableAnnotationComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> chaptersRefs<T extends Object>(
    Expression<T> Function($$ChaptersTableAnnotationComposer a) f,
  ) {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.volumeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VolumesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VolumesTable,
          Volume,
          $$VolumesTableFilterComposer,
          $$VolumesTableOrderingComposer,
          $$VolumesTableAnnotationComposer,
          $$VolumesTableCreateCompanionBuilder,
          $$VolumesTableUpdateCompanionBuilder,
          (Volume, $$VolumesTableReferences),
          Volume,
          PrefetchHooks Function({bool novelId, bool chaptersRefs})
        > {
  $$VolumesTableTableManager(_$AppDatabase db, $VolumesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VolumesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VolumesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VolumesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> novelId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> outline = const Value.absent(),
                Value<String?> emotionArcJson = const Value.absent(),
                Value<String?> conflictLadderJson = const Value.absent(),
                Value<String?> infoGapJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VolumesCompanion(
                id: id,
                novelId: novelId,
                name: name,
                outline: outline,
                emotionArcJson: emotionArcJson,
                conflictLadderJson: conflictLadderJson,
                infoGapJson: infoGapJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String novelId,
                required String name,
                Value<String?> outline = const Value.absent(),
                Value<String?> emotionArcJson = const Value.absent(),
                Value<String?> conflictLadderJson = const Value.absent(),
                Value<String?> infoGapJson = const Value.absent(),
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => VolumesCompanion.insert(
                id: id,
                novelId: novelId,
                name: name,
                outline: outline,
                emotionArcJson: emotionArcJson,
                conflictLadderJson: conflictLadderJson,
                infoGapJson: infoGapJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VolumesTable, Volume>(table),
                  $$VolumesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({novelId = false, chaptersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (chaptersRefs) db.chapters],
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
                    if (novelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.novelId,
                        referencedTable: $$VolumesTableReferences._novelIdTable(
                          db,
                        ),
                        referencedColumn: $$VolumesTableReferences
                            ._novelIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (chaptersRefs)
                    await $_getPrefetchedDataByColumns<
                      Volume,
                      $VolumesTable,
                      Chapter,
                      $ChaptersTable
                    >(
                      currentTable: table,
                      referencedTable: $$VolumesTableReferences
                          ._chaptersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$VolumesTableReferences(db, table, p0).chaptersRefs,
                      currentColumn: 'id',
                      referencedColumn: 'volume_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$VolumesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VolumesTable,
      Volume,
      $$VolumesTableFilterComposer,
      $$VolumesTableOrderingComposer,
      $$VolumesTableAnnotationComposer,
      $$VolumesTableCreateCompanionBuilder,
      $$VolumesTableUpdateCompanionBuilder,
      (Volume, $$VolumesTableReferences),
      Volume,
      PrefetchHooks Function({bool novelId, bool chaptersRefs})
    >;
typedef $$ChaptersTableCreateCompanionBuilder = ChaptersCompanion Function({
  required String id,
  required String volumeId,
  required String title,
  Value<String?> detailedOutline,
  Value<String?> sceneCardsJson,
  Value<String> content,
  required int sortOrder,
  Value<int> wordCount,
  Value<bool> isOriginal,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ChaptersTableUpdateCompanionBuilder = ChaptersCompanion Function({
  Value<String> id,
  Value<String> volumeId,
  Value<String> title,
  Value<String?> detailedOutline,
  Value<String?> sceneCardsJson,
  Value<String> content,
  Value<int> sortOrder,
  Value<int> wordCount,
  Value<bool> isOriginal,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ChaptersTableReferences
    extends BaseReferences<_$AppDatabase, $ChaptersTable, Chapter> {
  $$ChaptersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VolumesTable _volumeIdTable(_$AppDatabase db) =>
      db.volumes.createAlias('chapters__volume_id__volumes__id');

  $$VolumesTableProcessedTableManager get volumeId {
    final $_column = $_itemColumn<String>('volume_id')!;

    final manager = $$VolumesTableTableManager(
      $_db,
      $_db.volumes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_volumeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ChapterSummariesTable, List<ChapterSummary>>
  _chapterSummariesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.chapterSummaries,
    aliasName: 'chapters__id__chapter_summaries__chapter_id',
  );

  $$ChapterSummariesTableProcessedTableManager get chapterSummariesRefs {
    final manager = $$ChapterSummariesTableTableManager(
      $_db,
      $_db.chapterSummaries,
    ).filter((f) => f.chapterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _chapterSummariesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChapterSnapshotsTable, List<ChapterSnapshot>>
  _chapterSnapshotsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.chapterSnapshots,
    aliasName: 'chapters__id__chapter_snapshots__chapter_id',
  );

  $$ChapterSnapshotsTableProcessedTableManager get chapterSnapshotsRefs {
    final manager = $$ChapterSnapshotsTableTableManager(
      $_db,
      $_db.chapterSnapshots,
    ).filter((f) => f.chapterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _chapterSnapshotsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailedOutline => $composableBuilder(
    column: $table.detailedOutline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sceneCardsJson => $composableBuilder(
    column: $table.sceneCardsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOriginal => $composableBuilder(
    column: $table.isOriginal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VolumesTableFilterComposer get volumeId {
    final $$VolumesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.volumeId,
      referencedTable: $db.volumes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VolumesTableFilterComposer(
            $db: $db,
            $table: $db.volumes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> chapterSummariesRefs(
    Expression<bool> Function($$ChapterSummariesTableFilterComposer f) f,
  ) {
    final $$ChapterSummariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapterSummaries,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChapterSummariesTableFilterComposer(
            $db: $db,
            $table: $db.chapterSummaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> chapterSnapshotsRefs(
    Expression<bool> Function($$ChapterSnapshotsTableFilterComposer f) f,
  ) {
    final $$ChapterSnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapterSnapshots,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChapterSnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.chapterSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailedOutline => $composableBuilder(
    column: $table.detailedOutline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sceneCardsJson => $composableBuilder(
    column: $table.sceneCardsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOriginal => $composableBuilder(
    column: $table.isOriginal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VolumesTableOrderingComposer get volumeId {
    final $$VolumesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.volumeId,
      referencedTable: $db.volumes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VolumesTableOrderingComposer(
            $db: $db,
            $table: $db.volumes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get detailedOutline => $composableBuilder(
    column: $table.detailedOutline,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sceneCardsJson => $composableBuilder(
    column: $table.sceneCardsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<bool> get isOriginal => $composableBuilder(
    column: $table.isOriginal,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$VolumesTableAnnotationComposer get volumeId {
    final $$VolumesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.volumeId,
      referencedTable: $db.volumes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VolumesTableAnnotationComposer(
            $db: $db,
            $table: $db.volumes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> chapterSummariesRefs<T extends Object>(
    Expression<T> Function($$ChapterSummariesTableAnnotationComposer a) f,
  ) {
    final $$ChapterSummariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapterSummaries,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChapterSummariesTableAnnotationComposer(
            $db: $db,
            $table: $db.chapterSummaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> chapterSnapshotsRefs<T extends Object>(
    Expression<T> Function($$ChapterSnapshotsTableAnnotationComposer a) f,
  ) {
    final $$ChapterSnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapterSnapshots,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChapterSnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.chapterSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          Chapter,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (Chapter, $$ChaptersTableReferences),
          Chapter,
          PrefetchHooks Function({
            bool volumeId,
            bool chapterSummariesRefs,
            bool chapterSnapshotsRefs,
          })
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> volumeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> detailedOutline = const Value.absent(),
                Value<String?> sceneCardsJson = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<bool> isOriginal = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                volumeId: volumeId,
                title: title,
                detailedOutline: detailedOutline,
                sceneCardsJson: sceneCardsJson,
                content: content,
                sortOrder: sortOrder,
                wordCount: wordCount,
                isOriginal: isOriginal,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String volumeId,
                required String title,
                Value<String?> detailedOutline = const Value.absent(),
                Value<String?> sceneCardsJson = const Value.absent(),
                Value<String> content = const Value.absent(),
                required int sortOrder,
                Value<int> wordCount = const Value.absent(),
                Value<bool> isOriginal = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion.insert(
                id: id,
                volumeId: volumeId,
                title: title,
                detailedOutline: detailedOutline,
                sceneCardsJson: sceneCardsJson,
                content: content,
                sortOrder: sortOrder,
                wordCount: wordCount,
                isOriginal: isOriginal,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChaptersTable, Chapter>(table),
                  $$ChaptersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                volumeId = false,
                chapterSummariesRefs = false,
                chapterSnapshotsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (chapterSummariesRefs) db.chapterSummaries,
                    if (chapterSnapshotsRefs) db.chapterSnapshots,
                  ],
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
                        if (volumeId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.volumeId,
                            referencedTable: $$ChaptersTableReferences
                                ._volumeIdTable(db),
                            referencedColumn: $$ChaptersTableReferences
                                ._volumeIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (chapterSummariesRefs)
                        await $_getPrefetchedDataByColumns<
                          Chapter,
                          $ChaptersTable,
                          ChapterSummary,
                          $ChapterSummariesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ChaptersTableReferences
                              ._chapterSummariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChaptersTableReferences(
                                db,
                                table,
                                p0,
                              ).chapterSummariesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'chapter_id',
                          typedResults: items,
                        ),
                      if (chapterSnapshotsRefs)
                        await $_getPrefetchedDataByColumns<
                          Chapter,
                          $ChaptersTable,
                          ChapterSnapshot,
                          $ChapterSnapshotsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ChaptersTableReferences
                              ._chapterSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChaptersTableReferences(
                                db,
                                table,
                                p0,
                              ).chapterSnapshotsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'chapter_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      Chapter,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (Chapter, $$ChaptersTableReferences),
      Chapter,
      PrefetchHooks Function({
        bool volumeId,
        bool chapterSummariesRefs,
        bool chapterSnapshotsRefs,
      })
    >;
typedef $$ChapterSummariesTableCreateCompanionBuilder =
    ChapterSummariesCompanion Function({
      required String chapterId,
      required String summaryText,
      Value<String> keyFactsJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ChapterSummariesTableUpdateCompanionBuilder =
    ChapterSummariesCompanion Function({
      Value<String> chapterId,
      Value<String> summaryText,
      Value<String> keyFactsJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ChapterSummariesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ChapterSummariesTable, ChapterSummary> {
  $$ChapterSummariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('chapter_summaries__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager get chapterId {
    final $_column = $_itemColumn<String>('chapter_id')!;

    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChapterSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $ChapterSummariesTable> {
  $$ChapterSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyFactsJson => $composableBuilder(
    column: $table.keyFactsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChapterSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChapterSummariesTable> {
  $$ChapterSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyFactsJson => $composableBuilder(
    column: $table.keyFactsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableOrderingComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChapterSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChapterSummariesTable> {
  $$ChapterSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keyFactsJson => $composableBuilder(
    column: $table.keyFactsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChapterSummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChapterSummariesTable,
          ChapterSummary,
          $$ChapterSummariesTableFilterComposer,
          $$ChapterSummariesTableOrderingComposer,
          $$ChapterSummariesTableAnnotationComposer,
          $$ChapterSummariesTableCreateCompanionBuilder,
          $$ChapterSummariesTableUpdateCompanionBuilder,
          (ChapterSummary, $$ChapterSummariesTableReferences),
          ChapterSummary,
          PrefetchHooks Function({bool chapterId})
        > {
  $$ChapterSummariesTableTableManager(
    _$AppDatabase db,
    $ChapterSummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChapterSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChapterSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChapterSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> chapterId = const Value.absent(),
                Value<String> summaryText = const Value.absent(),
                Value<String> keyFactsJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChapterSummariesCompanion(
                chapterId: chapterId,
                summaryText: summaryText,
                keyFactsJson: keyFactsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chapterId,
                required String summaryText,
                Value<String> keyFactsJson = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ChapterSummariesCompanion.insert(
                chapterId: chapterId,
                summaryText: summaryText,
                keyFactsJson: keyFactsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChapterSummariesTable, ChapterSummary>(table),
                  $$ChapterSummariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({chapterId = false}) {
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
                    if (chapterId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.chapterId,
                        referencedTable: $$ChapterSummariesTableReferences
                            ._chapterIdTable(db),
                        referencedColumn: $$ChapterSummariesTableReferences
                            ._chapterIdTable(db)
                            .id,
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

typedef $$ChapterSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChapterSummariesTable,
      ChapterSummary,
      $$ChapterSummariesTableFilterComposer,
      $$ChapterSummariesTableOrderingComposer,
      $$ChapterSummariesTableAnnotationComposer,
      $$ChapterSummariesTableCreateCompanionBuilder,
      $$ChapterSummariesTableUpdateCompanionBuilder,
      (ChapterSummary, $$ChapterSummariesTableReferences),
      ChapterSummary,
      PrefetchHooks Function({bool chapterId})
    >;
typedef $$ChapterSnapshotsTableCreateCompanionBuilder =
    ChapterSnapshotsCompanion Function({
      required String id,
      required String chapterId,
      required int versionNumber,
      required String content,
      required String triggerType,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ChapterSnapshotsTableUpdateCompanionBuilder =
    ChapterSnapshotsCompanion Function({
      Value<String> id,
      Value<String> chapterId,
      Value<int> versionNumber,
      Value<String> content,
      Value<String> triggerType,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ChapterSnapshotsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ChapterSnapshotsTable, ChapterSnapshot> {
  $$ChapterSnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('chapter_snapshots__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager get chapterId {
    final $_column = $_itemColumn<String>('chapter_id')!;

    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChapterSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ChapterSnapshotsTable> {
  $$ChapterSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChapterSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChapterSnapshotsTable> {
  $$ChapterSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableOrderingComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChapterSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChapterSnapshotsTable> {
  $$ChapterSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versionNumber => $composableBuilder(
    column: $table.versionNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChapterSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChapterSnapshotsTable,
          ChapterSnapshot,
          $$ChapterSnapshotsTableFilterComposer,
          $$ChapterSnapshotsTableOrderingComposer,
          $$ChapterSnapshotsTableAnnotationComposer,
          $$ChapterSnapshotsTableCreateCompanionBuilder,
          $$ChapterSnapshotsTableUpdateCompanionBuilder,
          (ChapterSnapshot, $$ChapterSnapshotsTableReferences),
          ChapterSnapshot,
          PrefetchHooks Function({bool chapterId})
        > {
  $$ChapterSnapshotsTableTableManager(
    _$AppDatabase db,
    $ChapterSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChapterSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChapterSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChapterSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<int> versionNumber = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> triggerType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChapterSnapshotsCompanion(
                id: id,
                chapterId: chapterId,
                versionNumber: versionNumber,
                content: content,
                triggerType: triggerType,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chapterId,
                required int versionNumber,
                required String content,
                required String triggerType,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ChapterSnapshotsCompanion.insert(
                id: id,
                chapterId: chapterId,
                versionNumber: versionNumber,
                content: content,
                triggerType: triggerType,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChapterSnapshotsTable, ChapterSnapshot>(table),
                  $$ChapterSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({chapterId = false}) {
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
                    if (chapterId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.chapterId,
                        referencedTable: $$ChapterSnapshotsTableReferences
                            ._chapterIdTable(db),
                        referencedColumn: $$ChapterSnapshotsTableReferences
                            ._chapterIdTable(db)
                            .id,
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

typedef $$ChapterSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChapterSnapshotsTable,
      ChapterSnapshot,
      $$ChapterSnapshotsTableFilterComposer,
      $$ChapterSnapshotsTableOrderingComposer,
      $$ChapterSnapshotsTableAnnotationComposer,
      $$ChapterSnapshotsTableCreateCompanionBuilder,
      $$ChapterSnapshotsTableUpdateCompanionBuilder,
      (ChapterSnapshot, $$ChapterSnapshotsTableReferences),
      ChapterSnapshot,
      PrefetchHooks Function({bool chapterId})
    >;
typedef $$CharactersTableCreateCompanionBuilder = CharactersCompanion Function({
  required String id,
  required String novelId,
  required String name,
  Value<String> aliasesJson,
  Value<String?> appearance,
  Value<String?> personality,
  Value<String?> background,
  Value<String?> currentGoal,
  Value<String?> currentLocation,
  Value<String?> physicalState,
  Value<String?> mentalState,
  Value<String?> lastSeenChapterTitle,
  Value<bool> isSceneRelevant,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$CharactersTableUpdateCompanionBuilder = CharactersCompanion Function({
  Value<String> id,
  Value<String> novelId,
  Value<String> name,
  Value<String> aliasesJson,
  Value<String?> appearance,
  Value<String?> personality,
  Value<String?> background,
  Value<String?> currentGoal,
  Value<String?> currentLocation,
  Value<String?> physicalState,
  Value<String?> mentalState,
  Value<String?> lastSeenChapterTitle,
  Value<bool> isSceneRelevant,
  Value<int> sortOrder,
  Value<int> rowid,
});

final class $$CharactersTableReferences
    extends BaseReferences<_$AppDatabase, $CharactersTable, Character> {
  $$CharactersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NovelsTable _novelIdTable(_$AppDatabase db) =>
      db.novels.createAlias('characters__novel_id__novels__id');

  $$NovelsTableProcessedTableManager get novelId {
    final $_column = $_itemColumn<String>('novel_id')!;

    final manager = $$NovelsTableTableManager(
      $_db,
      $_db.novels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_novelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appearance => $composableBuilder(
    column: $table.appearance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personality => $composableBuilder(
    column: $table.personality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentGoal => $composableBuilder(
    column: $table.currentGoal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentLocation => $composableBuilder(
    column: $table.currentLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get physicalState => $composableBuilder(
    column: $table.physicalState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mentalState => $composableBuilder(
    column: $table.mentalState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSeenChapterTitle => $composableBuilder(
    column: $table.lastSeenChapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSceneRelevant => $composableBuilder(
    column: $table.isSceneRelevant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$NovelsTableFilterComposer get novelId {
    final $$NovelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableFilterComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appearance => $composableBuilder(
    column: $table.appearance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personality => $composableBuilder(
    column: $table.personality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentGoal => $composableBuilder(
    column: $table.currentGoal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentLocation => $composableBuilder(
    column: $table.currentLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get physicalState => $composableBuilder(
    column: $table.physicalState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mentalState => $composableBuilder(
    column: $table.mentalState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSeenChapterTitle => $composableBuilder(
    column: $table.lastSeenChapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSceneRelevant => $composableBuilder(
    column: $table.isSceneRelevant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$NovelsTableOrderingComposer get novelId {
    final $$NovelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableOrderingComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appearance => $composableBuilder(
    column: $table.appearance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get personality => $composableBuilder(
    column: $table.personality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentGoal => $composableBuilder(
    column: $table.currentGoal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentLocation => $composableBuilder(
    column: $table.currentLocation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get physicalState => $composableBuilder(
    column: $table.physicalState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mentalState => $composableBuilder(
    column: $table.mentalState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSeenChapterTitle => $composableBuilder(
    column: $table.lastSeenChapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSceneRelevant => $composableBuilder(
    column: $table.isSceneRelevant,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$NovelsTableAnnotationComposer get novelId {
    final $$NovelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableAnnotationComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CharactersTable,
          Character,
          $$CharactersTableFilterComposer,
          $$CharactersTableOrderingComposer,
          $$CharactersTableAnnotationComposer,
          $$CharactersTableCreateCompanionBuilder,
          $$CharactersTableUpdateCompanionBuilder,
          (Character, $$CharactersTableReferences),
          Character,
          PrefetchHooks Function({bool novelId})
        > {
  $$CharactersTableTableManager(_$AppDatabase db, $CharactersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> novelId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> aliasesJson = const Value.absent(),
                Value<String?> appearance = const Value.absent(),
                Value<String?> personality = const Value.absent(),
                Value<String?> background = const Value.absent(),
                Value<String?> currentGoal = const Value.absent(),
                Value<String?> currentLocation = const Value.absent(),
                Value<String?> physicalState = const Value.absent(),
                Value<String?> mentalState = const Value.absent(),
                Value<String?> lastSeenChapterTitle = const Value.absent(),
                Value<bool> isSceneRelevant = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion(
                id: id,
                novelId: novelId,
                name: name,
                aliasesJson: aliasesJson,
                appearance: appearance,
                personality: personality,
                background: background,
                currentGoal: currentGoal,
                currentLocation: currentLocation,
                physicalState: physicalState,
                mentalState: mentalState,
                lastSeenChapterTitle: lastSeenChapterTitle,
                isSceneRelevant: isSceneRelevant,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String novelId,
                required String name,
                Value<String> aliasesJson = const Value.absent(),
                Value<String?> appearance = const Value.absent(),
                Value<String?> personality = const Value.absent(),
                Value<String?> background = const Value.absent(),
                Value<String?> currentGoal = const Value.absent(),
                Value<String?> currentLocation = const Value.absent(),
                Value<String?> physicalState = const Value.absent(),
                Value<String?> mentalState = const Value.absent(),
                Value<String?> lastSeenChapterTitle = const Value.absent(),
                Value<bool> isSceneRelevant = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion.insert(
                id: id,
                novelId: novelId,
                name: name,
                aliasesJson: aliasesJson,
                appearance: appearance,
                personality: personality,
                background: background,
                currentGoal: currentGoal,
                currentLocation: currentLocation,
                physicalState: physicalState,
                mentalState: mentalState,
                lastSeenChapterTitle: lastSeenChapterTitle,
                isSceneRelevant: isSceneRelevant,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CharactersTable, Character>(table),
                  $$CharactersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({novelId = false}) {
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
                    if (novelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.novelId,
                        referencedTable: $$CharactersTableReferences
                            ._novelIdTable(db),
                        referencedColumn: $$CharactersTableReferences
                            ._novelIdTable(db)
                            .id,
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

typedef $$CharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CharactersTable,
      Character,
      $$CharactersTableFilterComposer,
      $$CharactersTableOrderingComposer,
      $$CharactersTableAnnotationComposer,
      $$CharactersTableCreateCompanionBuilder,
      $$CharactersTableUpdateCompanionBuilder,
      (Character, $$CharactersTableReferences),
      Character,
      PrefetchHooks Function({bool novelId})
    >;
typedef $$WorldEntriesTableCreateCompanionBuilder =
    WorldEntriesCompanion Function({
      required String id,
      required String novelId,
      required String category,
      required String name,
      Value<String> content,
      Value<String> keywordsJson,
      Value<bool> isAlwaysOn,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$WorldEntriesTableUpdateCompanionBuilder =
    WorldEntriesCompanion Function({
      Value<String> id,
      Value<String> novelId,
      Value<String> category,
      Value<String> name,
      Value<String> content,
      Value<String> keywordsJson,
      Value<bool> isAlwaysOn,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$WorldEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $WorldEntriesTable, WorldEntry> {
  $$WorldEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NovelsTable _novelIdTable(_$AppDatabase db) =>
      db.novels.createAlias('world_entries__novel_id__novels__id');

  $$NovelsTableProcessedTableManager get novelId {
    final $_column = $_itemColumn<String>('novel_id')!;

    final manager = $$NovelsTableTableManager(
      $_db,
      $_db.novels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_novelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorldEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WorldEntriesTable> {
  $$WorldEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keywordsJson => $composableBuilder(
    column: $table.keywordsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAlwaysOn => $composableBuilder(
    column: $table.isAlwaysOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$NovelsTableFilterComposer get novelId {
    final $$NovelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableFilterComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorldEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorldEntriesTable> {
  $$WorldEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keywordsJson => $composableBuilder(
    column: $table.keywordsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAlwaysOn => $composableBuilder(
    column: $table.isAlwaysOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$NovelsTableOrderingComposer get novelId {
    final $$NovelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableOrderingComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorldEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorldEntriesTable> {
  $$WorldEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get keywordsJson => $composableBuilder(
    column: $table.keywordsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAlwaysOn => $composableBuilder(
    column: $table.isAlwaysOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$NovelsTableAnnotationComposer get novelId {
    final $$NovelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableAnnotationComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorldEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorldEntriesTable,
          WorldEntry,
          $$WorldEntriesTableFilterComposer,
          $$WorldEntriesTableOrderingComposer,
          $$WorldEntriesTableAnnotationComposer,
          $$WorldEntriesTableCreateCompanionBuilder,
          $$WorldEntriesTableUpdateCompanionBuilder,
          (WorldEntry, $$WorldEntriesTableReferences),
          WorldEntry,
          PrefetchHooks Function({bool novelId})
        > {
  $$WorldEntriesTableTableManager(_$AppDatabase db, $WorldEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorldEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorldEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorldEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> novelId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> keywordsJson = const Value.absent(),
                Value<bool> isAlwaysOn = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorldEntriesCompanion(
                id: id,
                novelId: novelId,
                category: category,
                name: name,
                content: content,
                keywordsJson: keywordsJson,
                isAlwaysOn: isAlwaysOn,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String novelId,
                required String category,
                required String name,
                Value<String> content = const Value.absent(),
                Value<String> keywordsJson = const Value.absent(),
                Value<bool> isAlwaysOn = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorldEntriesCompanion.insert(
                id: id,
                novelId: novelId,
                category: category,
                name: name,
                content: content,
                keywordsJson: keywordsJson,
                isAlwaysOn: isAlwaysOn,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorldEntriesTable, WorldEntry>(table),
                  $$WorldEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({novelId = false}) {
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
                    if (novelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.novelId,
                        referencedTable: $$WorldEntriesTableReferences
                            ._novelIdTable(db),
                        referencedColumn: $$WorldEntriesTableReferences
                            ._novelIdTable(db)
                            .id,
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

typedef $$WorldEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorldEntriesTable,
      WorldEntry,
      $$WorldEntriesTableFilterComposer,
      $$WorldEntriesTableOrderingComposer,
      $$WorldEntriesTableAnnotationComposer,
      $$WorldEntriesTableCreateCompanionBuilder,
      $$WorldEntriesTableUpdateCompanionBuilder,
      (WorldEntry, $$WorldEntriesTableReferences),
      WorldEntry,
      PrefetchHooks Function({bool novelId})
    >;
typedef $$ForeshadowingsTableCreateCompanionBuilder =
    ForeshadowingsCompanion Function({
      required String id,
      required String novelId,
      required String title,
      Value<String?> detail,
      Value<int?> plantedVolumeIndex,
      Value<int?> plantedChapterOrder,
      Value<String?> plannedResolve,
      Value<String> status,
      Value<String?> note,
      Value<bool> suggestedResolved,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ForeshadowingsTableUpdateCompanionBuilder =
    ForeshadowingsCompanion Function({
      Value<String> id,
      Value<String> novelId,
      Value<String> title,
      Value<String?> detail,
      Value<int?> plantedVolumeIndex,
      Value<int?> plantedChapterOrder,
      Value<String?> plannedResolve,
      Value<String> status,
      Value<String?> note,
      Value<bool> suggestedResolved,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ForeshadowingsTableReferences
    extends BaseReferences<_$AppDatabase, $ForeshadowingsTable, Foreshadowing> {
  $$ForeshadowingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NovelsTable _novelIdTable(_$AppDatabase db) =>
      db.novels.createAlias('foreshadowings__novel_id__novels__id');

  $$NovelsTableProcessedTableManager get novelId {
    final $_column = $_itemColumn<String>('novel_id')!;

    final manager = $$NovelsTableTableManager(
      $_db,
      $_db.novels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_novelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ForeshadowingsTableFilterComposer
    extends Composer<_$AppDatabase, $ForeshadowingsTable> {
  $$ForeshadowingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plantedVolumeIndex => $composableBuilder(
    column: $table.plantedVolumeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plantedChapterOrder => $composableBuilder(
    column: $table.plantedChapterOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plannedResolve => $composableBuilder(
    column: $table.plannedResolve,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get suggestedResolved => $composableBuilder(
    column: $table.suggestedResolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NovelsTableFilterComposer get novelId {
    final $$NovelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableFilterComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ForeshadowingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ForeshadowingsTable> {
  $$ForeshadowingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plantedVolumeIndex => $composableBuilder(
    column: $table.plantedVolumeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plantedChapterOrder => $composableBuilder(
    column: $table.plantedChapterOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plannedResolve => $composableBuilder(
    column: $table.plannedResolve,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get suggestedResolved => $composableBuilder(
    column: $table.suggestedResolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NovelsTableOrderingComposer get novelId {
    final $$NovelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableOrderingComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ForeshadowingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ForeshadowingsTable> {
  $$ForeshadowingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<int> get plantedVolumeIndex => $composableBuilder(
    column: $table.plantedVolumeIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plantedChapterOrder => $composableBuilder(
    column: $table.plantedChapterOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plannedResolve => $composableBuilder(
    column: $table.plannedResolve,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get suggestedResolved => $composableBuilder(
    column: $table.suggestedResolved,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$NovelsTableAnnotationComposer get novelId {
    final $$NovelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableAnnotationComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ForeshadowingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ForeshadowingsTable,
          Foreshadowing,
          $$ForeshadowingsTableFilterComposer,
          $$ForeshadowingsTableOrderingComposer,
          $$ForeshadowingsTableAnnotationComposer,
          $$ForeshadowingsTableCreateCompanionBuilder,
          $$ForeshadowingsTableUpdateCompanionBuilder,
          (Foreshadowing, $$ForeshadowingsTableReferences),
          Foreshadowing,
          PrefetchHooks Function({bool novelId})
        > {
  $$ForeshadowingsTableTableManager(
    _$AppDatabase db,
    $ForeshadowingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ForeshadowingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ForeshadowingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ForeshadowingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> novelId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<int?> plantedVolumeIndex = const Value.absent(),
                Value<int?> plantedChapterOrder = const Value.absent(),
                Value<String?> plannedResolve = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> suggestedResolved = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ForeshadowingsCompanion(
                id: id,
                novelId: novelId,
                title: title,
                detail: detail,
                plantedVolumeIndex: plantedVolumeIndex,
                plantedChapterOrder: plantedChapterOrder,
                plannedResolve: plannedResolve,
                status: status,
                note: note,
                suggestedResolved: suggestedResolved,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String novelId,
                required String title,
                Value<String?> detail = const Value.absent(),
                Value<int?> plantedVolumeIndex = const Value.absent(),
                Value<int?> plantedChapterOrder = const Value.absent(),
                Value<String?> plannedResolve = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> suggestedResolved = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ForeshadowingsCompanion.insert(
                id: id,
                novelId: novelId,
                title: title,
                detail: detail,
                plantedVolumeIndex: plantedVolumeIndex,
                plantedChapterOrder: plantedChapterOrder,
                plannedResolve: plannedResolve,
                status: status,
                note: note,
                suggestedResolved: suggestedResolved,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ForeshadowingsTable, Foreshadowing>(table),
                  $$ForeshadowingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({novelId = false}) {
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
                    if (novelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.novelId,
                        referencedTable: $$ForeshadowingsTableReferences
                            ._novelIdTable(db),
                        referencedColumn: $$ForeshadowingsTableReferences
                            ._novelIdTable(db)
                            .id,
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

typedef $$ForeshadowingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ForeshadowingsTable,
      Foreshadowing,
      $$ForeshadowingsTableFilterComposer,
      $$ForeshadowingsTableOrderingComposer,
      $$ForeshadowingsTableAnnotationComposer,
      $$ForeshadowingsTableCreateCompanionBuilder,
      $$ForeshadowingsTableUpdateCompanionBuilder,
      (Foreshadowing, $$ForeshadowingsTableReferences),
      Foreshadowing,
      PrefetchHooks Function({bool novelId})
    >;
typedef $$ChatThreadsTableCreateCompanionBuilder =
    ChatThreadsCompanion Function({
      required String id,
      required String novelId,
      required String purpose,
      Value<bool> skipsClarification,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ChatThreadsTableUpdateCompanionBuilder =
    ChatThreadsCompanion Function({
      Value<String> id,
      Value<String> novelId,
      Value<String> purpose,
      Value<bool> skipsClarification,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ChatThreadsTableReferences
    extends BaseReferences<_$AppDatabase, $ChatThreadsTable, ChatThread> {
  $$ChatThreadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NovelsTable _novelIdTable(_$AppDatabase db) =>
      db.novels.createAlias('chat_threads__novel_id__novels__id');

  $$NovelsTableProcessedTableManager get novelId {
    final $_column = $_itemColumn<String>('novel_id')!;

    final manager = $$NovelsTableTableManager(
      $_db,
      $_db.novels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_novelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ChatMessagesTable, List<ChatMessage>>
  _chatMessagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.chatMessages,
    aliasName: 'chat_threads__id__chat_messages__thread_id',
  );

  $$ChatMessagesTableProcessedTableManager get chatMessagesRefs {
    final manager = $$ChatMessagesTableTableManager(
      $_db,
      $_db.chatMessages,
    ).filter((f) => f.threadId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_chatMessagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CreationSessionCachesTable,
    List<CreationSessionCache>
  >
  _creationSessionCachesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.creationSessionCaches,
        aliasName: 'chat_threads__id__creation_session_caches__thread_id',
      );

  $$CreationSessionCachesTableProcessedTableManager
  get creationSessionCachesRefs {
    final manager = $$CreationSessionCachesTableTableManager(
      $_db,
      $_db.creationSessionCaches,
    ).filter((f) => f.threadId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _creationSessionCachesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChatThreadsTableFilterComposer
    extends Composer<_$AppDatabase, $ChatThreadsTable> {
  $$ChatThreadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get skipsClarification => $composableBuilder(
    column: $table.skipsClarification,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NovelsTableFilterComposer get novelId {
    final $$NovelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableFilterComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> chatMessagesRefs(
    Expression<bool> Function($$ChatMessagesTableFilterComposer f) f,
  ) {
    final $$ChatMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.threadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatMessagesTableFilterComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> creationSessionCachesRefs(
    Expression<bool> Function($$CreationSessionCachesTableFilterComposer f) f,
  ) {
    final $$CreationSessionCachesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.creationSessionCaches,
          getReferencedColumn: (t) => t.threadId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CreationSessionCachesTableFilterComposer(
                $db: $db,
                $table: $db.creationSessionCaches,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ChatThreadsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatThreadsTable> {
  $$ChatThreadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get skipsClarification => $composableBuilder(
    column: $table.skipsClarification,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NovelsTableOrderingComposer get novelId {
    final $$NovelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableOrderingComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatThreadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatThreadsTable> {
  $$ChatThreadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<bool> get skipsClarification => $composableBuilder(
    column: $table.skipsClarification,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$NovelsTableAnnotationComposer get novelId {
    final $$NovelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableAnnotationComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> chatMessagesRefs<T extends Object>(
    Expression<T> Function($$ChatMessagesTableAnnotationComposer a) f,
  ) {
    final $$ChatMessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.threadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatMessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> creationSessionCachesRefs<T extends Object>(
    Expression<T> Function($$CreationSessionCachesTableAnnotationComposer a) f,
  ) {
    final $$CreationSessionCachesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.creationSessionCaches,
          getReferencedColumn: (t) => t.threadId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CreationSessionCachesTableAnnotationComposer(
                $db: $db,
                $table: $db.creationSessionCaches,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ChatThreadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatThreadsTable,
          ChatThread,
          $$ChatThreadsTableFilterComposer,
          $$ChatThreadsTableOrderingComposer,
          $$ChatThreadsTableAnnotationComposer,
          $$ChatThreadsTableCreateCompanionBuilder,
          $$ChatThreadsTableUpdateCompanionBuilder,
          (ChatThread, $$ChatThreadsTableReferences),
          ChatThread,
          PrefetchHooks Function({
            bool novelId,
            bool chatMessagesRefs,
            bool creationSessionCachesRefs,
          })
        > {
  $$ChatThreadsTableTableManager(_$AppDatabase db, $ChatThreadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatThreadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatThreadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatThreadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> novelId = const Value.absent(),
                Value<String> purpose = const Value.absent(),
                Value<bool> skipsClarification = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatThreadsCompanion(
                id: id,
                novelId: novelId,
                purpose: purpose,
                skipsClarification: skipsClarification,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String novelId,
                required String purpose,
                Value<bool> skipsClarification = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ChatThreadsCompanion.insert(
                id: id,
                novelId: novelId,
                purpose: purpose,
                skipsClarification: skipsClarification,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatThreadsTable, ChatThread>(table),
                  $$ChatThreadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                novelId = false,
                chatMessagesRefs = false,
                creationSessionCachesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (chatMessagesRefs) db.chatMessages,
                    if (creationSessionCachesRefs) db.creationSessionCaches,
                  ],
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
                        if (novelId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.novelId,
                            referencedTable: $$ChatThreadsTableReferences
                                ._novelIdTable(db),
                            referencedColumn: $$ChatThreadsTableReferences
                                ._novelIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (chatMessagesRefs)
                        await $_getPrefetchedDataByColumns<
                          ChatThread,
                          $ChatThreadsTable,
                          ChatMessage,
                          $ChatMessagesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ChatThreadsTableReferences
                              ._chatMessagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChatThreadsTableReferences(
                                db,
                                table,
                                p0,
                              ).chatMessagesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'thread_id',
                          typedResults: items,
                        ),
                      if (creationSessionCachesRefs)
                        await $_getPrefetchedDataByColumns<
                          ChatThread,
                          $ChatThreadsTable,
                          CreationSessionCache,
                          $CreationSessionCachesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ChatThreadsTableReferences
                              ._creationSessionCachesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChatThreadsTableReferences(
                                db,
                                table,
                                p0,
                              ).creationSessionCachesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'thread_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChatThreadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatThreadsTable,
      ChatThread,
      $$ChatThreadsTableFilterComposer,
      $$ChatThreadsTableOrderingComposer,
      $$ChatThreadsTableAnnotationComposer,
      $$ChatThreadsTableCreateCompanionBuilder,
      $$ChatThreadsTableUpdateCompanionBuilder,
      (ChatThread, $$ChatThreadsTableReferences),
      ChatThread,
      PrefetchHooks Function({
        bool novelId,
        bool chatMessagesRefs,
        bool creationSessionCachesRefs,
      })
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      required String id,
      required String threadId,
      required String role,
      required String content,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<String> id,
      Value<String> threadId,
      Value<String> role,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ChatMessagesTableReferences
    extends BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage> {
  $$ChatMessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChatThreadsTable _threadIdTable(_$AppDatabase db) =>
      db.chatThreads.createAlias('chat_messages__thread_id__chat_threads__id');

  $$ChatThreadsTableProcessedTableManager get threadId {
    final $_column = $_itemColumn<String>('thread_id')!;

    final manager = $$ChatThreadsTableTableManager(
      $_db,
      $_db.chatThreads,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_threadIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChatThreadsTableFilterComposer get threadId {
    final $$ChatThreadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.threadId,
      referencedTable: $db.chatThreads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatThreadsTableFilterComposer(
            $db: $db,
            $table: $db.chatThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChatThreadsTableOrderingComposer get threadId {
    final $$ChatThreadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.threadId,
      referencedTable: $db.chatThreads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatThreadsTableOrderingComposer(
            $db: $db,
            $table: $db.chatThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ChatThreadsTableAnnotationComposer get threadId {
    final $$ChatThreadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.threadId,
      referencedTable: $db.chatThreads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatThreadsTableAnnotationComposer(
            $db: $db,
            $table: $db.chatThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (ChatMessage, $$ChatMessagesTableReferences),
          ChatMessage,
          PrefetchHooks Function({bool threadId})
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> threadId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                threadId: threadId,
                role: role,
                content: content,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String threadId,
                required String role,
                required String content,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                threadId: threadId,
                role: role,
                content: content,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatMessagesTable, ChatMessage>(table),
                  $$ChatMessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({threadId = false}) {
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
                    if (threadId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.threadId,
                        referencedTable: $$ChatMessagesTableReferences
                            ._threadIdTable(db),
                        referencedColumn: $$ChatMessagesTableReferences
                            ._threadIdTable(db)
                            .id,
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

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (ChatMessage, $$ChatMessagesTableReferences),
      ChatMessage,
      PrefetchHooks Function({bool threadId})
    >;
typedef $$ProvidersTableCreateCompanionBuilder = ProvidersCompanion Function({
  required String id,
  required String name,
  required String baseUrl,
  required String apiKeyId,
  required String modelName,
  Value<double> temperature,
  Value<int> maxTokens,
  Value<int> contextBudgetChars,
  Value<String?> systemPromptExtra,
  Value<String?> proxyUrl,
  Value<bool> isDefault,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ProvidersTableUpdateCompanionBuilder = ProvidersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> baseUrl,
  Value<String> apiKeyId,
  Value<String> modelName,
  Value<double> temperature,
  Value<int> maxTokens,
  Value<int> contextBudgetChars,
  Value<String?> systemPromptExtra,
  Value<String?> proxyUrl,
  Value<bool> isDefault,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ProvidersTableFilterComposer
    extends Composer<_$AppDatabase, $ProvidersTable> {
  $$ProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiKeyId => $composableBuilder(
    column: $table.apiKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxTokens => $composableBuilder(
    column: $table.maxTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contextBudgetChars => $composableBuilder(
    column: $table.contextBudgetChars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPromptExtra => $composableBuilder(
    column: $table.systemPromptExtra,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proxyUrl => $composableBuilder(
    column: $table.proxyUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProvidersTableOrderingComposer
    extends Composer<_$AppDatabase, $ProvidersTable> {
  $$ProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiKeyId => $composableBuilder(
    column: $table.apiKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxTokens => $composableBuilder(
    column: $table.maxTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contextBudgetChars => $composableBuilder(
    column: $table.contextBudgetChars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPromptExtra => $composableBuilder(
    column: $table.systemPromptExtra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proxyUrl => $composableBuilder(
    column: $table.proxyUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProvidersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProvidersTable> {
  $$ProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get apiKeyId =>
      $composableBuilder(column: $table.apiKeyId, builder: (column) => column);

  GeneratedColumn<String> get modelName =>
      $composableBuilder(column: $table.modelName, builder: (column) => column);

  GeneratedColumn<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxTokens =>
      $composableBuilder(column: $table.maxTokens, builder: (column) => column);

  GeneratedColumn<int> get contextBudgetChars => $composableBuilder(
    column: $table.contextBudgetChars,
    builder: (column) => column,
  );

  GeneratedColumn<String> get systemPromptExtra => $composableBuilder(
    column: $table.systemPromptExtra,
    builder: (column) => column,
  );

  GeneratedColumn<String> get proxyUrl =>
      $composableBuilder(column: $table.proxyUrl, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProvidersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProvidersTable,
          ProviderRecord,
          $$ProvidersTableFilterComposer,
          $$ProvidersTableOrderingComposer,
          $$ProvidersTableAnnotationComposer,
          $$ProvidersTableCreateCompanionBuilder,
          $$ProvidersTableUpdateCompanionBuilder,
          (
            ProviderRecord,
            BaseReferences<_$AppDatabase, $ProvidersTable, ProviderRecord>,
          ),
          ProviderRecord,
          PrefetchHooks Function()
        > {
  $$ProvidersTableTableManager(_$AppDatabase db, $ProvidersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProvidersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> apiKeyId = const Value.absent(),
                Value<String> modelName = const Value.absent(),
                Value<double> temperature = const Value.absent(),
                Value<int> maxTokens = const Value.absent(),
                Value<int> contextBudgetChars = const Value.absent(),
                Value<String?> systemPromptExtra = const Value.absent(),
                Value<String?> proxyUrl = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProvidersCompanion(
                id: id,
                name: name,
                baseUrl: baseUrl,
                apiKeyId: apiKeyId,
                modelName: modelName,
                temperature: temperature,
                maxTokens: maxTokens,
                contextBudgetChars: contextBudgetChars,
                systemPromptExtra: systemPromptExtra,
                proxyUrl: proxyUrl,
                isDefault: isDefault,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String baseUrl,
                required String apiKeyId,
                required String modelName,
                Value<double> temperature = const Value.absent(),
                Value<int> maxTokens = const Value.absent(),
                Value<int> contextBudgetChars = const Value.absent(),
                Value<String?> systemPromptExtra = const Value.absent(),
                Value<String?> proxyUrl = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProvidersCompanion.insert(
                id: id,
                name: name,
                baseUrl: baseUrl,
                apiKeyId: apiKeyId,
                modelName: modelName,
                temperature: temperature,
                maxTokens: maxTokens,
                contextBudgetChars: contextBudgetChars,
                systemPromptExtra: systemPromptExtra,
                proxyUrl: proxyUrl,
                isDefault: isDefault,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProvidersTable, ProviderRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ProvidersTable,
                    ProviderRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProvidersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProvidersTable,
      ProviderRecord,
      $$ProvidersTableFilterComposer,
      $$ProvidersTableOrderingComposer,
      $$ProvidersTableAnnotationComposer,
      $$ProvidersTableCreateCompanionBuilder,
      $$ProvidersTableUpdateCompanionBuilder,
      (
        ProviderRecord,
        BaseReferences<_$AppDatabase, $ProvidersTable, ProviderRecord>,
      ),
      ProviderRecord,
      PrefetchHooks Function()
    >;
typedef $$StyleProfilesTableCreateCompanionBuilder =
    StyleProfilesCompanion Function({
      required String id,
      required String name,
      required String payloadJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StyleProfilesTableUpdateCompanionBuilder =
    StyleProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StyleProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $StyleProfilesTable> {
  $$StyleProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StyleProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $StyleProfilesTable> {
  $$StyleProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StyleProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StyleProfilesTable> {
  $$StyleProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StyleProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StyleProfilesTable,
          StyleProfile,
          $$StyleProfilesTableFilterComposer,
          $$StyleProfilesTableOrderingComposer,
          $$StyleProfilesTableAnnotationComposer,
          $$StyleProfilesTableCreateCompanionBuilder,
          $$StyleProfilesTableUpdateCompanionBuilder,
          (
            StyleProfile,
            BaseReferences<_$AppDatabase, $StyleProfilesTable, StyleProfile>,
          ),
          StyleProfile,
          PrefetchHooks Function()
        > {
  $$StyleProfilesTableTableManager(_$AppDatabase db, $StyleProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StyleProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StyleProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StyleProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StyleProfilesCompanion(
                id: id,
                name: name,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String payloadJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StyleProfilesCompanion.insert(
                id: id,
                name: name,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StyleProfilesTable, StyleProfile>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $StyleProfilesTable,
                    StyleProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StyleProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StyleProfilesTable,
      StyleProfile,
      $$StyleProfilesTableFilterComposer,
      $$StyleProfilesTableOrderingComposer,
      $$StyleProfilesTableAnnotationComposer,
      $$StyleProfilesTableCreateCompanionBuilder,
      $$StyleProfilesTableUpdateCompanionBuilder,
      (
        StyleProfile,
        BaseReferences<_$AppDatabase, $StyleProfilesTable, StyleProfile>,
      ),
      StyleProfile,
      PrefetchHooks Function()
    >;
typedef $$SourceProfilesTableCreateCompanionBuilder =
    SourceProfilesCompanion Function({
      required String id,
      required String title,
      Value<String?> author,
      required String payloadJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SourceProfilesTableUpdateCompanionBuilder =
    SourceProfilesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> author,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SourceProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $SourceProfilesTable> {
  $$SourceProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourceProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourceProfilesTable> {
  $$SourceProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourceProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourceProfilesTable> {
  $$SourceProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SourceProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourceProfilesTable,
          SourceProfile,
          $$SourceProfilesTableFilterComposer,
          $$SourceProfilesTableOrderingComposer,
          $$SourceProfilesTableAnnotationComposer,
          $$SourceProfilesTableCreateCompanionBuilder,
          $$SourceProfilesTableUpdateCompanionBuilder,
          (
            SourceProfile,
            BaseReferences<_$AppDatabase, $SourceProfilesTable, SourceProfile>,
          ),
          SourceProfile,
          PrefetchHooks Function()
        > {
  $$SourceProfilesTableTableManager(
    _$AppDatabase db,
    $SourceProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceProfilesCompanion(
                id: id,
                title: title,
                author: author,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> author = const Value.absent(),
                required String payloadJson,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SourceProfilesCompanion.insert(
                id: id,
                title: title,
                author: author,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourceProfilesTable, SourceProfile>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SourceProfilesTable,
                    SourceProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourceProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourceProfilesTable,
      SourceProfile,
      $$SourceProfilesTableFilterComposer,
      $$SourceProfilesTableOrderingComposer,
      $$SourceProfilesTableAnnotationComposer,
      $$SourceProfilesTableCreateCompanionBuilder,
      $$SourceProfilesTableUpdateCompanionBuilder,
      (
        SourceProfile,
        BaseReferences<_$AppDatabase, $SourceProfilesTable, SourceProfile>,
      ),
      SourceProfile,
      PrefetchHooks Function()
    >;
typedef $$PromptOverridesTableCreateCompanionBuilder =
    PromptOverridesCompanion Function({
      required String promptId,
      required String content,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PromptOverridesTableUpdateCompanionBuilder =
    PromptOverridesCompanion Function({
      Value<String> promptId,
      Value<String> content,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PromptOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $PromptOverridesTable> {
  $$PromptOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get promptId => $composableBuilder(
    column: $table.promptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PromptOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $PromptOverridesTable> {
  $$PromptOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get promptId => $composableBuilder(
    column: $table.promptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PromptOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PromptOverridesTable> {
  $$PromptOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get promptId =>
      $composableBuilder(column: $table.promptId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PromptOverridesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PromptOverridesTable,
          PromptOverride,
          $$PromptOverridesTableFilterComposer,
          $$PromptOverridesTableOrderingComposer,
          $$PromptOverridesTableAnnotationComposer,
          $$PromptOverridesTableCreateCompanionBuilder,
          $$PromptOverridesTableUpdateCompanionBuilder,
          (
            PromptOverride,
            BaseReferences<
              _$AppDatabase,
              $PromptOverridesTable,
              PromptOverride
            >,
          ),
          PromptOverride,
          PrefetchHooks Function()
        > {
  $$PromptOverridesTableTableManager(
    _$AppDatabase db,
    $PromptOverridesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PromptOverridesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PromptOverridesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PromptOverridesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> promptId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PromptOverridesCompanion(
                promptId: promptId,
                content: content,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String promptId,
                required String content,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PromptOverridesCompanion.insert(
                promptId: promptId,
                content: content,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PromptOverridesTable, PromptOverride>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PromptOverridesTable,
                    PromptOverride
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PromptOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PromptOverridesTable,
      PromptOverride,
      $$PromptOverridesTableFilterComposer,
      $$PromptOverridesTableOrderingComposer,
      $$PromptOverridesTableAnnotationComposer,
      $$PromptOverridesTableCreateCompanionBuilder,
      $$PromptOverridesTableUpdateCompanionBuilder,
      (
        PromptOverride,
        BaseReferences<_$AppDatabase, $PromptOverridesTable, PromptOverride>,
      ),
      PromptOverride,
      PrefetchHooks Function()
    >;
typedef $$PromptTagCategoriesTableCreateCompanionBuilder =
    PromptTagCategoriesCompanion Function({
      required String id,
      required String name,
      required String tagsJson,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$PromptTagCategoriesTableUpdateCompanionBuilder =
    PromptTagCategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> tagsJson,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$PromptTagCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $PromptTagCategoriesTable> {
  $$PromptTagCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PromptTagCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PromptTagCategoriesTable> {
  $$PromptTagCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PromptTagCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PromptTagCategoriesTable> {
  $$PromptTagCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$PromptTagCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PromptTagCategoriesTable,
          PromptTagCategory,
          $$PromptTagCategoriesTableFilterComposer,
          $$PromptTagCategoriesTableOrderingComposer,
          $$PromptTagCategoriesTableAnnotationComposer,
          $$PromptTagCategoriesTableCreateCompanionBuilder,
          $$PromptTagCategoriesTableUpdateCompanionBuilder,
          (
            PromptTagCategory,
            BaseReferences<
              _$AppDatabase,
              $PromptTagCategoriesTable,
              PromptTagCategory
            >,
          ),
          PromptTagCategory,
          PrefetchHooks Function()
        > {
  $$PromptTagCategoriesTableTableManager(
    _$AppDatabase db,
    $PromptTagCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PromptTagCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PromptTagCategoriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PromptTagCategoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PromptTagCategoriesCompanion(
                id: id,
                name: name,
                tagsJson: tagsJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String tagsJson,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PromptTagCategoriesCompanion.insert(
                id: id,
                name: name,
                tagsJson: tagsJson,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PromptTagCategoriesTable, PromptTagCategory>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $PromptTagCategoriesTable,
                    PromptTagCategory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PromptTagCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PromptTagCategoriesTable,
      PromptTagCategory,
      $$PromptTagCategoriesTableFilterComposer,
      $$PromptTagCategoriesTableOrderingComposer,
      $$PromptTagCategoriesTableAnnotationComposer,
      $$PromptTagCategoriesTableCreateCompanionBuilder,
      $$PromptTagCategoriesTableUpdateCompanionBuilder,
      (
        PromptTagCategory,
        BaseReferences<
          _$AppDatabase,
          $PromptTagCategoriesTable,
          PromptTagCategory
        >,
      ),
      PromptTagCategory,
      PrefetchHooks Function()
    >;
typedef $$CreationSessionCachesTableCreateCompanionBuilder =
    CreationSessionCachesCompanion Function({
      required String threadId,
      required String payloadJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CreationSessionCachesTableUpdateCompanionBuilder =
    CreationSessionCachesCompanion Function({
      Value<String> threadId,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CreationSessionCachesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CreationSessionCachesTable,
          CreationSessionCache
        > {
  $$CreationSessionCachesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChatThreadsTable _threadIdTable(_$AppDatabase db) => db.chatThreads
      .createAlias('creation_session_caches__thread_id__chat_threads__id');

  $$ChatThreadsTableProcessedTableManager get threadId {
    final $_column = $_itemColumn<String>('thread_id')!;

    final manager = $$ChatThreadsTableTableManager(
      $_db,
      $_db.chatThreads,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_threadIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CreationSessionCachesTableFilterComposer
    extends Composer<_$AppDatabase, $CreationSessionCachesTable> {
  $$CreationSessionCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChatThreadsTableFilterComposer get threadId {
    final $$ChatThreadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.threadId,
      referencedTable: $db.chatThreads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatThreadsTableFilterComposer(
            $db: $db,
            $table: $db.chatThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CreationSessionCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $CreationSessionCachesTable> {
  $$CreationSessionCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChatThreadsTableOrderingComposer get threadId {
    final $$ChatThreadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.threadId,
      referencedTable: $db.chatThreads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatThreadsTableOrderingComposer(
            $db: $db,
            $table: $db.chatThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CreationSessionCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CreationSessionCachesTable> {
  $$CreationSessionCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ChatThreadsTableAnnotationComposer get threadId {
    final $$ChatThreadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.threadId,
      referencedTable: $db.chatThreads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatThreadsTableAnnotationComposer(
            $db: $db,
            $table: $db.chatThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CreationSessionCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CreationSessionCachesTable,
          CreationSessionCache,
          $$CreationSessionCachesTableFilterComposer,
          $$CreationSessionCachesTableOrderingComposer,
          $$CreationSessionCachesTableAnnotationComposer,
          $$CreationSessionCachesTableCreateCompanionBuilder,
          $$CreationSessionCachesTableUpdateCompanionBuilder,
          (CreationSessionCache, $$CreationSessionCachesTableReferences),
          CreationSessionCache,
          PrefetchHooks Function({bool threadId})
        > {
  $$CreationSessionCachesTableTableManager(
    _$AppDatabase db,
    $CreationSessionCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CreationSessionCachesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CreationSessionCachesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CreationSessionCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> threadId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CreationSessionCachesCompanion(
                threadId: threadId,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String threadId,
                required String payloadJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CreationSessionCachesCompanion.insert(
                threadId: threadId,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CreationSessionCachesTable,
                    CreationSessionCache
                  >(table),
                  $$CreationSessionCachesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({threadId = false}) {
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
                    if (threadId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.threadId,
                        referencedTable: $$CreationSessionCachesTableReferences
                            ._threadIdTable(db),
                        referencedColumn: $$CreationSessionCachesTableReferences
                            ._threadIdTable(db)
                            .id,
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

typedef $$CreationSessionCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CreationSessionCachesTable,
      CreationSessionCache,
      $$CreationSessionCachesTableFilterComposer,
      $$CreationSessionCachesTableOrderingComposer,
      $$CreationSessionCachesTableAnnotationComposer,
      $$CreationSessionCachesTableCreateCompanionBuilder,
      $$CreationSessionCachesTableUpdateCompanionBuilder,
      (CreationSessionCache, $$CreationSessionCachesTableReferences),
      CreationSessionCache,
      PrefetchHooks Function({bool threadId})
    >;
typedef $$StyleDistillCachesTableCreateCompanionBuilder =
    StyleDistillCachesCompanion Function({
      required String slot,
      required String payloadJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StyleDistillCachesTableUpdateCompanionBuilder =
    StyleDistillCachesCompanion Function({
      Value<String> slot,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StyleDistillCachesTableFilterComposer
    extends Composer<_$AppDatabase, $StyleDistillCachesTable> {
  $$StyleDistillCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StyleDistillCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $StyleDistillCachesTable> {
  $$StyleDistillCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StyleDistillCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StyleDistillCachesTable> {
  $$StyleDistillCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StyleDistillCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StyleDistillCachesTable,
          StyleDistillCache,
          $$StyleDistillCachesTableFilterComposer,
          $$StyleDistillCachesTableOrderingComposer,
          $$StyleDistillCachesTableAnnotationComposer,
          $$StyleDistillCachesTableCreateCompanionBuilder,
          $$StyleDistillCachesTableUpdateCompanionBuilder,
          (
            StyleDistillCache,
            BaseReferences<
              _$AppDatabase,
              $StyleDistillCachesTable,
              StyleDistillCache
            >,
          ),
          StyleDistillCache,
          PrefetchHooks Function()
        > {
  $$StyleDistillCachesTableTableManager(
    _$AppDatabase db,
    $StyleDistillCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StyleDistillCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StyleDistillCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StyleDistillCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> slot = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StyleDistillCachesCompanion(
                slot: slot,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String slot,
                required String payloadJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StyleDistillCachesCompanion.insert(
                slot: slot,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StyleDistillCachesTable, StyleDistillCache>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $StyleDistillCachesTable,
                    StyleDistillCache
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StyleDistillCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StyleDistillCachesTable,
      StyleDistillCache,
      $$StyleDistillCachesTableFilterComposer,
      $$StyleDistillCachesTableOrderingComposer,
      $$StyleDistillCachesTableAnnotationComposer,
      $$StyleDistillCachesTableCreateCompanionBuilder,
      $$StyleDistillCachesTableUpdateCompanionBuilder,
      (
        StyleDistillCache,
        BaseReferences<
          _$AppDatabase,
          $StyleDistillCachesTable,
          StyleDistillCache
        >,
      ),
      StyleDistillCache,
      PrefetchHooks Function()
    >;
typedef $$ScanTasksTableCreateCompanionBuilder = ScanTasksCompanion Function({
  required String profileId,
  required String title,
  required String mode,
  required int batchSize,
  Value<bool> isContinuation,
  required int totalChunks,
  required String providerName,
  required String providerBaseUrl,
  required String providerModel,
  required String providerKeyId,
  required DateTime startedAt,
  Value<int> rowid,
});
typedef $$ScanTasksTableUpdateCompanionBuilder = ScanTasksCompanion Function({
  Value<String> profileId,
  Value<String> title,
  Value<String> mode,
  Value<int> batchSize,
  Value<bool> isContinuation,
  Value<int> totalChunks,
  Value<String> providerName,
  Value<String> providerBaseUrl,
  Value<String> providerModel,
  Value<String> providerKeyId,
  Value<DateTime> startedAt,
  Value<int> rowid,
});

class $$ScanTasksTableFilterComposer
    extends Composer<_$AppDatabase, $ScanTasksTable> {
  $$ScanTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batchSize => $composableBuilder(
    column: $table.batchSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isContinuation => $composableBuilder(
    column: $table.isContinuation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChunks => $composableBuilder(
    column: $table.totalChunks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerBaseUrl => $composableBuilder(
    column: $table.providerBaseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerModel => $composableBuilder(
    column: $table.providerModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerKeyId => $composableBuilder(
    column: $table.providerKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanTasksTable> {
  $$ScanTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batchSize => $composableBuilder(
    column: $table.batchSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isContinuation => $composableBuilder(
    column: $table.isContinuation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChunks => $composableBuilder(
    column: $table.totalChunks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerBaseUrl => $composableBuilder(
    column: $table.providerBaseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerModel => $composableBuilder(
    column: $table.providerModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerKeyId => $composableBuilder(
    column: $table.providerKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanTasksTable> {
  $$ScanTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get batchSize =>
      $composableBuilder(column: $table.batchSize, builder: (column) => column);

  GeneratedColumn<bool> get isContinuation => $composableBuilder(
    column: $table.isContinuation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalChunks => $composableBuilder(
    column: $table.totalChunks,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerBaseUrl => $composableBuilder(
    column: $table.providerBaseUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerModel => $composableBuilder(
    column: $table.providerModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerKeyId => $composableBuilder(
    column: $table.providerKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);
}

class $$ScanTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanTasksTable,
          ScanTask,
          $$ScanTasksTableFilterComposer,
          $$ScanTasksTableOrderingComposer,
          $$ScanTasksTableAnnotationComposer,
          $$ScanTasksTableCreateCompanionBuilder,
          $$ScanTasksTableUpdateCompanionBuilder,
          (ScanTask, BaseReferences<_$AppDatabase, $ScanTasksTable, ScanTask>),
          ScanTask,
          PrefetchHooks Function()
        > {
  $$ScanTasksTableTableManager(_$AppDatabase db, $ScanTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> batchSize = const Value.absent(),
                Value<bool> isContinuation = const Value.absent(),
                Value<int> totalChunks = const Value.absent(),
                Value<String> providerName = const Value.absent(),
                Value<String> providerBaseUrl = const Value.absent(),
                Value<String> providerModel = const Value.absent(),
                Value<String> providerKeyId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScanTasksCompanion(
                profileId: profileId,
                title: title,
                mode: mode,
                batchSize: batchSize,
                isContinuation: isContinuation,
                totalChunks: totalChunks,
                providerName: providerName,
                providerBaseUrl: providerBaseUrl,
                providerModel: providerModel,
                providerKeyId: providerKeyId,
                startedAt: startedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String title,
                required String mode,
                required int batchSize,
                Value<bool> isContinuation = const Value.absent(),
                required int totalChunks,
                required String providerName,
                required String providerBaseUrl,
                required String providerModel,
                required String providerKeyId,
                required DateTime startedAt,
                Value<int> rowid = const Value.absent(),
              }) => ScanTasksCompanion.insert(
                profileId: profileId,
                title: title,
                mode: mode,
                batchSize: batchSize,
                isContinuation: isContinuation,
                totalChunks: totalChunks,
                providerName: providerName,
                providerBaseUrl: providerBaseUrl,
                providerModel: providerModel,
                providerKeyId: providerKeyId,
                startedAt: startedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanTasksTable, ScanTask>(table),
                  BaseReferences<_$AppDatabase, $ScanTasksTable, ScanTask>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanTasksTable,
      ScanTask,
      $$ScanTasksTableFilterComposer,
      $$ScanTasksTableOrderingComposer,
      $$ScanTasksTableAnnotationComposer,
      $$ScanTasksTableCreateCompanionBuilder,
      $$ScanTasksTableUpdateCompanionBuilder,
      (ScanTask, BaseReferences<_$AppDatabase, $ScanTasksTable, ScanTask>),
      ScanTask,
      PrefetchHooks Function()
    >;
typedef $$ScanChunksTableCreateCompanionBuilder = ScanChunksCompanion Function({
  required String profileId,
  required int idx,
  required String status,
  Value<String?> payloadJson,
  Value<int> tokensIn,
  Value<int> tokensOut,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ScanChunksTableUpdateCompanionBuilder = ScanChunksCompanion Function({
  Value<String> profileId,
  Value<int> idx,
  Value<String> status,
  Value<String?> payloadJson,
  Value<int> tokensIn,
  Value<int> tokensOut,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ScanChunksTableFilterComposer
    extends Composer<_$AppDatabase, $ScanChunksTable> {
  $$ScanChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokensIn => $composableBuilder(
    column: $table.tokensIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokensOut => $composableBuilder(
    column: $table.tokensOut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanChunksTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanChunksTable> {
  $$ScanChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokensIn => $composableBuilder(
    column: $table.tokensIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokensOut => $composableBuilder(
    column: $table.tokensOut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanChunksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanChunksTable> {
  $$ScanChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tokensIn =>
      $composableBuilder(column: $table.tokensIn, builder: (column) => column);

  GeneratedColumn<int> get tokensOut =>
      $composableBuilder(column: $table.tokensOut, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ScanChunksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanChunksTable,
          ScanChunk,
          $$ScanChunksTableFilterComposer,
          $$ScanChunksTableOrderingComposer,
          $$ScanChunksTableAnnotationComposer,
          $$ScanChunksTableCreateCompanionBuilder,
          $$ScanChunksTableUpdateCompanionBuilder,
          (
            ScanChunk,
            BaseReferences<_$AppDatabase, $ScanChunksTable, ScanChunk>,
          ),
          ScanChunk,
          PrefetchHooks Function()
        > {
  $$ScanChunksTableTableManager(_$AppDatabase db, $ScanChunksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanChunksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanChunksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<int> idx = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> tokensIn = const Value.absent(),
                Value<int> tokensOut = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScanChunksCompanion(
                profileId: profileId,
                idx: idx,
                status: status,
                payloadJson: payloadJson,
                tokensIn: tokensIn,
                tokensOut: tokensOut,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required int idx,
                required String status,
                Value<String?> payloadJson = const Value.absent(),
                Value<int> tokensIn = const Value.absent(),
                Value<int> tokensOut = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ScanChunksCompanion.insert(
                profileId: profileId,
                idx: idx,
                status: status,
                payloadJson: payloadJson,
                tokensIn: tokensIn,
                tokensOut: tokensOut,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanChunksTable, ScanChunk>(table),
                  BaseReferences<_$AppDatabase, $ScanChunksTable, ScanChunk>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanChunksTable,
      ScanChunk,
      $$ScanChunksTableFilterComposer,
      $$ScanChunksTableOrderingComposer,
      $$ScanChunksTableAnnotationComposer,
      $$ScanChunksTableCreateCompanionBuilder,
      $$ScanChunksTableUpdateCompanionBuilder,
      (ScanChunk, BaseReferences<_$AppDatabase, $ScanChunksTable, ScanChunk>),
      ScanChunk,
      PrefetchHooks Function()
    >;
typedef $$ScanReducesTableCreateCompanionBuilder =
    ScanReducesCompanion Function({
      required String profileId,
      required int seq,
      required String summaryText,
      Value<int> rowid,
    });
typedef $$ScanReducesTableUpdateCompanionBuilder =
    ScanReducesCompanion Function({
      Value<String> profileId,
      Value<int> seq,
      Value<String> summaryText,
      Value<int> rowid,
    });

class $$ScanReducesTableFilterComposer
    extends Composer<_$AppDatabase, $ScanReducesTable> {
  $$ScanReducesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanReducesTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanReducesTable> {
  $$ScanReducesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanReducesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanReducesTable> {
  $$ScanReducesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => column,
  );
}

class $$ScanReducesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanReducesTable,
          ScanReduce,
          $$ScanReducesTableFilterComposer,
          $$ScanReducesTableOrderingComposer,
          $$ScanReducesTableAnnotationComposer,
          $$ScanReducesTableCreateCompanionBuilder,
          $$ScanReducesTableUpdateCompanionBuilder,
          (
            ScanReduce,
            BaseReferences<_$AppDatabase, $ScanReducesTable, ScanReduce>,
          ),
          ScanReduce,
          PrefetchHooks Function()
        > {
  $$ScanReducesTableTableManager(_$AppDatabase db, $ScanReducesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanReducesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanReducesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanReducesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> summaryText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScanReducesCompanion(
                profileId: profileId,
                seq: seq,
                summaryText: summaryText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required int seq,
                required String summaryText,
                Value<int> rowid = const Value.absent(),
              }) => ScanReducesCompanion.insert(
                profileId: profileId,
                seq: seq,
                summaryText: summaryText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanReducesTable, ScanReduce>(table),
                  BaseReferences<_$AppDatabase, $ScanReducesTable, ScanReduce>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanReducesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanReducesTable,
      ScanReduce,
      $$ScanReducesTableFilterComposer,
      $$ScanReducesTableOrderingComposer,
      $$ScanReducesTableAnnotationComposer,
      $$ScanReducesTableCreateCompanionBuilder,
      $$ScanReducesTableUpdateCompanionBuilder,
      (
        ScanReduce,
        BaseReferences<_$AppDatabase, $ScanReducesTable, ScanReduce>,
      ),
      ScanReduce,
      PrefetchHooks Function()
    >;
typedef $$ScanMetasTableCreateCompanionBuilder = ScanMetasCompanion Function({
  required String profileId,
  required String metaKey,
  required int metaValue,
  Value<int> rowid,
});
typedef $$ScanMetasTableUpdateCompanionBuilder = ScanMetasCompanion Function({
  Value<String> profileId,
  Value<String> metaKey,
  Value<int> metaValue,
  Value<int> rowid,
});

class $$ScanMetasTableFilterComposer
    extends Composer<_$AppDatabase, $ScanMetasTable> {
  $$ScanMetasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaKey => $composableBuilder(
    column: $table.metaKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get metaValue => $composableBuilder(
    column: $table.metaValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanMetasTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanMetasTable> {
  $$ScanMetasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaKey => $composableBuilder(
    column: $table.metaKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get metaValue => $composableBuilder(
    column: $table.metaValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanMetasTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanMetasTable> {
  $$ScanMetasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get metaKey =>
      $composableBuilder(column: $table.metaKey, builder: (column) => column);

  GeneratedColumn<int> get metaValue =>
      $composableBuilder(column: $table.metaValue, builder: (column) => column);
}

class $$ScanMetasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanMetasTable,
          ScanMeta,
          $$ScanMetasTableFilterComposer,
          $$ScanMetasTableOrderingComposer,
          $$ScanMetasTableAnnotationComposer,
          $$ScanMetasTableCreateCompanionBuilder,
          $$ScanMetasTableUpdateCompanionBuilder,
          (ScanMeta, BaseReferences<_$AppDatabase, $ScanMetasTable, ScanMeta>),
          ScanMeta,
          PrefetchHooks Function()
        > {
  $$ScanMetasTableTableManager(_$AppDatabase db, $ScanMetasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanMetasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanMetasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanMetasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> metaKey = const Value.absent(),
                Value<int> metaValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScanMetasCompanion(
                profileId: profileId,
                metaKey: metaKey,
                metaValue: metaValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String metaKey,
                required int metaValue,
                Value<int> rowid = const Value.absent(),
              }) => ScanMetasCompanion.insert(
                profileId: profileId,
                metaKey: metaKey,
                metaValue: metaValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanMetasTable, ScanMeta>(table),
                  BaseReferences<_$AppDatabase, $ScanMetasTable, ScanMeta>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanMetasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanMetasTable,
      ScanMeta,
      $$ScanMetasTableFilterComposer,
      $$ScanMetasTableOrderingComposer,
      $$ScanMetasTableAnnotationComposer,
      $$ScanMetasTableCreateCompanionBuilder,
      $$ScanMetasTableUpdateCompanionBuilder,
      (ScanMeta, BaseReferences<_$AppDatabase, $ScanMetasTable, ScanMeta>),
      ScanMeta,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NovelsTableTableManager get novels =>
      $$NovelsTableTableManager(_db, _db.novels);
  $$VolumesTableTableManager get volumes =>
      $$VolumesTableTableManager(_db, _db.volumes);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$ChapterSummariesTableTableManager get chapterSummaries =>
      $$ChapterSummariesTableTableManager(_db, _db.chapterSummaries);
  $$ChapterSnapshotsTableTableManager get chapterSnapshots =>
      $$ChapterSnapshotsTableTableManager(_db, _db.chapterSnapshots);
  $$CharactersTableTableManager get characters =>
      $$CharactersTableTableManager(_db, _db.characters);
  $$WorldEntriesTableTableManager get worldEntries =>
      $$WorldEntriesTableTableManager(_db, _db.worldEntries);
  $$ForeshadowingsTableTableManager get foreshadowings =>
      $$ForeshadowingsTableTableManager(_db, _db.foreshadowings);
  $$ChatThreadsTableTableManager get chatThreads =>
      $$ChatThreadsTableTableManager(_db, _db.chatThreads);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$ProvidersTableTableManager get providers =>
      $$ProvidersTableTableManager(_db, _db.providers);
  $$StyleProfilesTableTableManager get styleProfiles =>
      $$StyleProfilesTableTableManager(_db, _db.styleProfiles);
  $$SourceProfilesTableTableManager get sourceProfiles =>
      $$SourceProfilesTableTableManager(_db, _db.sourceProfiles);
  $$PromptOverridesTableTableManager get promptOverrides =>
      $$PromptOverridesTableTableManager(_db, _db.promptOverrides);
  $$PromptTagCategoriesTableTableManager get promptTagCategories =>
      $$PromptTagCategoriesTableTableManager(_db, _db.promptTagCategories);
  $$CreationSessionCachesTableTableManager get creationSessionCaches =>
      $$CreationSessionCachesTableTableManager(_db, _db.creationSessionCaches);
  $$StyleDistillCachesTableTableManager get styleDistillCaches =>
      $$StyleDistillCachesTableTableManager(_db, _db.styleDistillCaches);
  $$ScanTasksTableTableManager get scanTasks =>
      $$ScanTasksTableTableManager(_db, _db.scanTasks);
  $$ScanChunksTableTableManager get scanChunks =>
      $$ScanChunksTableTableManager(_db, _db.scanChunks);
  $$ScanReducesTableTableManager get scanReduces =>
      $$ScanReducesTableTableManager(_db, _db.scanReduces);
  $$ScanMetasTableTableManager get scanMetas =>
      $$ScanMetasTableTableManager(_db, _db.scanMetas);
}
