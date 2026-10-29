import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:universal_html/html.dart' as html; 
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Application de Notes",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
      ),
      home: const NotesListScreen(),
    );
  }
}

class Note {
  String title;
  String content;
  String date;

  Note({required this.title, required this.content, required this.date});

  Map<String, dynamic> toMap() {
    return {'title': title, 'content': content, 'date': date};
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      date: map['date'] ?? '',
    );
  }
}

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Note> _notes = [];
   // --- À REMPLACER DANS LES VARIABLES DE VOTRE ÉCRAN ---
  // On définit le Bleu Marine (0xFF002244) par défaut
  Color _baseColor = const Color(0xFF002244); 
  // Valeur de la réglette (0.0 = Noir complet, 1.0 = Couleur pure, 2.0 = Blanc éclatant)
  double _colorIntensity = 1.0; 
  // La couleur finale qui sera appliquée à l'écran
  late Color _currentBackgroundColor;
  List<Note> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();

  static const String _noteSeparator = "==================== NOTE ====================";

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
    
    // ///////////////////////////////////////////////////////////////////////////
    // REPERE : INITIALISATION (AUTOUR DE LA LIGNE 65)
    // ///////////////////////////////////////////////////////////////////////////
    _currentBackgroundColor = _baseColor; // Calcule le fond initial au démarrage
  }

  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = List.from(_notes);
      } else {
        _filteredNotes = _notes.where((note) {
          final titleMatch = note.title.toLowerCase().contains(query);
          final contentMatch = note.content.toLowerCase().contains(query);
          return titleMatch || contentMatch;
        }).toList();
      }
    });
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('saved_notes');
    if (notesJson != null) {
      final List<dynamic> decodedList = jsonDecode(notesJson);
      _notes = decodedList.map((item) => Note.fromMap(item)).toList();
    } else {
      _notes = [
        Note(title: "⚡ Idées Flutter", content: "Ajouter des animations de transition.", date: "28 Oct"),
      ];
      _saveNotes();
    }
    _filterNotes();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _notes.map((note) => note.toMap()).toList();
    final String encodedData = jsonEncode(jsonList);
    await prefs.setString('saved_notes', encodedData);
  }

  Future<void> _exportNotesAsTxt() async {
    if (_notes.isEmpty) return;
    StringBuffer txtBuffer = StringBuffer();
    for (var note in _notes) {
      txtBuffer.write("\n$_noteSeparator\nTITRE : ${note.title}\nCONTENU :\n${note.content}\n");
    }
    List<int> bytes = utf8.encode(txtBuffer.toString());
    Uint8List nativeBytes = Uint8List.fromList(bytes);

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'text/plain');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)..setAttribute("download", "notes.txt")..click();
    } else {
      try {
        Uri? outputFile = await FilePicker.saveFile(
          dialogTitle: 'Choisir où enregistrer vos notes',
          fileName: 'notes.txt',
          type: FileType.custom,
          allowedExtensions: ['txt'],
          bytes: nativeBytes,
        );
        if (outputFile != null) {
          _showSnackBar("Fichier enregistré avec succès !");
        }
      } catch (_) {}
    }
  }

  Future<void> _importNotesFromTxt() async {
    try {
      List<PlatformFile> files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
      if (files.isNotEmpty) {
        final file = files.first;
        final fileContent = utf8.decode(await file.readAsBytes());
        setState(() {
          _notes.add(Note(title: file.name.split('.').first, content: fileContent, date: '28 Oct'));
        });
        await _saveNotes();
        _searchController.clear();
        _filterNotes();
        _showSnackBar("Importé avec succès !");
      }
    } catch (_) {}
  }

   void _updateColorLighting(double value) {
    setState(() {
      _colorIntensity = value;
      if (value < 1.0) {
        // Mode sombre : On fusionne progressivement la couleur avec du noir
        _currentBackgroundColor = Color.lerp(Colors.black, _baseColor, value)!;
      } else {
        // Mode clair : On fusionne progressivement la couleur avec du blanc
        _currentBackgroundColor = Color.lerp(_baseColor, Colors.white, value - 1.0)!;
      }
    });
  } // <-- CETTE ACCOLADE ÉTAIT MANQUANTE ET CAUSAIT LE SOULIGNEMENT ROUGE

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _currentBackgroundColor,
      appBar: AppBar(
        title: const Text('Mes Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _currentBackgroundColor,
        elevation: 0, // Fusionne l'AppBar avec le fond pour un rendu plus propre
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _importNotesFromTxt),
          IconButton(icon: const Icon(Icons.file_upload), onPressed: _exportNotesAsTxt),
          
          // Sélecteur pour changer la teinte de base
          PopupMenuButton<Color>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Choisir la teinte de base',
            onSelected: (Color selectedColor) {
              _baseColor = selectedColor;
              _updateColorLighting(_colorIntensity); // Recalcule instantanément le fond
            },
            itemBuilder: (b) => [
              const PopupMenuItem(value: Color(0xFFFFF8E1), child: Text('Jaune')),
              const PopupMenuItem(value: Color(0xFF002244), child: Text('Bleu Marine')),
              const PopupMenuItem(value: Color(0xFFE8F5E9), child: Text('Vert')),
            ],
          ),
          
          // La réglette manuelle intégrée (Slider)
          Container(
            width: 130, // Taille optimisée pour ne pas déborder sur les smartphones
            padding: const EdgeInsets.only(right: 8),
            child: Slider(
              value: _colorIntensity,
              min: 0.2, // Limite pour ne pas atteindre le noir complet
              max: 1.8, // Limite pour ne pas atteindre le blanc pur
              activeColor: Colors.white,
              inactiveColor: Colors.white.withOpacity(0.3),
              onChanged: (double value) {
                _updateColorLighting(value); // Applique le gamma en temps réel
              },
            ),
          ),
        ],
      ),
      // Le reste de votre structure (body: Column, etc.) reste inchangé...

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              controller: _searchController,
              hintText: "Rechercher...",
              leading: const Icon(Icons.search),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredNotes.length,
              itemBuilder: (context, index) {
                final note = _filteredNotes[index];
                
                return Dismissible(
                  key: Key(note.title + note.date + index.toString()), // Clé unique pour Flutter
                  direction: DismissDirection.endToStart, // Autorise le balayage uniquement de la droite vers la gauche
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    // Petite pop-up de confirmation système avant suppression brute
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Supprimer la note ?"),
                          content: Text("Êtes-vous sûr de vouloir supprimer '${note.title}' ?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("Annuler"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) async {
                    // 1. On trouve l'index réel de la note dans la liste principale non filtrée
                    final int realIndex = _notes.indexOf(note);
                    
                    if (realIndex != -1) {
                      // 2. On garde une copie de la note en mémoire au cas où l'utilisateur annule
                      final Note backupNote = _notes[realIndex];

                      setState(() {
                        _notes.removeAt(realIndex); // Supprime de la liste principale
                        _filterNotes(); // Rafraîchit instantanément l'affichage filtré
                      });
                      
                      // 3. Met à jour la mémoire interne du smartphone
                      await _saveNotes();

                      // 4. Affiche un bandeau en bas avec un bouton "ANNULER"
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars(); // Nettoie les anciennes alertes
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Note '${backupNote.title}' supprimée"),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: "ANNULER",
                              onPressed: () async {
                                // Si l'utilisateur clique sur Annuler, on réinsère la note au même endroit
                                setState(() {
                                  _notes.insert(realIndex, backupNote);
                                  _filterNotes();
                                });
                                await _saveNotes(); // On resauvegarde
                              },
                            ),
                          ),
                        );
                      }
                    }
                  },
                  // Votre carte graphique d'origine vient s'imbriquer à l'intérieur ici :
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        note.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onTap: () async {
                        final edited = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => NoteFormScreen(note: note)),
                        );
                        if (edited != null) {
                          final realIdx = _notes.indexOf(note);
                          if (realIdx != -1) {
                            setState(() {
                              _notes[realIdx] = edited;
                            });
                            _saveNotes();
                            _filterNotes();
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final newNote = await Navigator.push(context, MaterialPageRoute(builder: (c) => const NoteFormScreen()));
          if (newNote != null) {
            setState(() { _notes.add(newNote); });
            _saveNotes(); _filterNotes();
          }
        },
      ),
    );
  }
}

class NoteFormScreen extends StatefulWidget {
  final Note? note;
  const NoteFormScreen({super.key, this.note});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isEditing = widget.note != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la note' : 'Nouvelle note'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Contenu de la note',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () {
                final String title = _titleController.text.trim();
                final String content = _contentController.text.trim();

                if (title.isNotEmpty && content.isNotEmpty) {
                  if (isEditing) {
                    widget.note!.title = title;
                    widget.note!.content = content;
                    widget.note!.date = '28 Oct (Modifié)';
                    Navigator.pop(context, widget.note);
                  } else {
                    final Note newNote = Note(
                      title: title,
                      content: content,
                      date: '28 Oct',
                    );
                    Navigator.pop(context, newNote);
                  }
                }
              },
              child: Text(isEditing ? 'Enregistrer les modifications' : 'Créer la note'),
            ),
          ],
        ),
      ),
    );
  }
}