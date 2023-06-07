import 'dart:core';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';

Future<void> main() async {
  var securityContext = await CertificateManager.getCertificateContext('www.baidu.com');
  print(securityContext);
  print(CertificateManager._caCert.tbsCertificate?.subject);
  print(CertificateManager._caCert.tbsCertificateSeqAsString);
  print(CertificateManager._caCert);
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
      cer = generate(_serverKeyPair.publicKey as RSAPublicKey, _caPriKey, host);
      _certificateMap[host] = cer;
    }

    var rsaPrivateKey = _serverKeyPair.privateKey as RSAPrivateKey;

    return SecurityContext.defaultContext
      ..useCertificateChainBytes(cer.codeUnits)
      ..usePrivateKeyBytes(CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(rsaPrivateKey).codeUnits);
  }

  /// 生成证书
  static String generate(PublicKey serverPubKey, RSAPrivateKey caPriKey, String host) {
    //根据CA证书subject来动态生成目标服务器证书的issuer和subject
    Map<String, String> x509Subject = {
      'C': 'CN',
      'ST': 'BJ',
      'L': 'BJ',
      'O': 'network',
      'OU': 'Proxy',
    };
    x509Subject['CN'] = host;
    var csr = X509Utils.generateRsaCsrPem(x509Subject, caPriKey, serverPubKey as RSAPublicKey, san: [host]);

    Map<String, String> issuer = Map.from(_caCert.tbsCertificate!.subject);
    var csrPem = X509Utils.generateSelfSignedCertificate(caPriKey, csr, 3650, sans: [host], issuer: issuer);
    return csrPem;
  }

  static Future<void> _initCAConfig() async {
    if (_initialized) {
      return;
    }
    //从项目目录加入ca根证书
    var caPem = await File('assets/certs/ca.crt').readAsString();
    _caCert = X509Utils.x509CertificateFromPem(caPem);
    //根据CA证书subject来动态生成目标服务器证书的issuer和subject

    //从项目目录加入ca私钥
    var privateBytes = await File('assets/certs/ca_private.der').readAsBytes();
    _caPriKey = CryptoUtils.rsaPrivateKeyFromDERBytes(privateBytes);

    _initialized = true;
  }
}
