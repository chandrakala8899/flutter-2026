// lib/astro_queue/widgets/wallet_topup_banner.dart
// Shown inside SessionScreen / ChatScreen when balance hits 75% / 90% / 95% thresholds

import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/services/wallet_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class WalletTopUpBanner extends StatefulWidget {
  final int customerId;
  final int sessionId;
  final double ratePerMinute;
  final int elapsedMinutes;
  final int totalMinutes;
  final double currentBalance;
  final VoidCallback?
      onTopUpComplete; // called after successful mid-session top-up

  const WalletTopUpBanner({
    super.key,
    required this.customerId,
    required this.sessionId,
    required this.ratePerMinute,
    required this.elapsedMinutes,
    required this.totalMinutes,
    required this.currentBalance,
    this.onTopUpComplete,
  });

  @override
  State<WalletTopUpBanner> createState() => _WalletTopUpBannerState();
}

class _WalletTopUpBannerState extends State<WalletTopUpBanner> {
  bool _isLoading = false;
  late Razorpay _razorpay;

  String? _currentOrderId;
  double _currentAmount = 0;

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final success = await WalletService.confirmTopUp(
      gatewayOrderId: response.orderId!,
      gatewayPaymentId: response.paymentId!,
      gatewaySignature: response.signature!,
    );

    if (success) {
      final mins = (_currentAmount / widget.ratePerMinute).floor();

      _snack(
        "✅ +₹${_currentAmount.toStringAsFixed(0)} added! ~$mins more minutes available.",
      );

      widget.onTopUpComplete?.call();
    } else {
      _snack("Payment verification failed", isError: true);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _snack("Payment cancelled or failed", isError: true);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External wallet: ${response.walletName}");
  }

  double get _percentUsed => widget.totalMinutes == 0
      ? 0
      : widget.elapsedMinutes / widget.totalMinutes;

  bool get _show75 => _percentUsed >= 0.75 && _percentUsed < 0.90;
  bool get _show90 => _percentUsed >= 0.90 && _percentUsed < 0.95;
  bool get _show95 => _percentUsed >= 0.95;

  String get _alertMessage {
    if (_show95)
      return "⚠️ Only ~${widget.totalMinutes - widget.elapsedMinutes} min left! Top up now to continue.";
    if (_show90) return "Session ending soon. Top up to extend.";
    return "75% of session used. Consider topping up.";
  }

  Color get _bannerColor {
    if (_show95) return const Color(0xFFFF3B30);
    if (_show90) return const Color(0xFFFF9500);
    return const Color(0xFFFFCC00);
  }

  Color get _textColor {
    if (_show95 || _show90) return Colors.white;
    return Colors.black87;
  }

  void _showTopUpSheet() async {
    // Load packages from backend before showing sheet
    final pkgs = await WalletService.getCurrencyPackages();
    if (!mounted) return;
    if (pkgs.isEmpty) {
      _snack('Could not load packages. Please try again.', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MidSessionTopUpSheet(
        packages: pkgs,
        ratePerMinute: widget.ratePerMinute,
        currentBalance: widget.currentBalance,
        onConfirm: (pkg) async {
          Navigator.pop(context);
          await _doMidSessionTopUp(pkg);
        },
      ),
    );
  }

  Future<void> _doMidSessionTopUp(WalletPackage pkg) async {
    setState(() => _isLoading = true);

    final initRes = await WalletService.initiateTopUp(
      userId: widget.customerId,
      amount: pkg.priceAmount,
    );

    if (initRes == null) {
      _snack('Payment initiation failed', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    final orderId = initRes['gatewayOrderId'];

    _currentOrderId = orderId;
    _currentAmount = pkg.priceAmount;

    var options = {
      'key': initRes['razorpayKeyId'],
      'amount': initRes['amountInPaise'],
      'order_id': orderId,
      'name': 'Aumraa Wallet',
      'description': 'Session Top-Up',
      'theme': {'color': '#FF9500'}
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _snack('Payment failed', isError: true);
    }

    setState(() => _isLoading = false);
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_show75 && !_show90 && !_show95) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: _bannerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            _show95
                ? Icons.warning_rounded
                : Icons.account_balance_wallet_outlined,
            color: _textColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _alertMessage,
              style: TextStyle(
                color: _textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _textColor,
              ),
            )
          else
            GestureDetector(
              onTap: _showTopUpSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Top Up',
                  style: TextStyle(
                    color: _bannerColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mid-Session Top-Up Sheet
// ─────────────────────────────────────────────────────────────

class _MidSessionTopUpSheet extends StatelessWidget {
  final List<WalletPackage> packages;
  final double ratePerMinute;
  final double currentBalance;
  final void Function(WalletPackage) onConfirm;

  const _MidSessionTopUpSheet({
    required this.packages,
    required this.ratePerMinute,
    required this.currentBalance,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '⚡ Quick Top-Up',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Rate: ₹${ratePerMinute.toStringAsFixed(0)}/min',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ...packages.map((pkg) {
            final mins = (pkg.totalCreditAmount / ratePerMinute).floor();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onConfirm(pkg),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${pkg.priceAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '~$mins more minutes',
                              style: const TextStyle(
                                  color: Color(0xFF00C896), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (pkg.bonusCredits != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    const Color(0xFFFF9500).withOpacity(0.4)),
                          ),
                          child: Text(
                            '+₹${pkg.bonusCredits!.toStringAsFixed(0)} bonus',
                            style: const TextStyle(
                                color: Color(0xFFFF9500),
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white38, size: 16),
                    ],
                  ),
                ),
              ),
            );
          }),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }
}
