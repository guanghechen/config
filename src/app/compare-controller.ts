import { Disposable, ProgressLocation, commands, window, type TreeView } from 'vscode'
import { CompareSession } from '../compare/compare-session'
import type { ICompareSnapshot } from '../compare/model'
import { formatReferenceLabel } from '../compare/reference-label'
import { GitClient } from '../git/git-client'
import { isFileChange } from '../git/file-change'
import type { IChangeTreeNode, IFileNode } from '../view/change-tree'
import { openRevisionDiff } from '../view/diff-opener'
import { RevisionContentProvider } from '../view/revision-content-provider'
import { pickRepository } from './repository-picker'

const COMMAND = {
  clear: 'vsgit.clear',
  compareRefs: 'vsgit.compareRefs',
  openDiff: 'vsgit.openDiff',
  refresh: 'vsgit.refresh',
  swapRefs: 'vsgit.swapRefs',
} as const

export interface ICompareControllerOptions {
  readonly contentProvider: RevisionContentProvider
  readonly gitClient: GitClient
  readonly session: CompareSession
  readonly treeView: TreeView<IChangeTreeNode>
}

export class CompareController implements Disposable {
  private readonly contentProvider: RevisionContentProvider
  private readonly gitClient: GitClient
  private readonly registrations: Disposable
  private readonly session: CompareSession
  private readonly treeView: TreeView<IChangeTreeNode>

  public constructor(options: ICompareControllerOptions) {
    this.contentProvider = options.contentProvider
    this.gitClient = options.gitClient
    this.session = options.session
    this.treeView = options.treeView
    this.registrations = Disposable.from(
      this.session.onDidChange(snapshot => this.updateViewState(snapshot)),
      commands.registerCommand(COMMAND.compareRefs, () => this.compareReferences()),
      commands.registerCommand(COMMAND.refresh, () =>
        this.runOperation('Refreshing comparison…', () => this.session.refresh()),
      ),
      commands.registerCommand(COMMAND.swapRefs, () =>
        this.runOperation('Swapping references…', () => this.session.swap()),
      ),
      commands.registerCommand(COMMAND.clear, () => this.session.clear()),
      commands.registerCommand(COMMAND.openDiff, (revisionOrNode: unknown, change: unknown) =>
        this.openFileDiff(revisionOrNode, change),
      ),
    )
    this.updateViewState(this.session.snapshot)
  }

  public dispose(): void {
    this.registrations.dispose()
  }

  private async compareReferences(): Promise<void> {
    try {
      const repositoryPath = await pickRepository(this.gitClient)
      if (!repositoryPath) return

      const baseRef = await this.promptForReference(
        'Base commit, branch, or tag',
        this.session.snapshot?.repositoryPath === repositoryPath
          ? this.session.snapshot.baseRef
          : 'HEAD~1',
      )
      if (baseRef === null) return

      const targetRef = await this.promptForReference(
        'Target commit, branch, or tag',
        this.session.snapshot?.repositoryPath === repositoryPath
          ? this.session.snapshot.targetRef
          : 'HEAD',
      )
      if (targetRef === null) return

      await this.runOperation(`Comparing ${baseRef} with ${targetRef}…`, () =>
        this.session.compare(repositoryPath, baseRef, targetRef),
      )
    } catch (cause) {
      await this.showError(cause)
    }
  }

  private async promptForReference(prompt: string, value: string): Promise<string | null> {
    const reference = await window.showInputBox({
      ignoreFocusOut: true,
      prompt,
      title: 'VSGit: Compare References',
      value,
      validateInput: validateReferenceInput,
    })
    return reference === undefined ? null : reference.trim()
  }

  private async runOperation(
    title: string,
    operation: () => Promise<ICompareSnapshot | null>,
  ): Promise<void> {
    try {
      await window.withProgress(
        { location: ProgressLocation.Notification, title, cancellable: false },
        operation,
      )
    } catch (cause) {
      await this.showError(cause)
    }
  }

  private async openFileDiff(revisionOrNode: unknown, changeValue: unknown): Promise<void> {
    const snapshot = this.session.snapshot
    const revision = isFileNode(revisionOrNode) ? snapshot?.revision : revisionOrNode
    const change = isFileNode(revisionOrNode) ? revisionOrNode.change : changeValue
    if (
      !snapshot ||
      typeof revision !== 'number' ||
      revision !== snapshot.revision ||
      !isFileChange(change)
    ) {
      await window.showWarningMessage('VSGit: This comparison is stale. Select the file again.')
      return
    }
    await openRevisionDiff(snapshot, change, this.contentProvider)
  }

  private updateViewState(snapshot: ICompareSnapshot | null): void {
    void commands.executeCommand('setContext', 'vsgit.hasComparison', Boolean(snapshot))
    this.treeView.description = snapshot
      ? `${formatReferenceLabel(snapshot.baseRef)} ↔ ${formatReferenceLabel(snapshot.targetRef)} · ${snapshot.changes.length}`
      : undefined
    this.treeView.message =
      snapshot?.changes.length === 0 ? 'No changes between these references.' : undefined
  }

  private async showError(cause: unknown): Promise<void> {
    const message = cause instanceof Error ? cause.message : 'Comparison failed.'
    await window.showErrorMessage(`VSGit: ${message}`)
  }
}

function isFileNode(value: unknown): value is IFileNode {
  if (!value || typeof value !== 'object') return false
  const node = value as Partial<IFileNode>
  return node.kind === 'file' && isFileChange(node.change)
}

function validateReferenceInput(value: string): string | undefined {
  const reference = value.trim()
  if (!reference) return 'Enter a Git reference.'
  if (reference.length > 1024 || reference.includes('\0')) return 'Git reference is invalid.'
  return undefined
}
