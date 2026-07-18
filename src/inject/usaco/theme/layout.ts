export const layoutTheme: string = `
  *, *::before, *::after {
    box-sizing: border-box;
  }

  html {
    min-width: 320px;
  }

  body {
    width: min(60rem, calc(100% - 2rem)) !important;
    max-width: 60rem !important;
    min-height: 100vh;
    margin: 0 auto !important;
    padding: 1.5rem 0 2.5rem;
    font-family:
      Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif !important;
    font-size: 16px;
    line-height: 1.65;
    overflow-wrap: break-word;
  }

  body > table {
    width: 100% !important;
    margin-inline: auto;
  }

  body > div[style*="width:" i],
  body > font > div[style*="width:" i] {
    width: min(100%, 52rem) !important;
    max-width: 52rem !important;
    margin-inline: auto !important;
  }

  body > img[width="742"] {
    display: block;
    width: 100% !important;
    max-width: 742px;
    height: auto !important;
    margin: 0 auto 1rem;
  }

  table, tbody, thead, tfoot, tr, td, th {
    max-width: 100%;
  }

  img {
    max-width: 100%;
    height: auto;
  }

  font[face] {
    font-family: inherit !important;
  }

  h1, h2, h3 {
    line-height: 1.25;
  }

  li + li {
    margin-top: 0.2rem;
  }

  a {
    text-decoration-thickness: 1px;
    text-underline-offset: 0.15em;
  }

  a:focus-visible,
  button:focus-visible,
  input:focus-visible,
  select:focus-visible,
  textarea:focus-visible {
    outline: 2px solid currentColor;
    outline-offset: 2px;
  }

  input[type="text"],
  input[type="password"],
  input[type="email"],
  input[type="file"],
  textarea,
  select {
    max-width: 100%;
    min-height: 2.25rem;
    padding: 0.35rem 0.55rem;
    border-width: 1px;
    border-style: solid;
    border-radius: 0.3rem;
    font: inherit;
  }

  input[type="submit"],
  input[type="reset"],
  input[type="button"],
  button {
    min-height: 2.25rem;
    margin: 0.25rem !important;
    padding: 0.4rem 0.8rem;
    border-width: 1px;
    border-style: solid;
    border-radius: 0.3rem;
    font: inherit;
    font-weight: 600;
    cursor: pointer;
  }

  input[type="file"]::file-selector-button {
    margin-right: 0.6rem;
    padding: 0.35rem 0.65rem;
    border-width: 1px;
    border-style: solid;
    border-radius: 0.3rem;
    font: inherit;
    cursor: pointer;
  }

  pre, code, kbd, samp, tt {
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", monospace;
  }

  pre {
    max-width: 100%;
    padding: 0.8rem;
    overflow-x: auto;
    border-width: 1px;
    border-style: solid;
    border-radius: 0.3rem;
  }

  @media (max-width: 640px) {
    body {
      width: calc(100% - 1rem) !important;
      padding-block: 0.75rem 1.5rem;
      font-size: 15px;
    }

    table {
      width: 100% !important;
    }

    td, th {
      max-width: calc(100vw - 1rem);
      padding: 0.35rem !important;
    }

    form table tr {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
    }

    form table td {
      width: auto !important;
      text-align: left !important;
    }

    input[type="text"],
    input[type="password"],
    input[type="email"],
    input[type="file"],
    textarea,
    select {
      width: 100%;
    }
  }
`.trim()
