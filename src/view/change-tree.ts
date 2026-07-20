import { resolveDisplayPath, type IFileChange } from '../git/file-change'

export interface IDirectoryNode {
  readonly kind: 'directory'
  readonly name: string
  readonly path: string
  readonly children: ReadonlyArray<IChangeTreeNode>
}

export interface IFileNode {
  readonly kind: 'file'
  readonly name: string
  readonly path: string
  readonly change: IFileChange
}

export type IChangeTreeNode = IDirectoryNode | IFileNode

interface IMutableDirectoryNode {
  readonly name: string
  readonly path: string
  readonly directories: Map<string, IMutableDirectoryNode>
  readonly files: IFileNode[]
}

export function buildChangeTree(
  changes: ReadonlyArray<IFileChange>,
): ReadonlyArray<IChangeTreeNode> {
  const root = createDirectory('', '')

  for (const change of changes) {
    const filePath = resolveDisplayPath(change)
    const segments = filePath.split('/').filter(Boolean)
    const name = segments.pop()
    if (!name) continue

    let directory = root
    for (const segment of segments) {
      const directoryPath = directory.path ? `${directory.path}/${segment}` : segment
      let child = directory.directories.get(segment)
      if (!child) {
        child = createDirectory(segment, directoryPath)
        directory.directories.set(segment, child)
      }
      directory = child
    }
    directory.files.push({ kind: 'file', name, path: filePath, change })
  }

  return finalizeChildren(root)
}

function createDirectory(name: string, directoryPath: string): IMutableDirectoryNode {
  return { name, path: directoryPath, directories: new Map(), files: [] }
}

function finalizeChildren(directory: IMutableDirectoryNode): ReadonlyArray<IChangeTreeNode> {
  const directories: IDirectoryNode[] = [...directory.directories.values()]
    .sort((left, right) => compareNames(left.name, right.name))
    .map(child => ({
      kind: 'directory',
      name: child.name,
      path: child.path,
      children: finalizeChildren(child),
    }))
  const files = [...directory.files].sort((left, right) => compareNames(left.name, right.name))
  return [...directories, ...files]
}

function compareNames(left: string, right: string): number {
  return left.localeCompare(right, undefined, {
    numeric: true,
    sensitivity: 'base',
  })
}
