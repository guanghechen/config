import { FILE_CHANGE_KINDS, type FileChangeKind } from '../git/file-change'

const QUERY_KEY = 'vsgitChange'

export interface IFileChangeDecoration {
  readonly badge: string
  readonly colorId: string
  readonly label: string
}

const DECORATIONS: Readonly<Record<FileChangeKind, IFileChangeDecoration>> = Object.freeze({
  added: { badge: 'A', colorId: 'gitDecoration.addedResourceForeground', label: 'Added' },
  copied: { badge: 'C', colorId: 'gitDecoration.renamedResourceForeground', label: 'Copied' },
  deleted: { badge: 'D', colorId: 'gitDecoration.deletedResourceForeground', label: 'Deleted' },
  modified: {
    badge: 'M',
    colorId: 'gitDecoration.modifiedResourceForeground',
    label: 'Modified',
  },
  renamed: { badge: 'R', colorId: 'gitDecoration.renamedResourceForeground', label: 'Renamed' },
  typeChanged: {
    badge: 'T',
    colorId: 'gitDecoration.modifiedResourceForeground',
    label: 'Type changed',
  },
  unmerged: {
    badge: 'U',
    colorId: 'gitDecoration.conflictingResourceForeground',
    label: 'Conflict',
  },
  unknown: {
    badge: '?',
    colorId: 'gitDecoration.untrackedResourceForeground',
    label: 'Unknown',
  },
})

export function createFileChangeQuery(kind: FileChangeKind): string {
  return new URLSearchParams([[QUERY_KEY, kind]]).toString()
}

export function parseFileChangeQuery(query: string): FileChangeKind | null {
  const kind = new URLSearchParams(query).get(QUERY_KEY)
  return FILE_CHANGE_KINDS.includes(kind as FileChangeKind) ? (kind as FileChangeKind) : null
}

export function resolveFileChangeDecoration(kind: FileChangeKind): IFileChangeDecoration {
  return DECORATIONS[kind]
}
