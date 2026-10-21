import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apk_agenda_bd_local/database/helper/contact_helper.dart';
import 'package:apk_agenda_bd_local/database/model/contact_model.dart';
import 'package:apk_agenda_bd_local/services/cep_service.dart';
import 'package:apk_agenda_bd_local/services/contact_photo_service.dart';
import 'package:apk_agenda_bd_local/utils/email_input.dart';
import 'package:apk_agenda_bd_local/view/contact_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestPaths extends PathProviderPlatform {
  TestPaths(this.path);
  final String path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

class TestPicker extends ImagePicker {
  String? path;
  ImageSource? source;
  bool denied = false;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    if (denied) throw PlatformException(code: 'camera_access_denied');
    return path == null ? null : XFile(path!);
  }
}

class TestPhotos extends ContactPhotoService {
  TestPhotos(ImagePicker picker) : super(picker: picker);
  @override
  bool get supportsCamera => true;
}

class PendingCep extends CepService {
  final requests = <String, Completer<PostalAddress>>{};
  @override
  Future<PostalAddress> lookup(String cep) =>
      (requests[cep] = Completer<PostalAddress>()).future;
}

const address = PostalAddress(
  street: 'Praça da Sé',
  neighborhood: 'Sé',
  city: 'São Paulo',
  uf: 'SP',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'Email formatting preserves local part and validates common addresses',
    () {
      expect(
        formatEmail(' Joao.Silva+tag @EXAMPLE.COM '),
        'Joao.Silva+tag@example.com',
      );
      final value = EmailInputFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: ' A@EXAMPLE.COM ',
          selection: TextSelection.collapsed(offset: 15),
        ),
      );
      expect(value.text, 'A@example.com');
      expect(value.selection.baseOffset, 13);
      for (final email in [
        'ana@example.com',
        "joao.o'neil+tag@exemplo.com.br",
        'a@sub.example.com',
      ]) {
        expect(isValidEmail(email), isTrue, reason: email);
      }
      for (final email in [
        '',
        'ana',
        'a@@b.com',
        '.a@b.com',
        'a..b@c.com',
        'a@-b.com',
        'a@b-.com',
        'a@b',
        'a@b.c',
        'a@b..com',
        'a b@c.com',
        'a@b.123',
      ]) {
        expect(isValidEmail(email), isFalse, reason: email);
      }
    },
  );

  test('ViaCEP validates request and decodes UTF-8, not-found, HTTP and malformed responses', () async {
    var calls = 0;
    final success = CepService(
      client: MockClient((request) async {
        calls++;
        expect(
          request.url.toString(),
          'https://viacep.com.br/ws/01001000/json/',
        );
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'logradouro': 'Praça da Sé',
              'bairro': 'Sé',
              'localidade': 'São Paulo',
              'uf': 'SP',
              'complemento': 'lado ímpar',
            }),
          ),
          200,
        );
      }),
    );
    await expectLater(success.lookup('123'), throwsA(isA<CepException>()));
    expect(calls, 0);
    final result = await success.lookup('01001-000');
    expect(result.street, 'Praça da Sé');
    expect(result.city, 'São Paulo');
    for (final response in [
      http.Response('{"erro":true}', 200),
      http.Response('{"erro":"true"}', 200),
      http.Response('unavailable', 503),
      http.Response('invalid', 200),
      http.Response('[]', 200),
      http.Response('{}', 200),
    ]) {
      await expectLater(
        CepService(client: MockClient((_) async => response))
            .lookup('99999999'),
        throwsA(isA<CepException>()),
      );
    }
    await expectLater(
      CepService(
        client: MockClient((_) async => throw const SocketException('offline')),
      ).lookup('01001000'),
      throwsA(isA<CepException>()),
    );
    await expectLater(
      CepService(
        client: MockClient((_) async => throw TimeoutException('timeout')),
      ).lookup('01001000'),
      throwsA(isA<CepException>()),
    );
    await expectLater(
      CepService(
        client: MockClient((_) async => throw const HandshakeException('TLS')),
      ).lookup('01001000'),
      throwsA(isA<CepException>()),
    );
  });

  test('Database v1 migrates without data loss and retains all address fields after reopening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'agenda-migration-',
    );
    final path = '${directory.path}/contactsDB.db';
    var db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE contactTable('
          'idColumn INTEGER PRIMARY KEY, nameColumn TEXT, emailColumn TEXT, phoneColumn TEXT, imgColumn TEXT)',
        ),
      ),
    );
    await db.insert(contactTable, {
      nameColumn: 'Contato antigo',
      emailColumn: 'antigo@example.com',
      phoneColumn: '(42) 99999-8888',
      imgColumn: null,
    });
    await db.close();
    Future<Database> open() => databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: ContactHelper.schemaVersion,
        onUpgrade: ContactHelper.upgradeDatabase,
      ),
    );
    var helper = ContactHelper.withDatabase(await open());
    try {
      final old = (await helper.getAllContacts()).single;
      expect(old.name, 'Contato antigo');
      expect(old.addressLabel, isEmpty);
      old.cep = '01001-000';
      old.street = 'Praça da Sé';
      old.neighborhood = 'Sé';
      old.city = 'São Paulo';
      old.uf = 'SP';
      old.number = '123A';
      old.complement = 'Apto 4';
      old.img = '/photos/persistent.jpg';
      await helper.updateContact(old);
      await helper.close();
      helper = ContactHelper.withDatabase(await open());
      expect((await helper.getContact(old.id!))!.toMap(), old.toMap());
      expect(
        (await helper.getAllContacts()).single.addressLabel,
        contains('123A, Apto 4'),
      );
    } finally {
      await helper.close();
      await directory.delete(recursive: true);
    }
  });

  test('Camera and gallery sources reach picker; photo survives removal of temporary original', () async {
    final directory = await Directory.systemTemp.createTemp('agenda-photo-');
    final originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths('${directory.path}/support');
    try {
      final original = await File('assets/imgs/image.png')
          .copy('${directory.path}/capture.png');
      final picker = TestPicker()..path = original.path;
      final photos = ContactPhotoService(picker: picker);
      final contact = Contact(
        name: 'Foto',
        email: 'foto@example.com',
        phone: '',
        img: null,
      );
      for (final source in [ImageSource.camera, ImageSource.gallery]) {
        final selected = await photos.pick(contact, source);
        expect(picker.source, source);
        expect(selected!.path, original.path);
      }
      final saved = await photos.persist(original.path);
      final bytes = await original.readAsBytes();
      await original.delete();
      expect(await File(saved).readAsBytes(), bytes);
      expect(await photos.persist(saved), saved);
      picker.path = null;
      expect(await photos.pick(contact, ImageSource.camera), isNull);
      picker.denied = true;
      await expectLater(
        photos.pick(contact, ImageSource.camera),
        throwsA(isA<PlatformException>()),
      );
    } finally {
      PathProviderPlatform.instance = originalPaths;
      await directory.delete(recursive: true);
    }
  });

  Future<ContactHelper> helper() async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    await ContactHelper.createTable(db);
    final result = ContactHelper.withDatabase(db);
    addTearDown(result.close);
    return result;
  }

  Future<void> openPage(WidgetTester tester, ContactPage page) async {
    tester.view.physicalSize = const Size(420, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => page),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Invalid email blocks creation and editing; correction and address persist',
    (tester) async {
      final db = await helper();
      final cep = PendingCep();
      await openPage(tester, ContactPage(helper: db, cepService: cep));
      await tester.enterText(find.byKey(const Key('name')), 'Maria');
      await tester.enterText(find.byKey(const Key('email')), 'invalido');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      expect(find.text('Informe um e-mail válido.'), findsWidgets);
      expect(await db.getAllContacts(), isEmpty);
      await tester.enterText(
        find.byKey(const Key('email')),
        ' Maria@EXAMPLE.COM ',
      );
      await tester.ensureVisible(find.byKey(const Key('cep')));
      await tester.enterText(find.byKey(const Key('cep')), '01001000');
      await tester.pump();
      expect(cep.requests.keys, ['01001000']);
      cep.requests['01001000']!.complete(address);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('street')))
            .controller!
            .text,
        'Praça da Sé',
      );
      await tester.ensureVisible(find.byKey(const Key('number')));
      await tester.enterText(find.byKey(const Key('number')), '123A');
      await tester.enterText(find.byKey(const Key('complement')), 'Apto 4');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      final contact = (await db.getAllContacts()).single;
      expect(contact.email, 'Maria@example.com');
      expect(contact.cep, '01001-000');
      expect(contact.street, 'Praça da Sé');
      expect(contact.number, '123A');
      expect(contact.complement, 'Apto 4');
      await openPage(tester, ContactPage(contact: contact, helper: db));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('complement')))
            .controller!
            .text,
        'Apto 4',
      );
      await tester.enterText(find.byKey(const Key('email')), 'a@@b.com');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      expect((await db.getContact(contact.id!))!.email, 'Maria@example.com');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Changing CEP ignores stale response and network errors permit retry',
    (tester) async {
      final cep = PendingCep();
      await openPage(
        tester,
        ContactPage(helper: await helper(), cepService: cep),
      );
      await tester.ensureVisible(find.byKey(const Key('cep')));
      await tester.enterText(find.byKey(const Key('cep')), '01001000');
      await tester.pump();
      final first = cep.requests['01001000']!;
      await tester.enterText(find.byKey(const Key('cep')), '80010000');
      await tester.pump();
      cep.requests['80010000']!.complete(
        const PostalAddress(
          street: 'Rua XV',
          neighborhood: 'Centro',
          city: 'Curitiba',
          uf: 'PR',
        ),
      );
      await tester.pumpAndSettle();
      first.complete(address);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('city')))
            .controller!
            .text,
        'Curitiba',
      );
      await tester.tap(find.byTooltip('Consultar CEP'));
      await tester.pump();
      cep.requests['80010000']!.completeError(
        const CepException('Sem conexão. Tente novamente.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão. Tente novamente.'), findsOneWidget);
      await tester.tap(find.byTooltip('Consultar CEP'));
      await tester.pump();
      cep.requests['80010000']!.complete(address);
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão. Tente novamente.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Photo menu offers camera and gallery and handles denied access',
    (tester) async {
      final picker = TestPicker()..denied = true;
      await openPage(
        tester,
        ContactPage(helper: await helper(), photoService: TestPhotos(picker)),
      );
      await tester.tap(find.text('Adicionar ou alterar foto'));
      await tester.pumpAndSettle();
      expect(find.text('Selecionar da galeria'), findsOneWidget);
      await tester.tap(find.text('Tirar foto'));
      await tester.pumpAndSettle();
      expect(picker.source, ImageSource.camera);
      expect(find.textContaining('Acesso à câmera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
