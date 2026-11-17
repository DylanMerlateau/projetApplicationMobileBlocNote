import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';

class CloudService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Récupère le numéro de téléphone de l'utilisateur connecté
  static String? get currentUserPhone => _auth.currentUser?.phoneNumber;

  // Envoie ou met à jour une note sur Firestore avec le numéro du destinataire
  static Future<void> shareNoteWithPhone(Note note, String targetPhone) async {
    final myPhone = currentUserPhone;
    if (myPhone == null) return;

    // On s'assure que les deux numéros sont dans la liste des personnes autorisées
    final Set<String> updatedList = {...note.sharedWith, myPhone, targetPhone.trim()};
    note.sharedWith = updatedList.toList();

    await _db.collection('notes').doc(note.id).set(note.toMap());
  }

  // Met à jour le texte d'une note déjà partagée à chaque modification
  static Future<void> syncNoteUpdate(Note note) async {
    if (note.sharedWith.isEmpty || currentUserPhone == null) return;
    await _db.collection('notes').doc(note.id).update({
      'title': note.title,
      'content': note.content,
      'date': note.date,
    });
  }

  // Écoute en direct toutes les notes partagées avec notre numéro
  static Stream<List<Note>> listenToSharedNotes() {
    final myPhone = currentUserPhone;
    if (myPhone == null) return const Stream.empty();

    return _db
        .collection('notes')
        .where('sharedWith', arrayContains: myPhone)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Note.fromMap(doc.data())).toList());
  }
}