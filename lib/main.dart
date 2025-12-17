import 'package:cta_design_prakash/screen/home_screen.dart';
import 'package:cta_design_prakash/screen/login_screen.dart';
import 'package:cta_design_prakash/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'colors/app_color.dart';
import 'models/uploads_provider.dart';

void main() {
  runApp(ChangeNotifierProvider(
    create: (_) => UploadsProvider(),
    child: const MyApp(),
  ),);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Celamia Academy',
      theme: ThemeData(
        // Use kDarkBlue as the primary color for AppBars, buttons, etc.
        primaryColor: AppColors.kDarkBlue,
        colorScheme: ColorScheme.light(
          primary: AppColors.kDarkBlue,
          secondary: AppColors.kLightBlue,
        ),
        // Apply the same style to all Elevated Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.kDarkBlue, // Background color
            foregroundColor: AppColors.kWhite, // Text color
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        // Apply a style to the text fields
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: AppColors.kGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: AppColors.kDarkBlue, width: 2.0),
          ),
          labelStyle: TextStyle(color: AppColors.kDarkBlue),
          filled: true,
          fillColor: AppColors.kPastelBlue, // Use pastel blue for fill
        ),
        useMaterial3: true,
      ),
      home: apiService.isLoggedIn
          ? HomeScreen(userName: apiService.currentUsername ?? '')
          :LoginScreen(),

    );
  }
}


