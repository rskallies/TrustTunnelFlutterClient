import 'dart:convert';
import 'dart:typed_data';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/model/certificate.dart';

class RawCertificateDecoder extends Converter<Uint8List, String> {
  const RawCertificateDecoder();

  @override
  String convert(Uint8List input) {
    final text = _tryUtf8(input);

    if (text != null) {
      return text;
    }

    return base64Encode(input);
  }

  String? _tryUtf8(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }
}
class CertificateDecoder extends Converter<db.CertificateTableData, Certificate> {
  const CertificateDecoder();

  @override
  Certificate convert(db.CertificateTableData input) => Certificate(
    name: input.name,
    data: input.data,
  );
}

class CertificateEncoder extends Converter<Certificate, db.CertificateTableData> {
  final int serverId;

  const CertificateEncoder({
    required this.serverId,
  });

  @override
  db.CertificateTableData convert(
    Certificate input,
  ) => db.CertificateTableData(
    name: input.name,
    data: input.data,
    serverId: serverId,
  );
}
