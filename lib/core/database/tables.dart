import 'package:drift/drift.dart';

class Novels extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get synopsis => text().withDefault(const Constant(''))();
  TextColumn get genre => text().nullable()();
  TextColumn get perspective => text().nullable()();
  TextColumn get styleGuide => text().nullable()();
  TextColumn get accentColorHex => text().nullable()();
  TextColumn get enabledTagIdsJson =>
      text().withDefault(const Constant('[]'))();
  BoolColumn get r18Enabled => boolean().withDefault(const Constant(false))();
  TextColumn get activeStyleProfileId => text().nullable()();
  TextColumn get sourceProfileId => text().nullable()();
  DateTimeColumn get lastStatsDate => dateTime().nullable()();
  IntColumn get lastTotalWordCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Volumes extends Table {
  TextColumn get id => text()();
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get outline => text().nullable()();
  TextColumn get emotionArcJson => text().nullable()();
  TextColumn get conflictLadderJson => text().nullable()();
  TextColumn get infoGapJson => text().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get volumeId =>
      text().references(Volumes, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get detailedOutline => text().nullable()();
  TextColumn get sceneCardsJson => text().nullable()();
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer()();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  BoolColumn get isOriginal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChapterSummaries extends Table {
  TextColumn get chapterId =>
      text().references(Chapters, #id, onDelete: KeyAction.cascade)();
  TextColumn get summaryText => text()();
  TextColumn get keyFactsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {chapterId};
}

class ChapterSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId =>
      text().references(Chapters, #id, onDelete: KeyAction.cascade)();
  IntColumn get versionNumber => integer()();
  TextColumn get content => text()();
  TextColumn get triggerType => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get appearance => text().nullable()();
  TextColumn get personality => text().nullable()();
  TextColumn get background => text().nullable()();
  TextColumn get currentGoal => text().nullable()();
  TextColumn get currentLocation => text().nullable()();
  TextColumn get physicalState => text().nullable()();
  TextColumn get mentalState => text().nullable()();
  TextColumn get lastSeenChapterTitle => text().nullable()();
  TextColumn get camp => text().nullable()();
  TextColumn get role => text().nullable()();
  TextColumn get arcJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isSceneRelevant =>
      boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CharacterRelations extends Table {
  TextColumn get id => text()();
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceCharacterId =>
      text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get targetCharacterId =>
      text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get relationType => text().withDefault(const Constant('未知'))();
  TextColumn get label => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get strength => integer().withDefault(const Constant(3))();
  TextColumn get line => text().withDefault(const Constant('明线'))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get evolutionJson => text().withDefault(const Constant('[]'))();
  IntColumn get firstChapterOrder => integer().nullable()();
  IntColumn get lastChapterOrder => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TimelineEvents extends Table {
  TextColumn get id => text()();
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get volumeId => text().nullable()();
  TextColumn get chapterId => text().nullable()();
  IntColumn get chapterOrder => integer().nullable()();
  TextColumn get chapterRange => text().nullable()();
  TextColumn get inWorldTime => text().nullable()();
  TextColumn get phase => text().nullable()();
  TextColumn get title => text()();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get location => text().nullable()();
  TextColumn get participantsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get linkedForeshadowingIdsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get importance => text().withDefault(const Constant('normal'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class WorldEntries extends Table {
  TextColumn get id => text()();
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get category => text()();
  TextColumn get name => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get keywordsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isAlwaysOn => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Foreshadowings extends Table {
  TextColumn get id => text()();
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get detail => text().nullable()();
  IntColumn get plantedVolumeIndex => integer().nullable()();
  IntColumn get plantedChapterOrder => integer().nullable()();
  TextColumn get plannedResolve => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get note => text().nullable()();
  TextColumn get involvedCharactersJson =>
      text().withDefault(const Constant('[]'))();
  IntColumn get resolvedChapterOrder => integer().nullable()();
  TextColumn get payoffDetail => text().nullable()();
  BoolColumn get suggestedResolved =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChatThreads extends Table {
  TextColumn get id => text()();
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get purpose => text()();
  BoolColumn get skipsClarification =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get threadId =>
      text().references(ChatThreads, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProviderRecord')
class Providers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get apiKeyId => text()();
  TextColumn get modelName => text()();
  RealColumn get temperature => real().withDefault(const Constant(0.8))();
  IntColumn get maxTokens => integer().withDefault(const Constant(16384))();
  IntColumn get contextBudgetChars =>
      integer().withDefault(const Constant(60000))();
  TextColumn get systemPromptExtra => text().nullable()();
  TextColumn get proxyUrl => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StyleProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SourceProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PromptOverrides extends Table {
  TextColumn get promptId => text()();
  TextColumn get content => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {promptId};
}

class PromptTagCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get tagsJson => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CreationSessionCaches extends Table {
  TextColumn get threadId =>
      text().references(ChatThreads, #id, onDelete: KeyAction.cascade)();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {threadId};
}

class StyleDistillCaches extends Table {
  TextColumn get slot => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {slot};
}

class ScanTasks extends Table {
  TextColumn get profileId => text()();
  TextColumn get title => text()();
  TextColumn get mode => text()();
  IntColumn get batchSize => integer()();
  BoolColumn get isContinuation =>
      boolean().withDefault(const Constant(false))();
  IntColumn get totalChunks => integer()();
  TextColumn get providerName => text()();
  TextColumn get providerBaseUrl => text()();
  TextColumn get providerModel => text()();
  TextColumn get providerKeyId => text()();
  DateTimeColumn get startedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {profileId};
}

class ScanChunks extends Table {
  TextColumn get profileId => text()();
  IntColumn get idx => integer()();
  TextColumn get status => text()();
  TextColumn get payloadJson => text().nullable()();
  IntColumn get tokensIn => integer().withDefault(const Constant(0))();
  IntColumn get tokensOut => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {profileId, idx};
}

class ScanReduces extends Table {
  TextColumn get profileId => text()();
  IntColumn get seq => integer()();
  TextColumn get summaryText => text()();

  @override
  Set<Column<Object>> get primaryKey => {profileId, seq};
}

class ScanMetas extends Table {
  TextColumn get profileId => text()();
  TextColumn get metaKey => text()();
  IntColumn get metaValue => integer()();

  @override
  Set<Column<Object>> get primaryKey => {profileId, metaKey};
}
