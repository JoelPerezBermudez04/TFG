import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/receptes_provider.dart';
import 'recepta_detail_screen.dart';

class ReceptesScreen extends StatefulWidget {
  const ReceptesScreen({super.key});

  @override
  State<ReceptesScreen> createState() => _ReceptesScreenState();
}

class _ReceptesScreenState extends State<ReceptesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final provider = context.read<ReceptesProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.fetchReceptes();
      provider.fetchFavorits();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<ReceptesProvider>();
      if (!provider.isLoading && provider.hasMore) {
        provider.fetchReceptes(loadMore: true);
      }
    }
  }

  void _onSearchChanged(String value) {
    context.read<ReceptesProvider>().setSearch(value);
  }

  void _showFiltresSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FiltresSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receptes'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Totes'),
            Tab(text: 'Preferides'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TotesReceptesTab(
            searchController: _searchController,
            scrollController: _scrollController,
            onSearchChanged: _onSearchChanged,
            onFiltres: _showFiltresSheet,
          ),
          const _PreferidestTab(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Tab: Totes les receptes
// ──────────────────────────────────────────────

class _TotesReceptesTab extends StatelessWidget {
  final TextEditingController searchController;
  final ScrollController scrollController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFiltres;

  const _TotesReceptesTab({
    required this.searchController,
    required this.scrollController,
    required this.onSearchChanged,
    required this.onFiltres,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceptesProvider>();

    return Column(
      children: [
        // ── Barra de cerca + filtres ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cerca receptes...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FiltreButton(
                active: provider.teFiltresActius,
                onTap: onFiltres,
              ),
            ],
          ),
        ),

        // ── Xips de filtres actius ──
        if (provider.teFiltresActius)
          _FiltresActiusRow(provider: provider),

        // ── Comptador ──
        if (!provider.isLoading || provider.receptes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${provider.total} receptes',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),

        // ── Llistat ──
        Expanded(
          child: _buildBody(context, provider),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ReceptesProvider provider) {
    if (provider.isLoading && provider.receptes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.receptes.isEmpty) {
      return _ErrorView(
        message: provider.error!,
        onRetry: () => provider.fetchReceptes(),
      );
    }

    if (provider.receptes.isEmpty) {
      return const _EmptyView(
        emoji: '🔍',
        titol: 'Sense resultats',
        subtitol: 'Prova amb un altre terme de cerca o canvia els filtres',
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchReceptes(),
      color: AppColors.primary,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: provider.receptes.length + (provider.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == provider.receptes.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return ReceptaCard(recepta: provider.receptes[i]);
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Tab: Preferides
// ──────────────────────────────────────────────

class _PreferidestTab extends StatelessWidget {
  const _PreferidestTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceptesProvider>();

    if (provider.loadingFavorits) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.favorits.isEmpty) {
      return const _EmptyView(
        emoji: '❤️',
        titol: 'Cap preferida encara',
        subtitol: 'Prem el cor d\'una recepta per guardar-la aquí',
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchFavorits(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: provider.favorits.length,
        itemBuilder: (context, i) {
          final fav = provider.favorits[i];
          return FavoritCard(favorit: fav);
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Targeta de recepta
// ──────────────────────────────────────────────

class ReceptaCard extends StatelessWidget {
  final Recepta recepta;

  const ReceptaCard({super.key, required this.recepta});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceptesProvider>();
    final esFav = provider.esFavorit(recepta.idApi);
    final toggling = provider.isToggling(recepta.idApi);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReceptaDetailScreen(idApi: recepta.idApi),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imatge
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: recepta.imatgeUrl != null && recepta.imatgeUrl!.isNotEmpty
                      ? Image.network(
                          recepta.imatgeUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            recepta.nom,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // Botó favorit
                        GestureDetector(
                          onTap: () =>
                              context.read<ReceptesProvider>().toggleFavorit(recepta.idApi),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: toggling
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(
                                    esFav ? Icons.favorite : Icons.favorite_border,
                                    key: ValueKey(esFav),
                                    color: esFav ? AppColors.error : AppColors.textMuted,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _metaChip(Icons.schedule_outlined, '${recepta.tempsPreparacio} min'),
                        const SizedBox(width: 8),
                        _metaChip(Icons.people_outline, '${recepta.porcions} p.'),
                        const SizedBox(width: 8),
                        _metaChip(
                            Icons.restaurant_outlined, '${recepta.numIngredients} ing.'),
                      ],
                    ),
                    if (recepta.dietes != null && recepta.dietes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: recepta.dietes!
                            .take(3)
                            .map((d) => _dietaChip(d))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: AppColors.primaryLight,
        child: const Center(
          child: Text('🍽️', style: TextStyle(fontSize: 40)),
        ),
      );

  Widget _metaChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      );

  Widget _dietaChip(String dieta) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          dieta,
          style: const TextStyle(
              fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
        ),
      );
}

// ──────────────────────────────────────────────
// Targeta de favorit
// ──────────────────────────────────────────────

class FavoritCard extends StatelessWidget {
  final FavoritItem favorit;

  const FavoritCard({super.key, required this.favorit});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceptesProvider>();
    final toggling = provider.isToggling(favorit.receptaId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReceptaDetailScreen(idApi: favorit.receptaId),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Miniatura
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: favorit.receptaImatgeUrl != null &&
                            favorit.receptaImatgeUrl!.isNotEmpty
                        ? Image.network(
                            favorit.receptaImatgeUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _thumb(),
                          )
                        : _thumb(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorit.receptaNom,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            '${favorit.receptaTempsPreparacio} min',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      if (favorit.receptaDietes != null &&
                          favorit.receptaDietes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          favorit.receptaDietes!.take(2).join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.primary),
                        ),
                      ],
                    ],
                  ),
                ),
                // Desguardar
                toggling
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.favorite,
                            color: AppColors.error, size: 22),
                        onPressed: () =>
                            provider.toggleFavorit(favorit.receptaId),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb() => Container(
        color: AppColors.primaryLight,
        child: const Center(
            child: Text('🍽️', style: TextStyle(fontSize: 26))),
      );
}

// ──────────────────────────────────────────────
// Botó de filtres
// ──────────────────────────────────────────────

class _FiltreButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _FiltreButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : Colors.grey.shade200,
          ),
        ),
        child: Icon(
          Icons.tune_rounded,
          color: active ? Colors.white : AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Xips de filtres actius
// ──────────────────────────────────────────────

class _FiltresActiusRow extends StatelessWidget {
  final ReceptesProvider provider;

  const _FiltresActiusRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (provider.dieta != null)
            _chip(provider.dieta!, () => provider.setDieta(null)),
          if (provider.intolerancia != null)
            _chip('Sense ${provider.intolerancia}',
                () => provider.setIntolerancia(null)),
          if (provider.maxTemps != null)
            _chip('≤${provider.maxTemps} min',
                () => provider.setMaxTemps(null)),
          TextButton(
            onPressed: provider.clearFiltres,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Netejar tot',
                style: TextStyle(fontSize: 12, color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 14, color: AppColors.primary),
            ),
          ],
        ),
      );
}

// ──────────────────────────────────────────────
// Bottom sheet de filtres
// ──────────────────────────────────────────────

class _FiltresSheet extends StatefulWidget {
  const _FiltresSheet();

  @override
  State<_FiltresSheet> createState() => _FiltresSheetState();
}

class _FiltresSheetState extends State<_FiltresSheet> {
  String? _dieta;
  String? _intolerancia;
  double? _maxTemps;

  static const _dietes = [
    'Vegetarià', 'Vegà', 'Sense gluten', 'Keto', 'Mediterrània',
  ];
  static const _intolerancias = [
    'Gluten', 'Làctia', 'Ous', 'Fruits secs', 'Peix', 'Marisc', 'Soja',
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<ReceptesProvider>();
    _dieta = p.dieta;
    _intolerancia = p.intolerancia;
    _maxTemps = p.maxTemps?.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Filtres',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _dieta = null;
                    _intolerancia = null;
                    _maxTemps = null;
                  });
                },
                child: const Text('Netejar',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Temps màxim
          const Text('Temps de preparació màxim',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _maxTemps ?? 120,
                  min: 10,
                  max: 120,
                  divisions: 11,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _maxTemps = v),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  _maxTemps != null ? '${_maxTemps!.toInt()} min' : 'Tots',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                onPressed: () => setState(() => _maxTemps = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dieta
          const Text('Dieta',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dietes
                .map((d) => _selectableChip(
                      d,
                      _dieta == d,
                      () => setState(
                          () => _dieta = _dieta == d ? null : d),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Intolerància
          const Text('Sense (al·lèrgens)',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _intolerancias
                .map((i) => _selectableChip(
                      i,
                      _intolerancia == i,
                      () => setState(() =>
                          _intolerancia = _intolerancia == i ? null : i),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _aplicar,
              child: const Text('Aplicar filtres'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectableChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade200,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );

  void _aplicar() {
    final p = context.read<ReceptesProvider>();
    p.setDieta(_dieta);
    p.setIntolerancia(_intolerancia);
    p.setMaxTemps(_maxTemps?.toInt());
    Navigator.pop(context);
  }
}

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final String emoji;
  final String titol;
  final String subtitol;

  const _EmptyView(
      {required this.emoji, required this.titol, required this.subtitol});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(titol,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitol,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(message,
              style:
                  const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}