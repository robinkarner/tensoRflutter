// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fig_imgs_dao.dart';

// ignore_for_file: type=lint
mixin _$FigImgsDaoMixin on DatabaseAccessor<AppDatabase> {
  $FigImgsTable get figImgs => attachedDatabase.figImgs;
  FigImgsDaoManager get managers => FigImgsDaoManager(this);
}

class FigImgsDaoManager {
  final _$FigImgsDaoMixin _db;
  FigImgsDaoManager(this._db);
  $$FigImgsTableTableManager get figImgs =>
      $$FigImgsTableTableManager(_db.attachedDatabase, _db.figImgs);
}
