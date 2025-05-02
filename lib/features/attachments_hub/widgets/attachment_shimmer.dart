import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AttachmentShimmerGrid extends StatelessWidget {
  const AttachmentShimmerGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.68, // Match the aspect ratio in the actual grid
      ),
      // Show 6 shimmer items initially
      itemCount: 6,
      itemBuilder: (context, index) {
        return _buildShimmerItem();
      },
    );
  }

  Widget _buildShimmerItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File icon placeholder
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),

              // Filename placeholder - two lines
              Container(
                height: 16,
                width: double.infinity,
                color: Colors.white,
              ),
              const SizedBox(height: 4),
              Container(height: 16, width: 100, color: Colors.white),
              const SizedBox(height: 8),

              // Size placeholder
              Container(height: 12, width: 60, color: Colors.white),
              const SizedBox(height: 4),

              // Date placeholder
              Container(height: 12, width: 80, color: Colors.white),
              const SizedBox(height: 8),

              // From placeholder
              Container(height: 12, width: 120, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
