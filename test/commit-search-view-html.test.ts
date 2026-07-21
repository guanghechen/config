import assert from 'node:assert/strict'
import test from 'node:test'
import { runInNewContext } from 'node:vm'
import { createCommitSearchQuery } from '../src/git/commit-search'
import { createCommitSearchViewHtml } from '../src/view/history/search-view-html'

test('creates a compact CSP-protected sidebar search form with collapsible filters', () => {
  const webview = { cspSource: 'vscode-webview://vsgit-test' } as Parameters<
    typeof createCommitSearchViewHtml
  >[0]
  const html = createCommitSearchViewHtml(webview)
  const scriptNonce = html.match(/<script nonce="([^"]+)">/)?.[1]

  assert.ok(scriptNonce)
  assert.ok(html.includes(`style-src ${webview.cspSource} 'nonce-${scriptNonce}'`))
  assert.ok(html.includes(`script-src 'nonce-${scriptNonce}'`))
  assert.ok(html.includes(`<style nonce="${scriptNonce}">`))
  assert.equal(html.includes("'unsafe-inline'"), false)
  for (const id of [
    'search-form',
    'message',
    'filters-toggle',
    'filter-panel',
    'filter-count',
    'scope',
    'path',
    'content-mode',
    'search',
    'clear',
  ]) {
    assert.ok(html.includes(`id="${id}"`), id)
  }
  assert.match(html, /<section id="filter-panel"[^>]* hidden>/)
  assert.equal(html.includes('<details open>'), false)
})

test('keeps an unchanged query clean and restores focus after a sidebar operation', () => {
  const harness = createClientHarness()
  const query = createCommitSearchQuery()
  harness.receive({
    type: 'state',
    active: false,
    commitCount: 1,
    hasMore: false,
    hasRepository: true,
    query,
    synchronize: true,
  })

  const messageInput = harness.element('message')
  messageInput.focus()
  harness.element('search-form').dispatch('submit')
  assert.equal(harness.state()?.dirty, false)
  assert.equal(harness.lastPostedMessage()?.type, 'search')

  harness.receive({ type: 'busy', value: true })
  assert.equal(messageInput.disabled, true)
  assert.equal(harness.document.activeElement, null)
  harness.receive({ type: 'busy', value: false })
  assert.equal(harness.document.activeElement, messageInput)

  harness.receive({
    type: 'state',
    active: true,
    commitCount: 1,
    hasMore: false,
    hasRepository: true,
    query: createCommitSearchQuery({ message: 'external' }),
    synchronize: false,
  })
  assert.equal(messageInput.value, 'external')
})

interface IPostedMessage {
  readonly type?: unknown
}

interface IPersistedState {
  readonly dirty?: unknown
}

function createClientHarness(): {
  readonly document: TestDocument
  element(id: string): TestElement
  lastPostedMessage(): IPostedMessage | undefined
  receive(message: unknown): void
  state(): IPersistedState | undefined
} {
  const document = new TestDocument()
  const windowListeners = new Set<(event: { readonly data: unknown }) => void>()
  const postedMessages: IPostedMessage[] = []
  let persistedState: IPersistedState | undefined
  const vscode = {
    getState: (): IPersistedState | undefined => persistedState,
    postMessage: (message: IPostedMessage): void => {
      postedMessages.push(message)
    },
    setState: (state: IPersistedState): void => {
      persistedState = state
    },
  }
  const html = createCommitSearchViewHtml({
    cspSource: 'vscode-webview://vsgit-test',
  } as Parameters<typeof createCommitSearchViewHtml>[0])
  const script = html.match(/<script nonce="[^"]+">([\s\S]*?)<\/script>/)?.[1]
  assert.ok(script)
  runInNewContext(script, {
    acquireVsCodeApi: () => vscode,
    document,
    window: {
      addEventListener: (type: string, listener: (event: { readonly data: unknown }) => void) => {
        if (type === 'message') windowListeners.add(listener)
      },
    },
  })

  return {
    document,
    element: id => document.getElementById(id),
    lastPostedMessage: () => postedMessages.at(-1),
    receive: message => {
      for (const listener of [...windowListeners]) listener({ data: message })
    },
    state: () => persistedState,
  }
}

interface ITestEvent {
  readonly data?: unknown
  preventDefault(): void
}

class TestDocument {
  public activeElement: TestElement | null = null
  private readonly elements = new Map<string, TestElement>()

  public constructor() {
    for (const [id, tagName] of Object.entries({
      'search-form': 'FORM',
      search: 'BUTTON',
      clear: 'BUTTON',
      cancel: 'BUTTON',
      'filters-toggle': 'BUTTON',
      'filter-count': 'SPAN',
      'filter-panel': 'SECTION',
      status: 'SPAN',
      error: 'DIV',
      scope: 'SELECT',
      'scope-row': 'DIV',
      'revision-field': 'LABEL',
      'content-mode': 'SELECT',
      'content-row': 'DIV',
      'content-field': 'LABEL',
      revision: 'INPUT',
      path: 'INPUT',
      author: 'INPUT',
      since: 'INPUT',
      until: 'INPUT',
      message: 'INPUT',
      'content-value': 'INPUT',
    })) {
      this.elements.set(id, new TestElement(this, id, tagName))
    }
    this.getElementById('scope').value = 'head'
    this.getElementById('content-mode').value = 'none'
    this.getElementById('filter-panel').hidden = true
  }

  public getElementById(id: string): TestElement {
    const element = this.elements.get(id)
    if (!element) throw new Error(`Unknown test element: ${id}`)
    return element
  }

  public querySelectorAll(selector: string): TestElement[] {
    const tagNames = new Set(selector.split(',').map(value => value.trim().toUpperCase()))
    return [...this.elements.values()].filter(element => tagNames.has(element.tagName))
  }
}

class TestElement {
  public readonly classList = { toggle: (): void => {} }
  public hidden = false
  public required = false
  public textContent = ''
  public title = ''
  public value = ''
  private readonly attributes = new Map<string, string>()
  private readonly listeners = new Map<string, Set<(event: ITestEvent) => void>>()
  private disabledValue = false

  public constructor(
    private readonly ownerDocument: TestDocument,
    public readonly id: string,
    public readonly tagName: string,
  ) {}

  public get disabled(): boolean {
    return this.disabledValue
  }

  public set disabled(value: boolean) {
    this.disabledValue = value
    if (value && this.ownerDocument.activeElement === this) {
      this.ownerDocument.activeElement = null
    }
  }

  public addEventListener(type: string, listener: (event: ITestEvent) => void): void {
    const listeners = this.listeners.get(type) ?? new Set()
    listeners.add(listener)
    this.listeners.set(type, listeners)
  }

  public checkValidity(): boolean {
    return this.ownerDocument
      .querySelectorAll('input')
      .every(element => !element.required || Boolean(element.value))
  }

  public dispatch(type: string): void {
    const event: ITestEvent = { preventDefault: () => {} }
    for (const listener of this.listeners.get(type) ?? []) listener(event)
  }

  public focus(): void {
    if (!this.disabled && !this.hidden) this.ownerDocument.activeElement = this
  }

  public querySelectorAll(tagName: string): TestElement[] {
    return this.ownerDocument.querySelectorAll(tagName)
  }

  public reportValidity(): boolean {
    return this.checkValidity()
  }

  public setAttribute(name: string, value: string): void {
    this.attributes.set(name, value)
  }
}
