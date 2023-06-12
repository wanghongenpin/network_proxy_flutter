import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter/services.dart';
import 'package:network/network/util/x509.dart';

Future<void> main() async {
  await CertificateManager.getCertificateContext('www.jianshu.com');
  String cer = CertificateManager.get('www.jianshu.com')!;
  var x509certificateFromPem = X509Utils.x509CertificateFromPem(cer);
  print(x509certificateFromPem.plain!);
}

class CertificateManager {
  /// 证书缓存
  static final Map<String, String> _certificateMap = {};

  /// 服务端密钥
  static final AsymmetricKeyPair _serverKeyPair = CryptoUtils.generateRSAKeyPair();

  /// ca证书
  static late X509CertificateData _caCert;

  /// ca私钥
  static late RSAPrivateKey _caPriKey;

  /// 是否初始化
  static bool _initialized = false;

  static String? get(String host) {
    return _certificateMap[host];
  }

  /// 获取域名自签名证书
  static Future<SecurityContext> getCertificateContext(String host) async {
    var cer = _certificateMap[host];

    if (cer == null) {
      if (!_initialized) {
        await _initCAConfig();
      }
      cer = generate(_caCert, _serverKeyPair.publicKey as RSAPublicKey, _caPriKey, host);
      _certificateMap[host] = cer;
    }

    var rsaPrivateKey = _serverKeyPair.privateKey as RSAPrivateKey;

    return SecurityContext.defaultContext
      ..useCertificateChainBytes(cer.codeUnits)
      ..usePrivateKeyBytes(CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(rsaPrivateKey).codeUnits);
  }

  /// 生成证书
  static String generate(X509CertificateData caRoot, RSAPublicKey serverPubKey, RSAPrivateKey caPriKey, String host) {
    //根据CA证书subject来动态生成目标服务器证书的issuer和subject
    Map<String, String> x509Subject = {
      'C': 'CN',
      'ST': 'BJ',
      'L': 'BJ',
      'O': 'network',
      'OU': 'Proxy',
    };
    x509Subject['CN'] = host;

    Map<String, String> issuer = Map.from(_caCert.tbsCertificate!.subject);
    var csrPem = X509Generate.generateSelfSignedCertificate(caRoot, serverPubKey, caPriKey, 365,
        sans: [host], serialNumber: Random().nextInt(1000000).toString(), issuer: issuer);
    return csrPem;
  }

  static Future<void> _initCAConfig() async {
    if (_initialized) {
      return;
    }
    //从项目目录加入ca根证书
    var caPem = await rootBundle.loadString('assets/certs/ca.crt');
    // var caPem = await File('assets/certs/ca.crt').readAsString();
    _caCert = X509Utils.x509CertificateFromPem(caPem);
    //根据CA证书subject来动态生成目标服务器证书的issuer和subject

    //从项目目录加入ca私钥
    var privateBytes = await rootBundle.load('assets/certs/ca_private.der');
    // var privateBytes = await File('assets/certs/ca_private.der').readAsBytes();
    _caPriKey = CryptoUtils.rsaPrivateKeyFromDERBytes(privateBytes.buffer.asUint8List());

    _initialized = true;
  }
}
