import React from 'react'
import { useBoardHost } from '../../HostContext'
import { WhiteboardFileConflictError } from '../../contracts'
import type { IWhiteboardEditorHandle } from '../../contracts'
import { PlainTextEditor } from './PlainTextEditor'
import { BoardIcon, BoardIconLabel } from '../BoardIcon'
import type { INode } from '@/shared/whiteboard/model'
import type { MarkdownResources } from '../../io/resources'

export interface IEditSession {
  readonly node: INode
  readonly content: string
  readonly filepath?: string
  readonly revision?: string
  readonly left: number
  readonly top: number
}

export const InlineEditor: React.FC<{
  viewport: { width: number; height: number }
  session: IEditSession
  resources: MarkdownResources
  onSave: (content: string) => void
  onClose: () => void
}> = ({ viewport, session, resources, onSave, onClose }) => {
  const { files, TextEditor = PlainTextEditor } = useBoardHost()
  // Monaco owns the draft; feeding each keystroke back through React can reset rapid input.
  const draft = React.useRef(session.content)
  const editorRef = React.useRef<IWhiteboardEditorHandle | null>(null)
  const getDraft = React.useCallback(() => editorRef.current?.getValue() ?? draft.current, [])
  const mountEditor = React.useCallback((editor: IWhiteboardEditorHandle) => {
    editorRef.current = editor
    editor.focus()
  }, [])
  const [error, setError] = React.useState('')
  const [disk, setDisk] = React.useState<{ content: string; revision: string } | null>(null)
  const [busy, setBusy] = React.useState(false)
  const width = Math.min(650, Math.max(0, viewport.width - 24))
  const height = Math.min(
    480,
    Math.max(260, viewport.height - 100),
    Math.max(0, viewport.height - 24),
  )
  const left = Math.max(12, Math.min(session.left, viewport.width - width - 12))
  const top = Math.max(12, Math.min(session.top, viewport.height - height - 12))
  const mounted = React.useRef(true)
  React.useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
    }
  }, [])
  React.useEffect(() => {
    const guard = (event: BeforeUnloadEvent): void => {
      if (getDraft() !== session.content) event.preventDefault()
    }
    window.addEventListener('beforeunload', guard)
    return () => window.removeEventListener('beforeunload', guard)
  }, [getDraft, session.content])

  const close = (): void => {
    if (!busy && (getDraft() === session.content || window.confirm('Discard unsaved edits?')))
      onClose()
  }
  const save = async (): Promise<void> => {
    if (busy) return
    const content = getDraft()
    setBusy(true)
    setError('')
    try {
      if (session.filepath && session.revision) {
        await files!.save(session.filepath, content, session.revision)
        resources.refresh(session.filepath)
      }
      if (mounted.current) onSave(content)
    } catch (error) {
      if (!mounted.current) return
      setError(error instanceof Error ? error.message : String(error))
      if (error instanceof WhiteboardFileConflictError && session.filepath) {
        try {
          const snapshot = await files!.load(session.filepath)
          if (mounted.current && snapshot) setDisk(snapshot)
        } catch {
          /* Keep the conflict and draft visible if reloading is unavailable. */
        }
      }
    } finally {
      if (mounted.current) setBusy(false)
    }
  }

  return (
    <section
      className="wb-editor"
      data-wb-ui
      role="dialog"
      aria-label="Edit node"
      style={{
        left,
        top,
        maxWidth: Math.max(0, viewport.width - left - 12),
        maxHeight: Math.max(0, viewport.height - top - 12),
      }}
      onKeyDownCapture={event => {
        if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
          event.preventDefault()
          event.stopPropagation()
          void save()
        }
        if (event.key === 'Escape') {
          event.preventDefault()
          event.stopPropagation()
          close()
        }
      }}
    >
      <header>
        <span>
          {session.filepath ||
            (session.node.type === 'image' ? 'Image URL or absolute path' : 'Edit Markdown / text')}
        </span>
        <button disabled={busy} onClick={close} aria-label="Close editor">
          <BoardIcon name="close" />
        </button>
      </header>
      {error && (
        <div role="alert" className="wb-resource-error">
          {error}
        </div>
      )}
      <div className="wb-monaco">
        <TextEditor
          language={session.node.type === 'markdown' ? 'markdown' : 'plaintext'}
          initialValue={session.content}
          onChange={value => {
            draft.current = value
          }}
          readOnly={busy}
          onMount={mountEditor}
        />
      </div>
      {disk && (
        <details className="wb-disk-version">
          <summary>
            <BoardIconLabel name="visible">
              View current disk version — your draft is above
            </BoardIconLabel>
          </summary>
          <pre>{disk.content}</pre>
        </details>
      )}
      <footer>
        <span>Ctrl / ⌘ + Enter to save</span>
        {disk && (
          <button
            onClick={() => {
              void navigator.clipboard
                .writeText(getDraft())
                .catch(() =>
                  setError('Clipboard unavailable; select and copy the draft in the editor.'),
                )
            }}
          >
            <BoardIconLabel name="copy">Copy draft</BoardIconLabel>
          </button>
        )}
        {disk && (
          <button
            onClick={() => {
              if (
                window.confirm(
                  'Discard your draft and close? Reopen the node to edit the latest file.',
                )
              ) {
                resources.refresh(session.filepath)
                onClose()
              }
            }}
          >
            <BoardIconLabel name="reload">Reload disk version</BoardIconLabel>
          </button>
        )}
        <button onClick={close} disabled={busy}>
          <BoardIconLabel name="close">Cancel</BoardIconLabel>
        </button>
        <button className="wb-primary" onClick={() => void save()} disabled={busy || !!disk}>
          <BoardIconLabel name="save">{busy ? 'Saving…' : 'Save'}</BoardIconLabel>
        </button>
      </footer>
    </section>
  )
}
