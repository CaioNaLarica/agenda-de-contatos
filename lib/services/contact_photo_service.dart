import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/model/contact_model.dart';

class ContactPhotoService {
  ContactPhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  bool get supportsCamera => Platform.isAndroid || Platform.isIOS;

  Future<File> _draftFile() async => File(
    p.join(
      (await getApplicationSupportDirectory()).path,
      'pending-photo-contact.json',
    ),
  );

  Future<XFile?> pick(Contact contact, ImageSource source) async {
    File? draft;
    if (Platform.isAndroid) {
      draft = await _draftFile();
      await draft.parent.create(recursive: true);
      await draft.writeAsString(jsonEncode(contact.toMap()), flush: true);
    }
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } finally {
      if (draft != null && await draft.exists()) await draft.delete();
    }
  }

  Future<Contact?> recover() async {
    if (!Platform.isAndroid) return null;
    final draft = await _draftFile();
    try {
      final response = await _picker.retrieveLostData();
      if (response.exception != null) throw response.exception!;
      if (response.files == null || response.files!.isEmpty) return null;
      final contact = await draft.exists()
          ? Contact.fromMap(
              jsonDecode(await draft.readAsString()) as Map<String, dynamic>,
            )
          : Contact(name: '', email: '', phone: '', img: null);
      contact.img = response.files!.first.path;
      return contact;
    } finally {
      if (await draft.exists()) await draft.delete();
    }
  }

  Future<String> persist(String source) async {
    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'photos'),
    );
    await directory.create(recursive: true);
    if (p.isWithin(directory.path, source)) return source;
    final target = p.join(
      directory.path,
      '${DateTime.now().microsecondsSinceEpoch}${p.extension(source)}',
    );
    return (await File(source).copy(target)).path;
  }
}
