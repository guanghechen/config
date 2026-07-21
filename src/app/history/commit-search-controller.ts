import { Disposable, ProgressLocation, commands, window, type QuickPickItem } from 'vscode'
import {
  createCommitSearchQuery,
  type CommitContentSearch,
  type CommitSearchScope,
  type ICommitSearchQuery,
  type ICommitSearchQueryInput,
} from '../../git/commit-search'
import type { CommitHistorySession } from '../../history/commit-history-session'
import type { ICommitHistorySnapshot } from '../../history/model'
import { COMMAND_IDS } from '../../platform/extension-ids'
import { formatCommitSearchQuery } from '../../view/history/search-presentation'
import type { IRepositoryResolver } from '../shared/repository-discovery'
import { pickRepository } from '../shared/repository-picker'

type SearchEditorAction =
  'run' | 'scope' | 'path' | 'author' | 'since' | 'until' | 'message' | 'content' | 'reset'

type OptionalSearchField = 'path' | 'author' | 'since' | 'until' | 'message'

interface ISearchEditorItem extends QuickPickItem {
  readonly action: SearchEditorAction
}

interface IScopeItem extends QuickPickItem {
  readonly scope: CommitSearchScope | 'custom'
}

interface IContentModeItem extends QuickPickItem {
  readonly mode: CommitContentSearch['mode'] | 'clear'
}

interface IOptionalFieldPrompt {
  readonly title: string
  readonly prompt: string
  readonly placeHolder: string
}

export interface ICommitSearchControllerOptions {
  readonly historySession: CommitHistorySession
  readonly repositoryResolver: IRepositoryResolver
}

export class CommitSearchController implements Disposable {
  private readonly historySession: CommitHistorySession
  private readonly repositoryResolver: IRepositoryResolver
  private readonly registrations: Disposable

  public constructor(options: ICommitSearchControllerOptions) {
    this.historySession = options.historySession
    this.repositoryResolver = options.repositoryResolver
    this.registrations = Disposable.from(
      commands.registerCommand(COMMAND_IDS.searchCommits, () => this.searchCommits()),
      commands.registerCommand(COMMAND_IDS.clearCommitSearch, () => this.clearSearch()),
    )
  }

  public dispose(): void {
    this.registrations.dispose()
  }

  private async searchCommits(): Promise<void> {
    try {
      const repositoryPath =
        this.historySession.snapshot?.repositoryPath ??
        (await pickRepository(this.repositoryResolver))
      if (!repositoryPath) return

      let query =
        this.historySession.snapshot?.searchQuery ??
        createCommitSearchQuery({ scope: { kind: 'head' } })

      while (true) {
        const selected = await window.showQuickPick(createSearchEditorItems(query), {
          ignoreFocusOut: true,
          placeHolder: 'Configure filters, then run the search',
          title: 'VSGit: Search Commits',
        })
        if (!selected) return

        if (selected.action === 'run') {
          const completed = await this.runOperation(
            `Searching commits: ${formatCommitSearchQuery(query)}…`,
            signal => this.historySession.search(repositoryPath, query, signal),
          )
          if (completed) return
          continue
        }
        if (selected.action === 'reset') {
          query = createCommitSearchQuery()
          continue
        }
        if (selected.action === 'scope') {
          query = (await this.editScope(query)) ?? query
          continue
        }
        if (selected.action === 'content') {
          query = (await this.editContent(query)) ?? query
          continue
        }

        query =
          (await this.editOptionalField(query, selected.action, FIELD_PROMPTS[selected.action])) ??
          query
      }
    } catch (cause) {
      await this.showError(cause)
    }
  }

  private async clearSearch(): Promise<void> {
    await this.runOperation('Clearing commit search…', signal =>
      this.historySession.clearSearch(signal),
    )
  }

  private async editScope(query: ICommitSearchQuery): Promise<ICommitSearchQuery | null> {
    const selected = await window.showQuickPick<IScopeItem>(
      [
        {
          label: 'HEAD',
          description: 'Search commits reachable from current HEAD',
          scope: { kind: 'head' },
        },
        {
          label: 'All refs',
          description: 'Search all local and remote refs',
          scope: { kind: 'all' },
        },
        {
          label: 'Custom revision or range…',
          description: 'Examples: main, v2.0..HEAD, main...feature',
          scope: 'custom',
        },
      ],
      { ignoreFocusOut: true, placeHolder: 'Select history scope', title: 'VSGit: Search Scope' },
    )
    if (!selected) return null
    if (selected.scope !== 'custom') return updateQuery(query, { scope: selected.scope })

    const revision = await window.showInputBox({
      ignoreFocusOut: true,
      placeHolder: 'main, v2.0..HEAD, or main...feature',
      prompt: 'Enter one Git revision or revision range',
      title: 'VSGit: Search Revision',
      value: query.scope.kind === 'revision' ? query.scope.revision : '',
      validateInput: validateRevision,
    })
    return revision === undefined
      ? null
      : updateQuery(query, { scope: { kind: 'revision', revision } })
  }

  private async editContent(query: ICommitSearchQuery): Promise<ICommitSearchQuery | null> {
    const selected = await window.showQuickPick<IContentModeItem>(
      [
        {
          label: 'Text occurrence (-S)',
          description: 'Find commits that change the number of exact text occurrences',
          mode: 'text',
        },
        {
          label: 'Changed-line regex (-G)',
          description: 'Find commits whose added or removed lines match a regex',
          mode: 'regex',
        },
        { label: 'Clear content filter', mode: 'clear' },
      ],
      {
        ignoreFocusOut: true,
        placeHolder: 'Select content search mode',
        title: 'VSGit: Content Search',
      },
    )
    if (!selected) return null
    if (selected.mode === 'clear') return updateQuery(query, { content: null })

    const value = await window.showInputBox({
      ignoreFocusOut: true,
      placeHolder: selected.mode === 'text' ? 'Exact text' : 'Regular expression',
      prompt:
        selected.mode === 'text'
          ? 'Find commits that add or remove this exact text'
          : 'Find commits with changed lines matching this regular expression',
      title: selected.mode === 'text' ? 'VSGit: Text Search (-S)' : 'VSGit: Regex Search (-G)',
      value: query.content?.mode === selected.mode ? query.content.value : '',
      validateInput: validateRequiredFilter,
    })
    return value === undefined
      ? null
      : updateQuery(query, { content: { mode: selected.mode, value } })
  }

  private async editOptionalField(
    query: ICommitSearchQuery,
    field: OptionalSearchField,
    prompt: IOptionalFieldPrompt,
  ): Promise<ICommitSearchQuery | null> {
    const value = await window.showInputBox({
      ignoreFocusOut: true,
      placeHolder: prompt.placeHolder,
      prompt: prompt.prompt,
      title: prompt.title,
      value: query[field] ?? '',
      validateInput: validateOptionalFilter,
    })
    return value === undefined ? null : updateQuery(query, { [field]: value || null })
  }

  private async runOperation(
    title: string,
    operation: (signal: AbortSignal) => Promise<ICommitHistorySnapshot | null>,
  ): Promise<boolean> {
    try {
      await window.withProgress(
        { cancellable: true, location: ProgressLocation.Notification, title },
        async (_progress, token) => {
          const cancellation = new AbortController()
          const cancellationRegistration = token.onCancellationRequested(() => cancellation.abort())
          try {
            if (token.isCancellationRequested) cancellation.abort()
            return await operation(cancellation.signal)
          } finally {
            cancellationRegistration.dispose()
          }
        },
      )
      return true
    } catch (cause) {
      await this.showError(cause)
      return false
    }
  }

  private async showError(cause: unknown): Promise<void> {
    const message = cause instanceof Error ? cause.message : 'Commit search failed.'
    await window.showErrorMessage(`VSGit: ${message}`)
  }
}

const FIELD_PROMPTS: Readonly<Record<OptionalSearchField, IOptionalFieldPrompt>> = Object.freeze({
  path: {
    title: 'VSGit: Search Path',
    prompt: 'Limit results to one path or Git pathspec; leave empty to clear',
    placeHolder: 'src/auth or :(glob)src/**/*.ts',
  },
  author: {
    title: 'VSGit: Search Author',
    prompt: 'Match author name or email; leave empty to clear',
    placeHolder: 'Alice or alice@example.com',
  },
  since: {
    title: 'VSGit: Search Since',
    prompt: 'Include commits after this Git date; leave empty to clear',
    placeHolder: '2026-01-01 or 2 weeks ago',
  },
  until: {
    title: 'VSGit: Search Until',
    prompt: 'Include commits before this Git date; leave empty to clear',
    placeHolder: '2026-07-01',
  },
  message: {
    title: 'VSGit: Search Message',
    prompt: 'Match commit messages using a Git regex; leave empty to clear',
    placeHolder: 'fix.*auth',
  },
})

function createSearchEditorItems(query: ICommitSearchQuery): ISearchEditorItem[] {
  return [
    {
      action: 'run',
      label: '$(search) Run Search',
      description: formatCommitSearchQuery(query),
    },
    { action: 'scope', label: 'Scope', description: formatScope(query.scope) },
    { action: 'path', label: 'Path / pathspec', description: query.path ?? 'Not set' },
    { action: 'author', label: 'Author', description: query.author ?? 'Not set' },
    { action: 'since', label: 'Since', description: query.since ?? 'Not set' },
    { action: 'until', label: 'Until', description: query.until ?? 'Not set' },
    { action: 'message', label: 'Commit message', description: query.message ?? 'Not set' },
    { action: 'content', label: 'Content change', description: formatContent(query.content) },
    { action: 'reset', label: '$(clear-all) Reset Filters' },
  ]
}

function updateQuery(
  query: ICommitSearchQuery,
  changes: ICommitSearchQueryInput,
): ICommitSearchQuery {
  return createCommitSearchQuery({ ...query, ...changes })
}

function formatScope(scope: CommitSearchScope): string {
  switch (scope.kind) {
    case 'head':
      return 'HEAD'
    case 'all':
      return 'All refs'
    case 'revision':
      return scope.revision
  }
}

function formatContent(content: CommitContentSearch | null): string {
  if (!content) return 'Not set'
  return `${content.mode === 'text' ? 'Text (-S)' : 'Regex (-G)'}: ${content.value}`
}

function validateRevision(value: string): string | undefined {
  try {
    createCommitSearchQuery({ scope: { kind: 'revision', revision: value } })
    return undefined
  } catch (cause) {
    return cause instanceof Error ? cause.message : 'Revision or range is invalid.'
  }
}

function validateRequiredFilter(value: string): string | undefined {
  if (!value) return 'Enter a search value.'
  return validateFilter(value)
}

function validateOptionalFilter(value: string): string | undefined {
  return value ? validateFilter(value) : undefined
}

function validateFilter(value: string): string | undefined {
  if (value.length > 4096 || value.includes('\0')) return 'Search value is invalid.'
  return undefined
}
