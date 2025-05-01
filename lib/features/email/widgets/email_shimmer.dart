import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class EmailShimmerList extends StatelessWidget {
  final int itemCount;

  const EmailShimmerList({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    // Calculate how many items would fill the screen based on device height
    final screenHeight = MediaQuery.of(context).size.height;
    final itemHeight =
        106.0; // Match the height of real email items (card + padding)
    final calculatedItemCount = (screenHeight / itemHeight).ceil();

    // Use the larger of provided itemCount or calculated count
    final effectiveItemCount =
        itemCount > calculatedItemCount ? itemCount : calculatedItemCount;

    return ListView.builder(
      // Match the padding of the real email list
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      itemCount: effectiveItemCount,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 6.0,
            ), // Match vertical spacing
            child: Card(
              elevation: 0, // Remove shadow
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!, width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar circle
                        const CircleAvatar(radius: 20),
                        const SizedBox(width: 12),

                        // Main content area
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sender row with date
                              Row(
                                children: [
                                  // Sender name
                                  Container(
                                    width: 120,
                                    height: 12,
                                    color: Colors.white,
                                  ),
                                  const Spacer(),
                                  // Date
                                  Container(
                                    width: 60,
                                    height: 10,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Provider badge
                              Container(
                                width: 80,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Subject
                              Container(
                                width: double.infinity,
                                height: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Message preview/snippet
                    Padding(
                      padding: const EdgeInsets.only(left: 52.0, top: 4.0),
                      child: Container(
                        width: double.infinity,
                        height: 10,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 52.0),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 10,
                        color: Colors.white,
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
