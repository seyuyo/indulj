import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../common/error_text.dart';
import '../favorites/favorites_notifier.dart';
import '../stop_search/stop_search_screen.dart';

/// Widget felrakásakor (vagy átkonfigurálásakor) nyílik meg: melyik csoportot
/// mutassa. Választás után a widget azonnal frissül, és az app bezárul.
class WidgetConfigScreen extends ConsumerStatefulWidget {
  const WidgetConfigScreen({super.key, required this.widgetId});

  final int widgetId;

  @override
  ConsumerState<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends ConsumerState<WidgetConfigScreen> {
  bool _saving = false;

  Future<void> _choose(String groupId) async {
    setState(() => _saving = true);
    await ref.read(widgetRefresherProvider).assign(widget.widgetId, groupId);
    await ref.read(finishWidgetConfigureProvider)();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(favoritesProvider);
    final current = ref.read(widgetRefresherProvider).groupOf(widget.widgetId);

    return Scaffold(
      appBar: AppBar(title: const Text('Mit mutasson a widget?')),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
          ? Center(
              child: StatusMessage(
                icon: Icons.star_outline,
                title: 'Még nincs kedvenc csoportod',
                detail: 'Hozz létre egyet, és utána válaszd ki itt.',
                actionLabel: 'Megálló hozzáadása',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StopSearchScreen(),
                  ),
                ),
              ),
            )
          : ListView(
              children: [
                for (final g in groups)
                  ListTile(
                    leading: Icon(
                      g.id == current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(g.name),
                    subtitle: Text('${g.stopIds.length} megálló'),
                    onTap: () => _choose(g.id),
                  ),
              ],
            ),
    );
  }
}
