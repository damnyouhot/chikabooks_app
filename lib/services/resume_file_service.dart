import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/resume_file.dart';
import 'web_file_picker_stub.dart'
    if (dart.library.html) 'web_file_picker_impl.dart';

/// 업로드 원본 이력서 파일 서비스
///
/// - 웹: dart:html 네이티브 파일 선택 (file_picker 웹 버그 우회)
/// - 앱: file_picker 패키지 사용
/// - Firebase Storage 업로드 + Firestore CRUD
class ResumeFileService {
  static final _db      = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static final _auth    = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static const allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
  static const maxFileSizeBytes   = 20 * 1024 * 1024; // 20MB

  // ── 조회 ──────────────────────────────────────────────

  static Stream<List<ResumeFile>> watchMyFiles() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('resumeFiles')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ResumeFile.fromDoc(d)).toList());
  }

  // ── 파일 선택 + 업로드 (웹/앱 통합) ─────────────────────

  /// 파일 선택 → 검증 → Storage 업로드 → Firestore 저장
  static Future<ResumeFile?> pickAndUploadFile({
    void Function(double progress)? onProgress,
    void Function(String message)? onError,
    void Function()? onPickComplete,
  }) async {
    debugPrint('📂 [pickAndUploadFile] 진입 (kIsWeb=$kIsWeb)');

    final uid = _uid;
    if (uid == null) {
      onError?.call('로그인이 필요합니다.');
      return null;
    }

    // 플랫폼별 파일 선택
    String fileName;
    String ext;
    int fileSize;
    Uint8List bytes;

    if (kIsWeb) {
      final result = await _pickFileWeb(onError: onError);
      if (result == null) return null;
      fileName = result.name;
      ext      = result.ext;
      fileSize = result.size;
      bytes    = result.bytes;
    } else {
      final result = await _pickFileApp(onError: onError);
      if (result == null) return null;
      fileName = result.name;
      ext      = result.ext;
      fileSize = result.size;
      bytes    = result.bytes;
    }

    debugPrint('📂 [pickAndUploadFile] 파일 선택 완료: $fileName ($fileSize bytes)');
    onPickComplete?.call();

    return _uploadBytes(
      uid:        uid,
      fileName:   fileName,
      ext:        ext,
      bytes:      bytes,
      fileSize:   fileSize,
      onProgress: onProgress,
      onError:    onError,
    );
  }

  // ── 웹 전용 파일 선택 ──────────────────────────────────

  static Future<_FileData?> _pickFileWeb({
    void Function(String)? onError,
  }) async {
    debugPrint('📂 [_pickFileWeb] 진입');
    try {
      final picked = await pickFileFromBrowser();
      if (picked == null) {
        debugPrint('📂 [_pickFileWeb] 사용자 취소');
        return null;
      }

      debugPrint('📂 [_pickFileWeb] 선택됨: ${picked.name} (${picked.size}bytes, ext=${picked.extension})');

      if (!allowedExtensions.contains(picked.extension)) {
        onError?.call('PDF, JPG, JPEG, PNG 파일만 업로드할 수 있어요.');
        return null;
      }
      if (picked.size > maxFileSizeBytes) {
        onError?.call('파일 크기가 20MB를 초과했어요.');
        return null;
      }

      return _FileData(
        name:  picked.name,
        ext:   picked.extension,
        size:  picked.size,
        bytes: picked.bytes,
      );
    } catch (e, st) {
      debugPrint('📂 [_pickFileWeb] 예외: $e\n$st');
      onError?.call('파일 선택 중 오류가 발생했어요: $e');
      return null;
    }
  }

  // ── 앱 전용 파일 선택 ──────────────────────────────────

  static Future<_FileData?> _pickFileApp({
    void Function(String)? onError,
  }) async {
    debugPrint('📂 [_pickFileApp] 진입');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('📂 [_pickFileApp] 취소');
        return null;
      }

      final file = result.files.first;
      final ext  = (file.extension ?? '').toLowerCase();
      debugPrint('📂 [_pickFileApp] 선택됨: ${file.name} (${file.size}bytes, ext=$ext)');

      if (!allowedExtensions.contains(ext)) {
        onError?.call('PDF, JPG, JPEG, PNG 파일만 업로드할 수 있어요.');
        return null;
      }
      if (file.size > maxFileSizeBytes) {
        onError?.call('파일 크기가 20MB를 초과했어요.');
        return null;
      }
      if (file.bytes == null) {
        onError?.call('파일을 읽을 수 없어요.');
        return null;
      }

      return _FileData(
        name:  file.name,
        ext:   ext,
        size:  file.size,
        bytes: file.bytes!,
      );
    } catch (e, st) {
      debugPrint('📂 [_pickFileApp] 예외: $e\n$st');
      onError?.call('파일 선택 중 오류가 발생했어요: $e');
      return null;
    }
  }

  // ── Storage 업로드 ─────────────────────────────────────

  static Future<ResumeFile?> _uploadBytes({
    required String uid,
    required String fileName,
    required String ext,
    required Uint8List bytes,
    required int fileSize,
    void Function(double)? onProgress,
    void Function(String)? onError,
  }) async {
    try {
      final fileType = ResumeFileType.fromString(ext);
      final mimeType = _mimeFromExt(ext);
      final fileId   = _db.collection('resumeFiles').doc().id;
      final path     = 'resumeFiles/$uid/$fileId/$fileName';

      final ref  = _storage.ref(path);
      final task = ref.putData(bytes, SettableMetadata(contentType: mimeType));

      if (onProgress != null) {
        task.snapshotEvents.listen((snap) {
          if (snap.totalBytes > 0) {
            onProgress(snap.bytesTransferred / snap.totalBytes);
          }
        });
      }

      await task;
      final downloadUrl = await ref.getDownloadURL();

      final resumeFile = ResumeFile(
        id:             fileId,
        userId:         uid,
        fileName:       fileName,
        displayName:    fileName,
        fileType:       fileType,
        mimeType:       mimeType,
        storagePath:    path,
        downloadUrl:    downloadUrl,
        fileSize:       fileSize,
        sourcePlatform: kIsWeb ? 'web' : 'app',
      );

      await _db.collection('resumeFiles').doc(fileId).set(resumeFile.toMap());
      debugPrint('✅ ResumeFile 업로드 완료: $fileId');
      return resumeFile;
    } catch (e) {
      debugPrint('⚠️ _uploadBytes 오류: $e');
      onError?.call('업로드 중 오류가 발생했어요. 다시 시도해주세요.');
      return null;
    }
  }

  // ── 수정 ──────────────────────────────────────────────

  static Future<bool> rename(String fileId, String newDisplayName) async {
    try {
      await _db.collection('resumeFiles').doc(fileId).update({
        'displayName': newDisplayName,
        'updatedAt':   FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ rename: $e');
      return false;
    }
  }

  static Future<bool> setPrimary(String fileId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final batch = _db.batch();
      final current = await _db
          .collection('resumeFiles')
          .where('userId', isEqualTo: uid)
          .where('isPrimary', isEqualTo: true)
          .get();
      for (final doc in current.docs) {
        batch.update(doc.reference, {'isPrimary': false});
      }
      batch.update(
        _db.collection('resumeFiles').doc(fileId),
        {'isPrimary': true, 'updatedAt': FieldValue.serverTimestamp()},
      );
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('⚠️ setPrimary: $e');
      return false;
    }
  }

  // ── 삭제 ──────────────────────────────────────────────

  static Future<bool> deleteFile(ResumeFile file) async {
    try { await _storage.ref(file.storagePath).delete(); }
    catch (e) { debugPrint('⚠️ Storage 삭제 (무시): $e'); }
    try {
      await _db.collection('resumeFiles').doc(file.id).update({
        'status': 'deleted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ deleteFile: $e');
      return false;
    }
  }

  // ── 유틸 ──────────────────────────────────────────────

  static String _mimeFromExt(String ext) {
    switch (ext) {
      case 'pdf':  return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      default:     return 'application/octet-stream';
    }
  }
}

class _FileData {
  final String name;
  final String ext;
  final int size;
  final Uint8List bytes;
  const _FileData({
    required this.name,
    required this.ext,
    required this.size,
    required this.bytes,
  });
}
