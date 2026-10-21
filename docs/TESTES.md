# Verificação da atividade

Versão 1.1.0, build 2.

## Verificações realizadas

- Análise estática sem problemas.
- Nove testes de unidade/widget aprovados.
- Teste de integração Linux aprovado com consulta real ao ViaCEP.
- APK de release gerado, integridade verificada e assinatura validada.

Os testes cobrem cadastro, edição, exclusão, ordenação, validação/formatação do e-mail, máscara de telefone, migração SQLite, persistência de endereço, resposta fora de ordem na consulta de CEP, falhas de rede, encaminhamento de câmera/galeria, cancelamento, permissão negada e cópia permanente da foto. A cópia é verificada após remover o arquivo temporário original.

O teste de integração preenche um contato, consulta o CEP `01001-000`, informa número e complemento, salva, edita e reabre o banco para conferir os dados. O banco de testes é temporário.

## Roteiro de avaliação no Android

1. Instalar o APK e abrir a agenda.
2. Criar um contato com nome e e-mail inválido. Tentar salvar e conferir a mensagem de erro. Corrigir o e-mail e salvar.
3. Editar o contato e repetir a tentativa com e-mail inválido, verificando que os dados anteriores não são alterados.
4. Adicionar foto pela câmera e confirmar a captura. Salvar e reabrir o aplicativo para conferir o avatar. Repetir com uma imagem da galeria e testar o cancelamento da seleção.
5. Informar `01001-000` e conferir o preenchimento do endereço. Informar número e complemento, salvar e reabrir a edição para confirmar a persistência.
6. Consultar um CEP inexistente e tentar uma consulta sem internet. Conferir as mensagens e repetir a busca após restabelecer a conexão.
7. Ordenar os contatos, editar e excluir um registro. A opção Ligar deve abrir o discador quando disponível no dispositivo.

A captura física e as permissões do Android dependem de verificação no aparelho; os testes automatizados não substituem essa etapa.
