import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../models/inventory_item_model.dart';
import 'add_product_screen.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tot';
  String? _selectedCategoria;
  final List<String> _filters = ['Tot', 'Fresc', 'Aviat', 'Caducat'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().fetchInventory();
    });
  }

  List<({int id, String nom, String emoji})> _getCategories(List<InventoryItem> items) {
    final seen = <int>{};
    final result = <({int id, String nom, String emoji})>[];
    for (final item in items) {
      final catId = item.producteCategoriaId;
      final catNom = item.producteCategoriaNom;
      final catEmoji = item.producteCategoriaEmoji ?? '🛒';
      if (catId != null && catNom != null && seen.add(catId)) {
        result.add((id: catId, nom: catNom, emoji: catEmoji));
      }
    }
    result.sort((a, b) => a.nom.compareTo(b.nom));
    return result;
  }

  List<InventoryItem> _applyFilters(List<InventoryItem> items) {
    return items.where((item) {
      if (_searchQuery.isNotEmpty) {
        final name = (item.producteNom ?? '').toLowerCase();
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }
      switch (_selectedFilter) {
        case 'Fresc':
          if (item.expiryStatus != ExpiryStatus.fresh &&
              item.expiryStatus != ExpiryStatus.none) return false;
        case 'Aviat':
          if (item.expiryStatus != ExpiryStatus.soon &&
              item.expiryStatus != ExpiryStatus.urgent) return false;
        case 'Caducat':
          if (item.expiryStatus != ExpiryStatus.expired) return false;
      }
      if (_selectedCategoria != null &&
          item.producteCategoriaNom != _selectedCategoria) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final categories = _getCategories(inventory.items);
    final filteredItems = _applyFilters(inventory.items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('El meu rebost'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cercar productes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primaryLight,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              },
            ),
          ),

          if (categories.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = _selectedCategoria == null;
                    return ChoiceChip(
                      label: const Text('🗂️ Totes'),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedCategoria = null),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primaryLight,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }
                  final cat = categories[index - 1];
                  final isSelected = _selectedCategoria == cat.nom;
                  return ChoiceChip(
                    label: Text('${cat.emoji} ${cat.nom}'),
                    selected: isSelected,
                    onSelected: (_) => setState(
                      () => _selectedCategoria = isSelected ? null : cat.nom,
                    ),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filteredItems.length} producte${filteredItems.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: inventory.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => inventory.fetchInventory(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _buildItemCard(context, filteredItems[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, InventoryItem item) {
    final (bgColor, textColor, label) = _getStatusDisplay(item);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(itemId: item.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ProductImage(
              imatgeUrl: item.producteImatgeUrl,
              emoji: item.producteEmoji,
              size: 56,
              backgroundColor: bgColor,
              borderRadius: 14,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.producteNom ?? 'Producte',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantitat % 1 == 0 ? item.quantitat.toInt() : item.quantitat} ${item.unitat == 'unitat' && item.quantitat != 1 ? 'unitats' : item.unitat}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (item.producteCategoriaNom != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.producteCategoriaNom!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                if (item.dataCaducitat != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(item.dataCaducitat!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🧺', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'El rebost està buit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Afegeix productes per començar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddProductScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Afegir producte'),
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
          days == 0 ? 'Avui!' : days == 1 ? 'Demà' : '$days dies',
        );
      case ExpiryStatus.soon:
        return (AppColors.expirySoon, AppColors.expirySoonText, '${item.daysUntilExpiry} dies');
      case ExpiryStatus.fresh:
        return (AppColors.expiryFresh, AppColors.expiryFreshText, 'Fresc');
      case ExpiryStatus.none:
        return (AppColors.primaryLight, AppColors.primary, 'Sense data');
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}