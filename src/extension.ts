import { window, workspace, type ExtensionContext } from 'vscode'
import { ComparisonController } from './app/comparison/comparison-controller'
import { CommitComparisonController } from './app/history/commit-comparison-controller'
import { CommitDiffController } from './app/history/commit-diff-controller'
import { CommitHistoryController } from './app/history/commit-history-controller'
import { CommitViewController } from './app/history/commit-view-controller'
import { ComparisonSession } from './comparison/session'
import { GitClient } from './git/git-client'
import { CommitHistorySession } from './history/commit-history-session'
import { CommitMarkSession } from './history/commit-mark-session'
import { VIEW_IDS } from './platform/extension-ids'
import { ComparisonTreeProvider } from './view/comparison/tree-provider'
import { REVISION_SCHEME, RevisionContentProvider } from './view/diff/revision-content-provider'
import { GitFileDecorationProvider } from './view/file-change/decoration-provider'
import { CommitHistoryTreeProvider } from './view/history/tree-provider'

export function activate(context: ExtensionContext): void {
  const gitClient = new GitClient()
  const comparisonSession = new ComparisonSession(gitClient)
  const historySession = new CommitHistorySession(gitClient)
  const markSession = new CommitMarkSession()
  const comparisonTreeProvider = new ComparisonTreeProvider(comparisonSession)
  const commitTreeProvider = new CommitHistoryTreeProvider(gitClient, markSession, historySession)
  const contentProvider = new RevisionContentProvider(gitClient)
  const comparisonTreeView = window.createTreeView(VIEW_IDS.comparison, {
    treeDataProvider: comparisonTreeProvider,
    showCollapseAll: true,
  })
  const commitTreeView = window.createTreeView(VIEW_IDS.commits, {
    treeDataProvider: commitTreeProvider,
    showCollapseAll: true,
  })
  const comparisonController = new ComparisonController({
    comparisonSession,
    contentProvider,
    gitClient,
    treeView: comparisonTreeView,
  })
  const commitComparisonController = new CommitComparisonController({
    comparisonSession,
    gitClient,
    historySession,
    markSession,
  })
  const commitDiffController = new CommitDiffController({ contentProvider, historySession })
  const commitHistoryController = new CommitHistoryController({ gitClient, historySession })
  const commitViewController = new CommitViewController({
    historySession,
    markSession,
    treeView: commitTreeView,
  })

  context.subscriptions.push(
    commitComparisonController,
    commitDiffController,
    commitHistoryController,
    commitViewController,
    comparisonController,
    historySession,
    markSession,
    comparisonSession,
    commitTreeProvider,
    comparisonTreeProvider,
    commitTreeView,
    comparisonTreeView,
    window.registerFileDecorationProvider(new GitFileDecorationProvider()),
    workspace.registerTextDocumentContentProvider(REVISION_SCHEME, contentProvider),
  )
  void commitHistoryController.initialize()
}

export function deactivate(): void {}
