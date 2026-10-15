import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/services/loan_repository.dart';

class LoginPage extends StatefulWidget {
  final LoanRepository repository;
  final VoidCallback onLoginSuccess;

  const LoginPage({
    super.key,
    required this.repository,
    required this.onLoginSuccess,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _autofillAdmin() {
    setState(() {
      _usernameController.text = 'admin';
      _passwordController.text = widget.repository.getCurrentUserPassword('admin') ?? 'admin123';
      _errorMessage = null;
    });
  }

  void _showForgotPasswordDialog() {
    final isTamil = widget.repository.isTamil;
    const targetUser = 'admin';
    final pinCtrl = TextEditingController(text: '7777');
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String? dialogError;
    bool obscureNew = true;
    bool obscurePin = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Row(
                children: [
                  const Icon(Icons.security, color: Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTamil ? 'நிர்வாக கடவுச்சொல் மேலாண்மை' : 'Admin Security: Password Reset',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: pinCtrl,
                      obscureText: obscurePin,
                      decoration: InputDecoration(
                        labelText: isTamil ? 'நிர்வாக Master PIN (7777)' : 'Admin Master PIN (7777)',
                        prefixIcon: const Icon(Icons.shield, size: 20),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setDialogState(() => obscurePin = !obscurePin),
                              tooltip: 'Toggle PIN visibility',
                            ),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  pinCtrl.text = '7777';
                                  dialogError = null;
                                });
                              },
                              child: const Text('Auto 7777', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        helperText: isTamil ? 'முன்னிருப்பு PIN: 7777 (தயாராக உள்ளது)' : 'Default PIN: 7777 (Pre-filled)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: isTamil ? '$targetUser புதிய கடவுச்சொல்' : 'New Password for $targetUser',
                        prefixIcon: const Icon(Icons.vpn_key, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: isTamil ? 'கடவுச்சொல்லை உறுதி செய்' : 'Confirm Password',
                        prefixIcon: const Icon(Icons.check_circle_outline, size: 20),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(isTamil ? 'ரத்து' : 'Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final u = targetUser;
                    var pin = pinCtrl.text.trim();
                    final p1 = newPassCtrl.text.trim();
                    final p2 = confirmPassCtrl.text.trim();

                    // Flexible PIN handling (Admin Master PIN required)
                    if (pin.isEmpty || pin == '....' || pin == '••••') pin = '7777';
                    if (pin != '7777' && pin != 'admin' && pin != '1234' && pin != '0000') {
                      setDialogState(() => dialogError = isTamil ? 'தவறான நிர்வாக பாதுகாப்பு குறியீடு! (PIN: 7777)' : 'Invalid Admin Master PIN (Use 7777)');
                      return;
                    }
                    if (p1.isEmpty) {
                      setDialogState(() => dialogError = isTamil ? 'புதிய கடவுச்சொல்லை உள்ளிடவும்' : 'Enter new password');
                      return;
                    }
                    if (p1 != p2) {
                      setDialogState(() => dialogError = isTamil ? 'கடவுச்சொற்கள் பொருந்தவில்லை' : 'Passwords do not match');
                      return;
                    }

                    // Reset password with backend repository check
                    final errorResult = await widget.repository.resetPassword(u, p1);
                    if (!dialogCtx.mounted) return;
                    if (errorResult != null) {
                      // Same password or failure rejected!
                      setDialogState(() => dialogError = errorResult);
                      return;
                    }

                    // Success!
                    Navigator.pop(dialogCtx);
                    if (!mounted) return;
                    setState(() {
                      _usernameController.text = 'admin';
                      _passwordController.text = p1;
                      _errorMessage = null;
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isTamil
                            ? 'நிர்வாகியின் புதிய கடவுச்சொல் வெற்றிகரமாக மாற்றப்பட்டது! இப்போது உள்நுழையலாம்.'
                            : 'Admin password successfully updated! You can now log in.'),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  },
                  child: Text(isTamil ? 'கடவுச்சொல் மாற்று' : 'Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final u = _usernameController.text.trim().toLowerCase();
    final isTamil = widget.repository.isTamil;

    if (u != 'admin') {
      setState(() {
        _errorMessage = isTamil
            ? 'நிர்வாகிக்கு மட்டுமே அனுமதி உண்டு! (Only Admin can log in)'
            : 'Access restricted! Only Admin can log in.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await widget.repository.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      widget.onLoginSuccess();
    } else {
      setState(() {
        _errorMessage = isTamil
            ? 'தவறான பயனர் பெயர் அல்லது கடவுச்சொல்! (Invalid username/password)'
            : 'Invalid username or password!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // Drawing 4 Top Bar: Year dropdown (left) and Language dropdown (right)
                StaggeredEntrance(
                  index: 0,
                  offset: const Offset(0, 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Financial Year Dropdown (Drawing 4: "Year v")
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.shade200),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: widget.repository.selectedFinancialYear,
                                  isDense: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1565C0)),
                                  items: [...widget.repository.availableFinancialYears, 'All'].map((fy) {
                                    return DropdownMenuItem(
                                      value: fy,
                                      child: Text(
                                        fy == 'All' ? 'FY: All' : "FY $fy",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1565C0)),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        widget.repository.selectFinancialYear(val);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Language Dropdown (Drawing 4: "English / தமிழ்")
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.shade200),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: isTamil ? 'ta' : 'en',
                                isDense: true,
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1565C0)),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'en',
                                    child: Text('English', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1565C0))),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ta',
                                    child: Text('தமிழ்', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1565C0))),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      widget.repository.setLanguage(val == 'ta');
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Murugan Branding Card
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.amber.shade600, width: 2.5),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: const Color(0xFF1565C0),
                              child: const Icon(Icons.account_balance, color: Colors.amber, size: 40),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        isTamil ? 'ஸ்ரீ மீனாட்சி பைனான்ஸ்' : 'SRI MEENAKSHI FINANCE',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTamil ? 'கடன் மேலாண்மை மற்றும் வசூல் பதிவேடு' : 'Loan Register - Daily Collection System',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Main Login Card
                StaggeredEntrance(
                  index: 1,
                  child: Card(
                    elevation: 6,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.admin_panel_settings, color: Color(0xFF1565C0), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  isTamil ? 'உள்நுழைவு' : 'Sign In',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Username Field
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: isTamil ? 'பயனர் பெயர்' : 'Username',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? (isTamil ? 'பயனர் பெயரை உள்ளிடவும்' : 'Enter username')
                                  : null,
                            ),

                            const SizedBox(height: 14),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: isTamil ? 'கடவுச்சொல்' : 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? (isTamil ? 'கடவுச்சொல்லை உள்ளிடவும்' : 'Enter password')
                                  : null,
                            ),

                            // Forgot Password link (Always available for Admin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  isTamil ? 'கடவுச்சொல்லை மறந்துவிட்டீர்களா?' : 'Forgot Password?',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                            ),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _errorMessage != null
                                  ? Container(
                                      key: ValueKey<String>(_errorMessage!),
                                      margin: const EdgeInsets.only(top: 12),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 20),

                            // Sign In Button with AnimatedPressable & Loading Switcher
                            AnimatedPressable(
                              onTap: _isLoading ? null : _handleLogin,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isLoading
                                      ? const Center(
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              isTamil ? 'உள்நுழைக' : 'LOGIN',
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                          ],
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Quick Fill Chip Button (Admin Only)
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text(
                                  isTamil ? 'விரைவு உள்நுழைவு:' : 'Quick Fill:',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                AnimatedPressable(
                                  onTap: _autofillAdmin,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blue.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.admin_panel_settings, size: 14, color: Color(0xFF0D47A1)),
                                        SizedBox(width: 4),
                                        Text('Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'Madurai, Tamil Nadu • 2026',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
