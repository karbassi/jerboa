import { describe, it, expect, beforeEach } from 'vitest';

function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const el = document.createElement('script');
    el.src = src;
    el.onload = () => resolve();
    el.onerror = () => reject(new Error(`Failed to load ${src}`));
    document.head.appendChild(el);
  });
}

let initialized = false;

beforeEach(async () => {
  document.body.innerHTML = `
    <div id="viewer">
      <main>
        <div id="meta-header"></div>
        <div id="content"></div>
      </main>
    </div>
  `;

  if (!initialized) {
    await loadScript('/markdown-it.min.js');
    await loadScript('/markdown-it-footnote.min.js');
    await loadScript('/markdown-it-task-lists.min.js');
    await loadScript('/markdown-it-github-alerts.min.js');
    await loadScript('/viewer.js');
    initialized = true;
  } else {
    (window as any).eval(`
      viewer = document.getElementById('viewer');
      metaHeader = document.getElementById('meta-header');
      content = document.getElementById('content');
      _hasRendered = false;
    `);
  }
});

function render(markdown: string) {
  (window as any).renderMarkdown(markdown);
}

function q(sel: string) {
  return document.getElementById('content')!.querySelector(sel);
}

function qa(sel: string) {
  return document.getElementById('content')!.querySelectorAll(sel);
}

function meta() {
  return document.getElementById('meta-header')!;
}

// ─── renderMarkdown ────────────────────────────────────────────────

describe('renderMarkdown', () => {
  it('renders basic markdown to HTML', () => {
    render('Hello **world**');
    expect(q('p strong')!.textContent).toBe('world');
  });

  it('shows empty state for whitespace-only input', () => {
    render('   \n  ');
    expect(q('.empty-state')).not.toBeNull();
    expect(q('.empty-state')!.textContent).toBe('Empty document');
  });

  it('activates viewer on render', () => {
    render('# Hello');
    expect(document.getElementById('viewer')!.classList.contains('active')).toBe(true);
  });

  it('activates viewer on empty render', () => {
    render('  ');
    expect(document.getElementById('viewer')!.classList.contains('active')).toBe(true);
  });

  it('renders inline code', () => {
    render('Use `console.log`');
    expect(q('code')!.textContent).toBe('console.log');
  });

  it('renders fenced code blocks', () => {
    render('```js\nconst x = 1;\n```');
    expect(q('pre code')!.textContent).toContain('const x = 1;');
  });

  it('renders links', () => {
    render('[Example](https://example.com)');
    const a = q('a') as HTMLAnchorElement;
    expect(a.href).toBe('https://example.com/');
    expect(a.textContent).toBe('Example');
  });

  it('renders images', () => {
    render('![alt text](image.png)');
    const img = q('img') as HTMLImageElement;
    expect(img.alt).toBe('alt text');
    expect(img.src).toContain('image.png');
  });

  it('renders blockquotes', () => {
    render('> A wise quote');
    expect(q('blockquote p')!.textContent).toBe('A wise quote');
  });

  it('renders ordered lists', () => {
    render('1. First\n2. Second\n3. Third');
    expect(qa('ol li').length).toBe(3);
  });

  it('renders unordered lists', () => {
    render('- Alpha\n- Beta');
    expect(qa('ul li').length).toBe(2);
  });

  it('renders tables', () => {
    render('| A | B |\n|---|---|\n| 1 | 2 |');
    expect(q('table')).not.toBeNull();
    expect(qa('td').length).toBe(2);
  });

  it('renders horizontal rules', () => {
    render('Above\n\n---\n\nBelow');
    expect(q('hr')).not.toBeNull();
  });

  it('renders HTML passthrough', () => {
    render('<div class="custom">raw HTML</div>');
    expect(q('.custom')!.textContent).toBe('raw HTML');
  });

  it('renders line breaks with breaks:true', () => {
    render('Line one\nLine two');
    const br = document.getElementById('content')!.querySelector('br');
    expect(br).not.toBeNull();
  });

  it('resets document title when no frontmatter title', () => {
    render('---\ntitle: Custom\n---\nBody.');
    expect(document.title).toContain('Custom');
    render('No frontmatter here.');
    expect(document.title).toBe('Markdown Viewer');
  });

  it('does not create collapsible elements for content without headings', () => {
    render('Just a paragraph.\n\nAnother paragraph.');
    expect(qa('.collapsible').length).toBe(0);
    expect(qa('.collapsible-content').length).toBe(0);
  });
});

// ─── Frontmatter ───────────────────────────────────────────────────

describe('frontmatter', () => {
  it('renders title as h1', () => {
    render('---\ntitle: My Doc\n---\nBody text.');
    expect(meta().querySelector('h1.title')!.textContent).toBe('My Doc');
  });

  it('sets document title from frontmatter', () => {
    render('---\ntitle: My Doc\n---\nBody.');
    expect(document.title).toContain('My Doc');
  });

  it('renders metadata table for extra keys', () => {
    render('---\ntitle: Doc\nauthor: Alice\ndate: 2026-01-01\n---\nBody.');
    const th = meta().querySelectorAll('th');
    const labels = Array.from(th).map((el) => el.textContent);
    expect(labels).toContain('Author');
    expect(labels).toContain('Date');
  });

  it('skips title and confidential from metadata table', () => {
    render('---\ntitle: Doc\nconfidential: true\nauthor: Bob\n---\nBody.');
    const th = meta().querySelectorAll('th');
    const labels = Array.from(th).map((el) => el.textContent);
    expect(labels).not.toContain('Title');
    expect(labels).not.toContain('Confidential');
    expect(labels).toContain('Author');
  });

  it('shows confidential badge', () => {
    render('---\nconfidential: true\n---\nSecret content.');
    expect(meta().querySelector('.confidential')!.textContent).toBe('CONFIDENTIAL');
  });

  it('strips surrounding quotes from values', () => {
    render('---\ntitle: "Quoted Title"\n---\nBody.');
    expect(meta().querySelector('h1.title')!.textContent).toBe('Quoted Title');
  });

  it('strips single quotes from values', () => {
    render("---\ntitle: 'Single Quoted'\n---\nBody.");
    expect(meta().querySelector('h1.title')!.textContent).toBe('Single Quoted');
  });

  it('coerces boolean true', () => {
    render('---\nconfidential: true\n---\nBody.');
    expect(meta().querySelector('.confidential')).not.toBeNull();
  });

  it('handles frontmatter with no body', () => {
    render('---\ntitle: Only Meta\n---\n');
    expect(meta().querySelector('h1.title')!.textContent).toBe('Only Meta');
  });

  it('treats text without frontmatter as body', () => {
    render('Just plain markdown.');
    expect(meta().innerHTML).toBe('');
    expect(q('p')!.textContent).toBe('Just plain markdown.');
  });

  it('clears metadata on empty render', () => {
    render('---\ntitle: Something\n---\nBody.');
    render('  ');
    expect(meta().innerHTML).toBe('');
  });

  it('escapes HTML in title', () => {
    render('---\ntitle: <script>alert(1)</script>\n---\nBody.');
    expect(meta().querySelector('h1.title')!.textContent).toBe('<script>alert(1)</script>');
    expect(meta().querySelector('script')).toBeNull();
  });

  it('escapes HTML in metadata values', () => {
    render('---\ntitle: Doc\nauthor: <img onerror=alert(1)>\n---\nBody.');
    const td = meta().querySelector('td');
    expect(td!.textContent).toContain('<img');
    expect(meta().querySelector('img')).toBeNull();
  });

  it('accepts ... as closing delimiter', () => {
    render('---\ntitle: Dot Close\n...\nBody text.');
    expect(meta().querySelector('h1.title')!.textContent).toBe('Dot Close');
  });

  it('coerces boolean false', () => {
    render('---\nconfidential: false\n---\nBody.');
    // false is coerced to boolean false, confidential badge should not appear
    expect(meta().querySelector('.confidential')).toBeNull();
  });

  it('skips lines without colons', () => {
    render('---\ntitle: Doc\nthis line has no colon\nauthor: Alice\n---\nBody.');
    const th = meta().querySelectorAll('th');
    const labels = Array.from(th).map((el) => el.textContent);
    expect(labels).toContain('Author');
    expect(labels.length).toBe(1);
  });

  it('skips empty keys', () => {
    render('---\n: empty key\ntitle: Doc\n---\nBody.');
    expect(meta().querySelector('h1.title')!.textContent).toBe('Doc');
  });

  it('returns null meta for empty frontmatter block', () => {
    render('---\n---\nBody text.');
    // Empty frontmatter should not produce a header
    expect(meta().querySelector('h1')).toBeNull();
    expect(meta().querySelector('table')).toBeNull();
  });

  it('capitalizes first letter of metadata keys', () => {
    render('---\ntitle: Doc\ncustom-field: value\n---\nBody.');
    const th = meta().querySelector('th');
    expect(th!.textContent).toBe('Custom-field');
  });
});

// ─── Heading IDs ───────────────────────────────────────────────────

describe('heading IDs', () => {
  it('assigns pandoc-compatible IDs to h2', () => {
    render('## Getting Started');
    expect(q('h2')!.id).toBe('getting-started');
  });

  it('assigns IDs to h3', () => {
    render('## Parent\nText.\n### Sub Section');
    expect(q('h3')!.id).toBe('sub-section');
  });

  it('lowercases IDs', () => {
    render('## UPPER CASE');
    expect(q('h2')!.id).toBe('upper-case');
  });

  it('removes special characters', () => {
    render("## What's New? (v2.0)");
    expect(q('h2')!.id).toBe('whats-new-v20');
  });

  it('deduplicates heading IDs', () => {
    render('## Section\nText.\n## Section\nMore.');
    const headings = qa('h2');
    expect(headings[0].id).toBe('section');
    expect(headings[1].id).toBe('section-1');
  });

  it('does not assign IDs to h1', () => {
    // h1 is reserved for title
    render('# Top Level');
    const h1 = document.getElementById('content')!.querySelector('h1');
    expect(h1!.id).toBe('');
  });

  it('falls back to heading for special-char-only text', () => {
    render('## ???\nContent.');
    expect(q('h2')!.id).toBe('heading');
  });

  it('deduplicates three identical headings', () => {
    render('## Dup\nA.\n## Dup\nB.\n## Dup\nC.');
    const headings = qa('h2');
    expect(headings[0].id).toBe('dup');
    expect(headings[1].id).toBe('dup-1');
    expect(headings[2].id).toBe('dup-2');
  });

  it('collapses multiple spaces to single hyphen', () => {
    render('## Too   Many   Spaces');
    expect(q('h2')!.id).toBe('too-many-spaces');
  });

  it('strips leading and trailing hyphens', () => {
    render('## -Hyphenated-');
    // The leading/trailing special chars get removed, then hyphens stripped
    expect(q('h2')!.id).not.toMatch(/^-|-$/);
  });
});

// ─── Collapsible headers ──────────────────────────────────────────

describe('collapsible headers', () => {
  describe('structure', () => {
    it('headings get collapsible class', () => {
      render('## Section One\nSome content.\n## Section Two\nMore content.');
      expect(qa('h2.collapsible').length).toBe(2);
    });

    it('content wrapped in collapsible-content div', () => {
      render('## Section\nParagraph one.\n\nParagraph two.');
      const wrappers = qa('.collapsible-content');
      expect(wrappers.length).toBe(1);
      expect(wrappers[0].querySelectorAll('p').length).toBe(2);
    });

    it('ellipsis element created but hidden', () => {
      render('## Section\nContent here.');
      const ellipsis = q('.collapse-ellipsis') as HTMLElement;
      expect(ellipsis).not.toBeNull();
      expect(ellipsis.textContent).toBe('\u2026');
      expect(ellipsis.style.display).toBe('none');
    });

    it('heading with no content is not collapsible', () => {
      render('## Empty Section');
      expect(qa('h2.collapsible').length).toBe(0);
    });

    it('same-level headings get separate wrappers', () => {
      render('## Section A\nContent A.\n## Section B\nContent B.');
      expect(qa('.collapsible-content').length).toBe(2);
    });

    it('h3 nested inside h2 wrapper', () => {
      render('## Parent\nIntro.\n### Child\nChild content.');
      const h2Wrapper = q('h2.collapsible + .collapse-ellipsis + .collapsible-content');
      expect(h2Wrapper).not.toBeNull();
      expect(h2Wrapper!.querySelector('h3')).not.toBeNull();
    });

    it('h4 is collapsible too', () => {
      render('## Main\nIntro.\n### Sub\nSub content.\n#### Detail\nDetail content.');
      expect(q('h4.collapsible')).not.toBeNull();
    });

    it('h2 stops at next h2', () => {
      render('## A\nContent A.\n## B\nContent B.');
      const firstWrapper = document.getElementById('content')!.querySelector(
        'h2.collapsible + .collapse-ellipsis + .collapsible-content'
      );
      expect(firstWrapper!.querySelectorAll('p').length).toBe(1);
    });

    it('h3 stops at next h2', () => {
      render('## Parent\nIntro.\n### Child\nChild text.\n## Next\nNext text.');
      // h3's wrapper should only have its own content
      const h3Wrapper = document.getElementById('content')!.querySelector(
        'h3.collapsible + .collapse-ellipsis + .collapsible-content'
      );
      expect(h3Wrapper!.querySelectorAll('p').length).toBe(1);
    });

    it('preserves DOM order: heading, ellipsis, wrapper', () => {
      render('## Section\nContent.');
      const h2 = q('h2.collapsible')!;
      const next1 = h2.nextElementSibling!;
      const next2 = next1.nextElementSibling!;
      expect(next1.classList.contains('collapse-ellipsis')).toBe(true);
      expect(next2.classList.contains('collapsible-content')).toBe(true);
    });
  });

  describe('toggle behavior', () => {
    it('click collapses and shows ellipsis', () => {
      render('## Section\nContent here.');
      const h2 = q('h2.collapsible') as HTMLElement;
      h2.click();

      expect(h2.classList.contains('collapsed')).toBe(true);
      expect(q('.collapsible-content')!.classList.contains('collapsed')).toBe(true);
      const ellipsis = q('.collapse-ellipsis') as HTMLElement;
      expect(ellipsis.style.display).toBe('');
    });

    it('double click expands and hides ellipsis', () => {
      render('## Section\nContent here.');
      const h2 = q('h2.collapsible') as HTMLElement;
      h2.click();
      h2.click();

      expect(h2.classList.contains('collapsed')).toBe(false);
      expect(q('.collapsible-content')!.classList.contains('collapsed')).toBe(false);
      expect((q('.collapse-ellipsis') as HTMLElement).style.display).toBe('none');
    });

    it('multiple sections collapse independently', () => {
      render('## A\nContent A.\n## B\nContent B.');
      const headings = qa('h2.collapsible');
      (headings[0] as HTMLElement).click();

      expect(headings[0].classList.contains('collapsed')).toBe(true);
      expect(headings[1].classList.contains('collapsed')).toBe(false);
    });

    it('collapsing h2 hides nested h3', () => {
      render('## Parent\nIntro.\n### Child\nChild content.');
      (q('h2.collapsible') as HTMLElement).click();

      // h3 is inside collapsed wrapper
      const wrapper = q('.collapsible-content.collapsed');
      expect(wrapper).not.toBeNull();
      expect(wrapper!.querySelector('h3')).not.toBeNull();
    });

    it('click on link inside heading still toggles collapse', () => {
      render('## [Link Title](https://example.com)\nContent.');
      const link = q('h2 a') as HTMLAnchorElement;
      expect(link).not.toBeNull();
      link.click();

      // Heading should collapse — link navigation is prevented on collapsible headings
      expect(q('h2')!.classList.contains('collapsed')).toBe(true);
    });

    it('wrapper captures mixed content types', () => {
      render(
        '## Section\nA paragraph.\n\n```js\ncode\n```\n\n- list item\n\n> blockquote\n\n| A |\n|---|\n| B |'
      );
      const wrapper = q('.collapsible-content')!;
      expect(wrapper.querySelector('p')).not.toBeNull();
      expect(wrapper.querySelector('pre')).not.toBeNull();
      expect(wrapper.querySelector('ul')).not.toBeNull();
      expect(wrapper.querySelector('blockquote')).not.toBeNull();
      expect(wrapper.querySelector('table')).not.toBeNull();
    });

    it('deep nesting: h2 > h3 > h4 all collapsible', () => {
      render('## L2\nA.\n### L3\nB.\n#### L4\nC.');
      expect(qa('.collapsible').length).toBe(3);
    });
  });
});

// ─── scrollToHeading ──────────────────────────────────────────────

describe('scrollToHeading', () => {
  it('expands a collapsed heading', () => {
    render('## Target\nTarget content.');
    const h2 = q('h2.collapsible') as HTMLElement;
    h2.click();
    expect(h2.classList.contains('collapsed')).toBe(true);

    (window as any).scrollToHeading(h2.id);
    expect(h2.classList.contains('collapsed')).toBe(false);
  });

  it('expands parent when scrolling to child', () => {
    render('## Parent\nIntro.\n### Child\nChild content.');
    const h2 = q('h2.collapsible') as HTMLElement;
    h2.click();
    expect(h2.classList.contains('collapsed')).toBe(true);

    const h3 = q('h3') as HTMLElement;
    (window as any).scrollToHeading(h3.id);
    expect(h2.classList.contains('collapsed')).toBe(false);
  });

  it('hides ellipsis after expanding via scroll', () => {
    render('## Section\nContent.');
    (q('h2.collapsible') as HTMLElement).click();

    const ellipsis = q('.collapse-ellipsis') as HTMLElement;
    expect(ellipsis.style.display).toBe('');

    (window as any).scrollToHeading(q('h2')!.id);
    expect(ellipsis.style.display).toBe('none');
  });

  it('does nothing for nonexistent ID', () => {
    render('## Section\nContent.');
    // Should not throw
    (window as any).scrollToHeading('nonexistent-id');
  });

  it('expands all ancestors for deeply nested h4', () => {
    render('## L2\nA.\n### L3\nB.\n#### L4\nC.');
    // Collapse h2 (hides h3 and h4)
    (q('h2.collapsible') as HTMLElement).click();
    expect(q('h2')!.classList.contains('collapsed')).toBe(true);

    // Scroll to h4 — should expand h2 (and h3 if it was collapsed)
    const h4 = document.getElementById('content')!.querySelector('h4')!;
    (window as any).scrollToHeading(h4.id);
    expect(q('h2')!.classList.contains('collapsed')).toBe(false);
  });

  it('is a no-op on already-expanded heading', () => {
    render('## Section\nContent.');
    const h2 = q('h2.collapsible') as HTMLElement;
    expect(h2.classList.contains('collapsed')).toBe(false);

    (window as any).scrollToHeading(h2.id);
    expect(h2.classList.contains('collapsed')).toBe(false);
  });
});

// ─── Footnotes ────────────────────────────────────────────────────

describe('footnotes', () => {
  it('converts footnotes to inline tooltips', () => {
    render('Some text[^1].\n\n[^1]: Footnote content here.');
    expect(q('.fn-ref')).not.toBeNull();
    expect(q('.fn-tooltip')).not.toBeNull();
  });

  it('tooltip contains footnote content', () => {
    render('Reference[^1].\n\n[^1]: The explanation.');
    expect(q('.fn-tooltip')!.textContent).toContain('The explanation.');
  });

  it('removes footnotes section from bottom', () => {
    render('Text[^1].\n\n[^1]: A note.');
    expect(q('section.footnotes')).toBeNull();
  });

  it('renders footnote label in sup', () => {
    render('Text[^1].\n\n[^1]: A note.');
    expect(q('.fn-ref sup')!.textContent).toBe('[1]');
  });

  it('handles multiple footnotes', () => {
    render('First[^1] and second[^2].\n\n[^1]: Note one.\n[^2]: Note two.');
    expect(qa('.fn-ref').length).toBe(2);
    expect(qa('.fn-tooltip').length).toBe(2);
  });

  it('fn-ref has tabindex for keyboard accessibility', () => {
    render('Text[^1].\n\n[^1]: A note.');
    expect((q('.fn-ref') as HTMLElement).tabIndex).toBe(0);
  });

  it('content without footnotes renders normally', () => {
    render('No footnotes here.');
    expect(q('.fn-ref')).toBeNull();
    expect(q('section.footnotes')).toBeNull();
  });
});

// ─── Task lists ───────────────────────────────────────────────────

describe('task lists', () => {
  it('renders checkboxes', () => {
    render('- [ ] Unchecked\n- [x] Checked');
    const checkboxes = qa('input[type="checkbox"]');
    expect(checkboxes.length).toBe(2);
  });

  it('checked state is correct', () => {
    render('- [ ] Unchecked\n- [x] Checked');
    const checkboxes = qa('input[type="checkbox"]') as NodeListOf<HTMLInputElement>;
    expect(checkboxes[0].checked).toBe(false);
    expect(checkboxes[1].checked).toBe(true);
  });

  it('applies task-list-item class', () => {
    render('- [ ] Task');
    expect(q('.task-list-item')).not.toBeNull();
  });
});

// ─── GitHub alerts ────────────────────────────────────────────────

describe('github alerts', () => {
  it('renders NOTE alert', () => {
    render('> [!NOTE]\n> Important information.');
    expect(q('.markdown-alert-note')).not.toBeNull();
  });

  it('renders WARNING alert', () => {
    render('> [!WARNING]\n> Be careful.');
    expect(q('.markdown-alert-warning')).not.toBeNull();
  });

  it('renders TIP alert', () => {
    render('> [!TIP]\n> Helpful advice.');
    expect(q('.markdown-alert-tip')).not.toBeNull();
  });

  it('renders IMPORTANT alert', () => {
    render('> [!IMPORTANT]\n> Critical info.');
    expect(q('.markdown-alert-important')).not.toBeNull();
  });

  it('renders CAUTION alert', () => {
    render('> [!CAUTION]\n> Dangerous action.');
    expect(q('.markdown-alert-caution')).not.toBeNull();
  });

  it('alert has title element', () => {
    render('> [!NOTE]\n> Some note.');
    expect(q('.markdown-alert-title')).not.toBeNull();
  });
});

// ─── Font size controls ───────────────────────────────────────────

describe('font size controls', () => {
  it('increases font size', () => {
    (window as any).resetFontSize();
    (window as any).increaseFontSize();
    expect(document.body.style.fontSize).toBe('14px');
  });

  it('decreases font size', () => {
    (window as any).resetFontSize();
    (window as any).decreaseFontSize();
    expect(document.body.style.fontSize).toBe('12px');
  });

  it('resets font size', () => {
    (window as any).increaseFontSize();
    (window as any).increaseFontSize();
    (window as any).resetFontSize();
    expect(document.body.style.fontSize).toBe('13px');
  });

  it('caps at maximum 32px', () => {
    (window as any).resetFontSize();
    for (let i = 0; i < 30; i++) (window as any).increaseFontSize();
    expect(document.body.style.fontSize).toBe('32px');
  });

  it('caps at minimum 8px', () => {
    (window as any).resetFontSize();
    for (let i = 0; i < 20; i++) (window as any).decreaseFontSize();
    expect(document.body.style.fontSize).toBe('8px');
  });
});

// ─── Re-render ────────────────────────────────────────────────────

describe('re-render', () => {
  it('resets collapsible state', () => {
    render('## Section\nContent.');
    (q('h2.collapsible') as HTMLElement).click();
    expect(q('h2')!.classList.contains('collapsed')).toBe(true);

    render('## Section\nContent.');
    expect(q('h2')!.classList.contains('collapsed')).toBe(false);
  });

  it('updates content on re-render', () => {
    render('## Old\nOld content.');
    render('## New\nNew content.');
    expect(q('h2')!.textContent).toBe('New');
  });

  it('clears old content completely', () => {
    render('## A\nText A.\n## B\nText B.');
    render('## Only\nSingle section.');
    expect(qa('h2').length).toBe(1);
  });
});

// ─── Bug: heading entirely composed of a link ─────────────────────

describe('collapsible edge cases', () => {
  it('heading that is entirely a link can still be collapsed', () => {
    render('## [Link Title](https://example.com)\nContent below.');
    const h2 = q('h2.collapsible') as HTMLElement;
    // The only clickable area is the link — clicking it should still toggle
    const link = h2.querySelector('a') as HTMLElement;
    link.click();
    expect(h2.classList.contains('collapsed')).toBe(true);
  });

  it('clicking the ellipsis expands the section', () => {
    render('## Section\nContent here.');
    const h2 = q('h2.collapsible') as HTMLElement;
    h2.click(); // collapse

    const ellipsis = q('.collapse-ellipsis') as HTMLElement;
    ellipsis.click(); // user clicks the "..." to expand

    expect(h2.classList.contains('collapsed')).toBe(false);
    expect(q('.collapsible-content')!.classList.contains('collapsed')).toBe(false);
    expect(ellipsis.style.display).toBe('none');
  });

  it('clicking ellipsis expands only the correct section among multiple', () => {
    render('## A\nContent A.\n## B\nContent B.\n## C\nContent C.');
    const headings = qa('h2.collapsible');
    const ellipses = document.getElementById('content')!.querySelectorAll('.collapse-ellipsis');

    // Collapse all three
    (headings[0] as HTMLElement).click();
    (headings[1] as HTMLElement).click();
    (headings[2] as HTMLElement).click();

    // Click ellipsis for section B only
    (ellipses[1] as HTMLElement).click();

    // B should be expanded, A and C still collapsed
    expect(headings[0].classList.contains('collapsed')).toBe(true);
    expect(headings[1].classList.contains('collapsed')).toBe(false);
    expect(headings[2].classList.contains('collapsed')).toBe(true);
  });

  it('scrollToHeading expands both h3 and h2 when independently collapsed', () => {
    render('## Parent\nIntro.\n### Child\nChild content.');
    // Collapse h3 first, then collapse h2
    (q('h3.collapsible') as HTMLElement).click();
    (q('h2.collapsible') as HTMLElement).click();

    expect(q('h2')!.classList.contains('collapsed')).toBe(true);
    expect(q('h3')!.classList.contains('collapsed')).toBe(true);

    const h3 = q('h3') as HTMLElement;
    (window as any).scrollToHeading(h3.id);

    // Both should be expanded
    expect(q('h2')!.classList.contains('collapsed')).toBe(false);
    expect(q('h3')!.classList.contains('collapsed')).toBe(false);
  });
});

// ─── Linkify configuration ────────────────────────────────────────

describe('linkify', () => {
  it('does not auto-link bare URLs (fuzzyLink: false)', () => {
    render('Visit example.com for more.');
    expect(q('a')).toBeNull();
  });

  it('auto-links explicit URLs', () => {
    render('Visit https://example.com for more.');
    const a = q('a') as HTMLAnchorElement;
    expect(a).not.toBeNull();
    expect(a.href).toContain('example.com');
  });

  it('does not auto-link bare emails (fuzzyEmail: false)', () => {
    render('Contact user@example.com for help.');
    expect(q('a')).toBeNull();
  });
});

// ─── Typographer ──────────────────────────────────────────────────

describe('typographer', () => {
  it('converts straight double quotes to smart quotes', () => {
    render('"Hello world"');
    const text = document.getElementById('content')!.textContent!;
    expect(text).toContain('\u201C'); // left double quote
    expect(text).toContain('\u201D'); // right double quote
  });

  it('converts double hyphens to en-dash', () => {
    render('pages 1--10');
    const text = document.getElementById('content')!.textContent!;
    expect(text).toContain('\u2013'); // en-dash
  });

  it('converts triple hyphens to em-dash', () => {
    render('word---word');
    const text = document.getElementById('content')!.textContent!;
    expect(text).toContain('\u2014'); // em-dash
  });
});
