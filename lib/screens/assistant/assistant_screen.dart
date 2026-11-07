import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user.dart';
import '../../services/ai/assistant_service.dart';
import '../../services/ai/gemini_client.dart';
import '../../theme/app_theme.dart';

/// Ouvre l'assistant (user == null : visiteur sur l'écran de connexion)
Future<void> ouvrirAssistant(BuildContext context, {User? user}) {
  return Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => AssistantScreen(user: user)));
}

/// Chatbot d'aide sur l'application (Gemini). La conversation reste en
/// mémoire pendant que l'écran est ouvert.
class AssistantScreen extends StatefulWidget {
  final User? user;

  /// Remplaçable dans les tests
  final AssistantService? service;

  const AssistantScreen({super.key, this.user, this.service});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  late final AssistantService _service =
      widget.service ?? AssistantService(user: widget.user);
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<GeminiMessage> _messages = []; // échanges réussis
  bool _enCours = false;
  String? _erreur; // dernière erreur (avec bouton Réessayer)
  String? _questionEchouee;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------- FONCTIONNALITÉ : poser une question ----------
  Future<void> _envoyer([String? texte]) async {
    final question = (texte ?? _controller.text).trim();
    if (question.isEmpty || _enCours) return;
    if (question.length > AssistantService.questionMax) {
      setState(
        () => _erreur =
            'Question trop longue (${AssistantService.questionMax} caractères max.)',
      );
      return;
    }

    _controller.clear();
    setState(() {
      _messages.add(GeminiMessage.utilisateur(question));
      _enCours = true;
      _erreur = null;
      _questionEchouee = null;
    });
    _defilerEnBas();

    try {
      final reponse = await _service.repondre(List.of(_messages));
      if (!mounted) return;
      setState(() => _messages.add(GeminiMessage.assistant(reponse)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // la question sans réponse sort de l'historique (renvoyable)
        _messages.removeLast();
        _questionEchouee = question;
        _erreur = e is GeminiException
            ? e.message
            : 'Une erreur est survenue. Réessaie.';
      });
    } finally {
      if (mounted) setState(() => _enCours = false);
      _defilerEnBas();
    }
  }

  void _nouvelleConversation() {
    setState(() {
      _messages.clear();
      _erreur = null;
      _questionEchouee = null;
    });
  }

  void _defilerEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0, // liste inversée : 0 = le bas
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------- Interface ----------
  @override
  Widget build(BuildContext context) {
    final configure = _service.estConfigure;

    // éléments affichés du bas vers le haut (liste inversée)
    final elements = <Widget>[
      if (_erreur != null)
        _BulleErreur(
          message: _erreur!,
          onReessayer: _questionEchouee == null
              ? null
              : () => _envoyer(_questionEchouee),
        ),
      if (_enCours) const _BulleEcriture(),
      for (final m in _messages.reversed) _Bulle(message: m),
      _Accueil(
        user: widget.user,
        suggestions: _messages.isEmpty && configure
            ? _service.suggestions
            : const [],
        onSuggestion: _envoyer,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const Row(
          children: [
            _IconeAssistant(size: 36),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assistant',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    "Questions sur l'application",
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Nouvelle conversation',
              onPressed: _enCours ? null : _nouvelleConversation,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: elements,
              ),
            ),
            if (!configure)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  "L'assistant n'est pas configuré (clé API Gemini manquante).",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            _buildSaisie(configure),
          ],
        ),
      ),
    );
  }

  Widget _buildSaisie(bool configure) {
    final actif = configure && !_enCours;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.fieldBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: configure,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              inputFormatters: [
                LengthLimitingTextInputFormatter(AssistantService.questionMax),
              ],
              onSubmitted: (_) => _envoyer(),
              decoration: const InputDecoration(
                hintText: 'Pose ta question…',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Envoyer',
            onPressed: actif ? () => _envoyer() : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.red,
              disabledBackgroundColor: AppColors.fieldFill,
              fixedSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _IconeAssistant extends StatelessWidget {
  final double size;
  const _IconeAssistant({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.cyan, AppColors.red]),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size * 0.5,
        color: Colors.black,
      ),
    );
  }
}

/// Message d'accueil + questions suggérées
class _Accueil extends StatelessWidget {
  final User? user;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  const _Accueil({
    required this.user,
    required this.suggestions,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final salut = user == null ? 'Salut !' : 'Salut ${user!.username} !';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bulle(
          message: GeminiMessage.assistant(
            '$salut Je réponds à tes questions sur l\'application : '
            'publier, postuler, discuter, ton profil… Que veux-tu savoir ?',
          ),
        ),
        if (suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 38, bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => onSuggestion(s),
                    backgroundColor: AppColors.fieldFill,
                    side: const BorderSide(color: Color(0x5925F4EE)),
                    shape: const StadiumBorder(),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Bulle extends StatelessWidget {
  final GeminiMessage message;
  const _Bulle({required this.message});

  @override
  Widget build(BuildContext context) {
    final moi = message.deLUtilisateur;
    final bulle = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: moi ? AppColors.red : AppColors.surface,
        border: moi ? null : Border.all(color: AppColors.fieldBorder),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(moi ? 18 : 4),
          bottomRight: Radius.circular(moi ? 4 : 18),
        ),
      ),
      child: SelectableText(
        message.texte,
        style: const TextStyle(fontSize: 14, height: 1.45),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: moi
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!moi) ...[const _IconeAssistant(), const SizedBox(width: 10)],
          Flexible(child: bulle),
        ],
      ),
    );
  }
}

/// « L'assistant écrit… »
class _BulleEcriture extends StatelessWidget {
  const _BulleEcriture();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _IconeAssistant(),
          SizedBox(width: 10),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.cyan,
            ),
          ),
          SizedBox(width: 8),
          Text(
            "L'assistant écrit…",
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _BulleErreur extends StatelessWidget {
  final String message;
  final VoidCallback? onReessayer;
  const _BulleErreur({required this.message, this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0x1FFF6B8A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x59FF6B8A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
          ),
          if (onReessayer != null)
            TextButton(
              onPressed: onReessayer,
              child: const Text(
                'Réessayer',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
