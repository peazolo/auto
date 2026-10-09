import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart' as http;

/// The default browser client buffers the whole response; fetch streams it.
http.Client makeStreamClient() => FetchClient(mode: RequestMode.cors);
