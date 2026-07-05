import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (response.user != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToRegister() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _handleGoogleSignIn(BuildContext context) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final localTextColor = isDark ? AppTheme.white : AppTheme.black;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.mediumGray.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in with Google',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: localTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'to continue to StyliAI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Account 1
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  title: Text(
                    'Ahmed Al-Masri',
                    style: TextStyle(color: localTextColor, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'ahmed.almasri@gmail.com',
                    style: TextStyle(color: AppTheme.mediumGray, fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(context); // Close bottom sheet
                    setState(() {
                      _isLoading = true;
                    });
                    HapticFeedback.mediumImpact();
                    await Future.delayed(const Duration(milliseconds: 1500));
                    if (!mounted) return;
                    setState(() {
                      _isLoading = false;
                    });
                    Navigator.pushAndRemoveUntil(
                      this.context,
                      MaterialPageRoute(builder: (_) => const MainShell()),
                      (route) => false,
                    );
                  },
                ),
                Divider(color: localTextColor.withValues(alpha: 0.1)),
                
                // Use another account
                ListTile(
                  leading: Icon(Icons.add_to_photos_outlined, color: AppTheme.mediumGray),
                  title: Text(
                    'Use another account',
                    style: TextStyle(color: localTextColor, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'To continue, Google will share your name, email address, language preference, and profile picture with StyliAI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.mediumGray.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.black : AppTheme.white;
    final textColor = isDark ? AppTheme.white : AppTheme.black;
    final fieldBg = isDark ? AppTheme.darkCard : AppTheme.lightGray;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SlideTransition(
              position: _slideUp,
              child: FadeTransition(
                opacity: _fadeIn,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      // StyliAI Calligraphy Logo
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.accentPurple, Color(0xFFE735F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentPurple.withValues(alpha: 0.25),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Taglines
                      Text(
                        "Welcome Back",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue styling your photos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.mediumGray,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Email Field
                      Text(
                        'Email Address',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your email';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textColor, fontSize: 15),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.email_outlined, color: AppTheme.mediumGray, size: 20),
                          filled: true,
                          fillColor: fieldBg,
                          hintText: 'Enter your email',
                          hintStyle: TextStyle(color: AppTheme.mediumGray.withValues(alpha: 0.7), fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      Text(
                        'Password',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your password' : null,
                        style: TextStyle(color: textColor, fontSize: 15),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.mediumGray, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppTheme.mediumGray,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: fieldBg,
                          hintText: 'Enter your password',
                          hintStyle: TextStyle(color: AppTheme.mediumGray.withValues(alpha: 0.7), fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign In Button
                      SizedBox(
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.accentPurple, Color(0xFFE735F6)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentPurple.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: textColor.withValues(alpha: 0.15))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(color: AppTheme.mediumGray, fontSize: 13),
                            ),
                          ),
                          Expanded(child: Divider(color: textColor.withValues(alpha: 0.15))),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Google Sign In button
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => _handleGoogleSignIn(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: textColor.withValues(alpha: 0.15), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text('G', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Sign in with Google',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Register link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: AppTheme.mediumGray, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: _navigateToRegister,
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppTheme.accentPurple,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
