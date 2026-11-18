import 'package:brainrot_wrapper/models/site_config.dart';
import 'package:brainrot_wrapper/services/injector.dart';
import 'package:brainrot_wrapper/services/route_guard.dart';
import 'package:brainrot_wrapper/sites/facebook.dart';
import 'package:brainrot_wrapper/sites/instagram.dart';
import 'package:brainrot_wrapper/sites/registry.dart';
import 'package:brainrot_wrapper/sites/youtube.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> defaults(SiteConfig s) =>
    {for (final t in s.allToggles) if (t.defaultOn) t.id};

void main() {
  group('RouteGuard', () {
    test('YouTube Shorts redirect to subscriptions', () {
      final g = RouteGuard(youtube, defaults(youtube));
      final d = g.check(Uri.parse('https://m.youtube.com/shorts/abc123'));
      expect(d, isA<Redirect>());
      expect((d as Redirect).url, youtube.safeRoute);
    });

    test('YouTube watch pages are allowed', () {
      final g = RouteGuard(youtube, defaults(youtube));
      expect(g.check(Uri.parse('https://m.youtube.com/watch?v=x')), isA<Allow>());
    });

    test('Shorts allowed only while a Reels pass runs', () {
      final off = RouteGuard(youtube, {});
      final d = off.check(Uri.parse('https://m.youtube.com/shorts/abc'));
      expect((d as Redirect).reason, reelsOffReason);
      final on = RouteGuard(youtube, {}, shortVideoAllowed: true);
      expect(on.check(Uri.parse('https://m.youtube.com/shorts/abc')), isA<Allow>());
    });

    test('a pass lifts Instagram and Facebook reel rules, not other blocks', () {
      final ig = RouteGuard(instagram, defaults(instagram), shortVideoAllowed: true);
      expect(ig.check(Uri.parse('https://www.instagram.com/reels/')), isA<Allow>());
      expect(ig.check(Uri.parse('https://www.instagram.com/reel/A/'), fromPath: '/'),
          isA<Allow>());
      expect(ig.check(Uri.parse('https://www.instagram.com/explore/')), isA<Redirect>());
      expect(ig.dmOnlySources, isEmpty);
      final fb = RouteGuard(facebook, {}, shortVideoAllowed: true);
      expect(fb.check(Uri.parse('https://m.facebook.com/watch/')), isA<Allow>());
    });

    test('redirect target itself is never redirected (no loop)', () {
      final g = RouteGuard(youtube, defaults(youtube));
      expect(g.check(Uri.parse(youtube.safeRoute)), isA<Allow>());
    });

    test('Instagram explore and reels blocked, DMs allowed', () {
      final g = RouteGuard(instagram, defaults(instagram));
      expect(g.check(Uri.parse('https://www.instagram.com/explore/')), isA<Redirect>());
      expect(g.check(Uri.parse('https://www.instagram.com/reels/')), isA<Redirect>());
      expect(g.check(Uri.parse('https://www.instagram.com/direct/t/1/')), isA<Allow>());
    });

    group('reels', () {
      const reel = 'https://www.instagram.com/reel/ABC123/';

      test('there is no switch to turn reels back on', () {
        for (final s in [instagram, facebook]) {
          expect(s.allToggles.where((t) => t.id.contains('reel')), isEmpty,
              reason: s.id);
        }
      });

      test('reels tab, feed and profile reels are blocked even with every toggle off', () {
        final g = RouteGuard(instagram, {});
        for (final p in ['/reels/', '/reels/XYZ/', '/someone/reels/']) {
          expect(g.check(Uri.parse('https://www.instagram.com$p'),
              fromPath: '/direct/t/1/'), isA<Redirect>(), reason: p);
        }
      });

      test('a reel opens when tapped in a DM thread', () {
        final g = RouteGuard(instagram, {});
        expect(g.check(Uri.parse(reel), fromPath: '/direct/t/123/'), isA<Allow>());
      });

      test('feed-style /<user>/reel/<id>/ links follow the same rule', () {
        final g = RouteGuard(instagram, {});
        const userReel = 'https://www.instagram.com/someone/reel/ABC/';
        expect(g.check(Uri.parse(userReel), fromPath: '/'), isA<Redirect>());
        expect(g.check(Uri.parse(userReel), fromPath: '/direct/t/1/'), isA<Allow>());
      });

      test('a reel from anywhere else, or swiping to the next reel, goes to the inbox', () {
        final g = RouteGuard(instagram, {});
        for (final from in [null, '/', '/someone/', '/reel/PREVIOUS/']) {
          final d = g.check(Uri.parse(reel), fromPath: from);
          expect(d, isA<Redirect>(), reason: '$from');
          expect((d as Redirect).url, instagram.messagesRoute);
        }
      });

      test('a DM reel is still allowed in messages-only focus mode', () {
        final g = RouteGuard(instagram, {}, messagesOnly: true);
        expect(g.check(Uri.parse(reel), fromPath: '/direct/t/9/'), isA<Allow>());
      });

      test('Facebook reels only open from Messages', () {
        final g = RouteGuard(facebook, {});
        const fbReel = 'https://m.facebook.com/reel/42/';
        expect(g.check(Uri.parse(fbReel), fromPath: '/messages/t/1/'), isA<Allow>());
        expect(g.check(Uri.parse(fbReel), fromPath: '/'), isA<Redirect>());
        expect(g.check(Uri.parse('https://m.facebook.com/watch/')), isA<Redirect>());
      });

      test('reels links are hidden whatever the toggles say', () {
        expect(buildCss(instagram, {}), contains('a[href="/reels/"]{display:none !important}'));
      });
    });

    test('foreign hosts open externally', () {
      final g = RouteGuard(instagram, defaults(instagram));
      expect(g.check(Uri.parse('https://example.com/x')), isA<OpenExternally>());
      expect(g.check(Uri.parse('intent://foo')), isA<OpenExternally>());
    });

    test('messages-only mode sends everything else to the inbox', () {
      final g = RouteGuard(instagram, defaults(instagram), messagesOnly: true);
      final d = g.check(Uri.parse('https://www.instagram.com/someone/'));
      expect(d, isA<Redirect>());
      expect((d as Redirect).url, instagram.messagesRoute);
      expect(g.check(Uri.parse('https://www.instagram.com/direct/inbox/')), isA<Allow>());
    });

    test('every site pattern compiles', () {
      for (final s in sites) {
        RouteGuard(s, {for (final t in s.allToggles) t.id}, messagesOnly: true);
        s.categorize('/');
      }
    });
  });

  test('only Snapchat, WhatsApp and Messenger use desktop mode; none open external apps', () {
    for (final s in sites) {
      expect(s.desktopMode, {'snapchat', 'whatsapp', 'messenger'}.contains(s.id), reason: s.id);
      expect(s.isExternal, isFalse, reason: s.id);
    }
  });

  group('categorize', () {
    test('maps paths to categories', () {
      expect(instagram.categorize('/direct/inbox/'), RouteCategory.messages);
      expect(instagram.categorize('/someone/'), RouteCategory.profile);
      expect(instagram.categorize('/'), RouteCategory.feed);
      expect(youtube.categorize('/results'), RouteCategory.search);
      expect(youtube.categorize('/watch'), RouteCategory.watch);
      expect(youtube.categorize('/shorts/x'), RouteCategory.shorts);
      expect(instagram.categorize('/reel/x/'), RouteCategory.shorts);
    });
  });

  group('injector', () {
    test('one CSS rule per selector, only for enabled toggles', () {
      final css = buildCss(youtube, {});
      expect(css, contains('ytm-reel-shelf-renderer{display:none !important}'));
      expect(css, isNot(contains('ytm-comment-section-renderer')));
    });

    test('short-video selectors drop out during a pass', () {
      final css = buildCss(youtube, {}, shortVideoAllowed: true);
      expect(css, isNot(contains('ytm-reel-shelf-renderer')));
      final js = buildInjection(
        site: instagram,
        enabled: {},
        guard: RouteGuard(instagram, {}, shortVideoAllowed: true),
        keywords: const [],
        feedCap: 0,
      );
      expect(js, contains('"dmOnly":[]'));
      expect(js, isNot(contains('/reels/')));
    });

    test('script carries config and no placeholder', () {
      final enabled = defaults(youtube);
      final js = buildInjection(
        site: youtube,
        enabled: enabled,
        guard: RouteGuard(youtube, enabled),
        keywords: const ['prank'],
        feedCap: 15,
      );
      expect(js, isNot(contains('__FF_CONFIG__')));
      expect(js, contains('"feedCap":15'));
      expect(js, contains('"prank"'));
      expect(js, contains(r'^/shorts'));
    });
  });
}
