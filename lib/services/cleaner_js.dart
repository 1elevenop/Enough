/// Runs inside every page at document start. `__FF_CONFIG__` is replaced
/// with a JSON object built by [buildInjection].
const cleanerJsTemplate = r'''
(function () {
  if (window.__ffLoaded) return;
  window.__ffLoaded = true;
  var C = __FF_CONFIG__;

  // ---- desktop mode: values the native client hints don't cover ----
  if (C.desktopMode) {
    try {
      var NP = Navigator.prototype;
      Object.defineProperty(NP, 'platform', { get: function () { return 'Linux x86_64'; }, configurable: true });
      Object.defineProperty(NP, 'maxTouchPoints', { get: function () { return 0; }, configurable: true });
    } catch (e) {}
    // Feature checks like ('ontouchstart' in window). Touch events still fire.
    [window, Window.prototype, Document.prototype, Element.prototype, HTMLElement.prototype]
      .forEach(function (o) { try { delete o.ontouchstart; } catch (e) {} });
    // Answer pointer/hover media queries like a mouse-driven desktop.
    try {
      var mm = window.matchMedia.bind(window);
      window.matchMedia = function (q) {
        q = String(q)
          .replace(/\((any-)?pointer:\s*fine\)/g, '(min-width: 0px)')
          .replace(/\((any-)?hover:\s*hover\)/g, '(min-width: 0px)')
          .replace(/\((any-)?pointer:\s*coarse\)/g, '(max-width: 0px)')
          .replace(/\((any-)?hover:\s*none\)/g, '(max-width: 0px)');
        return mm(q);
      };
    } catch (e) {}
    // Lay the page out at desktop width instead of the phone's 411px.
    var fixViewport = function () {
      var m = document.querySelector('meta[name=viewport]');
      if (!m) {
        if (!document.head) return;
        m = document.createElement('meta');
        m.name = 'viewport';
        document.head.appendChild(m);
      }
      if (m.content !== 'width=1280') m.content = 'width=1280';
    };
    fixViewport();
    new MutationObserver(fixViewport).observe(document.documentElement, { childList: true, subtree: true });
  }

  // ---- bridge to Flutter (queued until the handler is ready) ----
  var queue = [];
  function send(name, arg) {
    var b = window.flutter_inappwebview;
    if (b && b.callHandler) {
      try { b.callHandler(name, arg); } catch (e) {}
    } else {
      queue.push([name, arg]);
    }
  }
  window.addEventListener('flutterInAppWebViewPlatformReady', function () {
    var q = queue; queue = [];
    q.forEach(function (x) { send(x[0], x[1]); });
  });

  // ---- camera/mic permission state ----
  // Android WebView answers "prompt" to permissions.query even after access
  // is granted, and some sites (Snapchat) wait for "granted" before showing
  // the camera. Report the state Enough will actually give.
  if (C.media && navigator.permissions && navigator.mediaDevices) {
    try {
      var mediaGranted = C.media === 'granted', mediaDenied = C.media === 'denied';
      var mediaStatuses = [];
      var pq = navigator.permissions.query.bind(navigator.permissions);
      navigator.permissions.query = function (d) {
        var n = d && d.name;
        if (n !== 'camera' && n !== 'microphone') return pq(d);
        return pq(d).then(function (st) {
          Object.defineProperty(st, 'state', {
            configurable: true,
            get: function () { return mediaGranted ? 'granted' : mediaDenied ? 'denied' : 'prompt'; }
          });
          mediaStatuses.push(st);
          return st;
        });
      };
      var md = navigator.mediaDevices, gum = md.getUserMedia.bind(md);
      var granted = function (stream) {
        if (!mediaGranted) {
          mediaGranted = true; mediaDenied = false;
          mediaStatuses.forEach(function (st) { try { st.dispatchEvent(new Event('change')); } catch (e) {} });
        }
        return stream;
      };
      md.getUserMedia = function (c) { return gum(c).then(granted); };
      // Snapchat's camera fails if its first burst of requests has to wait
      // for Enough's grant. Ask once at load (released at once) so the
      // WebView already holds the grant when the camera opens.
      if (C.mediaWarmup && mediaGranted) {
        gum({ audio: true, video: true }).then(function (s) {
          s.getTracks().forEach(function (t) { t.stop(); });
        }, function () {});
      }
    } catch (e) {}
  }

  // ---- tracker counter ----
  // The native blocker refuses every request to these hosts and leaves no
  // trace the page can see, so count the attempts as they are made.
  if (C.trackers && C.trackers.length) {
    var trackerHit = function (u) {
      try {
        var h = new URL(String(u), location.href).hostname;
        for (var i = 0; i < C.trackers.length; i++) {
          var t = C.trackers[i];
          if (h === t || h.slice(-t.length - 1) === '.' + t) return true;
        }
      } catch (e) {}
      return false;
    };
    var hits = 0, counted = new WeakSet();
    var count = function (u, el) {
      if (!u || !trackerHit(u)) return;
      if (el) { if (counted.has(el)) return; counted.add(el); }
      hits++;
    };
    [window.HTMLImageElement, window.HTMLScriptElement, window.HTMLIFrameElement].forEach(function (K) {
      try {
        var d = Object.getOwnPropertyDescriptor(K.prototype, 'src');
        Object.defineProperty(K.prototype, 'src', {
          configurable: true, enumerable: d.enumerable, get: d.get,
          set: function (v) { count(v, this); d.set.call(this, v); }
        });
      } catch (e) {}
    });
    // Parser-created elements fail to load; catch those in the capture phase.
    window.addEventListener('error', function (e) {
      var t = e.target;
      if (t && t !== window) count(t.src || t.href, t);
    }, true);
    try {
      var f = window.fetch;
      window.fetch = function (input) {
        count(input && input.url ? input.url : input);
        return f.apply(this, arguments);
      };
    } catch (e) {}
    try {
      var open = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function (m, u) { count(u); return open.apply(this, arguments); };
    } catch (e) {}
    try {
      var beacon = navigator.sendBeacon.bind(navigator);
      navigator.sendBeacon = function (u, d) { count(u); return beacon(u, d); };
    } catch (e) {}
    setInterval(function () { if (hits) { send('trackers', hits); hits = 0; } }, 5000);
  }

  // ---- styles ----
  function addStyle() {
    if (document.getElementById('ff-style')) return;
    var s = document.createElement('style');
    s.id = 'ff-style';
    s.textContent = C.css;
    (document.head || document.documentElement).appendChild(s);
  }
  addStyle();
  document.addEventListener('DOMContentLoaded', addStyle);

  // ---- route guard for single-page navigation ----
  function rx(list) { return (list || []).map(function (p) { return new RegExp(p); }); }
  var blocked = rx(C.blocked);
  var focus = C.focusOnly ? rx(C.focusOnly) : null;
  var dmOnly = rx(C.dmOnly), dmSource = rx(C.dmSource);
  function any(list, p) { return list.some(function (r) { return r.test(p); }); }
  // Path of the page before the current SPA navigation. null on a full page
  // load: Flutter already checked that navigation with its own history.
  var prevPath = null;
  function guard() {
    var p = location.pathname || '/';
    var target = null;
    if (focus && !any(focus, p)) target = C.focusTarget;
    else if (any(blocked, p)) target = C.safe;
    else if (prevPath !== null && prevPath !== p && any(dmOnly, p) && !any(dmSource, prevPath)) {
      target = C.focusTarget; // messages inbox
    }
    if (!target) { prevPath = p; return false; }
    var t = new URL(target, location.href);
    if (t.host === location.host && t.pathname === location.pathname) return false;
    location.replace(target);
    return true;
  }
  function onRoute() {
    if (!guard()) send('routeChanged', location.href);
    schedule();
  }
  ['pushState', 'replaceState'].forEach(function (m) {
    var orig = history[m];
    history[m] = function () {
      var r = orig.apply(this, arguments);
      setTimeout(onRoute, 0);
      return r;
    };
  });
  window.addEventListener('popstate', onRoute);
  guard();

  // ---- one reel per tap inside DMs ----
  // Instagram plays a reel sent in a DM in a full-screen viewer without
  // changing the URL, and swiping moves on to unrelated reels. Allow the
  // first full-screen video; if a different one replaces it before the
  // viewer closes, that's a swipe: stop it and go back to the inbox.
  if (dmOnly.length) {
    var viewer = null;
    setInterval(function () {
      var p = location.pathname || '/';
      if (!any(dmSource, p) && !any(dmOnly, p)) { viewer = null; return; }
      var v = null, vids = document.querySelectorAll('video');
      for (var i = 0; i < vids.length; i++) {
        var r = vids[i].getBoundingClientRect();
        if (r.width > innerWidth * 0.8 && r.height > innerHeight * 0.5 &&
            r.top < innerHeight / 2 && r.bottom > innerHeight / 2) { v = vids[i]; break; }
      }
      if (!v) { viewer = null; return; }
      var src = v.currentSrc || v.src || '';
      if (!viewer) { viewer = { el: v, src: src }; return; }
      if (!viewer.src) viewer.src = src;
      if (v !== viewer.el || (src && src !== viewer.src)) {
        viewer = null;
        try { v.pause(); v.muted = true; } catch (e) {}
        send('reelSwipeBlocked', 1);
        location.replace(C.focusTarget);
      }
    }, 400);
  }

  // ---- activity pings (for idle detection) ----
  var lastAct = 0, lastGesture = 0;
  function act() {
    var n = Date.now();
    if (n - lastAct > 5000) { lastAct = n; send('activity', 1); }
  }
  ['touchstart', 'scroll', 'keydown', 'wheel'].forEach(function (e) {
    window.addEventListener(e, act, { passive: true, capture: true });
  });
  ['pointerdown', 'touchend', 'click', 'keydown'].forEach(function (e) {
    window.addEventListener(e, function () { lastGesture = Date.now(); }, true);
  });
  document.addEventListener('timeupdate', function (e) {
    if (e.target && !e.target.paused) act();
  }, true);

  // ---- no autoplay ----
  if (C.noAutoplay) {
    document.addEventListener('loadstart', function (e) {
      if (e.target && e.target.dataset) delete e.target.dataset.ffAllowed;
    }, true);
    document.addEventListener('play', function (e) {
      var v = e.target;
      if (!v || v.tagName !== 'VIDEO') return;
      if (v.dataset.ffAllowed || Date.now() - lastGesture < 1500) {
        v.dataset.ffAllowed = '1';
        return;
      }
      v.pause();
    }, true);
  }

  // ---- tap to reveal blurred media ----
  if (C.blurMedia) {
    document.addEventListener('click', function (e) {
      var els = document.elementsFromPoint(e.clientX, e.clientY);
      for (var i = 0; i < els.length; i++) {
        var el = els[i];
        if ((el.tagName === 'IMG' || el.tagName === 'VIDEO') && !el.hasAttribute('data-ff-revealed')) {
          el.setAttribute('data-ff-revealed', '1');
          e.preventDefault();
          e.stopPropagation();
          return;
        }
      }
    }, true);
  }

  // ---- keyword filter + feed cap ----
  function esc(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
  var kw = (C.keywords && C.keywords.length)
    ? new RegExp('(^|[^a-z0-9])(' + C.keywords.map(esc).join('|') + ')(?=[^a-z0-9]|$)', 'i')
    : null;
  var capActive = false;
  window.__ffSetCap = function (on) { capActive = !!on && C.feedCap > 0; schedule(); };

  function hide(el, why) {
    el.dataset.ffHidden = why;
    el.style.setProperty('display', 'none', 'important');
  }
  function unhide(el) {
    delete el.dataset.ffHidden;
    el.style.removeProperty('display');
  }
  function capCard() {
    var d = document.createElement('div');
    d.id = 'ff-cap-card';
    d.setAttribute('style', 'margin:24px 16px;padding:24px;border-radius:16px;' +
      'background:#111;color:#fff;font:16px/1.4 system-ui,sans-serif;text-align:center;filter:none');
    d.innerHTML = '<div style="font-size:32px">&#127919;</div>' +
      '<div style="font-weight:700;margin:8px 0">You\'re all caught up</div>' +
      '<div style="opacity:.75;margin-bottom:16px">You hit your feed cap of ' + C.feedCap +
      ' posts. Time to do something real.</div>' +
      '<button style="padding:10px 20px;border-radius:999px;border:0;background:#fff;color:#111;font-weight:700">Back to dashboard</button>';
    d.querySelector('button').addEventListener('click', function (e) {
      e.preventDefault(); e.stopPropagation(); send('goHome', 1);
    });
    return d;
  }

  function scan() {
    if (C.blurMedia) {
      var imgs = document.querySelectorAll('img:not([data-ff-revealed])');
      for (var j = 0; j < imgs.length; j++) {
        var w = imgs[j].getBoundingClientRect().width;
        if (w && w < 56) imgs[j].setAttribute('data-ff-revealed', 's');
      }
    }
    if (!C.postSelector || (!kw && !C.feedCap)) return;
    var posts = document.querySelectorAll(C.postSelector);
    var visible = 0, lastVisible = null;
    for (var i = 0; i < posts.length; i++) {
      var p = posts[i];
      if (p.dataset.ffHidden === 'kw') continue;
      if (kw) {
        var t = p.textContent || '';
        var key = String(t.length);
        if (p.dataset.ffChecked !== key) {
          p.dataset.ffChecked = key;
          if (kw.test(t)) { hide(p, 'kw'); continue; }
        }
      }
      if (capActive && visible >= C.feedCap) {
        if (p.dataset.ffHidden !== 'cap') hide(p, 'cap');
        continue;
      }
      if (p.dataset.ffHidden === 'cap') unhide(p);
      visible++;
      lastVisible = p;
    }
    var card = document.getElementById('ff-cap-card');
    if (capActive && visible >= C.feedCap && lastVisible) {
      if (!card || card.previousElementSibling !== lastVisible) {
        if (card) card.remove();
        lastVisible.insertAdjacentElement('afterend', capCard());
      }
    } else if (card) {
      card.remove();
    }
  }

  var pending = false;
  function schedule() {
    if (pending) return;
    pending = true;
    requestAnimationFrame(function () {
      pending = false;
      try { scan(); } catch (e) {}
    });
  }
  new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
  setInterval(schedule, 2000);
})();
''';
