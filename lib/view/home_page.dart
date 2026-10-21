import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/helper/contact_helper.dart';
import '../database/model/contact_model.dart';
import 'contact_avatar.dart';
import 'contact_page.dart';

enum OrderOptions { orderAZ, orderZA }

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.helper,
    this.recoveredContact,
    this.recoveryError,
  });
  final ContactHelper? helper;
  final Contact? recoveredContact;
  final String? recoveryError;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ContactHelper helper = widget.helper ?? ContactHelper();
  List<Contact> contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.recoveredContact != null) {
        _showContactPage(contact: widget.recoveredContact);
      } else if (widget.recoveryError != null) {
        _showError(widget.recoveryError!);
      }
    });
  }

  Future<void> _loadContacts() async {
    try {
      final list = await helper.getAllContacts();
      if (mounted) setState(() => contacts = list);
    } catch (_) {
      _showError('Não foi possível carregar os contatos.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Agenda de Contatos'),
      backgroundColor: Colors.blue,
      centerTitle: true,
      actions: [
        PopupMenuButton<OrderOptions>(
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: OrderOptions.orderAZ,
              child: Text('Ordenar de A-Z'),
            ),
            PopupMenuItem(
              value: OrderOptions.orderZA,
              child: Text('Ordenar de Z-A'),
            ),
          ],
          onSelected: _orderList,
        ),
      ],
    ),
    backgroundColor: Colors.white,
    floatingActionButton: FloatingActionButton(
      onPressed: () => _showContactPage(),
      backgroundColor: Colors.blue,
      child: const Icon(Icons.add),
    ),
    body: ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: contacts.length,
      itemBuilder: (context, index) => _contactCard(context, index),
    ),
  );

  Widget _contactCard(BuildContext context, int index) {
    final contact = contacts[index];
    return GestureDetector(
      onTap: () => _showOptions(context, contact),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ContactAvatar(path: contact.img, size: 80),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(contact.email, style: const TextStyle(fontSize: 18)),
                      Text(contact.phone, style: const TextStyle(fontSize: 18)),
                      if (contact.addressLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          contact.addressLabel,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showContactPage({Contact? contact}) async {
    final updatedContact = await Navigator.push<Contact>(
      context,
      MaterialPageRoute(
        builder: (context) => ContactPage(contact: contact, helper: helper),
      ),
    );
    if (updatedContact != null && mounted) await _loadContacts();
  }

  void _showOptions(BuildContext context, Contact contact) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              child: const Text(
                'Ligar',
                style: TextStyle(color: Colors.green, fontSize: 20),
              ),
              onPressed: () {
                Navigator.pop(sheetContext);
                _callContact(contact);
              },
            ),
            TextButton(
              child: const Text(
                'Editar',
                style: TextStyle(color: Colors.blue, fontSize: 20),
              ),
              onPressed: () {
                Navigator.pop(sheetContext);
                _showContactPage(contact: contact);
              },
            ),
            TextButton(
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.red, fontSize: 20),
              ),
              onPressed: () {
                Navigator.pop(sheetContext);
                _deleteContact(contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callContact(Contact contact) async {
    final number = contact.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    try {
      if (number.isEmpty ||
          !await launchUrl(Uri(scheme: 'tel', path: number))) {
        _showError('Não foi possível abrir o discador neste dispositivo.');
      }
    } catch (_) {
      _showError('Não foi possível abrir o discador neste dispositivo.');
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    if (contact.id == null) {
      _showError('Erro: ID do contato não encontrado.');
      return;
    }
    try {
      await helper.deleteContact(contact.id!);
      if (mounted) setState(() => contacts.remove(contact));
    } catch (_) {
      _showError('Não foi possível excluir o contato.');
    }
  }

  void _orderList(OrderOptions result) {
    setState(() {
      contacts.sort(
        (a, b) => result == OrderOptions.orderAZ
            ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
            : b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      );
    });
  }
}
