import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/test_competences.dart';

/// Le certificat au format PDF : génération, téléchargement et partage.
/// Tout se fait sur le téléphone, sans connexion.
class CertificatPdf {
  static const _mois = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static const _or = PdfColor.fromInt(0xFFC9A227);
  static const _cyan = PdfColor.fromInt(0xFF0FB5B0);
  static const _rouge = PdfColor.fromInt(0xFFEE1D52);
  static const _gris = PdfColor.fromInt(0xFF6B7280);
  static const _noir = PdfColor.fromInt(0xFF111111);

  static String nomFichier(Certification c) => 'certificat-${c.numero}.pdf';

  /// La police de l'application (Plus Jakarta Sans) : accents et « » bien
  /// rendus. Si elle ne se charge pas, le PDF garde la police par défaut.
  static Future<pw.ThemeData> _theme() async {
    Future<pw.Font> police(String nom) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$nom.ttf'));
    try {
      final bold = await police('PlusJakartaSans-Bold');
      return pw.ThemeData.withFont(
        base: await police('PlusJakartaSans-Regular'),
        bold: bold,
        italic: await police('PlusJakartaSans-Medium'),
        boldItalic: await police('PlusJakartaSans-ExtraBold'),
      );
    } catch (e) {
      debugPrint('[PDF] Police indisponible, police par défaut : $e');
      return pw.ThemeData();
    }
  }

  static String _date(String iso) {
    final d = DateTime.parse(iso);
    return '${d.day} ${_mois[d.month - 1]} ${d.year}';
  }

  // ---------- FONCTIONNALITÉ : générer le PDF ----------
  /// Une page A4 paysage, imprimable (fond blanc)
  static Future<Uint8List> generer(Certification c) async {
    final doc = pw.Document(
      theme: await _theme(),
      title: 'Certificat ${c.numero}',
      author: 'freelance',
      subject: 'Certificat de compétences de ${c.nomFreelancer}',
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _or, width: 3),
          ),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _cyan, width: 1),
            ),
            padding: const pw.EdgeInsets.fromLTRB(40, 26, 40, 22),
            child: pw.Column(
              children: [
                _logo(),
                pw.Spacer(), // espace réparti en haut et en bas
                pw.Text(
                  'CERTIFICAT DE COMPÉTENCES',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: _or,
                    letterSpacing: 3,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'Décerné à',
                  style: const pw.TextStyle(fontSize: 13, color: _gris),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '@${c.nomFreelancer}',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: _noir,
                  ),
                ),
                if (c.metier != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    c.metier!,
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: _cyan,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
                pw.SizedBox(height: 12),
                pw.Text(
                  'pour avoir réussi le test de compétences en '
                  '${c.domainesLisibles}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 13, color: _noir),
                ),
                pw.SizedBox(height: 18),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    _valeur('Score', '${c.score}/${c.total}'),
                    _valeur('Réussite', '${c.pourcentage} %'),
                    _valeur('Mention', c.mention),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF4F4F5),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Compétences validées',
                        style: const pw.TextStyle(fontSize: 10, color: _gris),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        c.competences,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Divider(color: const PdfColor.fromInt(0xFFE4E4E7)),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Délivré le ${_date(c.dateObtention)}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            'N° ${c.numero}',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'freelance',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                        pw.Text(
                          "L'équipe freelance",
                          style: const pw.TextStyle(fontSize: 10, color: _gris),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _logo() => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.center,
    children: [
      pw.Container(
        width: 34,
        height: 34,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: _noir,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: _rouge, width: 1.5),
        ),
        child: pw.Text(
          'F',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Text(
        'freelance',
        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );

  static pw.Widget _valeur(String titre, String valeur) => pw.Container(
    width: 140,
    child: pw.Column(
      children: [
        pw.Text(titre, style: const pw.TextStyle(fontSize: 10, color: _gris)),
        pw.SizedBox(height: 2),
        pw.Text(
          valeur,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  // ---------- FONCTIONNALITÉ : télécharger ----------
  /// Enregistre le PDF dans « Téléchargements » (Android) et renvoie le
  /// chemin du fichier. Si ce dossier n'est pas accessible, le fichier va
  /// dans le dossier de l'application.
  static Future<String> telecharger(
    Certification c, {
    Directory? dossier,
  }) async {
    final octets = await generer(c);
    final cibles = <Directory>[
      ?dossier,
      if (dossier == null && !kIsWeb && Platform.isAndroid)
        Directory('/storage/emulated/0/Download'),
    ];
    for (final d in cibles) {
      try {
        if (!await d.exists()) await d.create(recursive: true);
        final f = File('${d.path}/${nomFichier(c)}');
        await f.writeAsBytes(octets, flush: true);
        return f.path;
      } on FileSystemException catch (e) {
        debugPrint('[PDF] ${d.path} inaccessible : ${e.message}');
      }
    }
    final d = await getApplicationDocumentsDirectory();
    final f = File('${d.path}/${nomFichier(c)}');
    await f.writeAsBytes(octets, flush: true);
    return f.path;
  }

  // ---------- FONCTIONNALITÉ : partager / imprimer ----------
  static Future<void> partager(Certification c) async {
    await Printing.sharePdf(bytes: await generer(c), filename: nomFichier(c));
  }
}
