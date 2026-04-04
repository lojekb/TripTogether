import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trip_together/api_constants.dart';

class ApiService {
  Future<List<dynamic>> getEvents() async {
    try {
      var url = Uri.parse(ApiConstants.baseUrl + ApiConstants.eventsEndpoint);
      var response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Błąd serwera: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Błąd połączenia: $e');
      return [];
    }
  }
}