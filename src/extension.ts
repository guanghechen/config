import { window, workspace, type ExtensionContext } from 'vscode'
import { CommitController } from './app/commit-controller'
import { CompareController } from './app/compare-controller'
import { CompareSession } from './compare/compare-session'
import { GitClient } from './git/git-client'
import { CommitHistorySession } from './history/commit-history-session'
import { CommitMarkSession } from './history/commit-mark-session'
import { ChangeTreeProvider } from './view/change-tree-provider'
import { CommitTreeProvider } from './view/commit-tree-provider'
import { REVISION_SCHEME, RevisionContentProvider } from './view/revision-content-provider'

export function activate(context: ExtensionContext): void {
  const gitClient = new GitClient()
  const session = new CompareSession(gitClient)
  const treeProvider = new ChangeTreeProvider(session)
  const historySession = new CommitHistorySession(gitClient)
  const commitMarks = new CommitMarkSession()
  const commitTreeProvider = new CommitTreeProvider(gitClient, commitMarks, historySession)
  const contentProvider = new RevisionContentProvider(gitClient)
  const treeView = window.createTreeView('vsgit.changes', {
    treeDataProvider: treeProvider,
    showCollapseAll: true,
  })
  const commitTreeView = window.createTreeView('vsgit.commits', {
    treeDataProvider: commitTreeProvider,
    showCollapseAll: true,
  })
  const controller = new CompareController({ contentProvider, gitClient, session, treeView })
  const commitController = new CommitController({
    compareSession: session,
    contentProvider,
    gitClient,
    marks: commitMarks,
    session: historySession,
    treeView: commitTreeView,
  })

  context.subscriptions.push(
    commitController,
    controller,
    commitMarks,
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
