import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_builder_screen.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _handleLogin() async {
    debugPrint('LOGIN VIEW: button pressed');

    // ตรวจ Form
    if (!_formKey.currentState!.validate()) {
      debugPrint('LOGIN VIEW: validation failed');
      return;
    }

    if (_loading) {
      debugPrint('LOGIN VIEW: already loading');
      return;
    }

    setState(() {
      _loading = true;
    });

    debugPrint('LOGIN VIEW: loading=true');

    try {
      debugPrint(
        'LOGIN VIEW: calling AuthService.login()',
      );

      await AuthService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );

      debugPrint(
        'LOGIN VIEW: AuthService.login() completed',
      );

      debugPrint(
        'LOGIN VIEW: login success',
      );

      debugPrint(
        'LOGIN VIEW: user=${AuthService.currentUser?['username']}',
      );

      debugPrint(
        'LOGIN VIEW: role=${AuthService.currentUser?['role']}',
      );

      // สำคัญมาก:
      // หลัง await ต้องตรวจ mounted ก่อนใช้ context
      if (!mounted) {
        debugPrint(
          'LOGIN VIEW: widget is no longer mounted',
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เข้าสู่ระบบสำเร็จ'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 800),
        ),
      );

      // ให้ SnackBar แสดงสั้น ๆ ก่อน Navigate
      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );

      if (!mounted) {
        return;
      }

      debugPrint(
        'LOGIN VIEW: navigating to Dashboard',
      );

      _navigateToDashboard();
    } catch (e) {
      debugPrint(
        'LOGIN VIEW: login error=$e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cleanErrorMessage(e),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });

    debugPrint(
      'LOGIN VIEW: loading=false',
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigateToDashboard() {
    if (!mounted) {
      return;
    }

    debugPrint(
      'NAVIGATION: DashboardView',
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const DashboardView(),
      ),
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _openRegister() async {
    if (_loading) {
      return;
    }

    debugPrint(
      'NAVIGATION: RegisterView',
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RegisterView(),
      ),
    );
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  void _showForgotPasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ลืมรหัสผ่าน'),
          content: const Text(
            'กรุณาติดต่อผู้ดูแลระบบ Smart Farm '
            'เพื่อดำเนินการรีเซ็ตรหัสผ่าน',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // ------------------------------------------------
                          // LOGO
                          // ------------------------------------------------

                          const Center(
                            child: Icon(
                              Icons.agriculture,
                              size: 64,
                              color: Colors.green,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ------------------------------------------------
                          // TITLE
                          // ------------------------------------------------

                          const Center(
                            child: Text(
                              'เข้าสู่ระบบ',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Center(
                            child: Text(
                              'ลงชื่อเข้าใช้เพื่อจัดการฟาร์มของคุณ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ------------------------------------------------
                          // USERNAME
                          // ------------------------------------------------

                          TextFormField(
                            controller: _usernameController,
                            enabled: !_loading,
                            autocorrect: false,
                            textInputAction:
                                TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'ชื่อผู้ใช้งาน',
                              hintText: 'admin',
                              prefixIcon: const Icon(
                                Icons.person_outline,
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'กรุณากรอกชื่อผู้ใช้';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // ------------------------------------------------
                          // PASSWORD
                          // ------------------------------------------------

                          TextFormField(
                            controller: _passwordController,
                            enabled: !_loading,
                            obscureText: _obscurePassword,
                            autocorrect: false,
                            textInputAction:
                                TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_loading) {
                                _handleLogin();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'รหัสผ่าน',
                              hintText: 'กรอกรหัสผ่าน',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: _loading
                                    ? null
                                    : () {
                                        setState(() {
                                          _obscurePassword =
                                              !_obscurePassword;
                                        });
                                      },
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty) {
                                return 'กรุณากรอกรหัสผ่าน';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 8),

                          // ------------------------------------------------
                          // REMEMBER + FORGOT
                          // ------------------------------------------------

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    activeColor:
                                        Colors.green.shade700,
                                    onChanged: _loading
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _rememberMe =
                                                  value ?? false;
                                            });
                                          },
                                  ),
                                  const Text(
                                    'จดจำฉันไว้',
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : _showForgotPasswordDialog,
                                child: Text(
                                  'ลืมรหัสผ่าน?',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ------------------------------------------------
                          // LOGIN BUTTON
                          // ------------------------------------------------

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.green.shade700,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.grey.shade400,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _loading
                                  ? null
                                  : _handleLogin,
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<
                                                Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'เข้าสู่ระบบ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ------------------------------------------------
                          // REGISTER
                          // ------------------------------------------------

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed:
                                  _loading
                                      ? null
                                      : _openRegister,
                              style:
                                  OutlinedButton.styleFrom(
                                foregroundColor:
                                    Colors.green.shade700,
                                side: BorderSide(
                                  color:
                                      Colors.green.shade400,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'สร้างบัญชีใหม่',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ------------------------------------------------
                // FOOTER
                // ------------------------------------------------

                Text(
                  'Smart Farm IoT v1.0.0\n'
                  'Raspberry Pi Edge Gateway',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}