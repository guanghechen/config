export const codeforcesStyles: string = `
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

  a:not(.rated-user):not([class*="user-"]):visited {
    color: var(--tsuki-cf-link-visited) !important;
  }

  #body a:focus-visible,
  #body button:focus-visible,
  #body input:focus-visible,
  #body select:focus-visible,
  #body textarea:focus-visible {
    outline: 2px solid var(--tsuki-cf-focus) !important;
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
    color: var(--tsuki-cf-text) !important;
  }

  #pageContent .second-level-menu-list li a:hover,
  #pageContent .second-level-menu-list li a:focus-visible {
    background: var(--tsuki-cf-surface-hover) !important;
    color: var(--tsuki-cf-link-hover) !important;
  }

  #header img[alt="Codeforces"] {
    border-radius: 0.35rem;
    filter: var(--tsuki-cf-logo-filter);
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
    color: var(--tsuki-cf-link-hover) !important;
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
    background: var(--tsuki-cf-success-surface) !important;
  }

  #pageContent .problems .accepted-problem td.id {
    border-left-color: var(--tsuki-cf-success) !important;
  }

  #pageContent .problems .rejected-problem td.act {
    background: var(--tsuki-cf-danger-surface) !important;
  }

  #pageContent .problems .rejected-problem td.id {
    border-left-color: var(--tsuki-cf-danger) !important;
  }

  #pageContent .problems .submitted-verdict-problem td.act {
    background: var(--tsuki-cf-info-surface) !important;
  }

  #pageContent .problems .submitted-verdict-problem td.id {
    border-left-color: var(--tsuki-cf-info) !important;
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
    background: var(--tsuki-cf-code) !important;
    color: var(--tsuki-cf-code-text) !important;
  }

  .CodeMirror-cursor {
    border-left-color: var(--tsuki-cf-text) !important;
  }

  .CodeMirror-selected,
  .CodeMirror-focused .CodeMirror-selected {
    background: var(--tsuki-cf-selection) !important;
  }

  #pageContent .MathJax,
  #pageContent .MathJax *,
  #pageContent .MathJax_Display,
  #pageContent .MathJax_Display * {
    border-color: currentColor !important;
    color: var(--tsuki-cf-info) !important;
  }

  .prettyprint .kwd,
  .prettyprint .tag,
  .cm-keyword {
    color: var(--tsuki-cf-syntax-keyword) !important;
  }

  .prettyprint .str,
  .prettyprint .atv,
  .cm-string {
    color: var(--tsuki-cf-syntax-string) !important;
  }

  .prettyprint .com,
  .cm-comment {
    color: var(--tsuki-cf-syntax-comment) !important;
  }

  .prettyprint .lit,
  .prettyprint .dec,
  .cm-number {
    color: var(--tsuki-cf-syntax-number) !important;
  }

  .prettyprint .typ,
  .prettyprint .atn,
  .cm-variable,
  .cm-def {
    color: var(--tsuki-cf-syntax-type) !important;
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
    background: var(--tsuki-cf-input) !important;
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
    border-color: var(--tsuki-cf-focus) !important;
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
    border-color: var(--tsuki-cf-button) !important;
    background: var(--tsuki-cf-button) !important;
    color: var(--tsuki-cf-button-text) !important;
  }

  button:hover,
  input[type="button"]:hover,
  input[type="submit"]:hover,
  .button:hover,
  .submit:hover {
    border-color: var(--tsuki-cf-focus) !important;
    background: var(--tsuki-cf-button-hover) !important;
  }

  button:active,
  input[type="button"]:active,
  input[type="submit"]:active,
  .button:active,
  .submit:active {
    background: var(--tsuki-cf-button-active) !important;
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
    color: var(--tsuki-cf-link-hover) !important;
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
    border-color: var(--tsuki-cf-focus) !important;
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
    color: var(--tsuki-cf-user-legendary) !important;
  }

  #body .user-legendary::first-letter,
  #body .legendary-user-first-letter,
  #body .user-admin {
    color: var(--tsuki-cf-user-first-letter) !important;
  }

  #body .user-orange {
    color: var(--tsuki-cf-user-orange) !important;
  }

  #body .user-violet {
    color: var(--tsuki-cf-user-violet) !important;
  }

  #body .user-blue {
    color: var(--tsuki-cf-user-blue) !important;
  }

  #body .user-cyan {
    color: var(--tsuki-cf-user-cyan) !important;
  }

  #body .user-green {
    color: var(--tsuki-cf-user-green) !important;
  }

  #body .user-gray {
    color: var(--tsuki-cf-user-gray) !important;
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
    color: var(--tsuki-cf-warning) !important;
  }

  img.tex-formula {
    filter: var(--tsuki-cf-formula-filter);
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
    background: var(--tsuki-cf-selection);
    color: var(--tsuki-cf-selection-text);
  }
`.trim()
