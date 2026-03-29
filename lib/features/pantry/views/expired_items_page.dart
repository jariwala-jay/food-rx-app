import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/core/widgets/cached_network_image.dart';
import 'package:flutter_app/features/notifications/views/notification_center_page.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';

class ExpiredItemsPage extends StatefulWidget {
  const ExpiredItemsPage({super.key});

  @override
  State<ExpiredItemsPage> createState() => _ExpiredItemsPageState();
}

class _ExpiredItemsPageState extends State<ExpiredItemsPage> {
  bool _isLoading = true;
  String? _error;
  List<PantryItem> _expiredItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpiredItems();
    });
  }

  Future<void> _loadExpiredItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pantryController = context.read<PantryController>();

      final userId = await ApiClient.userId;
      if (userId != null && userId.isNotEmpty) {
        pantryController.initializeWithUser(userId);
      }

      // Reuse /pantry/expiring with a threshold of 0 days, then filter
      // strictly "expired" (before now).
      final allExpiring = await pantryController.getExpiringItems(
        daysThreshold: 0,
      );
      final now = DateTime.now();

      final expired = allExpiring
          .where((i) => i.expirationDate.isBefore(now))
          .toList()
        ..sort((a, b) => a.expirationDate.compareTo(b.expirationDate));

      if (!mounted) return;
      setState(() => _expiredItems = expired);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userFacingErrorMessage(e));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime dt) {
    // Example: 2026-03-18
    return dt.toLocal().toString().split(' ').first;
  }

  Future<void> _confirmAndExtend(PantryItem item, int days) async {
    final pantryController = context.read<PantryController>();
    // Extend from "now" so the item becomes usable again immediately.
    final newExpiration = DateTime.now().add(Duration(days: days));
    final updated = item.copyWith(expirationDate: newExpiration);

    await pantryController.updateItem(updated);
    await _loadExpiredItems();
  }

  Future<void> _showExtendDialog(PantryItem item) async {
    final accent = const Color(0xFFFF6A00);

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Extend ${item.name}?'),
          content: const Text(
            'If it is not spoiled, you can extend the expiration date by 1 or 2 days.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 1),
              child: Text(
                '+1 day',
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 2),
              child: Text(
                '+2 days',
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    await _confirmAndExtend(item, result);
  }

  void _goBackToNotifications() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NotificationCenterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _goBackToNotifications,
        ),
        title: const Text('Expired items'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
              ),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : _expiredItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Color(0xFFFF6A00),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No expired items',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _expiredItems.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _expiredItems[index];

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CachedNetworkImageWidget(
                                  imageUrl: item.imageUrl,
                                  width: 56,
                                  height: 56,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2C2C2C),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Category: ${item.category}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Expired on ${_formatDate(item.expirationDate)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _showExtendDialog(item),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF6A00),
                                    side: const BorderSide(
                                      color: Color(0xFFFF6A00),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Extend',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

