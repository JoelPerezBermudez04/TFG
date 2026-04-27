import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../products/models/product_model.dart';
import '../models/inventory_item_model.dart';
import '../widgets/product_image.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  Product? _selectedProduct;
  String _selectedUnit = 'unitat';
  DateTime? _expiryDate;

  int _step = 0;

  Category? _selectedCategory;

  static const _unitBases = ['g', 'kg', 'ml', 'L', 'unitat'];

  String get _resolvedUnit {
    final qty = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1;
    if (_selectedUnit == 'unitat') return qty == 1 ? 'unitat' : 'unitats';
    return _selectedUnit;
  }

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsProvider>().fetchCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final inventory = context.read<InventoryProvider>();
    final qty = double.parse(_quantityController.text.replaceAll(',', '.'));

    final success = await inventory.addItem(
      producteId: _selectedProduct!.id,
      quantitat: qty,
      unitat: _resolvedUnit,
      dataCaducitat: _expiryDate,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producte afegit al rebost'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inventory.error ?? 'Error afegint producte'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _step = 1;
      _searchController.clear();
      context.read<ProductsProvider>().clearProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Selecciona un producte' : _selectedProduct?.nom ?? 'Afegir'),
        leading: _step == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _step = 0;
                  _selectedProduct = null;
                }),
              )
            : null,
      ),
      body: _step == 0 ? _buildStep0() : _buildStep1(),
    );
  }

  Widget _buildStep0() {
    final products = context.watch<ProductsProvider>();
    final isSearching = _searchController.text.length >= 2;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cercar producte...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _selectedCategory = null);
                        context.read<ProductsProvider>().clearProducts();
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() => _selectedCategory = null);
              if (value.length >= 2) {
                context.read<ProductsProvider>().fetchProducts(cerca: value);
              } else {
                context.read<ProductsProvider>().clearProducts();
              }
            },
          ),
        ),

        Expanded(
          child: isSearching
              ? _buildSearchResults(products)
              : _selectedCategory != null
                  ? _buildCategoryProducts(products)
                  : _buildCategoryGrid(products),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(ProductsProvider products) {
    if (products.isLoading && products.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = products.categories;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return GestureDetector(
          onTap: () {
            setState(() => _selectedCategory = cat);
            products.fetchProducts(categoriaId: cat.id);
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(
                  cat.nom,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryProducts(ProductsProvider products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = null);
              products.clearProducts();
            },
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${_selectedCategory!.emoji} ${_selectedCategory!.nom}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _buildProductList(products)),
      ],
    );
  }

  Widget _buildSearchResults(ProductsProvider products) {
    if (products.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (products.products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'No s\'han trobat productes',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return _buildProductList(products);
  }

  Widget _buildProductList(ProductsProvider products) {
    if (products.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (products.products.isEmpty) {
      return const Center(
        child: Text(
          'Cap producte en aquesta categoria',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: products.products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = products.products[index];
        return GestureDetector(
          onTap: () => _selectProduct(product),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
              ],
            ),
            child: Row(
              children: [
                ProductImage(
                  imatgeUrl: product.imatgeUrl,
                  emoji: product.emoji,
                  size: 48,
                  backgroundColor: AppColors.primaryLight,
                  borderRadius: 10,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.nom,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (product.categoriaNom != null)
                        Text(
                          product.categoriaNom!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ProductImage(
                  imatgeUrl: _selectedProduct!.imatgeUrl,
                  emoji: _selectedProduct!.emoji,
                  size: 56,
                  backgroundColor: Colors.white.withOpacity(0.6),
                  borderRadius: 12,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedProduct!.nom,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_selectedProduct!.categoriaNom != null)
                        Text(
                          _selectedProduct!.categoriaNom!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Quantitat',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '1'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Obligatori';
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) return 'Valor invàlid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(),
                  items: _unitBases.map((u) {
                    final qty = double.tryParse(
                          _quantityController.text.replaceAll(',', '.'),
                        ) ?? 1;
                    final display = (u == 'unitat' && qty != 1) ? 'unitats' : u;
                    return DropdownMenuItem(value: u, child: Text(display));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedUnit = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'Data de caducitat',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _expiryDate != null
                          ? DateFormat('dd/MM/yyyy').format(_expiryDate!)
                          : 'Seleccionar data (opcional)',
                      style: TextStyle(
                        color: _expiryDate != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_expiryDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _expiryDate = null),
                      child: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          Consumer<InventoryProvider>(
            builder: (context, inventory, _) => ElevatedButton(
              onPressed: inventory.isLoading ? null : _handleSubmit,
              child: inventory.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Afegir al rebost'),
            ),
          ),
        ],
      ),
    );
  }
}