// ─────────────────────────────────────────
// Servify PWA Install Button
// Add this to your HTML: <script src="/pwa-install.js"></script>
// ─────────────────────────────────────────

(function () {
  let _deferredPrompt = null;

  // ── Register Service Worker ──
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js').catch(() => {});
    });
  }

  // ── Inject Button into DOM ──
  function injectButton() {
    // Don't show if already installed
    const isInstalled =
      window.matchMedia('(display-mode: standalone)').matches ||
      window.navigator.standalone;
    if (isInstalled) return;

    const style = document.createElement('style');
    style.textContent = `
      #servify-pwa-wrap {
        position: fixed;
        bottom: 24px;
        right: 24px;
        z-index: 99999;
        animation: pwaFadeIn 0.4s ease;
      }
      @keyframes pwaFadeIn {
        from { opacity: 0; transform: translateY(12px); }
        to   { opacity: 1; transform: translateY(0); }
      }
      #servify-pwa-btn {
        display: flex;
        align-items: center;
        gap: 10px;
        background: #e8521a;
        color: #fff;
        border: none;
        border-radius: 100px;
        padding: 14px 22px;
        font-family: 'DM Sans', 'Outfit', sans-serif;
        font-size: 0.9rem;
        font-weight: 600;
        box-shadow: 0 4px 24px rgba(232,82,26,0.35);
        cursor: pointer;
        transition: background 0.2s, transform 0.15s;
        white-space: nowrap;
        letter-spacing: 0.01em;
      }
      #servify-pwa-btn:hover {
        background: #d44810;
        transform: translateY(-2px);
      }
      #servify-pwa-btn:active {
        transform: scale(0.97);
      }
    `;
    document.head.appendChild(style);

    const wrap = document.createElement('div');
    wrap.id = 'servify-pwa-wrap';
    wrap.innerHTML = `
      <button id="servify-pwa-btn">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
          stroke="currentColor" stroke-width="2.5"
          stroke-linecap="round" stroke-linejoin="round">
          <rect x="5" y="2" width="14" height="20" rx="2"/>
          <line x1="12" y1="18" x2="12" y2="18.01"/>
        </svg>
        Install the App
      </button>
    `;
    document.body.appendChild(wrap);

    document.getElementById('servify-pwa-btn').addEventListener('click', handleInstall);
  }

  // ── Handle Install ──
  async function handleInstall() {
    if (_deferredPrompt) {
      _deferredPrompt.prompt();
      const { outcome } = await _deferredPrompt.userChoice;
      if (outcome === 'accepted') {
        document.getElementById('servify-pwa-wrap').remove();
      }
      _deferredPrompt = null;
    } else {
      const isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);
      if (isIOS) {
        alert(
          'Install Servify on your iPhone:\n\n' +
          '1. Tap the Share button \u2191 at the bottom of Safari\n' +
          '2. Tap "Add to Home Screen"\n' +
          '3. Tap "Add" \u2014 done! \uD83C\uDF89'
        );
      } else {
        alert(
          'Install Servify on your phone:\n\n' +
          '1. Tap the menu \u22EE at the top right of Chrome\n' +
          '2. Tap "Add to Home Screen" or "Install App"\n' +
          '3. Tap "Add" \u2014 done! \uD83C\uDF89'
        );
      }
    }
  }

  // ── Listen for browser install prompt ──
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    _deferredPrompt = e;
  });

  // ── Hide when installed ──
  window.addEventListener('appinstalled', () => {
    const wrap = document.getElementById('servify-pwa-wrap');
    if (wrap) wrap.remove();
    _deferredPrompt = null;
  });

  // ── Init on DOM ready ──
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectButton);
  } else {
    injectButton();
  }
})();
