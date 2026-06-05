import 'package:http/http.dart' as http;
import 'package:runhutch/functions/bl_functions.dart';

class RequestResult {
  const RequestResult({
    required this.success,
    required this.statusLabel,
  });

  final bool success;
  final String statusLabel;
}

class RequestService {
  RequestService._();

  static Future<RequestResult> send(String url) async {
    final target = BlFunctions.normalizeUrl(url);

    try {
      final response = await http
          .get(Uri.parse(target))
          .timeout(const Duration(seconds: 15));

      return RequestResult(
        success: true,
        statusLabel: 'OK ${response.statusCode}',
      );
    } catch (error) {
      return RequestResult(
        success: false,
        statusLabel: 'Failed',
      );
    }
  }
}
