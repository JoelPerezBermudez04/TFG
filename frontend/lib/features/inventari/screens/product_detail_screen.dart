import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../models/inventory_item_model.dart';
import 'edit_product_screen.dart';
import '../widgets/product_image.dart';

class ProductDetailScreen extends StatelessWidget {
  final int itemId;

  const ProductDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final item = inventory.getItemById(itemId);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Producte no trobat')),
      );
    }

    final (bgColor, textColor, statusLabel) = _getStatusDisplay(item);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditProductScreen(item: item)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ProductImage(
              imatgeUrl: item.producteImatgeUrl,
              emoji: item.producteEmoji,
              size: 120,
              backgroundColor: bgColor,
              borderRadius: 24,
            ),
            const SizedBox(height: 20),

            Text(
              item.producteNom ?? 'Producte',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'Quantitat',
                    '${item.quantitat % 1 == 0 ? item.quantitat.toInt() : item.quantitat} ${item.unitat == 'unitat' && item.quantitat != 1 ? 'unitats' : item.unitat}',
                    Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    'Caducitat',
                    item.dataCaducitat != null
                        ? DateFormat('dd/MM/yyyy').format(item.dataCaducitat!)
                        : 'No definida',
                    Icons.calendar_today_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'Afegit',
                    DateFormat('dd/MM/yyyy').format(item.dataAfegit),
                    Icons.add_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    'Dies restants',
                    item.dataCaducitat != null
                        ? (item.daysUntilExpiry >= 0
                            ? '${item.daysUntilExpiry} dies'
                            : 'Caducat')
                        : '—',
                    Icons.hourglass_empty,
                  ),
                ),
              ],
            ),

            if (item.dataCaducitat != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Temps de vida',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _getLifeProgress(item),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_getLifeProgress(item) * 100).round()}% del temps de vida restant',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleDelete(context, item, 'Llençat'),
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  label: const Text('Llençat', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleDelete(context, item, 'Consumit'),
                  icon: const Icon(Icons.check),
                  label: const Text('Consumit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, InventoryItem item, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action "${item.producteNom}"?'),
        content: Text(
          action == 'Consumit'
              ? 'El producte serà eliminat del rebost.'
              : 'El producte serà eliminat del rebost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: action == 'Llençat'
                ? ElevatedButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final inventory = context.read<InventoryProvider>();
      final success = await inventory.deleteItem(item.id);
      if (success && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.producteNom} marcat com a $action.toLowerCase()'),
            backgroundColor: action == 'Consumit' ? AppColors.success : AppColors.warning,
          ),
        );
      }
    }
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String) _getStatusDisplay(InventoryItem item) {
    switch (item.expiryStatus) {
      case ExpiryStatus.expired:
        return (AppColors.expiryUrgent, AppColors.expiryUrgentText, 'Caducat');
      case ExpiryStatus.urgent:
        final days = item.daysUntilExpiry;
        return (
          AppColors.expiryUrgent,
          AppColors.expiryUrgentText,
          days == 0 ? 'Caduca avui!' : days == 1 ? 'Caduca demà' : 'Caduca en $days dies',
        );
      case ExpiryStatus.soon:
        return (AppColors.expirySoon, AppColors.expirySoonText, 'Caduca en ${item.daysUntilExpiry} dies');
      case ExpiryStatus.fresh:
        return (AppColors.expiryFresh, AppColors.expiryFreshText, 'Fresc');
      case ExpiryStatus.none:
        return (AppColors.primaryLight, AppColors.primary, 'Sense data de caducitat');
    }
  }

  double _getLifeProgress(InventoryItem item) {
    if (item.dataCaducitat == null) return 1.0;
    final totalDays = item.dataCaducitat!.difference(item.dataAfegit).inDays;
    if (totalDays <= 0) return 0.0;
    final remaining = item.daysUntilExpiry;
    if (remaining <= 0) return 0.0;
    return (remaining / totalDays).clamp(0.0, 1.0);
  }
}