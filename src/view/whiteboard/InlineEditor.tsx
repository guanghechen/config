import React from 'react'
import { BoardIcon, BoardIconLabel } from './BoardIcon'
import { Editor, loader } from '@monaco-editor/react'
import * as monaco from 'monaco-editor'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { useSiteViewmodel } from '@/context/site'
import { registerEditorThemes } from '@/container/code-editor/theme'
import EditorWorker from 'monaco-editor/editor/editor.worker.js?worker'
import CssWorker from 'monaco-editor/languages/features/css/css.worker.js?worker'
import HtmlWorker from 'monaco-editor/languages/features/html/html.worker.js?worker'
import JsonWorker from 'monaco-editor/languages/features/json/json.worker.js?worker'
import TypeScriptWorker from 'monaco-editor/languages/features/typescript/ts.worker.js?worker'
import { FileConflictError, loadReferencedText, saveReferencedText } from '@/shared/api/whiteboard'
import type { INode } from '@/shared/whiteboard/model'
import type { MarkdownResources } from './resources'

// Reuse the installed Monaco package; no CDN or extra dependency is needed.
const previousEnvironment = self.MonacoEnvironment
self.MonacoEnvironment = {
  ...previousEnvironment,
  getWorker: (moduleId, label) => {
    if (label === 'json') return new JsonWorker()
    if (['css', 'scss', 'less'].includes(label)) return new CssWorker()
    if (['html', 'handlebars', 'razor'].includes(label)) return new HtmlWorker()
    if (['typescript', 'javascript'].includes(label)) return new TypeScriptWorker()
    return previousEnvironment?.getWorker?.(moduleId, label) ?? new EditorWorker()
  },
}
loader.config({ monaco })

export interface IEditSession {
  readonly node: INode
  readonly content: string
  readonly filepath?: string
  readonly revision?: string
  readonly left: number
  readonly top: number
}

export const InlineEditor: React.FC<{
  session: IEditSession
  resources: MarkdownResources
  onSave: (content: string) => void
  onClose: () => void
}> = ({ session, resources, onSave, onClose }) => {
  const palette = useStateValue(useSiteViewmodel().palette$)
  // Monaco owns the draft; feeding each keystroke back through React can reset rapid input.
  const draft = React.useRef(session.content)
  const editorRef = React.useRef<monaco.editor.IStandaloneCodeEditor | null>(null)
  const getDraft = React.useCallback(() => editorRef.current?.getValue() ?? draft.current, [])
  const [error, setError] = React.useState('')
  const [disk, setDisk] = React.useState<{ content: string; revision: string } | null>(null)
  const [busy, setBusy] = React.useState(false)
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
        await saveReferencedText(session.filepath, content, session.revision)
        resources.refresh(session.filepath)
      }
      if (mounted.current) onSave(content)
    } catch (error) {
      if (!mounted.current) return
      setError(error instanceof Error ? error.message : String(error))
      if (error instanceof FileConflictError && session.filepath) {
        try {
          const snapshot = await loadReferencedText(session.filepath)
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
        left: Math.max(12, Math.min(session.left, window.innerWidth - 680)),
        top: Math.max(76, Math.min(session.top, window.innerHeight - 520)),
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
        <Editor
          language={session.node.type === 'markdown' ? 'markdown' : 'plaintext'}
          defaultValue={session.content}
          onChange={value => {
            draft.current = value ?? ''
          }}
          beforeMount={registerEditorThemes}
          theme={palette}
          options={{
            fontSize: 15,
            minimap: { enabled: false },
            wordWrap: 'on',
            automaticLayout: true,
            scrollBeyondLastLine: false,
            padding: { top: 12 },
            readOnly: busy,
            editContext: false,
          }}
          onMount={editor => {
            editorRef.current = editor
            editor.focus()
          }}
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
