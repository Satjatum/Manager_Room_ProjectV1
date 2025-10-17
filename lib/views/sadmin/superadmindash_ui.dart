import 'package:flutter/material.dart';
import 'package:manager_room_project/widgets/navbar.dart';

class SuperadmindashUi extends StatefulWidget {
  const SuperadmindashUi({super.key});

  @override
  State<SuperadmindashUi> createState() => _SuperadmindashUiState();
}

class _SuperadmindashUiState extends State<SuperadmindashUi> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}
