import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../services/file_share_service.dart';

class SavedSetsScreen extends StatefulWidget {
  const SavedSetsScreen({super.key});

  static const routeName = '/saved-sets';

  @override
  State<SavedSetsScreen> createState() => _SavedSetsScreenState();
}

class _SavedSetsScreenState extends State<SavedSetsScreen> {
  bool _loading = true;
  String? _error;
  Directory? _setsDir;
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final docs = await getApplicationDocumentsDirectory();
      final setsDir = Directory(p.join(docs.path, 'sets'));
      _setsDir = setsDir;

      if (!await setsDir.exists()) {
        await setsDir.create(recursive: true);
      }

      final all = setsDir.listSync(followLinks: false);

      final csvs =
          all.where((e) {
            if (e is! File) return false;
            return e.path.toLowerCase().endsWith('.csv');
          }).toList();

      csvs.sort((a, b) {
        final am = a.statSync().modified;
        final bm = b.statSync().modified;
        return bm.compareTo(am);
      });

      setState(() {
        _files = csvs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _openPreview(File f) async {
    try {
      final lines = await f.readAsLines();
      final preview = lines.take(40).join('\n');

      if (!mounted) return;
      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(p.basename(f.path)),
              content: SingleChildScrollView(
                child: Text(
                  preview.isEmpty ? '(fichier vide)' : preview,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Echec de l apercu : $e')));
    }
  }

  Future<void> _deleteFile(File f) async {
    try {
      await f.delete();
      await _loadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Echec de la suppression : $e')));
    }
  }

  Future<void> _shareFile(File f) async {
    try {
      await FileShareService.shareCsvFile(
        f.path,
        context: context,
        text: 'Export CSV - ${p.basename(f.path)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Echec du partage du fichier : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Series sauvegardees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadFiles,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Erreur : $_error',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                : _files.isEmpty
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.folder_open,
                          color: Colors.white54,
                          size: 42,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Aucune serie sauvegardee pour le moment',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _setsDir == null
                              ? ''
                              : 'Dossier :\n${_setsDir!.path}',
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _loadFiles,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualiser'),
                        ),
                      ],
                    ),
                  ),
                )
                : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  itemCount: _files.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          'Dossier : ${_setsDir?.path ?? ''}',
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      );
                    }

                    final entity = _files[i - 1];
                    final file = entity as File;
                    final stat = file.statSync();
                    final name = p.basename(file.path);

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${_formatDate(stat.modified)} - ${_formatBytes(stat.size)}',
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        onTap: () => _openPreview(file),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white70,
                          ),
                          onSelected: (v) {
                            if (v == 'preview') _openPreview(file);
                            if (v == 'share') _shareFile(file);
                            if (v == 'delete') _deleteFile(file);
                          },
                          itemBuilder:
                              (_) => const [
                                PopupMenuItem(
                                  value: 'preview',
                                  child: Text('Apercu'),
                                ),
                                PopupMenuItem(
                                  value: 'share',
                                  child: Text('Telecharger / partager'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Supprimer'),
                                ),
                              ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
