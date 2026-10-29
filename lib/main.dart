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
  Color _baseColor = const Color(0xFF002244); 
  double _colorIntensity = 1.0; 
  late Color _currentBackgroundColor;
  List<Note> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();

  static const String _noteSeparator = "==================== NOTE ====================";

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
    _currentBackgroundColor = _baseColor; 
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
        Note(title: "⚡ Idées Flutter", content: "Ajouter des animations de transition.", date: "29 Oct 2026, 15:49"),
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
      txtBuffer.write("\n$_noteSeparator\nTITRE : ${note.title}\nDATE : ${note.date}\nCONTENU :\n${note.content}\n");
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
        
        final now = DateTime.now();
        final List<String> months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
        final String minuteStr = now.minute < 10 ? '0${now.minute}' : '${now.minute}';
        final String currentTimestamp = "${now.day} ${months[now.month - 1]} ${now.year}, ${now.hour}:$minuteStr";

        setState(() {
          _notes.add(Note(
            title: file.name.split('.').first, 
            content: fileContent, 
            date: currentTimestamp,
          ));
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
        _currentBackgroundColor = Color.lerp(Colors.black, _baseColor, value)!;
      } else {
        _currentBackgroundColor = Color.lerp(_baseColor, Colors.white, value - 1.0)!;
      }
    });
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
      backgroundColor: _currentBackgroundColor,
      appBar: AppBar(
        title: const Text('Mes Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _currentBackgroundColor,
        elevation: 0, 
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _importNotesFromTxt),
          IconButton(icon: const Icon(Icons.file_upload), onPressed: _exportNotesAsTxt),
          PopupMenuButton<Color>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Choisir la teinte de base',
            onSelected: (Color selectedColor) {
              _baseColor = selectedColor;
              _updateColorLighting(_colorIntensity); 
            },
            itemBuilder: (b) => [
              const PopupMenuItem(value: Color(0xFFFFF8E1), child: Text('Jaune')),
              const PopupMenuItem(value: Color(0xFF002244), child: Text('Bleu Marine')),
              const PopupMenuItem(value: Color(0xFFE8F5E9), child: Text('Vert')),
            ],
          ),
          Container(
            width: 130, 
            padding: const EdgeInsets.only(right: 8),
            child: Slider(
              value: _colorIntensity,
              min: 0.2, 
              max: 1.8, 
              activeColor: Colors.white,
              inactiveColor: Colors.white.withOpacity(0.3),
              onChanged: (double value) {
                _updateColorLighting(value); 
              },
            ),
          ),
        ],
      ),
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
            child: _filteredNotes.isEmpty
                ? Center(
                    child: Text(
                      _notes.isEmpty ? 'Aucune note pour le moment' : 'Aucun résultat trouvé',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      
                      return Dismissible(
                        key: Key(note.title + note.date + index.toString()), 
                        direction: DismissDirection.endToStart, 
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
                          final int realIndex = _notes.indexOf(note);
                          if (realIndex != -1) {
                            final Note backupNote = _notes[realIndex];
                            setState(() {
                              _notes.removeAt(realIndex); 
                              _filterNotes(); 
                            });
                            await _saveNotes();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars(); 
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Note '${backupNote.title}' supprimée"),
                                  behavior: SnackBarBehavior.floating,
                                  action: SnackBarAction(
                                    label: "ANNULER",
                                    onPressed: () async {
                                      setState(() {
                                        _notes.insert(realIndex, backupNote);
                                        _filterNotes();
                                      });
                                      await _saveNotes(); 
                                    },
                                  ),
                                ),
                              );
                            }
                          }
                        },
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
                            trailing: Text(
                              note.date,
                              style: TextStyle(color: theme.colorScheme.outline, fontSize: 11),
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
                  final now = DateTime.now();
                  final List<String> months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
                  final String minuteStr = now.minute < 10 ? '0${now.minute}' : '${now.minute}';
                  final String currentTimestamp = "${now.day} ${months[now.month - 1]} ${now.year}, ${now.hour}:$minuteStr";

                  if (isEditing) {
                    widget.note!.title = title;
                    widget.note!.content = content;
                    widget.note!.date = currentTimestamp; 
                    Navigator.pop(context, widget.note);
                  } else {
                    final Note newNote = Note(
                      title: title,
                      content: content,
                      date: currentTimestamp, 
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