import path from 'node:path'
import {
  ProgressLocation,
  commands,
  window,
  workspace,
  type ExtensionContext,
  type TreeView,
} from 'vscode'
import { CompareSession } from './compare/compare-session'
import { resolveDisplayPath, type ICompareSnapshot, type IFileChange } from './contract'
import { GitClient } from './git/git-client'
import type { IFileNode } from './tree/change-tree'
import { ChangeTreeProvider } from './tree/change-tree-provider'
import { REVISION_SCHEME, RevisionContentProvider } from './view/revision-content-provider'

export function activate(context: ExtensionContext): void {
  const gitClient = new GitClient()
  const session = new CompareSession(gitClient)
  const treeProvider = new ChangeTreeProvider(session)
  const contentProvider = new RevisionContentProvider(gitClient)
  const treeView = window.createTreeView('vsgit.changes', {
    treeDataProvider: treeProvider,
    showCollapseAll: true,
  })

  context.subscriptions.push(
    session,
    treeProvider,
    treeView,
    workspace.registerTextDocumentContentProvider(REVISION_SCHEME, contentProvider),
    session.onDidChange(snapshot => updateViewState(treeView, snapshot)),
    commands.registerCommand('vsgit.compareRefs', () => compareReferences(session, gitClient)),
    commands.registerCommand('vsgit.refresh', () =>
      runSessionOperation('Refreshing comparison…', () => session.refresh()),
    ),
    commands.registerCommand('vsgit.swapRefs', () =>
      runSessionOperation('Swapping references…', () => session.swap()),
    ),
    commands.registerCommand('vsgit.clear', () => session.clear()),
    commands.registerCommand('vsgit.openDiff', (revisionOrNode: unknown, change: unknown) =>
      openFileDiff(session, contentProvider, revisionOrNode, change),
    ),
  )

  updateViewState(treeView, session.snapshot)
}

export function deactivate(): void {}

async function compareReferences(session: CompareSession, gitClient: GitClient): Promise<void> {
  try {
    const repositoryPath = await selectRepository(gitClient)
    if (!repositoryPath) return

    const baseRef = await window.showInputBox({
      ignoreFocusOut: true,
      prompt: 'Base commit, branch, or tag',
      title: 'VSGit: Compare References',
      value:
        session.snapshot?.repositoryPath === repositoryPath ? session.snapshot.baseRef : 'HEAD~1',
      validateInput: validateReferenceInput,
    })
    if (baseRef === undefined) return

    const targetRef = await window.showInputBox({
      ignoreFocusOut: true,
      prompt: 'Target commit, branch, or tag',
      title: 'VSGit: Compare References',
      value:
        session.snapshot?.repositoryPath === repositoryPath ? session.snapshot.targetRef : 'HEAD',
      validateInput: validateReferenceInput,
    })
    if (targetRef === undefined) return

    await runSessionOperation(`Comparing ${baseRef.trim()} with ${targetRef.trim()}…`, () =>
      session.compare(repositoryPath, baseRef, targetRef),
    )
  } catch (cause) {
    await window.showErrorMessage(`VSGit: ${readErrorMessage(cause)}`)
  }
}

async function selectRepository(gitClient: GitClient): Promise<string | null> {
  const candidates: string[] = []
  const activeUri = window.activeTextEditor?.document.uri
  if (activeUri?.scheme === 'file') candidates.push(path.dirname(activeUri.fsPath))
  for (const folder of workspace.workspaceFolders ?? []) candidates.push(folder.uri.fsPath)

  const repositories = new Set<string>()
  for (const candidate of candidates) {
    try {
      repositories.add(await gitClient.resolveRepository(candidate))
    } catch {
      // Non-repository workspace folders are intentionally skipped.
    }
  }

  if (repositories.size === 0) {
    await window.showErrorMessage('VSGit: Open a Git repository before comparing references.')
    return null
  }
  if (repositories.size === 1) return [...repositories][0] ?? null

  const selected = await window.showQuickPick(
    [...repositories].map(repositoryPath => ({
      label: path.basename(repositoryPath),
      description: repositoryPath,
      repositoryPath,
    })),
    { ignoreFocusOut: true, placeHolder: 'Select a Git repository' },
  )
  return selected?.repositoryPath ?? null
}

async function runSessionOperation(
  title: string,
  operation: () => Promise<ICompareSnapshot | null>,
): Promise<void> {
  try {
    await window.withProgress(
      { location: ProgressLocation.Notification, title, cancellable: false },
      operation,
    )
  } catch (cause) {
    await window.showErrorMessage(`VSGit: ${readErrorMessage(cause)}`)
  }
}

async function openFileDiff(
  session: CompareSession,
  contentProvider: RevisionContentProvider,
  revisionOrNode: unknown,
  changeValue: unknown,
): Promise<void> {
  const snapshot = session.snapshot
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

  const displayPath = resolveDisplayPath(change)
  const previousPath = change.previousPath ?? displayPath
  const currentPath = change.currentPath ?? displayPath
  const leftUri = contentProvider.createUri(
    snapshot.repositoryPath,
    snapshot.baseCommit,
    previousPath,
    'base',
    change.previousPath === null,
  )
  const rightUri = contentProvider.createUri(
    snapshot.repositoryPath,
    snapshot.targetCommit,
    currentPath,
    'target',
    change.currentPath === null,
  )
  const title = createDiffTitle(snapshot, change)
  await commands.executeCommand('vscode.diff', leftUri, rightUri, title, {
    preview: true,
  })
}

function isFileNode(value: unknown): value is IFileNode {
  if (!value || typeof value !== 'object') return false
  const node = value as Partial<IFileNode>
  return node.kind === 'file' && isFileChange(node.change)
}

function updateViewState(treeView: TreeView<unknown>, snapshot: ICompareSnapshot | null): void {
  void commands.executeCommand('setContext', 'vsgit.hasComparison', Boolean(snapshot))
  treeView.description = snapshot
    ? `${shorten(snapshot.baseRef)} ↔ ${shorten(snapshot.targetRef)} · ${snapshot.changes.length}`
    : undefined
  treeView.message =
    snapshot?.changes.length === 0 ? 'No changes between these references.' : undefined
}

function createDiffTitle(snapshot: ICompareSnapshot, change: IFileChange): string {
  const pathLabel =
    change.previousPath && change.currentPath && change.previousPath !== change.currentPath
      ? `${change.previousPath} → ${change.currentPath}`
      : resolveDisplayPath(change)
  return `${pathLabel} (${shorten(snapshot.baseRef)} ↔ ${shorten(snapshot.targetRef)})`
}

function isFileChange(value: unknown): value is IFileChange {
  if (!value || typeof value !== 'object') return false
  const change = value as Partial<IFileChange>
  return (
    typeof change.kind === 'string' &&
    typeof change.status === 'string' &&
    (change.previousPath === null || typeof change.previousPath === 'string') &&
    (change.currentPath === null || typeof change.currentPath === 'string')
  )
}

function validateReferenceInput(value: string): string | undefined {
  const reference = value.trim()
  if (!reference) return 'Enter a Git reference.'
  if (reference.length > 1024 || reference.includes('\0')) return 'Git reference is invalid.'
  return undefined
}

function shorten(value: string): string {
  return value.length > 24 ? `${value.slice(0, 21)}…` : value
}

function readErrorMessage(cause: unknown): string {
  return cause instanceof Error ? cause.message : 'Comparison failed.'
}
