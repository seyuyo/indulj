import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/result.dart';
import '../../domain/models.dart';
import '../common/route_badge.dart';
import 'favorites_notifier.dart';

/// Csoport neve és járatszűrője; új csoportnál a kijelölt megállókból.
class GroupEditorScreen extends ConsumerStatefulWidget {
  GroupEditorScreen.create({super.key, required List<Stop> stops})
    : stopIds = [for (final s in stops) s.id],
      initialName = stops.first.name,
      existing = null;

  GroupEditorScreen.edit({super.key, required StopGroup group})
    : stopIds = group.stopIds,
      initialName = group.name,
      existing = group;

  final List<String> stopIds;
  final String initialName;
  final StopGroup? existing;

  @override
  ConsumerState<GroupEditorScreen> createState() => _GroupEditorScreenState();
}

typedef _RouteOption = ({String id, String name, int color, int textColor});

class _GroupEditorScreenState extends ConsumerState<GroupEditorScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  late final Set<String> _filter = {...?widget.existing?.routeFilter};
  List<_RouteOption>? _routes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Egyszeri lekérés: mely járatok indulnak a kijelölt megállókról.
  Future<void> _loadRoutes() async {
    final result = await ref
        .read(departuresRepositoryProvider)
        .fetch(widget.stopIds);
    if (!mounted) return;
    final byId = <String, _RouteOption>{};
    if (result case Ok(:final value)) {
      for (final d in value.result.departures) {
        byId[d.routeId] ??= (
          id: d.routeId,
          name: d.routeShortName,
          color: d.routeColor,
          textColor: d.routeTextColor,
        );
      }
    }
    // A mentett szűrő olyan járatot is tartalmazhat, ami most épp nem jár.
    for (final id in _filter) {
      byId[id] ??= (
        id: id,
        name: id.replaceFirst('BKK_', ''),
        color: 0xFF757575,
        textColor: 0xFFFFFFFF,
      );
    }
    setState(() {
      _routes = byId.values.toList()..sort((a, b) => _compare(a.name, b.name));
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final group =
        widget.existing?.copyWith(
          name: name,
          routeFilter: () => _filter.isEmpty ? null : {..._filter},
        ) ??
        StopGroup(
          id: '${ref.read(clockProvider).nowMs()}',
          name: name,
          stopIds: widget.stopIds,
          routeFilter: _filter.isEmpty ? null : {..._filter},
        );
    await ref.read(favoritesProvider.notifier).upsert(group);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final routes = _routes;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Új csoport' : 'Csoport'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Név',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text('${widget.stopIds.length} megálló'),
          const SizedBox(height: 24),
          Text('Járatok', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            _filter.isEmpty
                ? 'Minden járat látszik. Koppints a szűkítéshez.'
                : 'Csak a kijelölt járatok látszanak.',
          ),
          const SizedBox(height: 12),
          if (routes == null)
            const Center(child: CircularProgressIndicator())
          else if (routes.isEmpty)
            const Text('Most nem indul innen járat, a szűrő később állítható.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in routes)
                  FilterChip(
                    selected: _filter.contains(r.id),
                    onSelected: (on) => setState(
                      () => on ? _filter.add(r.id) : _filter.remove(r.id),
                    ),
                    label: RouteBadge(
                      label: r.name,
                      color: r.color,
                      textColor: r.textColor,
                    ),
                  ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Mentés'),
          ),
        ),
      ),
    );
  }
}

/// Természetes sorrend: „4" < „6" < „105" < „M1".
int _compare(String a, String b) {
  final na = int.tryParse(a), nb = int.tryParse(b);
  if (na != null && nb != null) return na.compareTo(nb);
  if (na != null) return -1;
  if (nb != null) return 1;
  return a.compareTo(b);
}
