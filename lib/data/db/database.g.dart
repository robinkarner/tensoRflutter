// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects
    with TableInfo<$ProjectsTable, ProjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonValueMeta = const VerificationMeta(
    'jsonValue',
  );
  @override
  late final GeneratedColumn<String> jsonValue = GeneratedColumn<String>(
    'json_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, jsonValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json_value')) {
      context.handle(
        _jsonValueMeta,
        jsonValue.isAcceptableOrUnknown(data['json_value']!, _jsonValueMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      jsonValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_value'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class ProjectRow extends DataClass implements Insertable<ProjectRow> {
  final String id;

  /// Der rohe ProjectRecord als JSON.
  final String jsonValue;
  const ProjectRow({required this.id, required this.jsonValue});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['json_value'] = Variable<String>(jsonValue);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(id: Value(id), jsonValue: Value(jsonValue));
  }

  factory ProjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectRow(
      id: serializer.fromJson<String>(json['id']),
      jsonValue: serializer.fromJson<String>(json['jsonValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'jsonValue': serializer.toJson<String>(jsonValue),
    };
  }

  ProjectRow copyWith({String? id, String? jsonValue}) =>
      ProjectRow(id: id ?? this.id, jsonValue: jsonValue ?? this.jsonValue);
  ProjectRow copyWithCompanion(ProjectsCompanion data) {
    return ProjectRow(
      id: data.id.present ? data.id.value : this.id,
      jsonValue: data.jsonValue.present ? data.jsonValue.value : this.jsonValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRow(')
          ..write('id: $id, ')
          ..write('jsonValue: $jsonValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, jsonValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectRow &&
          other.id == this.id &&
          other.jsonValue == this.jsonValue);
}

class ProjectsCompanion extends UpdateCompanion<ProjectRow> {
  final Value<String> id;
  final Value<String> jsonValue;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.jsonValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String jsonValue,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       jsonValue = Value(jsonValue);
  static Insertable<ProjectRow> custom({
    Expression<String>? id,
    Expression<String>? jsonValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jsonValue != null) 'json_value': jsonValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? jsonValue,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      jsonValue: jsonValue ?? this.jsonValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (jsonValue.present) {
      map['json_value'] = Variable<String>(jsonValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('jsonValue: $jsonValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KvTable extends Kv with TableInfo<$KvTable, KvRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonValueMeta = const VerificationMeta(
    'jsonValue',
  );
  @override
  late final GeneratedColumn<String> jsonValue = GeneratedColumn<String>(
    'json_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [projectId, key, jsonValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<KvRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json_value')) {
      context.handle(
        _jsonValueMeta,
        jsonValue.isAcceptableOrUnknown(data['json_value']!, _jsonValueMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId, key};
  @override
  KvRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvRow(
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      jsonValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_value'],
      )!,
    );
  }

  @override
  $KvTable createAlias(String alias) {
    return $KvTable(attachedDatabase, alias);
  }
}

class KvRow extends DataClass implements Insertable<KvRow> {
  final String projectId;
  final String key;
  final String jsonValue;
  const KvRow({
    required this.projectId,
    required this.key,
    required this.jsonValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['key'] = Variable<String>(key);
    map['json_value'] = Variable<String>(jsonValue);
    return map;
  }

  KvCompanion toCompanion(bool nullToAbsent) {
    return KvCompanion(
      projectId: Value(projectId),
      key: Value(key),
      jsonValue: Value(jsonValue),
    );
  }

  factory KvRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvRow(
      projectId: serializer.fromJson<String>(json['projectId']),
      key: serializer.fromJson<String>(json['key']),
      jsonValue: serializer.fromJson<String>(json['jsonValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'projectId': serializer.toJson<String>(projectId),
      'key': serializer.toJson<String>(key),
      'jsonValue': serializer.toJson<String>(jsonValue),
    };
  }

  KvRow copyWith({String? projectId, String? key, String? jsonValue}) => KvRow(
    projectId: projectId ?? this.projectId,
    key: key ?? this.key,
    jsonValue: jsonValue ?? this.jsonValue,
  );
  KvRow copyWithCompanion(KvCompanion data) {
    return KvRow(
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      key: data.key.present ? data.key.value : this.key,
      jsonValue: data.jsonValue.present ? data.jsonValue.value : this.jsonValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvRow(')
          ..write('projectId: $projectId, ')
          ..write('key: $key, ')
          ..write('jsonValue: $jsonValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(projectId, key, jsonValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvRow &&
          other.projectId == this.projectId &&
          other.key == this.key &&
          other.jsonValue == this.jsonValue);
}

class KvCompanion extends UpdateCompanion<KvRow> {
  final Value<String> projectId;
  final Value<String> key;
  final Value<String> jsonValue;
  final Value<int> rowid;
  const KvCompanion({
    this.projectId = const Value.absent(),
    this.key = const Value.absent(),
    this.jsonValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvCompanion.insert({
    required String projectId,
    required String key,
    required String jsonValue,
    this.rowid = const Value.absent(),
  }) : projectId = Value(projectId),
       key = Value(key),
       jsonValue = Value(jsonValue);
  static Insertable<KvRow> custom({
    Expression<String>? projectId,
    Expression<String>? key,
    Expression<String>? jsonValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (key != null) 'key': key,
      if (jsonValue != null) 'json_value': jsonValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvCompanion copyWith({
    Value<String>? projectId,
    Value<String>? key,
    Value<String>? jsonValue,
    Value<int>? rowid,
  }) {
    return KvCompanion(
      projectId: projectId ?? this.projectId,
      key: key ?? this.key,
      jsonValue: jsonValue ?? this.jsonValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (jsonValue.present) {
      map['json_value'] = Variable<String>(jsonValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvCompanion(')
          ..write('projectId: $projectId, ')
          ..write('key: $key, ')
          ..write('jsonValue: $jsonValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PdfBlobsTable extends PdfBlobs
    with TableInfo<$PdfBlobsTable, PdfBlobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PdfBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<Uint8List> data = GeneratedColumn<Uint8List>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, data, mime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pdf_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PdfBlobRow> instance, {
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
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PdfBlobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PdfBlobRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}data'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      ),
    );
  }

  @override
  $PdfBlobsTable createAlias(String alias) {
    return $PdfBlobsTable(attachedDatabase, alias);
  }
}

class PdfBlobRow extends DataClass implements Insertable<PdfBlobRow> {
  final String key;
  final Uint8List data;

  /// MIME-Typ (Original speichert Blob/File samt type) — für Bilder relevant.
  final String? mime;
  const PdfBlobRow({required this.key, required this.data, this.mime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['data'] = Variable<Uint8List>(data);
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    return map;
  }

  PdfBlobsCompanion toCompanion(bool nullToAbsent) {
    return PdfBlobsCompanion(
      key: Value(key),
      data: Value(data),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
    );
  }

  factory PdfBlobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PdfBlobRow(
      key: serializer.fromJson<String>(json['key']),
      data: serializer.fromJson<Uint8List>(json['data']),
      mime: serializer.fromJson<String?>(json['mime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'data': serializer.toJson<Uint8List>(data),
      'mime': serializer.toJson<String?>(mime),
    };
  }

  PdfBlobRow copyWith({
    String? key,
    Uint8List? data,
    Value<String?> mime = const Value.absent(),
  }) => PdfBlobRow(
    key: key ?? this.key,
    data: data ?? this.data,
    mime: mime.present ? mime.value : this.mime,
  );
  PdfBlobRow copyWithCompanion(PdfBlobsCompanion data) {
    return PdfBlobRow(
      key: data.key.present ? data.key.value : this.key,
      data: data.data.present ? data.data.value : this.data,
      mime: data.mime.present ? data.mime.value : this.mime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PdfBlobRow(')
          ..write('key: $key, ')
          ..write('data: $data, ')
          ..write('mime: $mime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, $driftBlobEquality.hash(data), mime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PdfBlobRow &&
          other.key == this.key &&
          $driftBlobEquality.equals(other.data, this.data) &&
          other.mime == this.mime);
}

class PdfBlobsCompanion extends UpdateCompanion<PdfBlobRow> {
  final Value<String> key;
  final Value<Uint8List> data;
  final Value<String?> mime;
  final Value<int> rowid;
  const PdfBlobsCompanion({
    this.key = const Value.absent(),
    this.data = const Value.absent(),
    this.mime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PdfBlobsCompanion.insert({
    required String key,
    required Uint8List data,
    this.mime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       data = Value(data);
  static Insertable<PdfBlobRow> custom({
    Expression<String>? key,
    Expression<Uint8List>? data,
    Expression<String>? mime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (data != null) 'data': data,
      if (mime != null) 'mime': mime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PdfBlobsCompanion copyWith({
    Value<String>? key,
    Value<Uint8List>? data,
    Value<String?>? mime,
    Value<int>? rowid,
  }) {
    return PdfBlobsCompanion(
      key: key ?? this.key,
      data: data ?? this.data,
      mime: mime ?? this.mime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (data.present) {
      map['data'] = Variable<Uint8List>(data.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PdfBlobsCompanion(')
          ..write('key: $key, ')
          ..write('data: $data, ')
          ..write('mime: $mime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FigImgsTable extends FigImgs with TableInfo<$FigImgsTable, FigImgRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FigImgsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _figIdMeta = const VerificationMeta('figId');
  @override
  late final GeneratedColumn<String> figId = GeneratedColumn<String>(
    'fig_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<Uint8List> data = GeneratedColumn<Uint8List>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [figId, data, mime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fig_imgs';
  @override
  VerificationContext validateIntegrity(
    Insertable<FigImgRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fig_id')) {
      context.handle(
        _figIdMeta,
        figId.isAcceptableOrUnknown(data['fig_id']!, _figIdMeta),
      );
    } else if (isInserting) {
      context.missing(_figIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {figId};
  @override
  FigImgRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FigImgRow(
      figId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fig_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}data'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      ),
    );
  }

  @override
  $FigImgsTable createAlias(String alias) {
    return $FigImgsTable(attachedDatabase, alias);
  }
}

class FigImgRow extends DataClass implements Insertable<FigImgRow> {
  final String figId;
  final Uint8List data;
  final String? mime;
  const FigImgRow({required this.figId, required this.data, this.mime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['fig_id'] = Variable<String>(figId);
    map['data'] = Variable<Uint8List>(data);
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    return map;
  }

  FigImgsCompanion toCompanion(bool nullToAbsent) {
    return FigImgsCompanion(
      figId: Value(figId),
      data: Value(data),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
    );
  }

  factory FigImgRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FigImgRow(
      figId: serializer.fromJson<String>(json['figId']),
      data: serializer.fromJson<Uint8List>(json['data']),
      mime: serializer.fromJson<String?>(json['mime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'figId': serializer.toJson<String>(figId),
      'data': serializer.toJson<Uint8List>(data),
      'mime': serializer.toJson<String?>(mime),
    };
  }

  FigImgRow copyWith({
    String? figId,
    Uint8List? data,
    Value<String?> mime = const Value.absent(),
  }) => FigImgRow(
    figId: figId ?? this.figId,
    data: data ?? this.data,
    mime: mime.present ? mime.value : this.mime,
  );
  FigImgRow copyWithCompanion(FigImgsCompanion data) {
    return FigImgRow(
      figId: data.figId.present ? data.figId.value : this.figId,
      data: data.data.present ? data.data.value : this.data,
      mime: data.mime.present ? data.mime.value : this.mime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FigImgRow(')
          ..write('figId: $figId, ')
          ..write('data: $data, ')
          ..write('mime: $mime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(figId, $driftBlobEquality.hash(data), mime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FigImgRow &&
          other.figId == this.figId &&
          $driftBlobEquality.equals(other.data, this.data) &&
          other.mime == this.mime);
}

class FigImgsCompanion extends UpdateCompanion<FigImgRow> {
  final Value<String> figId;
  final Value<Uint8List> data;
  final Value<String?> mime;
  final Value<int> rowid;
  const FigImgsCompanion({
    this.figId = const Value.absent(),
    this.data = const Value.absent(),
    this.mime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FigImgsCompanion.insert({
    required String figId,
    required Uint8List data,
    this.mime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : figId = Value(figId),
       data = Value(data);
  static Insertable<FigImgRow> custom({
    Expression<String>? figId,
    Expression<Uint8List>? data,
    Expression<String>? mime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (figId != null) 'fig_id': figId,
      if (data != null) 'data': data,
      if (mime != null) 'mime': mime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FigImgsCompanion copyWith({
    Value<String>? figId,
    Value<Uint8List>? data,
    Value<String?>? mime,
    Value<int>? rowid,
  }) {
    return FigImgsCompanion(
      figId: figId ?? this.figId,
      data: data ?? this.data,
      mime: mime ?? this.mime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (figId.present) {
      map['fig_id'] = Variable<String>(figId.value);
    }
    if (data.present) {
      map['data'] = Variable<Uint8List>(data.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FigImgsCompanion(')
          ..write('figId: $figId, ')
          ..write('data: $data, ')
          ..write('mime: $mime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OcrTextsTable extends OcrTexts with TableInfo<$OcrTextsTable, OcrRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OcrTextsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _srcIdMeta = const VerificationMeta('srcId');
  @override
  late final GeneratedColumn<String> srcId = GeneratedColumn<String>(
    'src_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
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
  @override
  List<GeneratedColumn> get $columns => [srcId, page, content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ocr_texts';
  @override
  VerificationContext validateIntegrity(
    Insertable<OcrRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('src_id')) {
      context.handle(
        _srcIdMeta,
        srcId.isAcceptableOrUnknown(data['src_id']!, _srcIdMeta),
      );
    } else if (isInserting) {
      context.missing(_srcIdMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    } else if (isInserting) {
      context.missing(_pageMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {srcId, page};
  @override
  OcrRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OcrRow(
      srcId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}src_id'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
    );
  }

  @override
  $OcrTextsTable createAlias(String alias) {
    return $OcrTextsTable(attachedDatabase, alias);
  }
}

class OcrRow extends DataClass implements Insertable<OcrRow> {
  final String srcId;
  final int page;
  final String content;
  const OcrRow({
    required this.srcId,
    required this.page,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['src_id'] = Variable<String>(srcId);
    map['page'] = Variable<int>(page);
    map['content'] = Variable<String>(content);
    return map;
  }

  OcrTextsCompanion toCompanion(bool nullToAbsent) {
    return OcrTextsCompanion(
      srcId: Value(srcId),
      page: Value(page),
      content: Value(content),
    );
  }

  factory OcrRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OcrRow(
      srcId: serializer.fromJson<String>(json['srcId']),
      page: serializer.fromJson<int>(json['page']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'srcId': serializer.toJson<String>(srcId),
      'page': serializer.toJson<int>(page),
      'content': serializer.toJson<String>(content),
    };
  }

  OcrRow copyWith({String? srcId, int? page, String? content}) => OcrRow(
    srcId: srcId ?? this.srcId,
    page: page ?? this.page,
    content: content ?? this.content,
  );
  OcrRow copyWithCompanion(OcrTextsCompanion data) {
    return OcrRow(
      srcId: data.srcId.present ? data.srcId.value : this.srcId,
      page: data.page.present ? data.page.value : this.page,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OcrRow(')
          ..write('srcId: $srcId, ')
          ..write('page: $page, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(srcId, page, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrRow &&
          other.srcId == this.srcId &&
          other.page == this.page &&
          other.content == this.content);
}

class OcrTextsCompanion extends UpdateCompanion<OcrRow> {
  final Value<String> srcId;
  final Value<int> page;
  final Value<String> content;
  final Value<int> rowid;
  const OcrTextsCompanion({
    this.srcId = const Value.absent(),
    this.page = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OcrTextsCompanion.insert({
    required String srcId,
    required int page,
    required String content,
    this.rowid = const Value.absent(),
  }) : srcId = Value(srcId),
       page = Value(page),
       content = Value(content);
  static Insertable<OcrRow> custom({
    Expression<String>? srcId,
    Expression<int>? page,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (srcId != null) 'src_id': srcId,
      if (page != null) 'page': page,
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OcrTextsCompanion copyWith({
    Value<String>? srcId,
    Value<int>? page,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return OcrTextsCompanion(
      srcId: srcId ?? this.srcId,
      page: page ?? this.page,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (srcId.present) {
      map['src_id'] = Variable<String>(srcId.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OcrTextsCompanion(')
          ..write('srcId: $srcId, ')
          ..write('page: $page, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $KvTable kv = $KvTable(this);
  late final $PdfBlobsTable pdfBlobs = $PdfBlobsTable(this);
  late final $FigImgsTable figImgs = $FigImgsTable(this);
  late final $OcrTextsTable ocrTexts = $OcrTextsTable(this);
  late final ProjectsDao projectsDao = ProjectsDao(this as AppDatabase);
  late final KvDao kvDao = KvDao(this as AppDatabase);
  late final FileBlobsDao fileBlobsDao = FileBlobsDao(this as AppDatabase);
  late final FigImgsDao figImgsDao = FigImgsDao(this as AppDatabase);
  late final OcrDao ocrDao = OcrDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projects,
    kv,
    pdfBlobs,
    figImgs,
    ocrTexts,
  ];
}

typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String jsonValue,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> jsonValue,
      Value<int> rowid,
    });

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
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

  ColumnFilters<String> get jsonValue => $composableBuilder(
    column: $table.jsonValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
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

  ColumnOrderings<String> get jsonValue => $composableBuilder(
    column: $table.jsonValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jsonValue =>
      $composableBuilder(column: $table.jsonValue, builder: (column) => column);
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          ProjectRow,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (
            ProjectRow,
            BaseReferences<_$AppDatabase, $ProjectsTable, ProjectRow>,
          ),
          ProjectRow,
          PrefetchHooks Function()
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> jsonValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  ProjectsCompanion(id: id, jsonValue: jsonValue, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String jsonValue,
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                jsonValue: jsonValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      ProjectRow,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (ProjectRow, BaseReferences<_$AppDatabase, $ProjectsTable, ProjectRow>),
      ProjectRow,
      PrefetchHooks Function()
    >;
typedef $$KvTableCreateCompanionBuilder =
    KvCompanion Function({
      required String projectId,
      required String key,
      required String jsonValue,
      Value<int> rowid,
    });
typedef $$KvTableUpdateCompanionBuilder =
    KvCompanion Function({
      Value<String> projectId,
      Value<String> key,
      Value<String> jsonValue,
      Value<int> rowid,
    });

class $$KvTableFilterComposer extends Composer<_$AppDatabase, $KvTable> {
  $$KvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonValue => $composableBuilder(
    column: $table.jsonValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KvTableOrderingComposer extends Composer<_$AppDatabase, $KvTable> {
  $$KvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonValue => $composableBuilder(
    column: $table.jsonValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KvTableAnnotationComposer extends Composer<_$AppDatabase, $KvTable> {
  $$KvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get jsonValue =>
      $composableBuilder(column: $table.jsonValue, builder: (column) => column);
}

class $$KvTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KvTable,
          KvRow,
          $$KvTableFilterComposer,
          $$KvTableOrderingComposer,
          $$KvTableAnnotationComposer,
          $$KvTableCreateCompanionBuilder,
          $$KvTableUpdateCompanionBuilder,
          (KvRow, BaseReferences<_$AppDatabase, $KvTable, KvRow>),
          KvRow,
          PrefetchHooks Function()
        > {
  $$KvTableTableManager(_$AppDatabase db, $KvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> projectId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> jsonValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvCompanion(
                projectId: projectId,
                key: key,
                jsonValue: jsonValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String projectId,
                required String key,
                required String jsonValue,
                Value<int> rowid = const Value.absent(),
              }) => KvCompanion.insert(
                projectId: projectId,
                key: key,
                jsonValue: jsonValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KvTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KvTable,
      KvRow,
      $$KvTableFilterComposer,
      $$KvTableOrderingComposer,
      $$KvTableAnnotationComposer,
      $$KvTableCreateCompanionBuilder,
      $$KvTableUpdateCompanionBuilder,
      (KvRow, BaseReferences<_$AppDatabase, $KvTable, KvRow>),
      KvRow,
      PrefetchHooks Function()
    >;
typedef $$PdfBlobsTableCreateCompanionBuilder =
    PdfBlobsCompanion Function({
      required String key,
      required Uint8List data,
      Value<String?> mime,
      Value<int> rowid,
    });
typedef $$PdfBlobsTableUpdateCompanionBuilder =
    PdfBlobsCompanion Function({
      Value<String> key,
      Value<Uint8List> data,
      Value<String?> mime,
      Value<int> rowid,
    });

class $$PdfBlobsTableFilterComposer
    extends Composer<_$AppDatabase, $PdfBlobsTable> {
  $$PdfBlobsTableFilterComposer({
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

  ColumnFilters<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PdfBlobsTableOrderingComposer
    extends Composer<_$AppDatabase, $PdfBlobsTable> {
  $$PdfBlobsTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PdfBlobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PdfBlobsTable> {
  $$PdfBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<Uint8List> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);
}

class $$PdfBlobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PdfBlobsTable,
          PdfBlobRow,
          $$PdfBlobsTableFilterComposer,
          $$PdfBlobsTableOrderingComposer,
          $$PdfBlobsTableAnnotationComposer,
          $$PdfBlobsTableCreateCompanionBuilder,
          $$PdfBlobsTableUpdateCompanionBuilder,
          (
            PdfBlobRow,
            BaseReferences<_$AppDatabase, $PdfBlobsTable, PdfBlobRow>,
          ),
          PdfBlobRow,
          PrefetchHooks Function()
        > {
  $$PdfBlobsTableTableManager(_$AppDatabase db, $PdfBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PdfBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PdfBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PdfBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<Uint8List> data = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PdfBlobsCompanion(
                key: key,
                data: data,
                mime: mime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required Uint8List data,
                Value<String?> mime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PdfBlobsCompanion.insert(
                key: key,
                data: data,
                mime: mime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PdfBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PdfBlobsTable,
      PdfBlobRow,
      $$PdfBlobsTableFilterComposer,
      $$PdfBlobsTableOrderingComposer,
      $$PdfBlobsTableAnnotationComposer,
      $$PdfBlobsTableCreateCompanionBuilder,
      $$PdfBlobsTableUpdateCompanionBuilder,
      (PdfBlobRow, BaseReferences<_$AppDatabase, $PdfBlobsTable, PdfBlobRow>),
      PdfBlobRow,
      PrefetchHooks Function()
    >;
typedef $$FigImgsTableCreateCompanionBuilder =
    FigImgsCompanion Function({
      required String figId,
      required Uint8List data,
      Value<String?> mime,
      Value<int> rowid,
    });
typedef $$FigImgsTableUpdateCompanionBuilder =
    FigImgsCompanion Function({
      Value<String> figId,
      Value<Uint8List> data,
      Value<String?> mime,
      Value<int> rowid,
    });

class $$FigImgsTableFilterComposer
    extends Composer<_$AppDatabase, $FigImgsTable> {
  $$FigImgsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get figId => $composableBuilder(
    column: $table.figId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FigImgsTableOrderingComposer
    extends Composer<_$AppDatabase, $FigImgsTable> {
  $$FigImgsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get figId => $composableBuilder(
    column: $table.figId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FigImgsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FigImgsTable> {
  $$FigImgsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get figId =>
      $composableBuilder(column: $table.figId, builder: (column) => column);

  GeneratedColumn<Uint8List> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);
}

class $$FigImgsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FigImgsTable,
          FigImgRow,
          $$FigImgsTableFilterComposer,
          $$FigImgsTableOrderingComposer,
          $$FigImgsTableAnnotationComposer,
          $$FigImgsTableCreateCompanionBuilder,
          $$FigImgsTableUpdateCompanionBuilder,
          (FigImgRow, BaseReferences<_$AppDatabase, $FigImgsTable, FigImgRow>),
          FigImgRow,
          PrefetchHooks Function()
        > {
  $$FigImgsTableTableManager(_$AppDatabase db, $FigImgsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FigImgsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FigImgsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FigImgsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> figId = const Value.absent(),
                Value<Uint8List> data = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FigImgsCompanion(
                figId: figId,
                data: data,
                mime: mime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String figId,
                required Uint8List data,
                Value<String?> mime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FigImgsCompanion.insert(
                figId: figId,
                data: data,
                mime: mime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FigImgsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FigImgsTable,
      FigImgRow,
      $$FigImgsTableFilterComposer,
      $$FigImgsTableOrderingComposer,
      $$FigImgsTableAnnotationComposer,
      $$FigImgsTableCreateCompanionBuilder,
      $$FigImgsTableUpdateCompanionBuilder,
      (FigImgRow, BaseReferences<_$AppDatabase, $FigImgsTable, FigImgRow>),
      FigImgRow,
      PrefetchHooks Function()
    >;
typedef $$OcrTextsTableCreateCompanionBuilder =
    OcrTextsCompanion Function({
      required String srcId,
      required int page,
      required String content,
      Value<int> rowid,
    });
typedef $$OcrTextsTableUpdateCompanionBuilder =
    OcrTextsCompanion Function({
      Value<String> srcId,
      Value<int> page,
      Value<String> content,
      Value<int> rowid,
    });

class $$OcrTextsTableFilterComposer
    extends Composer<_$AppDatabase, $OcrTextsTable> {
  $$OcrTextsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get srcId => $composableBuilder(
    column: $table.srcId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OcrTextsTableOrderingComposer
    extends Composer<_$AppDatabase, $OcrTextsTable> {
  $$OcrTextsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get srcId => $composableBuilder(
    column: $table.srcId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OcrTextsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OcrTextsTable> {
  $$OcrTextsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get srcId =>
      $composableBuilder(column: $table.srcId, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);
}

class $$OcrTextsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OcrTextsTable,
          OcrRow,
          $$OcrTextsTableFilterComposer,
          $$OcrTextsTableOrderingComposer,
          $$OcrTextsTableAnnotationComposer,
          $$OcrTextsTableCreateCompanionBuilder,
          $$OcrTextsTableUpdateCompanionBuilder,
          (OcrRow, BaseReferences<_$AppDatabase, $OcrTextsTable, OcrRow>),
          OcrRow,
          PrefetchHooks Function()
        > {
  $$OcrTextsTableTableManager(_$AppDatabase db, $OcrTextsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OcrTextsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OcrTextsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OcrTextsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> srcId = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OcrTextsCompanion(
                srcId: srcId,
                page: page,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String srcId,
                required int page,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => OcrTextsCompanion.insert(
                srcId: srcId,
                page: page,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OcrTextsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OcrTextsTable,
      OcrRow,
      $$OcrTextsTableFilterComposer,
      $$OcrTextsTableOrderingComposer,
      $$OcrTextsTableAnnotationComposer,
      $$OcrTextsTableCreateCompanionBuilder,
      $$OcrTextsTableUpdateCompanionBuilder,
      (OcrRow, BaseReferences<_$AppDatabase, $OcrTextsTable, OcrRow>),
      OcrRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$KvTableTableManager get kv => $$KvTableTableManager(_db, _db.kv);
  $$PdfBlobsTableTableManager get pdfBlobs =>
      $$PdfBlobsTableTableManager(_db, _db.pdfBlobs);
  $$FigImgsTableTableManager get figImgs =>
      $$FigImgsTableTableManager(_db, _db.figImgs);
  $$OcrTextsTableTableManager get ocrTexts =>
      $$OcrTextsTableTableManager(_db, _db.ocrTexts);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Die Datenbank als App-weiter Singleton-Provider; der explizite Reboot
/// (E8) invalidiert diesen Knoten NICHT — die DB überlebt Projektwechsel,
/// nur die Daten-Sichten darüber werden neu aufgebaut.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// Die Datenbank als App-weiter Singleton-Provider; der explizite Reboot
/// (E8) invalidiert diesen Knoten NICHT — die DB überlebt Projektwechsel,
/// nur die Daten-Sichten darüber werden neu aufgebaut.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// Die Datenbank als App-weiter Singleton-Provider; der explizite Reboot
  /// (E8) invalidiert diesen Knoten NICHT — die DB überlebt Projektwechsel,
  /// nur die Daten-Sichten darüber werden neu aufgebaut.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';
