const String kApiBaseUrl =
    'https://societymanagementbackend-anuritinnovation-dkf9hsgdcgcnfbf4.westus3-01.azurewebsites.net/api/v1';

const String kSocketUrl =
    'https://societymanagementbackend-anuritinnovation-dkf9hsgdcgcnfbf4.westus3-01.azurewebsites.net';

String socketUrlFromApi(String apiBase) {
  final uri = Uri.tryParse(apiBase);

  if (uri == null) return kSocketUrl;

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}
