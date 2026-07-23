// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ocr_dao.dart';

// ignore_for_file: type=lint
mixin _$OcrDaoMixin on DatabaseAccessor<AppDatabase> {
  $OcrTextsTable get ocrTexts => attachedDatabase.ocrTexts;
  OcrDaoManager get managers => OcrDaoManager(this);
}

class OcrDaoManager {
  final _$OcrDaoMixin _db;
  OcrDaoManager(this._db);
  $$OcrTextsTableTableManager get ocrTexts =>
      $$OcrTextsTableTableManager(_db.attachedDatabase, _db.ocrTexts);
}
