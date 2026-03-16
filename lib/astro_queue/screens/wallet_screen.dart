import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/model/practioner_profile_response.dart';
import 'package:flutter_learning/astro_queue/model/session_pack.dart';
import 'package:flutter_learning/astro_queue/services/wallet_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class WalletScreen extends StatefulWidget {
  final ConsultationSessionResponse? consultationSessionResponse;
  final int userId;
  final PractionerProfileResponse? practitioner;
  final VoidCallback? onTopUpSuccess;
  const WalletScreen(
      {super.key,
      required this.userId,
      this.practitioner,
      this.consultationSessionResponse,
      this.onTopUpSuccess});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  WalletBalance? _balance;
  List<WalletTransaction> _transactions = [];
  List<WalletPackage> _currencyPackages = [];
  List<WalletPackage> _minutePackages = [];
  bool _isLoading = true;
  bool _isPackagesLoading = false;
  bool _packagesError = false;
  bool _isTopUpLoading = false;
  String? _currentRequestId;

  late TabController _tabController;
  late Razorpay _razorpay;
  String? _currentOrderId;
  List<PractionerProfileResponse> _practitioners = [];
  bool _isUsersLoading = true;
  late int _amountInPaise; // stores the amount in paise for Razorpay
  late String _razorpayKeyId; // stores your Razorpay Key ID
  TextEditingController _amountCtrl = TextEditingController();

  bool _loading = false;
  bool _checkoutOpening = false;
  bool _checkoutInProgress = false;

  @override
  void initState() {
    super.initState();
    final showSessionPacks = _hasSessionPacks();
    _tabController = TabController(
      length: showSessionPacks ? 2 : 1,
      vsync: this,
    );

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _amountCtrl = TextEditingController();

    _loadAll();
    _loadAllPractitioners();
  }

  bool _hasSessionPacks() {
    final session = widget.consultationSessionResponse;
    if (session == null) return false;

    return (session.audioRatePerMin ?? 0) > 0 ||
        (session.videoRatePerMin ?? 0) > 0 ||
        (session.chatRatePerMin ?? 0) > 0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint(
        "╔════════════════════════════════════════════════════════════╗");
    debugPrint(
        "║               PAYMENT SUCCESS CALLBACK RECEIVED            ║");
    debugPrint(
        "╚════════════════════════════════════════════════════════════╝");
    debugPrint("Order ID     : ${response.orderId}");
    debugPrint("Payment ID   : ${response.paymentId}");
    debugPrint("Signature    : ${response.signature}");
    debugPrint("Stored order : $_currentOrderId");

    if (_currentOrderId == null ||
        response.paymentId == null ||
        response.signature == null) {
      debugPrint("[ERROR] Missing critical payment data");
      _showSnack("Payment verification failed - missing data", isError: true);
      _cleanupPayment(checkServer: true);
      return;
    }

    WalletService.confirmTopUp(
      gatewayOrderId: _currentOrderId!,
      gatewayPaymentId: response.paymentId!,
      gatewaySignature: response.signature!,
    ).then((success) {
      debugPrint("[ConfirmTopUp] Server response: success = $success");
      if (success) {
        _showSnack("Wallet topped up successfully!", isError: false);
        _loadAll();

        // NEW: Auto-return to previous screen (ChatScreen) after success
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
              Navigator.pop(context); // ← automatically go back
            }
          });
        }
      } else {
        _showSnack("Server could not verify payment", isError: true);
      }
    }).catchError((e) {
      debugPrint("[ConfirmTopUp] EXCEPTION: $e");
      _showSnack("Payment confirmation failed", isError: true);
    }).whenComplete(() {
      _cleanupPayment();
    });
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint(
        "╔════════════════════════════════════════════════════════════╗");
    debugPrint(
        "║                PAYMENT ERROR CALLBACK RECEIVED             ║");
    debugPrint(
        "╚════════════════════════════════════════════════════════════╝");
    debugPrint("Code    : ${response.code}");
    debugPrint("Message : ${response.message}");

    _showSnack("Payment failed: ${response.message ?? "Unknown error"}",
        isError: true);
    _cleanupPayment();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("[External Wallet] Selected: ${response.walletName}");
  }

  void _cleanupPayment({bool checkServer = false}) {
    debugPrint("[Cleanup] Resetting payment state (checkServer=$checkServer)");

    if (checkServer && _currentRequestId != null) {
      debugPrint(
          "[Fallback] Checking server status for requestId: $_currentRequestId");
    }

    _currentOrderId = null;
    _currentRequestId = null;
    _razorpayKeyId = '';
    _amountInPaise = 0;

    if (mounted) {
      setState(() => _checkoutInProgress = false);
    }
  }

  Future<void> _loadAllPractitioners() async {
    setState(() => _isUsersLoading = true);
    try {
      final users = await ApiService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _practitioners = users;
        _isUsersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUsersLoading = false);
      _showSnack("Failed to load practitioners", isError: true);
    }
  }

  List<WalletPackage> _generatePractitionerSessionPacks() {
    final session = widget.consultationSessionResponse;
    if (session == null) return [];

    final String? sessionTypeUpper = session.sessionType?.toUpperCase();
    if (sessionTypeUpper == null || sessionTypeUpper.isEmpty) return [];

    // Only generate packs for the exact session type
    double ratePerMin = 0;
    String mode = "";

    switch (sessionTypeUpper) {
      case "CHAT":
        ratePerMin = session.chatRatePerMin ?? 0;
        mode = "CHAT";
        break;
      case "AUDIO":
        ratePerMin = session.audioRatePerMin ?? 0;
        mode = "AUDIO";
        break;
      case "VIDEO":
        ratePerMin = session.videoRatePerMin ?? 0;
        mode = "VIDEO";
        break;
      default:
        return []; // unknown type → no packs
    }

    if (ratePerMin <= 0) return []; // no valid rate → hide tab

    final sessionPacks = generateSessionPacksForMode(session, mode, ratePerMin);

    return sessionPacks.map((e) {
      return WalletPackage(
        id: 0,
        name: "${e.minutes} Min • $mode",
        description:
            "${session.consultantName ?? 'Practitioner'} • ₹${e.ratePerMinute}/min",
        priceAmount: e.totalPrice,
        totalCreditAmount: e.totalPrice,
        bonusCredits: 0,
        includedMinutes: e.minutes,
        mode: mode,
        packageType: "MINUTES",
        isActive: true,
        displayOrder: 0,
      );
    }).toList();
  }

  List<SessionPack> generateSessionPacksForMode(
    ConsultationSessionResponse practitioner,
    String mode,
    double ratePerMinute,
  ) {
    const minutesOptions = [10, 20, 30, 60];
    List<SessionPack> packs = [];

    for (var m in minutesOptions) {
      packs.add(SessionPack(
        minutes: m,
        ratePerMinute: ratePerMinute,
        mode: mode,
        practitionerName: practitioner.consultantName ?? "",
      ));
    }

    return packs;
  }

  Future<void> _loadAll() async {
    debugPrint("[LoadAll] Starting wallet refresh");
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        WalletService.getBalance(widget.userId),
        WalletService.getTransactions(widget.userId),
        WalletService.getCurrencyPackages(),
      ]);

      if (!mounted) return;

      setState(() {
        _balance = results[0] as WalletBalance?;
        _transactions = results[1] as List<WalletTransaction>;
        _currencyPackages = results[2] as List<WalletPackage>;
        _isLoading = false;
      });
      debugPrint("[LoadAll] Success");
    } catch (e) {
      debugPrint("[LoadAll] ERROR: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack("Failed to load wallet", isError: true);
      }
    }
  }

  Future<void> _retryPackages() async {
    setState(() {
      _isPackagesLoading = true;
      _packagesError = false;
    });

    try {
      final currency = await WalletService.getCurrencyPackages();

      /// Regenerate session packs from practitioner rates
      List<WalletPackage> minutePackages = [];

      if (widget.practitioner != null) {
        final sessionPacks =
            generateSessionPacks(widget.consultationSessionResponse!);

        minutePackages = sessionPacks.map((e) {
          return WalletPackage(
            id: 0,
            name: "${e.minutes} Min • ${e.mode}",
            description:
                "${widget.practitioner?.userName} • ₹${e.ratePerMinute}/min",
            priceAmount: e.totalPrice,
            totalCreditAmount: e.totalPrice,
            bonusCredits: 0,
            includedMinutes: e.minutes,
            mode: e.mode,
            packageType: "MINUTES",
            isActive: true,
            displayOrder: 0,
          );
        }).toList();
      }

      if (!mounted) return;

      setState(() {
        _currencyPackages = currency;
        _minutePackages = minutePackages;
        _packagesError = currency.isEmpty && minutePackages.isEmpty;
        _isPackagesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isPackagesLoading = false;
        _packagesError = true;
      });
    }
  }

  Future<void> _doTopUp(WalletPackage pkg) async {
    debugPrint("[TopUp] Starting → ${pkg.name} ₹${pkg.priceAmount}");

    if (_isTopUpLoading || _checkoutInProgress) {
      debugPrint("[TopUp] Already in progress → skipped");
      return;
    }

    setState(() => _isTopUpLoading = true);

    try {
      final data = await WalletService.initiateTopUp(
        userId: widget.userId,
        amount: pkg.priceAmount,
      );

      if (data == null || data['gatewayOrderId'] == null) {
        throw Exception("Invalid top-up response");
      }

      _currentOrderId = data['gatewayOrderId'] as String;
      _currentRequestId = data['topUpRequestId']?.toString();
      _razorpayKeyId = data['razorpayKeyId'] as String;
      _amountInPaise = (data['amountInPaise'] as num).toInt();

      debugPrint("[TopUp] INIT OK");
      debugPrint("  Order ID     : $_currentOrderId");
      debugPrint("  Request ID   : $_currentRequestId");
      debugPrint("  Key          : $_razorpayKeyId");
      debugPrint("  Amount       : $_amountInPaise paise");

      _openCheckout();
    } catch (e) {
      debugPrint("[TopUp] FAILED: $e");
      _showSnack("Failed to start payment", isError: true);
    } finally {
      if (mounted) setState(() => _isTopUpLoading = false);
    }
  }

  void _openCheckout() {
    debugPrint("[Checkout] Attempting to open Razorpay");

    if (_checkoutInProgress) return;

    if (_currentOrderId == null || _razorpayKeyId.isEmpty) {
      _showSnack("Payment setup error", isError: true);
      return;
    }

    setState(() => _checkoutInProgress = true);

    final options = {
      'key': _razorpayKeyId,
      'amount': _amountInPaise,
      'order_id': _currentOrderId,
      'name': 'Aumraa Wallet',
      'description': 'Wallet Top-Up',
      'timeout': 300,
      'prefill': {'contact': '96666961236', 'email': 'gouni@gmail.com'},
      'redirect': true,
      'handleback': false,
      'modal': {'escape': false},
    };

    try {
      _razorpay.open(options);
      debugPrint("[Checkout] open() called successfully");

      // Timeout fallback — if no callback after 60 seconds
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted && _checkoutInProgress) {
          debugPrint("[Timeout] No callback after 60s → checking server");
          _cleanupPayment(checkServer: true);
          _showSnack("Checking payment status with server...", isError: false);
        }
      });
    } catch (e) {
      debugPrint("[Checkout] open() exception: $e");
      _showSnack("Failed to open payment", isError: true);
      _cleanupPayment();
    }
  }

  // ── UI Helpers ──────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor:
            isError ? const Color(0xFFFF6B6B) : const Color(0xFF00C896),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _confirmPackage(WalletPackage pkg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmSheet(
        pkg: pkg,
        currentBalance: _balance?.balance ?? 0,
        onConfirm: () {
          Navigator.pop(context);
          _doTopUp(pkg);
        },
      ),
    );
  }

  List<SessionPack> generateSessionPacks(
      ConsultationSessionResponse practitioner) {
    const minutesOptions = [10, 20, 30, 60];
    List<SessionPack> packs = [];

    // Determine which modes are supported
    final supportedModes = <String>[];
    if (practitioner.sessionType?.toUpperCase() == "AUDIO" &&
        (practitioner.audioRatePerMin ?? 0) > 0) {
      supportedModes.add("AUDIO");
    }
    if (practitioner.sessionType?.toUpperCase() == "VIDEO" &&
        (practitioner.videoRatePerMin ?? 0) > 0) {
      supportedModes.add("VIDEO");
    }
    if (practitioner.sessionType?.toUpperCase() == "CHAT" &&
        (practitioner.chatRatePerMin ?? 0) > 0) {
      supportedModes.add("CHAT");
    }

    for (var m in minutesOptions) {
      for (var mode in supportedModes) {
        double rate = 0;
        if (mode == "AUDIO") rate = practitioner.audioRatePerMin!;
        if (mode == "VIDEO") rate = practitioner.videoRatePerMin!;
        if (mode == "CHAT") rate = practitioner.chatRatePerMin!;

        packs.add(SessionPack(
          minutes: m,
          ratePerMinute: rate,
          mode: mode,
          practitionerName: practitioner.consultantName ?? "",
        ));
      }
    }

    return packs;
  }

  @override
  Widget build(BuildContext context) {
    final showSessionPacks = _hasSessionPacks();

    return PopScope(
      canPop: !_checkoutInProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _checkoutInProgress) {
          _showSnack(
            "DO NOT PRESS BACK!\nPlease wait until payment completes.",
            isError: true,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9500)))
            : RefreshIndicator(
                onRefresh: _loadAll,
                color: const Color(0xFFFF9500),
                child: CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(child: _buildBalanceCard()),
                    SliverToBoxAdapter(
                        child: _buildPackageSection(showSessionPacks)),
                    SliverToBoxAdapter(child: _buildTransactionSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF0D1117),
      foregroundColor: Colors.white,
      title: const Text(
        'Aumraa Wallet',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white70),
          onPressed: _loadAll,
        ),
      ],
      pinned: true,
      expandedHeight: 0,
    );
  }

  Widget _buildBalanceCard() {
    final bal = _balance?.balance ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFF6B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9500).withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'Available Balance',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₹${bal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat('Total Added',
                  '₹${(_balance?.totalCredited ?? 0).toStringAsFixed(0)}'),
              const SizedBox(width: 24),
              _miniStat('Total Spent',
                  '₹${(_balance?.totalSpent ?? 0).toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildPackageSection(bool showSessionPacks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Text(
            'Recharge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFFFF9500),
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            padding: const EdgeInsets.all(4),
            tabs: showSessionPacks
                ? const [
                    Tab(text: '💰  Top-Up'),
                    Tab(text: '⏱  Session Packs'),
                  ]
                : const [
                    Tab(text: '💰  Top-Up'),
                  ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 430,
          child: TabBarView(
            controller: _tabController,
            children: showSessionPacks
                ? [
                    _buildCurrencyGrid(),
                    _buildMinutePackages(),
                  ]
                : [
                    _buildCurrencyGrid(),
                  ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyGrid() {
    if (_isPackagesLoading) return _pkgLoading();

    if (_currencyPackages.isEmpty) {
      return _pkgEmpty("No top-up packs available");
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
        ),
        itemCount: _currencyPackages.length,
        itemBuilder: (_, i) {
          final pkg = _currencyPackages[i];
          return _CurrencyPackageCard(
            pkg: pkg,
            isLoading: _isTopUpLoading,
            onTap: () => _confirmPackage(pkg),
          );
        },
      ),
    );
  }

  Widget _buildMinutePackages() {
    if (_isUsersLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF9500)),
        ),
      );
    }
    final allMinutePackages = _generatePractitionerSessionPacks();
    if (allMinutePackages.isEmpty) {
      return _pkgEmpty("No session packs available");
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: allMinutePackages.length,
        itemBuilder: (context, index) {
          final pkg = allMinutePackages[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MinutePackageCard(
              pkg: pkg,
              isLoading: _isTopUpLoading,
              onTap: () => _confirmPackage(pkg),
            ),
          );
        },
      ),
    );
  }

  Widget _pkgLoading() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF9500),
            strokeWidth: 2,
          ),
        ),
      );

  Widget _pkgEmpty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined,
                color: Colors.white12, size: 48),
            const SizedBox(height: 12),
            Text(msg,
                style: const TextStyle(color: Colors.white24, fontSize: 14)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _retryPackages,
              icon:
                  const Icon(Icons.refresh, size: 16, color: Color(0xFFFF9500)),
              label: const Text('Retry',
                  style: TextStyle(color: Color(0xFFFF9500))),
            ),
          ],
        ),
      );

  // ── Transaction Section ──────────────────────────────────────────────────────

  Widget _buildTransactionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaction History',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                '${_transactions.length} records',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        if (_transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      color: Colors.white12, size: 56),
                  SizedBox(height: 12),
                  Text('No transactions yet',
                      style: TextStyle(color: Colors.white24, fontSize: 15)),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _transactions
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TransactionTile(txn: t),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _CurrencyPackageCard extends StatelessWidget {
  final WalletPackage pkg;
  final bool isLoading;
  final VoidCallback onTap;
  const _CurrencyPackageCard(
      {required this.pkg, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasBonus = pkg.bonusCredits != null && pkg.bonusCredits! > 0;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasBonus
                  ? const Color(0xFFFF9500).withOpacity(0.5)
                  : const Color(0xFF30363D),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    pkg.priceAmount.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                  if (hasBonus)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFFF9500).withOpacity(0.5)),
                      ),
                      child: Text(
                        '+₹${pkg.bonusCredits!.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Color(0xFFFF9500),
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.description,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  if (hasBonus) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Get ₹${pkg.totalCreditAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Color(0xFF00C896),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinutePackageCard extends StatelessWidget {
  final WalletPackage pkg;
  final bool isLoading;
  final VoidCallback onTap;
  const _MinutePackageCard(
      {required this.pkg, required this.isLoading, required this.onTap});

  IconData get _modeIcon {
    switch (pkg.mode) {
      case 'VIDEO':
        return Icons.videocam_rounded;
      case 'CHAT':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.phone_in_talk_rounded;
    }
  }

  Color get _modeColor {
    switch (pkg.mode) {
      case 'VIDEO':
        return const Color(0xFF7B61FF);
      case 'CHAT':
        return const Color(0xFF00C896);
      default:
        return const Color(0xFF00A8FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBonus = pkg.bonusCredits != null && pkg.bonusCredits! > 0;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _modeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_modeIcon, color: _modeColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pkg.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pkg.mode,
                          style: TextStyle(
                              color: _modeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pkg.description,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${pkg.priceAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                  if (hasBonus)
                    Text(
                      'Get ₹${pkg.totalCreditAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Color(0xFF00C896),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction txn;
  const _TransactionTile({required this.txn});

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final p = dt.hour >= 12 ? 'PM' : 'AM';
      return 'Today $h:$m $p';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: txn.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(txn.icon, color: txn.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  txn.description,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${txn.isCredit ? '+' : '-'}₹${txn.amount.toStringAsFixed(0)}',
                style: TextStyle(
                    color: txn.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(_formatDate(txn.createdAt),
                  style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class ConfirmSheet extends StatelessWidget {
  final WalletPackage pkg;
  final double currentBalance;
  final VoidCallback onConfirm;
  const ConfirmSheet(
      {required this.pkg,
      required this.currentBalance,
      required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final newBalance = currentBalance + pkg.totalCreditAmount;
    final hasBonus = pkg.bonusCredits != null && pkg.bonusCredits! > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white12, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Confirm Recharge',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          // Summary box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              children: [
                _row('You pay', '₹${pkg.priceAmount.toStringAsFixed(0)}',
                    Colors.white),
                if (hasBonus) ...[
                  const SizedBox(height: 10),
                  _row(
                      'Bonus credit',
                      '+₹${pkg.bonusCredits!.toStringAsFixed(0)}',
                      const Color(0xFFFF9500)),
                ],
                const SizedBox(height: 10),
                const Divider(color: Color(0xFF30363D)),
                const SizedBox(height: 10),
                _row(
                    'Wallet gets',
                    '₹${pkg.totalCreditAmount.toStringAsFixed(0)}',
                    const Color(0xFF00C896),
                    bold: true),
                const SizedBox(height: 10),
                _row('New balance', '₹${newBalance.toStringAsFixed(2)}',
                    Colors.white70),
                if (pkg.includedMinutes != null) ...[
                  const SizedBox(height: 10),
                  _row('Covers approx.', '${pkg.includedMinutes} minutes',
                      const Color(0xFF7B61FF)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: onConfirm,
              child: Text(
                'Pay ₹${pkg.priceAmount.toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color valueColor,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
      ],
    );
  }
}
