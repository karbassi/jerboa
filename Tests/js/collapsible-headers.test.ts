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
    // Resources served from publicDir at root
    await loadScript('/markdown-it.min.js');
    await loadScript('/markdown-it-footnote.min.js');
    await loadScript('/markdown-it-task-lists.min.js');
    await loadScript('/markdown-it-github-alerts.min.js');
    await loadScript('/viewer.js');
    initialized = true;
  } else {
    // Re-initialize viewer.js cached DOM refs after innerHTML reset
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

function content() {
  return document.getElementById('content')!;
}

describe('structure', () => {
  it('headings get collapsible class', () => {
    render('## Section One\nSome content.\n## Section Two\nMore content.');
    expect(content().querySelectorAll('h2.collapsible').length).toBe(2);
  });

  it('content wrapped in collapsible-content div', () => {
    render('## Section\nParagraph one.\n\nParagraph two.');
    const wrappers = content().querySelectorAll('.collapsible-content');
    expect(wrappers.length).toBe(1);
    expect(wrappers[0].querySelectorAll('p').length).toBe(2);
  });

  it('ellipsis element created but hidden', () => {
    render('## Section\nContent here.');
    const ellipsis = content().querySelector('.collapse-ellipsis') as HTMLElement;
    expect(ellipsis).not.toBeNull();
    expect(ellipsis.textContent).toBe('\u2026');
    expect(ellipsis.style.display).toBe('none');
  });

  it('heading with no content is not collapsible', () => {
    render('## Empty Section');
    expect(content().querySelectorAll('h2.collapsible').length).toBe(0);
  });

  it('same-level headings get separate wrappers', () => {
    render('## Section A\nContent A.\n## Section B\nContent B.');
    expect(content().querySelectorAll('.collapsible-content').length).toBe(2);
  });

  it('h3 nested inside h2 wrapper', () => {
    render('## Parent\nIntro.\n### Child\nChild content.');
    const h2Wrapper = content().querySelector(
      'h2.collapsible + .collapse-ellipsis + .collapsible-content'
    );
    expect(h2Wrapper).not.toBeNull();
    expect(h2Wrapper!.querySelector('h3')).not.toBeNull();
  });

  it('h4 is collapsible too', () => {
    render('## Main\nIntro.\n### Sub\nSub content.\n#### Detail\nDetail content.');
    expect(content().querySelector('h4.collapsible')).not.toBeNull();
  });
});

describe('toggle behavior', () => {
  it('click collapses and shows ellipsis', () => {
    render('## Section\nContent here.');
    const h2 = content().querySelector('h2.collapsible') as HTMLElement;
    h2.click();

    expect(h2.classList.contains('collapsed')).toBe(true);
    expect(
      content().querySelector('.collapsible-content')!.classList.contains('collapsed')
    ).toBe(true);

    const ellipsis = content().querySelector('.collapse-ellipsis') as HTMLElement;
    expect(ellipsis.style.display).toBe('');
  });

  it('double click expands and hides ellipsis', () => {
    render('## Section\nContent here.');
    const h2 = content().querySelector('h2.collapsible') as HTMLElement;
    h2.click();
    h2.click();

    expect(h2.classList.contains('collapsed')).toBe(false);
    expect(
      content().querySelector('.collapsible-content')!.classList.contains('collapsed')
    ).toBe(false);

    const ellipsis = content().querySelector('.collapse-ellipsis') as HTMLElement;
    expect(ellipsis.style.display).toBe('none');
  });
});

describe('scrollToHeading', () => {
  it('expands a collapsed heading', () => {
    render('## Target\nTarget content.');
    const h2 = content().querySelector('h2.collapsible') as HTMLElement;
    h2.click();
    expect(h2.classList.contains('collapsed')).toBe(true);

    (window as any).scrollToHeading(h2.id);
    expect(h2.classList.contains('collapsed')).toBe(false);
  });

  it('expands parent when scrolling to child', () => {
    render('## Parent\nIntro.\n### Child\nChild content.');
    const h2 = content().querySelector('h2.collapsible') as HTMLElement;
    h2.click();
    expect(h2.classList.contains('collapsed')).toBe(true);

    const h3 = content().querySelector('h3') as HTMLElement;
    (window as any).scrollToHeading(h3.id);
    expect(h2.classList.contains('collapsed')).toBe(false);
  });
});

describe('re-render', () => {
  it('re-render resets collapsible state', () => {
    render('## Section\nContent.');
    const h2 = content().querySelector('h2.collapsible') as HTMLElement;
    h2.click();
    expect(h2.classList.contains('collapsed')).toBe(true);

    render('## Section\nContent.');
    expect(content().querySelector('h2')!.classList.contains('collapsed')).toBe(false);
  });
});
