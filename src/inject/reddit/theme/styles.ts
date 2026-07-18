export const redditStyles: string = `
  html,
  body,
  .theme-beta {
    background-color: var(--tsuki-reddit-page) !important;
    color: var(--tsuki-reddit-text) !important;
  }

  header,
  .header,
  nav,
  .nav {
    border-color: var(--tsuki-reddit-border) !important;
    background-color: var(--tsuki-reddit-surface) !important;
    color: var(--tsuki-reddit-text) !important;
  }

  .Post,
  [data-testid="post-container"],
  .thing,
  .side,
  .sidebar,
  aside,
  .Comment,
  .comment,
  .commentarea {
    border-color: var(--tsuki-reddit-border) !important;
    background-color: var(--tsuki-reddit-surface) !important;
    color: var(--tsuki-reddit-text) !important;
  }

  .Post:hover,
  [data-testid="post-container"]:hover,
  .thing:hover {
    background-color: var(--tsuki-reddit-surface-hover) !important;
  }

  a {
    color: var(--tsuki-reddit-link) !important;
  }

  a:hover {
    color: var(--tsuki-reddit-link-hover) !important;
  }

  a:visited {
    color: var(--tsuki-reddit-link-visited) !important;
  }

  button,
  .button {
    border-color: var(--tsuki-reddit-button) !important;
    background-color: var(--tsuki-reddit-button) !important;
    color: var(--tsuki-reddit-button-text) !important;
  }

  button:hover,
  .button:hover {
    background-color: var(--tsuki-reddit-button-hover) !important;
  }

  button:active,
  .button:active {
    background-color: var(--tsuki-reddit-button-active) !important;
  }

  input,
  textarea,
  select,
  .search-input,
  [data-testid="search-input"] {
    border-color: var(--tsuki-reddit-border) !important;
    background-color: var(--tsuki-reddit-input) !important;
    color: var(--tsuki-reddit-text) !important;
  }

  input::placeholder,
  textarea::placeholder {
    color: var(--tsuki-reddit-text-muted) !important;
  }

  a:focus-visible,
  button:focus-visible,
  input:focus-visible,
  select:focus-visible,
  textarea:focus-visible {
    outline: 2px solid var(--tsuki-reddit-focus) !important;
    outline-offset: 2px !important;
  }

  .arrow {
    filter: var(--tsuki-reddit-arrow-filter) !important;
  }

  .modal,
  .dropdown-content {
    border-color: var(--tsuki-reddit-border) !important;
    background-color: var(--tsuki-reddit-surface) !important;
    color: var(--tsuki-reddit-text) !important;
  }
`.trim()
