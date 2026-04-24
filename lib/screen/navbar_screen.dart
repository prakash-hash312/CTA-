// lib/screens/navbar_screen.dart


import 'package:cta_design_prakash/screen/modifyprofile.dart';
import 'package:cta_design_prakash/screen/viewprofile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors/app_color.dart';
import '../models/dropdownmodel.dart';
import '../models/usermodel.dart';
import '../services/api_services.dart';
import 'Homeworkscreen.dart';
import 'changepasswordscreen.dart';
import 'login_screen.dart';
import 'student_syllabus_screen.dart';


String _normalizeMenuValue(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _matchesMenuTarget(List<String> values, List<String> needles) {
  for (final value in values) {
    final normalizedValue = _normalizeMenuValue(value);
    if (normalizedValue.isEmpty) continue;
    for (final needle in needles) {
      if (normalizedValue.contains(_normalizeMenuValue(needle))) {
        return true;
      }
    }
  }
  return false;
}

// --- Helper for Navigation ---
Widget _getScreen(BuildContext context, {required String title, String route = ''}) {
  final candidates = [title, route];
  // 🟢 VIEW PROFILE
  if (_matchesMenuTarget(candidates, ['view my profile', 'view profile'])) {
    return FutureBuilder<UserProfile>(
      future: apiService.viewProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading Profile'),
              backgroundColor: AppColors.kDarkBlue,
              foregroundColor: AppColors.kWhite,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.kDarkBlue),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
              backgroundColor: AppColors.kDarkBlue,
              foregroundColor: AppColors.kWhite,
            ),
            body: Center(
              child: Text(
                'Failed to load profile: ${snapshot.error}',
                style: const TextStyle(color: AppColors.kErrorRed),
              ),
            ),
          );
        } else if (snapshot.hasData) {
          return ViewMyProfileScreen(profile: snapshot.data!);
        } else {
          return const Scaffold(
            body: Center(child: Text('No profile data available.')),
          );
        }
      },
    );
  }

  // 🟣 HOMEWORK UPLOAD (Static call)
  else if (_matchesMenuTarget(candidates, [
    'homework upload',
    'student homework',
    'upload homework',
    'homework',
  ])) {
    return const HomeWorkScreen();
  }

  // 🟡 STUDENT SYLLABUS (Placeholder)
  else if (_matchesMenuTarget(candidates, [
    'student syllabus',
    'syllabus',
    'hscp',
  ])) {
    return const StudentSyllabusScreen();
  }

  // 🟡 CHANGE PASSWORD
  else if (_matchesMenuTarget(candidates, [
    'change password',
    'student password change',
  ])) {
    return const ChangePasswordScreen();
  }

  // 🟠 MODIFY PROFILE
  else if (_matchesMenuTarget(candidates, ['modify my profile', 'modify profile'])) {
    return FutureBuilder<UserProfile>(
      future: apiService.viewProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.kDarkBlue),
            ),
          );
        } else if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Failed to load profile for editing.')),
          );
        } else if (snapshot.hasData) {
          return ModifyProfileScreen(initialProfile: snapshot.data!);
        }
        return const Center(child: Text('Profile data unavailable.'));
      },
    );
  }

  // 🔵 DEFAULT CASE
  else {
    return Scaffold(
      appBar: AppBar(
        title: Text(title.isNotEmpty ? title : route),
        backgroundColor: AppColors.kDarkBlue,
        foregroundColor: AppColors.kWhite,
      ),
      body: Center(
        child: Text(
          'Screen for "${title.isNotEmpty ? title : route}" is not yet implemented.',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class NavbarScreen extends StatefulWidget {
  const NavbarScreen({super.key});

  @override
  State<NavbarScreen> createState() => _NavbarScreenState();
}

class _NavbarScreenState extends State<NavbarScreen> {
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;

  // For the collapsible profile box
  bool _profileExpanded = true;

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  List<MenuItem> _filteredSubMenuList = [];

  @override
  void initState() {
    super.initState();
    _fetchMenuList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMenuList() async {
    try {
      final items = await apiService.fetchMenuList(
        email: apiService.currentLoginEmail,
      );
      // sort by provided menuOrder
      items.sort((a, b) => a.menuOrder.compareTo(b.menuOrder));
      setState(() {
        _menuItems = items;
        _filteredSubMenuList = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load menu: $e',
              style: const TextStyle(color: AppColors.kWhite),
            ),
          ),
        );
      }
    }
  }

  // Helper: group menu items into main/sub structure
  Map<int, List<MenuItem>> _groupSubMenusByMainId(List<MenuItem> items) {
    final Map<int, List<MenuItem>> map = {};
    for (final it in items) {
      if (it.subMenuId != 0) {
        map.putIfAbsent(it.mainMenuId, () => []);
        map[it.mainMenuId]!.add(it);
      }
    }
    return map;
  }

  Map<int, MenuItem> _mainMenuEntries(List<MenuItem> items) {
    final Map<int, MenuItem> map = {};
    for (final it in items) {
      if (it.subMenuId == 0) {
        map[it.mainMenuId] = it;
      }
    }
    return map;
  }

  // Search/filter by entered text (search both main title and statusBar)
  void _onSearchChanged(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredSubMenuList = _menuItems);
      return;
    }

    final filtered = _menuItems.where((m) {
      final t1 = (m.mainMenuTitle ?? '').toLowerCase();
      final t2 = (m.statusBar ?? '').toLowerCase();
      return t1.contains(query) || t2.contains(query);
    }).toList();

    setState(() => _filteredSubMenuList = filtered);
  }

  @override
  Widget build(BuildContext context) {
    // Build main/sub maps
    final mainMenuEntries = _mainMenuEntries(_filteredSubMenuList);
    final subMenusByMainId = _groupSubMenusByMainId(_filteredSubMenuList);

    // Order main menu ids by menuOrder if available
    final mainMenuOrderMap = <int, int>{};
    for (final it in _filteredSubMenuList) {
      if (it.subMenuId == 0) mainMenuOrderMap[it.mainMenuId] = it.menuOrder;
    }
    final orderedMainIds = mainMenuEntries.keys.toList()
      ..sort((a, b) => (mainMenuOrderMap[a] ?? 999).compareTo(mainMenuOrderMap[b] ?? 999));

    final displayUserName = apiService.currentUsername ?? 'User Name';

    return Drawer(
      child: SafeArea(
      child: Column(
          children: [
            // Top profile header section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                colors: [Color(0xFF0A3D91), Color(0xFF1565C0)],
                ), boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TOP ROW: avatar + name (no online indicator, no chevrons)
                      Row(
                        children: [
                          // Avatar circle (you can swap with NetworkImage later)
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.kWhite,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.blue.shade900,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Name
                          Expanded(
                            child: Text(
                              displayUserName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // small close icon (optional — keep if you want a close)
                          // InkWell(
                          //   onTap: () => Navigator.of(context).pop(),
                          //   borderRadius: BorderRadius.circular(16),
                          //   child: Container(
                          //     width: 36,
                          //     height: 36,
                          //     alignment: Alignment.center,
                          //     decoration: BoxDecoration(
                          //       color: Colors.grey.shade100,
                          //       borderRadius: BorderRadius.circular(12),
                          //     ),
                          //     child: const Icon(Icons.close, size: 18, color: Colors.black54),
                          //   ),
                          // ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Search field (keeps exactly the same visual style & behavior you already had)
                      // Search box (reduced width)
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.72,   // <-- reduced width
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.black87.withOpacity(0.18),
                              width: 1,
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme.copyWith(primary: Colors.grey),
                              inputDecorationTheme: const InputDecorationTheme(
                                border: InputBorder.none,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              cursorColor: Colors.grey,
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                              decoration: InputDecoration(
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.search, size: 21, color: Colors.grey),
                                hintText: 'Search',
                                hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                      )

                    ],
                  ),
                ),
            ),

                      const SizedBox(height: 16),

                      // Search field
                // Put this where your search field is


            // Menu list
            Expanded(
              child: Container(
                color: AppColors.kWhite,
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.kDarkBlue,
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Profile expandable section
                    //_buildProfileSection(),

                    // Other menu items
                    ...orderedMainMenuTiles(
                      orderedMainIds,
                      mainMenuEntries,
                      subMenusByMainId,
                      context,
                    ),
                  ],
                ),
              ),
            ),

            // Logout button at bottom with spacing
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              color: AppColors.kWhite,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Logout Confirmation'),
                            content: const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.kErrorRed))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await apiService.logout();
                          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                        }
                      },
                      icon: const Icon(Icons.logout, color: AppColors.kErrorRed),
                      label: const Text('Logout', style: TextStyle(color: AppColors.kErrorRed)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.kErrorRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

    );
  }

  // Build Profile expandable section
  // Widget _buildProfileSection() {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //     decoration: BoxDecoration(
  //       color: AppColors.kPastelBlue.withOpacity(0.08),
  //       borderRadius: BorderRadius.circular(8),
  //     ),
  //     child: Column(
  //       children: [
  //         // Profile header
  //         InkWell(
  //           onTap: () {
  //             setState(() {
  //               _profileExpanded = !_profileExpanded;
  //             });
  //           },
  //           borderRadius: BorderRadius.circular(8),
  //           child: Padding(
  //             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  //             child: Row(
  //               children: [
  //                 Icon(
  //                   Icons.person_outline,
  //                   color: AppColors.kDarkBlue,
  //                   size: 20,
  //                 ),
  //                 const SizedBox(width: 12),
  //                 const Expanded(
  //                   child: Text(
  //                     'Profile',
  //                     style: TextStyle(
  //                       fontSize: 15,
  //                       fontWeight: FontWeight.w500,
  //                       color: Colors.black87,
  //                     ),
  //                   ),
  //                 ),
  //                 Icon(
  //                   _profileExpanded
  //                       ? Icons.keyboard_arrow_down
  //                       : Icons.keyboard_arrow_right,
  //                   color: AppColors.kDarkBlue,
  //                   size: 20,
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //
  //         // Profile options
  //         if (_profileExpanded) ...[
  //           _buildProfileOption(
  //             'View My Profile',
  //                 () {
  //               Navigator.of(context).pop();
  //               Navigator.of(context).push(
  //                 MaterialPageRoute(
  //                   builder: (_) => _getScreen(context, 'View My Profile'),
  //                 ),
  //               );
  //             },
  //           ),
  //           _buildProfileOption(
  //             'Modify My Profile',
  //                 () {
  //               Navigator.of(context).pop();
  //               Navigator.of(context).push(
  //                 MaterialPageRoute(
  //                   builder: (_) => _getScreen(context, 'Modify My Profile'),
  //                 ),
  //               );
  //             },
  //           ),
  //           _buildProfileOption(
  //             'Change Password',
  //                 () {
  //               Navigator.of(context).pop();
  //               Navigator.of(context).push(
  //                 MaterialPageRoute(
  //                   builder: (_) => _getScreen(context, 'Change Password'),
  //                 ),
  //               );
  //             },
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  // Helper method to build profile options
  Widget _buildProfileOption(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 32), // Indent
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build tile list for ordered main menus
  List<Widget> orderedMainMenuTiles(
      List<int> orderedMainIds,
      Map<int, MenuItem> mainMenuEntries,
      Map<int, List<MenuItem>> subMenusByMainId,
      BuildContext context,
      ) {
    return orderedMainIds.map((mainId) {
      final mainEntry = mainMenuEntries[mainId];
      final title = mainEntry?.mainMenuTitle ?? 'Menu';
      final sub = subMenusByMainId[mainId] ?? [];

      // Get appropriate icon based on menu title
      IconData menuIcon = _getMenuIcon(title, alt: mainEntry?.routePath);

      // If no submenus, render a simple ListTile
      if (sub.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Icon(menuIcon, color: AppColors.kDarkBlue, size: 20),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.kDarkBlue,
              size: 20,
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _getScreen(
                    context,
                    title: title,
                    route: mainEntry?.routePath ?? '',
                  ),
                ),
              );
            },
          ),
        );
      }

      // Render an ExpansionTile for main menu with sub items
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Icon(menuIcon, color: Colors.blue.shade800, size: 20),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.blue.shade800,
              size: 20,
            ),
            childrenPadding: const EdgeInsets.only(left: 44, bottom: 8),
            children: sub.map((item) {
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(right: 12, top: 0, bottom: 0),
                title: Text(
                  item.statusBar,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _getScreen(
                        context,
                        title: item.statusBar,
                        route: item.routePath,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      );
    }).toList();
  }

  // Helper to get icon based on menu title
  // IconData _getMenuIcon(String title) {
  //   final lowerTitle = title.toLowerCase();
  //
  //   if (lowerTitle.contains('user') || lowerTitle.contains('profile')) {
  //     return Icons.person_outline;
  //   } else if (lowerTitle.contains('report')) {
  //     return Icons.description_outlined;
  //   } else if (lowerTitle.contains('new report card')) {
  //     return Icons.share;
  //   } else if (lowerTitle.contains('resource')) {
  //     return Icons.folder_outlined;
  //   } else if (lowerTitle.contains('card')) {
  //     return Icons.credit_card_outlined;
  //   } else if (lowerTitle.contains('email') || lowerTitle.contains('mail')) {
  //     return Icons.mail_outline;
  //   } else if (lowerTitle.contains('parent') || lowerTitle.contains('access')) {
  //     return Icons.people_outline;
  //   } else if (lowerTitle.contains('help')) {
  //     return Icons.help_outline;
  //   } else if (lowerTitle.contains('magazine')) {
  //     return Icons.book_outlined;
  //   } else if (lowerTitle.contains('hscp')) {
  //     return Icons.medical_services_outlined;
  //   } else {
  //     return Icons.circle_outlined;
  //   }
  //}

  IconData _getMenuIcon(String title, {String? alt}) {
    // alt: optional alternate string (e.g. statusBar) if you want to try multiple fields
    final candidates = <String>[];
    if (title.isNotEmpty) candidates.add(title);
    if (alt != null && alt.isNotEmpty) candidates.add(alt);

    // Normalize: lowercase + trim
    final lowerCandidates = candidates.map((s) => s.toLowerCase().trim()).toList();

    // DEBUG: print what we're receiving (watch console)
    // Example: use this to see the exact strings coming from the API.
    // Remove or comment out in production.
    for (var c in lowerCandidates) {
      debugPrint('[_getMenuIcon] candidate -> "$c"');
    }

    // Helper to check any candidate
    bool anyContains(String needle) =>
        lowerCandidates.any((c) => c.contains(needle));
    bool anyEquals(String needle) =>
        lowerCandidates.any((c) => c == needle);

    // ---- Specific checks first (exact or distinctive) ----
    // exact match for "new report card"
    if (anyContains('new report card') || anyContains('new reportcard') || anyContains('report card new')) {
      return Icons.workspace_premium_outlined;
    }

    // exact "view profile" or "view my profile" OR titles that clearly indicate profile
    if (anyContains('view my profile') || anyContains('view profile') || anyEquals('profile') || anyContains('my profile')) {
      return Icons.person; // distinct profile icon
    }

    // main "user" menu (less specific)
    if (anyEquals('user') || anyContains('user menu') || anyContains('user')) {
      return Icons.person_pin_outlined;
    }

    // reports (generic)
    if (anyContains('report') && !anyContains('report card')) {
      return Icons.description_outlined;
    }

    // resources, cards, email, parent, help, magazine, hscp
    if (anyContains('resource')) return Icons.folder_outlined;
    if (anyContains('card')) return Icons.credit_card_outlined;
    if (anyContains('email') || anyContains('mail')) return Icons.mail_outline;
    if (anyContains('parent') || anyContains('access')) return Icons.people_outline;
    if (anyContains('help')) return Icons.help_outline;
    if (anyContains('magazine')) return Icons.book_outlined;
    if (anyContains('hscp')) return Icons.medical_services_outlined;

    // default
    return Icons.circle_outlined;
  }


}
