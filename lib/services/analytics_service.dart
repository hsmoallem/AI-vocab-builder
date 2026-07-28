import 'analytics/analytics_stub.dart'
    if (dart.library.js_interop) 'analytics/analytics_web.dart' as platform;

class AnalyticsService {
  /// Track custom user actions, clicks, button presses, and feature usage.
  static void trackEvent(String eventName, [Map<String, dynamic>? properties]) {
    platform.platformTrackEvent(eventName, properties ?? {});
  }

  /// Track screen navigation and view changes to accurately measure time spent per screen/page.
  static void trackView(String url, String title) {
    platform.platformTrackView(url, title);
  }
}
