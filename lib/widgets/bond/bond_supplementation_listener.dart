import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 주중 보충 멤버 합류 감지 (UI 없음, 콜백만)
class BondSupplementationListener extends StatefulWidget {
  final String? groupId;
  final Function()? onMemberJoined;

  const BondSupplementationListener({
    super.key,
    this.groupId,
    this.onMemberJoined,
  });

  @override
  State<BondSupplementationListener> createState() =>
      _BondSupplementationListenerState();
}

class _BondSupplementationListenerState
    extends State<BondSupplementationListener> {
  int _previousMemberCount = 0;

  @override
  void initState() {
    super.initState();
    _previousMemberCount = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partnerGroups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final memberUids = List<String>.from(data['memberUids'] ?? []);
        final currentMemberCount = memberUids.length;

        // 멤버 수 증가 감지 → 콜백 호출
        if (_previousMemberCount > 0 &&
            currentMemberCount > _previousMemberCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.onMemberJoined != null) {
              widget.onMemberJoined!();
            }
          });
        }
        _previousMemberCount = currentMemberCount;

        return const SizedBox.shrink();
      },
    );
  }
}
