// lib/astro_queue/services/wallet_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_learning/astro_queue/api_service.dart';

// ─────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────

class WalletBalance {
  final double balance;
  final double availableBalance;
  final double totalCredited;
  final double totalSpent;

  WalletBalance({
    required this.balance,
    required this.availableBalance,
    required this.totalCredited,
    required this.totalSpent,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
        balance: (json['balance'] ?? 0).toDouble(),
        availableBalance: (json['availableBalance'] ?? 0).toDouble(),
        totalCredited: (json['totalCredited'] ?? 0).toDouble(),
        totalSpent: (json['totalSpent'] ?? 0).toDouble(),
      );

  WalletBalance copyWith({
    double? balance,
    double? availableBalance,
    double? totalCredited,
    double? totalSpent,
  }) {
    return WalletBalance(
      balance: balance ?? this.balance,
      availableBalance: availableBalance ?? this.availableBalance,
      totalCredited: totalCredited ?? this.totalCredited,
      totalSpent: totalSpent ?? this.totalSpent,
    );
  }
}

class WalletPackage {
  final int? id;
  final String name;
  final String description;
  final String packageType; // CURRENCY | MINUTES
  final String mode; // AUDIO | VIDEO | CHAT | ALL
  final double priceAmount;
  final int? includedMinutes;
  final double? bonusCredits;
  final double totalCreditAmount;
  final bool isActive;
  final int displayOrder;

  WalletPackage({
    this.id,
    required this.name,
    required this.description,
    required this.packageType,
    required this.mode,
    required this.priceAmount,
    this.includedMinutes,
    this.bonusCredits,
    required this.totalCreditAmount,
    required this.isActive,
    required this.displayOrder,
  });

  factory WalletPackage.fromJson(Map<String, dynamic> json) => WalletPackage(
        id: json['id'] as int?,
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        packageType: json['packageType']?.toString() ?? 'CURRENCY',
        mode: json['mode']?.toString() ?? 'ALL',
        priceAmount: (json['priceAmount'] ?? 0).toDouble(),
        includedMinutes: json['includedMinutes'] as int?,
        bonusCredits: json['bonusCredits'] != null
            ? (json['bonusCredits']).toDouble()
            : null,
        totalCreditAmount:
            (json['totalCreditAmount'] ?? json['priceAmount'] ?? 0).toDouble(),
        isActive: json['isActive'] ?? json['active'] ?? true,
        displayOrder: json['displayOrder'] ?? 0,
      );
}

// ── SessionDuration — maps GET /api/wallet/durations ──────────────────────

class SessionDuration {
  final int id;
  final int durationMinutes;
  final String label;
  final String description;

  SessionDuration({
    required this.id,
    required this.durationMinutes,
    required this.label,
    required this.description,
  });

  factory SessionDuration.fromJson(Map<String, dynamic> json) =>
      SessionDuration(
        id: json['id'] ?? 0,
        durationMinutes: json['durationMinutes'] ?? 0,
        label: json['label']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );
}

class ThresholdCheckResult {
  final bool sufficient;
  final double walletBalance;
  final double ratePerMinute;
  final int durationMinutes;
  final double requiredAmount;
  final double shortfall;
  final double estimatedRemainingAfterSession;
  final String message;

  ThresholdCheckResult({
    required this.sufficient,
    required this.walletBalance,
    required this.ratePerMinute,
    required this.durationMinutes,
    required this.requiredAmount,
    required this.shortfall,
    required this.estimatedRemainingAfterSession,
    required this.message,
  });

  factory ThresholdCheckResult.fromJson(Map<String, dynamic> json) =>
      ThresholdCheckResult(
        sufficient: json['sufficient'] ?? false,
        walletBalance: (json['walletBalance'] ?? 0).toDouble(),
        ratePerMinute: (json['ratePerMinute'] ?? 0).toDouble(),
        durationMinutes: json['durationMinutes'] ?? 0,
        requiredAmount: (json['requiredAmount'] ?? 0).toDouble(),
        shortfall: (json['shortfall'] ?? 0).toDouble(),
        estimatedRemainingAfterSession:
            (json['estimatedRemainingAfterSession'] ?? 0).toDouble(),
        message: json['message'] ?? '',
      );
}

class WalletTransaction {
  final int id;
  final String transactionType;
  final double amount;
  final double balanceAfter;
  final String description;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] ?? 0,
        transactionType: json['transactionType'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        balanceAfter: (json['balanceAfter'] ?? 0).toDouble(),
        description: json['description'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );

  bool get isCredit => transactionType.startsWith('CREDIT');

  IconData get icon {
    switch (transactionType) {
      case 'CREDIT_TOPUP':
        return Icons.add_circle_outline;
      case 'CREDIT_REFUND':
        return Icons.replay;
      case 'CREDIT_BONUS':
        return Icons.card_giftcard;
      case 'DEBIT_SESSION':
        return Icons.videocam_outlined;
      default:
        return Icons.swap_horiz;
    }
  }

  Color get color {
    return isCredit ? const Color(0xFF00C896) : const Color(0xFFFF6B6B);
  }

  String get label {
    switch (transactionType) {
      case 'CREDIT_TOPUP':
        return 'Wallet Top-Up';
      case 'CREDIT_REFUND':
        return 'Refund';
      case 'CREDIT_BONUS':
        return 'Bonus Credit';
      case 'DEBIT_SESSION':
        return 'Session Charge';
      default:
        return transactionType;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────

class WalletService {
  static const String _base = ApiService.baseUrl;

  // GET /wallet/balance/{userId}
  static Future<WalletBalance?> getBalance(int userId) async {
    try {
      final res =
          await http.get(Uri.parse('$_base/api/wallet/balance/$userId'));
      if (res.statusCode == 200) {
        return WalletBalance.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('WalletService.getBalance error: $e');
    }
    return null;
  }

  // GET /api/wallet/durations
  // Returns bookable session durations (10 / 30 / 60 min) seeded in backend DB.
  static Future<List<SessionDuration>> getDurations() async {
    try {
      final res = await http.get(Uri.parse('$_base/api/wallet/durations'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list
            .map((e) => SessionDuration.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('WalletService.getDurations: status ${res.statusCode}');
    } catch (e) {
      debugPrint('WalletService.getDurations error: $e');
    }
    return [];
  }

  // POST /wallet/check-threshold
  static Future<ThresholdCheckResult?> checkThreshold({
    required int customerId,
    required int practitionerId,
    required String sessionType,
    required int durationMinutes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/api/wallet/check-threshold'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customerId': customerId,
          'practitionerId': practitionerId,
          'sessionType': sessionType,
          'durationMinutes': durationMinutes,
        }),
      );
      if (res.statusCode == 200) {
        return ThresholdCheckResult.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('WalletService.checkThreshold error: $e');
    }
    return null;
  }

  // POST /wallet/topup/initiate
  static Future<Map<String, dynamic>> initiateTopUp({
    required int userId,
    required double amount,
  }) async {
    try {
      final url = Uri.parse('$_base/api/wallet/topup/initiate');

      debugPrint("🚀 INITIATE TOPUP API CALL");
      debugPrint("URL: $url");
      debugPrint("Request Body: userId=$userId, amount=$amount");

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "userId": userId,
          "amount": amount,
        }),
      );

      debugPrint("Response Status: ${res.statusCode}");
      debugPrint("Response Body: ${res.body}");

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);

        debugPrint("✅ TOPUP INITIATED SUCCESS");
        debugPrint("OrderId: ${data['gatewayOrderId']}");
        debugPrint("KeyId: ${data['razorpayKeyId']}");
        debugPrint("AmountInPaise: ${data['amountInPaise']}");

        return data;
      } else {
        throw Exception(
          "TopUp initiate failed. StatusCode=${res.statusCode}, Body=${res.body}",
        );
      }
    } catch (e) {
      debugPrint("❌ WalletService.initiateTopUp error: $e");
      rethrow;
    }
  }

// private String gatewayOrderId;
//     private String gatewayPaymentId;
//     private String gatewaySignature;
//     private String gatewayResponse;
  static Future<bool> confirmTopUp({
    required String gatewayOrderId,
    required String gatewayPaymentId,
    required String gatewaySignature,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/api/wallet/topup/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'gatewayOrderId': gatewayOrderId,
          'gatewayPaymentId': gatewayPaymentId,
          'gatewaySignature': gatewaySignature,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint("confirmTopUp error $e");
    }

    return false;
  }

  // static Future<String> checkTopUpStatus(String requestId) async {
  //   try {
  //     final url = Uri.parse('$_base/api/wallet/topup/status/$requestId');

  //     debugPrint("[StatusCheck] Calling: $url");

  //     final res = await http.get(url);

  //     debugPrint("[StatusCheck] Status: ${res.statusCode} | Body: ${res.body}");

  //     if (res.statusCode == 200) {
  //       final json = jsonDecode(res.body);
  //       return json['status']?.toString() ?? 'UNKNOWN';
  //     } else {
  //       debugPrint("[StatusCheck] Failed: ${res.statusCode} - ${res.body}");
  //       return 'FAILED';
  //     }
  //   } catch (e) {
  //     debugPrint("[StatusCheck] Exception: $e");
  //     return 'ERROR';
  //   }
  // }

  // POST /wallet/deduct-minute  — called by frontend timer every 60 sec
  static Future<Map<String, dynamic>?> deductMinute({
    required int customerId,
    required int sessionId,
    required double ratePerMinute,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/api/wallet/deduct-minute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customerId': customerId,
          'sessionId': sessionId,
          'ratePerMinute': ratePerMinute,
        }),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint('WalletService.deductMinute error: $e');
    }
    return null;
  }

  // GET /wallet/transactions/{userId}
  static Future<List<WalletTransaction>> getTransactions(int userId,
      {int page = 0, int size = 20}) async {
    try {
      final res = await http.get(
        Uri.parse(
            '$_base/api/wallet/transactions/$userId?page=$page&size=$size'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['transactions'] as List<dynamic>? ?? [];
        return list.map((e) => WalletTransaction.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('WalletService.getTransactions error: $e');
    }
    return [];
  }

  // ── GET /wallet/packages ─────────────────────────────────────────────────
  // Returns ALL active packages from DB, sorted by displayOrder.
  // Backend endpoint: GET /wallet/packages?type=CURRENCY  (or MINUTES, or no filter)
  static Future<List<WalletPackage>> getPackages({String? type}) async {
    try {
      final query = type != null ? '?type=$type' : '';
      final res = await http.get(
        Uri.parse('$_base/api/wallet/packages$query'),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final pkgs = list
            .map((e) => WalletPackage.fromJson(e as Map<String, dynamic>))
            .where((p) => p.isActive)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        return pkgs;
      }
      debugPrint('WalletService.getPackages: status ${res.statusCode}');
    } catch (e) {
      debugPrint('WalletService.getPackages error: $e');
    }
    return [];
  }

  // Convenience helpers used by WalletScreen tabs
  static Future<List<WalletPackage>> getCurrencyPackages() =>
      getPackages(type: 'CURRENCY');

  static Future<List<WalletPackage>> getMinutePackages() =>
      getPackages(type: 'MINUTES');
}
