// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $VaultRecordsTable extends VaultRecords
    with TableInfo<$VaultRecordsTable, VaultRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nonceMeta = const VerificationMeta('nonce');
  @override
  late final GeneratedColumn<Uint8List> nonce = GeneratedColumn<Uint8List>(
    'nonce',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ciphertextMeta = const VerificationMeta(
    'ciphertext',
  );
  @override
  late final GeneratedColumn<Uint8List> ciphertext = GeneratedColumn<Uint8List>(
    'ciphertext',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, nonce, ciphertext];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('nonce')) {
      context.handle(
        _nonceMeta,
        nonce.isAcceptableOrUnknown(data['nonce']!, _nonceMeta),
      );
    } else if (isInserting) {
      context.missing(_nonceMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
        _ciphertextMeta,
        ciphertext.isAcceptableOrUnknown(data['ciphertext']!, _ciphertextMeta),
      );
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      nonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}nonce'],
      )!,
      ciphertext: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}ciphertext'],
      )!,
    );
  }

  @override
  $VaultRecordsTable createAlias(String alias) {
    return $VaultRecordsTable(attachedDatabase, alias);
  }
}

class VaultRecordRow extends DataClass implements Insertable<VaultRecordRow> {
  final String id;
  final String kind;
  final Uint8List nonce;
  final Uint8List ciphertext;
  const VaultRecordRow({
    required this.id,
    required this.kind,
    required this.nonce,
    required this.ciphertext,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['nonce'] = Variable<Uint8List>(nonce);
    map['ciphertext'] = Variable<Uint8List>(ciphertext);
    return map;
  }

  VaultRecordsCompanion toCompanion(bool nullToAbsent) {
    return VaultRecordsCompanion(
      id: Value(id),
      kind: Value(kind),
      nonce: Value(nonce),
      ciphertext: Value(ciphertext),
    );
  }

  factory VaultRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultRecordRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      nonce: serializer.fromJson<Uint8List>(json['nonce']),
      ciphertext: serializer.fromJson<Uint8List>(json['ciphertext']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'nonce': serializer.toJson<Uint8List>(nonce),
      'ciphertext': serializer.toJson<Uint8List>(ciphertext),
    };
  }

  VaultRecordRow copyWith({
    String? id,
    String? kind,
    Uint8List? nonce,
    Uint8List? ciphertext,
  }) => VaultRecordRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    nonce: nonce ?? this.nonce,
    ciphertext: ciphertext ?? this.ciphertext,
  );
  VaultRecordRow copyWithCompanion(VaultRecordsCompanion data) {
    return VaultRecordRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      nonce: data.nonce.present ? data.nonce.value : this.nonce,
      ciphertext: data.ciphertext.present
          ? data.ciphertext.value
          : this.ciphertext,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultRecordRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('nonce: $nonce, ')
          ..write('ciphertext: $ciphertext')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    $driftBlobEquality.hash(nonce),
    $driftBlobEquality.hash(ciphertext),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultRecordRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          $driftBlobEquality.equals(other.nonce, this.nonce) &&
          $driftBlobEquality.equals(other.ciphertext, this.ciphertext));
}

class VaultRecordsCompanion extends UpdateCompanion<VaultRecordRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<Uint8List> nonce;
  final Value<Uint8List> ciphertext;
  final Value<int> rowid;
  const VaultRecordsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.nonce = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultRecordsCompanion.insert({
    required String id,
    required String kind,
    required Uint8List nonce,
    required Uint8List ciphertext,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       nonce = Value(nonce),
       ciphertext = Value(ciphertext);
  static Insertable<VaultRecordRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<Uint8List>? nonce,
    Expression<Uint8List>? ciphertext,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (nonce != null) 'nonce': nonce,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<Uint8List>? nonce,
    Value<Uint8List>? ciphertext,
    Value<int>? rowid,
  }) {
    return VaultRecordsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      nonce: nonce ?? this.nonce,
      ciphertext: ciphertext ?? this.ciphertext,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (nonce.present) {
      map['nonce'] = Variable<Uint8List>(nonce.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<Uint8List>(ciphertext.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultRecordsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('nonce: $nonce, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SshKeysTable extends SshKeys with TableInfo<$SshKeysTable, SshKeyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SshKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyTypeMeta = const VerificationMeta(
    'keyType',
  );
  @override
  late final GeneratedColumn<String> keyType = GeneratedColumn<String>(
    'key_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bitsMeta = const VerificationMeta('bits');
  @override
  late final GeneratedColumn<int> bits = GeneratedColumn<int>(
    'bits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicLineMeta = const VerificationMeta(
    'publicLine',
  );
  @override
  late final GeneratedColumn<String> publicLine = GeneratedColumn<String>(
    'public_line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _vaultRecordIdMeta = const VerificationMeta(
    'vaultRecordId',
  );
  @override
  late final GeneratedColumn<String> vaultRecordId = GeneratedColumn<String>(
    'vault_record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vault_records (id)',
    ),
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
    label,
    keyType,
    bits,
    publicLine,
    fingerprint,
    vaultRecordId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ssh_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<SshKeyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('key_type')) {
      context.handle(
        _keyTypeMeta,
        keyType.isAcceptableOrUnknown(data['key_type']!, _keyTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_keyTypeMeta);
    }
    if (data.containsKey('bits')) {
      context.handle(
        _bitsMeta,
        bits.isAcceptableOrUnknown(data['bits']!, _bitsMeta),
      );
    } else if (isInserting) {
      context.missing(_bitsMeta);
    }
    if (data.containsKey('public_line')) {
      context.handle(
        _publicLineMeta,
        publicLine.isAcceptableOrUnknown(data['public_line']!, _publicLineMeta),
      );
    } else if (isInserting) {
      context.missing(_publicLineMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('vault_record_id')) {
      context.handle(
        _vaultRecordIdMeta,
        vaultRecordId.isAcceptableOrUnknown(
          data['vault_record_id']!,
          _vaultRecordIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vaultRecordIdMeta);
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
  SshKeyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SshKeyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      keyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_type'],
      )!,
      bits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bits'],
      )!,
      publicLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_line'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      vaultRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_record_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SshKeysTable createAlias(String alias) {
    return $SshKeysTable(attachedDatabase, alias);
  }
}

class SshKeyRow extends DataClass implements Insertable<SshKeyRow> {
  final String id;
  final String label;
  final String keyType;
  final int bits;
  final String publicLine;
  final String fingerprint;
  final String vaultRecordId;
  final DateTime createdAt;
  const SshKeyRow({
    required this.id,
    required this.label,
    required this.keyType,
    required this.bits,
    required this.publicLine,
    required this.fingerprint,
    required this.vaultRecordId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['key_type'] = Variable<String>(keyType);
    map['bits'] = Variable<int>(bits);
    map['public_line'] = Variable<String>(publicLine);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['vault_record_id'] = Variable<String>(vaultRecordId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SshKeysCompanion toCompanion(bool nullToAbsent) {
    return SshKeysCompanion(
      id: Value(id),
      label: Value(label),
      keyType: Value(keyType),
      bits: Value(bits),
      publicLine: Value(publicLine),
      fingerprint: Value(fingerprint),
      vaultRecordId: Value(vaultRecordId),
      createdAt: Value(createdAt),
    );
  }

  factory SshKeyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SshKeyRow(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      keyType: serializer.fromJson<String>(json['keyType']),
      bits: serializer.fromJson<int>(json['bits']),
      publicLine: serializer.fromJson<String>(json['publicLine']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      vaultRecordId: serializer.fromJson<String>(json['vaultRecordId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'keyType': serializer.toJson<String>(keyType),
      'bits': serializer.toJson<int>(bits),
      'publicLine': serializer.toJson<String>(publicLine),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'vaultRecordId': serializer.toJson<String>(vaultRecordId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SshKeyRow copyWith({
    String? id,
    String? label,
    String? keyType,
    int? bits,
    String? publicLine,
    String? fingerprint,
    String? vaultRecordId,
    DateTime? createdAt,
  }) => SshKeyRow(
    id: id ?? this.id,
    label: label ?? this.label,
    keyType: keyType ?? this.keyType,
    bits: bits ?? this.bits,
    publicLine: publicLine ?? this.publicLine,
    fingerprint: fingerprint ?? this.fingerprint,
    vaultRecordId: vaultRecordId ?? this.vaultRecordId,
    createdAt: createdAt ?? this.createdAt,
  );
  SshKeyRow copyWithCompanion(SshKeysCompanion data) {
    return SshKeyRow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      keyType: data.keyType.present ? data.keyType.value : this.keyType,
      bits: data.bits.present ? data.bits.value : this.bits,
      publicLine: data.publicLine.present
          ? data.publicLine.value
          : this.publicLine,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      vaultRecordId: data.vaultRecordId.present
          ? data.vaultRecordId.value
          : this.vaultRecordId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SshKeyRow(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('keyType: $keyType, ')
          ..write('bits: $bits, ')
          ..write('publicLine: $publicLine, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('vaultRecordId: $vaultRecordId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    keyType,
    bits,
    publicLine,
    fingerprint,
    vaultRecordId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SshKeyRow &&
          other.id == this.id &&
          other.label == this.label &&
          other.keyType == this.keyType &&
          other.bits == this.bits &&
          other.publicLine == this.publicLine &&
          other.fingerprint == this.fingerprint &&
          other.vaultRecordId == this.vaultRecordId &&
          other.createdAt == this.createdAt);
}

class SshKeysCompanion extends UpdateCompanion<SshKeyRow> {
  final Value<String> id;
  final Value<String> label;
  final Value<String> keyType;
  final Value<int> bits;
  final Value<String> publicLine;
  final Value<String> fingerprint;
  final Value<String> vaultRecordId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SshKeysCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.keyType = const Value.absent(),
    this.bits = const Value.absent(),
    this.publicLine = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.vaultRecordId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SshKeysCompanion.insert({
    required String id,
    required String label,
    required String keyType,
    required int bits,
    required String publicLine,
    required String fingerprint,
    required String vaultRecordId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       keyType = Value(keyType),
       bits = Value(bits),
       publicLine = Value(publicLine),
       fingerprint = Value(fingerprint),
       vaultRecordId = Value(vaultRecordId),
       createdAt = Value(createdAt);
  static Insertable<SshKeyRow> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? keyType,
    Expression<int>? bits,
    Expression<String>? publicLine,
    Expression<String>? fingerprint,
    Expression<String>? vaultRecordId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (keyType != null) 'key_type': keyType,
      if (bits != null) 'bits': bits,
      if (publicLine != null) 'public_line': publicLine,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (vaultRecordId != null) 'vault_record_id': vaultRecordId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SshKeysCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<String>? keyType,
    Value<int>? bits,
    Value<String>? publicLine,
    Value<String>? fingerprint,
    Value<String>? vaultRecordId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SshKeysCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      keyType: keyType ?? this.keyType,
      bits: bits ?? this.bits,
      publicLine: publicLine ?? this.publicLine,
      fingerprint: fingerprint ?? this.fingerprint,
      vaultRecordId: vaultRecordId ?? this.vaultRecordId,
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
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (keyType.present) {
      map['key_type'] = Variable<String>(keyType.value);
    }
    if (bits.present) {
      map['bits'] = Variable<int>(bits.value);
    }
    if (publicLine.present) {
      map['public_line'] = Variable<String>(publicLine.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (vaultRecordId.present) {
      map['vault_record_id'] = Variable<String>(vaultRecordId.value);
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
    return (StringBuffer('SshKeysCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('keyType: $keyType, ')
          ..write('bits: $bits, ')
          ..write('publicLine: $publicLine, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('vaultRecordId: $vaultRecordId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SecretsTable extends Secrets with TableInfo<$SecretsTable, SecretRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SecretsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vaultRecordIdMeta = const VerificationMeta(
    'vaultRecordId',
  );
  @override
  late final GeneratedColumn<String> vaultRecordId = GeneratedColumn<String>(
    'vault_record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vault_records (id)',
    ),
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
    label,
    vaultRecordId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'secrets';
  @override
  VerificationContext validateIntegrity(
    Insertable<SecretRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('vault_record_id')) {
      context.handle(
        _vaultRecordIdMeta,
        vaultRecordId.isAcceptableOrUnknown(
          data['vault_record_id']!,
          _vaultRecordIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vaultRecordIdMeta);
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
  SecretRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SecretRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      vaultRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_record_id'],
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
  $SecretsTable createAlias(String alias) {
    return $SecretsTable(attachedDatabase, alias);
  }
}

class SecretRow extends DataClass implements Insertable<SecretRow> {
  final String id;
  final String label;
  final String vaultRecordId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SecretRow({
    required this.id,
    required this.label,
    required this.vaultRecordId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['vault_record_id'] = Variable<String>(vaultRecordId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SecretsCompanion toCompanion(bool nullToAbsent) {
    return SecretsCompanion(
      id: Value(id),
      label: Value(label),
      vaultRecordId: Value(vaultRecordId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SecretRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SecretRow(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      vaultRecordId: serializer.fromJson<String>(json['vaultRecordId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'vaultRecordId': serializer.toJson<String>(vaultRecordId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SecretRow copyWith({
    String? id,
    String? label,
    String? vaultRecordId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SecretRow(
    id: id ?? this.id,
    label: label ?? this.label,
    vaultRecordId: vaultRecordId ?? this.vaultRecordId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SecretRow copyWithCompanion(SecretsCompanion data) {
    return SecretRow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      vaultRecordId: data.vaultRecordId.present
          ? data.vaultRecordId.value
          : this.vaultRecordId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SecretRow(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('vaultRecordId: $vaultRecordId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, label, vaultRecordId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecretRow &&
          other.id == this.id &&
          other.label == this.label &&
          other.vaultRecordId == this.vaultRecordId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SecretsCompanion extends UpdateCompanion<SecretRow> {
  final Value<String> id;
  final Value<String> label;
  final Value<String> vaultRecordId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SecretsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.vaultRecordId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SecretsCompanion.insert({
    required String id,
    required String label,
    required String vaultRecordId,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       vaultRecordId = Value(vaultRecordId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SecretRow> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? vaultRecordId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (vaultRecordId != null) 'vault_record_id': vaultRecordId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SecretsCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<String>? vaultRecordId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SecretsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      vaultRecordId: vaultRecordId ?? this.vaultRecordId,
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
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (vaultRecordId.present) {
      map['vault_record_id'] = Variable<String>(vaultRecordId.value);
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
    return (StringBuffer('SecretsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('vaultRecordId: $vaultRecordId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _builtInMeta = const VerificationMeta(
    'builtIn',
  );
  @override
  late final GeneratedColumn<bool> builtIn = GeneratedColumn<bool>(
    'built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("built_in" IN (0, 1))',
    ),
  );
  static const VerificationMeta _driverMeta = const VerificationMeta('driver');
  @override
  late final GeneratedColumn<String> driver = GeneratedColumn<String>(
    'driver',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandMeta = const VerificationMeta(
    'command',
  );
  @override
  late final GeneratedColumn<String> command = GeneratedColumn<String>(
    'command',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptRegexMeta = const VerificationMeta(
    'promptRegex',
  );
  @override
  late final GeneratedColumn<String> promptRegex = GeneratedColumn<String>(
    'prompt_regex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _successRegexMeta = const VerificationMeta(
    'successRegex',
  );
  @override
  late final GeneratedColumn<String> successRegex = GeneratedColumn<String>(
    'success_regex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureRegexMeta = const VerificationMeta(
    'failureRegex',
  );
  @override
  late final GeneratedColumn<String> failureRegex = GeneratedColumn<String>(
    'failure_regex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    builtIn,
    driver,
    command,
    promptRegex,
    successRegex,
    failureRegex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
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
    if (data.containsKey('built_in')) {
      context.handle(
        _builtInMeta,
        builtIn.isAcceptableOrUnknown(data['built_in']!, _builtInMeta),
      );
    } else if (isInserting) {
      context.missing(_builtInMeta);
    }
    if (data.containsKey('driver')) {
      context.handle(
        _driverMeta,
        driver.isAcceptableOrUnknown(data['driver']!, _driverMeta),
      );
    } else if (isInserting) {
      context.missing(_driverMeta);
    }
    if (data.containsKey('command')) {
      context.handle(
        _commandMeta,
        command.isAcceptableOrUnknown(data['command']!, _commandMeta),
      );
    } else if (isInserting) {
      context.missing(_commandMeta);
    }
    if (data.containsKey('prompt_regex')) {
      context.handle(
        _promptRegexMeta,
        promptRegex.isAcceptableOrUnknown(
          data['prompt_regex']!,
          _promptRegexMeta,
        ),
      );
    }
    if (data.containsKey('success_regex')) {
      context.handle(
        _successRegexMeta,
        successRegex.isAcceptableOrUnknown(
          data['success_regex']!,
          _successRegexMeta,
        ),
      );
    }
    if (data.containsKey('failure_regex')) {
      context.handle(
        _failureRegexMeta,
        failureRegex.isAcceptableOrUnknown(
          data['failure_regex']!,
          _failureRegexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      builtIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}built_in'],
      )!,
      driver: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver'],
      )!,
      command: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command'],
      )!,
      promptRegex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_regex'],
      ),
      successRegex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}success_regex'],
      ),
      failureRegex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_regex'],
      ),
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String id;
  final String name;
  final bool builtIn;
  final String driver;
  final String command;
  final String? promptRegex;
  final String? successRegex;
  final String? failureRegex;
  const ProfileRow({
    required this.id,
    required this.name,
    required this.builtIn,
    required this.driver,
    required this.command,
    this.promptRegex,
    this.successRegex,
    this.failureRegex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['built_in'] = Variable<bool>(builtIn);
    map['driver'] = Variable<String>(driver);
    map['command'] = Variable<String>(command);
    if (!nullToAbsent || promptRegex != null) {
      map['prompt_regex'] = Variable<String>(promptRegex);
    }
    if (!nullToAbsent || successRegex != null) {
      map['success_regex'] = Variable<String>(successRegex);
    }
    if (!nullToAbsent || failureRegex != null) {
      map['failure_regex'] = Variable<String>(failureRegex);
    }
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      builtIn: Value(builtIn),
      driver: Value(driver),
      command: Value(command),
      promptRegex: promptRegex == null && nullToAbsent
          ? const Value.absent()
          : Value(promptRegex),
      successRegex: successRegex == null && nullToAbsent
          ? const Value.absent()
          : Value(successRegex),
      failureRegex: failureRegex == null && nullToAbsent
          ? const Value.absent()
          : Value(failureRegex),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      builtIn: serializer.fromJson<bool>(json['builtIn']),
      driver: serializer.fromJson<String>(json['driver']),
      command: serializer.fromJson<String>(json['command']),
      promptRegex: serializer.fromJson<String?>(json['promptRegex']),
      successRegex: serializer.fromJson<String?>(json['successRegex']),
      failureRegex: serializer.fromJson<String?>(json['failureRegex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'builtIn': serializer.toJson<bool>(builtIn),
      'driver': serializer.toJson<String>(driver),
      'command': serializer.toJson<String>(command),
      'promptRegex': serializer.toJson<String?>(promptRegex),
      'successRegex': serializer.toJson<String?>(successRegex),
      'failureRegex': serializer.toJson<String?>(failureRegex),
    };
  }

  ProfileRow copyWith({
    String? id,
    String? name,
    bool? builtIn,
    String? driver,
    String? command,
    Value<String?> promptRegex = const Value.absent(),
    Value<String?> successRegex = const Value.absent(),
    Value<String?> failureRegex = const Value.absent(),
  }) => ProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    builtIn: builtIn ?? this.builtIn,
    driver: driver ?? this.driver,
    command: command ?? this.command,
    promptRegex: promptRegex.present ? promptRegex.value : this.promptRegex,
    successRegex: successRegex.present ? successRegex.value : this.successRegex,
    failureRegex: failureRegex.present ? failureRegex.value : this.failureRegex,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      builtIn: data.builtIn.present ? data.builtIn.value : this.builtIn,
      driver: data.driver.present ? data.driver.value : this.driver,
      command: data.command.present ? data.command.value : this.command,
      promptRegex: data.promptRegex.present
          ? data.promptRegex.value
          : this.promptRegex,
      successRegex: data.successRegex.present
          ? data.successRegex.value
          : this.successRegex,
      failureRegex: data.failureRegex.present
          ? data.failureRegex.value
          : this.failureRegex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('builtIn: $builtIn, ')
          ..write('driver: $driver, ')
          ..write('command: $command, ')
          ..write('promptRegex: $promptRegex, ')
          ..write('successRegex: $successRegex, ')
          ..write('failureRegex: $failureRegex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    builtIn,
    driver,
    command,
    promptRegex,
    successRegex,
    failureRegex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.builtIn == this.builtIn &&
          other.driver == this.driver &&
          other.command == this.command &&
          other.promptRegex == this.promptRegex &&
          other.successRegex == this.successRegex &&
          other.failureRegex == this.failureRegex);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> builtIn;
  final Value<String> driver;
  final Value<String> command;
  final Value<String?> promptRegex;
  final Value<String?> successRegex;
  final Value<String?> failureRegex;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.builtIn = const Value.absent(),
    this.driver = const Value.absent(),
    this.command = const Value.absent(),
    this.promptRegex = const Value.absent(),
    this.successRegex = const Value.absent(),
    this.failureRegex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String name,
    required bool builtIn,
    required String driver,
    required String command,
    this.promptRegex = const Value.absent(),
    this.successRegex = const Value.absent(),
    this.failureRegex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       builtIn = Value(builtIn),
       driver = Value(driver),
       command = Value(command);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? builtIn,
    Expression<String>? driver,
    Expression<String>? command,
    Expression<String>? promptRegex,
    Expression<String>? successRegex,
    Expression<String>? failureRegex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (builtIn != null) 'built_in': builtIn,
      if (driver != null) 'driver': driver,
      if (command != null) 'command': command,
      if (promptRegex != null) 'prompt_regex': promptRegex,
      if (successRegex != null) 'success_regex': successRegex,
      if (failureRegex != null) 'failure_regex': failureRegex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<bool>? builtIn,
    Value<String>? driver,
    Value<String>? command,
    Value<String?>? promptRegex,
    Value<String?>? successRegex,
    Value<String?>? failureRegex,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      builtIn: builtIn ?? this.builtIn,
      driver: driver ?? this.driver,
      command: command ?? this.command,
      promptRegex: promptRegex ?? this.promptRegex,
      successRegex: successRegex ?? this.successRegex,
      failureRegex: failureRegex ?? this.failureRegex,
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
    if (builtIn.present) {
      map['built_in'] = Variable<bool>(builtIn.value);
    }
    if (driver.present) {
      map['driver'] = Variable<String>(driver.value);
    }
    if (command.present) {
      map['command'] = Variable<String>(command.value);
    }
    if (promptRegex.present) {
      map['prompt_regex'] = Variable<String>(promptRegex.value);
    }
    if (successRegex.present) {
      map['success_regex'] = Variable<String>(successRegex.value);
    }
    if (failureRegex.present) {
      map['failure_regex'] = Variable<String>(failureRegex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('builtIn: $builtIn, ')
          ..write('driver: $driver, ')
          ..write('command: $command, ')
          ..write('promptRegex: $promptRegex, ')
          ..write('successRegex: $successRegex, ')
          ..write('failureRegex: $failureRegex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HostsTable extends Hosts with TableInfo<$HostsTable, HostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HostsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prebootJsonMeta = const VerificationMeta(
    'prebootJson',
  );
  @override
  late final GeneratedColumn<String> prebootJson = GeneratedColumn<String>(
    'preboot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loginUserMeta = const VerificationMeta(
    'loginUser',
  );
  @override
  late final GeneratedColumn<String> loginUser = GeneratedColumn<String>(
    'login_user',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyIdMeta = const VerificationMeta('keyId');
  @override
  late final GeneratedColumn<String> keyId = GeneratedColumn<String>(
    'key_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ssh_keys (id)',
    ),
  );
  static const VerificationMeta _secretIdMeta = const VerificationMeta(
    'secretId',
  );
  @override
  late final GeneratedColumn<String> secretId = GeneratedColumn<String>(
    'secret_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES secrets (id)',
    ),
  );
  static const VerificationMeta _diskOverridesJsonMeta = const VerificationMeta(
    'diskOverridesJson',
  );
  @override
  late final GeneratedColumn<String> diskOverridesJson =
      GeneratedColumn<String>(
        'disk_overrides_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _postbootHostMeta = const VerificationMeta(
    'postbootHost',
  );
  @override
  late final GeneratedColumn<String> postbootHost = GeneratedColumn<String>(
    'postboot_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _postbootPortMeta = const VerificationMeta(
    'postbootPort',
  );
  @override
  late final GeneratedColumn<int> postbootPort = GeneratedColumn<int>(
    'postboot_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postbootCheckMeta = const VerificationMeta(
    'postbootCheck',
  );
  @override
  late final GeneratedColumn<String> postbootCheck = GeneratedColumn<String>(
    'postboot_check',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _waitTimeoutSecondsMeta =
      const VerificationMeta('waitTimeoutSeconds');
  @override
  late final GeneratedColumn<int> waitTimeoutSeconds = GeneratedColumn<int>(
    'wait_timeout_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bootTimeoutSecondsMeta =
      const VerificationMeta('bootTimeoutSeconds');
  @override
  late final GeneratedColumn<int> bootTimeoutSeconds = GeneratedColumn<int>(
    'boot_timeout_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prebootKeyJsonMeta = const VerificationMeta(
    'prebootKeyJson',
  );
  @override
  late final GeneratedColumn<String> prebootKeyJson = GeneratedColumn<String>(
    'preboot_key_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _postbootKeyJsonMeta = const VerificationMeta(
    'postbootKeyJson',
  );
  @override
  late final GeneratedColumn<String> postbootKeyJson = GeneratedColumn<String>(
    'postboot_key_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _legacyAlgorithmsMeta = const VerificationMeta(
    'legacyAlgorithms',
  );
  @override
  late final GeneratedColumn<bool> legacyAlgorithms = GeneratedColumn<bool>(
    'legacy_algorithms',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("legacy_algorithms" IN (0, 1))',
    ),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
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
    groupName,
    prebootJson,
    loginUser,
    keyId,
    secretId,
    diskOverridesJson,
    profileId,
    postbootHost,
    postbootPort,
    postbootCheck,
    waitTimeoutSeconds,
    bootTimeoutSeconds,
    prebootKeyJson,
    postbootKeyJson,
    legacyAlgorithms,
    enabled,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hosts';
  @override
  VerificationContext validateIntegrity(
    Insertable<HostRow> instance, {
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
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('preboot_json')) {
      context.handle(
        _prebootJsonMeta,
        prebootJson.isAcceptableOrUnknown(
          data['preboot_json']!,
          _prebootJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prebootJsonMeta);
    }
    if (data.containsKey('login_user')) {
      context.handle(
        _loginUserMeta,
        loginUser.isAcceptableOrUnknown(data['login_user']!, _loginUserMeta),
      );
    } else if (isInserting) {
      context.missing(_loginUserMeta);
    }
    if (data.containsKey('key_id')) {
      context.handle(
        _keyIdMeta,
        keyId.isAcceptableOrUnknown(data['key_id']!, _keyIdMeta),
      );
    }
    if (data.containsKey('secret_id')) {
      context.handle(
        _secretIdMeta,
        secretId.isAcceptableOrUnknown(data['secret_id']!, _secretIdMeta),
      );
    }
    if (data.containsKey('disk_overrides_json')) {
      context.handle(
        _diskOverridesJsonMeta,
        diskOverridesJson.isAcceptableOrUnknown(
          data['disk_overrides_json']!,
          _diskOverridesJsonMeta,
        ),
      );
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('postboot_host')) {
      context.handle(
        _postbootHostMeta,
        postbootHost.isAcceptableOrUnknown(
          data['postboot_host']!,
          _postbootHostMeta,
        ),
      );
    }
    if (data.containsKey('postboot_port')) {
      context.handle(
        _postbootPortMeta,
        postbootPort.isAcceptableOrUnknown(
          data['postboot_port']!,
          _postbootPortMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_postbootPortMeta);
    }
    if (data.containsKey('postboot_check')) {
      context.handle(
        _postbootCheckMeta,
        postbootCheck.isAcceptableOrUnknown(
          data['postboot_check']!,
          _postbootCheckMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_postbootCheckMeta);
    }
    if (data.containsKey('wait_timeout_seconds')) {
      context.handle(
        _waitTimeoutSecondsMeta,
        waitTimeoutSeconds.isAcceptableOrUnknown(
          data['wait_timeout_seconds']!,
          _waitTimeoutSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_waitTimeoutSecondsMeta);
    }
    if (data.containsKey('boot_timeout_seconds')) {
      context.handle(
        _bootTimeoutSecondsMeta,
        bootTimeoutSeconds.isAcceptableOrUnknown(
          data['boot_timeout_seconds']!,
          _bootTimeoutSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bootTimeoutSecondsMeta);
    }
    if (data.containsKey('preboot_key_json')) {
      context.handle(
        _prebootKeyJsonMeta,
        prebootKeyJson.isAcceptableOrUnknown(
          data['preboot_key_json']!,
          _prebootKeyJsonMeta,
        ),
      );
    }
    if (data.containsKey('postboot_key_json')) {
      context.handle(
        _postbootKeyJsonMeta,
        postbootKeyJson.isAcceptableOrUnknown(
          data['postboot_key_json']!,
          _postbootKeyJsonMeta,
        ),
      );
    }
    if (data.containsKey('legacy_algorithms')) {
      context.handle(
        _legacyAlgorithmsMeta,
        legacyAlgorithms.isAcceptableOrUnknown(
          data['legacy_algorithms']!,
          _legacyAlgorithmsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legacyAlgorithmsMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    } else if (isInserting) {
      context.missing(_enabledMeta);
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
  HostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HostRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      prebootJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preboot_json'],
      )!,
      loginUser: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}login_user'],
      )!,
      keyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_id'],
      ),
      secretId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secret_id'],
      ),
      diskOverridesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}disk_overrides_json'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      ),
      postbootHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}postboot_host'],
      ),
      postbootPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}postboot_port'],
      )!,
      postbootCheck: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}postboot_check'],
      )!,
      waitTimeoutSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wait_timeout_seconds'],
      )!,
      bootTimeoutSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}boot_timeout_seconds'],
      )!,
      prebootKeyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preboot_key_json'],
      ),
      postbootKeyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}postboot_key_json'],
      ),
      legacyAlgorithms: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}legacy_algorithms'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HostsTable createAlias(String alias) {
    return $HostsTable(attachedDatabase, alias);
  }
}

class HostRow extends DataClass implements Insertable<HostRow> {
  final String id;
  final String name;
  final String? groupName;
  final String prebootJson;
  final String loginUser;
  final String? keyId;
  final String? secretId;
  final String diskOverridesJson;
  final String? profileId;
  final String? postbootHost;
  final int postbootPort;
  final String postbootCheck;
  final int waitTimeoutSeconds;
  final int bootTimeoutSeconds;
  final String? prebootKeyJson;
  final String? postbootKeyJson;
  final bool legacyAlgorithms;
  final bool enabled;
  final DateTime createdAt;
  const HostRow({
    required this.id,
    required this.name,
    this.groupName,
    required this.prebootJson,
    required this.loginUser,
    this.keyId,
    this.secretId,
    required this.diskOverridesJson,
    this.profileId,
    this.postbootHost,
    required this.postbootPort,
    required this.postbootCheck,
    required this.waitTimeoutSeconds,
    required this.bootTimeoutSeconds,
    this.prebootKeyJson,
    this.postbootKeyJson,
    required this.legacyAlgorithms,
    required this.enabled,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    map['preboot_json'] = Variable<String>(prebootJson);
    map['login_user'] = Variable<String>(loginUser);
    if (!nullToAbsent || keyId != null) {
      map['key_id'] = Variable<String>(keyId);
    }
    if (!nullToAbsent || secretId != null) {
      map['secret_id'] = Variable<String>(secretId);
    }
    map['disk_overrides_json'] = Variable<String>(diskOverridesJson);
    if (!nullToAbsent || profileId != null) {
      map['profile_id'] = Variable<String>(profileId);
    }
    if (!nullToAbsent || postbootHost != null) {
      map['postboot_host'] = Variable<String>(postbootHost);
    }
    map['postboot_port'] = Variable<int>(postbootPort);
    map['postboot_check'] = Variable<String>(postbootCheck);
    map['wait_timeout_seconds'] = Variable<int>(waitTimeoutSeconds);
    map['boot_timeout_seconds'] = Variable<int>(bootTimeoutSeconds);
    if (!nullToAbsent || prebootKeyJson != null) {
      map['preboot_key_json'] = Variable<String>(prebootKeyJson);
    }
    if (!nullToAbsent || postbootKeyJson != null) {
      map['postboot_key_json'] = Variable<String>(postbootKeyJson);
    }
    map['legacy_algorithms'] = Variable<bool>(legacyAlgorithms);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HostsCompanion toCompanion(bool nullToAbsent) {
    return HostsCompanion(
      id: Value(id),
      name: Value(name),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      prebootJson: Value(prebootJson),
      loginUser: Value(loginUser),
      keyId: keyId == null && nullToAbsent
          ? const Value.absent()
          : Value(keyId),
      secretId: secretId == null && nullToAbsent
          ? const Value.absent()
          : Value(secretId),
      diskOverridesJson: Value(diskOverridesJson),
      profileId: profileId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileId),
      postbootHost: postbootHost == null && nullToAbsent
          ? const Value.absent()
          : Value(postbootHost),
      postbootPort: Value(postbootPort),
      postbootCheck: Value(postbootCheck),
      waitTimeoutSeconds: Value(waitTimeoutSeconds),
      bootTimeoutSeconds: Value(bootTimeoutSeconds),
      prebootKeyJson: prebootKeyJson == null && nullToAbsent
          ? const Value.absent()
          : Value(prebootKeyJson),
      postbootKeyJson: postbootKeyJson == null && nullToAbsent
          ? const Value.absent()
          : Value(postbootKeyJson),
      legacyAlgorithms: Value(legacyAlgorithms),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
    );
  }

  factory HostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HostRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      prebootJson: serializer.fromJson<String>(json['prebootJson']),
      loginUser: serializer.fromJson<String>(json['loginUser']),
      keyId: serializer.fromJson<String?>(json['keyId']),
      secretId: serializer.fromJson<String?>(json['secretId']),
      diskOverridesJson: serializer.fromJson<String>(json['diskOverridesJson']),
      profileId: serializer.fromJson<String?>(json['profileId']),
      postbootHost: serializer.fromJson<String?>(json['postbootHost']),
      postbootPort: serializer.fromJson<int>(json['postbootPort']),
      postbootCheck: serializer.fromJson<String>(json['postbootCheck']),
      waitTimeoutSeconds: serializer.fromJson<int>(json['waitTimeoutSeconds']),
      bootTimeoutSeconds: serializer.fromJson<int>(json['bootTimeoutSeconds']),
      prebootKeyJson: serializer.fromJson<String?>(json['prebootKeyJson']),
      postbootKeyJson: serializer.fromJson<String?>(json['postbootKeyJson']),
      legacyAlgorithms: serializer.fromJson<bool>(json['legacyAlgorithms']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'groupName': serializer.toJson<String?>(groupName),
      'prebootJson': serializer.toJson<String>(prebootJson),
      'loginUser': serializer.toJson<String>(loginUser),
      'keyId': serializer.toJson<String?>(keyId),
      'secretId': serializer.toJson<String?>(secretId),
      'diskOverridesJson': serializer.toJson<String>(diskOverridesJson),
      'profileId': serializer.toJson<String?>(profileId),
      'postbootHost': serializer.toJson<String?>(postbootHost),
      'postbootPort': serializer.toJson<int>(postbootPort),
      'postbootCheck': serializer.toJson<String>(postbootCheck),
      'waitTimeoutSeconds': serializer.toJson<int>(waitTimeoutSeconds),
      'bootTimeoutSeconds': serializer.toJson<int>(bootTimeoutSeconds),
      'prebootKeyJson': serializer.toJson<String?>(prebootKeyJson),
      'postbootKeyJson': serializer.toJson<String?>(postbootKeyJson),
      'legacyAlgorithms': serializer.toJson<bool>(legacyAlgorithms),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HostRow copyWith({
    String? id,
    String? name,
    Value<String?> groupName = const Value.absent(),
    String? prebootJson,
    String? loginUser,
    Value<String?> keyId = const Value.absent(),
    Value<String?> secretId = const Value.absent(),
    String? diskOverridesJson,
    Value<String?> profileId = const Value.absent(),
    Value<String?> postbootHost = const Value.absent(),
    int? postbootPort,
    String? postbootCheck,
    int? waitTimeoutSeconds,
    int? bootTimeoutSeconds,
    Value<String?> prebootKeyJson = const Value.absent(),
    Value<String?> postbootKeyJson = const Value.absent(),
    bool? legacyAlgorithms,
    bool? enabled,
    DateTime? createdAt,
  }) => HostRow(
    id: id ?? this.id,
    name: name ?? this.name,
    groupName: groupName.present ? groupName.value : this.groupName,
    prebootJson: prebootJson ?? this.prebootJson,
    loginUser: loginUser ?? this.loginUser,
    keyId: keyId.present ? keyId.value : this.keyId,
    secretId: secretId.present ? secretId.value : this.secretId,
    diskOverridesJson: diskOverridesJson ?? this.diskOverridesJson,
    profileId: profileId.present ? profileId.value : this.profileId,
    postbootHost: postbootHost.present ? postbootHost.value : this.postbootHost,
    postbootPort: postbootPort ?? this.postbootPort,
    postbootCheck: postbootCheck ?? this.postbootCheck,
    waitTimeoutSeconds: waitTimeoutSeconds ?? this.waitTimeoutSeconds,
    bootTimeoutSeconds: bootTimeoutSeconds ?? this.bootTimeoutSeconds,
    prebootKeyJson: prebootKeyJson.present
        ? prebootKeyJson.value
        : this.prebootKeyJson,
    postbootKeyJson: postbootKeyJson.present
        ? postbootKeyJson.value
        : this.postbootKeyJson,
    legacyAlgorithms: legacyAlgorithms ?? this.legacyAlgorithms,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
  );
  HostRow copyWithCompanion(HostsCompanion data) {
    return HostRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      prebootJson: data.prebootJson.present
          ? data.prebootJson.value
          : this.prebootJson,
      loginUser: data.loginUser.present ? data.loginUser.value : this.loginUser,
      keyId: data.keyId.present ? data.keyId.value : this.keyId,
      secretId: data.secretId.present ? data.secretId.value : this.secretId,
      diskOverridesJson: data.diskOverridesJson.present
          ? data.diskOverridesJson.value
          : this.diskOverridesJson,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      postbootHost: data.postbootHost.present
          ? data.postbootHost.value
          : this.postbootHost,
      postbootPort: data.postbootPort.present
          ? data.postbootPort.value
          : this.postbootPort,
      postbootCheck: data.postbootCheck.present
          ? data.postbootCheck.value
          : this.postbootCheck,
      waitTimeoutSeconds: data.waitTimeoutSeconds.present
          ? data.waitTimeoutSeconds.value
          : this.waitTimeoutSeconds,
      bootTimeoutSeconds: data.bootTimeoutSeconds.present
          ? data.bootTimeoutSeconds.value
          : this.bootTimeoutSeconds,
      prebootKeyJson: data.prebootKeyJson.present
          ? data.prebootKeyJson.value
          : this.prebootKeyJson,
      postbootKeyJson: data.postbootKeyJson.present
          ? data.postbootKeyJson.value
          : this.postbootKeyJson,
      legacyAlgorithms: data.legacyAlgorithms.present
          ? data.legacyAlgorithms.value
          : this.legacyAlgorithms,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HostRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupName: $groupName, ')
          ..write('prebootJson: $prebootJson, ')
          ..write('loginUser: $loginUser, ')
          ..write('keyId: $keyId, ')
          ..write('secretId: $secretId, ')
          ..write('diskOverridesJson: $diskOverridesJson, ')
          ..write('profileId: $profileId, ')
          ..write('postbootHost: $postbootHost, ')
          ..write('postbootPort: $postbootPort, ')
          ..write('postbootCheck: $postbootCheck, ')
          ..write('waitTimeoutSeconds: $waitTimeoutSeconds, ')
          ..write('bootTimeoutSeconds: $bootTimeoutSeconds, ')
          ..write('prebootKeyJson: $prebootKeyJson, ')
          ..write('postbootKeyJson: $postbootKeyJson, ')
          ..write('legacyAlgorithms: $legacyAlgorithms, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    groupName,
    prebootJson,
    loginUser,
    keyId,
    secretId,
    diskOverridesJson,
    profileId,
    postbootHost,
    postbootPort,
    postbootCheck,
    waitTimeoutSeconds,
    bootTimeoutSeconds,
    prebootKeyJson,
    postbootKeyJson,
    legacyAlgorithms,
    enabled,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HostRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.groupName == this.groupName &&
          other.prebootJson == this.prebootJson &&
          other.loginUser == this.loginUser &&
          other.keyId == this.keyId &&
          other.secretId == this.secretId &&
          other.diskOverridesJson == this.diskOverridesJson &&
          other.profileId == this.profileId &&
          other.postbootHost == this.postbootHost &&
          other.postbootPort == this.postbootPort &&
          other.postbootCheck == this.postbootCheck &&
          other.waitTimeoutSeconds == this.waitTimeoutSeconds &&
          other.bootTimeoutSeconds == this.bootTimeoutSeconds &&
          other.prebootKeyJson == this.prebootKeyJson &&
          other.postbootKeyJson == this.postbootKeyJson &&
          other.legacyAlgorithms == this.legacyAlgorithms &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt);
}

class HostsCompanion extends UpdateCompanion<HostRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> groupName;
  final Value<String> prebootJson;
  final Value<String> loginUser;
  final Value<String?> keyId;
  final Value<String?> secretId;
  final Value<String> diskOverridesJson;
  final Value<String?> profileId;
  final Value<String?> postbootHost;
  final Value<int> postbootPort;
  final Value<String> postbootCheck;
  final Value<int> waitTimeoutSeconds;
  final Value<int> bootTimeoutSeconds;
  final Value<String?> prebootKeyJson;
  final Value<String?> postbootKeyJson;
  final Value<bool> legacyAlgorithms;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const HostsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.groupName = const Value.absent(),
    this.prebootJson = const Value.absent(),
    this.loginUser = const Value.absent(),
    this.keyId = const Value.absent(),
    this.secretId = const Value.absent(),
    this.diskOverridesJson = const Value.absent(),
    this.profileId = const Value.absent(),
    this.postbootHost = const Value.absent(),
    this.postbootPort = const Value.absent(),
    this.postbootCheck = const Value.absent(),
    this.waitTimeoutSeconds = const Value.absent(),
    this.bootTimeoutSeconds = const Value.absent(),
    this.prebootKeyJson = const Value.absent(),
    this.postbootKeyJson = const Value.absent(),
    this.legacyAlgorithms = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HostsCompanion.insert({
    required String id,
    required String name,
    this.groupName = const Value.absent(),
    required String prebootJson,
    required String loginUser,
    this.keyId = const Value.absent(),
    this.secretId = const Value.absent(),
    this.diskOverridesJson = const Value.absent(),
    this.profileId = const Value.absent(),
    this.postbootHost = const Value.absent(),
    required int postbootPort,
    required String postbootCheck,
    required int waitTimeoutSeconds,
    required int bootTimeoutSeconds,
    this.prebootKeyJson = const Value.absent(),
    this.postbootKeyJson = const Value.absent(),
    required bool legacyAlgorithms,
    required bool enabled,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       prebootJson = Value(prebootJson),
       loginUser = Value(loginUser),
       postbootPort = Value(postbootPort),
       postbootCheck = Value(postbootCheck),
       waitTimeoutSeconds = Value(waitTimeoutSeconds),
       bootTimeoutSeconds = Value(bootTimeoutSeconds),
       legacyAlgorithms = Value(legacyAlgorithms),
       enabled = Value(enabled),
       createdAt = Value(createdAt);
  static Insertable<HostRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? groupName,
    Expression<String>? prebootJson,
    Expression<String>? loginUser,
    Expression<String>? keyId,
    Expression<String>? secretId,
    Expression<String>? diskOverridesJson,
    Expression<String>? profileId,
    Expression<String>? postbootHost,
    Expression<int>? postbootPort,
    Expression<String>? postbootCheck,
    Expression<int>? waitTimeoutSeconds,
    Expression<int>? bootTimeoutSeconds,
    Expression<String>? prebootKeyJson,
    Expression<String>? postbootKeyJson,
    Expression<bool>? legacyAlgorithms,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (groupName != null) 'group_name': groupName,
      if (prebootJson != null) 'preboot_json': prebootJson,
      if (loginUser != null) 'login_user': loginUser,
      if (keyId != null) 'key_id': keyId,
      if (secretId != null) 'secret_id': secretId,
      if (diskOverridesJson != null) 'disk_overrides_json': diskOverridesJson,
      if (profileId != null) 'profile_id': profileId,
      if (postbootHost != null) 'postboot_host': postbootHost,
      if (postbootPort != null) 'postboot_port': postbootPort,
      if (postbootCheck != null) 'postboot_check': postbootCheck,
      if (waitTimeoutSeconds != null)
        'wait_timeout_seconds': waitTimeoutSeconds,
      if (bootTimeoutSeconds != null)
        'boot_timeout_seconds': bootTimeoutSeconds,
      if (prebootKeyJson != null) 'preboot_key_json': prebootKeyJson,
      if (postbootKeyJson != null) 'postboot_key_json': postbootKeyJson,
      if (legacyAlgorithms != null) 'legacy_algorithms': legacyAlgorithms,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HostsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? groupName,
    Value<String>? prebootJson,
    Value<String>? loginUser,
    Value<String?>? keyId,
    Value<String?>? secretId,
    Value<String>? diskOverridesJson,
    Value<String?>? profileId,
    Value<String?>? postbootHost,
    Value<int>? postbootPort,
    Value<String>? postbootCheck,
    Value<int>? waitTimeoutSeconds,
    Value<int>? bootTimeoutSeconds,
    Value<String?>? prebootKeyJson,
    Value<String?>? postbootKeyJson,
    Value<bool>? legacyAlgorithms,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return HostsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      groupName: groupName ?? this.groupName,
      prebootJson: prebootJson ?? this.prebootJson,
      loginUser: loginUser ?? this.loginUser,
      keyId: keyId ?? this.keyId,
      secretId: secretId ?? this.secretId,
      diskOverridesJson: diskOverridesJson ?? this.diskOverridesJson,
      profileId: profileId ?? this.profileId,
      postbootHost: postbootHost ?? this.postbootHost,
      postbootPort: postbootPort ?? this.postbootPort,
      postbootCheck: postbootCheck ?? this.postbootCheck,
      waitTimeoutSeconds: waitTimeoutSeconds ?? this.waitTimeoutSeconds,
      bootTimeoutSeconds: bootTimeoutSeconds ?? this.bootTimeoutSeconds,
      prebootKeyJson: prebootKeyJson ?? this.prebootKeyJson,
      postbootKeyJson: postbootKeyJson ?? this.postbootKeyJson,
      legacyAlgorithms: legacyAlgorithms ?? this.legacyAlgorithms,
      enabled: enabled ?? this.enabled,
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
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (prebootJson.present) {
      map['preboot_json'] = Variable<String>(prebootJson.value);
    }
    if (loginUser.present) {
      map['login_user'] = Variable<String>(loginUser.value);
    }
    if (keyId.present) {
      map['key_id'] = Variable<String>(keyId.value);
    }
    if (secretId.present) {
      map['secret_id'] = Variable<String>(secretId.value);
    }
    if (diskOverridesJson.present) {
      map['disk_overrides_json'] = Variable<String>(diskOverridesJson.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (postbootHost.present) {
      map['postboot_host'] = Variable<String>(postbootHost.value);
    }
    if (postbootPort.present) {
      map['postboot_port'] = Variable<int>(postbootPort.value);
    }
    if (postbootCheck.present) {
      map['postboot_check'] = Variable<String>(postbootCheck.value);
    }
    if (waitTimeoutSeconds.present) {
      map['wait_timeout_seconds'] = Variable<int>(waitTimeoutSeconds.value);
    }
    if (bootTimeoutSeconds.present) {
      map['boot_timeout_seconds'] = Variable<int>(bootTimeoutSeconds.value);
    }
    if (prebootKeyJson.present) {
      map['preboot_key_json'] = Variable<String>(prebootKeyJson.value);
    }
    if (postbootKeyJson.present) {
      map['postboot_key_json'] = Variable<String>(postbootKeyJson.value);
    }
    if (legacyAlgorithms.present) {
      map['legacy_algorithms'] = Variable<bool>(legacyAlgorithms.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
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
    return (StringBuffer('HostsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupName: $groupName, ')
          ..write('prebootJson: $prebootJson, ')
          ..write('loginUser: $loginUser, ')
          ..write('keyId: $keyId, ')
          ..write('secretId: $secretId, ')
          ..write('diskOverridesJson: $diskOverridesJson, ')
          ..write('profileId: $profileId, ')
          ..write('postbootHost: $postbootHost, ')
          ..write('postbootPort: $postbootPort, ')
          ..write('postbootCheck: $postbootCheck, ')
          ..write('waitTimeoutSeconds: $waitTimeoutSeconds, ')
          ..write('bootTimeoutSeconds: $bootTimeoutSeconds, ')
          ..write('prebootKeyJson: $prebootKeyJson, ')
          ..write('postbootKeyJson: $postbootKeyJson, ')
          ..write('legacyAlgorithms: $legacyAlgorithms, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultPasswordSlotTable extends VaultPasswordSlot
    with TableInfo<$VaultPasswordSlotTable, PasswordSlotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultPasswordSlotTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saltMeta = const VerificationMeta('salt');
  @override
  late final GeneratedColumn<Uint8List> salt = GeneratedColumn<Uint8List>(
    'salt',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoryKibMeta = const VerificationMeta(
    'memoryKib',
  );
  @override
  late final GeneratedColumn<int> memoryKib = GeneratedColumn<int>(
    'memory_kib',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iterationsMeta = const VerificationMeta(
    'iterations',
  );
  @override
  late final GeneratedColumn<int> iterations = GeneratedColumn<int>(
    'iterations',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parallelismMeta = const VerificationMeta(
    'parallelism',
  );
  @override
  late final GeneratedColumn<int> parallelism = GeneratedColumn<int>(
    'parallelism',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nonceMeta = const VerificationMeta('nonce');
  @override
  late final GeneratedColumn<Uint8List> nonce = GeneratedColumn<Uint8List>(
    'nonce',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrappedKeyMeta = const VerificationMeta(
    'wrappedKey',
  );
  @override
  late final GeneratedColumn<Uint8List> wrappedKey = GeneratedColumn<Uint8List>(
    'wrapped_key',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    salt,
    memoryKib,
    iterations,
    parallelism,
    nonce,
    wrappedKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_password_slot';
  @override
  VerificationContext validateIntegrity(
    Insertable<PasswordSlotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('salt')) {
      context.handle(
        _saltMeta,
        salt.isAcceptableOrUnknown(data['salt']!, _saltMeta),
      );
    } else if (isInserting) {
      context.missing(_saltMeta);
    }
    if (data.containsKey('memory_kib')) {
      context.handle(
        _memoryKibMeta,
        memoryKib.isAcceptableOrUnknown(data['memory_kib']!, _memoryKibMeta),
      );
    } else if (isInserting) {
      context.missing(_memoryKibMeta);
    }
    if (data.containsKey('iterations')) {
      context.handle(
        _iterationsMeta,
        iterations.isAcceptableOrUnknown(data['iterations']!, _iterationsMeta),
      );
    } else if (isInserting) {
      context.missing(_iterationsMeta);
    }
    if (data.containsKey('parallelism')) {
      context.handle(
        _parallelismMeta,
        parallelism.isAcceptableOrUnknown(
          data['parallelism']!,
          _parallelismMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parallelismMeta);
    }
    if (data.containsKey('nonce')) {
      context.handle(
        _nonceMeta,
        nonce.isAcceptableOrUnknown(data['nonce']!, _nonceMeta),
      );
    } else if (isInserting) {
      context.missing(_nonceMeta);
    }
    if (data.containsKey('wrapped_key')) {
      context.handle(
        _wrappedKeyMeta,
        wrappedKey.isAcceptableOrUnknown(data['wrapped_key']!, _wrappedKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wrappedKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PasswordSlotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PasswordSlotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      salt: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}salt'],
      )!,
      memoryKib: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}memory_kib'],
      )!,
      iterations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iterations'],
      )!,
      parallelism: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parallelism'],
      )!,
      nonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}nonce'],
      )!,
      wrappedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}wrapped_key'],
      )!,
    );
  }

  @override
  $VaultPasswordSlotTable createAlias(String alias) {
    return $VaultPasswordSlotTable(attachedDatabase, alias);
  }
}

class PasswordSlotRow extends DataClass implements Insertable<PasswordSlotRow> {
  final int id;
  final Uint8List salt;
  final int memoryKib;
  final int iterations;
  final int parallelism;
  final Uint8List nonce;
  final Uint8List wrappedKey;
  const PasswordSlotRow({
    required this.id,
    required this.salt,
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
    required this.nonce,
    required this.wrappedKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['salt'] = Variable<Uint8List>(salt);
    map['memory_kib'] = Variable<int>(memoryKib);
    map['iterations'] = Variable<int>(iterations);
    map['parallelism'] = Variable<int>(parallelism);
    map['nonce'] = Variable<Uint8List>(nonce);
    map['wrapped_key'] = Variable<Uint8List>(wrappedKey);
    return map;
  }

  VaultPasswordSlotCompanion toCompanion(bool nullToAbsent) {
    return VaultPasswordSlotCompanion(
      id: Value(id),
      salt: Value(salt),
      memoryKib: Value(memoryKib),
      iterations: Value(iterations),
      parallelism: Value(parallelism),
      nonce: Value(nonce),
      wrappedKey: Value(wrappedKey),
    );
  }

  factory PasswordSlotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PasswordSlotRow(
      id: serializer.fromJson<int>(json['id']),
      salt: serializer.fromJson<Uint8List>(json['salt']),
      memoryKib: serializer.fromJson<int>(json['memoryKib']),
      iterations: serializer.fromJson<int>(json['iterations']),
      parallelism: serializer.fromJson<int>(json['parallelism']),
      nonce: serializer.fromJson<Uint8List>(json['nonce']),
      wrappedKey: serializer.fromJson<Uint8List>(json['wrappedKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'salt': serializer.toJson<Uint8List>(salt),
      'memoryKib': serializer.toJson<int>(memoryKib),
      'iterations': serializer.toJson<int>(iterations),
      'parallelism': serializer.toJson<int>(parallelism),
      'nonce': serializer.toJson<Uint8List>(nonce),
      'wrappedKey': serializer.toJson<Uint8List>(wrappedKey),
    };
  }

  PasswordSlotRow copyWith({
    int? id,
    Uint8List? salt,
    int? memoryKib,
    int? iterations,
    int? parallelism,
    Uint8List? nonce,
    Uint8List? wrappedKey,
  }) => PasswordSlotRow(
    id: id ?? this.id,
    salt: salt ?? this.salt,
    memoryKib: memoryKib ?? this.memoryKib,
    iterations: iterations ?? this.iterations,
    parallelism: parallelism ?? this.parallelism,
    nonce: nonce ?? this.nonce,
    wrappedKey: wrappedKey ?? this.wrappedKey,
  );
  PasswordSlotRow copyWithCompanion(VaultPasswordSlotCompanion data) {
    return PasswordSlotRow(
      id: data.id.present ? data.id.value : this.id,
      salt: data.salt.present ? data.salt.value : this.salt,
      memoryKib: data.memoryKib.present ? data.memoryKib.value : this.memoryKib,
      iterations: data.iterations.present
          ? data.iterations.value
          : this.iterations,
      parallelism: data.parallelism.present
          ? data.parallelism.value
          : this.parallelism,
      nonce: data.nonce.present ? data.nonce.value : this.nonce,
      wrappedKey: data.wrappedKey.present
          ? data.wrappedKey.value
          : this.wrappedKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PasswordSlotRow(')
          ..write('id: $id, ')
          ..write('salt: $salt, ')
          ..write('memoryKib: $memoryKib, ')
          ..write('iterations: $iterations, ')
          ..write('parallelism: $parallelism, ')
          ..write('nonce: $nonce, ')
          ..write('wrappedKey: $wrappedKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    $driftBlobEquality.hash(salt),
    memoryKib,
    iterations,
    parallelism,
    $driftBlobEquality.hash(nonce),
    $driftBlobEquality.hash(wrappedKey),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PasswordSlotRow &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.salt, this.salt) &&
          other.memoryKib == this.memoryKib &&
          other.iterations == this.iterations &&
          other.parallelism == this.parallelism &&
          $driftBlobEquality.equals(other.nonce, this.nonce) &&
          $driftBlobEquality.equals(other.wrappedKey, this.wrappedKey));
}

class VaultPasswordSlotCompanion extends UpdateCompanion<PasswordSlotRow> {
  final Value<int> id;
  final Value<Uint8List> salt;
  final Value<int> memoryKib;
  final Value<int> iterations;
  final Value<int> parallelism;
  final Value<Uint8List> nonce;
  final Value<Uint8List> wrappedKey;
  const VaultPasswordSlotCompanion({
    this.id = const Value.absent(),
    this.salt = const Value.absent(),
    this.memoryKib = const Value.absent(),
    this.iterations = const Value.absent(),
    this.parallelism = const Value.absent(),
    this.nonce = const Value.absent(),
    this.wrappedKey = const Value.absent(),
  });
  VaultPasswordSlotCompanion.insert({
    this.id = const Value.absent(),
    required Uint8List salt,
    required int memoryKib,
    required int iterations,
    required int parallelism,
    required Uint8List nonce,
    required Uint8List wrappedKey,
  }) : salt = Value(salt),
       memoryKib = Value(memoryKib),
       iterations = Value(iterations),
       parallelism = Value(parallelism),
       nonce = Value(nonce),
       wrappedKey = Value(wrappedKey);
  static Insertable<PasswordSlotRow> custom({
    Expression<int>? id,
    Expression<Uint8List>? salt,
    Expression<int>? memoryKib,
    Expression<int>? iterations,
    Expression<int>? parallelism,
    Expression<Uint8List>? nonce,
    Expression<Uint8List>? wrappedKey,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (salt != null) 'salt': salt,
      if (memoryKib != null) 'memory_kib': memoryKib,
      if (iterations != null) 'iterations': iterations,
      if (parallelism != null) 'parallelism': parallelism,
      if (nonce != null) 'nonce': nonce,
      if (wrappedKey != null) 'wrapped_key': wrappedKey,
    });
  }

  VaultPasswordSlotCompanion copyWith({
    Value<int>? id,
    Value<Uint8List>? salt,
    Value<int>? memoryKib,
    Value<int>? iterations,
    Value<int>? parallelism,
    Value<Uint8List>? nonce,
    Value<Uint8List>? wrappedKey,
  }) {
    return VaultPasswordSlotCompanion(
      id: id ?? this.id,
      salt: salt ?? this.salt,
      memoryKib: memoryKib ?? this.memoryKib,
      iterations: iterations ?? this.iterations,
      parallelism: parallelism ?? this.parallelism,
      nonce: nonce ?? this.nonce,
      wrappedKey: wrappedKey ?? this.wrappedKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (salt.present) {
      map['salt'] = Variable<Uint8List>(salt.value);
    }
    if (memoryKib.present) {
      map['memory_kib'] = Variable<int>(memoryKib.value);
    }
    if (iterations.present) {
      map['iterations'] = Variable<int>(iterations.value);
    }
    if (parallelism.present) {
      map['parallelism'] = Variable<int>(parallelism.value);
    }
    if (nonce.present) {
      map['nonce'] = Variable<Uint8List>(nonce.value);
    }
    if (wrappedKey.present) {
      map['wrapped_key'] = Variable<Uint8List>(wrappedKey.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultPasswordSlotCompanion(')
          ..write('id: $id, ')
          ..write('salt: $salt, ')
          ..write('memoryKib: $memoryKib, ')
          ..write('iterations: $iterations, ')
          ..write('parallelism: $parallelism, ')
          ..write('nonce: $nonce, ')
          ..write('wrappedKey: $wrappedKey')
          ..write(')'))
        .toString();
  }
}

class $VaultMetadataTableTable extends VaultMetadataTable
    with TableInfo<$VaultMetadataTableTable, VaultMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultMetadataTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<int> formatVersion = GeneratedColumn<int>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vaultIdMeta = const VerificationMeta(
    'vaultId',
  );
  @override
  late final GeneratedColumn<String> vaultId = GeneratedColumn<String>(
    'vault_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyCheckNonceMeta = const VerificationMeta(
    'keyCheckNonce',
  );
  @override
  late final GeneratedColumn<Uint8List> keyCheckNonce =
      GeneratedColumn<Uint8List>(
        'key_check_nonce',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _keyCheckMeta = const VerificationMeta(
    'keyCheck',
  );
  @override
  late final GeneratedColumn<Uint8List> keyCheck = GeneratedColumn<Uint8List>(
    'key_check',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _biometricSlotEnrolledMeta =
      const VerificationMeta('biometricSlotEnrolled');
  @override
  late final GeneratedColumn<bool> biometricSlotEnrolled =
      GeneratedColumn<bool>(
        'biometric_slot_enrolled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("biometric_slot_enrolled" IN (0, 1))',
        ),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    formatVersion,
    vaultId,
    keyCheckNonce,
    keyCheck,
    biometricSlotEnrolled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatVersionMeta);
    }
    if (data.containsKey('vault_id')) {
      context.handle(
        _vaultIdMeta,
        vaultId.isAcceptableOrUnknown(data['vault_id']!, _vaultIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaultIdMeta);
    }
    if (data.containsKey('key_check_nonce')) {
      context.handle(
        _keyCheckNonceMeta,
        keyCheckNonce.isAcceptableOrUnknown(
          data['key_check_nonce']!,
          _keyCheckNonceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_keyCheckNonceMeta);
    }
    if (data.containsKey('key_check')) {
      context.handle(
        _keyCheckMeta,
        keyCheck.isAcceptableOrUnknown(data['key_check']!, _keyCheckMeta),
      );
    } else if (isInserting) {
      context.missing(_keyCheckMeta);
    }
    if (data.containsKey('biometric_slot_enrolled')) {
      context.handle(
        _biometricSlotEnrolledMeta,
        biometricSlotEnrolled.isAcceptableOrUnknown(
          data['biometric_slot_enrolled']!,
          _biometricSlotEnrolledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_biometricSlotEnrolledMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultMetadataRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_version'],
      )!,
      vaultId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_id'],
      )!,
      keyCheckNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}key_check_nonce'],
      )!,
      keyCheck: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}key_check'],
      )!,
      biometricSlotEnrolled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}biometric_slot_enrolled'],
      )!,
    );
  }

  @override
  $VaultMetadataTableTable createAlias(String alias) {
    return $VaultMetadataTableTable(attachedDatabase, alias);
  }
}

class VaultMetadataRow extends DataClass
    implements Insertable<VaultMetadataRow> {
  final int id;
  final int formatVersion;
  final String vaultId;
  final Uint8List keyCheckNonce;
  final Uint8List keyCheck;
  final bool biometricSlotEnrolled;
  const VaultMetadataRow({
    required this.id,
    required this.formatVersion,
    required this.vaultId,
    required this.keyCheckNonce,
    required this.keyCheck,
    required this.biometricSlotEnrolled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['format_version'] = Variable<int>(formatVersion);
    map['vault_id'] = Variable<String>(vaultId);
    map['key_check_nonce'] = Variable<Uint8List>(keyCheckNonce);
    map['key_check'] = Variable<Uint8List>(keyCheck);
    map['biometric_slot_enrolled'] = Variable<bool>(biometricSlotEnrolled);
    return map;
  }

  VaultMetadataTableCompanion toCompanion(bool nullToAbsent) {
    return VaultMetadataTableCompanion(
      id: Value(id),
      formatVersion: Value(formatVersion),
      vaultId: Value(vaultId),
      keyCheckNonce: Value(keyCheckNonce),
      keyCheck: Value(keyCheck),
      biometricSlotEnrolled: Value(biometricSlotEnrolled),
    );
  }

  factory VaultMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultMetadataRow(
      id: serializer.fromJson<int>(json['id']),
      formatVersion: serializer.fromJson<int>(json['formatVersion']),
      vaultId: serializer.fromJson<String>(json['vaultId']),
      keyCheckNonce: serializer.fromJson<Uint8List>(json['keyCheckNonce']),
      keyCheck: serializer.fromJson<Uint8List>(json['keyCheck']),
      biometricSlotEnrolled: serializer.fromJson<bool>(
        json['biometricSlotEnrolled'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'formatVersion': serializer.toJson<int>(formatVersion),
      'vaultId': serializer.toJson<String>(vaultId),
      'keyCheckNonce': serializer.toJson<Uint8List>(keyCheckNonce),
      'keyCheck': serializer.toJson<Uint8List>(keyCheck),
      'biometricSlotEnrolled': serializer.toJson<bool>(biometricSlotEnrolled),
    };
  }

  VaultMetadataRow copyWith({
    int? id,
    int? formatVersion,
    String? vaultId,
    Uint8List? keyCheckNonce,
    Uint8List? keyCheck,
    bool? biometricSlotEnrolled,
  }) => VaultMetadataRow(
    id: id ?? this.id,
    formatVersion: formatVersion ?? this.formatVersion,
    vaultId: vaultId ?? this.vaultId,
    keyCheckNonce: keyCheckNonce ?? this.keyCheckNonce,
    keyCheck: keyCheck ?? this.keyCheck,
    biometricSlotEnrolled: biometricSlotEnrolled ?? this.biometricSlotEnrolled,
  );
  VaultMetadataRow copyWithCompanion(VaultMetadataTableCompanion data) {
    return VaultMetadataRow(
      id: data.id.present ? data.id.value : this.id,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      vaultId: data.vaultId.present ? data.vaultId.value : this.vaultId,
      keyCheckNonce: data.keyCheckNonce.present
          ? data.keyCheckNonce.value
          : this.keyCheckNonce,
      keyCheck: data.keyCheck.present ? data.keyCheck.value : this.keyCheck,
      biometricSlotEnrolled: data.biometricSlotEnrolled.present
          ? data.biometricSlotEnrolled.value
          : this.biometricSlotEnrolled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetadataRow(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('vaultId: $vaultId, ')
          ..write('keyCheckNonce: $keyCheckNonce, ')
          ..write('keyCheck: $keyCheck, ')
          ..write('biometricSlotEnrolled: $biometricSlotEnrolled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    formatVersion,
    vaultId,
    $driftBlobEquality.hash(keyCheckNonce),
    $driftBlobEquality.hash(keyCheck),
    biometricSlotEnrolled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultMetadataRow &&
          other.id == this.id &&
          other.formatVersion == this.formatVersion &&
          other.vaultId == this.vaultId &&
          $driftBlobEquality.equals(other.keyCheckNonce, this.keyCheckNonce) &&
          $driftBlobEquality.equals(other.keyCheck, this.keyCheck) &&
          other.biometricSlotEnrolled == this.biometricSlotEnrolled);
}

class VaultMetadataTableCompanion extends UpdateCompanion<VaultMetadataRow> {
  final Value<int> id;
  final Value<int> formatVersion;
  final Value<String> vaultId;
  final Value<Uint8List> keyCheckNonce;
  final Value<Uint8List> keyCheck;
  final Value<bool> biometricSlotEnrolled;
  const VaultMetadataTableCompanion({
    this.id = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.vaultId = const Value.absent(),
    this.keyCheckNonce = const Value.absent(),
    this.keyCheck = const Value.absent(),
    this.biometricSlotEnrolled = const Value.absent(),
  });
  VaultMetadataTableCompanion.insert({
    this.id = const Value.absent(),
    required int formatVersion,
    required String vaultId,
    required Uint8List keyCheckNonce,
    required Uint8List keyCheck,
    required bool biometricSlotEnrolled,
  }) : formatVersion = Value(formatVersion),
       vaultId = Value(vaultId),
       keyCheckNonce = Value(keyCheckNonce),
       keyCheck = Value(keyCheck),
       biometricSlotEnrolled = Value(biometricSlotEnrolled);
  static Insertable<VaultMetadataRow> custom({
    Expression<int>? id,
    Expression<int>? formatVersion,
    Expression<String>? vaultId,
    Expression<Uint8List>? keyCheckNonce,
    Expression<Uint8List>? keyCheck,
    Expression<bool>? biometricSlotEnrolled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (formatVersion != null) 'format_version': formatVersion,
      if (vaultId != null) 'vault_id': vaultId,
      if (keyCheckNonce != null) 'key_check_nonce': keyCheckNonce,
      if (keyCheck != null) 'key_check': keyCheck,
      if (biometricSlotEnrolled != null)
        'biometric_slot_enrolled': biometricSlotEnrolled,
    });
  }

  VaultMetadataTableCompanion copyWith({
    Value<int>? id,
    Value<int>? formatVersion,
    Value<String>? vaultId,
    Value<Uint8List>? keyCheckNonce,
    Value<Uint8List>? keyCheck,
    Value<bool>? biometricSlotEnrolled,
  }) {
    return VaultMetadataTableCompanion(
      id: id ?? this.id,
      formatVersion: formatVersion ?? this.formatVersion,
      vaultId: vaultId ?? this.vaultId,
      keyCheckNonce: keyCheckNonce ?? this.keyCheckNonce,
      keyCheck: keyCheck ?? this.keyCheck,
      biometricSlotEnrolled:
          biometricSlotEnrolled ?? this.biometricSlotEnrolled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<int>(formatVersion.value);
    }
    if (vaultId.present) {
      map['vault_id'] = Variable<String>(vaultId.value);
    }
    if (keyCheckNonce.present) {
      map['key_check_nonce'] = Variable<Uint8List>(keyCheckNonce.value);
    }
    if (keyCheck.present) {
      map['key_check'] = Variable<Uint8List>(keyCheck.value);
    }
    if (biometricSlotEnrolled.present) {
      map['biometric_slot_enrolled'] = Variable<bool>(
        biometricSlotEnrolled.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetadataTableCompanion(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('vaultId: $vaultId, ')
          ..write('keyCheckNonce: $keyCheckNonce, ')
          ..write('keyCheck: $keyCheck, ')
          ..write('biometricSlotEnrolled: $biometricSlotEnrolled')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(AppSettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunsTable extends Runs with TableInfo<$RunsTable, RunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, startedAt, finishedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunRow> instance, {
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
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
    );
  }

  @override
  $RunsTable createAlias(String alias) {
    return $RunsTable(attachedDatabase, alias);
  }
}

class RunRow extends DataClass implements Insertable<RunRow> {
  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime? finishedAt;
  const RunRow({
    required this.id,
    required this.title,
    required this.startedAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    return map;
  }

  RunsCompanion toCompanion(bool nullToAbsent) {
    return RunsCompanion(
      id: Value(id),
      title: Value(title),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory RunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  RunRow copyWith({
    String? id,
    String? title,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => RunRow(
    id: id ?? this.id,
    title: title ?? this.title,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  RunRow copyWithCompanion(RunsCompanion data) {
    return RunRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, startedAt, finishedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class RunsCompanion extends UpdateCompanion<RunRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<int> rowid;
  const RunsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunsCompanion.insert({
    required String id,
    required String title,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       startedAt = Value(startedAt);
  static Insertable<RunRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<int>? rowid,
  }) {
    return RunsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
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
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunHostsTable extends RunHosts
    with TableInfo<$RunHostsTable, RunHostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunHostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostNameMeta = const VerificationMeta(
    'hostName',
  );
  @override
  late final GeneratedColumn<String> hostName = GeneratedColumn<String>(
    'host_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finalStateMeta = const VerificationMeta(
    'finalState',
  );
  @override
  late final GeneratedColumn<String> finalState = GeneratedColumn<String>(
    'final_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [runId, hostId, hostName, finalState];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_hosts';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunHostRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('host_name')) {
      context.handle(
        _hostNameMeta,
        hostName.isAcceptableOrUnknown(data['host_name']!, _hostNameMeta),
      );
    } else if (isInserting) {
      context.missing(_hostNameMeta);
    }
    if (data.containsKey('final_state')) {
      context.handle(
        _finalStateMeta,
        finalState.isAcceptableOrUnknown(data['final_state']!, _finalStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {runId, hostId};
  @override
  RunHostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunHostRow(
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      hostName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_name'],
      )!,
      finalState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_state'],
      ),
    );
  }

  @override
  $RunHostsTable createAlias(String alias) {
    return $RunHostsTable(attachedDatabase, alias);
  }
}

class RunHostRow extends DataClass implements Insertable<RunHostRow> {
  final String runId;
  final String hostId;
  final String hostName;
  final String? finalState;
  const RunHostRow({
    required this.runId,
    required this.hostId,
    required this.hostName,
    this.finalState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['run_id'] = Variable<String>(runId);
    map['host_id'] = Variable<String>(hostId);
    map['host_name'] = Variable<String>(hostName);
    if (!nullToAbsent || finalState != null) {
      map['final_state'] = Variable<String>(finalState);
    }
    return map;
  }

  RunHostsCompanion toCompanion(bool nullToAbsent) {
    return RunHostsCompanion(
      runId: Value(runId),
      hostId: Value(hostId),
      hostName: Value(hostName),
      finalState: finalState == null && nullToAbsent
          ? const Value.absent()
          : Value(finalState),
    );
  }

  factory RunHostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunHostRow(
      runId: serializer.fromJson<String>(json['runId']),
      hostId: serializer.fromJson<String>(json['hostId']),
      hostName: serializer.fromJson<String>(json['hostName']),
      finalState: serializer.fromJson<String?>(json['finalState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'runId': serializer.toJson<String>(runId),
      'hostId': serializer.toJson<String>(hostId),
      'hostName': serializer.toJson<String>(hostName),
      'finalState': serializer.toJson<String?>(finalState),
    };
  }

  RunHostRow copyWith({
    String? runId,
    String? hostId,
    String? hostName,
    Value<String?> finalState = const Value.absent(),
  }) => RunHostRow(
    runId: runId ?? this.runId,
    hostId: hostId ?? this.hostId,
    hostName: hostName ?? this.hostName,
    finalState: finalState.present ? finalState.value : this.finalState,
  );
  RunHostRow copyWithCompanion(RunHostsCompanion data) {
    return RunHostRow(
      runId: data.runId.present ? data.runId.value : this.runId,
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      hostName: data.hostName.present ? data.hostName.value : this.hostName,
      finalState: data.finalState.present
          ? data.finalState.value
          : this.finalState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunHostRow(')
          ..write('runId: $runId, ')
          ..write('hostId: $hostId, ')
          ..write('hostName: $hostName, ')
          ..write('finalState: $finalState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(runId, hostId, hostName, finalState);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunHostRow &&
          other.runId == this.runId &&
          other.hostId == this.hostId &&
          other.hostName == this.hostName &&
          other.finalState == this.finalState);
}

class RunHostsCompanion extends UpdateCompanion<RunHostRow> {
  final Value<String> runId;
  final Value<String> hostId;
  final Value<String> hostName;
  final Value<String?> finalState;
  final Value<int> rowid;
  const RunHostsCompanion({
    this.runId = const Value.absent(),
    this.hostId = const Value.absent(),
    this.hostName = const Value.absent(),
    this.finalState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunHostsCompanion.insert({
    required String runId,
    required String hostId,
    required String hostName,
    this.finalState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : runId = Value(runId),
       hostId = Value(hostId),
       hostName = Value(hostName);
  static Insertable<RunHostRow> custom({
    Expression<String>? runId,
    Expression<String>? hostId,
    Expression<String>? hostName,
    Expression<String>? finalState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (runId != null) 'run_id': runId,
      if (hostId != null) 'host_id': hostId,
      if (hostName != null) 'host_name': hostName,
      if (finalState != null) 'final_state': finalState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunHostsCompanion copyWith({
    Value<String>? runId,
    Value<String>? hostId,
    Value<String>? hostName,
    Value<String?>? finalState,
    Value<int>? rowid,
  }) {
    return RunHostsCompanion(
      runId: runId ?? this.runId,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      finalState: finalState ?? this.finalState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (hostName.present) {
      map['host_name'] = Variable<String>(hostName.value);
    }
    if (finalState.present) {
      map['final_state'] = Variable<String>(finalState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunHostsCompanion(')
          ..write('runId: $runId, ')
          ..write('hostId: $hostId, ')
          ..write('hostName: $hostName, ')
          ..write('finalState: $finalState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunEventsTable extends RunEvents
    with TableInfo<$RunEventsTable, RunEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    hostId,
    time,
    phase,
    message,
    result,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}time'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
    );
  }

  @override
  $RunEventsTable createAlias(String alias) {
    return $RunEventsTable(attachedDatabase, alias);
  }
}

class RunEventRow extends DataClass implements Insertable<RunEventRow> {
  final int id;
  final String runId;
  final String hostId;
  final DateTime time;
  final String phase;
  final String message;
  final String? result;
  const RunEventRow({
    required this.id,
    required this.runId,
    required this.hostId,
    required this.time,
    required this.phase,
    required this.message,
    this.result,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['run_id'] = Variable<String>(runId);
    map['host_id'] = Variable<String>(hostId);
    map['time'] = Variable<DateTime>(time);
    map['phase'] = Variable<String>(phase);
    map['message'] = Variable<String>(message);
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    return map;
  }

  RunEventsCompanion toCompanion(bool nullToAbsent) {
    return RunEventsCompanion(
      id: Value(id),
      runId: Value(runId),
      hostId: Value(hostId),
      time: Value(time),
      phase: Value(phase),
      message: Value(message),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
    );
  }

  factory RunEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunEventRow(
      id: serializer.fromJson<int>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      hostId: serializer.fromJson<String>(json['hostId']),
      time: serializer.fromJson<DateTime>(json['time']),
      phase: serializer.fromJson<String>(json['phase']),
      message: serializer.fromJson<String>(json['message']),
      result: serializer.fromJson<String?>(json['result']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'runId': serializer.toJson<String>(runId),
      'hostId': serializer.toJson<String>(hostId),
      'time': serializer.toJson<DateTime>(time),
      'phase': serializer.toJson<String>(phase),
      'message': serializer.toJson<String>(message),
      'result': serializer.toJson<String?>(result),
    };
  }

  RunEventRow copyWith({
    int? id,
    String? runId,
    String? hostId,
    DateTime? time,
    String? phase,
    String? message,
    Value<String?> result = const Value.absent(),
  }) => RunEventRow(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    hostId: hostId ?? this.hostId,
    time: time ?? this.time,
    phase: phase ?? this.phase,
    message: message ?? this.message,
    result: result.present ? result.value : this.result,
  );
  RunEventRow copyWithCompanion(RunEventsCompanion data) {
    return RunEventRow(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      time: data.time.present ? data.time.value : this.time,
      phase: data.phase.present ? data.phase.value : this.phase,
      message: data.message.present ? data.message.value : this.message,
      result: data.result.present ? data.result.value : this.result,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunEventRow(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('hostId: $hostId, ')
          ..write('time: $time, ')
          ..write('phase: $phase, ')
          ..write('message: $message, ')
          ..write('result: $result')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, runId, hostId, time, phase, message, result);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunEventRow &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.hostId == this.hostId &&
          other.time == this.time &&
          other.phase == this.phase &&
          other.message == this.message &&
          other.result == this.result);
}

class RunEventsCompanion extends UpdateCompanion<RunEventRow> {
  final Value<int> id;
  final Value<String> runId;
  final Value<String> hostId;
  final Value<DateTime> time;
  final Value<String> phase;
  final Value<String> message;
  final Value<String?> result;
  const RunEventsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.hostId = const Value.absent(),
    this.time = const Value.absent(),
    this.phase = const Value.absent(),
    this.message = const Value.absent(),
    this.result = const Value.absent(),
  });
  RunEventsCompanion.insert({
    this.id = const Value.absent(),
    required String runId,
    required String hostId,
    required DateTime time,
    required String phase,
    required String message,
    this.result = const Value.absent(),
  }) : runId = Value(runId),
       hostId = Value(hostId),
       time = Value(time),
       phase = Value(phase),
       message = Value(message);
  static Insertable<RunEventRow> custom({
    Expression<int>? id,
    Expression<String>? runId,
    Expression<String>? hostId,
    Expression<DateTime>? time,
    Expression<String>? phase,
    Expression<String>? message,
    Expression<String>? result,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (hostId != null) 'host_id': hostId,
      if (time != null) 'time': time,
      if (phase != null) 'phase': phase,
      if (message != null) 'message': message,
      if (result != null) 'result': result,
    });
  }

  RunEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? runId,
    Value<String>? hostId,
    Value<DateTime>? time,
    Value<String>? phase,
    Value<String>? message,
    Value<String?>? result,
  }) {
    return RunEventsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      hostId: hostId ?? this.hostId,
      time: time ?? this.time,
      phase: phase ?? this.phase,
      message: message ?? this.message,
      result: result ?? this.result,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunEventsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('hostId: $hostId, ')
          ..write('time: $time, ')
          ..write('phase: $phase, ')
          ..write('message: $message, ')
          ..write('result: $result')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VaultRecordsTable vaultRecords = $VaultRecordsTable(this);
  late final $SshKeysTable sshKeys = $SshKeysTable(this);
  late final $SecretsTable secrets = $SecretsTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $HostsTable hosts = $HostsTable(this);
  late final $VaultPasswordSlotTable vaultPasswordSlot =
      $VaultPasswordSlotTable(this);
  late final $VaultMetadataTableTable vaultMetadataTable =
      $VaultMetadataTableTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $RunsTable runs = $RunsTable(this);
  late final $RunHostsTable runHosts = $RunHostsTable(this);
  late final $RunEventsTable runEvents = $RunEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vaultRecords,
    sshKeys,
    secrets,
    profiles,
    hosts,
    vaultPasswordSlot,
    vaultMetadataTable,
    appSettings,
    runs,
    runHosts,
    runEvents,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('run_hosts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('run_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$VaultRecordsTableCreateCompanionBuilder =
    VaultRecordsCompanion Function({
      required String id,
      required String kind,
      required Uint8List nonce,
      required Uint8List ciphertext,
      Value<int> rowid,
    });
typedef $$VaultRecordsTableUpdateCompanionBuilder =
    VaultRecordsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<Uint8List> nonce,
      Value<Uint8List> ciphertext,
      Value<int> rowid,
    });

final class $$VaultRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $VaultRecordsTable, VaultRecordRow> {
  $$VaultRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SshKeysTable, List<SshKeyRow>> _sshKeysRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sshKeys,
    aliasName: 'vault_records__id__ssh_keys__vault_record_id',
  );

  $$SshKeysTableProcessedTableManager get sshKeysRefs {
    final manager = $$SshKeysTableTableManager(
      $_db,
      $_db.sshKeys,
    ).filter((f) => f.vaultRecordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sshKeysRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SecretsTable, List<SecretRow>> _secretsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.secrets,
    aliasName: 'vault_records__id__secrets__vault_record_id',
  );

  $$SecretsTableProcessedTableManager get secretsRefs {
    final manager = $$SecretsTableTableManager(
      $_db,
      $_db.secrets,
    ).filter((f) => f.vaultRecordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_secretsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VaultRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $VaultRecordsTable> {
  $$VaultRecordsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sshKeysRefs(
    Expression<bool> Function($$SshKeysTableFilterComposer f) f,
  ) {
    final $$SshKeysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sshKeys,
      getReferencedColumn: (t) => t.vaultRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SshKeysTableFilterComposer(
            $db: $db,
            $table: $db.sshKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> secretsRefs(
    Expression<bool> Function($$SecretsTableFilterComposer f) f,
  ) {
    final $$SecretsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.secrets,
      getReferencedColumn: (t) => t.vaultRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SecretsTableFilterComposer(
            $db: $db,
            $table: $db.secrets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VaultRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultRecordsTable> {
  $$VaultRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultRecordsTable> {
  $$VaultRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<Uint8List> get nonce =>
      $composableBuilder(column: $table.nonce, builder: (column) => column);

  GeneratedColumn<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => column,
  );

  Expression<T> sshKeysRefs<T extends Object>(
    Expression<T> Function($$SshKeysTableAnnotationComposer a) f,
  ) {
    final $$SshKeysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sshKeys,
      getReferencedColumn: (t) => t.vaultRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SshKeysTableAnnotationComposer(
            $db: $db,
            $table: $db.sshKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> secretsRefs<T extends Object>(
    Expression<T> Function($$SecretsTableAnnotationComposer a) f,
  ) {
    final $$SecretsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.secrets,
      getReferencedColumn: (t) => t.vaultRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SecretsTableAnnotationComposer(
            $db: $db,
            $table: $db.secrets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VaultRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultRecordsTable,
          VaultRecordRow,
          $$VaultRecordsTableFilterComposer,
          $$VaultRecordsTableOrderingComposer,
          $$VaultRecordsTableAnnotationComposer,
          $$VaultRecordsTableCreateCompanionBuilder,
          $$VaultRecordsTableUpdateCompanionBuilder,
          (VaultRecordRow, $$VaultRecordsTableReferences),
          VaultRecordRow,
          PrefetchHooks Function({bool sshKeysRefs, bool secretsRefs})
        > {
  $$VaultRecordsTableTableManager(_$AppDatabase db, $VaultRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<Uint8List> nonce = const Value.absent(),
                Value<Uint8List> ciphertext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultRecordsCompanion(
                id: id,
                kind: kind,
                nonce: nonce,
                ciphertext: ciphertext,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required Uint8List nonce,
                required Uint8List ciphertext,
                Value<int> rowid = const Value.absent(),
              }) => VaultRecordsCompanion.insert(
                id: id,
                kind: kind,
                nonce: nonce,
                ciphertext: ciphertext,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultRecordsTable, VaultRecordRow>(table),
                  $$VaultRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sshKeysRefs = false, secretsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sshKeysRefs) db.sshKeys,
                if (secretsRefs) db.secrets,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sshKeysRefs)
                    await $_getPrefetchedDataByColumns<
                      VaultRecordRow,
                      $VaultRecordsTable,
                      SshKeyRow,
                      $SshKeysTable
                    >(
                      currentTable: table,
                      referencedTable: $$VaultRecordsTableReferences
                          ._sshKeysRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$VaultRecordsTableReferences(
                            db,
                            table,
                            p0,
                          ).sshKeysRefs,
                      currentColumn: 'id',
                      referencedColumn: 'vault_record_id',
                      typedResults: items,
                    ),
                  if (secretsRefs)
                    await $_getPrefetchedDataByColumns<
                      VaultRecordRow,
                      $VaultRecordsTable,
                      SecretRow,
                      $SecretsTable
                    >(
                      currentTable: table,
                      referencedTable: $$VaultRecordsTableReferences
                          ._secretsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$VaultRecordsTableReferences(
                            db,
                            table,
                            p0,
                          ).secretsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'vault_record_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$VaultRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultRecordsTable,
      VaultRecordRow,
      $$VaultRecordsTableFilterComposer,
      $$VaultRecordsTableOrderingComposer,
      $$VaultRecordsTableAnnotationComposer,
      $$VaultRecordsTableCreateCompanionBuilder,
      $$VaultRecordsTableUpdateCompanionBuilder,
      (VaultRecordRow, $$VaultRecordsTableReferences),
      VaultRecordRow,
      PrefetchHooks Function({bool sshKeysRefs, bool secretsRefs})
    >;
typedef $$SshKeysTableCreateCompanionBuilder = SshKeysCompanion Function({
  required String id,
  required String label,
  required String keyType,
  required int bits,
  required String publicLine,
  required String fingerprint,
  required String vaultRecordId,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$SshKeysTableUpdateCompanionBuilder = SshKeysCompanion Function({
  Value<String> id,
  Value<String> label,
  Value<String> keyType,
  Value<int> bits,
  Value<String> publicLine,
  Value<String> fingerprint,
  Value<String> vaultRecordId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$SshKeysTableReferences
    extends BaseReferences<_$AppDatabase, $SshKeysTable, SshKeyRow> {
  $$SshKeysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VaultRecordsTable _vaultRecordIdTable(_$AppDatabase db) => db
      .vaultRecords
      .createAlias('ssh_keys__vault_record_id__vault_records__id');

  $$VaultRecordsTableProcessedTableManager get vaultRecordId {
    final $_column = $_itemColumn<String>('vault_record_id')!;

    final manager = $$VaultRecordsTableTableManager(
      $_db,
      $_db.vaultRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vaultRecordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HostsTable, List<HostRow>> _hostsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.hosts,
    aliasName: 'ssh_keys__id__hosts__key_id',
  );

  $$HostsTableProcessedTableManager get hostsRefs {
    final manager = $$HostsTableTableManager(
      $_db,
      $_db.hosts,
    ).filter((f) => f.keyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_hostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SshKeysTableFilterComposer
    extends Composer<_$AppDatabase, $SshKeysTable> {
  $$SshKeysTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyType => $composableBuilder(
    column: $table.keyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bits => $composableBuilder(
    column: $table.bits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicLine => $composableBuilder(
    column: $table.publicLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VaultRecordsTableFilterComposer get vaultRecordId {
    final $$VaultRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vaultRecordId,
      referencedTable: $db.vaultRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultRecordsTableFilterComposer(
            $db: $db,
            $table: $db.vaultRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> hostsRefs(
    Expression<bool> Function($$HostsTableFilterComposer f) f,
  ) {
    final $$HostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.keyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableFilterComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SshKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $SshKeysTable> {
  $$SshKeysTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyType => $composableBuilder(
    column: $table.keyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bits => $composableBuilder(
    column: $table.bits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicLine => $composableBuilder(
    column: $table.publicLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VaultRecordsTableOrderingComposer get vaultRecordId {
    final $$VaultRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vaultRecordId,
      referencedTable: $db.vaultRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.vaultRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SshKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $SshKeysTable> {
  $$SshKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get keyType =>
      $composableBuilder(column: $table.keyType, builder: (column) => column);

  GeneratedColumn<int> get bits =>
      $composableBuilder(column: $table.bits, builder: (column) => column);

  GeneratedColumn<String> get publicLine => $composableBuilder(
    column: $table.publicLine,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$VaultRecordsTableAnnotationComposer get vaultRecordId {
    final $$VaultRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vaultRecordId,
      referencedTable: $db.vaultRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.vaultRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> hostsRefs<T extends Object>(
    Expression<T> Function($$HostsTableAnnotationComposer a) f,
  ) {
    final $$HostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.keyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableAnnotationComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SshKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SshKeysTable,
          SshKeyRow,
          $$SshKeysTableFilterComposer,
          $$SshKeysTableOrderingComposer,
          $$SshKeysTableAnnotationComposer,
          $$SshKeysTableCreateCompanionBuilder,
          $$SshKeysTableUpdateCompanionBuilder,
          (SshKeyRow, $$SshKeysTableReferences),
          SshKeyRow,
          PrefetchHooks Function({bool vaultRecordId, bool hostsRefs})
        > {
  $$SshKeysTableTableManager(_$AppDatabase db, $SshKeysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SshKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SshKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SshKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> keyType = const Value.absent(),
                Value<int> bits = const Value.absent(),
                Value<String> publicLine = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> vaultRecordId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SshKeysCompanion(
                id: id,
                label: label,
                keyType: keyType,
                bits: bits,
                publicLine: publicLine,
                fingerprint: fingerprint,
                vaultRecordId: vaultRecordId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                required String keyType,
                required int bits,
                required String publicLine,
                required String fingerprint,
                required String vaultRecordId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SshKeysCompanion.insert(
                id: id,
                label: label,
                keyType: keyType,
                bits: bits,
                publicLine: publicLine,
                fingerprint: fingerprint,
                vaultRecordId: vaultRecordId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SshKeysTable, SshKeyRow>(table),
                  $$SshKeysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vaultRecordId = false, hostsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (hostsRefs) db.hosts],
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
                    if (vaultRecordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vaultRecordId,
                        referencedTable: $$SshKeysTableReferences
                            ._vaultRecordIdTable(db),
                        referencedColumn: $$SshKeysTableReferences
                            ._vaultRecordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (hostsRefs)
                    await $_getPrefetchedDataByColumns<
                      SshKeyRow,
                      $SshKeysTable,
                      HostRow,
                      $HostsTable
                    >(
                      currentTable: table,
                      referencedTable: $$SshKeysTableReferences._hostsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$SshKeysTableReferences(db, table, p0).hostsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'key_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SshKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SshKeysTable,
      SshKeyRow,
      $$SshKeysTableFilterComposer,
      $$SshKeysTableOrderingComposer,
      $$SshKeysTableAnnotationComposer,
      $$SshKeysTableCreateCompanionBuilder,
      $$SshKeysTableUpdateCompanionBuilder,
      (SshKeyRow, $$SshKeysTableReferences),
      SshKeyRow,
      PrefetchHooks Function({bool vaultRecordId, bool hostsRefs})
    >;
typedef $$SecretsTableCreateCompanionBuilder = SecretsCompanion Function({
  required String id,
  required String label,
  required String vaultRecordId,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SecretsTableUpdateCompanionBuilder = SecretsCompanion Function({
  Value<String> id,
  Value<String> label,
  Value<String> vaultRecordId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$SecretsTableReferences
    extends BaseReferences<_$AppDatabase, $SecretsTable, SecretRow> {
  $$SecretsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VaultRecordsTable _vaultRecordIdTable(_$AppDatabase db) => db
      .vaultRecords
      .createAlias('secrets__vault_record_id__vault_records__id');

  $$VaultRecordsTableProcessedTableManager get vaultRecordId {
    final $_column = $_itemColumn<String>('vault_record_id')!;

    final manager = $$VaultRecordsTableTableManager(
      $_db,
      $_db.vaultRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vaultRecordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HostsTable, List<HostRow>> _hostsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.hosts,
    aliasName: 'secrets__id__hosts__secret_id',
  );

  $$HostsTableProcessedTableManager get hostsRefs {
    final manager = $$HostsTableTableManager(
      $_db,
      $_db.hosts,
    ).filter((f) => f.secretId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_hostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SecretsTableFilterComposer
    extends Composer<_$AppDatabase, $SecretsTable> {
  $$SecretsTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
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

  $$VaultRecordsTableFilterComposer get vaultRecordId {
    final $$VaultRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vaultRecordId,
      referencedTable: $db.vaultRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultRecordsTableFilterComposer(
            $db: $db,
            $table: $db.vaultRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> hostsRefs(
    Expression<bool> Function($$HostsTableFilterComposer f) f,
  ) {
    final $$HostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.secretId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableFilterComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SecretsTableOrderingComposer
    extends Composer<_$AppDatabase, $SecretsTable> {
  $$SecretsTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
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

  $$VaultRecordsTableOrderingComposer get vaultRecordId {
    final $$VaultRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vaultRecordId,
      referencedTable: $db.vaultRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.vaultRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SecretsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SecretsTable> {
  $$SecretsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$VaultRecordsTableAnnotationComposer get vaultRecordId {
    final $$VaultRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vaultRecordId,
      referencedTable: $db.vaultRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.vaultRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> hostsRefs<T extends Object>(
    Expression<T> Function($$HostsTableAnnotationComposer a) f,
  ) {
    final $$HostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.secretId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableAnnotationComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SecretsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SecretsTable,
          SecretRow,
          $$SecretsTableFilterComposer,
          $$SecretsTableOrderingComposer,
          $$SecretsTableAnnotationComposer,
          $$SecretsTableCreateCompanionBuilder,
          $$SecretsTableUpdateCompanionBuilder,
          (SecretRow, $$SecretsTableReferences),
          SecretRow,
          PrefetchHooks Function({bool vaultRecordId, bool hostsRefs})
        > {
  $$SecretsTableTableManager(_$AppDatabase db, $SecretsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SecretsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SecretsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SecretsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> vaultRecordId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SecretsCompanion(
                id: id,
                label: label,
                vaultRecordId: vaultRecordId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                required String vaultRecordId,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SecretsCompanion.insert(
                id: id,
                label: label,
                vaultRecordId: vaultRecordId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SecretsTable, SecretRow>(table),
                  $$SecretsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vaultRecordId = false, hostsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (hostsRefs) db.hosts],
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
                    if (vaultRecordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vaultRecordId,
                        referencedTable: $$SecretsTableReferences
                            ._vaultRecordIdTable(db),
                        referencedColumn: $$SecretsTableReferences
                            ._vaultRecordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (hostsRefs)
                    await $_getPrefetchedDataByColumns<
                      SecretRow,
                      $SecretsTable,
                      HostRow,
                      $HostsTable
                    >(
                      currentTable: table,
                      referencedTable: $$SecretsTableReferences._hostsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$SecretsTableReferences(db, table, p0).hostsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'secret_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SecretsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SecretsTable,
      SecretRow,
      $$SecretsTableFilterComposer,
      $$SecretsTableOrderingComposer,
      $$SecretsTableAnnotationComposer,
      $$SecretsTableCreateCompanionBuilder,
      $$SecretsTableUpdateCompanionBuilder,
      (SecretRow, $$SecretsTableReferences),
      SecretRow,
      PrefetchHooks Function({bool vaultRecordId, bool hostsRefs})
    >;
typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String name,
  required bool builtIn,
  required String driver,
  required String command,
  Value<String?> promptRegex,
  Value<String?> successRegex,
  Value<String?> failureRegex,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<bool> builtIn,
  Value<String> driver,
  Value<String> command,
  Value<String?> promptRegex,
  Value<String?> successRegex,
  Value<String?> failureRegex,
  Value<int> rowid,
});

final class $$ProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$HostsTable, List<HostRow>> _hostsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.hosts,
    aliasName: 'profiles__id__hosts__profile_id',
  );

  $$HostsTableProcessedTableManager get hostsRefs {
    final manager = $$HostsTableTableManager(
      $_db,
      $_db.hosts,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_hostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
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

  ColumnFilters<bool> get builtIn => $composableBuilder(
    column: $table.builtIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driver => $composableBuilder(
    column: $table.driver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptRegex => $composableBuilder(
    column: $table.promptRegex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get successRegex => $composableBuilder(
    column: $table.successRegex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureRegex => $composableBuilder(
    column: $table.failureRegex,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> hostsRefs(
    Expression<bool> Function($$HostsTableFilterComposer f) f,
  ) {
    final $$HostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableFilterComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
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

  ColumnOrderings<bool> get builtIn => $composableBuilder(
    column: $table.builtIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driver => $composableBuilder(
    column: $table.driver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptRegex => $composableBuilder(
    column: $table.promptRegex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get successRegex => $composableBuilder(
    column: $table.successRegex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureRegex => $composableBuilder(
    column: $table.failureRegex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
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

  GeneratedColumn<bool> get builtIn =>
      $composableBuilder(column: $table.builtIn, builder: (column) => column);

  GeneratedColumn<String> get driver =>
      $composableBuilder(column: $table.driver, builder: (column) => column);

  GeneratedColumn<String> get command =>
      $composableBuilder(column: $table.command, builder: (column) => column);

  GeneratedColumn<String> get promptRegex => $composableBuilder(
    column: $table.promptRegex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get successRegex => $composableBuilder(
    column: $table.successRegex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureRegex => $composableBuilder(
    column: $table.failureRegex,
    builder: (column) => column,
  );

  Expression<T> hostsRefs<T extends Object>(
    Expression<T> Function($$HostsTableAnnotationComposer a) f,
  ) {
    final $$HostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableAnnotationComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (ProfileRow, $$ProfilesTableReferences),
          ProfileRow,
          PrefetchHooks Function({bool hostsRefs})
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> builtIn = const Value.absent(),
                Value<String> driver = const Value.absent(),
                Value<String> command = const Value.absent(),
                Value<String?> promptRegex = const Value.absent(),
                Value<String?> successRegex = const Value.absent(),
                Value<String?> failureRegex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                name: name,
                builtIn: builtIn,
                driver: driver,
                command: command,
                promptRegex: promptRegex,
                successRegex: successRegex,
                failureRegex: failureRegex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required bool builtIn,
                required String driver,
                required String command,
                Value<String?> promptRegex = const Value.absent(),
                Value<String?> successRegex = const Value.absent(),
                Value<String?> failureRegex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                name: name,
                builtIn: builtIn,
                driver: driver,
                command: command,
                promptRegex: promptRegex,
                successRegex: successRegex,
                failureRegex: failureRegex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, ProfileRow>(table),
                  $$ProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({hostsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (hostsRefs) db.hosts],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (hostsRefs)
                    await $_getPrefetchedDataByColumns<
                      ProfileRow,
                      $ProfilesTable,
                      HostRow,
                      $HostsTable
                    >(
                      currentTable: table,
                      referencedTable: $$ProfilesTableReferences
                          ._hostsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProfilesTableReferences(db, table, p0).hostsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'profile_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, $$ProfilesTableReferences),
      ProfileRow,
      PrefetchHooks Function({bool hostsRefs})
    >;
typedef $$HostsTableCreateCompanionBuilder = HostsCompanion Function({
  required String id,
  required String name,
  Value<String?> groupName,
  required String prebootJson,
  required String loginUser,
  Value<String?> keyId,
  Value<String?> secretId,
  Value<String> diskOverridesJson,
  Value<String?> profileId,
  Value<String?> postbootHost,
  required int postbootPort,
  required String postbootCheck,
  required int waitTimeoutSeconds,
  required int bootTimeoutSeconds,
  Value<String?> prebootKeyJson,
  Value<String?> postbootKeyJson,
  required bool legacyAlgorithms,
  required bool enabled,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$HostsTableUpdateCompanionBuilder = HostsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> groupName,
  Value<String> prebootJson,
  Value<String> loginUser,
  Value<String?> keyId,
  Value<String?> secretId,
  Value<String> diskOverridesJson,
  Value<String?> profileId,
  Value<String?> postbootHost,
  Value<int> postbootPort,
  Value<String> postbootCheck,
  Value<int> waitTimeoutSeconds,
  Value<int> bootTimeoutSeconds,
  Value<String?> prebootKeyJson,
  Value<String?> postbootKeyJson,
  Value<bool> legacyAlgorithms,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$HostsTableReferences
    extends BaseReferences<_$AppDatabase, $HostsTable, HostRow> {
  $$HostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SshKeysTable _keyIdTable(_$AppDatabase db) =>
      db.sshKeys.createAlias('hosts__key_id__ssh_keys__id');

  $$SshKeysTableProcessedTableManager? get keyId {
    final $_column = $_itemColumn<String>('key_id');
    if ($_column == null) return null;
    final manager = $$SshKeysTableTableManager(
      $_db,
      $_db.sshKeys,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_keyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SecretsTable _secretIdTable(_$AppDatabase db) =>
      db.secrets.createAlias('hosts__secret_id__secrets__id');

  $$SecretsTableProcessedTableManager? get secretId {
    final $_column = $_itemColumn<String>('secret_id');
    if ($_column == null) return null;
    final manager = $$SecretsTableTableManager(
      $_db,
      $_db.secrets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_secretIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias('hosts__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager? get profileId {
    final $_column = $_itemColumn<String>('profile_id');
    if ($_column == null) return null;
    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HostsTableFilterComposer extends Composer<_$AppDatabase, $HostsTable> {
  $$HostsTableFilterComposer({
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

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prebootJson => $composableBuilder(
    column: $table.prebootJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loginUser => $composableBuilder(
    column: $table.loginUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diskOverridesJson => $composableBuilder(
    column: $table.diskOverridesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postbootHost => $composableBuilder(
    column: $table.postbootHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get postbootPort => $composableBuilder(
    column: $table.postbootPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postbootCheck => $composableBuilder(
    column: $table.postbootCheck,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get waitTimeoutSeconds => $composableBuilder(
    column: $table.waitTimeoutSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bootTimeoutSeconds => $composableBuilder(
    column: $table.bootTimeoutSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prebootKeyJson => $composableBuilder(
    column: $table.prebootKeyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postbootKeyJson => $composableBuilder(
    column: $table.postbootKeyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get legacyAlgorithms => $composableBuilder(
    column: $table.legacyAlgorithms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SshKeysTableFilterComposer get keyId {
    final $$SshKeysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.keyId,
      referencedTable: $db.sshKeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SshKeysTableFilterComposer(
            $db: $db,
            $table: $db.sshKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SecretsTableFilterComposer get secretId {
    final $$SecretsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.secretId,
      referencedTable: $db.secrets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SecretsTableFilterComposer(
            $db: $db,
            $table: $db.secrets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HostsTableOrderingComposer
    extends Composer<_$AppDatabase, $HostsTable> {
  $$HostsTableOrderingComposer({
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

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prebootJson => $composableBuilder(
    column: $table.prebootJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loginUser => $composableBuilder(
    column: $table.loginUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diskOverridesJson => $composableBuilder(
    column: $table.diskOverridesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postbootHost => $composableBuilder(
    column: $table.postbootHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get postbootPort => $composableBuilder(
    column: $table.postbootPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postbootCheck => $composableBuilder(
    column: $table.postbootCheck,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get waitTimeoutSeconds => $composableBuilder(
    column: $table.waitTimeoutSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bootTimeoutSeconds => $composableBuilder(
    column: $table.bootTimeoutSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prebootKeyJson => $composableBuilder(
    column: $table.prebootKeyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postbootKeyJson => $composableBuilder(
    column: $table.postbootKeyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get legacyAlgorithms => $composableBuilder(
    column: $table.legacyAlgorithms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SshKeysTableOrderingComposer get keyId {
    final $$SshKeysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.keyId,
      referencedTable: $db.sshKeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SshKeysTableOrderingComposer(
            $db: $db,
            $table: $db.sshKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SecretsTableOrderingComposer get secretId {
    final $$SecretsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.secretId,
      referencedTable: $db.secrets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SecretsTableOrderingComposer(
            $db: $db,
            $table: $db.secrets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HostsTable> {
  $$HostsTableAnnotationComposer({
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

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get prebootJson => $composableBuilder(
    column: $table.prebootJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loginUser =>
      $composableBuilder(column: $table.loginUser, builder: (column) => column);

  GeneratedColumn<String> get diskOverridesJson => $composableBuilder(
    column: $table.diskOverridesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get postbootHost => $composableBuilder(
    column: $table.postbootHost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get postbootPort => $composableBuilder(
    column: $table.postbootPort,
    builder: (column) => column,
  );

  GeneratedColumn<String> get postbootCheck => $composableBuilder(
    column: $table.postbootCheck,
    builder: (column) => column,
  );

  GeneratedColumn<int> get waitTimeoutSeconds => $composableBuilder(
    column: $table.waitTimeoutSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bootTimeoutSeconds => $composableBuilder(
    column: $table.bootTimeoutSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prebootKeyJson => $composableBuilder(
    column: $table.prebootKeyJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get postbootKeyJson => $composableBuilder(
    column: $table.postbootKeyJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get legacyAlgorithms => $composableBuilder(
    column: $table.legacyAlgorithms,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SshKeysTableAnnotationComposer get keyId {
    final $$SshKeysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.keyId,
      referencedTable: $db.sshKeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SshKeysTableAnnotationComposer(
            $db: $db,
            $table: $db.sshKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SecretsTableAnnotationComposer get secretId {
    final $$SecretsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.secretId,
      referencedTable: $db.secrets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SecretsTableAnnotationComposer(
            $db: $db,
            $table: $db.secrets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HostsTable,
          HostRow,
          $$HostsTableFilterComposer,
          $$HostsTableOrderingComposer,
          $$HostsTableAnnotationComposer,
          $$HostsTableCreateCompanionBuilder,
          $$HostsTableUpdateCompanionBuilder,
          (HostRow, $$HostsTableReferences),
          HostRow,
          PrefetchHooks Function({bool keyId, bool secretId, bool profileId})
        > {
  $$HostsTableTableManager(_$AppDatabase db, $HostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String> prebootJson = const Value.absent(),
                Value<String> loginUser = const Value.absent(),
                Value<String?> keyId = const Value.absent(),
                Value<String?> secretId = const Value.absent(),
                Value<String> diskOverridesJson = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String?> postbootHost = const Value.absent(),
                Value<int> postbootPort = const Value.absent(),
                Value<String> postbootCheck = const Value.absent(),
                Value<int> waitTimeoutSeconds = const Value.absent(),
                Value<int> bootTimeoutSeconds = const Value.absent(),
                Value<String?> prebootKeyJson = const Value.absent(),
                Value<String?> postbootKeyJson = const Value.absent(),
                Value<bool> legacyAlgorithms = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HostsCompanion(
                id: id,
                name: name,
                groupName: groupName,
                prebootJson: prebootJson,
                loginUser: loginUser,
                keyId: keyId,
                secretId: secretId,
                diskOverridesJson: diskOverridesJson,
                profileId: profileId,
                postbootHost: postbootHost,
                postbootPort: postbootPort,
                postbootCheck: postbootCheck,
                waitTimeoutSeconds: waitTimeoutSeconds,
                bootTimeoutSeconds: bootTimeoutSeconds,
                prebootKeyJson: prebootKeyJson,
                postbootKeyJson: postbootKeyJson,
                legacyAlgorithms: legacyAlgorithms,
                enabled: enabled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> groupName = const Value.absent(),
                required String prebootJson,
                required String loginUser,
                Value<String?> keyId = const Value.absent(),
                Value<String?> secretId = const Value.absent(),
                Value<String> diskOverridesJson = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String?> postbootHost = const Value.absent(),
                required int postbootPort,
                required String postbootCheck,
                required int waitTimeoutSeconds,
                required int bootTimeoutSeconds,
                Value<String?> prebootKeyJson = const Value.absent(),
                Value<String?> postbootKeyJson = const Value.absent(),
                required bool legacyAlgorithms,
                required bool enabled,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => HostsCompanion.insert(
                id: id,
                name: name,
                groupName: groupName,
                prebootJson: prebootJson,
                loginUser: loginUser,
                keyId: keyId,
                secretId: secretId,
                diskOverridesJson: diskOverridesJson,
                profileId: profileId,
                postbootHost: postbootHost,
                postbootPort: postbootPort,
                postbootCheck: postbootCheck,
                waitTimeoutSeconds: waitTimeoutSeconds,
                bootTimeoutSeconds: bootTimeoutSeconds,
                prebootKeyJson: prebootKeyJson,
                postbootKeyJson: postbootKeyJson,
                legacyAlgorithms: legacyAlgorithms,
                enabled: enabled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HostsTable, HostRow>(table),
                  $$HostsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({keyId = false, secretId = false, profileId = false}) {
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
                        if (keyId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.keyId,
                            referencedTable: $$HostsTableReferences._keyIdTable(
                              db,
                            ),
                            referencedColumn: $$HostsTableReferences
                                ._keyIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (secretId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.secretId,
                            referencedTable: $$HostsTableReferences
                                ._secretIdTable(db),
                            referencedColumn: $$HostsTableReferences
                                ._secretIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (profileId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.profileId,
                            referencedTable: $$HostsTableReferences
                                ._profileIdTable(db),
                            referencedColumn: $$HostsTableReferences
                                ._profileIdTable(db)
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

typedef $$HostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HostsTable,
      HostRow,
      $$HostsTableFilterComposer,
      $$HostsTableOrderingComposer,
      $$HostsTableAnnotationComposer,
      $$HostsTableCreateCompanionBuilder,
      $$HostsTableUpdateCompanionBuilder,
      (HostRow, $$HostsTableReferences),
      HostRow,
      PrefetchHooks Function({bool keyId, bool secretId, bool profileId})
    >;
typedef $$VaultPasswordSlotTableCreateCompanionBuilder =
    VaultPasswordSlotCompanion Function({
      Value<int> id,
      required Uint8List salt,
      required int memoryKib,
      required int iterations,
      required int parallelism,
      required Uint8List nonce,
      required Uint8List wrappedKey,
    });
typedef $$VaultPasswordSlotTableUpdateCompanionBuilder =
    VaultPasswordSlotCompanion Function({
      Value<int> id,
      Value<Uint8List> salt,
      Value<int> memoryKib,
      Value<int> iterations,
      Value<int> parallelism,
      Value<Uint8List> nonce,
      Value<Uint8List> wrappedKey,
    });

class $$VaultPasswordSlotTableFilterComposer
    extends Composer<_$AppDatabase, $VaultPasswordSlotTable> {
  $$VaultPasswordSlotTableFilterComposer({
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

  ColumnFilters<Uint8List> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get memoryKib => $composableBuilder(
    column: $table.memoryKib,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iterations => $composableBuilder(
    column: $table.iterations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parallelism => $composableBuilder(
    column: $table.parallelism,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get wrappedKey => $composableBuilder(
    column: $table.wrappedKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultPasswordSlotTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultPasswordSlotTable> {
  $$VaultPasswordSlotTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get memoryKib => $composableBuilder(
    column: $table.memoryKib,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iterations => $composableBuilder(
    column: $table.iterations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parallelism => $composableBuilder(
    column: $table.parallelism,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get wrappedKey => $composableBuilder(
    column: $table.wrappedKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultPasswordSlotTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultPasswordSlotTable> {
  $$VaultPasswordSlotTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get salt =>
      $composableBuilder(column: $table.salt, builder: (column) => column);

  GeneratedColumn<int> get memoryKib =>
      $composableBuilder(column: $table.memoryKib, builder: (column) => column);

  GeneratedColumn<int> get iterations => $composableBuilder(
    column: $table.iterations,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parallelism => $composableBuilder(
    column: $table.parallelism,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get nonce =>
      $composableBuilder(column: $table.nonce, builder: (column) => column);

  GeneratedColumn<Uint8List> get wrappedKey => $composableBuilder(
    column: $table.wrappedKey,
    builder: (column) => column,
  );
}

class $$VaultPasswordSlotTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultPasswordSlotTable,
          PasswordSlotRow,
          $$VaultPasswordSlotTableFilterComposer,
          $$VaultPasswordSlotTableOrderingComposer,
          $$VaultPasswordSlotTableAnnotationComposer,
          $$VaultPasswordSlotTableCreateCompanionBuilder,
          $$VaultPasswordSlotTableUpdateCompanionBuilder,
          (
            PasswordSlotRow,
            BaseReferences<
              _$AppDatabase,
              $VaultPasswordSlotTable,
              PasswordSlotRow
            >,
          ),
          PasswordSlotRow,
          PrefetchHooks Function()
        > {
  $$VaultPasswordSlotTableTableManager(
    _$AppDatabase db,
    $VaultPasswordSlotTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultPasswordSlotTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultPasswordSlotTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultPasswordSlotTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Uint8List> salt = const Value.absent(),
                Value<int> memoryKib = const Value.absent(),
                Value<int> iterations = const Value.absent(),
                Value<int> parallelism = const Value.absent(),
                Value<Uint8List> nonce = const Value.absent(),
                Value<Uint8List> wrappedKey = const Value.absent(),
              }) => VaultPasswordSlotCompanion(
                id: id,
                salt: salt,
                memoryKib: memoryKib,
                iterations: iterations,
                parallelism: parallelism,
                nonce: nonce,
                wrappedKey: wrappedKey,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Uint8List salt,
                required int memoryKib,
                required int iterations,
                required int parallelism,
                required Uint8List nonce,
                required Uint8List wrappedKey,
              }) => VaultPasswordSlotCompanion.insert(
                id: id,
                salt: salt,
                memoryKib: memoryKib,
                iterations: iterations,
                parallelism: parallelism,
                nonce: nonce,
                wrappedKey: wrappedKey,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultPasswordSlotTable, PasswordSlotRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $VaultPasswordSlotTable,
                    PasswordSlotRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultPasswordSlotTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultPasswordSlotTable,
      PasswordSlotRow,
      $$VaultPasswordSlotTableFilterComposer,
      $$VaultPasswordSlotTableOrderingComposer,
      $$VaultPasswordSlotTableAnnotationComposer,
      $$VaultPasswordSlotTableCreateCompanionBuilder,
      $$VaultPasswordSlotTableUpdateCompanionBuilder,
      (
        PasswordSlotRow,
        BaseReferences<_$AppDatabase, $VaultPasswordSlotTable, PasswordSlotRow>,
      ),
      PasswordSlotRow,
      PrefetchHooks Function()
    >;
typedef $$VaultMetadataTableTableCreateCompanionBuilder =
    VaultMetadataTableCompanion Function({
      Value<int> id,
      required int formatVersion,
      required String vaultId,
      required Uint8List keyCheckNonce,
      required Uint8List keyCheck,
      required bool biometricSlotEnrolled,
    });
typedef $$VaultMetadataTableTableUpdateCompanionBuilder =
    VaultMetadataTableCompanion Function({
      Value<int> id,
      Value<int> formatVersion,
      Value<String> vaultId,
      Value<Uint8List> keyCheckNonce,
      Value<Uint8List> keyCheck,
      Value<bool> biometricSlotEnrolled,
    });

class $$VaultMetadataTableTableFilterComposer
    extends Composer<_$AppDatabase, $VaultMetadataTableTable> {
  $$VaultMetadataTableTableFilterComposer({
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

  ColumnFilters<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get keyCheckNonce => $composableBuilder(
    column: $table.keyCheckNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get keyCheck => $composableBuilder(
    column: $table.keyCheck,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get biometricSlotEnrolled => $composableBuilder(
    column: $table.biometricSlotEnrolled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultMetadataTableTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultMetadataTableTable> {
  $$VaultMetadataTableTableOrderingComposer({
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

  ColumnOrderings<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaultId => $composableBuilder(
    column: $table.vaultId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get keyCheckNonce => $composableBuilder(
    column: $table.keyCheckNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get keyCheck => $composableBuilder(
    column: $table.keyCheck,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get biometricSlotEnrolled => $composableBuilder(
    column: $table.biometricSlotEnrolled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultMetadataTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultMetadataTableTable> {
  $$VaultMetadataTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vaultId =>
      $composableBuilder(column: $table.vaultId, builder: (column) => column);

  GeneratedColumn<Uint8List> get keyCheckNonce => $composableBuilder(
    column: $table.keyCheckNonce,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get keyCheck =>
      $composableBuilder(column: $table.keyCheck, builder: (column) => column);

  GeneratedColumn<bool> get biometricSlotEnrolled => $composableBuilder(
    column: $table.biometricSlotEnrolled,
    builder: (column) => column,
  );
}

class $$VaultMetadataTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultMetadataTableTable,
          VaultMetadataRow,
          $$VaultMetadataTableTableFilterComposer,
          $$VaultMetadataTableTableOrderingComposer,
          $$VaultMetadataTableTableAnnotationComposer,
          $$VaultMetadataTableTableCreateCompanionBuilder,
          $$VaultMetadataTableTableUpdateCompanionBuilder,
          (
            VaultMetadataRow,
            BaseReferences<
              _$AppDatabase,
              $VaultMetadataTableTable,
              VaultMetadataRow
            >,
          ),
          VaultMetadataRow,
          PrefetchHooks Function()
        > {
  $$VaultMetadataTableTableTableManager(
    _$AppDatabase db,
    $VaultMetadataTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultMetadataTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultMetadataTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultMetadataTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<String> vaultId = const Value.absent(),
                Value<Uint8List> keyCheckNonce = const Value.absent(),
                Value<Uint8List> keyCheck = const Value.absent(),
                Value<bool> biometricSlotEnrolled = const Value.absent(),
              }) => VaultMetadataTableCompanion(
                id: id,
                formatVersion: formatVersion,
                vaultId: vaultId,
                keyCheckNonce: keyCheckNonce,
                keyCheck: keyCheck,
                biometricSlotEnrolled: biometricSlotEnrolled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int formatVersion,
                required String vaultId,
                required Uint8List keyCheckNonce,
                required Uint8List keyCheck,
                required bool biometricSlotEnrolled,
              }) => VaultMetadataTableCompanion.insert(
                id: id,
                formatVersion: formatVersion,
                vaultId: vaultId,
                keyCheckNonce: keyCheckNonce,
                keyCheck: keyCheck,
                biometricSlotEnrolled: biometricSlotEnrolled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultMetadataTableTable, VaultMetadataRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $VaultMetadataTableTable,
                    VaultMetadataRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultMetadataTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultMetadataTableTable,
      VaultMetadataRow,
      $$VaultMetadataTableTableFilterComposer,
      $$VaultMetadataTableTableOrderingComposer,
      $$VaultMetadataTableTableAnnotationComposer,
      $$VaultMetadataTableTableCreateCompanionBuilder,
      $$VaultMetadataTableTableUpdateCompanionBuilder,
      (
        VaultMetadataRow,
        BaseReferences<
          _$AppDatabase,
          $VaultMetadataTableTable,
          VaultMetadataRow
        >,
      ),
      VaultMetadataRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
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
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
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
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
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
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          SettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>(
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

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      SettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$RunsTableCreateCompanionBuilder = RunsCompanion Function({
  required String id,
  required String title,
  required DateTime startedAt,
  Value<DateTime?> finishedAt,
  Value<int> rowid,
});
typedef $$RunsTableUpdateCompanionBuilder = RunsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<DateTime> startedAt,
  Value<DateTime?> finishedAt,
  Value<int> rowid,
});

final class $$RunsTableReferences
    extends BaseReferences<_$AppDatabase, $RunsTable, RunRow> {
  $$RunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RunHostsTable, List<RunHostRow>>
  _runHostsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.runHosts,
    aliasName: 'runs__id__run_hosts__run_id',
  );

  $$RunHostsTableProcessedTableManager get runHostsRefs {
    final manager = $$RunHostsTableTableManager(
      $_db,
      $_db.runHosts,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_runHostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RunEventsTable, List<RunEventRow>>
  _runEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.runEvents,
    aliasName: 'runs__id__run_events__run_id',
  );

  $$RunEventsTableProcessedTableManager get runEventsRefs {
    final manager = $$RunEventsTableTableManager(
      $_db,
      $_db.runEvents,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_runEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RunsTableFilterComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> runHostsRefs(
    Expression<bool> Function($$RunHostsTableFilterComposer f) f,
  ) {
    final $$RunHostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runHosts,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunHostsTableFilterComposer(
            $db: $db,
            $table: $db.runHosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> runEventsRefs(
    Expression<bool> Function($$RunEventsTableFilterComposer f) f,
  ) {
    final $$RunEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runEvents,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunEventsTableFilterComposer(
            $db: $db,
            $table: $db.runEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunsTableOrderingComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  Expression<T> runHostsRefs<T extends Object>(
    Expression<T> Function($$RunHostsTableAnnotationComposer a) f,
  ) {
    final $$RunHostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runHosts,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunHostsTableAnnotationComposer(
            $db: $db,
            $table: $db.runHosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> runEventsRefs<T extends Object>(
    Expression<T> Function($$RunEventsTableAnnotationComposer a) f,
  ) {
    final $$RunEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runEvents,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.runEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunsTable,
          RunRow,
          $$RunsTableFilterComposer,
          $$RunsTableOrderingComposer,
          $$RunsTableAnnotationComposer,
          $$RunsTableCreateCompanionBuilder,
          $$RunsTableUpdateCompanionBuilder,
          (RunRow, $$RunsTableReferences),
          RunRow,
          PrefetchHooks Function({bool runHostsRefs, bool runEventsRefs})
        > {
  $$RunsTableTableManager(_$AppDatabase db, $RunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion(
                id: id,
                title: title,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion.insert(
                id: id,
                title: title,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RunsTable, RunRow>(table),
                  $$RunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({runHostsRefs = false, runEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (runHostsRefs) db.runHosts,
                    if (runEventsRefs) db.runEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (runHostsRefs)
                        await $_getPrefetchedDataByColumns<
                          RunRow,
                          $RunsTable,
                          RunHostRow,
                          $RunHostsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RunsTableReferences
                              ._runHostsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RunsTableReferences(db, table, p0).runHostsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'run_id',
                          typedResults: items,
                        ),
                      if (runEventsRefs)
                        await $_getPrefetchedDataByColumns<
                          RunRow,
                          $RunsTable,
                          RunEventRow,
                          $RunEventsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RunsTableReferences
                              ._runEventsRefsTable(db),
                          managerFromTypedResult: (p0) => $$RunsTableReferences(
                            db,
                            table,
                            p0,
                          ).runEventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'run_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunsTable,
      RunRow,
      $$RunsTableFilterComposer,
      $$RunsTableOrderingComposer,
      $$RunsTableAnnotationComposer,
      $$RunsTableCreateCompanionBuilder,
      $$RunsTableUpdateCompanionBuilder,
      (RunRow, $$RunsTableReferences),
      RunRow,
      PrefetchHooks Function({bool runHostsRefs, bool runEventsRefs})
    >;
typedef $$RunHostsTableCreateCompanionBuilder = RunHostsCompanion Function({
  required String runId,
  required String hostId,
  required String hostName,
  Value<String?> finalState,
  Value<int> rowid,
});
typedef $$RunHostsTableUpdateCompanionBuilder = RunHostsCompanion Function({
  Value<String> runId,
  Value<String> hostId,
  Value<String> hostName,
  Value<String?> finalState,
  Value<int> rowid,
});

final class $$RunHostsTableReferences
    extends BaseReferences<_$AppDatabase, $RunHostsTable, RunHostRow> {
  $$RunHostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RunsTable _runIdTable(_$AppDatabase db) =>
      db.runs.createAlias('run_hosts__run_id__runs__id');

  $$RunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$RunsTableTableManager(
      $_db,
      $_db.runs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RunHostsTableFilterComposer
    extends Composer<_$AppDatabase, $RunHostsTable> {
  $$RunHostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hostId => $composableBuilder(
    column: $table.hostId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hostName => $composableBuilder(
    column: $table.hostName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalState => $composableBuilder(
    column: $table.finalState,
    builder: (column) => ColumnFilters(column),
  );

  $$RunsTableFilterComposer get runId {
    final $$RunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableFilterComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunHostsTableOrderingComposer
    extends Composer<_$AppDatabase, $RunHostsTable> {
  $$RunHostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hostId => $composableBuilder(
    column: $table.hostId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hostName => $composableBuilder(
    column: $table.hostName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalState => $composableBuilder(
    column: $table.finalState,
    builder: (column) => ColumnOrderings(column),
  );

  $$RunsTableOrderingComposer get runId {
    final $$RunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableOrderingComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunHostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunHostsTable> {
  $$RunHostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hostId =>
      $composableBuilder(column: $table.hostId, builder: (column) => column);

  GeneratedColumn<String> get hostName =>
      $composableBuilder(column: $table.hostName, builder: (column) => column);

  GeneratedColumn<String> get finalState => $composableBuilder(
    column: $table.finalState,
    builder: (column) => column,
  );

  $$RunsTableAnnotationComposer get runId {
    final $$RunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableAnnotationComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunHostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunHostsTable,
          RunHostRow,
          $$RunHostsTableFilterComposer,
          $$RunHostsTableOrderingComposer,
          $$RunHostsTableAnnotationComposer,
          $$RunHostsTableCreateCompanionBuilder,
          $$RunHostsTableUpdateCompanionBuilder,
          (RunHostRow, $$RunHostsTableReferences),
          RunHostRow,
          PrefetchHooks Function({bool runId})
        > {
  $$RunHostsTableTableManager(_$AppDatabase db, $RunHostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunHostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunHostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunHostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> runId = const Value.absent(),
                Value<String> hostId = const Value.absent(),
                Value<String> hostName = const Value.absent(),
                Value<String?> finalState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunHostsCompanion(
                runId: runId,
                hostId: hostId,
                hostName: hostName,
                finalState: finalState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String runId,
                required String hostId,
                required String hostName,
                Value<String?> finalState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunHostsCompanion.insert(
                runId: runId,
                hostId: hostId,
                hostName: hostName,
                finalState: finalState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RunHostsTable, RunHostRow>(table),
                  $$RunHostsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
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
                    if (runId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.runId,
                        referencedTable: $$RunHostsTableReferences._runIdTable(
                          db,
                        ),
                        referencedColumn: $$RunHostsTableReferences
                            ._runIdTable(db)
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

typedef $$RunHostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunHostsTable,
      RunHostRow,
      $$RunHostsTableFilterComposer,
      $$RunHostsTableOrderingComposer,
      $$RunHostsTableAnnotationComposer,
      $$RunHostsTableCreateCompanionBuilder,
      $$RunHostsTableUpdateCompanionBuilder,
      (RunHostRow, $$RunHostsTableReferences),
      RunHostRow,
      PrefetchHooks Function({bool runId})
    >;
typedef $$RunEventsTableCreateCompanionBuilder = RunEventsCompanion Function({
  Value<int> id,
  required String runId,
  required String hostId,
  required DateTime time,
  required String phase,
  required String message,
  Value<String?> result,
});
typedef $$RunEventsTableUpdateCompanionBuilder = RunEventsCompanion Function({
  Value<int> id,
  Value<String> runId,
  Value<String> hostId,
  Value<DateTime> time,
  Value<String> phase,
  Value<String> message,
  Value<String?> result,
});

final class $$RunEventsTableReferences
    extends BaseReferences<_$AppDatabase, $RunEventsTable, RunEventRow> {
  $$RunEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RunsTable _runIdTable(_$AppDatabase db) =>
      db.runs.createAlias('run_events__run_id__runs__id');

  $$RunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$RunsTableTableManager(
      $_db,
      $_db.runs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RunEventsTableFilterComposer
    extends Composer<_$AppDatabase, $RunEventsTable> {
  $$RunEventsTableFilterComposer({
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

  ColumnFilters<String> get hostId => $composableBuilder(
    column: $table.hostId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  $$RunsTableFilterComposer get runId {
    final $$RunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableFilterComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $RunEventsTable> {
  $$RunEventsTableOrderingComposer({
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

  ColumnOrderings<String> get hostId => $composableBuilder(
    column: $table.hostId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  $$RunsTableOrderingComposer get runId {
    final $$RunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableOrderingComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunEventsTable> {
  $$RunEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hostId =>
      $composableBuilder(column: $table.hostId, builder: (column) => column);

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  $$RunsTableAnnotationComposer get runId {
    final $$RunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableAnnotationComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunEventsTable,
          RunEventRow,
          $$RunEventsTableFilterComposer,
          $$RunEventsTableOrderingComposer,
          $$RunEventsTableAnnotationComposer,
          $$RunEventsTableCreateCompanionBuilder,
          $$RunEventsTableUpdateCompanionBuilder,
          (RunEventRow, $$RunEventsTableReferences),
          RunEventRow,
          PrefetchHooks Function({bool runId})
        > {
  $$RunEventsTableTableManager(_$AppDatabase db, $RunEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> hostId = const Value.absent(),
                Value<DateTime> time = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String?> result = const Value.absent(),
              }) => RunEventsCompanion(
                id: id,
                runId: runId,
                hostId: hostId,
                time: time,
                phase: phase,
                message: message,
                result: result,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String runId,
                required String hostId,
                required DateTime time,
                required String phase,
                required String message,
                Value<String?> result = const Value.absent(),
              }) => RunEventsCompanion.insert(
                id: id,
                runId: runId,
                hostId: hostId,
                time: time,
                phase: phase,
                message: message,
                result: result,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RunEventsTable, RunEventRow>(table),
                  $$RunEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
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
                    if (runId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.runId,
                        referencedTable: $$RunEventsTableReferences._runIdTable(
                          db,
                        ),
                        referencedColumn: $$RunEventsTableReferences
                            ._runIdTable(db)
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

typedef $$RunEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunEventsTable,
      RunEventRow,
      $$RunEventsTableFilterComposer,
      $$RunEventsTableOrderingComposer,
      $$RunEventsTableAnnotationComposer,
      $$RunEventsTableCreateCompanionBuilder,
      $$RunEventsTableUpdateCompanionBuilder,
      (RunEventRow, $$RunEventsTableReferences),
      RunEventRow,
      PrefetchHooks Function({bool runId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VaultRecordsTableTableManager get vaultRecords =>
      $$VaultRecordsTableTableManager(_db, _db.vaultRecords);
  $$SshKeysTableTableManager get sshKeys =>
      $$SshKeysTableTableManager(_db, _db.sshKeys);
  $$SecretsTableTableManager get secrets =>
      $$SecretsTableTableManager(_db, _db.secrets);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$HostsTableTableManager get hosts =>
      $$HostsTableTableManager(_db, _db.hosts);
  $$VaultPasswordSlotTableTableManager get vaultPasswordSlot =>
      $$VaultPasswordSlotTableTableManager(_db, _db.vaultPasswordSlot);
  $$VaultMetadataTableTableTableManager get vaultMetadataTable =>
      $$VaultMetadataTableTableTableManager(_db, _db.vaultMetadataTable);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$RunsTableTableManager get runs => $$RunsTableTableManager(_db, _db.runs);
  $$RunHostsTableTableManager get runHosts =>
      $$RunHostsTableTableManager(_db, _db.runHosts);
  $$RunEventsTableTableManager get runEvents =>
      $$RunEventsTableTableManager(_db, _db.runEvents);
}
