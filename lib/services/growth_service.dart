import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GrowthService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> recordEvent({
    String? uid,
    required String type,
    required double value,
  }) async {
    final userId = uid ?? _auth.currentUser!.uid;
    await _db.collection('growthEvents').add({
      'userId': userId,
      'type': type,
      'value': value,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
