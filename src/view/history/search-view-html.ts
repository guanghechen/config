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
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 6px 8px 8px;
      color: var(--vscode-foreground);
      background: var(--vscode-sideBar-background);
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
    }
    form { display: grid; gap: 5px; }
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
    .search-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 4px;
    }
    input, select {
      width: 100%;
      min-width: 0;
      height: 24px;
      padding: 2px 6px;
      border: 1px solid var(--vscode-dropdown-border, transparent);
      border-radius: 2px;
      color: var(--vscode-input-foreground);
      background: var(--vscode-input-background);
      font: inherit;
      font-weight: 400;
      outline: none;
    }
    input:focus, select:focus {
      border-color: var(--vscode-focusBorder);
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: -1px;
    }
    input::placeholder { color: var(--vscode-input-placeholderForeground); }
    button {
      min-height: 24px;
      padding: 2px 9px;
      border: 1px solid transparent;
      border-radius: 2px;
      color: var(--vscode-button-foreground);
      background: var(--vscode-button-background);
      font: inherit;
      cursor: pointer;
    }
    button:hover { background: var(--vscode-button-hoverBackground); }
    button:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 1px;
    }
    button.secondary {
      color: var(--vscode-button-secondaryForeground);
      background: var(--vscode-button-secondaryBackground);
    }
    button.secondary:hover { background: var(--vscode-button-secondaryHoverBackground); }
    button:disabled { cursor: default; opacity: 0.6; }
    .meta-row {
      display: flex;
      align-items: center;
      gap: 6px;
      min-width: 0;
      min-height: 20px;
    }
    button.link {
      min-height: 20px;
      padding: 0 2px;
      border: 0;
      color: var(--vscode-textLink-foreground);
      background: transparent;
      font-size: 11px;
    }
    button.link:hover {
      color: var(--vscode-textLink-activeForeground);
      background: transparent;
      text-decoration: underline;
    }
    #filters-toggle {
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    #filters-toggle::before {
      content: '›';
      color: var(--vscode-descriptionForeground);
      font-size: 15px;
      line-height: 1;
      transform-origin: center;
      transition: transform 80ms ease;
    }
    #filters-toggle[aria-expanded='true']::before { transform: rotate(90deg); }
    #filter-count {
      min-width: 16px;
      padding: 0 4px;
      border-radius: 8px;
      color: var(--vscode-badge-foreground);
      background: var(--vscode-badge-background);
      font-size: 10px;
      line-height: 16px;
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
    #filter-panel {
      display: grid;
      gap: 7px;
      padding: 7px 0 3px;
      border-top: 1px solid var(--vscode-sideBarSectionHeader-border, transparent);
    }
    #filter-panel label {
      display: grid;
      gap: 2px;
      min-width: 0;
      color: var(--vscode-descriptionForeground);
      font-size: 11px;
      font-weight: 500;
    }
    .filter-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 6px;
    }
    .filter-row.split {
      grid-template-columns: minmax(84px, 0.8fr) minmax(0, 1.2fr);
    }
    .date-row { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); }
    #error {
      padding-top: 2px;
      color: var(--vscode-errorForeground);
      font-size: 11px;
      line-height: 15px;
      overflow-wrap: anywhere;
    }
    [hidden] { display: none !important; }
  </style>
</head>
<body>
  <form id="search-form" novalidate>
    <div class="search-row">
      <label class="sr-only" for="message">Commit message</label>
      <input
        id="message"
        type="text"
        maxlength="4096"
        placeholder="Search commit messages (Git regex)"
        spellcheck="false"
      >
      <button id="search" type="submit">Search</button>
      <button id="cancel" class="secondary" type="button" hidden>Cancel</button>
    </div>
    <div class="meta-row">
      <button
        id="filters-toggle"
        class="link"
        type="button"
        aria-expanded="false"
        aria-controls="filter-panel"
      >
        Filters <span id="filter-count" hidden>0</span>
      </button>
      <span id="status" role="status"></span>
      <button id="clear" class="link" type="button" hidden>Clear</button>
    </div>
    <section id="filter-panel" aria-label="Commit search filters" hidden>
      <div id="scope-row" class="filter-row">
        <label>
          Scope
          <select id="scope">
            <option value="head">HEAD</option>
            <option value="all">All refs</option>
            <option value="revision">Revision / range</option>
          </select>
        </label>
        <label id="revision-field" hidden>
          Revision
          <input id="revision" type="text" maxlength="1024" placeholder="main..feature" spellcheck="false">
        </label>
      </div>
      <label>
        Path
        <input
          id="path"
          type="text"
          maxlength="4096"
          placeholder="src/auth or :(glob)src/**/*.ts"
          spellcheck="false"
          title="Git pathspec"
        >
      </label>
      <label>
        Author
        <input id="author" type="text" maxlength="4096" placeholder="Name or email" spellcheck="false">
      </label>
      <div class="filter-row date-row">
        <label>
          Since
          <input id="since" type="text" maxlength="4096" placeholder="2 weeks ago" spellcheck="false">
        </label>
        <label>
          Until
          <input id="until" type="text" maxlength="4096" placeholder="2026-07-01" spellcheck="false">
        </label>
      </div>
      <div id="content-row" class="filter-row">
        <label>
          Content change
          <select id="content-mode">
            <option value="none">Not set</option>
            <option value="text">Exact text (-S)</option>
            <option value="regex">Changed-line regex (-G)</option>
          </select>
        </label>
        <label id="content-field" hidden>
          Value
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
