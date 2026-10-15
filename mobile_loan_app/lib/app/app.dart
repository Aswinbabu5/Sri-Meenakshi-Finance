import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import '../core/services/loan_repository.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/loans/presentation/loan_form_page.dart';
import '../features/collections/presentation/daily_collection_page.dart';
import '../features/collections/presentation/editing_page.dart';
import '../features/loans/presentation/balance_view_page.dart';
import '../features/auth/presentation/financial_year_selection_page.dart';
import '../features/auth/presentation/splash_screen.dart';

class LoanManagementApp extends StatefulWidget {
  final int initialTabIndex;

  const LoanManagementApp({super.key, this.initialTabIndex = 0});

  @override
  State<LoanManagementApp> createState() => _LoanManagementAppState();
}

class _LoanManagementAppState extends State<LoanManagementApp> {
  final LoanRepository _repository = LoanRepository();
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sri Meenakshi Finance - Loan Register',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _showSplash
          ? AnimatedSplashScreen(
              onFinish: () {
                if (mounted) {
                  setState(() => _showSplash = false);
                }
              },
            )
          : (_repository.isAuthenticated
              ? (_repository.hasSelectedFinancialYear
                  ? MainAppShell(
                      repository: _repository,
                      initialIndex: widget.initialTabIndex,
                    )
                  : FinancialYearSelectionPage(
                      repository: _repository,
                      onYearSelected: (year) {
                        if (mounted) setState(() {});
                      },
                    ))
              : LoginPage(
                  repository: _repository,
                  onLoginSuccess: () {
                    final isPhone = Theme.of(context).platform == TargetPlatform.android ||
                        Theme.of(context).platform == TargetPlatform.iOS;
                    if (isPhone) {
                      // Mobile phones directly jump into the current active financial year
                      _repository.selectFinancialYear(LoanRepository.calculateCurrentFinancialYear());
                    }
                    if (mounted) setState(() {});
                  },
                )),
    );
  }
}

class MainAppShell extends StatefulWidget {
  final LoanRepository repository;
  final int initialIndex;

  const MainAppShell({
    super.key,
    required this.repository,
    this.initialIndex = 0,
  });

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    widget.repository.addListener(_onRepositoryUpdate);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryUpdate);
    super.dispose();
  }

  void _onRepositoryUpdate() {
    if (mounted) setState(() {});
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;

    final List<Widget> pages = [
      DashboardPage(repository: widget.repository),
      LoanFormPage(repository: widget.repository),
      EditingPage(repository: widget.repository),
      DailyCollectionPage(repository: widget.repository, receiptType: 'Chit'),
      BalanceViewPage(repository: widget.repository),
    ];

    return Scaffold(
      body: TweenAnimationBuilder<double>(
        key: ValueKey<int>(_currentIndex),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) {
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, 8 * (1.0 - opacity)),
              child: child,
            ),
          );
        },
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey.shade600,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          backgroundColor: Colors.white,
          elevation: 8,
          onTap: _onTabSelected,
          items: [
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _currentIndex == 0 ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.home),
              ),
              label: isTamil ? "முகப்பு" : "Home",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _currentIndex == 1 ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.add_circle_outline),
              ),
              label: isTamil ? "புதிய கடன்" : "New Loan",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _currentIndex == 2 ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.edit_note),
              ),
              label: isTamil ? "திருத்தம்" : "Edit",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _currentIndex == 3 ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.receipt_long),
              ),
              label: isTamil ? "கைசிட்டை" : "Daily Chit",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _currentIndex == 4 ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.account_balance_wallet_outlined),
              ),
              label: isTamil ? "பாக்கி" : "Balance",
            ),
          ],
        ),
      ),
    );
  }
}