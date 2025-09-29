import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:manager_room_project/widgets/navbar.dart';

class TenantdashUi extends StatefulWidget {
  const TenantdashUi({super.key});

  @override
  State<TenantdashUi> createState() => _TenantdashUiState();
}

class _TenantdashUiState extends State<TenantdashUi> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}
