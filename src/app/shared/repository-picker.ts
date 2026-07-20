import path from 'node:path'
import { window, workspace } from 'vscode'
import { resolveRepositoryCandidates, type IRepositoryResolver } from './repository-discovery'

export async function pickRepository(
  repositoryResolver: IRepositoryResolver,
): Promise<string | null> {
  const repositories = await discoverRepositories(repositoryResolver)

  if (repositories.length === 0) {
    await window.showErrorMessage('VSGit: Open a Git repository to continue.')
    return null
  }
  if (repositories.length === 1) return repositories[0] ?? null

  const selected = await window.showQuickPick(
    repositories.map(repositoryPath => ({
      label: path.basename(repositoryPath),
      description: repositoryPath,
      repositoryPath,
    })),
    { ignoreFocusOut: true, placeHolder: 'Select a Git repository' },
  )
  return selected?.repositoryPath ?? null
}

export function discoverRepositories(
  repositoryResolver: IRepositoryResolver,
): Promise<ReadonlyArray<string>> {
  const candidates = collectRepositoryCandidates()
  return resolveRepositoryCandidates(candidates, repositoryResolver)
}

function collectRepositoryCandidates(): ReadonlyArray<string> {
  const candidates: string[] = []
  const activeUri = window.activeTextEditor?.document.uri
  if (activeUri?.scheme === 'file') candidates.push(path.dirname(activeUri.fsPath))
  for (const folder of workspace.workspaceFolders ?? []) candidates.push(folder.uri.fsPath)
  return candidates
}
