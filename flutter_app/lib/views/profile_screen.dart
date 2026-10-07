import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'login_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _profileImageKey = 'smartfarm_profile_image';

  final ImagePicker _imagePicker = ImagePicker();

  String? _profileImageBase64;
  bool _loadingImage = true;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final image = prefs.getString(_profileImageKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _profileImageBase64 = image;
      _loadingImage = false;
    });
  }

  Future<void> _changeProfileImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (pickedFile == null) {
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _profileImageKey,
        base64Image,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profileImageBase64 = base64Image;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เปลี่ยนรูปโปรไฟล์เรียบร้อยแล้ว'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถเปลี่ยนรูปโปรไฟล์ได้: $e'),
        ),
      );
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) {
      return;
    }

    setState(() {
      _loggingOut = true;
    });

    try {
      await AuthService.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginView(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ออกจากระบบไม่สำเร็จ: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser ?? {};

    final displayName =
        user['display_name']?.toString().trim() ?? '';

    final username =
        user['username']?.toString().trim() ?? '';

    final email =
        user['email']?.toString().trim() ?? '';

    final phoneNumber =
        user['phone_number']?.toString().trim() ?? '';

    final role =
        user['role']?.toString().trim() ?? '';

    final status =
        user['status']?.toString().trim() ?? '';

    final nameForAvatar =
        displayName.isNotEmpty ? displayName : username;

    final avatarText = nameForAvatar.isNotEmpty
        ? nameForAvatar.substring(0, 1).toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'โปรไฟล์ผู้ใช้งาน',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // ==================================================
              // PROFILE AVATAR
              // ==================================================
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.shade50,
                      border: Border.all(
                        color: Colors.green.shade200,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: _loadingImage
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : _profileImageBase64 != null &&
                                  _profileImageBase64!.isNotEmpty
                              ? Image.memory(
                                  base64Decode(
                                    _profileImageBase64!,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Text(
                                    avatarText,
                                    style: TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                    ),
                  ),
                  Material(
                    color: Colors.green.shade700,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _changeProfileImage,
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                displayName.isNotEmpty
                    ? displayName
                    : 'ผู้ใช้งาน',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              if (username.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ==================================================
              // USER INFORMATION
              // ==================================================
              _buildSectionCard(
                title: 'ข้อมูลผู้ใช้งาน',
                icon: Icons.person_outline,
                children: [
                  _buildInfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Username',
                    value: username,
                  ),
                  _buildInfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                  ),
                  _buildInfoTile(
                    icon: Icons.phone_outlined,
                    label: 'เบอร์โทรศัพท์',
                    value: phoneNumber,
                  ),
                  _buildInfoTile(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Role',
                    value: role,
                  ),
                  _buildInfoTile(
                    icon: Icons.verified_user_outlined,
                    label: 'สถานะ',
                    value: status,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ==================================================
              // LOGOUT
              // ==================================================
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loggingOut ? null : _logout,
                  icon: _loggingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: Text(
                    _loggingOut
                        ? 'กำลังออกจากระบบ...'
                        : 'ออกจากระบบ',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(
                      color: Colors.red.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final displayValue =
        value.isNotEmpty ? value : '-';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.green.shade50,
        child: Icon(
          icon,
          color: Colors.green.shade700,
          size: 21,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          displayValue,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
