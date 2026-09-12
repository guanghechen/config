import type React from 'react'
import type { IWhiteboardDocument } from '@/shared/whiteboard/model'
import type { IWhiteboardTheme } from './theme'

export interface IWhiteboardFile {
  readonly filepath: string
  readonly content: string
  readonly revision: string
  readonly renderData?: unknown
}

export interface IWhiteboardFiles {
  load: (
    filepath: string,
    revision?: string,
    signal?: AbortSignal,
  ) => Promise<IWhiteboardFile | null>
  save: (filepath: string, content: string, expectedRevision: string) => Promise<string>
  create: (
    directory: string,
    filename: string,
    content: string,
  ) => Promise<{ filepath: string; revision: string }>
  subscribe?: (changed: (filepath: string) => void) => () => void
}

export class WhiteboardFileConflictError extends Error {}

export interface IWhiteboardDrafts {
  read: (filepath?: string) => string | null
  write: (filepath: string | undefined, content: string) => void
}

export interface IWhiteboardMarkdownProps {
  content: string
  renderData?: unknown
}

export interface IWhiteboardEditorHandle {
  getValue: () => string
  focus: () => void
}

export interface IWhiteboardEditorProps {
  initialValue: string
  language: 'markdown' | 'plaintext'
  readOnly: boolean
  onChange: (value: string) => void
  onMount: (editor: IWhiteboardEditorHandle) => void
}

export interface IWhiteboardFilePickerProps {
  mode: 'reference' | 'save'
  title: string
  directory?: string
  onChoose: (filepath: string) => void | Promise<void>
  onClose: () => void
}

// Host capabilities are stable for a mounted board. They do not own the board document or history.
export interface IWhiteboardHost {
  readonly files?: IWhiteboardFiles
  readonly drafts?: IWhiteboardDrafts
  readonly Markdown?: React.ComponentType<IWhiteboardMarkdownProps>
  readonly TextEditor?: React.ComponentType<IWhiteboardEditorProps>
  readonly FilePicker?: React.ComponentType<IWhiteboardFilePickerProps>
  readonly appearance?: React.ReactNode
  readonly workspaceHref?: string
  readonly openFile?: (filepath: string) => void
  readonly imageUrl?: (url: string) => string
}

export interface IWhiteboardProps {
  readonly initialDocument?: IWhiteboardDocument
  readonly filepath?: string
  readonly theme?: IWhiteboardTheme
  readonly host?: IWhiteboardHost
  readonly style?: React.CSSProperties
}
