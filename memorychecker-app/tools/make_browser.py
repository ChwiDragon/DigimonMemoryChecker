r"""memorychecker.html (browser / PWA / artifact) = memorycheckerapk.html + browser-only parts:
  - landscape windows (desktop, a phone browser turned sideways) show the layout without rotating it
  - fullscreen by default on phones (the first tap enters it; there is no fullscreen button)
  - installable web app (PWA): manifest, icons and service worker, only on the real https site

Run from memorychecker-app/ after every change to memorycheckerapk.html:
  ..\.venv\Scripts\python.exe tools\make_browser.py
"""
from pathlib import Path

APP = Path(__file__).resolve().parents[1]

LANDSCAPE_CSS = '''  /* Browser only: a landscape window (desktop, or a phone browser turned sideways) shows the
     landscape layout as it is instead of rotating it. The APK is portrait-locked and always rotates
     (its keyboard can make the WebView wider than tall, so this rule must not go into the APK). */
  @media (orientation: landscape) {
    .rotator {
      left: 0; transform: none;
      width: var(--real-w, 100vw); height: var(--real-h, 100vh);
      /* not turned, so the safe-area insets keep their own directions */
      --sa-t: env(safe-area-inset-top, 0px);
      --sa-r: env(safe-area-inset-right, 0px);
      --sa-b: env(safe-area-inset-bottom, 0px);
      --sa-l: env(safe-area-inset-left, 0px);
    }
  }

'''

BROWSER_JS = '''  // ---------- Browser only: fullscreen by default, installable web app (PWA) ----------
  // A page may enter fullscreen only from a tap, so on a phone every tap outside fullscreen asks for it
  // (the first tap, and again after the player leaves it). Desktop windows and the installed app
  // (already fullscreen from its manifest) are left alone.
  (() => {
    const installed = matchMedia("(display-mode: fullscreen), (display-mode: standalone)").matches;
    if (installed || !matchMedia("(pointer: coarse)").matches) return;
    document.addEventListener("pointerup", () => {
      if (document.fullscreenElement || document.webkitFullscreenElement) return;
      const el = document.documentElement;
      const req = el.requestFullscreen || el.webkitRequestFullscreen;
      if (!req) return;
      try { const p = req.call(el, { navigationUI: "hide" }); if (p && p.catch) p.catch(() => {}); } catch {}
    }, { passive: true });
  })();
  // Install as an app: only on the real website (https, top window), not in the APK, an artifact or a local file.
  if (location.protocol === "https:" && window.top === window && !window.Capacitor) {
    [["manifest", "manifest.webmanifest"], ["icon", "pwa/icon-192.png"], ["apple-touch-icon", "pwa/apple-touch-icon.png"]].forEach(([rel, href]) => {
      const link = document.createElement("link");
      link.rel = rel; link.href = href;
      document.head.appendChild(link);
    });
    if ("serviceWorker" in navigator) addEventListener("load", () => { navigator.serviceWorker.register("sw.js").catch(() => {}); });
  }

'''


def build():
    s = (APP / 'memorycheckerapk.html').read_text(encoding='utf-8')
    for anchor, add in [('  @media (prefers-reduced-motion: reduce) {', LANDSCAPE_CSS),
                        ('  // ---------- Initial ----------', BROWSER_JS)]:
        assert s.count(anchor) == 1, anchor
        s = s.replace(anchor, add + anchor)
    (APP / 'memorychecker.html').write_text(s, encoding='utf-8', newline='')


if __name__ == '__main__':
    build()
    print('memorychecker.html built')
