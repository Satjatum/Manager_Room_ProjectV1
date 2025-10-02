import 'package:flutter/material.dart';
import 'package:manager_room_project/views/splash_ui.dart';
import 'config/superbase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Link Supabase Setupp
  await SupabaseConfig.initialize();

  runApp(const ManagerRoomProject());
}

class ManagerRoomProject extends StatelessWidget {
  const ManagerRoomProject({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบจัดการห้องเช่า',
      theme: ThemeData(),
      home: SplashUi(),
      debugShowCheckedModeBanner: false,
    );
  }
}
