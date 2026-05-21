import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/empty_state_widget.dart';

class EmptyTripsWidget extends StatelessWidget {
  const EmptyTripsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.two_wheeler,
      title: 'No rides planned yet',
      subtitle: 'Start planning your next motorcycle adventure!',
      action: ElevatedButton.icon(
        onPressed: () => context.push('/trip/new'),
        icon: const Icon(Icons.add),
        label: const Text('Plan a Ride'),
      ),
    );
  }
}
