/// Non-web platforms never call this (callers guard with kIsWeb).
void downloadTextFile(String content, String filename, String mime) {
  throw UnsupportedError('downloadTextFile is only available on web');
}
