import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../database/helper/contact_helper.dart';
import '../database/model/contact_model.dart';
import '../services/cep_service.dart';
import '../services/contact_photo_service.dart';
import '../utils/email_input.dart';
import 'contact_avatar.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({
    super.key,
    this.contact,
    this.helper,
    this.cepService,
    this.photoService,
  });
  final Contact? contact;
  final ContactHelper? helper;
  final CepService? cepService;
  final ContactPhotoService? photoService;

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  late final Contact _editContact;
  late final ContactHelper _helper = widget.helper ?? ContactHelper();
  late final CepService _cepService = widget.cepService ?? CepService();
  late final ContactPhotoService _photos =
      widget.photoService ?? ContactPhotoService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _ufController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  late final MaskTextInputFormatter phoneMask;
  late final MaskTextInputFormatter cepMask;
  bool _saving = false;
  bool _pickingPhoto = false;
  bool _lookingUp = false;
  int _lookupSerial = 0;
  String? _emailError;
  String? _cepError;

  @override
  void initState() {
    super.initState();
    _editContact = widget.contact == null
        ? Contact(name: '', email: '', phone: '', img: null)
        : Contact.fromMap(widget.contact!.toMap());
    _nameController.text = _editContact.name;
    _emailController.text = _editContact.email;
    phoneMask = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {'#': RegExp(r'[0-9]')},
      initialText: _editContact.phone,
    );
    _phoneController.text = phoneMask.getMaskedText();
    cepMask = MaskTextInputFormatter(
      mask: '#####-###',
      filter: {'#': RegExp(r'[0-9]')},
      initialText: _editContact.cep,
    );
    _cepController.text = cepMask.getMaskedText();
    _streetController.text = _editContact.street;
    _neighborhoodController.text = _editContact.neighborhood;
    _cityController.text = _editContact.city;
    _ufController.text = _editContact.uf;
    _numberController.text = _editContact.number;
    _complementController.text = _editContact.complement;
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _emailController,
      _phoneController,
      _cepController,
      _streetController,
      _neighborhoodController,
      _cityController,
      _ufController,
      _numberController,
      _complementController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.blue,
      centerTitle: true,
      title: Text(
        _editContact.name.isEmpty ? 'Novo Contato' : _editContact.name,
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _saving || _lookingUp || _pickingPhoto ? null : _saveContact,
      backgroundColor: Colors.blue,
      tooltip: 'Salvar contato',
      child: _saving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
    ),
    body: AbsorbPointer(
      absorbing: _saving || _pickingPhoto,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 96),
        child: Column(
          children: [
            GestureDetector(
              onTap: _choosePhoto,
              child: Semantics(
                button: true,
                label: 'Alterar foto do contato',
                child: ContactAvatar(path: _editContact.img, size: 140),
              ),
            ),
            TextButton.icon(
              onPressed: _choosePhoto,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Adicionar ou alterar foto'),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              onChanged: (text) => setState(() => _editContact.name = text),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('email'),
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'nome@exemplo.com',
                errorText: _emailError,
              ),
              inputFormatters: [EmailInputFormatter()],
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              onChanged: (text) {
                _editContact.email = text;
                if (_emailError != null) {
                  setState(
                    () => _emailError = isValidEmail(text)
                        ? null
                        : 'Informe um e-mail válido.',
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('phone'),
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,
              inputFormatters: [phoneMask],
            ),
            const SizedBox(height: 28),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Endereço',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('cep'),
              controller: _cepController,
              decoration: InputDecoration(
                labelText: 'CEP',
                hintText: '00000-000',
                errorText: _cepError,
                helperText: 'Informe o CEP para preencher o endereço.',
                suffixIcon: _lookingUp
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Consultar CEP',
                        onPressed: _lookupCep,
                        icon: const Icon(Icons.search),
                      ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [cepMask],
              onChanged: (_) {
                _lookupSerial++;
                _streetController.clear();
                _neighborhoodController.clear();
                _cityController.clear();
                _ufController.clear();
                setState(() {
                  _cepError = null;
                  _lookingUp = false;
                });
                if (cepMask.getUnmaskedText().length == 8) _lookupCep();
              },
              onSubmitted: (_) => _lookupCep(),
            ),
            _addressField('Logradouro', 'street', _streetController),
            _addressField('Bairro', 'neighborhood', _neighborhoodController),
            _addressField('Cidade', 'city', _cityController),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: TextField(
                key: const Key('uf'),
                controller: _ufController,
                enabled: !_lookingUp,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) =>
                        newValue.copyWith(text: newValue.text.toUpperCase()),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Estado/UF',
                  counterText: '',
                ),
              ),
            ),
            _addressField('Número', 'number', _numberController),
            _addressField('Complemento', 'complement', _complementController),
          ],
        ),
      ),
    ),
  );

  Widget _addressField(
    String label,
    String keyName,
    TextEditingController controller,
  ) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: TextField(
      key: Key(keyName),
      controller: controller,
      enabled: !_lookingUp,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Future<void> _lookupCep() async {
    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) {
      setState(() => _cepError = 'Informe um CEP com 8 dígitos.');
      return;
    }
    final serial = ++_lookupSerial;
    setState(() {
      _lookingUp = true;
      _cepError = null;
    });
    try {
      final address = await _cepService.lookup(cep);
      if (!mounted || serial != _lookupSerial) return;
      _streetController.text = address.street;
      _neighborhoodController.text = address.neighborhood;
      _cityController.text = address.city;
      _ufController.text = address.uf;
    } on CepException catch (error) {
      if (mounted && serial == _lookupSerial) {
        setState(() => _cepError = error.message);
      }
    } finally {
      if (mounted && serial == _lookupSerial) {
        setState(() => _lookingUp = false);
      }
    }
  }

  Future<void> _choosePhoto() async {
    if (_saving || _pickingPhoto) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar foto'),
              subtitle: _photos.supportsCamera
                  ? null
                  : const Text('Disponível no aplicativo Android'),
              enabled: _photos.supportsCamera,
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Selecionar da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    _readFields();
    setState(() => _pickingPhoto = true);
    try {
      final image = await _photos.pick(_editContact, source);
      if (image != null && mounted) {
        setState(() => _editContact.img = image.path);
      }
    } on PlatformException catch (error) {
      final denied =
          error.code.contains('denied') || error.code.contains('restricted');
      _showError(
        denied
            ? 'Acesso à câmera ou às fotos negado. Verifique as permissões nas configurações.'
            : 'Não foi possível abrir a câmera ou a galeria. Verifique se estão disponíveis.',
      );
    } catch (_) {
      _showError('Não foi possível obter a foto. Tente novamente.');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _readFields() {
    _editContact.name = _nameController.text.trim();
    _editContact.email = formatEmail(_emailController.text);
    _editContact.phone = _phoneController.text;
    _editContact.cep = _cepController.text;
    _editContact.street = _streetController.text.trim();
    _editContact.neighborhood = _neighborhoodController.text.trim();
    _editContact.city = _cityController.text.trim();
    _editContact.uf = _ufController.text.trim().toUpperCase();
    _editContact.number = _numberController.text.trim();
    _editContact.complement = _complementController.text.trim();
  }

  Future<void> _saveContact() async {
    if (_saving || _lookingUp || _pickingPhoto) return;
    _readFields();
    if (_editContact.name.isEmpty) {
      _showError('Nome é obrigatório!');
      return;
    }
    if (!isValidEmail(_editContact.email)) {
      setState(() => _emailError = 'Informe um e-mail válido.');
      _showError('Informe um e-mail válido.');
      return;
    }
    if (_editContact.cep.isNotEmpty &&
        _editContact.cep.replaceAll(RegExp(r'\D'), '').length != 8) {
      setState(() => _cepError = 'Informe um CEP com 8 dígitos.');
      _showError('Informe um CEP com 8 dígitos.');
      return;
    }
    if (_editContact.uf.isNotEmpty &&
        !RegExp(r'^[A-Z]{2}$').hasMatch(_editContact.uf)) {
      _showError('Informe a UF com duas letras.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (_editContact.img != null) {
        _editContact.img = await _photos.persist(_editContact.img!);
      }
      if (_editContact.id != null) {
        await _helper.updateContact(_editContact);
      } else {
        await _helper.saveContact(_editContact);
      }
      if (mounted) Navigator.pop(context, _editContact);
    } catch (_) {
      _showError('Não foi possível salvar o contato.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
