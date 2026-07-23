// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_blobs_dao.dart';

// ignore_for_file: type=lint
mixin _$FileBlobsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PdfBlobsTable get pdfBlobs => attachedDatabase.pdfBlobs;
  FileBlobsDaoManager get managers => FileBlobsDaoManager(this);
}

class FileBlobsDaoManager {
  final _$FileBlobsDaoMixin _db;
  FileBlobsDaoManager(this._db);
  $$PdfBlobsTableTableManager get pdfBlobs =>
      $$PdfBlobsTableTableManager(_db.attachedDatabase, _db.pdfBlobs);
}
