import 'package:flutter/material.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_button_styles.dart';
import '../widgets/status_bar_style.dart';
import '../services/haptic_service.dart';

class WalletHistoryScreen extends StatefulWidget {
  final bool isDarkMode;

  const WalletHistoryScreen({super.key, required this.isDarkMode});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  late bool _isDark;
  final WalletService _walletService = WalletService();

  bool _isLoading = true;
  String? _error;
  List<WalletTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final history = await _walletService.getWalletHistory();
      if (!mounted) return;
      setState(() {
        _transactions = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load transaction history.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    final surfaceColor = _isDark ? AppTheme.darkCard : AppTheme.lightGray;

    return StatusBarStyle(
      isDark: _isDark,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticService.light();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: textColor),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Transaction History',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: textColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildBody(textColor, surfaceColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Color textColor, Color surfaceColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentPurple));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: textColor)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHistory,
                style: AppButtonStyles.primary(),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions yet.',
          style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadHistory();
        HapticService.medium();
      },
      color: AppTheme.accentPurple,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _TransactionTile(
            transaction: _transactions[index],
            textColor: textColor,
            surfaceColor: surfaceColor,
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;
  final Color textColor;
  final Color surfaceColor;

  const _TransactionTile({
    required this.transaction,
    required this.textColor,
    required this.surfaceColor,
  });

  ({IconData icon, Color color, String label}) get _typeMeta {
    switch (transaction.type) {
      case 'reward':
        return (icon: Icons.play_circle_fill_rounded, color: Colors.green, label: 'Ad Reward');
      case 'purchase':
        return (icon: Icons.shopping_bag_rounded, color: Colors.blue, label: 'Purchase');
      case 'generation':
        return (icon: Icons.auto_awesome_rounded, color: AppTheme.accentPurple, label: 'Style Generation');
      case 'refund':
        return (icon: Icons.replay_rounded, color: Colors.orange, label: 'Refund');
      case 'admin':
        return (icon: Icons.admin_panel_settings_rounded, color: Colors.grey, label: 'Admin Adjustment');
      default:
        return (icon: Icons.receipt_long_rounded, color: Colors.grey, label: transaction.type);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta;
    final isPositive = transaction.amount > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, color: meta.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description?.isNotEmpty == true ? transaction.description! : meta.label,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${transaction.amount}',
            style: TextStyle(
              color: isPositive ? Colors.green : Colors.redAccent,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
