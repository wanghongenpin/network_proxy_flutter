import 'dart:io';
import 'dart:math';
import 'package:basic_utils/basic_utils.dart';
import 'package:network_proxy/network/util/file_read.dart';
import 'package:network_proxy/network/util/x509.dart';

void main() async {
  var caPem = await FileRead.readAsString('assets/certs/ca.crt');
  //生成 公钥和私钥
  var caRoot = X509Utils.x509CertificateFromPem(caPem);
  var generateRSAKeyPair = CryptoUtils.generateRSAKeyPair();
  var serverPubKey = generateRSAKeyPair.publicKey as RSAPublicKey;
  var serverPriKey = generateRSAKeyPair.privateKey as RSAPrivateKey;

  //保存私钥
  var serverPriKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(serverPriKey);
  print(serverPriKeyPem);
  await File('assets/certs/server.key').writeAsString(serverPriKeyPem);
  var rsaPrivateKeyFromPem = CryptoUtils.rsaPrivateKeyFromPem(serverPriKeyPem);
  print(rsaPrivateKeyFromPem);
  var crt = generate(caRoot, serverPubKey, serverPriKey);
  print(crt);
  await File('assets/certs/server.crt').writeAsString(crt);
}

/// 生成证书
String generate(X509CertificateData caRoot, RSAPublicKey serverPubKey, RSAPrivateKey caPriKey) {
//根据CA证书subject来动态生成目标服务器证书的issuer和subject
  Map<String, String> x509Subject = {
    'C': 'CN',
    'ST': 'BJ',
    'L': 'Beijing',
    'O': 'Proxy',
    'OU': 'ProxyPin',
  };
  x509Subject['CN'] = 'ProxyPin CA (${Platform.localHostname})';

  var csrPem = X509Generate.generateSelfSignedCertificate(caRoot, serverPubKey, caPriKey, 1095,
      serialNumber: Random().nextInt(1000000).toString(), subject: x509Subject);
  return csrPem;
}
