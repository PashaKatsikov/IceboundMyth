import 'package:webview_flutter/webview_flutter.dart';

import '../config/veiled_bytes.dart';

// JavaScript that runs inside the portal WebView. When the byte tables
// carry a body it wins; otherwise the inline defaults below run. The
// only behaviour the shell actually needs is keeping a focused field
// visible when the soft keyboard opens — Blink pans the visual viewport
// itself, so this only patches whatever it leaves covered. Safe-area
// CSS is intentionally left alone: the native shell already paints a
// gutter around the camera cutout.

class WebScripts {
  WebScripts._();

  /// Runs the ordered set of enhancers. Each is idempotent behind its
  /// own window flag, so calling this on every onPageFinished is fine.
  static Future<void> installAll(WebViewController controller) async {
    for (final String body in _bodies()) {
      if (body.isEmpty) continue;
      await controller.runJavaScript(body);
    }
  }

  static List<String> _bodies() {
    final String keyboard = unlockJsKeyboardScript();
    return <String>[
      unlockJsSafeAreaScript(),
      keyboard.isNotEmpty ? keyboard : _keyboardFallback,
      unlockJsAutoplayScript(),
    ];
  }

  /// Passes the page the fraction of its own height the keyboard covers
  /// (`0` when closed). A fraction rather than a length: the page may
  /// declare a scaled viewport and neither side can turn dp into CSS px
  /// without guessing.
  static Future<void> feedCover(
    WebViewController controller, {
    required double cover,
  }) async {
    final String packed = unlockJsKeyboardBridge();
    final String template = packed.isNotEmpty ? packed : _bridgeFallback;
    final String call = template.replaceAll('%SHARE%', cover.toStringAsFixed(4));
    try {
      await controller.runJavaScript(call);
    } catch (_) {}
  }

  static const String _bridgeFallback =
      'window.__imeInset&&window.__imeInset(%SHARE%);';

  // Residual keyboard correction. Blink owns the motion; this only acts
  // on pages that declare overlays-content, or a WebView whose visual
  // viewport never shrinks. Reports arrive across the whole IME
  // animation, so it waits for a quiet period, measures once, and stays
  // silent if Blink already has the caret in view — a second nudge on
  // the same pixels is exactly the jitter this avoids.
  static const String _keyboardFallback = r'''
(function(){
  if (window.__imeGuard) return;
  window.__imeGuard = 1;
  var FIELDS = 'input,textarea,select,[contenteditable="true"]';
  var QUIET = 160;
  var MAX_COVER = 0.86;
  var SLACK = 5;
  var cover = 0;
  var timer = 0;
  var held = null;
  var savedInline = '';
  var savedBase = '';
  var offset = 0;

  function viewportShrank(){
    var vv = window.visualViewport;
    return !!(vv && vv.height > 0 && (window.innerHeight - vv.height) > 1);
  }
  function margin(){
    var n = Math.round(window.innerHeight * 0.02);
    if (n < 9) return 9;
    if (n > 22) return 22;
    return n;
  }
  function focused(){
    var el = document.activeElement;
    if (!el || typeof el.matches !== 'function') return null;
    try { return el.matches(FIELDS) ? el : null; } catch (e) { return null; }
  }
  function fixedAncestor(node){
    for (var n = node.parentElement; n && n !== document.body; n = n.parentElement){
      if (window.getComputedStyle(n).position === 'fixed') return n;
    }
    return null;
  }
  function reset(){
    offset = 0;
    if (!held) return;
    held.style.transform = savedInline;
    held = null;
    savedInline = '';
    savedBase = '';
  }
  function apply(el, dy){
    if (held !== el){
      reset();
      held = el;
      savedInline = el.style.transform;
      var current = window.getComputedStyle(el).transform;
      savedBase = current === 'none' ? '' : current;
    }
    offset = dy;
    el.style.transform = (savedBase ? savedBase + ' ' : '') + 'translate3d(0px,' + (-dy) + 'px,0px)';
  }
  function visibleTop(){
    return viewportShrank() ? window.visualViewport.offsetTop : 0;
  }
  function visibleBottom(){
    if (viewportShrank()){
      var vv = window.visualViewport;
      return vv.offsetTop + vv.height;
    }
    var c = cover > MAX_COVER ? MAX_COVER : cover;
    return window.innerHeight * (1 - c);
  }
  function reflow(){
    var el = focused();
    if (!el || cover <= 0){ reset(); return; }
    var anchor = fixedAncestor(el);
    var applied = (held && held === anchor) ? offset : 0;
    var rect = el.getBoundingClientRect();
    var pad = viewportShrank() ? 0 : margin();
    var below = rect.bottom + applied - (visibleBottom() - pad);
    var above = rect.top + applied - (visibleTop() + pad);
    var dy = below < above ? below : above;
    if (dy < SLACK) dy = 0;
    if (!anchor){
      reset();
      if (dy > 0) window.scrollBy(0, dy);
      return;
    }
    if (dy === 0 && !held) return;
    apply(anchor, dy);
  }
  function schedule(){
    window.clearTimeout(timer);
    timer = window.setTimeout(function(){ timer = 0; reflow(); }, QUIET);
  }
  window.__imeInset = function(share){
    cover = share > 0 ? share : 0;
    if (cover <= 0){
      window.clearTimeout(timer);
      timer = 0;
      reset();
      return;
    }
    schedule();
  };
  document.addEventListener('focusin', schedule, true);
  if (window.visualViewport){
    window.visualViewport.addEventListener('resize', schedule);
    window.visualViewport.addEventListener('scroll', schedule);
  }
})();
''';
}
