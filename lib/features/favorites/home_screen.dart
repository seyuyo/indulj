import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../board/board_screen.dart';
import '../common/error_text.dart';
import '../stop_search/stop_search_screen.dart';
import 'favorites_notifier.dart';
import 'favorites_repository.dart';
import 'group_editor_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(favoritesProvider);
    final canAdd = groups.length < maxFavoriteGroups;

    return Scaffold(
      appBar: AppBar(title: const Text('Indulj')),
      body: groups.isEmpty
          ? Center(
              child: StatusMessage(
                icon: Icons.star_outline,
                title: 'Még nincs kedvenc megállód',
                detail:
                    'Állíts össze legfeljebb $maxFavoriteGroups csoportot, '
                    'és itt látod az indulásaikat.',
                actionLabel: 'Megálló hozzáadása',
                onAction: () => _addGroup(context),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final g in groups) _GroupTile(group: g),
                if (!canAdd)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Legfeljebb $maxFavoriteGroups csoport lehet. '
                      'Újhoz törölj egyet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
      floatingActionButton: groups.isNotEmpty && canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _addGroup(context),
              icon: const Icon(Icons.add),
              label: const Text('Új csoport'),
            )
          : null,
    );
  }

  void _addGroup(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const StopSearchScreen()));
}

enum _GroupAction { edit, delete }

class _GroupTile extends ConsumerWidget {
  const _GroupTile({required this.group});

  final StopGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = '${group.stopIds.length} megálló';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.directions_transit),
        title: Text(group.name),
        subtitle: Text(
          group.routeFilter == null
              ? stops
              : '$stops · ${group.routeFilter!.length} járat',
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BoardScreen(groupId: group.id),
          ),
        ),
        trailing: PopupMenuButton<_GroupAction>(
          onSelected: (action) => switch (action) {
            _GroupAction.edit => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupEditorScreen.edit(group: group),
              ),
            ),
            _GroupAction.delete =>
              ref.read(favoritesProvider.notifier).remove(group.id),
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: _GroupAction.edit, child: Text('Szerkesztés')),
            PopupMenuItem(value: _GroupAction.delete, child: Text('Törlés')),
          ],
        ),
      ),
    );
  }
}
