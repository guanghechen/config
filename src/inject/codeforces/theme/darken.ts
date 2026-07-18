export const darkTheme: string = `
  :root {
    --tsuki-cf-page: #0f1117;
    --tsuki-cf-surface: #171a22;
    --tsuki-cf-surface-muted: #1e222d;
    --tsuki-cf-surface-hover: #252b38;
    --tsuki-cf-border: #343b49;
    --tsuki-cf-text: #d8dee9;
    --tsuki-cf-text-muted: #929cab;
    --tsuki-cf-link: #8ab4f8;
    --tsuki-cf-link-hover: #b3ceff;
    --tsuki-cf-accent: #7c8cff;
    --tsuki-cf-accent-soft: #303a5f;
    --tsuki-cf-success: #69d28f;
    --tsuki-cf-danger: #ff7b86;
    color-scheme: dark;
  }

  html,
  body,
  #body {
    background: var(--tsuki-cf-page) !important;
    color: var(--tsuki-cf-text) !important;
  }

  body,
  input,
  select,
  textarea,
  button {
    color: var(--tsuki-cf-text);
  }

  a:not(.rated-user):not([class*="user-"]) {
    color: var(--tsuki-cf-link) !important;
  }

  a:not(.rated-user):not([class*="user-"]):hover {
    color: var(--tsuki-cf-link-hover) !important;
  }

  #body a:focus-visible,
  #body button:focus-visible,
  #body input:focus-visible,
  #body select:focus-visible,
  #body textarea:focus-visible {
    outline: 2px solid var(--tsuki-cf-accent) !important;
    outline-offset: 2px !important;
  }

  #pageContent div.ttypography a:hover,
  #pageContent div.ttypography a:focus,
  #pageContent div.ttypography a:focus-visible {
    border-radius: 0.2rem;
    background: var(--tsuki-cf-surface-hover) !important;
    color: var(--tsuki-cf-link-hover) !important;
    text-decoration: underline !important;
  }

  hr,
  fieldset {
    border-color: var(--tsuki-cf-border) !important;
  }

  #header,
  #header .lang-chooser,
  #header .userbox,
  .second-level-menu,
  .menu-list,
  .menu-box {
    border-color: var(--tsuki-cf-border) !important;
    background-color: var(--tsuki-cf-surface) !important;
    color: var(--tsuki-cf-text) !important;
  }

  .menu-list li a,
  .second-level-menu a {
    border-color: transparent !important;
    background: transparent !important;
  }

  .menu-list li.current a,
  .menu-list li a:hover,
  .menu-list li a:focus-visible {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface-hover) !important;
  }

  #pageContent .second-level-menu-list li.backLava {
    display: none !important;
  }

  #pageContent .second-level-menu-list li a {
    border-radius: 0.3rem;
    background: transparent !important;
    color: var(--tsuki-cf-text-muted) !important;
  }

  #pageContent .second-level-menu-list li.current a,
  #pageContent .second-level-menu-list li.selectedLava a {
    background: var(--tsuki-cf-accent-soft) !important;
    color: #dce5ff !important;
  }

  #pageContent .second-level-menu-list li a:hover,
  #pageContent .second-level-menu-list li a:focus-visible {
    background: var(--tsuki-cf-surface-hover) !important;
    color: var(--tsuki-cf-link-hover) !important;
  }

  #header img[alt="Codeforces"] {
    border-radius: 0.35rem;
    filter: invert(1) hue-rotate(180deg) brightness(0.95);
  }

  #pageContent,
  .content-with-sidebar,
  .content-with-sidebar > div,
  #sidebar,
  .sidebar {
    color: var(--tsuki-cf-text) !important;
  }

  .roundbox,
  .sidebox,
  .datatable,
  .problem-statement,
  .ttypography,
  .topic,
  .comment-table,
  .blog-entry,
  .user-info,
  .contest-state,
  .submit-form,
  .recent-actions {
    border-color: var(--tsuki-cf-border) !important;
    background-color: var(--tsuki-cf-surface) !important;
    color: var(--tsuki-cf-text) !important;
  }

  .roundbox .caption,
  .sidebox .caption,
  .datatable .caption,
  .datatable .caption a,
  .roundbox-lt,
  .roundbox-rt,
  .roundbox-lb,
  .roundbox-rb {
    border-color: var(--tsuki-cf-border) !important;
    background-color: var(--tsuki-cf-surface-muted) !important;
    color: var(--tsuki-cf-text) !important;
  }

  #pageContent .topic {
    padding: 1rem 1.2rem;
    border: 1px solid var(--tsuki-cf-border) !important;
    border-radius: 0.6rem;
    box-sizing: border-box;
  }

  #pageContent .topic .title *,
  #pageContent .topic .title a,
  #pageContent .topic .title a:hover,
  #pageContent .topic .title a:visited,
  #pageContent .comments .title {
    color: #9bbcf9 !important;
  }

  #pageContent .topic .content,
  #pageContent .topic .ttypography {
    border-color: var(--tsuki-cf-border) !important;
    background: transparent !important;
    color: var(--tsuki-cf-text) !important;
  }

  .datatable table,
  .datatable tbody,
  .datatable tr,
  .standings table,
  .status-frame-datatable table,
  .tests-table table {
    border-color: var(--tsuki-cf-border) !important;
    background: transparent !important;
    color: var(--tsuki-cf-text) !important;
  }

  .datatable .lt,
  .datatable .rt,
  .datatable .lb,
  .datatable .rb,
  .datatable .ilt,
  .datatable .irt {
    display: none !important;
    background: none !important;
  }

  .datatable th,
  .standings th,
  .status-frame-datatable th,
  .tests-table th {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface-muted) !important;
    color: var(--tsuki-cf-text) !important;
  }

  .datatable td,
  .standings td,
  .status-frame-datatable td,
  .tests-table td {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface) !important;
    color: var(--tsuki-cf-text) !important;
  }

  .datatable tr:nth-child(even) td,
  .standings tr:nth-child(even) td,
  .status-frame-datatable tr:nth-child(even) td,
  .tests-table tr:nth-child(even) td,
  tr.dark td {
    background: var(--tsuki-cf-surface-muted) !important;
  }

  .datatable tr:hover td,
  .standings tr:hover td,
  tr.highlighted-row td {
    background: var(--tsuki-cf-surface-hover) !important;
  }

  #pageContent .problems .accepted-problem td.act {
    background: #173b2a !important;
  }

  #pageContent .problems .accepted-problem td.id {
    border-left-color: #57c785 !important;
  }

  #pageContent .problems .rejected-problem td.act {
    background: #401f28 !important;
  }

  #pageContent .problems .rejected-problem td.id {
    border-left-color: #e56b78 !important;
  }

  #pageContent .problems .submitted-verdict-problem td.act {
    background: #1e3554 !important;
  }

  #pageContent .problems .submitted-verdict-problem td.id {
    border-left-color: #6ea8ff !important;
  }

  #sidebar .roundbox table.rtable,
  #sidebar .roundbox table.rtable tbody,
  #sidebar .roundbox table.rtable tr {
    border-color: var(--tsuki-cf-border) !important;
    background: transparent !important;
    color: var(--tsuki-cf-text) !important;
  }

  #sidebar .roundbox table.rtable th {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface-muted) !important;
    color: var(--tsuki-cf-text) !important;
  }

  #sidebar .roundbox table.rtable td {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface) !important;
    color: var(--tsuki-cf-text) !important;
  }

  #sidebar .roundbox table.rtable td.dark {
    background: var(--tsuki-cf-surface-muted) !important;
  }

  #sidebar .roundbox .bottom-links,
  #sidebar .roundbox .bottom-links table,
  #sidebar .roundbox .bottom-links tbody,
  #sidebar .roundbox .bottom-links tr,
  #sidebar .roundbox .bottom-links td {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface-muted) !important;
    color: var(--tsuki-cf-text-muted) !important;
  }

  .ttypography table.bordertable,
  .ttypography table.bordertable th,
  .ttypography table.bordertable td {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface-muted) !important;
    color: var(--tsuki-cf-text) !important;
  }

  .problem-statement .header,
  .problem-statement .title,
  .problem-statement .section-title,
  .problem-statement .property-title,
  .problem-statement .input .title,
  .problem-statement .output .title,
  .problem-statement .sample-test .title {
    border-color: var(--tsuki-cf-border) !important;
    color: var(--tsuki-cf-text) !important;
  }

  .problem-statement .input,
  .problem-statement .output,
  .problem-statement .sample-test,
  .problem-statement .sample-tests,
  .problem-statement .note {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface) !important;
    color: var(--tsuki-cf-text) !important;
  }

  pre,
  code,
  .code,
  .prettyprint,
  .problem-statement pre,
  .problem-statement .input pre,
  .problem-statement .output pre,
  .test-example-line,
  .CodeMirror,
  .CodeMirror-gutters {
    border-color: var(--tsuki-cf-border) !important;
    background: #0c0f15 !important;
    color: #d7dce5 !important;
  }

  .CodeMirror-cursor {
    border-left-color: var(--tsuki-cf-text) !important;
  }

  .CodeMirror-selected,
  .CodeMirror-focused .CodeMirror-selected {
    background: #303953 !important;
  }

  #pageContent .MathJax,
  #pageContent .MathJax *,
  #pageContent .MathJax_Display,
  #pageContent .MathJax_Display * {
    border-color: currentColor !important;
    color: var(--tsuki-cf-text) !important;
  }

  .prettyprint .kwd,
  .prettyprint .tag,
  .cm-keyword {
    color: #c792ea !important;
  }

  .prettyprint .str,
  .prettyprint .atv,
  .cm-string {
    color: #c3e88d !important;
  }

  .prettyprint .com,
  .cm-comment {
    color: #7f8c98 !important;
  }

  .prettyprint .lit,
  .prettyprint .dec,
  .cm-number {
    color: #f78c6c !important;
  }

  .prettyprint .typ,
  .prettyprint .atn,
  .cm-variable,
  .cm-def {
    color: #82aaff !important;
  }

  input[type="text"],
  input[type="password"],
  input[type="email"],
  input[type="number"],
  input[type="search"],
  textarea,
  select,
  option,
  .select2-container .select2-choice,
  .select2-container .select2-selection {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface-muted) !important;
    color: var(--tsuki-cf-text) !important;
  }

  input::placeholder,
  textarea::placeholder {
    color: var(--tsuki-cf-text-muted) !important;
  }

  #body input[type="text"]:hover,
  #body input[type="password"]:hover,
  #body input[type="email"]:hover,
  #body input[type="number"]:hover,
  #body input[type="search"]:hover,
  #body textarea:hover,
  #body select:hover {
    border-color: #566075 !important;
  }

  #body input[type="text"]:focus,
  #body input[type="password"]:focus,
  #body input[type="email"]:focus,
  #body input[type="number"]:focus,
  #body input[type="search"]:focus,
  #body textarea:focus,
  #body select:focus {
    border-color: var(--tsuki-cf-accent) !important;
  }

  button,
  input[type="button"],
  input[type="submit"],
  .button,
  .submit {
    border-color: #6976d9 !important;
    background: #4d5bc2 !important;
    color: #ffffff !important;
  }

  button:hover,
  input[type="button"]:hover,
  input[type="submit"]:hover,
  .button:hover,
  .submit:hover {
    border-color: #929cff !important;
    background: #6573d9 !important;
  }

  button:active,
  input[type="button"]:active,
  input[type="submit"]:active,
  .button:active,
  .submit:active {
    background: #414da4 !important;
  }

  .popup,
  .tooltip,
  .ui-dialog,
  .ui-dialog-titlebar,
  .ui-widget-content,
  .ui-widget-header,
  .select2-drop,
  .select2-dropdown,
  .autocomplete,
  .alert {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface) !important;
    color: var(--tsuki-cf-text) !important;
  }

  .ui-state-hover,
  .ui-menu-item:hover,
  .select2-results__option--highlighted {
    background: var(--tsuki-cf-surface-hover) !important;
    color: var(--tsuki-cf-text) !important;
  }

  .tabs,
  .tab,
  .page-index,
  .pagination,
  .pagination span,
  .pagination a {
    border-color: var(--tsuki-cf-border) !important;
    background-color: var(--tsuki-cf-surface) !important;
    color: var(--tsuki-cf-text) !important;
  }

  .tab.current,
  .page-index.active,
  .pagination .active,
  .pagination a:hover {
    background: var(--tsuki-cf-surface-hover) !important;
    color: var(--tsuki-cf-link-hover) !important;
  }

  #sidebar .contest-state-phase {
    color: #9bbcf9 !important;
  }

  #sidebar .contest-state-regular {
    color: var(--tsuki-cf-text-muted) !important;
  }

  #sidebar .sidebar-menu ul a {
    color: var(--tsuki-cf-link) !important;
  }

  #sidebar .sidebar-menu ul li {
    border-color: transparent !important;
    background: transparent !important;
  }

  #sidebar .sidebar-menu ul li:hover,
  #sidebar .sidebar-menu ul li:focus-within {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface-hover) !important;
  }

  #sidebar .sidebar-menu ul li.active {
    border-color: #5967aa !important;
    background: var(--tsuki-cf-accent-soft) !important;
  }

  #pageContent .action-link a,
  #pageContent .ask-question-link {
    border-radius: 0.25rem;
    padding: 0.15rem 0.25rem;
  }

  #pageContent .action-link a:hover,
  #pageContent .action-link a:focus-visible,
  #pageContent .ask-question-link:hover,
  #pageContent .ask-question-link:focus-visible {
    background: var(--tsuki-cf-surface-hover) !important;
    color: var(--tsuki-cf-link-hover) !important;
  }

  #body .sidebar-caption-icon:hover,
  #body .sidebar-caption-icon:focus-visible {
    color: var(--tsuki-cf-link-hover) !important;
  }

  #body img.toggle-favourite:hover,
  #body img.add-favourite:hover,
  #body .action-link img:hover {
    filter: brightness(1.35);
  }

  .comment,
  .comment-table td,
  .talk-text,
  .reply,
  .topic .content {
    border-color: var(--tsuki-cf-border) !important;
    background: var(--tsuki-cf-surface) !important;
    color: var(--tsuki-cf-text) !important;
  }

  #body .user-legendary,
  #body .user-red {
    color: #ff6b76 !important;
  }

  #body .user-legendary::first-letter,
  #body .legendary-user-first-letter,
  #body .user-admin {
    color: #f2f4f8 !important;
  }

  #body .user-orange {
    color: #ffb454 !important;
  }

  #body .user-violet {
    color: #d28cff !important;
  }

  #body .user-blue {
    color: #6ea8ff !important;
  }

  #body .user-cyan {
    color: #4fd1c5 !important;
  }

  #body .user-green {
    color: #7ddc8a !important;
  }

  #body .user-gray {
    color: #aab2c0 !important;
  }

  .notice,
  .gray,
  .minor,
  .info,
  .property-title,
  .footer,
  #footer {
    color: var(--tsuki-cf-text-muted) !important;
  }

  .verdict-accepted,
  .verdict-ok,
  .accepted,
  .datatable td.verdict-accepted,
  .datatable td.verdict-ok {
    color: var(--tsuki-cf-success) !important;
  }

  .verdict-rejected,
  .verdict-failed,
  .rejected,
  .datatable td.verdict-rejected,
  .datatable td.verdict-failed,
  .error,
  .error__message {
    color: var(--tsuki-cf-danger) !important;
  }

  .verdict-waiting,
  .verdict-running,
  .datatable td.verdict-waiting,
  .datatable td.verdict-running {
    color: #f3c969 !important;
  }

  img.tex-formula {
    filter: invert(0.9) hue-rotate(180deg);
  }

  div[style*="background-color: white" i],
  div[style*="background-color:#fff" i],
  td[style*="background-color: white" i],
  td[style*="background-color:#fff" i] {
    background-color: var(--tsuki-cf-surface) !important;
  }

  * {
    scrollbar-color: var(--tsuki-cf-border) var(--tsuki-cf-surface);
  }

  ::selection {
    background: #39446a;
    color: #ffffff;
  }
`.trim()
