export const usacoStyles: string = `
  html,
  body {
    background: var(--tsuki-usaco-page) !important;
    color: var(--tsuki-usaco-text) !important;
  }

  table, tbody, thead, tfoot, tr, td, th {
    border-color: var(--tsuki-usaco-border) !important;
  }

  a {
    color: var(--tsuki-usaco-link) !important;
  }

  a:hover {
    color: var(--tsuki-usaco-link-hover) !important;
  }

  a:visited {
    color: var(--tsuki-usaco-link-visited) !important;
  }

  a:focus-visible,
  button:focus-visible,
  input:focus-visible,
  select:focus-visible,
  textarea:focus-visible {
    outline-color: var(--tsuki-usaco-focus) !important;
  }

  input[type="text"],
  input[type="password"],
  input[type="email"],
  input[type="file"],
  textarea,
  select {
    border-color: var(--tsuki-usaco-border) !important;
    background: var(--tsuki-usaco-input) !important;
    color: var(--tsuki-usaco-text) !important;
  }

  input::placeholder,
  textarea::placeholder {
    color: var(--tsuki-usaco-text-muted) !important;
  }

  input[type="submit"],
  input[type="button"],
  button {
    border-color: var(--tsuki-usaco-button) !important;
    background: var(--tsuki-usaco-button) !important;
    color: var(--tsuki-usaco-button-text) !important;
  }

  input[type="submit"]:hover,
  input[type="button"]:hover,
  button:hover {
    background: var(--tsuki-usaco-button-hover) !important;
  }

  input[type="submit"]:active,
  input[type="button"]:active,
  button:active {
    background: var(--tsuki-usaco-button-active) !important;
  }

  input[type="reset"],
  input[type="file"]::file-selector-button {
    border-color: var(--tsuki-usaco-border) !important;
    background: var(--tsuki-usaco-surface-muted) !important;
    color: var(--tsuki-usaco-text) !important;
  }

  input[type="reset"]:hover,
  input[type="file"]::file-selector-button:hover {
    background: var(--tsuki-usaco-surface-hover) !important;
  }

  pre {
    border-color: var(--tsuki-usaco-border) !important;
    background: var(--tsuki-usaco-code) !important;
    color: var(--tsuki-usaco-text) !important;
  }

  hr {
    border: 0;
    border-top: 1px solid var(--tsuki-usaco-border);
  }

  [bgcolor="white" i],
  [bgcolor="#ffffff" i],
  [style*="background-color:white" i],
  [style*="background-color: white" i] {
    border-color: var(--tsuki-usaco-border) !important;
    background-color: var(--tsuki-usaco-surface) !important;
    color: var(--tsuki-usaco-text) !important;
  }

  [bgcolor="#000000" i] {
    background-color: var(--tsuki-usaco-text) !important;
    color: var(--tsuki-usaco-surface) !important;
  }

  font[color="red" i],
  font[color="#ee0000" i],
  font[color="#ff0000" i],
  [style*="color:red" i],
  [style*="color: red" i] {
    color: var(--tsuki-usaco-danger) !important;
  }

  font[color="purple" i] {
    color: var(--tsuki-usaco-link-visited) !important;
  }

  img[src*="/usaco/cow" i],
  body > img[width="742"] {
    filter: var(--tsuki-usaco-image-filter);
  }

  ::selection {
    background: var(--tsuki-usaco-selection);
    color: var(--tsuki-usaco-selection-text);
  }
`.trim()
