import { window, workspace, type ExtensionContext } from 'vscode'
import { CommitController } from './app/commit-controller'
import { CompareController } from './app/compare-controller'
import { CompareSession } from './compare/compare-session'
import { GitClient } from './git/git-client'
import { CommitHistorySession } from './history/commit-history-session'
import { ChangeTreeProvider } from './view/change-tree-provider'
import { CommitTreeProvider } from './view/commit-tree-provider'
import { REVISION_SCHEME, RevisionContentProvider } from './view/revision-content-provider'

export function activate(context: ExtensionContext): void {
  const gitClient = new GitClient()
  const session = new CompareSession(gitClient)
  const treeProvider = new ChangeTreeProvider(session)
  const historySession = new CommitHistorySession(gitClient)
  const commitTreeProvider = new CommitTreeProvider(gitClient, historySession)
  const contentProvider = new RevisionContentProvider(gitClient)
  const treeView = window.createTreeView('vsgit.changes', {
    treeDataProvider: treeProvider,
    showCollapseAll: true,
  })
  const commitTreeView = window.createTreeView('vsgit.commits', {
    canSelectMany: true,
    treeDataProvider: commitTreeProvider,
    showCollapseAll: true,
  })
  const controller = new CompareController({ contentProvider, gitClient, session, treeView })
  const commitController = new CommitController({
    compareSession: session,
    contentProvider,
    gitClient,
    session: historySession,
    treeView: commitTreeView,
  })

  context.subscriptions.push(
    commitController,
    controller,
    historySession,
    session,
    commitTreeProvider,
    treeProvider,
    commitTreeView,
    treeView,
    workspace.registerTextDocumentContentProvider(REVISION_SCHEME, contentProvider),
  )
  void commitController.initialize()
}

export function deactivate(): void {}
