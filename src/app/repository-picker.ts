import path from 'node:path'
import { window, workspace } from 'vscode'
import { GitClient } from '../git/git-client'

export async function pickRepository(gitClient: GitClient): Promise<string | null> {
  const candidates = collectRepositoryCandidates()
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

function collectRepositoryCandidates(): ReadonlyArray<string> {
  const candidates: string[] = []
  const activeUri = window.activeTextEditor?.document.uri
  if (activeUri?.scheme === 'file') candidates.push(path.dirname(activeUri.fsPath))
  for (const folder of workspace.workspaceFolders ?? []) candidates.push(folder.uri.fsPath)
  return candidates
}
