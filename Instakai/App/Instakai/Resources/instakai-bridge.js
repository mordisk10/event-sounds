/*
 * Instakai bridge
 * ---------------
 * Injected into the hosted instagram.com web view at document start. It does
 * two things:
 *
 *   1. Reports which surface (feed / reels / stories / …) is on screen, so
 *      rules scoped with `.surface(...)` work.
 *   2. Executes the surface commands the native macro dispatcher sends.
 *
 * Design notes:
 *
 * - Instagram ships obfuscated class names that change often, so nothing here
 *   matches on styling. We use `aria-label`, `role`, semantic tags and SVG
 *   titles, which are far more stable because they carry accessibility meaning.
 * - Every selector list is ordered most-specific first and falls back to a
 *   geometric heuristic. When a control genuinely cannot be found we report a
 *   failure rather than clicking something random.
 * - Labels are matched in several languages because the interface follows the
 *   account language, not the device language.
 */
(function () {
  'use strict';

  if (window.__instakai) { return; }

  const send = (payload) => {
    try {
      window.webkit.messageHandlers.instakai.postMessage(payload);
    } catch (error) {
      /* Bridge not attached (e.g. opened in Safari for debugging). */
    }
  };

  /* ---------------------------------------------------------------- labels */

  const LABELS = {
    like:    ['like', 'beğen', 'me gusta', "j'aime", 'gefällt mir', 'curtir'],
    unlike:  ['unlike', 'beğenmekten vazgeç', 'beğeniyi geri al', 'no me gusta'],
    comment: ['comment', 'yorum yap', 'yorum', 'comentar', 'commenter'],
    share:   ['share', 'paylaş', 'compartir', 'partager', 'teilen'],
    save:    ['save', 'kaydet', 'guardar', 'enregistrer', 'speichern'],
    follow:  ['follow', 'takip et', 'seguir', 'suivre', 'folgen'],
    audio:   ['audio', 'ses', 'sound', 'sonido', 'mute', 'unmute', 'sesi aç', 'sesi kapat'],
    back:    ['back', 'geri', 'close', 'kapat', 'atrás', 'retour', 'zurück']
  };

  const normalise = (value) => (value || '').toString().trim().toLowerCase();

  const matchesLabel = (element, keys) => {
    const haystack = [
      element.getAttribute('aria-label'),
      element.getAttribute('title'),
      element.textContent
    ].map(normalise).join(' ');
    return keys.some((key) => haystack.includes(key));
  };

  const isVisible = (element) => {
    if (!element) { return false; }
    const rect = element.getBoundingClientRect();
    if (rect.width < 4 || rect.height < 4) { return false; }
    if (rect.bottom < 0 || rect.top > window.innerHeight) { return false; }
    const style = window.getComputedStyle(element);
    return style.visibility !== 'hidden' && style.display !== 'none' && style.opacity !== '0';
  };

  /* Clickable ancestors: Instagram often puts the label on an inner <span>. */
  const clickableAncestor = (element) => {
    let node = element;
    for (let depth = 0; node && depth < 6; depth += 1) {
      const role = normalise(node.getAttribute && node.getAttribute('role'));
      if (node.tagName === 'BUTTON' || node.tagName === 'A' || role === 'button' || role === 'link') {
        return node;
      }
      node = node.parentElement;
    }
    return element;
  };

  const findByLabel = (keys, root) => {
    const scope = root || document;
    const candidates = scope.querySelectorAll(
      'button, a, [role="button"], [role="link"], svg[aria-label], [aria-label]'
    );
    for (const candidate of candidates) {
      if (matchesLabel(candidate, keys) && isVisible(candidate)) {
        return clickableAncestor(candidate);
      }
    }
    return null;
  };

  /* --------------------------------------------------------------- surface */

  const detectSurface = () => {
    const path = window.location.pathname;
    if (path.startsWith('/reels') || path.startsWith('/reel/')) { return 'reels'; }
    if (path.startsWith('/stories')) { return 'stories'; }
    if (path.startsWith('/explore')) { return 'explore'; }
    if (path.startsWith('/direct')) { return 'directMessages'; }
    if (path.startsWith('/p/') || path.startsWith('/tv/')) { return 'postDetail'; }
    if (path === '/' || path === '') { return 'feed'; }
    /* /<username>/ with no further segments is a profile. */
    if (/^\/[^/]+\/?$/.test(path)) { return 'profile'; }
    return 'unknown';
  };

  let lastSurface = null;
  const reportSurface = () => {
    const surface = detectSurface();
    if (surface === lastSurface) { return; }
    lastSurface = surface;
    send({ kind: 'surface', surface });
  };

  /* -------------------------------------------------- scrolling containers */

  /*
   * Instagram scrolls an inner element rather than the document on several
   * surfaces. Find the deepest scrollable container under the viewport centre;
   * fall back to the window.
   */
  const scrollTarget = () => {
    const centre = document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2);
    let node = centre;
    while (node && node !== document.body) {
      const style = window.getComputedStyle(node);
      const scrollable = /(auto|scroll)/.test(style.overflowY);
      if (scrollable && node.scrollHeight > node.clientHeight + 8) {
        return node;
      }
      node = node.parentElement;
    }
    return null;
  };

  const performScroll = (dx, dy, animated) => {
    const behavior = animated ? 'smooth' : 'auto';
    const target = scrollTarget();
    if (target) {
      target.scrollBy({ top: dy, left: dx, behavior });
    } else {
      window.scrollBy({ top: dy, left: dx, behavior });
    }
    return true;
  };

  /* ----------------------------------------------------------------- media */

  const focusedVideo = () => {
    const videos = Array.from(document.querySelectorAll('video')).filter(isVisible);
    if (videos.length === 0) { return null; }
    /* The one whose centre is nearest the viewport centre is the one in view. */
    const centre = window.innerHeight / 2;
    return videos.sort((a, b) => {
      const da = Math.abs(a.getBoundingClientRect().top + a.getBoundingClientRect().height / 2 - centre);
      const db = Math.abs(b.getBoundingClientRect().top + b.getBoundingClientRect().height / 2 - centre);
      return da - db;
    })[0];
  };

  /*
   * The article/section wrapping the focused media. Scoping button lookups to
   * it stops "like" from hitting the post above when the feed is mid-scroll.
   */
  const focusedPost = () => {
    const media = focusedVideo() || (() => {
      const images = Array.from(document.querySelectorAll('article img')).filter(isVisible);
      const centre = window.innerHeight / 2;
      return images.sort((a, b) => {
        const ra = a.getBoundingClientRect();
        const rb = b.getBoundingClientRect();
        return Math.abs(ra.top + ra.height / 2 - centre) - Math.abs(rb.top + rb.height / 2 - centre);
      })[0];
    })();
    if (!media) { return document; }
    return media.closest('article') || media.closest('section') || document;
  };

  /* -------------------------------------------------------------- commands */

  const clickIfFound = (element) => {
    if (!element) { return false; }
    element.click();
    return true;
  };

  const isLiked = (button) => {
    if (!button) { return false; }
    /* Instagram's liked state uses a filled heart whose label flips to "Unlike". */
    return matchesLabel(button, LABELS.unlike) ||
           normalise(button.getAttribute('aria-pressed')) === 'true';
  };

  const commands = {
    scroll(payload) {
      return performScroll(payload.dx || 0, payload.dy || 0, payload.animated !== false);
    },

    like() {
      const scope = focusedPost();
      const button = findByLabel(LABELS.like, scope) || findByLabel(LABELS.like, document);
      if (!button) { return false; }
      if (isLiked(button)) { return true; }
      return clickIfFound(button);
    },

    unlike() {
      const scope = focusedPost();
      const button = findByLabel(LABELS.unlike, scope) || findByLabel(LABELS.like, scope);
      if (!button || !isLiked(button)) { return false; }
      return clickIfFound(button);
    },

    doubleTapLike() {
      const media = focusedVideo() || focusedPost().querySelector('img');
      if (!media) { return false; }
      const rect = media.getBoundingClientRect();
      const x = rect.left + rect.width / 2;
      const y = rect.top + rect.height / 2;
      const options = { bubbles: true, cancelable: true, clientX: x, clientY: y, detail: 2 };
      media.dispatchEvent(new MouseEvent('mousedown', options));
      media.dispatchEvent(new MouseEvent('mouseup', options));
      media.dispatchEvent(new MouseEvent('dblclick', options));
      return true;
    },

    savePost() {
      return clickIfFound(findByLabel(LABELS.save, focusedPost()) || findByLabel(LABELS.save, document));
    },

    openComments() {
      return clickIfFound(findByLabel(LABELS.comment, focusedPost()) ||
                          findByLabel(LABELS.comment, document));
    },

    tap(payload) {
      const map = {
        likeButton: LABELS.like,
        commentButton: LABELS.comment,
        shareButton: LABELS.share,
        saveButton: LABELS.save,
        followButton: LABELS.follow,
        audioToggle: LABELS.audio,
        backButton: LABELS.back
      };
      if (payload.target === 'centerOfScreen') {
        const element = document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2);
        return clickIfFound(element);
      }
      if (payload.target === 'profileAvatar') {
        return clickIfFound(focusedPost().querySelector('header a img'));
      }
      const keys = map[payload.target];
      if (!keys) { return false; }
      return clickIfFound(findByLabel(keys, focusedPost()) || findByLabel(keys, document));
    },

    closeOverlay() {
      const dialog = document.querySelector('[role="dialog"]');
      if (dialog) {
        const close = findByLabel(LABELS.back, dialog);
        if (close) { return clickIfFound(close); }
      }
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
      return Boolean(dialog);
    },

    navigate(payload) {
      const routes = {
        home: '/',
        reels: '/reels/',
        explore: '/explore/',
        notifications: '/notifications/',
        directMessages: '/direct/inbox/',
        search: '/explore/search/'
      };
      if (payload.destination === 'back') {
        window.history.back();
        return true;
      }
      if (payload.destination === 'profile') {
        return clickIfFound(document.querySelector('nav a[href*="/"] img[alt*="rofil"]')) ||
               clickIfFound(findByLabel(['profile', 'profil'], document));
      }
      const route = routes[payload.destination];
      if (!route) { return false; }
      /* Prefer clicking the nav link so the SPA router handles it; a hard
         location change would reload the whole app. */
      const link = document.querySelector('nav a[href="' + route + '"]') ||
                   document.querySelector('a[href="' + route + '"]');
      if (link) { return clickIfFound(link); }
      window.location.href = route;
      return true;
    },

    toggleMute() {
      const video = focusedVideo();
      if (video) {
        video.muted = !video.muted;
        return true;
      }
      return clickIfFound(findByLabel(LABELS.audio, document));
    },

    playPause() {
      const video = focusedVideo();
      if (!video) { return false; }
      if (video.paused) { video.play(); } else { video.pause(); }
      return true;
    }
  };

  /* ----------------------------------------------------------------- entry */

  window.__instakai = {
    version: 1,

    /* Called from native via evaluateJavaScript. */
    perform(json) {
      let command;
      try {
        command = typeof json === 'string' ? JSON.parse(json) : json;
      } catch (error) {
        send({ kind: 'error', message: 'Geçersiz komut: ' + error.message });
        return false;
      }
      const handler = commands[command.kind];
      if (!handler) {
        send({ kind: 'error', message: 'Bilinmeyen komut: ' + command.kind });
        return false;
      }
      let ok = false;
      try {
        ok = handler(command) === true;
      } catch (error) {
        send({ kind: 'error', message: command.kind + ': ' + error.message });
        return false;
      }
      send({ kind: 'result', command: command.kind, ok });
      return ok;
    },

    surface: detectSurface
  };

  /* Surface changes: the SPA rewrites history rather than navigating. */
  const originalPushState = history.pushState;
  history.pushState = function () {
    originalPushState.apply(this, arguments);
    reportSurface();
  };
  window.addEventListener('popstate', reportSurface);
  window.addEventListener('load', reportSurface);
  setInterval(reportSurface, 1000);
  reportSurface();

  send({ kind: 'ready', version: 1 });
}());
