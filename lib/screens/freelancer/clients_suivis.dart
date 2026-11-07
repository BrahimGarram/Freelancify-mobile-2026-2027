import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/abonnement_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/home_widgets.dart';

/// Les clients que le freelancer suit (et ne plus les suivre)
class ClientsSuivisScreen extends StatefulWidget {
  final User user;
  const ClientsSuivisScreen({super.key, required this.user});

  @override
  State<ClientsSuivisScreen> createState() => _ClientsSuivisScreenState();
}

class _ClientsSuivisScreenState extends State<ClientsSuivisScreen> {
  final _service = AbonnementService();
  List<({int id, String nom, int postsOuverts})> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final liste = await _service.detailsClientsSuivis(widget.user.id!);
    if (mounted) {
      setState(() {
        _clients = liste;
        _loading = false;
      });
    }
  }

  Future<void> _nePlusSuivre(int clientId, String nom) async {
    await _service.nePlusSuivre(
      freelancerId: widget.user.id!,
      clientId: clientId,
    );
    if (!mounted) return;
    showAppMessage(context, 'Tu ne suis plus @$nom');
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Clients suivis',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_clients.isEmpty)
                  const EmptyState(
                    icon: Icons.person_add_alt_rounded,
                    title: 'Tu ne suis aucun client',
                    message:
                        'Touche « Suivre » sur une mission : tu seras '
                        'notifié des prochaines offres de ce client.',
                  )
                else
                  for (final c in _clients)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.fieldBorder),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            name: c.nom,
                            isClient: true,
                            size: 40,
                            withShadow: false,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@${c.nom}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  c.postsOuverts == 0
                                      ? 'Aucune mission ouverte'
                                      : '${c.postsOuverts} mission'
                                            '${c.postsOuverts > 1 ? 's' : ''} '
                                            'ouverte${c.postsOuverts > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _nePlusSuivre(c.id, c.nom),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text('Ne plus suivre'),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}
