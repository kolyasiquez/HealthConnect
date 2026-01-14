import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:health_app/services/api_service.dart';
import 'package:health_app/constants/constants.dart';
import 'package:health_app/screens/auth/change_password_screen.dart';
// 👇 1. Імпорт екрану списку візитів
import 'package:health_app/screens/common/appointments_list_screen.dart';

const List<String> kDoctorAvatarPaths = [
  'assets/doctor_avatars/doctor_1.png',
  'assets/doctor_avatars/doctor_2.png',
  'assets/doctor_avatars/doctor_3.png',
  'assets/doctor_avatars/doctor_4.png',
  'assets/doctor_avatars/doctor_5.png',
  'assets/doctor_avatars/doctor_6.png',
  'assets/doctor_avatars/doctor_7.png',
  'assets/doctor_avatars/doctor_8.png',
  'assets/doctor_avatars/doctor_9.png',
  'assets/doctor_avatars/doctor_10.png',
  'assets/doctor_avatars/doctor_11.png',
  'assets/doctor_avatars/doctor_12.png',
];

const String kDefaultPlaceholderPath = 'assets/doctor_avatars/doctor_1.png';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final ApiService _apiService = ApiService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  String? _selectedSpecialization;
  String? _avatarUrl;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userData = await _apiService.getUserData();
      if (mounted && userData != null) {
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _bioController.text = userData['bio'] ?? '';

          _avatarUrl = userData['avatarUrl'] ?? kDefaultPlaceholderPath;

          String? currentSpec = userData['specialization'];
          if (currentSpec != null && kSpecializations.contains(currentSpec)) {
            _selectedSpecialization = currentSpec;
          } else {
            _selectedSpecialization = kSpecializations.isNotEmpty ? kSpecializations.first : null;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAvatarSelectionDialog() {
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            children: [
              Text('Select Avatar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: kDoctorAvatarPaths.length,
                  itemBuilder: (context, index) {
                    final assetPath = kDoctorAvatarPaths[index];
                    final isSelected = _avatarUrl == assetPath;

                    return GestureDetector(
                      onTap: () {
                        setState(() { _avatarUrl = assetPath; });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: primaryColor, width: 3)
                              : Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          backgroundImage: AssetImage(assetPath),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    setState(() { _isLoading = true; });

    try {
      await _apiService.updateUserProfile({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'specialization': _selectedSpecialization,
        'avatarUrl': _avatarUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performSignOut();
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performSignOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _avatarUrl != null
                        ? AssetImage(_avatarUrl!)
                        : const AssetImage(kDefaultPlaceholderPath),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _openAvatarSelectionDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedSpecialization,
              decoration: InputDecoration(
                labelText: 'Specialization',
                prefixIcon: const Icon(Icons.medical_services_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: kSpecializations.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedSpecialization = newValue;
                });
              },
            ),

            const SizedBox(height: 20),

            _buildTextField(
              controller: _bioController,
              label: 'Bio / Description',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),

            const SizedBox(height: 30),

            // 👇 2. Нова секція WORK & HISTORY
            _buildSectionTitle('WORK & HISTORY'),
            _buildMenuTile(
              icon: Icons.calendar_month_outlined,
              title: 'My Schedule & History',
              subtitle: 'View all appointments statistics',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Передаємо isDoctor: true, щоб бачити розклад лікаря
                    builder: (context) => const AppointmentsListScreen(isDoctor: true),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Секція SECURITY
            _buildSectionTitle('SECURITY'),
            // Оновлений дизайн кнопки зміни пароля
            _buildMenuTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your login credentials',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _confirmSignOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  // 👇 3. Додано метод для заголовків секцій
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // 👇 4. Додано метод для красивих плиток меню (як у пацієнта)
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }
}