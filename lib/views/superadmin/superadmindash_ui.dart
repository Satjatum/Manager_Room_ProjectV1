import 'package:flutter/material.dart';
import 'package:manager_room_project/model/user_model.dart';
import 'package:manager_room_project/widget/appbuttomnav.dart';
import 'package:manager_room_project/widget/appcolors.dart';

class SuperadmindashUi extends StatefulWidget {
  const SuperadmindashUi({super.key});

  @override
  State<SuperadmindashUi> createState() => _SuperadmindashUiState();
}

class _SuperadmindashUiState extends State<SuperadmindashUi> {
  UserModel? currentUser;

  @override
  // หน้า Page
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Superadmin DashBoard',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          children: [],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}
