/*
 * Copyright 2023 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:network_proxy/network/util/x509.dart';

import 'file_read.dart';

Future<void> main() async {
  await CertificateManager.getCertificateContext('www.jianshu.com');
  CertificateManager.caCert.tbsCertificateSeqAsString;

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

  static X509CertificateData get caCert => _caCert;

  /// 清除缓存
  static void cleanCache() {
    _certificateMap.clear();
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
      ..allowLegacyUnsafeRenegotiation = true
      ..usePrivateKeyBytes(CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(rsaPrivateKey).codeUnits);
  }

  /// 生成证书
  static String generate(X509CertificateData caRoot, RSAPublicKey serverPubKey, RSAPrivateKey caPriKey, String host) {
    //根据CA证书subject来动态生成目标服务器证书的issuer和subject
    Map<String, String> x509Subject = {
      'C': 'CN',
      'ST': 'BJ',
      'L': 'BeiJing',
      'O': 'Proxy',
      'OU': 'ProxyPin',
    };
    x509Subject['CN'] = host;

    var csrPem = X509Generate.generateSelfSignedCertificate(caRoot, serverPubKey, caPriKey, 365,
        sans: [host], serialNumber: Random().nextInt(1000000).toString(), subject: x509Subject);
    return csrPem;
  }

  static Future<void> _initCAConfig() async {
    if (_initialized) {
      return;
    }
    //从项目目录加入ca根证书
    var caPem = await FileRead.readAsString('assets/certs/ca.crt');
    _caCert = X509Utils.x509CertificateFromPem(caPem);
    //根据CA证书subject来动态生成目标服务器证书的issuer和subject

    //从项目目录加入ca私钥
    var privateBytes = await FileRead.read('assets/certs/ca_private.der');
    _caPriKey = CryptoUtils.rsaPrivateKeyFromDERBytes(privateBytes.buffer.asUint8List());

    _initialized = true;
  }
}
