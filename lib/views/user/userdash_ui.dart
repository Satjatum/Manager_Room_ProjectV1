import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';

class UserdashUi extends StatefulWidget {
  const UserdashUi({super.key});

  @override
  State<UserdashUi> createState() => _UserdashUiState();
}

class _UserdashUiState extends State<UserdashUi> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Text(
              'User',
            )
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}
