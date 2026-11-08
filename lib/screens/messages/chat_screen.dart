import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/candidature_service.dart';
import '../../services/message_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/home_widgets.dart';
import '../profil_freelancer.dart';

/// Ouvre la discussion liée à une candidature (depuis les listes).
/// Renvoie quand l'utilisateur revient en arrière.
Future<void> ouvrirDiscussion(
  BuildContext context,
  User user,
  int candidatureId,
) async {
  final conv = await MessageService().getConversation(candidatureId, user.id!);
  if (!context.mounted) return;
  if (conv == null) {
    showAppMessage(context, 'Discussion introuvable', error: true);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(user: user, conversation: conv),
    ),
  );
}

/// Discussion entre le client et le freelancer autour d'une candidature.
class ChatScreen extends StatefulWidget {
  final User user;
  final Conversation conversation;
  const ChatScreen({super.key, required this.user, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageService = MessageService();
  final _candidatureService = CandidatureService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  late Conversation _conv = widget.conversation;
  List<Message> _messages = [];
  bool _loading = true;
  bool _envoi = false;
  String? _erreurSaisie;

  int get _moi => widget.user.id!;
  bool get _suisClient => _moi == _conv.clientId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {})); // active/désactive Envoyer
    _charger();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------- FONCTIONNALITÉ : charger + marquer comme lus ----------
  Future<void> _charger() async {
    try {
      await _messageService.marquerLus(_conv.candidatureId, _moi);
      final messages = await _messageService.getMessages(_conv.candidatureId);
      final conv = await _messageService.getConversation(
        _conv.candidatureId,
        _moi,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        if (conv != null) _conv = conv;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, 'Erreur : $e', error: true);
    }
  }

  // ---------- FONCTIONNALITÉ : envoyer un message ----------
  Future<void> _envoyer() async {
    final erreur = Validators.messageChat(_controller.text);
    if (erreur != null) {
      setState(() => _erreurSaisie = erreur);
      return;
    }
    setState(() {
      _envoi = true;
      _erreurSaisie = null;
    });
    try {
      final m = await _messageService.envoyer(
        candidatureId: _conv.candidatureId,
        expediteurId: _moi,
        contenu: _controller.text,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() => _messages = [..._messages, m]);
      // la liste est inversée : 0 = tout en bas
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } on MessageException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  // ---------- FONCTIONNALITÉ : le client accepte / refuse ----------
  Future<void> _decider(bool accepter) async {
    final ok = await confirmerDecision(
      context,
      accepter: accepter,
      freelancer: _conv.freelancerUsername,
    );
    if (!ok) return;
    try {
      if (accepter) {
        await _candidatureService.accepterCandidature(_conv.candidatureId);
      } else {
        await _candidatureService.refuserCandidature(_conv.candidatureId);
      }
      if (!mounted) return;
      showAppMessage(
        context,
        accepter ? 'Candidature acceptée' : 'Candidature refusée',
      );
      _charger();
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    }
  }

  // ---------- Interface ----------
  @override
  Widget build(BuildContext context) {
    final nom = _conv.interlocuteur(_moi);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        // le client touche l'en-tête → profil du freelancer
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _suisClient
              ? () => ouvrirProfilFreelancer(
                  context,
                  freelancerId: _conv.freelancerId,
                  viewer: widget.user,
                )
              : null,
          child: Row(
            children: [
              UserAvatar(
                name: nom,
                isClient: _conv.interlocuteurEstClient(_moi),
                size: 36,
                withShadow: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$nom',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _conv.postTitre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_suisClient)
                      Tooltip(
                        message: 'CofeeCoins du freelancer',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_cafe_outlined,
                              size: 13,
                              color: AppColors.cyan,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${_conv.freelancerCofeeCoins}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.fieldBorder),
        ),
      ),
      body: Column(
        children: [
          _buildBandeauStatut(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.red),
                  )
                : _messages.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Aucun message',
                    message: 'Écris le premier message ci-dessous.',
                  )
                : _buildMessages(),
          ),
          _buildSaisie(),
        ],
      ),
    );
  }

  Widget _buildBandeauStatut() {
    final statut = _conv.statutCandidature;
    final enAttente = statut == 'en_attente';
    final (texte, couleur) = switch (statut) {
      'acceptee' => ('Candidature acceptée', AppColors.cyan),
      'refusee' => ('Candidature refusée : discussion fermée', AppColors.error),
      _ => (
        _suisClient
            ? 'Candidature en attente de ta réponse'
            : 'Candidature en attente de réponse du client',
        AppColors.textSecondary,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatutCandidatureChip(statut: statut),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texte,
                  style: TextStyle(fontSize: 12, color: couleur),
                ),
              ),
            ],
          ),
          // Le client peut décider directement depuis la discussion
          if (_suisClient && enAttente) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decider(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.fieldBorder),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decider(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    child: const Text('Accepter'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessages() {
    // Liste inversée : le message le plus récent est en bas
    final items = _messages.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        final precedent = i + 1 < items.length ? items[i + 1] : null;
        final nouveauJour =
            precedent == null || !_memeJour(precedent.dateEnvoi, m.dateEnvoi);
        return Column(
          children: [
            if (nouveauJour) _SeparateurJour(iso: m.dateEnvoi),
            _Bulle(
              message: m,
              deMoi: m.expediteurId == _moi,
              estCandidature: identical(m, _messages.first),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSaisie() {
    if (_conv.fermee) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.surface,
        child: const SafeArea(
          top: false,
          child: Text(
            'Tu ne peux plus envoyer de message dans cette discussion.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final vide = _controller.text.trim().isEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.fieldBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                maxLength: Validators.messageChatMax,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: AppColors.cyan,
                onChanged: (_) {
                  if (_erreurSaisie != null) {
                    setState(() => _erreurSaisie = null);
                  }
                },
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Écris ton message…',
                  errorText: _erreurSaisie,
                  // compteur seulement quand on approche de la limite
                  counterText:
                      _controller.text.length > Validators.messageChatMax - 100
                      ? null
                      : '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: IconButton.filled(
                tooltip: 'Envoyer',
                onPressed: vide || _envoi ? null : _envoyer,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.red,
                  disabledBackgroundColor: AppColors.fieldFill,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: AppColors.textMuted,
                  fixedSize: const Size(48, 48),
                ),
                icon: _envoi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _memeJour(String a, String b) {
    final da = DateTime.tryParse(a), db = DateTime.tryParse(b);
    if (da == null || db == null) return false;
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }
}

/// Bulle de message : à droite (rouge) pour moi, à gauche pour l'autre.
class _Bulle extends StatelessWidget {
  final Message message;
  final bool deMoi;
  final bool estCandidature; // 1er message = message de candidature

  const _Bulle({
    required this.message,
    required this.deMoi,
    required this.estCandidature,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(message.dateEnvoi);
    final heure = date == null
        ? ''
        : '${date.hour.toString().padLeft(2, '0')}:'
              '${date.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: deMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: deMoi ? AppColors.red : AppColors.surface,
            border: deMoi ? null : Border.all(color: AppColors.fieldBorder),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(deMoi ? 18 : 4),
              bottomRight: Radius.circular(deMoi ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (estCandidature)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Message de candidature',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: deMoi ? Colors.white70 : AppColors.cyan,
                    ),
                  ),
                ),
              SelectableText(
                message.contenu,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      heure,
                      style: TextStyle(
                        fontSize: 11,
                        color: deMoi ? Colors.white70 : AppColors.textMuted,
                      ),
                    ),
                    if (deMoi) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.lu
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 14,
                        color: message.lu ? AppColors.cyan : Colors.white70,
                        semanticLabel: message.lu ? 'Lu' : 'Envoyé',
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
}

class _SeparateurJour extends StatelessWidget {
  final String iso;
  const _SeparateurJour({required this.iso});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(iso);
    var texte = '';
    if (date != null) {
      final now = DateTime.now();
      final jour = DateTime(date.year, date.month, date.day);
      final aujourdHui = DateTime(now.year, now.month, now.day);
      final ecart = aujourdHui.difference(jour).inDays;
      texte = ecart == 0
          ? "Aujourd'hui"
          : ecart == 1
          ? 'Hier'
          : formatDate(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            texte,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
