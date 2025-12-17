import 'package:flutter/material.dart';
import '../colors/app_color.dart';
import '../models/usermodel.dart';
import '../services/api_services.dart';
import 'navbar_screen.dart';
import 'modifyprofile.dart';

class ViewMyProfileScreen extends StatefulWidget {
  final UserProfile? profile;

  const ViewMyProfileScreen({super.key, this.profile});

  @override
  State<ViewMyProfileScreen> createState() => _ViewMyProfileScreenState();
}

class _ViewMyProfileScreenState extends State<ViewMyProfileScreen> {
  late Future<UserProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture =
    widget.profile != null ? Future.value(widget.profile!) : apiService.viewProfile();
  }

  Future<void> _openModifyProfile(UserProfile user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModifyProfileScreen(initialProfile: user),
      ),
    );

    if (result == true) {
      setState(() {
        _profileFuture = apiService.viewProfile(); // 🔄 refresh
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFE9F0FF),
      
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A3D91),
          centerTitle: true,
          elevation: 0,
          foregroundColor: AppColors.kWhite,
          title: const Text(
            "View My Profile",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          // actions: [
          //   IconButton(
          //     icon: const Icon(Icons.edit),
          //     onPressed: () {
          //       _profileFuture.then((user) {
          //         _openModifyProfile(user);
          //       });
          //     },
          //   ),
          // ],
        ),
      
        drawer: const NavbarScreen(),
      
        body: FutureBuilder<UserProfile>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.kDarkBlue),
              );
            }
      
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              );
            }
      
            if (!snapshot.hasData) {
              return const Center(child: Text('No profile data found'));
            }
      
            final user = snapshot.data!;
      
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  sectionHeader("Personal Details", context),
                  buildInfoSection(context, [
                    {"label": "Username", "value": user.userName},
                    {"label": "Gender", "value": user.gender},
                  ]),
      
                  sectionHeader("Contact Details", context),
                  buildInfoSection(context, [
                    {"label": "Phone 1", "value": user.userHomePhone},
                    {"label": "Phone 2", "value": user.userMobilePhone1},
                    {"label": "Phone 3", "value": user.userMobilePhone2},
                  ]),
      
                  sectionHeader("Email Details", context),
                  buildInfoSection(context, [
                    {"label": "Email", "value": user.userEmailId},
                    {"label": "Alternate Email", "value": user.userAltEmailId},
                  ]),
      
                  sectionHeader("Address Details", context),
                  buildInfoSection(context, [
                    {"label": "Street", "value": user.street},
                    {"label": "City", "value": user.city},
                    {"label": "State", "value": user.stateName},
                    {"label": "Zip Code", "value": user.zip},
                  ]),
      
                  sectionHeader("Theme", context),
                  buildInfoSection(context, [
                    {"label": "Theme", "value": user.theme},
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- UI HELPERS ----------

  Widget sectionHeader(String text, BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.90,
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0A3D91),
        ),
      ),
    );
  }

  Widget buildInfoSection(
      BuildContext context, List<Map<String, dynamic>> dataList) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.91,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dataList.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['label'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  (item['value'] ?? '').toString().isEmpty
                      ? 'N/A'
                      : item['value'],
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
