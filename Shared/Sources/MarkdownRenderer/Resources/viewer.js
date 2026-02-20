'use strict';

// ── Initialize markdown-it and pre-warm the JIT ──
var md = window.markdownit({
  html: true,
  typographer: true,
  breaks: true,
  linkify: true
}).use(window.markdownitFootnote)
  .use(window.markdownitTaskLists);
md.render('');

// ── DOM refs ──
var viewer = document.getElementById('viewer');
var metaHeader = document.getElementById('meta-header');
var content = document.getElementById('content');

// ── Native app detection ──
var isNativeApp = !!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tocData);

// ── Parse YAML frontmatter (simple key: value, no dependency) ──
var _frontmatterRe = /^---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)(?:\r?\n|$)([\s\S]*)$/;

function parseFrontmatter(text) {
  var match = text.match(_frontmatterRe);
  if (!match) return { meta: null, body: text };

  var meta = {};
  var lines = match[1].split('\n');
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/\r$/, '');
    var colon = line.indexOf(':');
    if (colon === -1) continue;
    var key = line.substring(0, colon).trim();
    var val = line.substring(colon + 1).trim();
    if (!key) continue;
    // Strip surrounding quotes
    if (val.length >= 2 &&
        ((val[0] === '"' && val[val.length - 1] === '"') ||
         (val[0] === "'" && val[val.length - 1] === "'"))) {
      val = val.substring(1, val.length - 1);
    }
    // Coerce booleans
    if (val === 'true') val = true;
    else if (val === 'false') val = false;
    meta[key] = val;
  }

  var hasKeys = false;
  for (var k in meta) { hasKeys = true; break; }
  return { meta: hasKeys ? meta : null, body: match[2] };
}

// ── Heading ID (pandoc-compatible) ──
function headingId(text) {
  return text
    .toLowerCase()
    .replace(/<[^>]+>/g, '')
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

// ── HTML escaping via string replacement (no DOM) ──
var _escapeMap = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
var _escapeRe = /[&<>"']/g;

function escapeHtml(str) {
  return str.replace(_escapeRe, function(ch) { return _escapeMap[ch]; });
}

// ── Build metadata header ──
function buildMetaHeader(meta) {
  if (!meta) { metaHeader.innerHTML = ''; return; }

  var html = '<header id="title-block-header">';

  if (meta.confidential === 'true' || meta.confidential === true) {
    html += '<div class="confidential">CONFIDENTIAL</div>';
  }

  if (meta.title) {
    html += '<h1 class="title">' + escapeHtml(String(meta.title)) + '</h1>';
    document.title = meta.title + ' \u2014 Markdown Viewer';
  }

  html += '<hr />';

  var skipKeys = ['title', 'confidential'];
  var entries = Object.entries(meta).filter(function(e) {
    return skipKeys.indexOf(e[0]) === -1 && e[1];
  });

  if (entries.length > 0) {
    html += '<table class="metadata">';
    entries.forEach(function(entry) {
      html += '<tr><th>' + escapeHtml(entry[0].charAt(0).toUpperCase() + entry[0].slice(1)) + '</th>';
      html += '<td>' + escapeHtml(String(entry[1])) + '</td></tr>';
    });
    html += '</table>';
  }

  html += '<hr /></header>';
  metaHeader.innerHTML = html;
}

// ── Assign heading IDs (deduplicated) ──
function assignHeadingIds(container) {
  var seen = {};
  container.querySelectorAll('h2, h3').forEach(function(h) {
    var base = headingId(h.textContent);
    var id = base;
    if (seen[id]) {
      id = base + '-' + seen[base];
    }
    seen[base] = (seen[base] || 1) + 1;
    h.id = id;
  });
}

// ── Post-process footnotes ──
var _backrefRe = /<a[^>]*class="footnote-backref"[^>]*>[\s\S]*?<\/a>/g;

function processFootnotes(container) {
  var footnotesSection = container.querySelector('section.footnotes');
  if (!footnotesSection) return;

  var footnoteContents = {};
  footnotesSection.querySelectorAll('li.footnote-item').forEach(function(li) {
    footnoteContents[li.id] = li.innerHTML.replace(_backrefRe, '').trim();
  });

  container.querySelectorAll('sup.footnote-ref').forEach(function(sup) {
    var a = sup.querySelector('a');
    if (!a) return;
    var href = a.getAttribute('href');
    var fnId = href ? href.replace('#', '') : '';
    var fnContent = footnoteContents[fnId] || '';
    var label = a.textContent;

    var span = document.createElement('span');
    span.className = 'fn-ref';
    span.tabIndex = 0;
    span.innerHTML = '<sup>' + label + '</sup><span class="fn-tooltip">' + fnContent + '</span>';
    sup.replaceWith(span);
  });

  footnotesSection.remove();
}

// ── Native app scroll tracking ──
var _scrollHandler = null;
var _lastReportedId = null;

function initNativeScrollTracking() {
  var headings = document.querySelectorAll('h2[id], h3[id]');

  if (_scrollHandler) {
    window.removeEventListener('scroll', _scrollHandler);
    _scrollHandler = null;
  }

  if (!headings.length) {
    _lastReportedId = null;
    return;
  }

  var ticking = false;

  function reportActiveHeading() {
    var cur = null;
    var y = window.scrollY + 80;
    for (var i = 0; i < headings.length; i++) {
      if (headings[i].offsetTop <= y) cur = headings[i];
    }
    var id = cur ? cur.id : '';
    if (id !== _lastReportedId) {
      _lastReportedId = id;
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.scrollPosition) {
        window.webkit.messageHandlers.scrollPosition.postMessage(id);
      }
    }
  }

  _scrollHandler = function() {
    if (!ticking) {
      ticking = true;
      requestAnimationFrame(function() {
        reportActiveHeading();
        ticking = false;
      });
    }
  };

  window.addEventListener('scroll', _scrollHandler, { passive: true });
  reportActiveHeading();
}

// ── Render markdown ──
var _hasRendered = false;

window.renderMarkdown = function(text) {
  if (!text.trim()) {
    metaHeader.innerHTML = '';
    content.innerHTML = '<p class="empty-state">Empty document</p>';
    viewer.classList.add('active');
    _hasRendered = true;
    return;
  }

  var parsed = parseFrontmatter(text);
  buildMetaHeader(parsed.meta);

  if (!parsed.meta || !parsed.meta.title) {
    document.title = 'Markdown Viewer';
  }

  // Save scroll position for re-renders
  var scrollY = _hasRendered ? window.scrollY : 0;

  content.innerHTML = md.render(parsed.body);
  processFootnotes(content);
  assignHeadingIds(content);

  viewer.classList.add('active');

  // Restore scroll position on re-renders
  if (_hasRendered) {
    window.scrollTo(0, scrollY);
  } else {
    _hasRendered = true;
  }

  // Defer non-critical work
  if (isNativeApp) {
    (window.requestIdleCallback || requestAnimationFrame)(function() {
      var headings = content.querySelectorAll('h2[id], h3[id]');
      var entries = [];
      headings.forEach(function(h) {
        entries.push({
          id: h.id,
          title: h.textContent,
          level: parseInt(h.tagName.charAt(1), 10)
        });
      });
      window.webkit.messageHandlers.tocData.postMessage(JSON.stringify(entries));
      initNativeScrollTracking();
    });
  }
};

// ── Scroll to heading (called from native app) ──
window.scrollToHeading = function(id) {
  var el = document.getElementById(id);
  if (!el) return;
  var motion = window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth';
  el.scrollIntoView({ behavior: motion, block: 'start' });
};

// ── Font size controls (called from native app) ──
var baseFontSize = 13;
var currentFontSize = baseFontSize;

window.increaseFontSize = function() {
  currentFontSize = Math.min(currentFontSize + 1, 32);
  document.body.style.fontSize = currentFontSize + 'px';
};

window.decreaseFontSize = function() {
  currentFontSize = Math.max(currentFontSize - 1, 8);
  document.body.style.fontSize = currentFontSize + 'px';
};

window.resetFontSize = function() {
  currentFontSize = baseFontSize;
  document.body.style.fontSize = currentFontSize + 'px';
};
