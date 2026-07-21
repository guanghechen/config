import type { WebviewView, WebviewViewProvider } from 'vscode'
import type { IDisposable } from '../../core/signal'
import { createCommitSearchQuery, type ICommitSearchQuery } from '../../git/commit-search'
import type { CommitHistorySession } from '../../history/commit-history-session'
import type { ICommitHistorySnapshot } from '../../history/model'
import type { CommitSearchViewOperationResult } from './search-view-contract'
import { createCommitSearchViewHtml } from './search-view-html'
import { parseCommitSearchViewMessage } from './search-view-protocol'

export interface ICommitSearchViewOperations {
  runSearch(
    query: ICommitSearchQuery,
    signal: AbortSignal,
  ): Promise<CommitSearchViewOperationResult>
  clearSearch(signal: AbortSignal): Promise<CommitSearchViewOperationResult>
}

export interface ICommitSearchViewProviderOptions {
  readonly historySession: CommitHistorySession
  readonly operations: ICommitSearchViewOperations
}

export class CommitSearchViewProvider implements WebviewViewProvider, IDisposable {
  private readonly historySession: CommitHistorySession
  private readonly historySubscription: IDisposable
  private readonly operations: ICommitSearchViewOperations
  private activeRequest: AbortController | null = null
  private view: WebviewView | null = null
  private viewSubscriptions: IDisposable | null = null

  public constructor(options: ICommitSearchViewProviderOptions) {
    this.historySession = options.historySession
    this.operations = options.operations
    this.historySubscription = this.historySession.onDidChange(snapshot => {
      void this.postState(snapshot, false)
    })
  }

  public resolveWebviewView(view: WebviewView): void {
    if (this.view) this.releaseView(this.view)
    this.view = view
    view.webview.options = { enableScripts: true, localResourceRoots: [] }
    view.webview.html = createCommitSearchViewHtml(view.webview)
    this.viewSubscriptions = combineDisposables(
      view.webview.onDidReceiveMessage(message => void this.handleMessage(message)),
      view.onDidDispose(() => this.releaseView(view)),
    )
  }

  public dispose(): void {
    if (this.view) this.releaseView(this.view)
    this.historySubscription.dispose()
  }

  private async handleMessage(value: unknown): Promise<void> {
    let message
    try {
      message = parseCommitSearchViewMessage(value)
    } catch (cause) {
      await this.postError(cause)
      return
    }

    switch (message.type) {
      case 'ready':
        await this.postState(this.historySession.snapshot, true)
        return
      case 'cancel':
        this.activeRequest?.abort()
        return
      case 'clear':
        await this.runOperation(signal => this.operations.clearSearch(signal))
        return
      case 'search':
        await this.runOperation(signal => this.operations.runSearch(message.query, signal))
    }
  }

  private async runOperation(
    operation: (signal: AbortSignal) => Promise<CommitSearchViewOperationResult>,
  ): Promise<void> {
    this.activeRequest?.abort()
    const request = new AbortController()
    this.activeRequest = request

    try {
      await this.postMessage({ type: 'busy', value: true })
      const result = await operation(request.signal)
      if (this.activeRequest !== request) return
      if (request.signal.aborted) return

      if (result.kind === 'cancelled') return
      if (result.kind === 'unavailable') {
        await this.postMessage({ type: 'error', message: 'Open or select a Git repository first.' })
        return
      }
      await this.postState(result.snapshot ?? this.historySession.snapshot, true)
    } catch (cause) {
      if (this.activeRequest === request && !request.signal.aborted) await this.postError(cause)
    } finally {
      if (this.activeRequest === request) {
        this.activeRequest = null
        await this.postMessage({ type: 'busy', value: false })
      }
    }
  }

  private postState(
    snapshot: ICommitHistorySnapshot | null,
    synchronize: boolean,
  ): Thenable<boolean> {
    const query = snapshot?.searchQuery ?? createCommitSearchQuery()
    return this.postMessage({
      type: 'state',
      active: Boolean(snapshot?.searchQuery),
      commitCount: snapshot?.commits.length ?? 0,
      hasMore: snapshot?.hasMore ?? false,
      hasRepository: Boolean(snapshot),
      query,
      synchronize,
    })
  }

  private postError(cause: unknown): Thenable<boolean> {
    const message = cause instanceof Error ? cause.message : 'Commit search failed.'
    return this.postMessage({ type: 'error', message })
  }

  private postMessage(message: unknown): Thenable<boolean> {
    return this.view?.webview.postMessage(message) ?? Promise.resolve(false)
  }

  private releaseView(view: WebviewView): void {
    if (this.view !== view) return
    this.activeRequest?.abort()
    this.activeRequest = null
    this.viewSubscriptions?.dispose()
    this.viewSubscriptions = null
    this.view = null
  }
}

function combineDisposables(...disposables: IDisposable[]): IDisposable {
  let disposed = false
  return {
    dispose: () => {
      if (disposed) return
      disposed = true
      for (const disposable of disposables) disposable.dispose()
    },
  }
}
