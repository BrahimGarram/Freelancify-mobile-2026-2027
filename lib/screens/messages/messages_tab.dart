import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/message_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/home_widgets.dart';
import 'chat_screen.dart';

/// Onglet « Messages » (Client et Freelancer) : la liste des discussions.
class MessagesTab extends StatefulWidget {
  final User user;

  /// Appelé après la lecture d'une discussion (pour le badge non lus)
  final VoidCallback? onLu;

  const MessagesTab({super.key, required this.user, this.onLu});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  final _messageService = MessageService();
  List<Conversation> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final convs = await _messageService.getConversations(widget.user.id!);
      if (!mounted) return;
      setState(() {
        _conversations = convs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, 'Erreur : $e', error: true);
    }
  }

  Future<void> _ouvrir(Conversation c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(user: widget.user, conversation: c),
      ),
    );
    widget.onLu?.call();
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.user.role == 'client';
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.red,
        backgroundColor: AppColors.surface,
        onRefresh: _charger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            HomeHeader(user: widget.user, title: 'Messages'),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.red),
                ),
              )
            else if (_conversations.isEmpty)
              EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Aucune discussion',
                message: isClient
                    ? 'Quand un freelancer postule à un de tes posts, '
                          'vous pourrez discuter ici.'
                    : 'Postule à une mission pour discuter avec le client.',
              )
            else
              for (final c in _conversations)
                _ConversationTile(
                  conversation: c,
                  moi: widget.user.id!,
                  onTap: () => _ouvrir(c),
                ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final int moi;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.moi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final nom = c.interlocuteur(moi);
    final nonLu = c.nbNonLus > 0;
    final apercu = c.dernierMessage == null
        ? 'Aucun message'
        : '${c.dernierExpediteurId == moi ? 'Toi : ' : ''}${c.dernierMessage}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: nonLu ? const Color(0x99EE1D52) : AppColors.fieldBorder,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                UserAvatar(
                  name: nom,
                  isClient: c.interlocuteurEstClient(moi),
                  size: 46,
                  withShadow: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '@$nom',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (c.dateDernierMessage != null)
                            Text(
                              tempsEcoule(c.dateDernierMessage!),
                              style: TextStyle(
                                fontSize: 11,
                                color: nonLu
                                    ? AppColors.red
                                    : AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.postTitre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cyan,
                        ),
                      ),
                      if (moi == c.clientId) ...[
                        const SizedBox(height: 4),
                        Tooltip(
                          message: 'CofeeCoins du freelancer',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_cafe_outlined,
                                size: 14,
                                color: AppColors.cyan,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${c.freelancerCofeeCoins}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              apercu,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: nonLu
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: nonLu
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (nonLu)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.red,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${c.nbNonLus}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
