import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class CepException implements Exception {
  const CepException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PostalAddress {
  const PostalAddress({
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.uf,
  });
  final String street;
  final String neighborhood;
  final String city;
  final String uf;
}

class CepService {
  CepService({this._client});
  final http.Client? _client;

  Future<PostalAddress> lookup(String cep) async {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{8}$').hasMatch(digits)) {
      throw const CepException('Informe um CEP com 8 dígitos.');
    }
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.https('viacep.com.br', '/ws/$digits/json/'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw const CepException(
          'Serviço de CEP indisponível. Tente novamente.',
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (data['erro'] == true || data['erro'] == 'true') {
        throw const CepException('CEP não encontrado. Confira os números.');
      }
      if (data['localidade'] is! String ||
          data['uf'] is! String ||
          (data['localidade'] as String).isEmpty ||
          !RegExp(r'^[A-Z]{2}$').hasMatch(data['uf'] as String)) {
        throw const FormatException();
      }
      return PostalAddress(
        street: data['logradouro'] as String? ?? '',
        neighborhood: data['bairro'] as String? ?? '',
        city: data['localidade'] as String,
        uf: data['uf'] as String,
      );
    } on TimeoutException {
      throw const CepException('A consulta demorou demais. Tente novamente.');
    } on SocketException {
      throw const CepException(
        'Sem conexão. Verifique a internet e tente novamente.',
      );
    } on IOException {
      throw const CepException(
        'Não foi possível conectar ao serviço de CEP. Tente novamente.',
      );
    } on http.ClientException {
      throw const CepException(
        'Não foi possível consultar o CEP. Verifique a internet.',
      );
    } on FormatException {
      throw const CepException(
        'O serviço de CEP retornou uma resposta inválida.',
      );
    } on TypeError {
      throw const CepException(
        'O serviço de CEP retornou uma resposta inválida.',
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}
