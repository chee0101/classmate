import 'package:flutter/material.dart';
import '../../core/mock/mock_academic_session.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: currentAcademicSessionNotifier,
        builder: (context, session, _) {
          if (session == null) {
            return EmptyStateCard(
              onPressed: () {
                AcademicSessionSetupBottomSheet.show(context);
              },
            );
          }

          return Center(
            child: Text('Current session: ${session.name}'),
          );
        },
      ),
    );
  }
}