import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class EmailShimmerList extends StatelessWidget {
  final int itemCount;

  const EmailShimmerList({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    // Calculate how many items would fill the screen based on device height
    final screenHeight = MediaQuery.of(context).size.height;
    final itemHeight = 100.0; // Approximate height of each shimmer item
    final calculatedItemCount = (screenHeight / itemHeight).ceil();

    // Use the larger of provided itemCount or calculated count
    final effectiveItemCount =
        itemCount > calculatedItemCount ? itemCount : calculatedItemCount;

    return ListView.builder(
      itemCount: effectiveItemCount,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 150,
                            height: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 100,
                            height: 10,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
