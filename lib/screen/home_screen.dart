// lib/screens/home_screen.dart

import 'package:flutter/material.dart';

import '../colors/app_color.dart';
import '../services/api_services.dart';
import 'navbar_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  late Future<void> _homeworkDataFuture;
  List<_TaskItem> _pendingTasks = [];
  List<_TaskItem> _completedTasks = [];

  @override
  void initState() {
    super.initState();
    _homeworkDataFuture = _loadHomeworkData();
  }

  Future<void> _loadHomeworkData() async {
    try {
      final homeworkList = await apiService.fetchStudentHomeWork();

      final pendingList = <_TaskItem>[];
      final completedList = <_TaskItem>[];

      for (final hw in homeworkList) {
        final title =
            hw['hw_subject']?.toString() ?? hw['week_name']?.toString() ?? 'Homework';

        // Use stud_name for the dashboard subject display when available.
        final studName = (hw['stud_name'] ?? '').toString().trim();
        final subjectForCard =
        studName.isNotEmpty ? 'Name: $studName' : (hw['hw_name'] ?? '').toString();

        final dueDateStr = hw['due_date']?.toString() ?? '';
        final submittedDateStr = hw['submitted_date']?.toString() ?? '';

        final dueDate = DateTime.tryParse(dueDateStr) ?? DateTime.now();

        String displayStatus = hw['status']?.toString() ?? 'Pending';
        bool isCompleted = false;

        if (submittedDateStr.isNotEmpty && dueDateStr.isNotEmpty) {
          final submitted = DateTime.tryParse(submittedDateStr);
          final due = DateTime.tryParse(dueDateStr);

          if (submitted != null && due != null) {
            isCompleted = true;
            if (submitted.isAfter(due)) {
              displayStatus = 'LATE';
            } else {
              displayStatus = 'COMPLETED';
            }
          }
        }

        final taskItem = _TaskItem(
          title: title,
          subject: subjectForCard, // student name (or fallback)
          dueDate: dueDate,
          status: displayStatus,
          hwData: hw,
        );

        if (isCompleted) {
          completedList.add(taskItem);
        } else {
          pendingList.add(taskItem);
        }
      }

      setState(() {
        _pendingTasks = pendingList;
        _completedTasks = completedList;
      });
    } catch (e) {
      debugPrint('❌ Error loading homework data: $e');
      setState(() {
        _pendingTasks = [];
        _completedTasks = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.userName.trim().isEmpty)
        ? 'Student'
        : widget.userName.split(' ').first;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('Dashboard',
              style: TextStyle(color: AppColors.kDarkText, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.kWhite,
          foregroundColor: AppColors.kWhite,
          iconTheme: IconThemeData(color: AppColors.kDarkText),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFCAC5C5)),
          ),
        ),
        drawer: const NavbarScreen(),
        backgroundColor: Colors.white,
        body: FutureBuilder<void>(
          future: _homeworkDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.kDarkBlue));
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('❌ Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.kErrorRed),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _homeworkDataFuture = _loadHomeworkData();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
      
            final pendingCount = _pendingTasks.length;
            final completedCount = _completedTasks.length;
      
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome gradient card
                    Center(
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 560),
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2B57A0), Color(0xFF13345F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: Offset(0, 6))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome, $firstName!',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 8),
                            Text('You have $pendingCount pending tasks to complete.',
                                style: const TextStyle(fontSize: 14, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
      
                    const SizedBox(height: 20),
      
                    // Segmented control (pill)
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 560),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F6FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTab = 0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 0 ? AppColors.kDarkBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('Pending ($pendingCount)',
                                        style: TextStyle(
                                          color: _selectedTab == 0 ? Colors.white : AppColors.kDarkBlue,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        )),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTab = 1),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 1 ? AppColors.kDarkBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('Completed ($completedCount)',
                                        style: TextStyle(
                                          color: _selectedTab == 1 ? Colors.white : AppColors.kDarkBlue,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        )),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
      
                    const SizedBox(height: 20),
      
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(_selectedTab == 0 ? 'Pending Tasks' : 'Completed Tasks',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.kDarkBlue)),
                    ),
      
                    const SizedBox(height: 12),
      
                    // Cards list
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: (_selectedTab == 0 ? _pendingTasks : _completedTasks).isEmpty
                            ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Text(
                                _selectedTab == 0 ? 'No pending tasks' : 'No completed tasks',
                                style: const TextStyle(fontSize: 14, color: Colors.black54)),
                          ),
                        )
                            : Column(
                          children: (_selectedTab == 0 ? _pendingTasks : _completedTasks)
                              .map((task) => _TaskCard(task: task, onViewDetails: () {
                            // navigate or open homework details
                            debugPrint('📖 View homework: ${task.title}');
                          }))
                              .toList(),
                        ),
                      ),
                    ),
      
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TaskItem {
  final String title;
  final String subject;
  final DateTime dueDate;
  final String status;
  final Map<String, dynamic> hwData;

  _TaskItem({
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.status,
    required this.hwData,
  });
}

class _TaskCard extends StatelessWidget {
  final _TaskItem task;
  final VoidCallback? onViewDetails;
  const _TaskCard({Key? key, required this.task, this.onViewDetails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dueDateStr =
        '${task.dueDate.year}-${task.dueDate.month.toString().padLeft(2, '0')}-${task.dueDate.day.toString().padLeft(2, '0')}';

    // Choose stripe color by status or subject (you can customize)
    Color stripeColor = Colors.blue;
    Color badgeBg = const Color(0xFFFFF4D1);
    Color badgeText = Colors.orange.shade900;

    if (task.status.toLowerCase().contains('late')) {
      stripeColor = const Color(0xFFD84315); // red
      badgeBg = const Color(0xFFFFECE6);
      badgeText = Colors.red.shade700;
    } else if (task.status.toLowerCase().contains('completed') ||
        task.status.toLowerCase() == 'turned in') {
      stripeColor = const Color(0xFF2E7D32); // green
      badgeBg = const Color(0xFFE8F6EC);
      badgeText = const Color(0xFF2E7D32);
    } else {
      stripeColor = const Color(0xFFF9A825); // yellow for pending
      badgeBg = const Color(0xFFFFF4D1);
      badgeText = Colors.orange.shade900;
    }

    final isLate = task.status.toLowerCase().contains('late');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Stack(
        children: [
          // Card background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
              border: Border.all(color: const Color(0xFFEEF2F6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // left color stripe
                Container(width: 6, height: 86, decoration: BoxDecoration(color: stripeColor, borderRadius: BorderRadius.circular(6))),
                const SizedBox(width: 12),

                // content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // show subject (student name or fallback) as-is
                      Text(task.subject, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),

                      Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: Color(0xFF78909C)),
                                const SizedBox(width: 6),
                                Text('Due: $dueDateStr', style: const TextStyle(fontSize: 13, color: Color(0xFF78909C), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // right circular action
                // Hide the visible background for LATE tasks while preserving layout spacing
                if (!isLate)
                  InkResponse(
                    onTap: onViewDetails,
                    radius: 22,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFF78909C)),
                    ),
                  )
                else
                  const SizedBox(width: 36),
              ],
            ),
          ),

          // status badge (positioned)
          Positioned(
            right: 12,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badgeText.withOpacity(0.08)),
              ),
              child: Text(task.status, style: TextStyle(color: badgeText, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
