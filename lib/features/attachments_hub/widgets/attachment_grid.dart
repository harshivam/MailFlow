import 'package:flutter/material.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/features/attachments_hub/widgets/attachment_item.dart';

class AttachmentGrid extends StatelessWidget {
  final List<EmailAttachment> attachments;
  final Function(EmailAttachment)? onAttachmentTap;
  final int crossAxisCount;
  final String title;

  const AttachmentGrid({
    Key? key,
    required this.attachments,
    this.onAttachmentTap,
    this.crossAxisCount = 2,
    this.title = 'Attachments',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: .69,
          ),
          itemCount: attachments.length,
          itemBuilder: (context, index) {
            return AttachmentItem(
              attachment: attachments[index],
              onViewDetails: onAttachmentTap,
            );
          },
        ),
      ],
    );
  }
}
