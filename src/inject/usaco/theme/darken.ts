export const darkTheme: string = `
  @media (prefers-color-scheme: dark) {
    :root {
      --tsuki-usaco-page: #111713;
      --tsuki-usaco-surface: #1b2420;
      --tsuki-usaco-surface-muted: #232f29;
      --tsuki-usaco-text: #e4ebe6;
      --tsuki-usaco-border: #46544b;
      --tsuki-usaco-link: #7dd3fc;
      --tsuki-usaco-link-visited: #d8b4fe;
      --tsuki-usaco-accent: #15803d;
      --tsuki-usaco-code: #0d1310;
      color-scheme: dark;
    }

    font[color="red" i],
    font[color="#ee0000" i],
    font[color="#ff0000" i],
    [style*="color:red" i],
    [style*="color: red" i] {
      color: #fca5a5 !important;
    }

    font[color="purple" i] {
      color: #d8b4fe !important;
    }

    img[src*="/usaco/cow" i],
    body > img[width="742"] {
      filter: brightness(0.82) contrast(1.05);
    }
  }
`.trim()
