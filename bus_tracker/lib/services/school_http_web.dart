// 웹용: 브라우저가 인증서를 알아서 처리하므로 평범한 Dio. 휴대폰용은 school_http_native.dart.
import 'package:dio/dio.dart';

Dio schoolDio(BaseOptions options) => Dio(options);
