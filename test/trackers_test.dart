import 'package:brainrot_wrapper/sites/facebook.dart';
import 'package:brainrot_wrapper/sites/instagram.dart';
import 'package:brainrot_wrapper/sites/youtube.dart';
import 'package:brainrot_wrapper/services/trackers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final list = TrackerList([
    'google-analytics.com',
    'doubleclick.net',
    'pixel.facebook.com',
    'adservice.google.com',
  ]);

  test('matches hosts and subdomains, not lookalikes', () {
    expect(list.blocks(instagram, 'www.google-analytics.com'), isTrue);
    expect(list.blocks(instagram, 'google-analytics.com'), isTrue);
    expect(list.blocks(instagram, 'notgoogle-analytics.com'), isFalse);
  });

  test('a site\'s own hosts are never blocked on that site', () {
    // facebook.com is first-party for Instagram and Facebook.
    expect(list.blocks(instagram, 'pixel.facebook.com'), isFalse);
    expect(list.blocks(facebook, 'pixel.facebook.com'), isFalse);
    // google.com is first-party for YouTube.
    expect(list.blocks(youtube, 'adservice.google.com'), isFalse);
    expect(list.blocks(youtube, 'stats.g.doubleclick.net'), isTrue);
  });

  test('content blocker regex matches whole tracker URLs only', () {
    final re = RegExp(TrackerList.urlPattern(list.forSite(instagram)));
    expect(re.hasMatch('https://www.google-analytics.com/g/collect?v=2'), isTrue);
    expect(re.hasMatch('https://doubleclick.net'), isTrue);
    expect(re.hasMatch('https://ad.doubleclick.net:443/x'), isTrue);
    expect(re.hasMatch('https://www.instagram.com/?ref=google-analytics.com'), isFalse);
    expect(re.hasMatch('https://evil-doubleclick.net/'), isFalse);
  });
}
