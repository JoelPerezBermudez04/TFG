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

    // Dades de cobertura (mode recomanacions)
    final recomanacio = provider.modeRecomanacions
        ? provider.recomanacions
            .cast<Recomanacio?>()
            .firstWhere((r) => r?.idApi == recepta.idApi, orElse: () => null)
        : null;

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
                        _metaChip(Icons.restaurant_outlined, '${recepta.numIngredients} ing.'),
                        if (recomanacio != null) ...[
                          const SizedBox(width: 8),
                          _coberturaChip(recomanacio.ingredientsCoberts, recomanacio.totalIngredients),
                        ],
                      ],
                    ),
                    // Barra de cobertura en mode recomanacions
                    if (recomanacio != null) ...[
                      const SizedBox(height: 8),
                      _coberturaBar(recomanacio.ingredientsCoberts, recomanacio.totalIngredients),
                    ],
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

  Widget _coberturaChip(int coberts, int total) {
    final color = coberts == total
        ? AppColors.success
        : coberts >= total * 0.6
            ? AppColors.warning
            : AppColors.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.kitchen_outlined, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          '$coberts/$total ing.',
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _coberturaBar(int coberts, int total) {
    final pct = total > 0 ? coberts / total : 0.0;
    final color = pct == 1.0
        ? AppColors.success
        : pct >= 0.6
            ? AppColors.warning
            : AppColors.error;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: pct,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 4,
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
          if (provider.nomesInventari)
            _chip('Tinc els ingredients', () => provider.setNomesInventari(false)),
          if (provider.nomesUrgents)
            _chip('Urgents', () => provider.setNomesUrgents(false)),
          if (provider.producteNom != null)
            _chip(
              '${provider.producteNom}',
              () => provider.setProducte(null, null),
            ),
          for (final d in provider.dietes)
            _chip(d, () => provider.setDietes(
                provider.dietes.where((v) => v != d).toList())),
          if (provider.maxTemps != null)
            _chip('≤${provider.maxTemps} min', () => provider.setMaxTemps(null)),
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
  Set<String> _dietes = {};
  double? _maxTemps;
  bool _nomesInventari = false;
  bool _nomesUrgents = false;

  static const _opcions = [
    'Vegetarià',
    'Vegà',
    'Lacto-ovo-vegetarià',
    'Pescatarià',
    'Sense gluten',
    'Sense làctics',
    'Cetogènica',
    'Paleolítica',
    'Primal',
    'Whole30',
    'Baix en FODMAP',
    'Compatible amb FODMAP',
  ];

  static const _dietesInfo = {
    'Vegetarià': (
      emoji: '🥦',
      desc: 'No inclou carn ni peix, però sí ous, làctics i mel.',
    ),
    'Vegà': (
      emoji: '🌱',
      desc: 'Exclou tots els productes d\'origen animal: carn, peix, ous, làctics i mel.',
    ),
    'Lacto-ovo-vegetarià': (
      emoji: '🥚',
      desc: 'No inclou carn ni peix. Permet ous i productes làctics.',
    ),
    'Pescatarià': (
      emoji: '🐟',
      desc: 'Exclou la carn però permet peix i marisc.',
    ),
    'Sense gluten': (
      emoji: '🌾',
      desc: 'No conté blat, ordi, sègol ni espelta. Apta per a celíacs i sensibles al gluten.',
    ),
    'Sense làctics': (
      emoji: '🥛',
      desc: 'No conté llet ni cap derivat làctic (formatge, iogurt, mantega...).',
    ),
    'Cetogènica': (
      emoji: '🥑',
      desc: 'Molt baixa en carbohidrats i alta en greixos. Indueix la cetosi per cremar greix com a font d\'energia.',
    ),
    'Paleolítica': (
      emoji: '🍖',
      desc: 'Basada en aliments no processats: carn, peix, fruita, verdura i fruits secs. Exclou cereals, llegums i làctics.',
    ),
    'Primal': (
      emoji: '🫙',
      desc: 'Similar a la paleolítica però permet làctics d\'alta qualitat i alguns aliments fermentats.',
    ),
    'Whole30': (
      emoji: '📅',
      desc: 'Programa de 30 dies que elimina sucre afegit, cereals, llegums, làctics i additius. Enfocada a reiniciar hàbits alimentaris.',
    ),
    'Baix en FODMAP': (
      emoji: '🔬',
      desc: 'Redueix els hidrats de carboni fermentables (FODMAP) per alleujar símptomes de l\'intestí irritable.',
    ),
    'Compatible amb FODMAP': (
      emoji: '✅',
      desc: 'Receptes que compleixen les directrius FODMAP i són adequades per a persones amb síndrome de l\'intestí irritable.',
    ),
  };

  void _mostrarInfoDietes([String? dietaFocus]) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                color: AppColors.primaryLight,
                child: Row(
                  children: [
                    const Text('ℹ️', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tipus de dietes',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    children: _opcions.map((dieta) {
                      final info = _dietesInfo[dieta];
                      if (info == null) return const SizedBox.shrink();
                      final isHighlighted = dieta == dietaFocus;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isHighlighted ? AppColors.primaryLight : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isHighlighted ? AppColors.primary : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dieta,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isHighlighted
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    info.desc,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final p = context.read<ReceptesProvider>();
    _dietes = Set.from(p.dietes);
    _maxTemps = p.maxTemps?.toDouble();
    _nomesInventari = p.nomesInventari;
    _nomesUrgents = p.nomesUrgents;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
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
                      _dietes = {};
                      _maxTemps = null;
                      _nomesInventari = false;
                      _nomesUrgents = false;
                    });
                  },
                  child: const Text('Netejar',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Secció recomanacions ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_nomesInventari || _nomesUrgents) ? AppColors.primaryLight : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_nomesInventari || _nomesUrgents) ? AppColors.primary : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.kitchen_outlined, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Recomanacions',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _switchOpcio(
                    Icons.check_circle_outline,
                    'Només ingredients que tinc',
                    'Mostra receptes que pots fer ara',
                    _nomesInventari,
                    (v) => setState(() => _nomesInventari = v),
                  ),
                  const SizedBox(height: 10),
                  _switchOpcio(
                    Icons.warning_amber_outlined,
                    'Només productes urgents',
                    'Prioritza ingredients a punt de caducar',
                    _nomesUrgents,
                    (v) => setState(() => _nomesUrgents = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
            Row(
              children: [
                const Text('Dieta',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _mostrarInfoDietes(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (_dietes.isNotEmpty)
                  Text(
                    '${_dietes.length} seleccionad${_dietes.length == 1 ? 'a' : 'es'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _opcions
                  .map((d) => _selectableChip(
                        d,
                        _dietes.contains(d),
                        onTap: () => setState(() {
                          if (_dietes.contains(d)) {
                            _dietes.remove(d);
                          } else {
                            _dietes.add(d);
                          }
                        }),
                        onLongPress: () => _mostrarInfoDietes(d),
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
      ),
    );
  }

  Widget _switchOpcio(
      IconData icon, String titol, String subtitol, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titol,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
              Text(subtitol,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _selectableChip(String label, bool selected,
      {required VoidCallback onTap, VoidCallback? onLongPress}) =>
      GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );

  void _aplicar() {
    final p = context.read<ReceptesProvider>();
    p.setDietes(_dietes.toList());
    p.setMaxTemps(_maxTemps?.toInt());
    p.setNomesInventari(_nomesInventari);
    p.setNomesUrgents(_nomesUrgents);
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