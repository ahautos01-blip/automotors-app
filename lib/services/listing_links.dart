final _listingIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
Uri listingShareUri(String? id) => id != null && _listingIdPattern.hasMatch(id)
    ? Uri.https('automotors.info', '/anuncio/', {'listing': id})
    : Uri.https('automotors.info', '/');
String? listingIdFromUri(Uri uri) {
  final official =
      uri.scheme == 'https' &&
      const ['automotors.info', 'www.automotors.info'].contains(uri.host) &&
      uri.path == '/anuncio/';
  final native =
      uri.scheme == 'com.automotors.automotorsbase' && uri.host == 'listing';
  if (!official && !native) return null;
  final id = uri.queryParameters['listing'];
  return id != null && _listingIdPattern.hasMatch(id) ? id : null;
}
