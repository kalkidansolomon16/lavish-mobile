import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

typedef Json = Map<String, dynamic>;

/// Every API error has the same shape: branch on [code], show [message].
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, {this.errors = const {}, this.details = const {}});

  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> errors;
  final Map<String, dynamic> details;

  /// First field error, or the message.
  String get friendly {
    for (final v in errors.values) {
      if (v is List && v.isNotEmpty) return v.first.toString();
    }
    return message;
  }

  @override
  String toString() => friendly;
}

/// Thin wrapper around Dio: bearer token, JSON, uniform errors.
class Api {
  Api._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (token != null) o.headers['Authorization'] = 'Bearer $token';
      h.next(o);
    }));
  }

  static final Api instance = Api._();
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  static const _key = 'lavish_token';

  String? token;

  /// Called when the server says the token is no longer valid (401 unauthenticated).
  void Function()? onUnauthenticated;

  Future<void> loadToken() async {
    try {
      token = await _storage.read(key: _key);
    } catch (_) {
      token = null;
    }
  }

  Future<void> saveToken(String? t) async {
    token = t;
    try {
      if (t == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: t);
      }
    } catch (_) {}
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, [Object? body]) => _send(() => _dio.post(path, data: body));

  Future<dynamic> patch(String path, [Object? body]) => _send(() => _dio.patch(path, data: body));

  Future<dynamic> put(String path, [Object? body]) => _send(() => _dio.put(path, data: body));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  /// Multipart upload. [files] maps field name → list of (bytes, filename).
  Future<dynamic> upload(String path, Map<String, dynamic> fields, Map<String, List<UploadFile>> files) {
    final form = FormData();
    fields.forEach((k, v) {
      if (v != null) form.fields.add(MapEntry(k, v.toString()));
    });
    files.forEach((field, list) {
      for (final f in list) {
        form.files.add(MapEntry(field, MultipartFile.fromBytes(f.bytes, filename: f.name)));
      }
    });
    return _send(() => _dio.post(path, data: form));
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) => q == null ? null : (Map.of(q)..removeWhere((k, v) => v == null || v == ''));

  Future<dynamic> _send(Future<Response> Function() call) async {
    try {
      final res = await call();
      return res.data;
    } on DioException catch (e) {
      final r = e.response;
      if (r == null) {
        throw ApiException(0, 'offline', 'Can’t reach Lavish right now. Check your internet connection and try again.');
      }
      final data = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
      final code = (data['code'] ?? (r.statusCode == 429 ? 'too_many_requests' : 'error')).toString();
      final err = ApiException(
        r.statusCode ?? 0,
        code,
        (data['message'] ?? (r.statusCode == 429 ? 'Too many tries — please wait a moment.' : 'Something went wrong.')).toString(),
        errors: data['errors'] is Map ? Map<String, dynamic>.from(data['errors']) : const {},
        details: data['details'] is Map ? Map<String, dynamic>.from(data['details']) : const {},
      );
      if (r.statusCode == 401 && code == 'unauthenticated') onUnauthenticated?.call();
      throw err;
    }
  }
}

class UploadFile {
  UploadFile(this.bytes, this.name);
  final List<int> bytes;
  final String name;
}

final api = Api.instance;

/// Helpers for reading loosely-typed JSON.
extension JsonRead on Json {
  Json obj(String k) => this[k] is Map ? Map<String, dynamic>.from(this[k] as Map) : <String, dynamic>{};
  Json? objOrNull(String k) => this[k] is Map ? Map<String, dynamic>.from(this[k] as Map) : null;
  List<Json> list(String k) => this[k] is List ? (this[k] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Json>[];
  String str(String k, [String fallback = '']) => this[k]?.toString() ?? fallback;
  int integer(String k, [int fallback = 0]) => this[k] is num ? (this[k] as num).toInt() : int.tryParse('${this[k]}') ?? fallback;
  double number(String k, [double fallback = 0]) => this[k] is num ? (this[k] as num).toDouble() : double.tryParse('${this[k]}') ?? fallback;
  bool flag(String k) => this[k] == true || this[k] == 1;

  /// Enum fields come as "value" or {value, label}.
  String enumValue(String k) => this[k] is Map ? (this[k] as Map)['value']?.toString() ?? '' : str(k);
  String enumLabel(String k) => this[k] is Map ? (this[k] as Map)['label']?.toString() ?? '' : str(k);
}

/// `{data: ...}` → the data.
Json dataOf(dynamic res) => res is Map && res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : (res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{});
List<Json> listOf(dynamic res) => res is Map && res['data'] is List
    ? (res['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Json>[];
