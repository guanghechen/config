import { randomBytes } from 'node:crypto'
import type { Webview } from 'vscode'

export function createCommitSearchViewHtml(webview: Webview): string {
  const nonce = randomBytes(16).toString('base64')
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta
    http-equiv="Content-Security-Policy"
    content="default-src 'none'; style-src ${webview.cspSource} 'nonce-${nonce}'; script-src 'nonce-${nonce}';"
  >
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style nonce="${nonce}">
    :root {
      color-scheme: light dark;
      --control-border: var(--vscode-input-border, var(--vscode-dropdown-border, transparent));
      --panel-border: var(--vscode-widget-border, var(--vscode-sideBarSectionHeader-border, transparent));
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 8px 10px 10px;
      color: var(--vscode-foreground);
      background: var(--vscode-sideBar-background);
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
    }
    form { min-width: 0; }
    .sr-only {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    }
    .search-shell {
      display: grid;
      grid-template-columns: auto minmax(0, 1fr) auto;
      align-items: center;
      min-height: 34px;
      border: 1px solid var(--control-border);
      border-radius: 6px;
      background: var(--vscode-input-background);
      box-shadow: 0 1px 2px var(--vscode-widget-shadow, rgba(0, 0, 0, 0.16));
      transition: border-color 100ms ease, box-shadow 100ms ease;
    }
    .search-shell:focus-within {
      border-color: var(--vscode-focusBorder);
      box-shadow: 0 0 0 1px var(--vscode-focusBorder);
    }
    .search-icon {
      width: 15px;
      height: 15px;
      margin-left: 9px;
      color: var(--vscode-descriptionForeground);
      pointer-events: none;
    }
    #message {
      width: 100%;
      min-width: 0;
      height: 32px;
      padding: 3px 8px;
      border: 0;
      color: var(--vscode-input-foreground);
      background: transparent;
      font: inherit;
      font-weight: 400;
      outline: none;
    }
    #message::-webkit-search-cancel-button { display: none; }
    input::placeholder { color: var(--vscode-input-placeholderForeground); }
    button {
      border: 0;
      font: inherit;
      cursor: pointer;
    }
    button:focus-visible {
      outline: 2px solid var(--vscode-focusBorder);
      outline-offset: 1px;
    }
    button:disabled { cursor: default; opacity: 0.6; }
    .primary-action {
      align-self: stretch;
      min-width: 56px;
      margin: 3px;
      padding: 0 10px;
      border-radius: 4px;
      color: var(--vscode-button-foreground);
      background: var(--vscode-button-background);
      font-weight: 500;
    }
    .primary-action:hover { background: var(--vscode-button-hoverBackground); }
    .primary-action.cancel-action {
      color: var(--vscode-button-secondaryForeground);
      background: var(--vscode-button-secondaryBackground);
    }
    .primary-action.cancel-action:hover {
      background: var(--vscode-button-secondaryHoverBackground);
    }
    .toolbar {
      display: flex;
      align-items: center;
      gap: 6px;
      min-width: 0;
      min-height: 24px;
      padding: 3px 1px 0;
    }
    .toolbar-action {
      display: inline-flex;
      align-items: center;
      min-height: 22px;
      padding: 2px 4px;
      border-radius: 4px;
      color: var(--vscode-descriptionForeground);
      background: transparent;
      font-size: 11px;
    }
    .toolbar-action:hover {
      color: var(--vscode-foreground);
      background: var(--vscode-toolbar-hoverBackground);
    }
    #filters-toggle {
      gap: 4px;
    }
    .chevron {
      width: 12px;
      height: 12px;
      color: var(--vscode-descriptionForeground);
      transform-origin: center;
      transition: transform 80ms ease;
    }
    #filters-toggle[aria-expanded='true'] .chevron { transform: rotate(90deg); }
    #filter-count {
      min-width: 15px;
      padding: 0 5px;
      border-radius: 999px;
      color: var(--vscode-badge-foreground);
      background: var(--vscode-badge-background);
      font-size: 10px;
      font-weight: 600;
      line-height: 15px;
      text-align: center;
    }
    #status {
      flex: 1;
      min-width: 0;
      color: var(--vscode-descriptionForeground);
      font-size: 11px;
      line-height: 16px;
      overflow: hidden;
      text-align: right;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    #status.is-draft { color: var(--vscode-editorWarning-foreground); }
    #clear { color: var(--vscode-textLink-foreground); }
    #clear:hover { color: var(--vscode-textLink-activeForeground); }
    #filter-panel {
      display: grid;
      gap: 9px;
      margin-top: 5px;
      padding: 10px;
      border: 1px solid var(--panel-border);
      border-radius: 6px;
      background: var(
        --vscode-sideBarSectionHeader-background,
        var(--vscode-editorWidget-background, var(--vscode-sideBar-background))
      );
    }
    #filter-panel label {
      display: grid;
      gap: 4px;
      min-width: 0;
    }
    .field-label {
      color: var(--vscode-descriptionForeground);
      font-size: 11px;
      font-weight: 450;
      line-height: 14px;
    }
    #filter-panel input, #filter-panel select {
      width: 100%;
      min-width: 0;
      height: 28px;
      padding: 3px 8px;
      border: 1px solid var(--control-border);
      border-radius: 4px;
      color: var(--vscode-input-foreground);
      background: var(--vscode-input-background);
      font: inherit;
      outline: none;
    }
    #filter-panel select {
      color: var(--vscode-dropdown-foreground, var(--vscode-input-foreground));
      background: var(--vscode-dropdown-background, var(--vscode-input-background));
    }
    #filter-panel input:focus, #filter-panel select:focus {
      border-color: var(--vscode-focusBorder);
      box-shadow: 0 0 0 1px var(--vscode-focusBorder);
    }
    .filter-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 9px;
    }
    .filter-divider {
      height: 1px;
      margin: 1px 0;
      background: var(--panel-border);
    }
    #error {
      margin-top: 6px;
      padding: 7px 8px;
      border: 1px solid var(--vscode-inputValidation-errorBorder, var(--panel-border));
      border-radius: 4px;
      color: var(--vscode-errorForeground);
      background: var(--vscode-inputValidation-errorBackground, transparent);
      font-size: 11px;
      line-height: 15px;
      overflow-wrap: anywhere;
    }
    [hidden] { display: none !important; }
    @media (min-width: 290px) {
      .filter-row.split {
        grid-template-columns: minmax(82px, 0.8fr) minmax(0, 1.2fr);
      }
      .date-row { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); }
    }
    @media (max-width: 220px) {
      body { padding-inline: 7px; }
      .primary-action {
        min-width: 48px;
        padding-inline: 7px;
      }
    }
    @media (prefers-reduced-motion: reduce) {
      .search-shell, .chevron { transition: none; }
    }
  </style>
</head>
<body>
  <form id="search-form" novalidate>
    <div class="search-shell">
      <svg class="search-icon" viewBox="0 0 16 16" aria-hidden="true">
        <circle cx="7" cy="7" r="4.25" fill="none" stroke="currentColor" stroke-width="1.5"></circle>
        <path d="m10.25 10.25 3 3" fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"></path>
      </svg>
      <label class="sr-only" for="message">Commit message</label>
      <input
        id="message"
        type="search"
        maxlength="4096"
        placeholder="Search commit messages…"
        spellcheck="false"
        title="Uses Git regular expressions"
      >
      <button id="search" class="primary-action" type="submit">Search</button>
      <button id="cancel" class="primary-action cancel-action" type="button" hidden>Cancel</button>
    </div>
    <div class="toolbar">
      <button
        id="filters-toggle"
        class="toolbar-action"
        type="button"
        aria-expanded="false"
        aria-controls="filter-panel"
      >
        <svg class="chevron" viewBox="0 0 12 12" aria-hidden="true">
          <path d="m4.5 2.5 3.5 3.5-3.5 3.5" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.25"></path>
        </svg>
        <span>Filters</span>
        <span id="filter-count" hidden>0</span>
      </button>
      <span id="status" role="status"></span>
      <button id="clear" class="toolbar-action" type="button" hidden>Clear</button>
    </div>
    <section id="filter-panel" aria-label="Commit search filters" hidden>
      <div id="scope-row" class="filter-row">
        <label>
          <span class="field-label">Scope</span>
          <select id="scope">
            <option value="head">HEAD</option>
            <option value="all">All refs</option>
            <option value="revision">Revision / range</option>
          </select>
        </label>
        <label id="revision-field" hidden>
          <span class="field-label">Revision</span>
          <input id="revision" type="text" maxlength="1024" placeholder="main..feature" spellcheck="false">
        </label>
      </div>
      <label>
        <span class="field-label">Path</span>
        <input
          id="path"
          type="text"
          maxlength="4096"
          placeholder="src/auth or Git pathspec"
          spellcheck="false"
          title="Git pathspec"
        >
      </label>
      <label>
        <span class="field-label">Author</span>
        <input id="author" type="text" maxlength="4096" placeholder="Name or email" spellcheck="false">
      </label>
      <div class="filter-row date-row">
        <label>
          <span class="field-label">Since</span>
          <input id="since" type="text" maxlength="4096" placeholder="2 weeks ago" spellcheck="false">
        </label>
        <label>
          <span class="field-label">Until</span>
          <input id="until" type="text" maxlength="4096" placeholder="2026-07-01" spellcheck="false">
        </label>
      </div>
      <div class="filter-divider" aria-hidden="true"></div>
      <div id="content-row" class="filter-row">
        <label>
          <span class="field-label">Content change</span>
          <select id="content-mode">
            <option value="none">Not set</option>
            <option value="text">Exact text (-S)</option>
            <option value="regex">Changed-line regex (-G)</option>
          </select>
        </label>
        <label id="content-field" hidden>
          <span class="field-label">Value</span>
          <input id="content-value" type="text" maxlength="4096" placeholder="Search value" spellcheck="false">
        </label>
      </div>
    </section>
    <div id="error" role="alert" hidden></div>
  </form>
  <script nonce="${nonce}">
    const vscode = acquireVsCodeApi()
    const form = document.getElementById('search-form')
    const searchButton = document.getElementById('search')
    const clearButton = document.getElementById('clear')
    const cancelButton = document.getElementById('cancel')
    const filtersToggle = document.getElementById('filters-toggle')
    const filterCount = document.getElementById('filter-count')
    const filterPanel = document.getElementById('filter-panel')
    const status = document.getElementById('status')
    const error = document.getElementById('error')
    const scope = document.getElementById('scope')
    const scopeRow = document.getElementById('scope-row')
    const revisionField = document.getElementById('revision-field')
    const contentMode = document.getElementById('content-mode')
    const contentRow = document.getElementById('content-row')
    const contentField = document.getElementById('content-field')
    const inputs = {
      revision: document.getElementById('revision'),
      path: document.getElementById('path'),
      author: document.getElementById('author'),
      since: document.getElementById('since'),
      until: document.getElementById('until'),
      message: document.getElementById('message'),
      contentValue: document.getElementById('content-value'),
    }
    const persisted = vscode.getState()
    let initialized = false
    let busy = false
    let dirty = false
    let latestState = null
    let filtersExpanded = Boolean(persisted && persisted.filtersExpanded)
    let restoreFocusId = null

    function optional(value) {
      return value === '' ? null : value
    }

    function readQuery() {
      const scopeValue =
        scope.value === 'revision'
          ? { kind: 'revision', revision: inputs.revision.value }
          : { kind: scope.value }
      const content =
        contentMode.value === 'none'
          ? null
          : { mode: contentMode.value, value: inputs.contentValue.value }
      return {
        scope: scopeValue,
        path: optional(inputs.path.value),
        author: optional(inputs.author.value),
        since: optional(inputs.since.value),
        until: optional(inputs.until.value),
        message: optional(inputs.message.value),
        content,
      }
    }

    function setForm(query) {
      scope.value = query.scope.kind
      inputs.revision.value = query.scope.kind === 'revision' ? query.scope.revision : ''
      inputs.path.value = query.path || ''
      inputs.author.value = query.author || ''
      inputs.since.value = query.since || ''
      inputs.until.value = query.until || ''
      inputs.message.value = query.message || ''
      contentMode.value = query.content ? query.content.mode : 'none'
      inputs.contentValue.value = query.content ? query.content.value : ''
      updateConditionalFields()
    }

    function countAdvancedFilters(query) {
      let count = query.scope.kind === 'head' ? 0 : 1
      for (const value of [query.path, query.author, query.since, query.until, query.content]) {
        if (value) count += 1
      }
      return count
    }

    function updateConditionalFields() {
      const usesRevision = scope.value === 'revision'
      const usesContent = contentMode.value !== 'none'
      revisionField.hidden = !usesRevision
      contentField.hidden = !usesContent
      scopeRow.classList.toggle('split', usesRevision)
      contentRow.classList.toggle('split', usesContent)
      inputs.revision.required = usesRevision
      inputs.contentValue.required = usesContent

      const count = countAdvancedFilters(readQuery())
      filterCount.textContent = String(count)
      filterCount.hidden = count === 0
    }

    function renderFilterPanel() {
      filterPanel.hidden = !filtersExpanded
      filtersToggle.setAttribute('aria-expanded', String(filtersExpanded))
    }

    function restorePersistedDraft(query) {
      if (!query || typeof query !== 'object' || !query.scope) return false
      if (!['head', 'all', 'revision'].includes(query.scope.kind)) return false
      if (query.content && !['text', 'regex'].includes(query.content.mode)) return false
      try {
        setForm(query)
        return true
      } catch {
        return false
      }
    }

    function persistDraft() {
      vscode.setState({ dirty, filtersExpanded, query: readQuery() })
    }

    function markDirty() {
      dirty = !latestState || JSON.stringify(readQuery()) !== JSON.stringify(latestState.query)
      persistDraft()
      renderStatus()
    }

    function setBusy(value) {
      if (value && !busy) {
        const activeElement = document.activeElement
        restoreFocusId = activeElement && activeElement.id ? activeElement.id : null
      }
      for (const control of form.querySelectorAll('input, select')) control.disabled = value
      filtersToggle.disabled = value
      clearButton.disabled = value
      searchButton.hidden = value
      cancelButton.hidden = !value
      busy = value
      if (!value && restoreFocusId) {
        document.getElementById(restoreFocusId)?.focus()
        restoreFocusId = null
      }
    }

    function showError(message) {
      error.textContent = message || ''
      error.hidden = !message
    }

    function renderStatus() {
      status.classList.toggle('is-draft', dirty)
      clearButton.hidden = !dirty && !Boolean(latestState && latestState.active)
      if (!latestState) {
        status.textContent = dirty ? 'Draft' : ''
        status.title = dirty ? 'Draft filters have not been applied.' : ''
        return
      }
      if (!latestState.hasRepository) {
        status.textContent = dirty ? 'Draft · no repository' : 'No repository'
        status.title = 'Open or select a Git repository first.'
        return
      }
      const suffix = latestState.hasMore ? '+' : ''
      const mode = latestState.active ? 'matches' : 'commits'
      const draft = dirty ? ' · draft' : ''
      status.textContent = String(latestState.commitCount) + suffix + ' ' + mode + draft
      status.title = dirty ? 'Draft filters have not been applied.' : status.textContent
    }

    function handleDraftChange() {
      updateConditionalFields()
      showError('')
      markDirty()
    }

    for (const input of form.querySelectorAll('input')) {
      input.addEventListener('input', handleDraftChange)
    }
    for (const select of form.querySelectorAll('select')) {
      select.addEventListener('change', handleDraftChange)
    }
    form.addEventListener('submit', event => {
      event.preventDefault()
      showError('')
      if (!form.checkValidity()) {
        filtersExpanded = true
        renderFilterPanel()
        persistDraft()
        form.reportValidity()
        return
      }
      markDirty()
      vscode.postMessage({ type: 'search', query: readQuery() })
    })
    filtersToggle.addEventListener('click', () => {
      filtersExpanded = !filtersExpanded
      renderFilterPanel()
      persistDraft()
    })
    clearButton.addEventListener('click', () => {
      showError('')
      vscode.postMessage({ type: 'clear' })
    })
    cancelButton.addEventListener('click', () => vscode.postMessage({ type: 'cancel' }))

    window.addEventListener('message', event => {
      const message = event.data
      if (!message || typeof message !== 'object') return
      if (message.type === 'busy') {
        setBusy(Boolean(message.value))
        return
      }
      if (message.type === 'error') {
        showError(String(message.message || 'Commit search failed.'))
        return
      }
      if (message.type !== 'state') return

      showError('')
      latestState = message
      if (!initialized) {
        if (persisted && persisted.dirty && restorePersistedDraft(persisted.query)) {
          dirty = JSON.stringify(readQuery()) !== JSON.stringify(message.query)
        } else {
          setForm(message.query)
          dirty = false
        }
        initialized = true
      } else if (message.synchronize || !dirty) {
        setForm(message.query)
        dirty = false
      }
      persistDraft()
      renderStatus()
    })

    renderFilterPanel()
    updateConditionalFields()
    renderStatus()
    vscode.postMessage({ type: 'ready' })
  </script>
</body>
</html>`
}
