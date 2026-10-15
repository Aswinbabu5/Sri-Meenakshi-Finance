import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../models/loan_model.dart';
import '../models/collection_model.dart';
import '../models/line_model.dart';
import '../models/user_model.dart';
import 'database_helper.dart';

class LoanRepository extends ChangeNotifier {
  static final LoanRepository _instance = LoanRepository._internal();
  factory LoanRepository() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final List<CustomerModel> _customers = [];
  final List<LoanModel> _loans = [];
  final List<CollectionModel> _collections = [];
  final List<LineModel> _lines = [];

  UserModel? _currentUser;
  bool isTamil = true; // Default to Tamil as in the original software
  String selectedLine = 'A';
  bool _isInitialized = false;

  // Financial Year State
  static String calculateCurrentFinancialYear([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    if (startYear >= 2026) {
      return '2026-Present';
    }
    return '$startYear-$endYear';
  }

  late String selectedFinancialYear = calculateCurrentFinancialYear();
  bool hasSelectedFinancialYear = false;
  List<String> _availableFinancialYears = [
    '2024-2025',
    '2025-2026',
    '2026-Present',
  ];
  List<String> get availableFinancialYears => List.unmodifiable(_availableFinancialYears);

  List<String> get availableLines {
    final set = _lines.map((l) => l.lineCode.toUpperCase()).toSet();
    if (set.isEmpty) {
      set.addAll(['A', 'B', 'C', 'D']);
    }
    final list = set.toList()..sort();
    return list;
  }

  Future<void> addFinancialYear(String year) async {
    final trimmed = year.trim();
    if (trimmed.isEmpty || _availableFinancialYears.contains(trimmed)) return;
    _availableFinancialYears.add(trimmed);
    await _dbHelper.insertFinancialYear(trimmed);
    notifyListeners();
  }

  Future<void> deleteFinancialYear(String year) async {
    final trimmed = year.trim();
    if (!_availableFinancialYears.contains(trimmed)) return;
    _availableFinancialYears.remove(trimmed);
    await _dbHelper.deleteFinancialYear(trimmed);
    if (selectedFinancialYear == trimmed) {
      selectedFinancialYear = _availableFinancialYears.isNotEmpty ? _availableFinancialYears.last : 'All';
    }
    notifyListeners();
  }

  Future<void> addLine(String lineCode, [String? lineName]) async {
    final code = lineCode.trim().toUpperCase();
    if (code.isEmpty || _lines.any((l) => l.lineCode.toUpperCase() == code)) return;
    final name = (lineName != null && lineName.trim().isNotEmpty) ? lineName.trim() : 'Line $code';
    final line = LineModel(
      lineCode: code,
      lineName: name,
      collectorName: 'Admin',
      description: 'Collection Line $code',
    );
    _lines.add(line);
    await _dbHelper.insertLine(line);
    notifyListeners();
  }

  Future<void> deleteLine(String lineCode) async {
    final code = lineCode.trim().toUpperCase();
    _lines.removeWhere((l) => l.lineCode.toUpperCase() == code);
    await _dbHelper.deleteLine(code);
    if (selectedLine.toUpperCase() == code) {
      selectedLine = availableLines.isNotEmpty ? availableLines.first : 'A';
    }
    notifyListeners();
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser != null;
  bool get isLender => false;
  bool get isViewer => false;
  bool get isInitialized => _isInitialized;

  Future<void>? _initFuture;

  LoanRepository._internal() {
    _initFuture = _initRepository();
  }

  Future<void> ensureInitialized() => _initFuture ?? Future.value();

  Future<void> _initRepository() async {
    // Default to null so user logs in first
    _currentUser = null;
    hasSelectedFinancialYear = false;

    await _loadFromDatabase();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadFromDatabase() async {
    try {
      final dbLines = await _dbHelper.getAllLines();
      _lines.clear();
      _lines.addAll(dbLines);

      final dbFys = await _dbHelper.getAllFinancialYears();
      if (dbFys.isNotEmpty) {
        _availableFinancialYears = List.from(dbFys);
      } else {
        for (final fy in _availableFinancialYears) {
          await _dbHelper.insertFinancialYear(fy);
        }
      }

      final dbCustomers = await _dbHelper.getAllCustomers();
      _customers.clear();
      _customers.addAll(dbCustomers);

      final dbLoans = await _dbHelper.getAllLoans();
      _loans.clear();
      _loans.addAll(dbLoans);

      final dbCollections = await _dbHelper.getAllCollections();
      _collections.clear();
      _collections.addAll(dbCollections);

      final dbUsers = await _dbHelper.getAllUsers();
      for (final usr in dbUsers) {
        _usersCache[usr.username.toLowerCase()] = usr;
      }
    } catch (e) {
      debugPrint('Database load fallback: $e');
    }
  }

  final Map<String, UserModel> _usersCache = {
    'admin': const UserModel(
      id: 1,
      username: 'admin',
      password: 'admin123',
      name: 'நிர்வாகி (Admin)',
      role: 'admin',
    ),
  };

  String? getCurrentUserPassword(String username) {
    final u = username.trim().toLowerCase();
    return _usersCache[u]?.password;
  }

  // --- Authentication ---
  Future<bool> login(String username, String password) async {
    await ensureInitialized();
    final u = username.trim().toLowerCase();
    final p = password.trim();

    // Only Admin can authenticate
    if (u != 'admin') {
      return false;
    }

    // 1. Authenticate against DB first
    final dbUser = await _dbHelper.authenticateUser(u, p);
    if (dbUser != null) {
      _usersCache[u] = dbUser;
      _currentUser = dbUser;
      notifyListeners();
      return true;
    }

    // 2. Authenticate against active in-memory cache
    final cached = _usersCache[u];
    if (cached != null && cached.password == p) {
      _currentUser = cached;
      notifyListeners();
      return true;
    }

    return false;
  }

  void switchRole(String role) {
    // Single-role Admin architecture
    _currentUser = _usersCache['admin'] ?? UserModel(
      id: 1,
      username: 'admin',
      password: getCurrentUserPassword('admin') ?? 'admin123',
      name: 'நிர்வாகி (Admin)',
      role: 'admin',
    );
    notifyListeners();
  }

  /// Admin can change password
  Future<String?> resetPassword(String username, String newPassword) async {
    final u = username.trim().toLowerCase();
    final p = newPassword.trim();

    if (u != 'admin') {
      return isTamil ? 'நிர்வாகி கடவுச்சொல் மட்டுமே மாற்ற முடியும்' : 'Only Admin password can be reset';
    }

    if (p.isEmpty) {
      return isTamil ? 'புதிய கடவுச்சொல்லை உள்ளிடவும்' : 'Enter new password';
    }

    // 1. Fetch current password from cache or database
    final existingUser = await _dbHelper.getUserByUsername(u);
    final currentPass = existingUser?.password ?? _usersCache[u]?.password;

    // 2. Reject if the new password is the SAME as the current password
    if (currentPass != null && p == currentPass) {
      return isTamil
          ? 'புதிய கடவுச்சொல் பழைய கடவுச்சொல்லாகவே உள்ளது! தயவுசெய்து வேறு புதிய கடவுச்சொல்லை உள்ளிடவும்.'
          : 'New password cannot be the same as your existing password! Please choose a different password.';
    }

    final success = await _dbHelper.resetUserPassword(u, p);
    if (success) {
      final oldModel = _usersCache[u];
      final updated = (oldModel != null)
          ? oldModel.copyWith(password: p)
          : UserModel(
              id: 1,
              username: 'admin',
              password: p,
              name: 'நிர்வாகி (Admin)',
              role: 'admin',
            );
      _usersCache[u] = updated;

      if (_currentUser?.username.toLowerCase() == u) {
        _currentUser = updated;
      }
      notifyListeners();
      return null; // Success!
    }
    return isTamil ? 'கடவுச்சொல் மாற்றுவதில் பிழை ஏற்பட்டது' : 'Failed to reset password';
  }

  Future<void> toggleTargetCustomer(String bondNumber, bool isTarget) async {
    final loan = getLoanByBond(bondNumber);
    if (loan != null) {
      final updatedLoan = loan.copyWith(isTargetCustomer: isTarget);
      final idx = _loans.indexWhere((l) => l.bondNumber == loan.bondNumber);
      if (idx != -1) {
        _loans[idx] = updatedLoan;
      }
      final custIdx = _customers.indexWhere((c) => c.id == loan.customerId);
      if (custIdx != -1) {
        _customers[custIdx] = _customers[custIdx].copyWith(isTargetCustomer: isTarget);
      }
      await _dbHelper.toggleCustomerTargetStatus(loan.customerId, isTarget);
      notifyListeners();
    }
  }

  void logout() {
    _currentUser = null;
    hasSelectedFinancialYear = false;
    notifyListeners();
  }

  void selectFinancialYear(String fy) {
    selectedFinancialYear = fy;
    hasSelectedFinancialYear = true;
    notifyListeners();
  }

  void resetFinancialYearSelection() {
    hasSelectedFinancialYear = false;
    notifyListeners();
  }

  bool isDateInFinancialYear(DateTime date, String fy) {
    if (fy == 'All' || fy.isEmpty) return true;
    final parts = fy.split('-');
    if (parts.length == 2) {
      final startYear = int.tryParse(parts[0].replaceAll(RegExp(r'\D'), ''));
      if (startYear != null) {
        if (parts[1].toLowerCase().contains('present')) {
          return (date.year == startYear && date.month >= 4) || (date.year > startYear);
        }
        final endYear = int.tryParse(parts[1].replaceAll(RegExp(r'\D'), ''));
        if (endYear != null) {
          return (date.year == startYear && date.month >= 4) || (date.year == endYear && date.month <= 3);
        }
      }
    }
    return true; // Fallback
  }

  void toggleLanguage() {
    isTamil = !isTamil;
    notifyListeners();
  }

  void setLanguage(bool tamil) {
    if (isTamil != tamil) {
      isTamil = tamil;
      notifyListeners();
    }
  }

  void setLine(String line) {
    selectedLine = line;
    notifyListeners();
  }

  // --- Queries ---
  List<LineModel> getLines() => List.unmodifiable(_lines);
  List<CustomerModel> getCustomers() => List.unmodifiable(_customers);
  List<CollectionModel> getCollections() => List.unmodifiable(_collections);

  /// Find customer by Member ID (e.g. 1 or CUS001), phone number, bond number, or name
  CustomerModel? getCustomerByIdOrCode(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    // 1. By Customer Code (e.g. CUS001)
    for (final c in _customers) {
      if (c.cusCode.toLowerCase() == q) return c;
    }
    // 2. By numeric ID
    final idNum = int.tryParse(q);
    if (idNum != null) {
      for (final c in _customers) {
        if (c.id == idNum) return c;
      }
    }
    // 3. By Phone Number
    final digitsOnly = q.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isNotEmpty && digitsOnly.length >= 7) {
      for (final c in _customers) {
        final cDigits = c.phoneNumber.replaceAll(RegExp(r'\D'), '');
        if (cDigits.contains(digitsOnly) || digitsOnly.contains(cDigits)) return c;
      }
    }
    // 4. By existing Bond Number (e.g. A001)
    for (final l in _loans) {
      if (l.bondNumber.toLowerCase() == q) {
        for (final c in _customers) {
          if (c.id == l.customerId) return c;
        }
        if (l.customer != null) return l.customer;
      }
    }
    // 5. By Customer Name (exact match)
    for (final c in _customers) {
      if (c.name.toLowerCase() == q) return c;
    }
    return null;
  }

  /// Search customers by partial match for name, code, phone
  List<CustomerModel> searchCustomers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_customers);
    return _customers.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.cusCode.toLowerCase().contains(q) ||
          c.id.toString() == q ||
          c.phoneNumber.contains(q) ||
          (c.fatherOrSpouseName != null && c.fatherOrSpouseName!.toLowerCase().contains(q));
    }).toList();
  }

  /// Get all loans previously or currently associated with a customer
  List<LoanModel> getCustomerLoans(int customerId) {
    return _loans.where((l) => l.customerId == customerId).toList();
  }

  List<LoanModel> getLoans({
    String? lineCode,
    String? status,
    String? search,
    String? financialYear,
  }) {
    var list = _loans.toList();
    final fy = financialYear ?? selectedFinancialYear;
    if (fy != 'All') {
      list = list.where((l) => isDateInFinancialYear(l.startDate, fy)).toList();
    }
    if (lineCode != null && lineCode != 'All') {
      list = list.where((l) => l.lineCode == lineCode).toList();
    }
    if (status != null && status != 'All') {
      list = list.where((l) => l.status == status).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((l) =>
        l.bondNumber.toLowerCase().contains(q) ||
        l.customerName.toLowerCase().contains(q) ||
        l.phoneNumber.contains(q) ||
        (l.proofType != null && l.proofType!.toLowerCase().contains(q)) ||
        (l.address != null && l.address!.toLowerCase().contains(q))
      ).toList();
    }
    return list;
  }

  LoanModel? getLoanByBond(String bondNumber, [String? lineCode]) {
    final raw = bondNumber.trim().toUpperCase().replaceAll('-', '').replaceAll(' ', '');
    if (raw.isEmpty) return null;

    final targetLine = (lineCode != null && lineCode.isNotEmpty) ? lineCode.toUpperCase() : selectedLine;

    try {
      return _loans.firstWhere((l) {
        final b = l.bondNumber.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
        if (b == raw) return true;
        // Search by numeric suffix e.g. "001" or "1"
        final intVal = int.tryParse(raw);
        if (intVal != null) {
          if (b == '$targetLine${intVal.toString().padLeft(3, '0')}') return true;
        }
        return false;
      });
    } catch (_) {
      return null;
    }
  }

  /// Calculates next bond numeric part without hyphen, starting from "001"
  /// e.g. for line A: A001, A002, A003
  String getNextBondNumber(String lineCode) {
    final line = lineCode.isEmpty ? 'A' : lineCode.toUpperCase();
    int maxNum = 0;

    for (var l in _loans.where((x) => x.lineCode == line)) {
      // Bond is e.g. "A001" or legacy "A-01"
      String clean = l.bondNumber.toUpperCase().replaceAll('-', '');
      if (clean.startsWith(line)) {
        clean = clean.substring(line.length);
      }
      final n = int.tryParse(clean) ?? 0;
      if (n > maxNum) maxNum = n;
    }

    final next = maxNum + 1;
    return next.toString().padLeft(3, '0'); // returns "001", "002", etc.
  }

  /// Generates the full formatted ID without hyphen e.g. "A001"
  String formatBondNumber(String lineCode, String inputNumber) {
    final line = lineCode.trim().toUpperCase();
    String cleanNum = inputNumber.trim().toUpperCase().replaceAll('-', '');
    if (cleanNum.startsWith(line)) {
      cleanNum = cleanNum.substring(line.length);
    }
    final n = int.tryParse(cleanNum);
    if (n != null) {
      return '$line${n.toString().padLeft(3, '0')}';
    }
    return '$line$cleanNum';
  }

  // --- Mutations ---
  Future<LoanModel> createLoan({
    required String lineCode,
    String? bondNumber,
    int? customerId,
    required String customerName,
    String? fatherOrSpouseName,
    required String phoneNumber,
    String? address,
    String city = "மதுரை",
    String? photoPath,
    String? proofType,
    String? proofFrontPath,
    String? proofBackPath,
    String? details,
    int tenureDays = 100,
    required double loanAmount,
    required double interestAmount,
    double chitFee = 100,
    required DateTime startDate,
  }) async {
    if (_currentUser != null && !isAdmin) {
      throw Exception(isTamil ? 'அனுமதி இல்லை: நிர்வாகி மட்டுமே புதிய கடன் உருவாக்க முடியும்.' : 'Access Denied: Only Admin can create new loans.');
    }

    final line = lineCode.toUpperCase();

    // Bond ID starts at A001, NO hyphen!
    String bond;
    if (bondNumber != null && bondNumber.trim().isNotEmpty) {
      bond = formatBondNumber(line, bondNumber);
    } else {
      bond = '$line${getNextBondNumber(line)}';
    }

    final total = loanAmount;
    final tenure = tenureDays > 0 ? tenureDays : 100;
    final dailyDue = (total / tenure).roundToDouble();

    // Find or create customer
    CustomerModel? cust;
    if (customerId != null && customerId > 0) {
      for (final c in _customers) {
        if (c.id == customerId) {
          cust = c;
          break;
        }
      }
    }

    if (cust != null) {
      // Existing customer: update details if provided
      cust = cust.copyWith(
        name: customerName.trim(),
        fatherOrSpouseName: fatherOrSpouseName ?? cust.fatherOrSpouseName,
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : cust.phoneNumber,
        address: address ?? cust.address,
        city: city.isNotEmpty ? city : cust.city,
        photoPath: photoPath ?? cust.photoPath,
        proofType: proofType ?? cust.proofType,
        proofFrontPath: proofFrontPath ?? cust.proofFrontPath,
        proofBackPath: proofBackPath ?? cust.proofBackPath,
        notes: details ?? cust.notes,
      );
      final cIdx = _customers.indexWhere((c) => c.id == cust!.id);
      if (cIdx != -1) _customers[cIdx] = cust;
      await _dbHelper.updateCustomer(cust);
    } else {
      try {
        cust = _customers.firstWhere((c) =>
          c.name.toLowerCase() == customerName.trim().toLowerCase() ||
          (c.phoneNumber == phoneNumber && phoneNumber.isNotEmpty)
        );
        // Update customer proof/details if newly provided
        if (photoPath != null || proofType != null || proofFrontPath != null || proofBackPath != null) {
          cust = cust.copyWith(
            photoPath: photoPath ?? cust.photoPath,
            proofType: proofType ?? cust.proofType,
            proofFrontPath: proofFrontPath ?? cust.proofFrontPath,
            proofBackPath: proofBackPath ?? cust.proofBackPath,
            fatherOrSpouseName: fatherOrSpouseName ?? cust.fatherOrSpouseName,
            address: address ?? cust.address,
          );
          final cIdx = _customers.indexWhere((c) => c.id == cust!.id);
          if (cIdx != -1) _customers[cIdx] = cust;
          await _dbHelper.updateCustomer(cust);
        }
      } catch (_) {
        final allDbCusts = await _dbHelper.getAllCustomers();
        int nextNum = (allDbCusts.length > _customers.length ? allDbCusts.length : _customers.length) + 1;
        while (allDbCusts.any((c) => c.cusCode == 'CUS${nextNum.toString().padLeft(3, '0')}') ||
               _customers.any((c) => c.cusCode == 'CUS${nextNum.toString().padLeft(3, '0')}')) {
          nextNum++;
        }
        final newCusCode = 'CUS${nextNum.toString().padLeft(3, '0')}';
        cust = CustomerModel(
          id: 0,
          cusCode: newCusCode,
          name: customerName.trim(),
          fatherOrSpouseName: fatherOrSpouseName,
          phoneNumber: phoneNumber,
          address: address,
          city: city,
          photoPath: photoPath,
          proofType: proofType,
          proofFrontPath: proofFrontPath,
          proofBackPath: proofBackPath,
          notes: details,
        );
        final insertedId = await _dbHelper.insertCustomer(cust);
        if (insertedId > 0) {
          cust = cust.copyWith(id: insertedId);
        }
        _customers.add(cust);
      }
    }

    var newLoan = LoanModel(
      id: 0,
      bondNumber: bond,
      lineCode: line,
      customerId: cust.id,
      customer: cust,
      customerName: cust.name,
      fatherOrSpouseName: fatherOrSpouseName ?? cust.fatherOrSpouseName,
      phoneNumber: phoneNumber,
      address: address ?? cust.address,
      city: city,
      photoPath: photoPath,
      proofType: proofType,
      proofFrontPath: proofFrontPath,
      proofBackPath: proofBackPath,
      tenureDays: tenure,
      loanAmount: loanAmount,
      interestRate: 1.0,
      interestAmount: interestAmount,
      totalAmount: total,
      dailyDueAmount: dailyDue,
      chitFee: chitFee,
      startDate: startDate,
      endDate: startDate.add(Duration(days: tenure)),
      collectedAmount: 0,
      balanceAmount: total,
      status: 'active',
    );

    final insertedLoanId = await _dbHelper.insertLoan(newLoan);
    if (insertedLoanId > 0) {
      newLoan = newLoan.copyWith(id: insertedLoanId);
    }
    _loans.insert(0, newLoan);

    notifyListeners();
    return newLoan;
  }

  /// Updates a member's details.
  /// If [isAdmin] is false (Viewer role): only personal, identification, photo, and notes are modified.
  /// Financial loan terms (loanAmount, interest, tenure, dailyDue, startDate) can only be changed if [isAdmin] is true.
  Future<void> updateMember({
    required int loanId,
    required String customerName,
    String? fatherOrSpouseName,
    required String phoneNumber,
    String? address,
    String? city,
    String? photoPath,
    String? proofType,
    String? proofFrontPath,
    String? proofBackPath,
    String? notes,
    // Financial fields (Admin only)
    String? lineCode,
    String? bondNumber,
    double? loanAmount,
    double? interestAmount,
    double? chitFee,
    int? tenureDays,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final loanIdx = _loans.indexWhere((l) => l.id == loanId);
    if (loanIdx == -1) return;

    final existingLoan = _loans[loanIdx];

    // Check permissions
    final canEditFinancials = isAdmin;

    String finalLine = existingLoan.lineCode;
    String finalBond = existingLoan.bondNumber;
    double finalLoanAmount = existingLoan.loanAmount;
    double finalInterestAmount = existingLoan.interestAmount;
    double finalChitFee = existingLoan.chitFee;
    int finalTenure = existingLoan.tenureDays;
    DateTime finalStartDate = existingLoan.startDate;
    DateTime finalEndDate = existingLoan.endDate;
    double finalTotalAmount = existingLoan.totalAmount;
    double finalDailyDue = existingLoan.dailyDueAmount;
    double finalBalance = existingLoan.balanceAmount;

    if (canEditFinancials) {
      if (lineCode != null && lineCode.isNotEmpty) finalLine = lineCode;
      if (bondNumber != null && bondNumber.isNotEmpty) {
        finalBond = formatBondNumber(finalLine, bondNumber);
      }
      if (loanAmount != null) finalLoanAmount = loanAmount;
      if (interestAmount != null) finalInterestAmount = interestAmount;
      if (chitFee != null) finalChitFee = chitFee;
      if (tenureDays != null && tenureDays > 0) finalTenure = tenureDays;
      if (startDate != null) {
        finalStartDate = startDate;
        finalEndDate = endDate ?? finalStartDate.add(Duration(days: finalTenure));
      } else if (endDate != null) {
        finalEndDate = endDate;
      }
      finalTotalAmount = finalLoanAmount;
      finalDailyDue = (finalTotalAmount / finalTenure).roundToDouble();
      finalBalance = (finalTotalAmount - existingLoan.collectedAmount).clamp(0, finalTotalAmount);
    }

    final updatedLoan = existingLoan.copyWith(
      lineCode: finalLine,
      bondNumber: finalBond,
      customerName: customerName.trim(),
      fatherOrSpouseName: fatherOrSpouseName,
      phoneNumber: phoneNumber.trim(),
      address: address,
      city: city,
      photoPath: photoPath ?? existingLoan.photoPath,
      proofType: proofType ?? existingLoan.proofType,
      proofFrontPath: proofFrontPath ?? existingLoan.proofFrontPath,
      proofBackPath: proofBackPath ?? existingLoan.proofBackPath,
      loanAmount: finalLoanAmount,
      interestAmount: finalInterestAmount,
      chitFee: finalChitFee,
      totalAmount: finalTotalAmount,
      dailyDueAmount: finalDailyDue,
      tenureDays: finalTenure,
      startDate: finalStartDate,
      endDate: finalEndDate,
      balanceAmount: finalBalance,
      status: status ?? existingLoan.status,
    );

    _loans[loanIdx] = updatedLoan;
    await _dbHelper.updateLoan(updatedLoan);

    // Also update customer model
    final custIdx = _customers.indexWhere((c) => c.id == existingLoan.customerId);
    if (custIdx != -1) {
      final updatedCust = _customers[custIdx].copyWith(
        name: customerName.trim(),
        fatherOrSpouseName: fatherOrSpouseName,
        phoneNumber: phoneNumber.trim(),
        address: address,
        city: city ?? _customers[custIdx].city,
        photoPath: photoPath ?? _customers[custIdx].photoPath,
        proofType: proofType ?? _customers[custIdx].proofType,
        proofFrontPath: proofFrontPath ?? _customers[custIdx].proofFrontPath,
        proofBackPath: proofBackPath ?? _customers[custIdx].proofBackPath,
        notes: notes ?? _customers[custIdx].notes,
      );
      _customers[custIdx] = updatedCust;
      await _dbHelper.updateCustomer(updatedCust);
    }

    notifyListeners();
  }

  Future<void> deleteLoan(dynamic idOrBond) async {
    if (!isAdmin) {
      throw Exception('Only Admin can delete loan accounts.');
    }

    int? targetId;
    String? targetBond;

    if (idOrBond is int) {
      targetId = idOrBond;
      for (var l in _loans) {
        if (l.id == targetId) {
          targetBond = l.bondNumber;
          break;
        }
      }
    } else if (idOrBond is String) {
      targetBond = idOrBond.trim();
      for (var l in _loans) {
        if (l.bondNumber.toUpperCase() == targetBond.toUpperCase()) {
          targetId = l.id;
          break;
        }
      }
    }

    if (targetId == null && targetBond == null) {
      throw Exception('Loan account not found.');
    }

    // Remove from in-memory loans
    _loans.removeWhere((l) =>
      (targetId != null && l.id == targetId) ||
      (targetBond != null && l.bondNumber.toUpperCase() == targetBond.toUpperCase())
    );

    // Remove from in-memory collections
    if (targetBond != null) {
      _collections.removeWhere((c) => c.bondNumber.toUpperCase() == targetBond!.toUpperCase());
    }

    // Delete in SQLite database
    await _dbHelper.deleteLoan(targetId ?? 0, bondNumber: targetBond);

    notifyListeners();
  }

  Future<CollectionModel> recordCollection({
    required String bondNumber,
    required String lineCode,
    required double amount,
    DateTime? collectionDate,
    String receiptType = 'Note',
    String paymentMode = 'Cash',
    String? notes,
    String? personName,
  }) async {
    if (_currentUser != null && !isAdmin) {
      throw Exception(isTamil ? 'அனுமதி இல்லை: நிர்வாகி மட்டுமே வசூல் செய்ய முடியும்.' : 'Access Denied: Only Admin can record collections.');
    }

    final loan = getLoanByBond(bondNumber, lineCode);
    final date = collectionDate ?? DateTime.now();

    final effectivePayerName = (personName != null && personName.trim().isNotEmpty)
        ? personName.trim()
        : (loan?.customerName ?? 'வாடிக்கையாளர்');

    double prevBal = 0;
    double newBal = 0;
    int loanId = 0;
    String finalBond = bondNumber.trim().isNotEmpty ? formatBondNumber(lineCode, bondNumber) : '$lineCode-CHIT';

    if (loan != null) {
      loanId = loan.id;
      finalBond = loan.bondNumber;
      prevBal = loan.balanceAmount;
      newBal = prevBal - amount;
      if (newBal < 0) newBal = 0;

      loan.collectedAmount += amount;
      loan.balanceAmount = newBal;
      if (newBal <= 0) {
        loan.status = 'closed';
        loan.finishedDate = date;
      }

      final isOnlinePayment = paymentMode.toLowerCase() == 'online';
      if (isOnlinePayment) {
        final updatedLoan = loan.copyWith(isTargetCustomer: true);
        final lIdx = _loans.indexWhere((l) => l.bondNumber == loan.bondNumber);
        if (lIdx != -1) _loans[lIdx] = updatedLoan;
        final cIdx = _customers.indexWhere((c) => c.id == loan.customerId);
        if (cIdx != -1) _customers[cIdx] = _customers[cIdx].copyWith(isTargetCustomer: true);
        await _dbHelper.toggleCustomerTargetStatus(loan.customerId, true);
      }
    }

    // Check if a collection already exists for this bond/loan on the same date
    final existingIdx = _collections.indexWhere((c) {
      final cb = c.bondNumber.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
      final fb = finalBond.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
      final sameBond = (cb == fb || (loanId != 0 && c.loanId == loanId));
      final sameDay = c.collectionDate.year == date.year &&
          c.collectionDate.month == date.month &&
          c.collectionDate.day == date.day;
      return sameBond && sameDay;
    });

    if (existingIdx != -1) {
      final existingCol = _collections[existingIdx];
      final combinedAmount = existingCol.amount + amount;
      String? combinedNotes;
      if (notes != null && notes.trim().isNotEmpty) {
        if (existingCol.notes != null && existingCol.notes!.trim().isNotEmpty) {
          combinedNotes = '${existingCol.notes!.trim()}, ${notes.trim()}';
        } else {
          combinedNotes = notes.trim();
        }
      } else {
        combinedNotes = existingCol.notes;
      }

      final updatedCol = CollectionModel(
        id: existingCol.id,
        loanId: existingCol.loanId,
        bondNumber: existingCol.bondNumber,
        lineCode: existingCol.lineCode,
        customerName: effectivePayerName,
        collectionDate: existingCol.collectionDate,
        amount: combinedAmount,
        previousBalance: existingCol.previousBalance,
        currentBalance: newBal,
        receiptType: receiptType,
        paymentMode: paymentMode,
        notes: combinedNotes,
      );

      _collections[existingIdx] = updatedCol;
      await _dbHelper.updateCollection(updatedCol);
      if (loan != null) {
        await _dbHelper.updateLoan(loan);
      }
      notifyListeners();
      return updatedCol;
    }

    var collection = CollectionModel(
      id: 0,
      loanId: loanId,
      bondNumber: finalBond,
      lineCode: lineCode,
      customerName: effectivePayerName,
      collectionDate: date,
      amount: amount,
      previousBalance: prevBal,
      currentBalance: newBal,
      receiptType: receiptType,
      paymentMode: paymentMode,
      notes: notes,
    );

    final insertedColId = await _dbHelper.insertCollection(collection);
    if (insertedColId > 0) {
      collection = CollectionModel(
        id: insertedColId,
        loanId: collection.loanId,
        bondNumber: collection.bondNumber,
        lineCode: collection.lineCode,
        customerName: collection.customerName,
        collectionDate: collection.collectionDate,
        amount: collection.amount,
        previousBalance: collection.previousBalance,
        currentBalance: collection.currentBalance,
        receiptType: collection.receiptType,
        paymentMode: collection.paymentMode,
        notes: collection.notes,
      );
    }

    _collections.insert(0, collection);
    if (loan != null) {
      await _dbHelper.updateLoan(loan);
    }

    notifyListeners();
    return collection;
  }

  Future<void> updateCollection(int id, double newAmount) async {
    final idx = _collections.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final col = _collections[idx];
      final loan = _loans.firstWhere((l) => l.bondNumber == col.bondNumber);
      final diff = newAmount - col.amount;
      loan.collectedAmount += diff;
      loan.balanceAmount -= diff;
      if (loan.balanceAmount < 0) loan.balanceAmount = 0;

      final updatedCol = CollectionModel(
        id: col.id,
        loanId: col.loanId,
        bondNumber: col.bondNumber,
        lineCode: col.lineCode,
        customerName: col.customerName,
        collectionDate: col.collectionDate,
        amount: newAmount,
        previousBalance: col.previousBalance,
        currentBalance: loan.balanceAmount,
        receiptType: col.receiptType,
        notes: col.notes,
      );

      _collections[idx] = updatedCol;
      await _dbHelper.updateLoan(loan);
      await _dbHelper.updateCollection(updatedCol);

      notifyListeners();
    }
  }

  Future<void> deleteCollection(int id) async {
    if (!isAdmin) {
      throw Exception('Only Admin can delete collection records.');
    }

    final idx = _collections.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final col = _collections[idx];
      final loanIdx = _loans.indexWhere((l) => l.bondNumber == col.bondNumber);
      if (loanIdx != -1) {
        final loan = _loans[loanIdx];
        loan.collectedAmount -= col.amount;
        loan.balanceAmount += col.amount;
        await _dbHelper.updateLoan(loan);
      }
      _collections.removeAt(idx);
      await _dbHelper.deleteCollection(id);

      notifyListeners();
    }
  }

  List<CollectionModel> getDailySheet({required DateTime date, required String lineCode}) {
    return _collections.where((c) {
      final sameLine = lineCode == 'All' || c.lineCode == lineCode;
      final sameDay = c.collectionDate.year == date.year &&
                      c.collectionDate.month == date.month &&
                      c.collectionDate.day == date.day;
      return sameLine && sameDay;
    }).toList();
  }

  /// Check if an installment collection has already been recorded for this loan on this date
  CollectionModel? getTodayCollectionForLoan(String bondNumber, DateTime date) {
    final b = bondNumber.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
    try {
      return _collections.firstWhere((c) {
        final cb = c.bondNumber.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
        final sameBond = cb == b || cb.endsWith(b);
        final sameDay = c.collectionDate.year == date.year &&
            c.collectionDate.month == date.month &&
            c.collectionDate.day == date.day;
        return sameBond && sameDay;
      });
    } catch (_) {
      return null;
    }
  }

  List<CollectionModel> getLedger(String bondNumber) {
    final b = bondNumber.trim().toUpperCase().replaceAll('-', '');
    return _collections.where((c) {
      final cb = c.bondNumber.toUpperCase().replaceAll('-', '');
      return cb == b || cb.endsWith(b);
    }).toList()
      ..sort((a, b) => b.collectionDate.compareTo(a.collectionDate));
  }

  Map<String, dynamic> getDashboardSummary() {
    final active = _loans.where((l) => l.status == 'active').toList();
    final totalOutstanding = active.fold<double>(0, (sum, l) => sum + l.balanceAmount);

    final today = DateTime.now();
    final todayCols = _collections.where((c) =>
      c.collectionDate.year == today.year &&
      c.collectionDate.month == today.month &&
      c.collectionDate.day == today.day
    ).toList();

    final todayTotal = todayCols.fold<double>(0, (sum, c) => sum + c.amount);

    final todayLoans = _loans.where((l) =>
      l.startDate.year == today.year &&
      l.startDate.month == today.month &&
      l.startDate.day == today.day
    ).toList();
    final todayInterest = todayLoans.fold<double>(0, (sum, l) => sum + l.interestAmount);
    final todayDisbursed = todayLoans.fold<double>(0, (sum, l) => sum + l.loanAmount);
    final todayDocCharge = todayLoans.fold<double>(0, (sum, l) => sum + l.chitFee);
    // Standardized Formula: original amnt - interest amnt + docment charge + days
    final todayAmountReceived = todayDisbursed - (todayInterest + todayDocCharge + todayTotal);

    // Lender Capital & Investment Totals
    final totalLendedPrincipal = _loans.fold<double>(0, (sum, l) => sum + l.loanAmount);
    final thisMonthLoans = _loans.where((l) =>
      l.startDate.year == today.year && l.startDate.month == today.month
    ).toList();
    final thisMonthLendedPrincipal = thisMonthLoans.fold<double>(0, (sum, l) => sum + l.loanAmount);

    final totalExpectedReturns = _loans.fold<double>(0, (sum, l) => sum + l.totalAmount);
    final totalCollectedAmount = _collections.fold<double>(0, (sum, c) => sum + c.amount);

    final thisMonthCols = _collections.where((c) =>
      c.collectionDate.year == today.year && c.collectionDate.month == today.month
    ).toList();
    final thisMonthCollectedAmount = thisMonthCols.fold<double>(0, (sum, c) => sum + c.amount);

    final targetCustomersCount = _customers.where((c) => c.isTargetCustomer).length +
        _loans.where((l) => l.isTargetCustomer).map((l) => l.bondNumber).toSet().length;

    final onlineCollectionsCount = _collections.where((c) => c.isOnline).length;
    final cashCollectionsCount = _collections.where((c) => c.isCash).length;

    return {
      'totalOutstanding': totalOutstanding,
      'todayCollection': todayTotal,
      'todayAmountReceived': todayAmountReceived,
      'todayInterest': todayInterest,
      'todayDisbursed': todayDisbursed,
      'todayDocCharge': todayDocCharge,
      'activeLoansCount': active.length,
      'totalCustomersCount': _customers.length,
      'todayPartiesCount': todayCols.map((c) => c.bondNumber).toSet().length,
      'overdueCount': active.where((l) => l.endDate.isBefore(today) && l.balanceAmount > 0).length,
      // Lender Totals:
      'totalLendedPrincipal': totalLendedPrincipal,
      'thisMonthLendedPrincipal': thisMonthLendedPrincipal,
      'totalExpectedReturns': totalExpectedReturns,
      'totalCollectedAmount': totalCollectedAmount,
      'thisMonthCollectedAmount': thisMonthCollectedAmount,
      'targetCustomersCount': targetCustomersCount,
      'onlineCollectionsCount': onlineCollectionsCount,
      'cashCollectionsCount': cashCollectionsCount,
    };
  }

  Map<String, dynamic> getMonthlyWiseData({String? fy, int? month, int? year}) {
    final targetFy = fy ?? selectedFinancialYear;
    final now = DateTime.now();

    int startYear;
    int endYear;

    if (targetFy == 'All') {
      int minYear = now.year;
      int maxYear = now.year;
      for (final l in _loans) {
        if (l.startDate.year < minYear) minYear = l.startDate.year;
        if (l.startDate.year > maxYear) maxYear = l.startDate.year;
      }
      for (final c in _collections) {
        if (c.collectionDate.year < minYear) minYear = c.collectionDate.year;
        if (c.collectionDate.year > maxYear) maxYear = c.collectionDate.year;
      }
      startYear = minYear;
      endYear = maxYear >= now.year ? (now.month >= 4 ? now.year + 1 : now.year) : maxYear + 1;
      if (endYear <= startYear) endYear = startYear + 1;
    } else {
      final parts = targetFy.split('-');
      final parsedStart = parts.isNotEmpty ? int.tryParse(parts[0].replaceAll(RegExp(r'\D'), '')) : null;
      startYear = parsedStart ?? (now.month >= 4 ? now.year : now.year - 1);

      if (parts.length > 1 && parts[1].toLowerCase().contains('present')) {
        endYear = now.month >= 4 ? now.year + 1 : now.year;
        if (endYear <= startYear) endYear = startYear + 1;
      } else if (parts.length > 1 && int.tryParse(parts[1].replaceAll(RegExp(r'\D'), '')) != null) {
        endYear = int.parse(parts[1].replaceAll(RegExp(r'\D'), ''));
      } else {
        endYear = startYear + 1;
      }
    }

    const List<Map<String, dynamic>> monthMetadata = [
      {'month': 1, 'nameTa': 'ஜனவரி', 'nameEn': 'January'},
      {'month': 2, 'nameTa': 'பிப்ரவரி', 'nameEn': 'February'},
      {'month': 3, 'nameTa': 'மார்ச்', 'nameEn': 'March'},
      {'month': 4, 'nameTa': 'ஏப்ரல்', 'nameEn': 'April'},
      {'month': 5, 'nameTa': 'மே', 'nameEn': 'May'},
      {'month': 6, 'nameTa': 'ஜூன்', 'nameEn': 'June'},
      {'month': 7, 'nameTa': 'ஜூலை', 'nameEn': 'July'},
      {'month': 8, 'nameTa': 'ஆகஸ்ட்', 'nameEn': 'August'},
      {'month': 9, 'nameTa': 'செப்டம்பர்', 'nameEn': 'September'},
      {'month': 10, 'nameTa': 'அக்டோபர்', 'nameEn': 'October'},
      {'month': 11, 'nameTa': 'நவம்பர்', 'nameEn': 'November'},
      {'month': 12, 'nameTa': 'டிசம்பர்', 'nameEn': 'December'},
    ];

    Map<String, dynamic> createFiscalMonth(int m, int y) {
      final meta = monthMetadata[m - 1];
      return {
        'month': m,
        'year': y,
        'nameTa': meta['nameTa'],
        'nameEn': meta['nameEn'],
      };
    }

    // Dynamically generate all fiscal months across the target financial span
    final List<Map<String, dynamic>> fiscalMonths = [];
    for (int y = startYear; y < endYear; y++) {
      for (int m = 4; m <= 12; m++) {
        fiscalMonths.add(createFiscalMonth(m, y));
      }
      for (int m = 1; m <= 3; m++) {
        fiscalMonths.add(createFiscalMonth(m, y + 1));
      }
    }
    if (fiscalMonths.isEmpty) {
      for (int m = 4; m <= 12; m++) {
        fiscalMonths.add(createFiscalMonth(m, startYear));
      }
      for (int m = 1; m <= 3; m++) {
        fiscalMonths.add(createFiscalMonth(m, startYear + 1));
      }
    }

    final defaultMatch = fiscalMonths.firstWhere(
      (m) => m['month'] == (month ?? now.month) && (year == null || m['year'] == year),
      orElse: () => fiscalMonths.isNotEmpty ? fiscalMonths.last : {'month': now.month, 'year': now.year},
    );
    final targetMonth = month ?? defaultMatch['month'] as int;
    final targetYear = year ?? defaultMatch['year'] as int;

    final monthLoans = _loans.where((l) =>
      l.startDate.year == targetYear && l.startDate.month == targetMonth
    ).toList();

    final monthCollections = _collections.where((c) =>
      c.collectionDate.year == targetYear && c.collectionDate.month == targetMonth
    ).toList();

    final disbursedTotal = monthLoans.fold<double>(0, (sum, l) => sum + l.loanAmount);
    final collectedTotal = monthCollections.fold<double>(0, (sum, c) => sum + c.amount);
    final totalExpected = monthLoans.fold<double>(0, (sum, l) => sum + l.totalAmount);

    final totalDays = DateTime(targetYear, targetMonth + 1, 0).day;
    final Map<int, double> dayTotals = {};
    for (int d = 1; d <= totalDays; d++) {
      final s = monthCollections
          .where((c) => c.collectionDate.day == d)
          .fold<double>(0, (sum, c) => sum + c.amount);
      dayTotals[d] = s;
    }

    final monthsSummary = fiscalMonths.map((m) {
      final mLoans = _loans.where((l) =>
        l.startDate.year == m['year'] && l.startDate.month == m['month']
      ).toList();
      final mCols = _collections.where((c) =>
        c.collectionDate.year == m['year'] && c.collectionDate.month == m['month']
      ).toList();

      final mDisbursed = mLoans.fold<double>(0, (sum, l) => sum + l.loanAmount);
      final mCollected = mCols.fold<double>(0, (sum, c) => sum + c.amount);

      return {
        'month': m['month'] as int,
        'year': m['year'] as int,
        'nameTa': m['nameTa'] as String,
        'nameEn': m['nameEn'] as String,
        'disbursed': mDisbursed,
        'collected': mCollected,
        'loansCount': mLoans.length,
        'collectionsCount': mCols.length,
      };
    }).toList();

    return {
      'month': targetMonth,
      'year': targetYear,
      'financialYear': targetFy,
      'monthLoansCount': monthLoans.length,
      'disbursedTotal': disbursedTotal,
      'collectedTotal': collectedTotal,
      'totalExpected': totalExpected,
      'collectionsCount': monthCollections.length,
      'uniqueMembersCount': monthCollections.map((c) => c.bondNumber).toSet().length,
      'totalDays': totalDays,
      'dayTotals': dayTotals,
      'monthsSummary': monthsSummary,
    };
  }

  Map<String, dynamic> getYearlyWiseData({String? fy}) {
    final targetFy = fy ?? selectedFinancialYear;
    final fyLoans = _loans.where((l) =>
      targetFy == 'All' ? true : isDateInFinancialYear(l.startDate, targetFy)
    ).toList();

    final fyCollections = _collections.where((c) =>
      targetFy == 'All' ? true : isDateInFinancialYear(c.collectionDate, targetFy)
    ).toList();

    final totalDisbursed = fyLoans.fold<double>(0, (sum, l) => sum + l.loanAmount);
    final totalExpected = fyLoans.fold<double>(0, (sum, l) => sum + l.totalAmount);
    final totalInterest = fyLoans.fold<double>(0, (sum, l) => sum + l.interestAmount);
    final totalChitFee = fyLoans.fold<double>(0, (sum, l) => sum + l.chitFee);
    final totalCollected = fyCollections.fold<double>(0, (sum, c) => sum + c.amount);
    final totalBalance = fyLoans.fold<double>(0, (sum, l) => sum + l.balanceAmount);

    final recoveryRate = totalExpected > 0 ? (totalCollected / totalExpected) * 100 : 0.0;
    final activeCount = fyLoans.where((l) => l.status == 'active').length;
    final closedCount = fyLoans.where((l) => l.status == 'closed').length;

    final Map<String, Map<String, dynamic>> lineStats = {};
    for (var line in availableLines) {
      final lLoans = fyLoans.where((l) => l.lineCode == line).toList();
      final lCols = fyCollections.where((c) => c.lineCode == line).toList();
      lineStats[line] = {
        'count': lLoans.length,
        'disbursed': lLoans.fold<double>(0, (sum, l) => sum + l.loanAmount),
        'collected': lCols.fold<double>(0, (sum, c) => sum + c.amount),
        'balance': lLoans.fold<double>(0, (sum, l) => sum + l.balanceAmount),
      };
    }

    return {
      'financialYear': targetFy,
      'totalLoans': fyLoans.length,
      'activeCount': activeCount,
      'closedCount': closedCount,
      'totalDisbursed': totalDisbursed,
      'totalExpected': totalExpected,
      'totalInterest': totalInterest,
      'totalChitFee': totalChitFee,
      'totalCollected': totalCollected,
      'totalBalance': totalBalance,
      'totalAmountReceived': totalDisbursed - totalInterest + totalChitFee + totalCollected,
      'recoveryRate': recoveryRate,
      'lineStats': lineStats,
    };
  }

  List<Map<String, dynamic>> get31DayRegister(String lineCode, int month, int year) {
    final lineLoans = _loans.where((l) => lineCode == 'All' || l.lineCode == lineCode).toList();
    final monthCols = _collections.where((c) =>
      c.collectionDate.year == year && c.collectionDate.month == month
    ).toList();
    final totalDays = DateTime(year, month + 1, 0).day;

    final List<Map<String, dynamic>> rows = [];
    for (var loan in lineLoans) {
      final loanCols = monthCols.where((c) => c.bondNumber == loan.bondNumber).toList();
      final Map<int, double> dayMap = {};
      double totalMonth = 0;

      for (int d = 1; d <= totalDays; d++) {
        final daySum = loanCols
            .where((c) => c.collectionDate.day == d)
            .fold<double>(0, (sum, c) => sum + c.amount);
        dayMap[d] = daySum;
        totalMonth += daySum;
      }

      rows.add(<String, dynamic>{
        'bondNumber': loan.bondNumber,
        'customerName': loan.customerName,
        'loanAmount': loan.loanAmount,
        'totalAmount': loan.totalAmount,
        'dailyDue': loan.dailyDueAmount,
        'balanceAmount': loan.balanceAmount,
        'totalDays': totalDays,
        'dayCollections': dayMap,
        'totalMonthCollected': totalMonth,
      });
    }
    return rows;
  }
}
