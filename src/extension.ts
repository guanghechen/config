import { window, workspace, type ExtensionContext } from 'vscode'
import { CompareController } from './app/compare-controller'
import { CompareSession } from './compare/compare-session'
import { GitClient } from './git/git-client'
import { ChangeTreeProvider } from './view/change-tree-provider'
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
  const controller = new CompareController({ contentProvider, gitClient, session, treeView })

  context.subscriptions.push(
    controller,
    session,
    treeProvider,
    treeView,
    workspace.registerTextDocumentContentProvider(REVISION_SCHEME, contentProvider),
  )
}

export function deactivate(): void {}
