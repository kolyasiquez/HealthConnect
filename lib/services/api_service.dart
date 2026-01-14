import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { patient, doctor, admin }

class ApiService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _getCollectionForRole(UserRole role) {
    switch (role) {
      case UserRole.patient: return 'patients';
      case UserRole.doctor: return 'doctors';
      case UserRole.admin: return 'admins';
    }
  }

  String _getCollectionForRoleString(String role) {
    switch (role) {
      case 'patient': return 'patients';
      case 'doctor':
      case 'pending_doctor': return 'doctors';
      case 'admin': return 'admins';
      default: throw Exception('Невідома роль: $role');
    }
  }

  Future<void> checkAdminLimit() async {
    final adminQuery = await _firestore.collection('admins').limit(2).get();
    if (adminQuery.docs.length >= 2) {
      throw Exception("Ліміт адміністраторів (2) вже досягнуто.");
    }
  }

  Future<void> createUserDocument(
      String uid,
      String email,
      String name,
      String phoneNumber,
      UserRole role, {
        // Необов'язкові параметри (потрібні лише для лікаря)
        String? bio,
        String? specialization,
        String? address,
      }) async {

    // Якщо випадково спробувати зареєструвати адміна через код — викидаємо помилку
    if (role == UserRole.admin) {
      throw Exception('Реєстрація адміністраторів через додаток заборонена.');
    }

    final String collectionPath = _getCollectionForRole(role);
    Map<String, dynamic> userData;
    String documentRole;

    // --- 1. ЛОГІКА ДЛЯ ПАЦІЄНТА (Мінімальний набір полів) ---
    if (role == UserRole.patient) {
      documentRole = 'patient';

      userData = {
        'email': email,
        'name': name,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'avatarUrl': 'assets/avatars/default_person.png',
        'role': documentRole,
        // Інші поля (bio, specialization, address) сюди НЕ додаються
      };
    }

    // --- 2. ЛОГІКА ДЛЯ ЛІКАРЯ (Розширений набір полів) ---
    else {
      // Тут role == UserRole.doctor
      documentRole = 'pending_doctor'; // Лікар спочатку має статус "очікує"

      userData = {
        'email': email,
        'name': name,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'avatarUrl': 'assets/doctor_avatars/default_doctor.png',
        'role': documentRole,
        // Специфічні поля лікаря:
        'bio': bio,
        'specialization': specialization,
        'address': address,
      };
    }

    // --- 3. ЗАПИС У FIRESTORE ---
    final batch = _firestore.batch();

    // Запис у колекцію 'patients' або 'doctors'
    final userDocRef = _firestore.collection(collectionPath).doc(uid);
    batch.set(userDocRef, userData);

    // Запис ролі у 'user_roles' (для швидкої перевірки при вході)
    final roleDocRef = _firestore.collection('user_roles').doc(uid);
    batch.set(roleDocRef, {'role': documentRole});

    await batch.commit();
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final roleDoc = await _firestore.collection('user_roles').doc(user.uid).get();
      if (!roleDoc.exists) return null;

      final role = roleDoc.data()?['role'] as String?;
      if (role == null) return null;

      final collectionPath = _getCollectionForRoleString(role);
      final doc = await _firestore.collection(collectionPath).doc(user.uid).get();
      return doc.data();
    } catch (e) {
      log('Помилка під час отримання даних: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in.");
    if (data.isEmpty) return;

    try {
      final roleDoc = await _firestore.collection('user_roles').doc(user.uid).get();
      final role = roleDoc.data()?['role'] as String?;
      if (role == null) throw Exception('Role not found.');

      final collectionPath = _getCollectionForRoleString(role);
      await _firestore.collection(collectionPath).doc(user.uid).update(data);
    } catch (e) {
      log('Error updating profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // --- МЕТОДИ АДМІНА ---
  Future<QuerySnapshot> getPendingDoctors() {
    return _firestore.collection('doctors').where('role', isEqualTo: 'pending_doctor').get();
  }

  Future<QuerySnapshot> getDoctorsList() {
    return _firestore.collection('doctors').where('role', isEqualTo: 'doctor').get();
  }

  Future<void> approveDoctor(String uid) async {
    final batch = _firestore.batch();
    final docRef = _firestore.collection('doctors').doc(uid);
    batch.update(docRef, {'role': 'doctor'});
    final roleRef = _firestore.collection('user_roles').doc(uid);
    batch.update(roleRef, {'role': 'doctor'});
    await batch.commit();
  }

  Future<void> denyDoctor(String uid) async {
    final batch = _firestore.batch();
    final docRef = _firestore.collection('doctors').doc(uid);
    batch.delete(docRef);
    final roleRef = _firestore.collection('user_roles').doc(uid);
    batch.delete(roleRef);
    await batch.commit();
    log("Firestore data deleted for user $uid");
  }
}