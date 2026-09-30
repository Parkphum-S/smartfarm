import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() =>
      _RegisterViewState();
}

class _RegisterViewState
    extends State<RegisterView> {
  final _formKey =
      GlobalKey<FormState>();

  final _usernameController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await AuthService.register(
        username:
            _usernameController.text.trim(),
        password:
            _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'สมัครสมาชิกสำเร็จ กรุณาเข้าสู่ระบบ',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _cleanErrorMessage(e),
          ),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'สมัครสมาชิก',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 420,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.agriculture,
                      size: 64,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    const Text(
                      'สร้างบัญชี Smart Farm',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    const Text(
                      'สร้างบัญชีเพื่อเข้าใช้งานระบบ Smart Farm',
                      textAlign:
                          TextAlign.center,
                    ),

                    const SizedBox(
                      height: 32,
                    ),

                    // USERNAME
                    TextFormField(
                      controller:
                          _usernameController,
                      enabled: !_loading,
                      textInputAction:
                          TextInputAction.next,
                      autocorrect: false,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'ชื่อผู้ใช้',
                        hintText:
                            'เช่น farmadmin',
                        prefixIcon:
                            Icon(
                          Icons.person,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final username =
                            value?.trim() ??
                                '';

                        if (username.isEmpty) {
                          return 'กรุณากรอกชื่อผู้ใช้';
                        }

                        if (username.length <
                            3) {
                          return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 3 ตัวอักษร';
                        }

                        if (username.length >
                            30) {
                          return 'ชื่อผู้ใช้ต้องไม่เกิน 30 ตัวอักษร';
                        }

                        final valid =
                            RegExp(
                          r'^[A-Za-z0-9_]+$',
                        ).hasMatch(username);

                        if (!valid) {
                          return 'ใช้เฉพาะ A-Z, a-z, 0-9 และ _';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // PASSWORD
                    TextFormField(
                      controller:
                          _passwordController,
                      enabled: !_loading,
                      obscureText:
                          _obscurePassword,
                      textInputAction:
                          TextInputAction.next,
                      autocorrect: false,
                      decoration:
                          InputDecoration(
                        labelText:
                            'รหัสผ่าน',
                        hintText:
                            'อย่างน้อย 6 ตัวอักษร',
                        prefixIcon:
                            const Icon(
                          Icons.lock,
                        ),
                        suffixIcon:
                            IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons
                                    .visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword;
                            });
                          },
                        ),
                        border:
                            const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final password =
                            value ?? '';

                        if (password.isEmpty) {
                          return 'กรุณากรอกรหัสผ่าน';
                        }

                        if (password.length <
                            6) {
                          return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // CONFIRM PASSWORD
                    TextFormField(
                      controller:
                          _confirmPasswordController,
                      enabled: !_loading,
                      obscureText:
                          _obscureConfirmPassword,
                      textInputAction:
                          TextInputAction.done,
                      autocorrect: false,
                      onFieldSubmitted:
                          (_) {
                        if (!_loading) {
                          _register();
                        }
                      },
                      decoration:
                          InputDecoration(
                        labelText:
                            'ยืนยันรหัสผ่าน',
                        prefixIcon:
                            const Icon(
                          Icons.lock_outline,
                        ),
                        suffixIcon:
                            IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility
                                : Icons
                                    .visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border:
                            const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'กรุณายืนยันรหัสผ่าน';
                        }

                        if (value !=
                            _passwordController
                                .text) {
                          return 'รหัสผ่านไม่ตรงกัน';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // INFORMATION
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          )
                              .dividerColor,
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'ข้อกำหนดบัญชี',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            height: 8,
                          ),
                          Text(
                            '• ชื่อผู้ใช้ 3–30 ตัวอักษร',
                          ),
                          Text(
                            '• ใช้ A-Z, a-z, 0-9 และ _',
                          ),
                          Text(
                            '• รหัสผ่านอย่างน้อย 6 ตัวอักษร',
                          ),
                          Text(
                            '• ระบบตรวจสอบคำขอจาก Bot',
                          ),
                          Text(
                            '• บัญชีใหม่เริ่มต้นเป็น Viewer',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // REGISTER BUTTON
                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          ElevatedButton(
                        onPressed: _loading
                            ? null
                            : _register,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'สมัครสมาชิก',
                                style:
                                    TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).pop();
                            },
                      child: const Text(
                        'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}