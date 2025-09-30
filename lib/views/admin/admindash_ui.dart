import 'package:flutter/material.dart';
import 'package:manager_room_project/widgets/navbar.dart';

class AdmindashUi extends StatefulWidget {
  const AdmindashUi({super.key});

  @override
  State<AdmindashUi> createState() => _AdmindashUiState();
}

class _AdmindashUiState extends State<AdmindashUi> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}
