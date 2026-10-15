import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../models/line_model.dart';
import '../models/customer_model.dart';
import '../models/loan_model.dart';
import '../models/collection_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('loan_management.db');
    await _ensureUsersTable(_database!);
    return _database!;
  }

  Future<void> _ensureUsersTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          name TEXT NOT NULL,
          role TEXT NOT NULL
        )
      ''');

      // Ensure only Admin user exists - purge any legacy lender accounts
      await db.delete('users', where: 'LOWER(username) != ?', whereArgs: ['admin']);

      final users = await db.query('users', where: 'LOWER(username) = ?', whereArgs: ['admin']);
      if (users.isEmpty) {
        await db.insert('users', {
          'username': 'admin',
          'password': 'admin123',
          'name': 'நிர்வாகி (Admin)',
          'role': 'admin',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      debugPrint('Error ensuring users table: $e');
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    // 2. Lines table
    await db.execute('''
      CREATE TABLE lines (
        line_code TEXT PRIMARY KEY,
        line_name TEXT NOT NULL,
        collector_name TEXT NOT NULL,
        description TEXT
      )
    ''');

    // 3. Customers table (Clean Proof Section: customer photo, proof type reference, proof front & back photos, target customer tag)
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cus_code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        father_or_spouse_name TEXT,
        phone_number TEXT NOT NULL,
        address TEXT,
        city TEXT,
        photo_path TEXT,
        proof_type TEXT,
        proof_front_path TEXT,
        proof_back_path TEXT,
        notes TEXT,
        status TEXT DEFAULT 'active',
        is_target_customer INTEGER DEFAULT 0
      )
    ''');

    // 4. Loans table (Bond number starts at A001 without hyphen, Proof Section included, finished date and target customer)
    await db.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bond_number TEXT UNIQUE NOT NULL,
        line_code TEXT NOT NULL,
        customer_id INTEGER NOT NULL,
        customer_name TEXT NOT NULL,
        father_or_spouse_name TEXT,
        phone_number TEXT NOT NULL,
        address TEXT,
        city TEXT,
        photo_path TEXT,
        proof_type TEXT,
        proof_front_path TEXT,
        proof_back_path TEXT,
        tenure_days INTEGER DEFAULT 100,
        loan_amount REAL NOT NULL,
        interest_rate REAL DEFAULT 1.0,
        interest_amount REAL NOT NULL,
        total_amount REAL NOT NULL,
        daily_due_amount REAL NOT NULL,
        chit_fee REAL DEFAULT 100,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        finished_date TEXT,
        collected_amount REAL DEFAULT 0,
        balance_amount REAL NOT NULL,
        status TEXT DEFAULT 'active',
        is_target_customer INTEGER DEFAULT 0
      )
    ''');

    // 5. Collections table (with payment_mode: Cash or Online)
    await db.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL,
        bond_number TEXT NOT NULL,
        line_code TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        collection_date TEXT NOT NULL,
        amount REAL NOT NULL,
        previous_balance REAL NOT NULL,
        current_balance REAL NOT NULL,
        receipt_type TEXT DEFAULT 'Note',
        payment_mode TEXT DEFAULT 'Cash',
        notes TEXT
      )
    ''');

    // Seed default admin user only
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123',
      'name': 'நிர்வாகி (Admin)',
      'role': 'admin',
    });

    // Seed default lines only (no hardcoded customers or loans)
    await db.insert('lines', {
      'line_code': 'A',
      'line_name': 'Line A - மதுரை டவுன் (Town Area)',
      'collector_name': 'R. Suresh (சுரேஷ்)',
      'description': 'Town Hall Rd, West Masi St',
    });
    await db.insert('lines', {
      'line_code': 'B',
      'line_name': 'Line B - செல்லூர் (Sellur)',
      'collector_name': 'K. Manikandan (மணிகண்டன்)',
      'description': 'Sellur 50 Feet Rd',
    });
    await db.insert('lines', {
      'line_code': 'C',
      'line_name': 'Line C - சிம்மக்கல் (Simmakkal)',
      'collector_name': 'M. Karthik (கார்த்திக்)',
      'description': 'Simmakkal Market',
    });
    await db.insert('lines', {
      'line_code': 'D',
      'line_name': 'Line D - திருநகர் (Thirunagar)',
      'collector_name': 'S. Vignesh (விக்னேஷ்)',
      'description': 'Thirunagar Bus Stand',
    });
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN proof_type TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN proof_front_path TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN proof_back_path TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN proof_type TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN proof_front_path TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN proof_back_path TEXT');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN is_target_customer INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN is_target_customer INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN finished_date TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE collections ADD COLUMN payment_mode TEXT DEFAULT "Cash"');
      } catch (_) {}
    }
  }

  // --- Users Operations ---
  Future<UserModel?> authenticateUser(String username, String password) async {
    try {
      final db = await database;
      final maps = await db.query(
        'users',
        where: 'LOWER(username) = ? AND password = ?',
        whereArgs: [username.trim().toLowerCase(), password.trim()],
      );
      if (maps.isNotEmpty) {
        return UserModel.fromJson(maps.first);
      }
    } catch (e) {
      debugPrint('Error authenticating user: $e');
    }
    return null;
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final db = await database;
      final maps = await db.query('users');
      return maps.map((m) => UserModel.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Error loading users: $e');
      return [];
    }
  }

  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final db = await database;
      final maps = await db.query(
        'users',
        where: 'LOWER(username) = ?',
        whereArgs: [username.trim().toLowerCase()],
      );
      if (maps.isNotEmpty) {
        return UserModel.fromJson(maps.first);
      }
    } catch (e) {
      debugPrint('Error getting user by username: $e');
    }
    return null;
  }

  Future<bool> resetUserPassword(String username, String newPassword) async {
    try {
      final db = await database;
      final u = username.trim().toLowerCase();
      final p = newPassword.trim();
      if (u != 'admin') return false;

      final count = await db.update(
        'users',
        {'password': p},
        where: 'LOWER(username) = ?',
        whereArgs: [u],
      );

      if (count > 0) {
        return true;
      }

      // If admin wasn't in DB yet, insert admin with the new password
      final id = await db.insert('users', {
        'username': 'admin',
        'password': p,
        'name': 'நிர்வாகி (Admin)',
        'role': 'admin',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return id > 0;
    } catch (e) {
      debugPrint('Error resetting user password: $e');
      return false;
    }
  }

  // --- Lines Operations ---
  Future<List<LineModel>> getAllLines() async {
    try {
      final db = await database;
      final maps = await db.query('lines', orderBy: 'line_code ASC');
      return maps.map((m) => LineModel.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Error loading lines: $e');
      return [];
    }
  }

  Future<int> insertLine(LineModel line) async {
    try {
      final db = await database;
      return await db.insert('lines', line.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Error inserting line: $e');
      return -1;
    }
  }

  Future<int> deleteLine(String lineCode) async {
    try {
      final db = await database;
      return await db.delete('lines', where: 'line_code = ?', whereArgs: [lineCode]);
    } catch (e) {
      debugPrint('Error deleting line: $e');
      return -1;
    }
  }

  // --- Financial Years Operations ---
  Future<List<String>> getAllFinancialYears() async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS financial_years (
          year_name TEXT PRIMARY KEY
        )
      ''');
      final maps = await db.query('financial_years', orderBy: 'year_name ASC');
      return maps.map((m) => m['year_name'] as String).toList();
    } catch (e) {
      debugPrint('Error loading financial years: $e');
      return [];
    }
  }

  Future<int> insertFinancialYear(String year) async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS financial_years (
          year_name TEXT PRIMARY KEY
        )
      ''');
      return await db.insert(
        'financial_years',
        {'year_name': year},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting financial year: $e');
      return -1;
    }
  }

  Future<int> deleteFinancialYear(String year) async {
    try {
      final db = await database;
      return await db.delete(
        'financial_years',
        where: 'year_name = ?',
        whereArgs: [year],
      );
    } catch (e) {
      debugPrint('Error deleting financial year: $e');
      return -1;
    }
  }

  // --- Customers Operations ---
  Future<List<CustomerModel>> getAllCustomers() async {
    try {
      final db = await database;
      final maps = await db.query('customers', orderBy: 'id DESC');
      return maps.map((m) => CustomerModel(
        id: m['id'] as int,
        cusCode: m['cus_code'] as String? ?? '',
        name: m['name'] as String? ?? '',
        fatherOrSpouseName: m['father_or_spouse_name'] as String?,
        phoneNumber: m['phone_number'] as String? ?? '',
        address: m['address'] as String?,
        city: m['city'] as String? ?? 'Madurai',
        photoPath: m['photo_path'] as String?,
        proofType: m['proof_type'] as String?,
        proofFrontPath: m['proof_front_path'] as String?,
        proofBackPath: m['proof_back_path'] as String?,
        notes: m['notes'] as String?,
        status: m['status'] as String? ?? 'active',
        isTargetCustomer: (m['is_target_customer'] as int? ?? 0) == 1,
      )).toList();
    } catch (e) {
      debugPrint('Error loading customers: $e');
      return [];
    }
  }

  Future<int> insertCustomer(CustomerModel customer) async {
    try {
      final db = await database;
      return await db.insert('customers', customer.toDbMap());
    } catch (e) {
      debugPrint('Error inserting customer: $e');
      return -1;
    }
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    try {
      final db = await database;
      return await db.update(
        'customers',
        customer.toDbMap(),
        where: 'id = ?',
        whereArgs: [customer.id],
      );
    } catch (e) {
      debugPrint('Error updating customer: $e');
      return -1;
    }
  }

  Future<int> toggleCustomerTargetStatus(int customerId, bool isTarget) async {
    try {
      final db = await database;
      await db.update(
        'loans',
        {'is_target_customer': isTarget ? 1 : 0},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      return await db.update(
        'customers',
        {'is_target_customer': isTarget ? 1 : 0},
        where: 'id = ?',
        whereArgs: [customerId],
      );
    } catch (e) {
      debugPrint('Error toggling target customer: $e');
      return -1;
    }
  }

  Future<int> deleteCustomer(int id) async {
    try {
      final db = await database;
      return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      return -1;
    }
  }

  // --- Loans Operations ---
  Future<List<LoanModel>> getAllLoans() async {
    try {
      final db = await database;
      final maps = await db.query('loans', orderBy: 'id DESC');
      return maps.map((m) => LoanModel(
        id: m['id'] as int,
        bondNumber: m['bond_number'] as String? ?? '',
        lineCode: m['line_code'] as String? ?? 'A',
        customerId: m['customer_id'] as int? ?? 0,
        customerName: m['customer_name'] as String? ?? '',
        fatherOrSpouseName: m['father_or_spouse_name'] as String?,
        phoneNumber: m['phone_number'] as String? ?? '',
        address: m['address'] as String?,
        city: m['city'] as String?,
        photoPath: m['photo_path'] as String?,
        proofType: m['proof_type'] as String?,
        proofFrontPath: m['proof_front_path'] as String?,
        proofBackPath: m['proof_back_path'] as String?,
        tenureDays: m['tenure_days'] as int? ?? 100,
        loanAmount: (m['loan_amount'] as num?)?.toDouble() ?? 0.0,
        interestRate: (m['interest_rate'] as num?)?.toDouble() ?? 1.0,
        interestAmount: (m['interest_amount'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0.0,
        dailyDueAmount: (m['daily_due_amount'] as num?)?.toDouble() ?? 0.0,
        chitFee: (m['chit_fee'] as num?)?.toDouble() ?? 100.0,
        startDate: DateTime.tryParse(m['start_date'] as String? ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(m['end_date'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 100)),
        finishedDate: m['finished_date'] != null ? DateTime.tryParse(m['finished_date'] as String) : null,
        collectedAmount: (m['collected_amount'] as num?)?.toDouble() ?? 0.0,
        balanceAmount: (m['balance_amount'] as num?)?.toDouble() ?? 0.0,
        status: m['status'] as String? ?? 'active',
        isTargetCustomer: (m['is_target_customer'] as int? ?? 0) == 1,
      )).toList();
    } catch (e) {
      debugPrint('Error loading loans: $e');
      return [];
    }
  }

  Future<int> insertLoan(LoanModel loan) async {
    try {
      final db = await database;
      return await db.insert('loans', loan.toDbMap());
    } catch (e) {
      debugPrint('Error inserting loan: $e');
      return -1;
    }
  }

  Future<int> updateLoan(LoanModel loan) async {
    try {
      final db = await database;
      return await db.update(
        'loans',
        loan.toDbMap(),
        where: 'id = ?',
        whereArgs: [loan.id],
      );
    } catch (e) {
      debugPrint('Error updating loan: $e');
      return -1;
    }
  }

  Future<int> deleteLoan(int id, {String? bondNumber}) async {
    try {
      final db = await database;
      // Cascade delete collections
      if (bondNumber != null && bondNumber.isNotEmpty) {
        await db.delete('collections', where: 'loan_id = ? OR bond_number = ?', whereArgs: [id, bondNumber]);
        return await db.delete('loans', where: 'id = ? OR bond_number = ?', whereArgs: [id, bondNumber]);
      } else {
        await db.delete('collections', where: 'loan_id = ?', whereArgs: [id]);
        return await db.delete('loans', where: 'id = ?', whereArgs: [id]);
      }
    } catch (e) {
      debugPrint('Error deleting loan: $e');
      return -1;
    }
  }

  // --- Collections Operations ---
  Future<List<CollectionModel>> getAllCollections() async {
    try {
      final db = await database;
      final maps = await db.query('collections', orderBy: 'id DESC');
      return maps.map((m) => CollectionModel(
        id: m['id'] as int,
        loanId: m['loan_id'] as int? ?? 0,
        bondNumber: m['bond_number'] as String? ?? '',
        lineCode: m['line_code'] as String? ?? 'A',
        customerName: m['customer_name'] as String? ?? '',
        collectionDate: DateTime.tryParse(m['collection_date'] as String? ?? '') ?? DateTime.now(),
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        previousBalance: (m['previous_balance'] as num?)?.toDouble() ?? 0.0,
        currentBalance: (m['current_balance'] as num?)?.toDouble() ?? 0.0,
        receiptType: m['receipt_type'] as String? ?? 'Note',
        paymentMode: m['payment_mode'] as String? ?? 'Cash',
        notes: m['notes'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('Error loading collections: $e');
      return [];
    }
  }

  Future<int> insertCollection(CollectionModel col) async {
    try {
      final db = await database;
      return await db.insert('collections', col.toDbMap());
    } catch (e) {
      debugPrint('Error inserting collection: $e');
      return -1;
    }
  }

  Future<int> updateCollection(CollectionModel col) async {
    try {
      final db = await database;
      return await db.update(
        'collections',
        {
          'amount': col.amount,
          'previous_balance': col.previousBalance,
          'current_balance': col.currentBalance,
          'receipt_type': col.receiptType,
          'payment_mode': col.paymentMode,
          'notes': col.notes,
        },
        where: 'id = ?',
        whereArgs: [col.id],
      );
    } catch (e) {
      debugPrint('Error updating collection: $e');
      return -1;
    }
  }

  Future<int> deleteCollection(int id) async {
    try {
      final db = await database;
      return await db.delete('collections', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error deleting collection: $e');
      return -1;
    }
  }

  Future<String?> getSetting(String key) async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      final res = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
      if (res.isNotEmpty) {
        return res.first['value'] as String?;
      }
    } catch (e) {
      debugPrint('Error getting setting $key: $e');
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      await db.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error setting $key: $e');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
