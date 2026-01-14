import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:health_app/widgets/appointment_details_sheet.dart';

class AppointmentsListScreen extends StatefulWidget {
  final bool isDoctor; // 👈 Цей прапорець визначає режим роботи екрану

  const AppointmentsListScreen({super.key, required this.isDoctor});

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DocumentSnapshot> _appointments = [];
  bool _isListLoading = false;
  bool _hasMore = true;
  final int _documentLimit = 10;
  DocumentSnapshot? _lastDocument;

  bool _isStatsLoading = true;
  int _statsConfirmed = 0;
  int _statsCancelled = 0;
  int _statsPending = 0;
  int _statsCompleted = 0;

  int get _totalVisits => _statsConfirmed + _statsCancelled + _statsPending + _statsCompleted;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _getAppointments();
  }

  Future<void> _refreshList() async {
    setState(() {
      _appointments = [];
      _lastDocument = null;
      _hasMore = true;
      _isStatsLoading = true;
    });
    _fetchStats();
    await _getAppointments();
  }

  // ---------------------------------------------------------------------------
  // 🔍 ЛОГІКА РОЗДІЛЕННЯ РОЛЕЙ (Backend)
  // ---------------------------------------------------------------------------

  Future<void> _fetchStats() async {
    final userId = _auth.currentUser!.uid;

    // 👇 ГОЛОВНА ЛОГІКА:
    // Якщо я лікар -> шукаємо записи, де 'doctorId' == моє ID (бачу всіх своїх пацієнтів)
    // Якщо я пацієнт -> шукаємо записи, де 'patientId' == моє ID (бачу всіх своїх лікарів)
    final String searchField = widget.isDoctor ? 'doctorId' : 'patientId';

    final baseQuery = _firestore.collection('appointments').where(searchField, isEqualTo: userId);

    try {
      final pendingQuery = baseQuery.where('status', isEqualTo: 'pending').count();
      final confirmedQuery = baseQuery.where('status', isEqualTo: 'confirmed').count();
      final cancelledQuery = baseQuery.where('status', isEqualTo: 'cancelled').count();
      final completedQuery = baseQuery.where('status', isEqualTo: 'completed').count();

      final results = await Future.wait([
        pendingQuery.get(),
        confirmedQuery.get(),
        cancelledQuery.get(),
        completedQuery.get(),
      ]);

      if (mounted) {
        setState(() {
          _statsPending = results[0].count ?? 0;
          _statsConfirmed = results[1].count ?? 0;
          _statsCancelled = results[2].count ?? 0;
          _statsCompleted = results[3].count ?? 0;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  Future<void> _getAppointments() async {
    if (_isListLoading) return;

    setState(() => _isListLoading = true);

    final userId = _auth.currentUser!.uid;

    try {
      // 👇 ТА Ж САМА ЛОГІКА ДЛЯ СПИСКУ:
      final String searchField = widget.isDoctor ? 'doctorId' : 'patientId';

      Query query = _firestore
          .collection('appointments')
          .where(searchField, isEqualTo: userId)
          .orderBy('date', descending: true) // Сортуємо: нові зверху
          .limit(_documentLimit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot querySnapshot = await query.get();

      if (querySnapshot.docs.length < _documentLimit) {
        _hasMore = false;
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _appointments.addAll(querySnapshot.docs);
      }
    } catch (e) {
      debugPrint("Error loading appointments: $e");
    }

    if (mounted) setState(() => _isListLoading = false);
  }

  // ---------------------------------------------------------------------------
  // 🎨 UI ВІДЖЕТИ
  // ---------------------------------------------------------------------------

  Widget _buildChartSection() {
    if (_isStatsLoading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    if (_totalVisits == 0) return const SizedBox.shrink();

    // Заголовок графіка залежить від ролі
    final String chartTitle = widget.isDoctor
        ? "Workload Statistics"
        : "My Medical History Stats";

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Text(
            chartTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    startDegreeOffset: -90,
                    sections: _showingSections(),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _totalVisits.toString(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const Text("Total", style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(Colors.green, "Confirmed", _statsConfirmed),
              _buildLegendItem(Colors.blue, "Completed", _statsCompleted),
              _buildLegendItem(Colors.orange, "Pending", _statsPending),
              _buildLegendItem(Colors.red, "Cancelled", _statsCancelled),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _showingSections() {
    if (_totalVisits == 0) {
      return [PieChartSectionData(color: Colors.grey.shade200, value: 1, title: '', radius: 25)];
    }
    final double total = _totalVisits.toDouble();
    String getPercentage(int value) => value == 0 ? '' : '${((value / total) * 100).toStringAsFixed(0)}%';

    return [
      if (_statsCompleted > 0)
        PieChartSectionData(color: Colors.blue, value: _statsCompleted.toDouble(), title: getPercentage(_statsCompleted), radius: 30, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      if (_statsConfirmed > 0)
        PieChartSectionData(color: Colors.green, value: _statsConfirmed.toDouble(), title: getPercentage(_statsConfirmed), radius: 28, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      if (_statsPending > 0)
        PieChartSectionData(color: Colors.orange, value: _statsPending.toDouble(), title: getPercentage(_statsPending), radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      if (_statsCancelled > 0)
        PieChartSectionData(color: Colors.red, value: _statsCancelled.toDouble(), title: getPercentage(_statsCancelled), radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
    ];
  }

  Widget _buildLegendItem(Color color, String text, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 2),
        Text(count.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAppointmentItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final date = data['date'] ?? 'Unknown Date';
    final time = data['slot'] ?? '--:--';
    final status = data['status'] ?? 'pending';

    // 👇 UI ЛОГІКА:
    // Якщо я лікар -> мені важливо бачити ім'я ПАЦІЄНТА
    // Якщо я пацієнт -> мені важливо бачити ім'я ЛІКАРЯ
    final String titleName = widget.isDoctor
        ? (data['patientName'] ?? 'Unknown Patient')
        : (data['doctorName'] ?? 'Unknown Doctor');

    final String subTitleLabel = widget.isDoctor ? "Patient" : "Doctor";

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.access_time;

    if (status == 'confirmed') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'cancelled') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
    } else if (status == 'completed') {
      statusColor = Colors.blue;
      statusIcon = Icons.task_alt;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            builder: (context) => AppointmentDetailsSheet(
              appointmentId: doc.id,
              appointmentData: data,
              isDoctor: widget.isDoctor,
            ),
          );
          _refreshList();
        },
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(statusIcon, color: statusColor),
          ),
          title: Text(titleName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('$date at $time'),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Адаптивний заголовок екрану
    final String appBarTitle = widget.isDoctor
        ? 'My Patients Schedule'
        : 'My Visits History';

    final String emptyMessage = widget.isDoctor
        ? "No scheduled appointments found"
        : "You have no visit history yet";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshList,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildChartSection(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Text(
                  widget.isDoctor ? "Appointments List" : "History List",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
              ),
            ),
            _appointments.isEmpty && !_isListLoading
                ? SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    Text(
                      emptyMessage,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index == _appointments.length) {
                    return _buildLoadMoreButton();
                  }
                  return _buildAppointmentItem(_appointments[index]);
                },
                childCount: _appointments.length + 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text("End of list", style: TextStyle(color: Colors.grey))),
      );
    }

    if (_isListLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: OutlinedButton(
        onPressed: _getAppointments,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: const Text("Load More"),
      ),
    );
  }
}