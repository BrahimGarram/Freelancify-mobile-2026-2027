import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/post_options.dart';
import '../../models/realisation.dart';
import '../../models/user.dart';
import '../../services/realisation_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/home_widgets.dart';

/// Formulaire du freelancer pour ajouter une réalisation à son portfolio
/// (projet, expérience, site réalisé…), avec ou sans photo.
/// Renvoie true si la réalisation a été publiée.
class PublierRealisationScreen extends StatefulWidget {
  final User user;
  const PublierRealisationScreen({super.key, required this.user});

  @override
  State<PublierRealisationScreen> createState() =>
      _PublierRealisationScreenState();
}

class _PublierRealisationScreenState extends State<PublierRealisationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _clientController = TextEditingController();
  final _lienController = TextEditingController();
  final _service = RealisationService();

  String? _categorie;
  String? _image; // chemin de la photo choisie (pas encore copiée)
  String? _erreurImage;
  bool _loading = false;

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _clientController.dispose();
    _lienController.dispose();
    super.dispose();
  }

  // ---------- FONCTIONNALITÉ : choisir une photo ----------
  Future<void> _choisirPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final fichier = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600, // photo redimensionnée : plus légère
        imageQuality: 85,
      );
      if (fichier == null) return; // annulé
      final erreur = Validators.image(
        fichier.path,
        await File(fichier.path).length(),
      );
      setState(() {
        _erreurImage = erreur;
        _image = erreur == null ? fichier.path : null;
      });
    } catch (e) {
      if (mounted) {
        showAppMessage(context, "Impossible d'ouvrir la photo", error: true);
      }
    }
  }

  // ---------- FONCTIONNALITÉ : publier ----------
  Future<void> _publier() async {
    FocusScope.of(context).unfocus();
    final valide = _formKey.currentState!.validate();
    if (!valide || _erreurImage != null) {
      showAppMessage(
        context,
        'Corrige les champs en rouge avant de publier',
        error: true,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.publier(
        Realisation(
          freelancerId: widget.user.id!,
          titre: _titreController.text,
          description: _descriptionController.text,
          categorie: _categorie!,
          client: _clientController.text,
          lien: _lienController.text,
          dateCreation: DateTime.now().toIso8601String(),
        ),
        imageSource: _image,
      );
      if (!mounted) return;
      showAppMessage(context, 'Réalisation ajoutée à ton portfolio !');
      Navigator.of(context).pop(true);
    } on RealisationException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Nouvelle réalisation',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Montre ton\ntravail.',
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Un projet, une expérience, un site sur lequel tu as '
                  'travaillé… Les clients le verront sur ton profil.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const FieldLabel('Photo', facultatif: true),
                _buildPhoto(),
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Titre',
                  hint: 'Site vitrine pour un restaurant',
                  controller: _titreController,
                  maxLength: Validators.titreMax,
                  validator: Validators.titreRealisation,
                ),
                const SizedBox(height: 16),
                ChoiceChipsField(
                  label: 'Catégorie',
                  options: PostOptions.categories,
                  icones: iconesCategories,
                  validator: Validators.choix(
                    PostOptions.categories,
                    'Choisis une catégorie',
                  ),
                  onChanged: (v) => _categorie = v,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Description',
                  hint: 'Ce que tu as fait, les outils utilisés, le résultat…',
                  controller: _descriptionController,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLength: Validators.descriptionMax,
                  validator: Validators.descriptionRealisation,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Client ou entreprise (facultatif)',
                  hint: 'Restaurant Le Golfe',
                  icon: Icons.business_outlined,
                  controller: _clientController,
                  maxLength: Validators.clientMax,
                  validator: Validators.clientRealisation,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Lien du projet (facultatif)',
                  hint: 'monsite.tn',
                  icon: Icons.link_rounded,
                  controller: _lienController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  maxLength: Validators.lienMax,
                  validator: Validators.lien,
                  onSubmitted: (_) => _publier(),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Publier la réalisation',
                  loading: _loading,
                  onPressed: _publier,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    final bord = _erreurImage != null ? AppColors.error : AppColors.fieldBorder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_image == null)
          Material(
            color: AppColors.fieldFill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: bord),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _choisirPhoto,
              child: const SizedBox(
                height: 140,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 34,
                      color: AppColors.cyan,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ajouter une photo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'jpg, png ou webp · 5 Mo max',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.file(
                    File(_image!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    cacheWidth: 1200,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton.filled(
                      tooltip: 'Changer la photo',
                      onPressed: _choisirPhoto,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xB3000000),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: 'Retirer la photo',
                      onPressed: () => setState(() => _image = null),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xB3000000),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (_erreurImage != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              _erreurImage!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
