import 'package:crypto/crypto.dart';
import 'dart:convert';

void main() {
  // الماك بتاع جهازك الأصلي من أمر getmac
  const mac = "009337F5DDF5";  // من غير شرطات
  const secret = "doctor_system_secret_2024";
  const List<int> xorKey = [
    0xAB, 0xCD, 0x12, 0x34, 0x56, 0x78,
    0x9A, 0xBC, 0xDE, 0xF0, 0x11, 0x22,
  ];

  // حساب XOR
  final macBytes = mac.codeUnits;
  final encoded = List<int>.generate(
    macBytes.length,
    (i) => macBytes[i] ^ xorKey[i],
  );
  final hex = encoded
      .map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}')
      .join(', ');

  // حساب Hash
  final round1 = Hmac(sha256, utf8.encode(secret))
      .convert(utf8.encode(mac))
      .toString();
  final round2 = Hmac(sha256, utf8.encode(round1))
      .convert(utf8.encode(secret + mac))
      .toString();

  print("═══════════════════════════════════════");
  print("الجهاز: 00-93-37-F5-DD-F4");
  print("═══════════════════════════════════════");
  print("_encodedMac: [$hex]");
  print("");
  print("_allowedHash: $round2");
  print("═══════════════════════════════════════");
}