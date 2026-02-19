'use strict';

// ── Initialize markdown-it ──
var md = window.markdownit({
  html: true,
  typographer: true,
  breaks: true,
  linkify: true
}).use(window.markdownitFootnote);

// ── DOM refs ──
var viewer = document.getElementById('viewer');
var tocSidebar = document.getElementById('toc-sidebar');
var tocList = document.getElementById('toc-list');
var metaHeader = document.getElementById('meta-header');
var content = document.getElementById('content');

// ── Native app detection ──
var isNativeApp = !!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tocData);

// Hide in-page TOC sidebar when running inside the native app (sidebar is provided natively)
if (isNativeApp && tocSidebar) {
  tocSidebar.style.display = 'none';
}

// ── Parse YAML frontmatter ──
function parseFrontmatter(text) {
  var match = text.match(/^---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)(?:\r?\n|$)([\s\S]*)$/);
  if (!match) return { meta: null, body: text };

  try {
    var parsed = jsyaml.load(match[1]);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return { meta: parsed, body: match[2] };
    }
  } catch (e) {
    // Fall through to return unparsed body
  }

  return { meta: null, body: text };
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

function escapeHtml(str) {
  var div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// ── Build metadata header (matches template.html structure) ──
function buildMetaHeader(meta) {
  if (!meta) { metaHeader.innerHTML = ''; return; }

  var html = '<header id="title-block-header">';

  if (meta.confidential === 'true' || meta.confidential === true) {
    html += '<div class="confidential">CONFIDENTIAL</div>';
  }

  if (meta.title) {
    html += '<h1 class="title">' + escapeHtml(meta.title) + '</h1>';
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
      html += '<td>' + escapeHtml(entry[1]) + '</td></tr>';
    });
    html += '</table>';
  }

  html += '<hr /></header>';
  metaHeader.innerHTML = html;
}

// ── Add heading IDs and build TOC (nested ul for h3 under h2) ──
function processHeadingsAndToc(container) {
  var headings = container.querySelectorAll('h2, h3');
  var tocHtml = '';
  var inSub = false;

  headings.forEach(function(h) {
    var id = headingId(h.textContent);
    h.id = id;
    var level = h.tagName.toLowerCase();

    if (level === 'h2') {
      if (inSub) { tocHtml += '</ul></li>'; inSub = false; }
      tocHtml += '<li><a href="#' + id + '">' + escapeHtml(h.textContent) + '</a>';
    } else {
      if (!inSub) { tocHtml += '<ul>'; inSub = true; }
      tocHtml += '<li><a href="#' + id + '">' + escapeHtml(h.textContent) + '</a></li>';
    }
  });

  if (inSub) tocHtml += '</ul></li>';
  else if (tocHtml) tocHtml += '</li>';

  tocList.innerHTML = tocHtml;
}

// ── Post-process footnotes into inline tooltips ──
function processFootnotes(container) {
  var footnotesSection = container.querySelector('section.footnotes');
  if (!footnotesSection) return;

  var footnoteContents = {};
  footnotesSection.querySelectorAll('li.footnote-item').forEach(function(li) {
    var clone = li.cloneNode(true);
    clone.querySelectorAll('.footnote-backref').forEach(function(a) { a.remove(); });
    footnoteContents[li.id] = clone.innerHTML.trim();
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

// ── Scroll spy (JS fallback) ──
function initScrollSpy() {
  var links = tocSidebar.querySelectorAll('a[href^="#"]');
  var sects = [];
  links.forEach(function(l) {
    var el = document.getElementById(l.getAttribute('href').slice(1));
    if (el) sects.push({ el: el, link: l });
  });

  function update() {
    var cur = null;
    var y = window.scrollY + 80;
    for (var i = 0; i < sects.length; i++) {
      if (sects[i].el.offsetTop <= y) cur = sects[i];
    }
    links.forEach(function(l) { l.classList.remove('active'); });
    if (cur) cur.link.classList.add('active');
  }

  window.addEventListener('scroll', update, { passive: true });
  update();
}

// ── Native app scroll tracking ──
function initNativeScrollTracking() {
  var headings = document.querySelectorAll('h2[id], h3[id]');
  if (!headings.length) return;

  var lastReportedId = null;

  function reportActiveHeading() {
    var cur = null;
    var y = window.scrollY + 80;
    for (var i = 0; i < headings.length; i++) {
      if (headings[i].offsetTop <= y) cur = headings[i];
    }
    var id = cur ? cur.id : '';
    if (id !== lastReportedId) {
      lastReportedId = id;
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.scrollPosition) {
        window.webkit.messageHandlers.scrollPosition.postMessage(id);
      }
    }
  }

  window.addEventListener('scroll', reportActiveHeading, { passive: true });
  reportActiveHeading();
}

// ── Render markdown ──
window.renderMarkdown = function(text) {
  var parsed = parseFrontmatter(text);
  buildMetaHeader(parsed.meta);

  if (!parsed.meta || !parsed.meta.title) {
    document.title = 'Markdown Viewer';
  }

  content.innerHTML = md.render(parsed.body);
  processFootnotes(content);
  processHeadingsAndToc(content);

  // Activate viewer
  viewer.classList.add('active');
  if (tocSidebar) tocSidebar.classList.add('active');

  // Post TOC data to native app
  if (isNativeApp) {
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
  }

  // Scroll spy for in-page TOC (skip if browser supports CSS scroll-target-group)
  if (!isNativeApp && !CSS.supports('scroll-target-group', 'auto')) {
    initScrollSpy();
  }

  window.scrollTo(0, 0);
};

// ── Set theme (called from native app) ──
window.setTheme = function(name) {
  document.body.setAttribute('data-theme', name);
};

// ── Scroll to heading (called from native app) ──
window.scrollToHeading = function(id) {
  var el = document.getElementById(id);
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
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
