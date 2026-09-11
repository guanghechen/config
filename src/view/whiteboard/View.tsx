import React from 'react'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { useSearchParams } from 'react-router-dom'
import { MarkdownTopProvider } from '@/container/markdown/context/top/Provider'
import { LoginModal } from '@/container/LoginModal'
import { useSiteViewmodel } from '@/context/site'
import { useMermaidSyncThemeEffect } from '@/hook/useMermaidSyncThemeEffect'
import { loadReferencedText, saveReferencedText } from '@/shared/api/whiteboard'
import { parseDocument } from '@/shared/whiteboard/document'
import {
  elementBounds,
  intersects,
  labelArea,
  unionBounds,
  worldPoint,
} from '@/shared/whiteboard/geometry'
import { DEFAULT_STYLE, createDocument } from '@/shared/whiteboard/model'
import type {
  IElement,
  ILabelElement,
  INode,
  IStyle,
  IWhiteboardDocument,
} from '@/shared/whiteboard/model'
import type { IEditSession } from './InlineEditor'
import { createNode, useBoardInteraction } from './interaction'
import type { ITool } from './interaction'
import { MarkdownCard } from './MarkdownCard'
import { LabelEditor } from './LabelEditor'
import { MarkdownCode } from './MarkdownCode'
import { CanvasRenderer, isCard, visibleBounds } from './renderer'
import { MarkdownResources } from './resources'
import { BoardStore } from './store'
import { DrawingTools } from './DrawingTools'
import { BoardNavigation } from './BoardNavigation'
import { SelectionActions } from './SelectionActions'
import { StyleControls } from './StyleControls'
import { useWhiteboardTheme } from './theme'
import { BoardAppearance } from './BoardAppearance'
import './style.css'

const InlineEditor = React.lazy(() =>
  import('./InlineEditor').then(module => ({ default: module.InlineEditor })),
)

const markdownRenderers = { code: MarkdownCode }

function readDraft(key: string): {
  document: IWhiteboardDocument
  revision?: string
  error?: string
  recovered?: boolean
} {
  try {
    const raw = localStorage.getItem(key)
    if (raw) {
      const value = JSON.parse(raw)
      return {
        document: parseDocument(JSON.stringify(value.document)),
        revision: value.revision,
        recovered: true,
      }
    }
  } catch (error) {
    return {
      document: createDocument(),
      error: `Unable to restore draft: ${error instanceof Error ? error.message : String(error)}`,
    }
  }
  return { document: createDocument() }
}

export const WhiteboardView: React.FC = () => {
  const [search] = useSearchParams()
  const filepath = search.get('filepath') ?? undefined
  return (
    <>
      <WhiteboardBoard key={filepath ?? 'scratch'} filepath={filepath} />
      <LoginModal />
    </>
  )
}

interface IBoardProps {
  filepath?: string
  initialDocument?: IWhiteboardDocument
}

export const WhiteboardBoard: React.FC<IBoardProps> = props => {
  useMermaidSyncThemeEffect()
  const site = useSiteViewmodel()
  const theme = useStateValue(site.theme$)
  return (
    <MarkdownTopProvider theme={theme} customizedRendererMap={markdownRenderers}>
      <BoardContent {...props} />
    </MarkdownTopProvider>
  )
}

const BoardContent: React.FC<IBoardProps> = ({ filepath, initialDocument }) => {
  const { theme, ready: themeReady } = useWhiteboardTheme()
  const draftKey = `yoz.whiteboard.v1:${filepath ?? 'scratch'}`
  const [initial] = React.useState(() =>
    initialDocument
      ? { document: initialDocument, revision: undefined, error: undefined, recovered: false }
      : readDraft(draftKey),
  )
  const [store] = React.useState(() => new BoardStore(initial.document))
  const [resources] = React.useState(() => new MarkdownResources())
  const [renderer] = React.useState(() => new CanvasRenderer(theme))
  const snapshot = React.useSyncExternalStore(store.subscribe, store.getSnapshot)
  const stage = React.useRef<HTMLDivElement>(null)
  const drawing = React.useRef<HTMLCanvasElement>(null)
  const overlay = React.useRef<HTMLCanvasElement>(null)
  const fileInput = React.useRef<HTMLInputElement>(null)
  const [size, setSize] = React.useState({ width: 1, height: 1 })
  const [tool, setTool] = React.useState<ITool>('select')
  const [style, setStyle] = React.useState<IStyle>(DEFAULT_STYLE)
  const [message, setMessage] = React.useState(initial.error ?? '')
  const [status, setStatus] = React.useState(
    initial.recovered ? 'Draft restored' : 'Local whiteboard',
  )
  const [loading, setLoading] = React.useState(!!filepath)
  const [saving, setSaving] = React.useState(false)
  const [editor, setEditor] = React.useState<IEditSession | null>(null)
  const [labelEditor, setLabelEditor] = React.useState<ILabelElement | null>(null)
  const [reference, setReference] = React.useState<string | null>(null)
  const revision = React.useRef(initial.revision)
  const editGeneration = React.useRef(0)
  const importGeneration = React.useRef(0)

  React.useEffect(() => resources.start(), [resources])
  React.useEffect(
    () => () => {
      editGeneration.current++
      importGeneration.current++
    },
    [],
  )
  React.useLayoutEffect(() => {
    const element = stage.current!
    const observer = new ResizeObserver(() =>
      setSize({ width: element.clientWidth, height: element.clientHeight }),
    )
    observer.observe(element)
    return () => observer.disconnect()
  }, [])

  const fit = React.useCallback(
    (selectionOnly = false): void => {
      const current = store.getSnapshot()
      const map = new Map(current.document.elements.map(item => [item.id, item]))
      const elements = selectionOnly
        ? current.document.elements.filter(item => current.selected.has(item.id))
        : current.document.elements
      const bounds = unionBounds(elements.map(item => elementBounds(item, map)))
      if (!bounds) {
        store.camera({ x: size.width / 2, y: size.height / 2, zoom: 1 })
        return
      }
      const zoom = Math.max(
        0.05,
        Math.min(
          2,
          (size.width - 180) / (bounds.width + 80),
          (size.height - 180) / (bounds.height + 80),
        ),
      )
      store.camera({
        x: size.width / 2 - (bounds.x + bounds.width / 2) * zoom,
        y: size.height / 2 - (bounds.y + bounds.height / 2) * zoom,
        zoom,
      })
    },
    [store, size],
  )

  React.useEffect(() => {
    if (!filepath) return
    const controller = new AbortController()
    void loadReferencedText(filepath, undefined, controller.signal)
      .then(data => {
        if (!data || controller.signal.aborted) return
        const document = parseDocument(data.content)
        if (initial.recovered) {
          setMessage(
            'Recovered local draft. Saving checks the file version from when the draft was created.',
          )
        } else {
          revision.current = data.revision
          store.replace(document)
        }
        setLoading(false)
        setStatus('File loaded · local draft enabled')
      })
      .catch((error: unknown) => {
        if (!controller.signal.aborted) {
          setLoading(false)
          setMessage(error instanceof Error ? error.message : String(error))
        }
      })
    return () => controller.abort()
  }, [filepath, initial.recovered, store])

  React.useEffect(() => {
    let saved = store.getDocument()
    let pending: ReturnType<typeof setTimeout> | undefined
    let failed = false
    const persist = (): void => {
      clearTimeout(pending)
      try {
        localStorage.setItem(
          draftKey,
          JSON.stringify({ document: store.getDocument(), revision: revision.current }),
        )
        saved = store.getDocument()
        failed = false
        setStatus('Draft saved locally')
      } catch (error) {
        failed = true
        setMessage(`Draft not saved: ${error instanceof Error ? error.message : String(error)}`)
      }
    }
    const unsubscribe = store.subscribe(() => {
      if (store.getDocument() === saved) return
      clearTimeout(pending)
      setStatus('Saving local draft…')
      pending = setTimeout(persist, 500)
    })
    const unload = (event: BeforeUnloadEvent): void => {
      if (store.getDocument() !== saved) persist()
      if (failed) event.preventDefault()
    }
    window.addEventListener('beforeunload', unload)
    return () => {
      unsubscribe()
      window.removeEventListener('beforeunload', unload)
      clearTimeout(pending)
      if (store.getDocument() !== saved) persist()
    }
  }, [store, draftKey])

  const edit = React.useCallback(
    async (node: IElement): Promise<void> => {
      if (editor || labelEditor || node.type === 'stroke') return
      const generation = ++editGeneration.current
      if (node.type === 'shape' || node.type === 'edge') {
        store.select(new Set([node.id]))
        setLabelEditor(node)
        return
      }
      let content =
        node.type === 'markdown' && node.source.kind === 'inline'
          ? node.source.content
          : node.type === 'text'
            ? node.text
            : node.type === 'image'
              ? node.url
              : ''
      let sourceFile: string | undefined, sourceRevision: string | undefined
      try {
        if (node.type === 'markdown' && node.source.kind === 'file') {
          setMessage('Loading source for editing…')
          const data = await loadReferencedText(node.source.filepath)
          if (!data || generation !== editGeneration.current) return
          content = data.content
          sourceFile = data.filepath
          sourceRevision = data.revision
          setMessage('')
        }
        if (generation !== editGeneration.current) return
        if (!store.getDocument().elements.some(element => element.id === node.id)) return
        const camera = store.getSnapshot().camera
        setEditor({
          node,
          content,
          filepath: sourceFile,
          revision: sourceRevision,
          left: node.x * camera.zoom + camera.x,
          top: node.y * camera.zoom + camera.y,
        })
      } catch (error) {
        if (generation === editGeneration.current)
          setMessage(error instanceof Error ? error.message : String(error))
      }
    },
    [store, editor, labelEditor],
  )

  const { marquee, ...events } = useBoardInteraction(
    stage,
    store,
    tool,
    style,
    setTool,
    node => {
      void edit(node)
    },
    setMessage,
  )
  React.useLayoutEffect(() => {
    if (!drawing.current || !overlay.current) return
    renderer.setTheme(theme)
    renderer.draw(
      drawing.current,
      snapshot.document.elements,
      snapshot.camera,
      size.width,
      size.height,
    )
    renderer.drawSelection(
      overlay.current,
      snapshot.document.elements,
      snapshot.camera,
      snapshot.selected,
      size.width,
      size.height,
      marquee,
    )
  }, [renderer, snapshot, size, marquee, theme])
  React.useEffect(() => {
    const timer = setTimeout(() => {
      if (!drawing.current) return
      renderer.invalidate()
      renderer.draw(
        drawing.current,
        snapshot.document.elements,
        snapshot.camera,
        size.width,
        size.height,
      )
    }, 180)
    return () => clearTimeout(timer)
  }, [renderer, snapshot.document.elements, snapshot.camera, size])
  React.useEffect(() => () => renderer.dispose(), [renderer])
  const visible = visibleBounds(snapshot.camera, size.width, size.height)
  // Keep the grid 16–32 screen pixels apart; dense overview dots otherwise dominate raster work.
  const gridSpacing =
    24 * snapshot.camera.zoom * 2 ** Math.ceil(Math.log2(16 / (24 * snapshot.camera.zoom)))
  const cards =
    snapshot.camera.zoom < 0.35
      ? []
      : (snapshot.document.elements.filter(
          item => isCard(item) && intersects(item, visible),
        ) as INode[])
  const selected = snapshot.document.elements.filter(item => snapshot.selected.has(item.id))
  const displayStyle = selected[0]?.style ?? style
  const editingLabelArea = labelEditor
    ? labelArea(
        labelEditor,
        new Map(snapshot.document.elements.map(element => [element.id, element])),
      )
    : null

  const updateStyle = React.useCallback(
    (patch: Partial<IStyle>): void => {
      setStyle(current => ({ ...current, ...patch }))
      const current = store.getSnapshot()
      if (current.selected.size)
        store.commit({
          ...current.document,
          elements: current.document.elements.map(item =>
            current.selected.has(item.id) ? { ...item, style: { ...item.style, ...patch } } : item,
          ),
        })
    },
    [store],
  )
  const download = (): void => {
    const document = store.getDocument()
    const url = URL.createObjectURL(
      new Blob([JSON.stringify(document, null, 2)], { type: 'application/json' }),
    )
    const anchor = window.document.createElement('a')
    anchor.href = url
    anchor.download = `${document.title.replace(/[^\p{L}\p{N} _-]/gu, '').slice(0, 80) || 'whiteboard'}.whiteboard`
    anchor.click()
    setTimeout(() => URL.revokeObjectURL(url), 1000)
  }
  const saveFile = async (): Promise<void> => {
    if (!filepath || !revision.current || saving) return
    const document = store.getDocument()
    setSaving(true)
    try {
      revision.current = await saveReferencedText(
        filepath,
        JSON.stringify(document, null, 2),
        revision.current,
      )
      localStorage.setItem(
        draftKey,
        JSON.stringify({ document: store.getDocument(), revision: revision.current }),
      )
      setStatus(
        store.getDocument() === document
          ? 'Saved to file'
          : 'File saved · newer local changes remain',
      )
      setMessage('')
    } catch (error) {
      setMessage(error instanceof Error ? error.message : String(error))
    } finally {
      setSaving(false)
    }
  }

  const reloadFile = async (): Promise<void> => {
    if (
      !filepath ||
      loading ||
      saving ||
      !window.confirm('Reload from disk and discard local changes? Export first to keep a copy.')
    )
      return
    const generation = ++importGeneration.current
    setLoading(true)
    try {
      const data = await loadReferencedText(filepath)
      if (!data || generation !== importGeneration.current) return
      const document = parseDocument(data.content)
      revision.current = data.revision
      store.replace(document)
      setMessage('')
      fit()
    } catch (error) {
      if (generation === importGeneration.current)
        setMessage(error instanceof Error ? error.message : String(error))
    } finally {
      if (generation === importGeneration.current) setLoading(false)
    }
  }

  return (
    <div
      className="wb"
      data-whiteboard
      data-element-count={snapshot.document.elements.length}
      style={
        {
          '--wb-on-accent': theme.onAccent,
          '--wb-selected-ink': theme.activeInk,
          '--wb-readable-link': theme.colors['theme:accent'],
        } as React.CSSProperties
      }
    >
      <div
        ref={stage}
        className={`wb-stage wb-tool-${tool}`}
        tabIndex={0}
        role="application"
        aria-label="Whiteboard canvas"
        {...events}
        style={{
          visibility: themeReady ? 'visible' : 'hidden',
          backgroundPosition: `${snapshot.camera.x}px ${snapshot.camera.y}px`,
          backgroundSize: `${gridSpacing}px ${gridSpacing}px`,
        }}
      >
        <canvas ref={drawing} className="wb-drawing" />
        <div
          className="wb-world"
          style={{
            transform: `translate(${snapshot.camera.x}px,${snapshot.camera.y}px) scale(${snapshot.camera.zoom})`,
          }}
        >
          {cards.map(node => (
            <MarkdownCard key={node.id} node={node} resources={resources} theme={theme} />
          ))}
        </div>
        <canvas ref={overlay} className="wb-overlay" />
      </div>
      <header className="wb-filebar" data-wb-ui>
        <a href="/ws" title="Back to workspace" aria-label="Workspace">
          ⌂
        </a>
        <input
          aria-label="Whiteboard title"
          value={snapshot.document.title}
          onChange={event => store.commit({ ...snapshot.document, title: event.target.value })}
        />
        <details className="wb-file-menu">
          <summary aria-label="File menu">☰</summary>
          <div>
            <button
              onClick={() => {
                if (
                  !snapshot.document.elements.length ||
                  window.confirm(
                    'Start a new whiteboard? Export the current board first to keep a separate copy.',
                  )
                ) {
                  store.replace(createDocument())
                  store.camera({ x: 0, y: 0, zoom: 1 })
                }
              }}
            >
              New whiteboard
            </button>
            <button onClick={() => fileInput.current?.click()}>Import .whiteboard</button>
            <button onClick={download}>Export .whiteboard</button>
            {filepath && (
              <button onClick={() => void saveFile()} disabled={saving || !revision.current}>
                {saving ? 'Saving…' : 'Save to source file'}
              </button>
            )}
            {filepath && (
              <button onClick={() => void reloadFile()} disabled={loading || saving}>
                Reload source file
              </button>
            )}
            <button onClick={() => setReference('')}>Reference Markdown file…</button>
          </div>
        </details>
        <BoardAppearance />
      </header>
      <DrawingTools tool={tool} setTool={setTool} />
      {(selected.length > 0 || (tool !== 'select' && tool !== 'hand')) && (
        <aside className="wb-inspector" data-wb-ui aria-label="Properties">
          <h2>{selected.length ? `${selected.length} selected` : 'Style'}</h2>
          <StyleControls
            style={displayStyle}
            colors={theme.colors}
            onChange={updateStyle}
            showSketch={
              selected.length
                ? selected.some(item => item.type !== 'text' && item.type !== 'stroke')
                : tool !== 'text' && tool !== 'stroke'
            }
            showFillPattern={
              selected.length
                ? selected.some(item => item.type === 'shape')
                : ['rectangle', 'ellipse', 'diamond'].includes(tool)
            }
          />
          {selected.length === 1 && selected[0].type !== 'stroke' && (
            <button onClick={() => void edit(selected[0])}>
              {selected[0].type === 'shape' || selected[0].type === 'edge'
                ? 'Edit label ↵'
                : 'Edit content ↵'}
            </button>
          )}
          {selected.length === 1 && selected[0].type === 'edge' && (
            <p className="wb-endpoint-hint">
              Drag a round endpoint to reconnect. Release on empty space to detach.
            </p>
          )}
          {selected.length > 0 && (
            <>
              <SelectionActions selected={selected} store={store} />
              <button onClick={store.removeSelected}>Delete selection</button>
            </>
          )}
        </aside>
      )}
      {!snapshot.document.elements.length && !loading && (
        <div className="wb-welcome" aria-hidden="true">
          <h1>Room for your next idea.</h1>
          <p>Draw a block. Connect a thought. Add the details.</p>
          <p className="wb-welcome-hint">
            M for Markdown · Space to pan · Ctrl / ⌘ + scroll to zoom
          </p>
        </div>
      )}
      <BoardNavigation
        store={store}
        zoomPercent={Math.round(snapshot.camera.zoom * 100)}
        size={size}
        selectedCount={selected.length}
        nodeCount={snapshot.document.elements.filter(item => item.type !== 'edge').length}
        status={status}
        fit={fit}
      />
      {message && (
        <div className="wb-notice" role="alert" data-wb-ui>
          <span>{message}</span>
          <button aria-label="Dismiss message" onClick={() => setMessage('')}>
            ×
          </button>
        </div>
      )}
      {loading && (
        <div className="wb-loading" role="status">
          Loading whiteboard…
        </div>
      )}
      {editor && (
        <React.Suspense fallback={<div className="wb-loading">Loading editor…</div>}>
          <InlineEditor
            key={editor.node.id}
            session={editor}
            resources={resources}
            onClose={() => setEditor(null)}
            onSave={content => {
              const current = store.getSnapshot().document
              if (!editor.filepath) {
                const elements = current.elements.map(item => {
                  if (item.id !== editor.node.id) return item
                  if (item.type === 'markdown')
                    return { ...item, source: { kind: 'inline' as const, content } }
                  if (item.type === 'text') return { ...item, text: content }
                  if (item.type === 'image') return { ...item, url: content }
                  return item
                })
                try {
                  store.commit(parseDocument(JSON.stringify({ ...current, elements })))
                } catch (error) {
                  setMessage(error instanceof Error ? error.message : String(error))
                  return
                }
              }
              setEditor(null)
            }}
          />
        </React.Suspense>
      )}
      {labelEditor && editingLabelArea && (
        <LabelEditor
          key={labelEditor.id}
          label={labelEditor.label ?? ''}
          position={{
            x:
              (editingLabelArea.x + editingLabelArea.width / 2) * snapshot.camera.zoom +
              snapshot.camera.x,
            y:
              (editingLabelArea.y + editingLabelArea.height / 2) * snapshot.camera.zoom +
              snapshot.camera.y,
          }}
          viewport={size}
          onClose={() => {
            setLabelEditor(null)
            stage.current?.focus()
          }}
          onSave={label => {
            const current = store.getDocument()
            store.commit({
              ...current,
              elements: current.elements.map(element =>
                element.id === labelEditor.id &&
                (element.type === 'shape' || element.type === 'edge')
                  ? { ...element, label }
                  : element,
              ),
            })
            setLabelEditor(null)
            stage.current?.focus()
          }}
        />
      )}
      {reference !== null && (
        <form
          className="wb-reference"
          data-wb-ui
          role="dialog"
          aria-label="Reference Markdown"
          onSubmit={event => {
            event.preventDefault()
            if (!reference.startsWith('/') || !reference.toLowerCase().endsWith('.md')) {
              setMessage('Enter an absolute .md path within the allowed workspace.')
              return
            }
            const point = worldPoint(
              { x: size.width / 2 - 180, y: size.height / 2 - 130 },
              snapshot.camera,
            )
            const node: INode = {
              ...createNode('markdown', point, style),
              type: 'markdown',
              source: { kind: 'file', filepath: reference },
            }
            store.commit({ ...snapshot.document, elements: [...snapshot.document.elements, node] })
            store.select(new Set([node.id]))
            setReference(null)
          }}
        >
          <h2>Reference Markdown</h2>
          <p>Changes to the source appear on the board. Editing saves back to the file.</p>
          <input
            autoFocus
            aria-label="Markdown file path"
            placeholder="/absolute/path/to/notes.md"
            value={reference}
            onChange={event => setReference(event.target.value)}
          />
          <footer>
            <button type="button" onClick={() => setReference(null)}>
              Cancel
            </button>
            <button className="wb-primary" type="submit">
              Add reference
            </button>
          </footer>
        </form>
      )}
      <input
        ref={fileInput}
        hidden
        type="file"
        accept=".whiteboard,application/json"
        onChange={event => {
          const input = event.target
          const file = input.files?.[0]
          input.value = ''
          if (!file) return
          const generation = ++importGeneration.current
          const previous = store.getDocument()
          void file
            .text()
            .then(text => {
              if (generation !== importGeneration.current) return
              const document = parseDocument(text)
              if (store.getDocument() !== previous) {
                setMessage('The whiteboard changed while importing. Please import the file again.')
                return
              }
              store.replace(document)
              setMessage('')
              store.camera({ x: 80, y: 100, zoom: 1 })
            })
            .catch(error => {
              if (generation === importGeneration.current)
                setMessage(error instanceof Error ? error.message : String(error))
            })
        }}
      />
    </div>
  )
}
