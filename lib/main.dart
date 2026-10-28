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
    return {
      'title': title,
      'content': content,
      'date': date,
    };
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
  List<Note> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();

  static const String _noteSeparator = "\n==================== NOTE ====================\n";

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
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
        Note(title: "⚡ Idées Flutter", content: "Ajouter des animations de transition et un mode sombre à l'application.", date: "28 Oct"),
        Note(title: "🛒 Liste de courses", content: "Pain complet, lait d'amande, fruits de saison, café en grains.", date: "28 Oct"),
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
    if (_notes.isEmpty) {
      _showSnackBar("Aucune note à exporter.");
      return;
    }

    StringBuffer txtBuffer = StringBuffer();
    txtBuffer.write("--- EXPORT DE MES NOTES ---\n");

    for (var note in _notes) {
      txtBuffer.write(_noteSeparator);
      txtBuffer.write("TITRE : \${note.title}\n");
      txtBuffer.write("DATE : \${note.date}\n");
      txtBuffer.write("CONTENU :\n\${note.content}\n");
    }

    String txtString = txtBuffer.toString();
    List<int> bytes = utf8.encode(txtString);
    Uint8List nativeBytes = Uint8List.fromList(bytes);

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'text/plain');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "mes_notes.txt")
        ..click();
      html.Url.revokeObjectUrl(url);
      _showSnackBar("Notes téléchargées !");
    } else {
      try {
        Uri? outputFile = await FilePicker.saveFile(
          dialogTitle: 'Choisir où enregistrer vos notes',
          fileName: 'mes_notes.txt',
          type: FileType.custom,
          allowedExtensions: ['txt'],
          bytes: nativeBytes, 
        );

        if (outputFile != null) {
          _showSnackBar("Fichier enregistré avec succès !");
        } else {
          _showSnackBar("Exportation annulée.");
        }
      } catch (e) {
        _showSnackBar("Erreur lors du choix du dossier : \$e");
      }
    }
  }

  Future<void> _importNotesFromTxt() async {
    try {
      List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final fileBytes = await file.readAsBytes();
        final fileContent = utf8.decode(fileBytes);
        
        List<String> rawNotes = fileContent.split(_noteSeparator);
        if (rawNotes.isNotEmpty) rawNotes.removeAt(0);

        List<Note> importedNotes = [];

        for (String rawNote in rawNotes) {
          if (rawNote.trim().isEmpty) continue;

          List<String> lines = rawNote.split('\n');
          String title = "";
          String date = "";
          StringBuffer contentBuffer = StringBuffer();
          bool readingContent = false;

          for (String line in lines) {
            if (line.startsWith("TITRE : ")) {
              title = line.replaceFirst("TITRE : ", "").trim();
            } else if (line.startsWith("DATE : ")) {
              date = line.replaceFirst("DATE : ", "").trim();
            } else if (line.startsWith("CONTENU :")) {
              readingContent = true;
            } else if (readingContent) {
              contentBuffer.writeln(line);
            }
          }

          if (title.isNotEmpty) {
            importedNotes.add(Note(
              title: title,
              content: contentBuffer.toString().trim(),
              date: date.isEmpty ? '28 Oct' : date,
            ));
          }
        }

        if (importedNotes.isEmpty) throw Exception();

        setState(() {
          _notes = importedNotes;
        });
        
        _saveNotes();
        _filterNotes();
        _showSnackBar("Notes importées avec succès !");
      }
    } catch (e) {
      _showSnackBar("Erreur lors de l'importation du fichier.");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.2),
      appBar: AppBar(
        title: const Text('Mes Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Importer',
            onPressed: _importNotesFromTxt,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Exporter',
            onPressed: _exportNotesAsTxt,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              controller: _searchController,
              hintText: "Rechercher une note...",
              leading: const Icon(Icons.search),
              trailing: _searchController.text.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    ]
                  : null,
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHigh),
            ),
          ),
          
          Expanded(
            child: _filteredNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          _notes.isEmpty ? 'Aucune note pour le moment' : 'Aucun résultat trouvé',
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      return Card(
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
                          trailing: Text(
                            note.date,
                            style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                          ),
                          onTap: () async {
                            final Note? editedNote = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => NoteFormScreen(note: note)),
                            );
                            if (editedNote != null) {
                              final realIndex = _notes.indexOf(note);
                              if (realIndex != -1) {
                                setState(() {
                                  _notes[realIndex] = editedNote;
                                });
                                _saveNotes();
                                _filterNotes();
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: const Icon(Icons.add),
        onPressed: () async {
          final Note? newNote = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NoteFormScreen()),
          );
          if (newNote != null) {
            setState(() {
              _notes.add(newNote);
            });
            _saveNotes();
            _searchController.clear();
            _filterNotes();
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
