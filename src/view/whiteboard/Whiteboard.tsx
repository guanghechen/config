import React from 'react'
import { useSelectionStyle } from './ui/inspector/useSelectionStyle'
import { useNodeEditor } from './ui/editors/useNodeEditor'
import { NodeEditors } from './ui/editors/NodeEditors'
import { readDraft } from './io/drafts'
import { useDocumentFile } from './io/useDocumentFile'
import { BoardHostContext, EMPTY_HOST, useBoardHost } from './HostContext'
import type { IWhiteboardProps } from './contracts'
import { DEFAULT_WHITEBOARD_THEME } from './theme'
import type { IWhiteboardTheme } from './theme'
import { DrawingScene } from './rendering/DrawingElement'
import { Minimap } from './ui/panels/Minimap'
import { PresentationBar } from './ui/panels/PresentationBar'
import { AreaPanel } from './ui/panels/AreaPanel'
import { LaserPointer } from './ui/panels/LaserPointer'
import type { ILaserPointer } from './ui/panels/LaserPointer'
import { cameraForBounds } from '@/shared/whiteboard/navigation'
import { BoardExportDialog } from './io/export/BoardExportDialog'
import { parseDocument } from '@/shared/whiteboard/document'
import { elementBounds, intersects, unionBounds, worldPoint } from '@/shared/whiteboard/geometry'

import { orderedDocument } from '@/shared/whiteboard/stacking'
import type { ICamera, INode, IPoint, IRegion } from '@/shared/whiteboard/model'

import { useBoardInteraction } from './interaction/useBoardInteraction'
import { BOARD_DIALOG_SELECTOR } from './interaction/targets'
import { createNode } from './interaction/createNode'
import type { ITool } from './interaction/tools'
import { BoardIcon, BoardIconLabel } from './ui/BoardIcon'
import { MarkdownCard } from './rendering/MarkdownCard'

import { useBoardRenderer } from './rendering/useBoardRenderer'
import { MarkdownResources } from './io/resources'
import { BoardStore } from './store'
import { BoardToolbar } from './ui/toolbar/BoardToolbar'
import { Inspector } from './ui/inspector/Inspector'
import { BoardNavigation } from './ui/toolbar/BoardNavigation'
import { useImageImport } from './io/useImageImport'
import { BoardTypography } from './rendering/typography'
import { ElementList } from './ui/panels/ElementList'
import { BoardContextMenu } from './ui/panels/BoardContextMenu'

import './style.css'

export const Whiteboard: React.FC<IWhiteboardProps> = ({
  host = EMPTY_HOST,
  theme = DEFAULT_WHITEBOARD_THEME,
  ...props
}) => (
  <BoardHostContext.Provider value={host}>
    <BoardContent key={props.filepath ?? 'scratch'} {...props} theme={theme} />
  </BoardHostContext.Provider>
)

const BoardContent: React.FC<
  Pick<IWhiteboardProps, 'filepath' | 'initialDocument' | 'style'> & { theme: IWhiteboardTheme }
> = ({ filepath, initialDocument, theme, style: containerStyle }) => {
  const host = useBoardHost()
  const { files, drafts, FilePicker } = host
  const [typography] = React.useState(() => new BoardTypography())
  const [initial] = React.useState(() => {
    const value = initialDocument
      ? { document: initialDocument, revision: undefined, error: undefined, recovered: false }
      : readDraft(drafts, filepath)
    return { ...value, document: typography.normalize(orderedDocument(value.document)) }
  })
  const [store] = React.useState(() => new BoardStore(initial.document, typography.normalize))
  const [resources] = React.useState(() => new MarkdownResources(files))
  const snapshot = React.useSyncExternalStore(store.subscribe, store.getSnapshot)
  const stage = React.useRef<HTMLDivElement>(null)
  const fileInput = React.useRef<HTMLInputElement>(null)
  const imageInput = React.useRef<HTMLInputElement>(null)
  const [size, setSize] = React.useState({ width: 1, height: 1 })
  const compactToolbar = size.width < 1000
  const [reading, setReading] = React.useState(false)
  const [presenting, setPresenting] = React.useState<number | null>(null)
  const readOnly = reading || presenting !== null
  const laser = React.useRef<ILaserPointer>(null)
  const pointLaser = React.useCallback((point: IPoint) => laser.current?.point(point), [])
  const presentationStart = React.useRef<{ camera: ICamera; tool: ITool } | null>(null)
  const readingTool = React.useRef<ITool>('select')
  const [showNavigation, setShowNavigation] = React.useState(false)
  const closeNavigation = React.useCallback(() => setShowNavigation(false), [])
  const [tool, setTool] = React.useState<ITool>('select')
  const [locked, setLocked] = React.useState(false)
  const toggleLock = React.useCallback(() => setLocked(value => !value), [])
  const selectTool = React.useCallback(() => setTool('select'), [])
  const chooseTool = React.useCallback(
    (next: ITool): void => {
      if (readOnly && !['select', 'hand', 'laser'].includes(next)) return
      if (next === 'image') imageInput.current?.click()
      else setTool(next)
    },
    [readOnly],
  )
  const {
    style,
    edgeAppearance,
    updateStyle,
    updateTypography,
    updateAutoSize,
    updateEdgeAppearance,
  } = useSelectionStyle(store)
  const [message, setMessage] = React.useState(initial.error ?? '')
  const [status, setStatus] = React.useState(
    initial.recovered ? 'Draft restored' : 'Local whiteboard',
  )
  const focusCanvas = React.useCallback(() => stage.current?.focus(), [])
  const nodeEditor = useNodeEditor(store, readOnly, setMessage, focusCanvas)
  const { editor, labelEditor, editGeneration, edit } = nodeEditor
  const [reference, setReference] = React.useState<string | null>(null)
  const [saveAs, setSaveAs] = React.useState(false)
  const [exportImage, setExportImage] = React.useState(false)
  const [showElements, setShowElements] = React.useState(false)
  const closeElements = React.useCallback(() => setShowElements(false), [])
  const importGeneration = React.useRef(0)
  const importImages = useImageImport(store, style, setMessage, selectTool, readOnly)

  React.useEffect(() => resources.start(), [resources])
  React.useEffect(
    () => () => {
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
        ? current.document.elements.filter(
            item => current.selected.has(item.id) && !current.hidden.has(item.id),
          )
        : current.document.elements.filter(item => !current.hidden.has(item.id))
      const bounds = unionBounds(elements.map(item => elementBounds(item, map)))
      if (!bounds) {
        if (current.document.elements.length) return
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

  const focusElement = React.useCallback(
    (id: string): void => {
      store.select(new Set([id]))
      fit(true)
    },
    [store, fit],
  )

  const {
    cancelInteraction,
    contextMenu,
    closeContextMenu,
    copyToClipboard,
    pasteFromClipboard,
    marquee,
    guides,
    rotationPreview,
    isInteracting,
    ...events
  } = useBoardInteraction(
    stage,
    store,
    tool,
    style,
    chooseTool,
    node => {
      void edit(node)
    },
    setMessage,
    locked,
    toggleLock,
    importImages,
    edgeAppearance,
    typography,
    readOnly,
    pointLaser,
  )
  const isFileBusy = React.useCallback(() => {
    const root = stage.current?.parentElement
    const focused = document.activeElement
    return (
      isInteracting() ||
      !!root?.querySelector(`${BOARD_DIALOG_SELECTOR},.wb-context-menu`) ||
      !!(
        focused &&
        root?.contains(focused) &&
        focused.closest('[data-wb-ui]') &&
        focused.matches('input,textarea,select,[contenteditable="true"]')
      )
    )
  }, [isInteracting])
  const { loading, saving, sourceUpdate, canSave, saveFile, reloadFile, saveAsFile } =
    useDocumentFile({
      filepath,
      store,
      typography,
      recovered: initial.recovered,
      initialRevision: initial.revision,
      isBusy: isFileBusy,
      onMessage: setMessage,
      onStatus: setStatus,
      fit,
      getGeneration: () => importGeneration.current,
      nextGeneration: () => ++importGeneration.current,
    })
  const focusArea = React.useCallback(
    (region: IRegion): void => {
      store.camera(cameraForBounds(region, size.width, size.height))
    },
    [store, size],
  )
  const areas = snapshot.document.regions ?? []
  const steps = snapshot.document.presentation ?? areas.map(region => region.id)
  const currentStep =
    presenting === null ? null : Math.max(0, Math.min(presenting, steps.length - 1))
  const currentArea =
    currentStep === null ? undefined : areas.find(region => region.id === steps[currentStep])
  const modeBusy =
    !!editor ||
    !!labelEditor ||
    reference !== null ||
    saveAs ||
    exportImage ||
    loading ||
    saving ||
    isInteracting()
  const startPresentation = (): void => {
    if (!steps.length || modeBusy) return
    editGeneration.current++
    cancelInteraction()
    laser.current?.clear()
    presentationStart.current = { camera: store.getSnapshot().camera, tool }
    setTool('hand')
    setPresenting(0)
    stage.current?.focus({ preventScroll: true })
  }
  const stopPresentation = (): void => {
    cancelInteraction()
    laser.current?.clear()
    setPresenting(null)
    if (presentationStart.current) {
      store.camera(presentationStart.current.camera)
      setTool(presentationStart.current.tool)
    }
    presentationStart.current = null
  }
  const toggleReading = (): void => {
    if (modeBusy) return
    editGeneration.current++
    cancelInteraction()
    laser.current?.clear()
    if (!reading) {
      readingTool.current = tool
      setTool('hand')
    } else setTool(readingTool.current)
    setReading(!reading)
  }
  const { drawing, overlay, visible, visibleElements, gridSpacing } = useBoardRenderer({
    snapshot,
    theme,
    typography,
    size,
    readOnly,
    marquee,
    guides,
    rotationPreview,
  })
  React.useEffect(() => () => typography.dispose(), [typography])
  const selected = snapshot.document.elements.filter(item => snapshot.selected.has(item.id))
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

  return (
    <div
      className="wb"
      data-whiteboard
      data-compact={compactToolbar}
      data-reading={readOnly}
      data-element-count={snapshot.document.elements.length}
      style={
        {
          ...DEFAULT_WHITEBOARD_THEME.tokens,
          ...theme.tokens,
          '--wb-canvas': theme.canvas,
          '--wb-paper': theme.paper,
          '--wb-ink': theme.ink,
          '--wb-muted': theme.muted,
          '--wb-control-border': theme.border,
          '--wb-focus': theme.selection,
          '--wb-on-accent': theme.onAccent,
          '--wb-selected-ink': theme.activeInk,
          '--wb-readable-link': theme.colors['theme:accent'],
          ...containerStyle,
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
          backgroundPosition: `${snapshot.camera.x}px ${snapshot.camera.y}px`,
          backgroundSize: `${gridSpacing}px ${gridSpacing}px`,
        }}
      >
        <canvas
          ref={drawing}
          className="wb-drawing"
          style={{ display: snapshot.camera.zoom < 0.35 ? undefined : 'none' }}
        />
        <div
          className="wb-world"
          style={{
            transform: `translate(${snapshot.camera.x}px,${snapshot.camera.y}px) scale(${snapshot.camera.zoom})`,
          }}
        >
          {showNavigation &&
            presenting === null &&
            areas
              .filter(area => intersects(area, visible))
              .map(area => (
                <div
                  key={area.id}
                  className="wb-area-frame"
                  style={{ left: area.x, top: area.y, width: area.width, height: area.height }}
                >
                  <span>{area.name}</span>
                </div>
              ))}
          <DrawingScene
            elements={snapshot.document.elements}
            visible={visibleElements}
            theme={theme}
            typography={typography}
            card={node => (
              <MarkdownCard key={node.id} node={node} resources={resources} theme={theme} />
            )}
          />
        </div>
        <canvas ref={overlay} className="wb-overlay" />
        <LaserPointer ref={laser} size={size} />
      </div>
      {presenting === null && (
        <BoardToolbar
          snapshot={snapshot}
          store={store}
          tool={tool}
          locked={locked}
          readOnly={readOnly}
          reading={reading}
          modeBusy={modeBusy}
          width={size.width}
          showElements={showElements}
          showNavigation={showNavigation}
          onToggleElements={() => {
            setShowElements(value => !value)
            setShowNavigation(false)
          }}
          onToggleNavigation={() => {
            setShowNavigation(value => !value)
            setShowElements(false)
          }}
          toggleReading={toggleReading}
          chooseTool={chooseTool}
          setTool={setTool}
          toggleLock={toggleLock}
          onImport={() => fileInput.current?.click()}
          download={download}
          onExportImage={() => setExportImage(true)}
          onSaveAs={() => setSaveAs(true)}
          onAddImages={() => imageInput.current?.click()}
          onReference={() => setReference('')}
          filepath={filepath}
          saving={saving}
          loading={loading}
          canSave={canSave}
          saveFile={saveFile}
          reloadFile={reloadFile}
        />
      )}
      {presenting !== null && (
        <PresentationBar
          currentStep={currentStep}
          currentArea={currentArea}
          stepCount={steps.length}
          tool={tool}
          setTool={setTool}
          setPresenting={setPresenting}
          stopPresentation={stopPresentation}
          focusArea={focusArea}
        />
      )}
      {!readOnly &&
        (selected.length > 0 || !['select', 'hand', 'eraser', 'laser'].includes(tool)) && (
          <Inspector
            theme={theme}
            snapshot={snapshot}
            store={store}
            tool={tool}
            style={style}
            edgeAppearance={edgeAppearance}
            busy={isInteracting()}
            updateStyle={updateStyle}
            updateTypography={updateTypography}
            updateAutoSize={updateAutoSize}
            updateEdgeAppearance={updateEdgeAppearance}
            edit={edit}
          />
        )}
      {exportImage && (
        <BoardExportDialog
          store={store}
          typography={typography}
          theme={theme}
          onClose={() => setExportImage(false)}
        />
      )}
      {presenting === null && showElements && (
        <ElementList
          snapshot={snapshot}
          store={store}
          busy={isInteracting()}
          editable={!readOnly}
          resources={resources}
          onClose={closeElements}
          onFocus={focusElement}
        />
      )}
      {presenting === null && showNavigation && (
        <AreaPanel
          document={snapshot.document}
          selected={snapshot.selected}
          store={store}
          size={size}
          readOnly={readOnly || modeBusy}
          busy={modeBusy}
          onFocus={focusArea}
          onPresent={startPresentation}
          onClose={closeNavigation}
        />
      )}
      {presenting === null &&
        !showElements &&
        (snapshot.document.elements.length > 0 || areas.length > 0) && (
          <Minimap snapshot={snapshot} store={store} size={size} theme={theme} />
        )}
      {contextMenu && (
        <BoardContextMenu
          viewport={size}
          position={contextMenu}
          selected={selected}
          store={store}
          close={closeContextMenu}
          copy={copyToClipboard}
          paste={pasteFromClipboard}
          edit={node => {
            void edit(node)
          }}
        />
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
      {presenting === null && (
        <BoardNavigation
          readOnly={readOnly}
          store={store}
          zoomPercent={Math.round(snapshot.camera.zoom * 100)}
          size={size}
          selectedCount={selected.length}
          nodeCount={snapshot.document.elements.filter(item => item.type !== 'edge').length}
          status={status}
          fit={fit}
        />
      )}
      {message && (
        <div className="wb-notice" role="alert" data-wb-ui>
          <span>{message}</span>
          <button aria-label="Dismiss message" onClick={() => setMessage('')}>
            <BoardIcon name="close" />
          </button>
        </div>
      )}
      {sourceUpdate && (
        <aside className="wb-source-update" role="alert" data-wb-ui>
          <p>
            {'error' in sourceUpdate
              ? sourceUpdate.error
              : `Source file changed: ${sourceUpdate.title} (${sourceUpdate.count} elements). Local work is preserved.`}
          </p>
          <div>
            <button onClick={download}>
              <BoardIconLabel name="exportBoard">Export local board</BoardIconLabel>
            </button>
            <button
              disabled={
                loading || saving || !!editor || !!labelEditor || reference !== null || saveAs
              }
              onClick={() => void reloadFile()}
            >
              <BoardIconLabel name="reload">Reload source file</BoardIconLabel>
            </button>
          </div>
        </aside>
      )}
      {loading && (
        <div className="wb-loading" role="status">
          Loading whiteboard…
        </div>
      )}
      <NodeEditors session={nodeEditor} resources={resources} snapshot={snapshot} size={size} />
      {reference !== null && FilePicker && (
        <FilePicker
          mode="reference"
          title={snapshot.document.title}
          directory={filepath?.slice(0, filepath.lastIndexOf('/')) || undefined}
          onClose={() => setReference(null)}
          onChoose={sourcePath => {
            const point = worldPoint(
              { x: size.width / 2 - 180, y: size.height / 2 - 130 },
              snapshot.camera,
            )
            const node: INode = {
              ...createNode('markdown', point, style),
              type: 'markdown',
              source: { kind: 'file', filepath: sourcePath },
            }
            store.commit({ ...snapshot.document, elements: [...snapshot.document.elements, node] })
            store.select(new Set([node.id]))
            setReference(null)
          }}
        />
      )}
      {saveAs && FilePicker && (
        <FilePicker
          mode="save"
          title={snapshot.document.title}
          directory={filepath?.slice(0, filepath.lastIndexOf('/')) || undefined}
          onClose={() => setSaveAs(false)}
          onChoose={saveAsFile}
        />
      )}
      <input
        ref={imageInput}
        hidden
        type="file"
        aria-label="Import images"
        accept="image/png,image/jpeg,image/webp,image/gif"
        multiple
        onChange={event => {
          const input = event.target
          const files = Array.from(input.files ?? [])
          input.value = ''
          importImages(
            files,
            worldPoint({ x: size.width / 2, y: size.height / 2 }, store.getSnapshot().camera),
          )
        }}
      />
      <input
        ref={fileInput}
        hidden
        type="file"
        aria-label="Import whiteboard"
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
