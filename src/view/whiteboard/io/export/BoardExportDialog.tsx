import React from 'react'
import { useBoardHost } from '../../HostContext'
import { BoardIconLabel } from '../../ui/BoardIcon'
import type { IElement } from '@/shared/whiteboard/model'
import { exportBounds, exportSelection, rasterSize } from '@/shared/whiteboard/export'
import type { BoardStore } from '../../store'
import type { BoardTypography } from '../../rendering/typography'
import type { IWhiteboardTheme } from '../../theme'
import type { IMarkdownResources } from '../resources'
import { DrawingScene } from '../../rendering/DrawingElement'
import { MarkdownCard } from '../../rendering/MarkdownCard'
import {
  ExportAssets,
  frozenMarkdown,
  rasterize,
  serializeDrawing,
  svgDocument,
  waitForArtwork,
} from './exportArtwork'

interface IExportBatch {
  readonly key: number
  readonly scene: ReadonlyArray<IElement>
  readonly elements: ReadonlyArray<IElement>
  readonly resources: IMarkdownResources
  readonly ready: (host: HTMLDivElement) => void
}

const ExportBatch: React.FC<{
  batch: IExportBatch
  theme: IWhiteboardTheme
  typography: BoardTypography
}> = ({ batch, theme, typography }) => {
  const ref = React.useRef<HTMLDivElement>(null)
  React.useLayoutEffect(() => {
    batch.ready(ref.current!)
  }, [batch])
  return (
    <div ref={ref} className="wb-export-stage" aria-hidden="true">
      <React.Suspense fallback={<span data-export-pending>Loading…</span>}>
        <DrawingScene
          elements={batch.scene}
          visible={batch.elements}
          theme={theme}
          typography={typography}
          card={node => (
            <MarkdownCard key={node.id} node={node} resources={batch.resources} theme={theme} />
          )}
        />
      </React.Suspense>
    </div>
  )
}

export const BoardExportDialog: React.FC<{
  store: BoardStore
  typography: BoardTypography
  theme: IWhiteboardTheme
  onClose: () => void
}> = ({ store, typography, theme, onClose }) => {
  const { files } = useBoardHost()
  const [format, setFormat] = React.useState<'svg' | 'png'>('png')
  const [selection, setSelection] = React.useState(store.getSnapshot().selected.size > 0)
  const [scale, setScale] = React.useState(1)
  const [background, setBackground] = React.useState(true)
  const [busy, setBusy] = React.useState(false)
  const [status, setStatus] = React.useState('')
  const [error, setError] = React.useState('')
  const [batch, setBatch] = React.useState<IExportBatch | null>(null)
  const active = React.useRef<AbortController | null>(null)
  const exportTheme = React.useRef<IWhiteboardTheme | null>(null)
  const mounted = React.useRef(true)
  const button = React.useRef<HTMLButtonElement>(null)
  React.useEffect(() => {
    mounted.current = true
    button.current?.focus()
    return () => {
      mounted.current = false
      active.current?.abort()
    }
  }, [])
  React.useEffect(() => {
    if (active.current && exportTheme.current !== theme)
      active.current.abort(new Error('Theme changed during export. Export again.'))
  }, [theme])
  const close = (): void => {
    active.current?.abort()
    onClose()
  }

  const build = async (type: 'svg' | 'png', signal: AbortSignal): Promise<Blob> => {
    const snapshot = store.getSnapshot(),
      document = store.getDocument()
    if (snapshot.document !== document)
      throw new Error('Finish the current gesture before exporting')
    const elements = exportSelection(document, selection ? snapshot.selected : undefined)
    const bounds = exportBounds(elements, document.elements)
    const size = type === 'png' ? rasterSize(bounds, scale) : null
    setStatus('Loading resources…')
    const resources = await frozenMarkdown(elements, signal, files),
      assets = new ExportAssets(signal),
      parts: string[] = []
    let length = 0
    for (let index = 0; index < elements.length; index += 16) {
      signal.throwIfAborted()
      const slice = elements.slice(index, index + 16)
      const host = await new Promise<HTMLDivElement>((resolve, reject) => {
        const abort = (): void => reject(signal.reason)
        signal.addEventListener('abort', abort, { once: true })
        setBatch({
          key: index,
          scene: document.elements,
          elements: slice,
          resources,
          ready: node => {
            signal.removeEventListener('abort', abort)
            if (signal.aborted) reject(signal.reason)
            else resolve(node)
          },
        })
      })
      await waitForArtwork(host, signal)
      const nodes = [...host.querySelectorAll(':scope > [data-node-id]')]
      if (nodes.length !== slice.length) throw new Error('Export scene did not finish rendering')
      for (let item = 0; item < slice.length; item++) {
        signal.throwIfAborted()
        try {
          const part = await serializeDrawing(nodes[item], slice[item], assets)
          length += part.length
          if (length > 100_000_000)
            throw new Error('Export exceeds 100 MB; choose a smaller selection')
          parts.push(part)
        } catch (reason) {
          throw new Error(
            `Element ${slice[item].id}: ${reason instanceof Error ? reason.message : String(reason)}`,
            { cause: reason },
          )
        }
      }
      setStatus(`Rendered ${Math.min(index + slice.length, elements.length)} of ${elements.length}`)
    }
    const fonts = await assets.fontFaces()
    signal.throwIfAborted()
    const svg = svgDocument(
      parts,
      bounds,
      `${fonts}\n${assets.styleSheet()}`,
      background ? theme.canvas : undefined,
    )
    if (svg.length > 100_000_000)
      throw new Error('Export exceeds 100 MB; choose a smaller selection')
    setStatus(type === 'svg' ? 'Preparing SVG…' : 'Encoding PNG…')
    return size ? rasterize(svg, size, signal) : new Blob([svg], { type: 'image/svg+xml' })
  }

  const start = (copy: boolean): void => {
    if (active.current) return
    const controller = new AbortController()
    active.current = controller
    exportTheme.current = theme
    setBusy(true)
    setError('')
    const signal = AbortSignal.any([controller.signal, AbortSignal.timeout(120_000)])
    const type = copy ? 'png' : format
    const title = store.getDocument().title
    const output = build(type, signal)
    void output.catch(() => {})
    // ClipboardItem accepts a promise, preserving the initiating user gesture while artwork loads.
    const complete = copy
      ? () => {
          if (!navigator.clipboard?.write || typeof ClipboardItem === 'undefined')
            throw new Error('Image clipboard is unavailable in this browser. Download PNG instead.')
          return navigator.clipboard.write([new ClipboardItem({ 'image/png': output })])
        }
      : async () => {
          const blob = await output
          signal.throwIfAborted()
          const url = URL.createObjectURL(blob),
            anchor = document.createElement('a')
          anchor.href = url
          anchor.download = `${title.replace(/[^\p{L}\p{N} _-]/gu, '').slice(0, 80) || 'whiteboard'}.${type}`
          anchor.click()
          setTimeout(() => URL.revokeObjectURL(url), 1000)
        }
    void Promise.resolve()
      .then(complete)
      .then(() => {
        if (mounted.current) setStatus(copy ? 'Image copied' : 'Export downloaded')
      })
      .catch((reason: unknown) => {
        const failure = controller.signal.aborted ? controller.signal.reason : reason
        if (mounted.current && !(failure instanceof DOMException && failure.name === 'AbortError'))
          setError(failure instanceof Error ? failure.message : String(failure))
      })
      .finally(() => {
        controller.abort()
        // A rejected clipboard request can finish before its image promise.
        void output.catch(() => {})
        if (active.current === controller) active.current = null
        if (mounted.current) {
          setBusy(false)
          setBatch(null)
        }
      })
  }

  return (
    <>
      <section
        className="wb-reference wb-file-dialog wb-export-dialog"
        role="dialog"
        aria-label="Export image"
        data-wb-ui
        onKeyDown={event => {
          event.stopPropagation()
          if (event.key === 'Escape') {
            event.preventDefault()
            close()
          }
        }}
      >
        <h2>
          <BoardIconLabel name="exportImage">Export image</BoardIconLabel>
        </h2>
        <fieldset disabled={busy}>
          <label>
            <BoardIconLabel name="layers">Content</BoardIconLabel>
            <select
              aria-label="Export content"
              value={selection ? 'selection' : 'all'}
              onChange={event => setSelection(event.target.value === 'selection')}
            >
              <option value="all">Whole board</option>
              <option value="selection" disabled={!store.getSnapshot().selected.size}>
                Selection
              </option>
            </select>
          </label>
          <label>
            <BoardIconLabel name="image">Format</BoardIconLabel>
            <select
              aria-label="Export format"
              value={format}
              onChange={event => setFormat(event.target.value as 'svg' | 'png')}
            >
              <option value="png">PNG</option>
              <option value="svg">SVG</option>
            </select>
          </label>
          <label>
            <BoardIconLabel name="autoSize">PNG scale</BoardIconLabel>
            <select
              aria-label="PNG scale"
              value={scale}
              onChange={event => setScale(Number(event.target.value))}
            >
              <option value="1">1×</option>
              <option value="2">2×</option>
              <option value="4">4×</option>
            </select>
          </label>
          <label>
            <input
              type="checkbox"
              checked={background}
              onChange={event => setBackground(event.target.checked)}
            />{' '}
            <BoardIconLabel name="fill">Include background</BoardIconLabel>
          </label>
        </fieldset>
        {error && <p role="alert">{error}</p>}
        <p role="status">
          {status || 'Hidden elements are excluded. Card contents use their saved size.'}
        </p>
        <footer>
          <button onClick={close}>
            <BoardIconLabel name="close">{busy ? 'Cancel' : 'Close'}</BoardIconLabel>
          </button>
          <button disabled={busy} onClick={() => start(true)}>
            <BoardIconLabel name="copy">Copy PNG</BoardIconLabel>
          </button>
          <button ref={button} disabled={busy} onClick={() => start(false)}>
            <BoardIconLabel name="exportImage">Download</BoardIconLabel>
          </button>
        </footer>
      </section>
      {batch && <ExportBatch key={batch.key} batch={batch} theme={theme} typography={typography} />}
    </>
  )
}
