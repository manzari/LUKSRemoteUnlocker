import 'package:drift/drift.dart';
import 'package:unlock_core/unlock_core.dart';

import 'database.steps.dart';

part 'database.g.dart';

@DataClassName('SshKeyRow')
class SshKeys extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get keyType => text()();
  IntColumn get bits => integer()();
  TextColumn get publicLine => text()();
  TextColumn get fingerprint => text().unique()();
  TextColumn get vaultRecordId => text().references(VaultRecords, #id)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SecretRow')
class Secrets extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get vaultRecordId => text().references(VaultRecords, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get builtIn => boolean()();
  TextColumn get driver => text()();
  TextColumn get command => text()();
  TextColumn get promptRegex => text().nullable()();
  TextColumn get successRegex => text().nullable()();
  TextColumn get failureRegex => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Endpoints, disk overrides and host keys are JSON from the core models' toJson.
@DataClassName('HostRow')
class Hosts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get groupName => text().nullable()();
  TextColumn get prebootJson => text()();
  TextColumn get loginUser => text()();
  TextColumn get keyId => text().nullable().references(SshKeys, #id)();
  TextColumn get secretId => text().nullable().references(Secrets, #id)();
  TextColumn get diskOverridesJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get profileId => text().nullable().references(Profiles, #id)();
  TextColumn get postbootHost => text().nullable()();
  IntColumn get postbootPort => integer()();
  TextColumn get postbootCheck => text()();
  IntColumn get waitTimeoutSeconds => integer()();
  IntColumn get bootTimeoutSeconds => integer()();
  TextColumn get prebootKeyJson => text().nullable()();
  TextColumn get postbootKeyJson => text().nullable()();
  BoolColumn get legacyAlgorithms => boolean()();
  BoolColumn get enabled => boolean()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('VaultRecordRow')
class VaultRecords extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  BlobColumn get nonce => blob()();
  BlobColumn get ciphertext => blob()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PasswordSlotRow')
class VaultPasswordSlot extends Table {
  IntColumn get id => integer()();
  BlobColumn get salt => blob()();
  IntColumn get memoryKib => integer()();
  IntColumn get iterations => integer()();
  IntColumn get parallelism => integer()();
  BlobColumn get nonce => blob()();
  BlobColumn get wrappedKey => blob()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

@DataClassName('VaultMetadataRow')
class VaultMetadataTable extends Table {
  @override
  String get tableName => 'vault_metadata';

  IntColumn get id => integer()();
  IntColumn get formatVersion => integer()();
  TextColumn get vaultId => text()();
  BlobColumn get keyCheckNonce => blob()();
  BlobColumn get keyCheck => blob()();
  BoolColumn get biometricSlotEnrolled => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('RunRow')
class Runs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One host of a run; host name is a snapshot, the host may be deleted later.
@DataClassName('RunHostRow')
class RunHosts extends Table {
  TextColumn get runId =>
      text().references(Runs, #id, onDelete: KeyAction.cascade)();
  TextColumn get hostId => text()();
  TextColumn get hostName => text()();
  TextColumn get finalState => text().nullable()();

  /// Order of the host within the run.
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Why the run left the host out (no key or passphrase, unreadable record).
  TextColumn get skipReason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {runId, hostId};
}

/// Sanitized host events; messages never contain a run secret.
@DataClassName('RunEventRow')
@TableIndex(name: 'run_events_by_run', columns: {#runId})
class RunEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get runId =>
      text().references(Runs, #id, onDelete: KeyAction.cascade)();
  TextColumn get hostId => text()();
  DateTimeColumn get time => dateTime()();
  TextColumn get phase => text()();
  TextColumn get message => text()();
  TextColumn get result => text().nullable()();
}

@DriftDatabase(
  tables: [
    SshKeys,
    Secrets,
    Profiles,
    Hosts,
    VaultRecords,
    VaultPasswordSlot,
    VaultMetadataTable,
    AppSettings,
    Runs,
    RunHosts,
    RunEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.runHosts, schema.runHosts.position);
        await m.addColumn(schema.runHosts, schema.runHosts.skipReason);
        await m.create(schema.runEventsByRun);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA secure_delete = ON');
      await batch(
        (b) => b.insertAllOnConflictUpdate(profiles, [
          for (final p in UnlockProfile.builtIns) profileCompanion(p),
        ]),
      );
    },
  );

  static ProfilesCompanion profileCompanion(UnlockProfile p) =>
      ProfilesCompanion.insert(
        id: p.id,
        name: p.name,
        builtIn: p.builtIn,
        driver: p.driver.id,
        command: p.command,
        promptRegex: Value(p.promptRegex),
        successRegex: Value(p.successRegex),
        failureRegex: Value(p.failureRegex),
      );
}
