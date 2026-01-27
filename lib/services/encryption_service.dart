import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final _key = encrypt.Key.fromUtf8('jc8upb889n3SHP1LTveX0s3tCJOemFYo');

  static final _iv = encrypt.IV.fromUtf8('6LG0mK7sv1SMvyfO');

  static Map<String, String> encryptData(String plainText) {
    if (plainText.isEmpty) throw Exception("Plain text is empty");

    final encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );

    final encrypted = encrypter.encrypt(plainText, iv: _iv).base64;

    final hash = sha256.convert(utf8.encode(encrypted)).toString();

    return {'encryptedData': encrypted, 'Hash': hash};
  }

  static String? decryptData(String encryptedText, String hash) {
    if (encryptedText.isEmpty) throw Exception("Encrypted text is empty");

    final calculatedHash =
        sha256.convert(utf8.encode(encryptedText)).toString();

    if (calculatedHash == hash) {
      final encrypter = encrypt.Encrypter(
        encrypt.AES(_key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);

      return decrypted;
    } else {
      return null;
    }
  }

  static String generateHash(String input) {
    if (input.isEmpty) throw Exception("Input is empty");
    return sha256.convert(utf8.encode(input)).toString();
  }
}
