import React from 'react'
import { DrawingScene } from './DrawingElement'
import { Minimap } from './Minimap'
import { AreaPanel } from './AreaPanel'
import { LaserPointer } from './LaserPointer'
import type { ILaserPointer } from './LaserPointer'
import { cameraForBounds } from '@/shared/whiteboard/navigation'
import { BoardExportDialog } from './BoardExportDialog'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { useSearchParams } from 'react-router-dom'
import { MarkdownTopProvider } from '@/container/markdown/context/top/Provider'
import { LoginModal } from '@/container/LoginModal'
import { useSiteViewmodel } from '@/context/site'
import { useMermaidSyncThemeEffect } from '@/hook/useMermaidSyncThemeEffect'
import {
  createWhiteboardFile,
  loadReferencedText,
  saveReferencedText,
} from '@/shared/api/whiteboard'
import { parseDocument } from '@/shared/whiteboard/document'
import {
  elementBounds,
  intersects,
  labelArea,
  unionBounds,
  worldPoint,
} from '@/shared/whiteboard/geometry'
import { DEFAULT_EDGE_APPEARANCE, DEFAULT_STYLE, createDocument } from '@/shared/whiteboard/model'
import { orderedDocument, stackingDirections } from '@/shared/whiteboard/stacking'
import type {
  ICamera,
  IEdgeAppearance,
  IElement,
  ILabelElement,
  INode,
  IPoint,
  IRegion,
  IStyle,
  IWhiteboardDocument,
} from '@/shared/whiteboard/model'
import type { IEditSession } from './InlineEditor'
import { BOARD_DIALOG_SELECTOR, createNode, useBoardInteraction } from './interaction'
import type { ITool } from './tools'
import { BoardIcon, BoardIconLabel } from './BoardIcon'
import { MarkdownCard } from './MarkdownCard'
import { LabelEditor } from './LabelEditor'
import { MarkdownCode } from './MarkdownCode'
import { CanvasRenderer, visibleBounds } from './renderer'
import { MarkdownResources } from './resources'
import { BoardStore } from './store'
import { DrawingTools } from './DrawingTools'
import { BoardNavigation } from './BoardNavigation'
import { SelectionActions } from './SelectionActions'
import { StyleControls } from './StyleControls'
import { useWhiteboardTheme } from './theme'
import { BoardAppearance } from './BoardAppearance'
import { useImageImport } from './useImageImport'
import { WorkspaceFileDialog } from './WorkspaceFileDialog'
import { ConnectorControls } from './ConnectorControls'
import { BoardTypography } from './typography'
import { TypographyControls } from './TypographyControls'
import { TransformControls } from './TransformControls'
import { ElementList } from './ElementList'
import { BoardContextMenu } from './BoardContextMenu'
import { hasText } from '@/shared/whiteboard/text'
import type { ITextStyle } from '@/shared/whiteboard/text'
import { nodeBounds } from '@/shared/whiteboard/pose'
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
  const [typography] = React.useState(() => new BoardTypography())
  const [initial] = React.useState(() => {
    const value = initialDocument
      ? { document: initialDocument, revision: undefined, error: undefined, recovered: false }
      : readDraft(draftKey)
    return { ...value, document: typography.normalize(orderedDocument(value.document)) }
  })
  const [store] = React.useState(() => new BoardStore(initial.document, typography.normalize))
  const [resources] = React.useState(() => new MarkdownResources())
  const [renderer] = React.useState(() => new CanvasRenderer(theme, typography))
  const snapshot = React.useSyncExternalStore(store.subscribe, store.getSnapshot)
  const stage = React.useRef<HTMLDivElement>(null)
  const drawing = React.useRef<HTMLCanvasElement>(null)
  const overlay = React.useRef<HTMLCanvasElement>(null)
  const fileInput = React.useRef<HTMLInputElement>(null)
  const imageInput = React.useRef<HTMLInputElement>(null)
  const [size, setSize] = React.useState({ width: 1, height: 1 })
  const compactToolbar = size.width < 1000
  const topbar = React.useRef<HTMLElement>(null)
  const toolbarMenuName = React.useId()
  React.useEffect(() => {
    const closeMenus = (event: PointerEvent): void => {
      const header = topbar.current
      if (!header || (event.target instanceof Node && header.contains(event.target))) return
      for (const menu of header.querySelectorAll<HTMLDetailsElement>('details[open]'))
        menu.open = false
    }
    document.addEventListener('pointerdown', closeMenus, true)
    return () => document.removeEventListener('pointerdown', closeMenus, true)
  }, [])
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
  const [style, setStyle] = React.useState<IStyle>(DEFAULT_STYLE)
  const [edgeAppearance, setEdgeAppearance] =
    React.useState<IEdgeAppearance>(DEFAULT_EDGE_APPEARANCE)
  const [message, setMessage] = React.useState(initial.error ?? '')
  const [status, setStatus] = React.useState(
    initial.recovered ? 'Draft restored' : 'Local whiteboard',
  )
  const [loading, setLoading] = React.useState(!!filepath)
  const [saving, setSaving] = React.useState(false)
  const [editor, setEditor] = React.useState<IEditSession | null>(null)
  const [labelEditor, setLabelEditor] = React.useState<ILabelElement | null>(null)
  const [reference, setReference] = React.useState<string | null>(null)
  const [saveAs, setSaveAs] = React.useState(false)
  const [exportImage, setExportImage] = React.useState(false)
  const [showElements, setShowElements] = React.useState(false)
  const closeElements = React.useCallback(() => setShowElements(false), [])
  const [sourceUpdate, setSourceUpdate] = React.useState<
    { revision: string; title: string; count: number } | { error: string } | null
  >(null)
  const revision = React.useRef(initial.revision)
  const canonicalFilepath = React.useRef(filepath)
  const fileSavedDocument = React.useRef<IWhiteboardDocument | null>(null)
  const createdFileDocument = React.useRef<IWhiteboardDocument | null>(null)
  const editGeneration = React.useRef(0)
  const importGeneration = React.useRef(0)
  const importImages = useImageImport(store, style, setMessage, selectTool, readOnly)

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

  React.useEffect(() => {
    if (!filepath) return
    const controller = new AbortController()
    void loadReferencedText(filepath, undefined, controller.signal)
      .then(data => {
        if (!data || controller.signal.aborted) return
        const document = typography.normalize(orderedDocument(parseDocument(data.content)))
        canonicalFilepath.current = data.filepath
        fileSavedDocument.current = document
        if (initial.recovered) {
          if (JSON.stringify(store.getDocument()) === JSON.stringify(document)) {
            fileSavedDocument.current = store.getDocument()
            revision.current = data.revision
          } else if (revision.current !== data.revision) {
            setSourceUpdate({
              revision: data.revision,
              title: document.title,
              count: document.elements.length,
            })
          } else {
            setMessage(
              'Recovered local draft. Saving checks the file version from when the draft was created.',
            )
          }
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
  }, [filepath, initial.recovered, store, typography])

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
      if (
        failed &&
        store.getDocument() !== fileSavedDocument.current &&
        store.getDocument() !== createdFileDocument.current
      )
        event.preventDefault()
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
      if (readOnly || store.getSnapshot().locked.has(node.id)) return
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
        const bounds = nodeBounds(node)
        setEditor({
          node,
          content,
          filepath: sourceFile,
          revision: sourceRevision,
          left: bounds.x * camera.zoom + camera.x,
          top: bounds.y * camera.zoom + camera.y,
        })
      } catch (error) {
        if (generation === editGeneration.current)
          setMessage(error instanceof Error ? error.message : String(error))
      }
    },
    [store, editor, labelEditor, readOnly],
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
  React.useEffect(() => {
    if (presenting !== null && currentArea) focusArea(currentArea)
  }, [presenting, currentArea, focusArea])
  React.useEffect(() => {
    if (presenting === null) return
    const keydown = (event: KeyboardEvent): void => {
      if (
        event.ctrlKey ||
        event.metaKey ||
        event.altKey ||
        window.document.querySelector(BOARD_DIALOG_SELECTOR) ||
        (event.target instanceof Element &&
          event.target.closest('input,textarea,select,[contenteditable="true"]'))
      )
        return
      const key = event.key
      if (
        ![
          'Escape',
          'ArrowRight',
          'ArrowDown',
          'PageDown',
          ' ',
          'ArrowLeft',
          'ArrowUp',
          'PageUp',
          'Home',
          'End',
        ].includes(key)
      )
        return
      event.preventDefault()
      event.stopImmediatePropagation()
      if (key === 'Escape') stopPresentation()
      else if (key === 'Home') setPresenting(0)
      else if (key === 'End') setPresenting(Math.max(0, steps.length - 1))
      else
        setPresenting(
          Math.max(
            0,
            Math.min(
              steps.length - 1,
              (currentStep ?? 0) + (['ArrowLeft', 'ArrowUp', 'PageUp'].includes(key) ? -1 : 1),
            ),
          ),
        )
    }
    window.addEventListener('keydown', keydown, true)
    return () => window.removeEventListener('keydown', keydown, true)
  })
  React.useEffect(() => {
    if (!filepath || loading || saving) return
    let controller: AbortController | undefined
    const refresh = (force = false): void => {
      if (!revision.current) return
      if (controller && !force) return
      controller?.abort()
      const request = new AbortController()
      controller = request
      const expectedRevision = revision.current
      void loadReferencedText(
        canonicalFilepath.current ?? filepath,
        expectedRevision,
        request.signal,
      )
        .then(data => {
          if (request.signal.aborted || revision.current !== expectedRevision) return
          if (!data) {
            setSourceUpdate(current => (current && 'error' in current ? null : current))
            return
          }
          const document = typography.normalize(orderedDocument(parseDocument(data.content)))
          canonicalFilepath.current = data.filepath
          const current = store.getDocument()
          const focused = window.document.activeElement
          const busy =
            isInteracting() ||
            !!window.document.querySelector(`${BOARD_DIALOG_SELECTOR},.wb-context-menu`) ||
            !!(
              focused?.closest('[data-wb-ui]') &&
              focused.matches('input,textarea,select,[contenteditable="true"]')
            )
          if (
            !busy &&
            current === fileSavedDocument.current &&
            store.getSnapshot().document === current
          ) {
            revision.current = data.revision
            fileSavedDocument.current = document
            store.replace(document)
            setSourceUpdate(null)
            setStatus('Updated from source file')
          } else {
            setSourceUpdate(previous =>
              previous && 'revision' in previous && previous.revision === data.revision
                ? previous
                : {
                    revision: data.revision,
                    title: document.title,
                    count: document.elements.length,
                  },
            )
          }
        })
        .catch((error: unknown) => {
          if (!request.signal.aborted && revision.current === expectedRevision)
            setSourceUpdate({
              error: `Unable to refresh source: ${error instanceof Error ? error.message : String(error)}`,
            })
        })
        .finally(() => {
          if (controller === request) controller = undefined
        })
    }
    const focus = (): void => refresh(true)
    const changed = (event: { filepath: string }): void => {
      if (event.filepath === filepath || event.filepath === canonicalFilepath.current) refresh(true)
    }
    const timer = setInterval(refresh, 2500)
    window.addEventListener('focus', focus)
    import.meta.hot?.on('guanghechen/file-changed', changed)
    refresh()
    return () => {
      clearInterval(timer)
      controller?.abort()
      window.removeEventListener('focus', focus)
      import.meta.hot?.off('guanghechen/file-changed', changed)
    }
  }, [filepath, loading, saving, store, isInteracting, typography])
  React.useLayoutEffect(() => {
    if (!drawing.current || !overlay.current) return
    renderer.setTheme(theme)
    if (snapshot.camera.zoom < 0.35)
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
      readOnly ? new Set() : snapshot.selected,
      size.width,
      size.height,
      marquee,
      guides,
      rotationPreview,
    )
  }, [renderer, snapshot, size, marquee, guides, rotationPreview, theme, readOnly])
  React.useEffect(() => {
    const timer = setTimeout(() => {
      if (!drawing.current || snapshot.camera.zoom >= 0.35) return
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
  React.useEffect(() => () => typography.dispose(), [typography])
  const visible = visibleBounds(snapshot.camera, size.width, size.height)
  // Keep the grid 16–32 screen pixels apart; dense overview dots otherwise dominate raster work.
  const gridSpacing =
    24 * snapshot.camera.zoom * 2 ** Math.ceil(Math.log2(16 / (24 * snapshot.camera.zoom)))
  const elementMap = new Map(snapshot.document.elements.map(element => [element.id, element]))
  const visibleElements =
    snapshot.camera.zoom < 0.35
      ? []
      : snapshot.document.elements.filter(
          item =>
            !snapshot.hidden.has(item.id) && intersects(elementBounds(item, elementMap), visible),
        )
  const selected = snapshot.document.elements.filter(item => snapshot.selected.has(item.id))
  const selectionLocked = selected.some(element => snapshot.locked.has(element.id))
  const textSelection = selected.find(hasText)
  const autoSelection = selected.filter(
    element => element.type === 'shape' || element.type === 'text',
  )
  const stacking = React.useMemo(
    () => stackingDirections(snapshot.document.elements, snapshot.selected),
    [snapshot.document.elements, snapshot.selected],
  )
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
  const updateTypography = React.useCallback(
    (patch: ITextStyle): void => {
      setStyle(current => ({ ...current, ...patch }))
      const current = store.getSnapshot()
      store.commit({
        ...current.document,
        elements: current.document.elements.map(element =>
          current.selected.has(element.id) && hasText(element)
            ? { ...element, style: { ...element.style, ...patch } }
            : element,
        ),
      })
    },
    [store],
  )
  const updateAutoSize = React.useCallback(
    (automatic: boolean): void => {
      const current = store.getSnapshot()
      store.commit({
        ...current.document,
        elements: current.document.elements.map(element =>
          current.selected.has(element.id) && (element.type === 'text' || element.type === 'shape')
            ? { ...element, autoSize: automatic }
            : element,
        ),
      })
    },
    [store],
  )
  const updateEdgeAppearance = React.useCallback(
    (patch: IEdgeAppearance): void => {
      setEdgeAppearance(current => ({ ...current, ...patch }))
      const current = store.getSnapshot()
      if (current.selected.size)
        store.commit({
          ...current.document,
          elements: current.document.elements.map(element => {
            if (element.type !== 'edge' || !current.selected.has(element.id)) return element
            const { controls, ...base } = element
            return {
              ...base,
              ...patch,
              ...((patch.routing === undefined ||
                patch.routing === (element.routing ?? 'straight')) &&
              controls
                ? { controls }
                : {}),
            }
          }),
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
      fileSavedDocument.current = document
      setSourceUpdate(null)
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
      const document = typography.normalize(orderedDocument(parseDocument(data.content)))
      revision.current = data.revision
      canonicalFilepath.current = data.filepath
      fileSavedDocument.current = document
      store.replace(document)
      setSourceUpdate(null)
      setMessage('')
      fit()
    } catch (error) {
      if (generation === importGeneration.current)
        setMessage(error instanceof Error ? error.message : String(error))
    } finally {
      if (generation === importGeneration.current) setLoading(false)
    }
  }

  const viewControls = (
    <>
      <button
        aria-label="Elements"
        aria-pressed={showElements}
        title="Elements and search"
        onClick={() => {
          setShowElements(value => !value)
          setShowNavigation(false)
        }}
      >
        <BoardIcon name="layers" />
        <span>Elements</span>
      </button>
      <button
        aria-label="Navigate"
        title="Navigate"
        aria-pressed={showNavigation}
        onClick={() => {
          setShowNavigation(value => !value)
          setShowElements(false)
        }}
      >
        <BoardIcon name="navigate" />
        <span>Navigate</span>
      </button>
      <button
        aria-label={reading ? 'Exit reading mode' : 'Enter reading mode'}
        title={reading ? 'Exit reading mode' : 'Enter reading mode'}
        aria-pressed={reading}
        disabled={modeBusy}
        onClick={toggleReading}
      >
        <BoardIcon name="read" />
        <span>{reading ? 'Exit reading mode' : 'Reading mode'}</span>
      </button>
      <BoardAppearance />
    </>
  )

  return (
    <div
      className="wb"
      data-whiteboard
      data-compact={compactToolbar}
      data-reading={readOnly}
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
        <header
          ref={topbar}
          className="wb-topbar"
          data-wb-ui
          onKeyDown={event => {
            if (event.key === 'Enter' || event.key === ' ') event.stopPropagation()
            const menu =
              event.target instanceof Element
                ? event.target.closest<HTMLDetailsElement>('details[open]')
                : null
            if (!menu || event.defaultPrevented) return
            event.stopPropagation()
            if (event.key === 'Escape') {
              event.preventDefault()
              menu.open = false
              menu.querySelector('summary')?.focus()
            }
          }}
          onClick={event => {
            if (!(event.target instanceof Element) || event.target.closest('.wb-appearance')) return
            const button = event.target.closest('button,a')
            const menu = button?.closest<HTMLDetailsElement>('details')
            if (menu) {
              menu.open = false
              menu.querySelector('summary')?.focus({ preventScroll: true })
            }
          }}
        >
          <div className="wb-filebar">
            <details className="wb-file-menu" name={toolbarMenuName}>
              <summary aria-label="File menu" title="File menu">
                <BoardIcon name="menu" />
                <span className="wb-board-name" title={snapshot.document.title}>
                  {snapshot.document.title || 'Untitled whiteboard'}
                </span>
              </summary>
              <div>
                <a href="/ws" title="Back to workspace" aria-label="Workspace">
                  <BoardIcon name="home" />
                  <span>Back to workspace</span>
                </a>
                <label className="wb-menu-title">
                  Board name
                  <input
                    aria-label="Whiteboard title"
                    readOnly={readOnly}
                    maxLength={2_000_000}
                    value={snapshot.document.title}
                    onChange={event =>
                      store.commit({ ...snapshot.document, title: event.target.value })
                    }
                  />
                </label>
                <hr />
                <button
                  disabled={readOnly}
                  onClick={() => {
                    if (
                      !snapshot.document.elements.length ||
                      window.confirm(
                        'Start a new whiteboard? Export the current board first to keep a separate copy.',
                      )
                    ) {
                      if (readOnly) return
                      store.replace(createDocument())
                      store.camera({ x: 0, y: 0, zoom: 1 })
                    }
                  }}
                >
                  <BoardIcon name="newBoard" />
                  <span>New whiteboard</span>
                </button>
                <button onClick={() => fileInput.current?.click()}>
                  <BoardIcon name="importBoard" />
                  <span>Import .whiteboard</span>
                </button>
                <button onClick={download}>
                  <BoardIcon name="exportBoard" />
                  <span>Export .whiteboard</span>
                </button>
                <button onClick={() => setExportImage(true)}>
                  <BoardIcon name="exportImage" />
                  <span>Export image…</span>
                </button>
                <button onClick={() => setSaveAs(true)}>
                  <BoardIcon name="saveAs" />
                  <span>Save as in workspace…</span>
                </button>
                {filepath && (
                  <button onClick={() => void saveFile()} disabled={saving || !revision.current}>
                    <BoardIcon name="save" />
                    <span>{saving ? 'Saving…' : 'Save to source file'}</span>
                  </button>
                )}
                {filepath && (
                  <button onClick={() => void reloadFile()} disabled={loading || saving}>
                    <BoardIcon name="reload" />
                    <span>Reload source file</span>
                  </button>
                )}
                <hr />
                <button disabled={readOnly} onClick={() => imageInput.current?.click()}>
                  <BoardIcon name="addImage" />
                  <span>Add images…</span>
                </button>
                <button disabled={readOnly} onClick={() => setTool('image')}>
                  <BoardIcon name="link" />
                  <span>Place image from URL or path</span>
                </button>
                <button disabled={readOnly} onClick={() => setReference('')}>
                  <BoardIcon name="reference" />
                  <span>Reference Markdown file…</span>
                </button>
              </div>
            </details>
          </div>
          {!readOnly && (
            <DrawingTools
              tool={tool}
              setTool={chooseTool}
              locked={locked}
              toggleLock={toggleLock}
              compact={size.width < 680}
              menuName={toolbarMenuName}
            />
          )}
          {reading && (
            <div className="wb-reading-tools" data-wb-ui>
              <span>Reading mode</span>
              <button
                aria-label="Hand"
                aria-pressed={tool === 'hand'}
                onClick={() => setTool('hand')}
              >
                <BoardIcon name="hand" />
              </button>
              <button
                aria-label="Laser pointer"
                aria-pressed={tool === 'laser'}
                onClick={() => setTool('laser')}
              >
                <BoardIcon name="laser" />
              </button>
            </div>
          )}
          <div className="wb-viewbar">
            {compactToolbar ? (
              <details className="wb-view-menu" name={toolbarMenuName}>
                <summary aria-label="View options" title="View options">
                  <BoardIcon name="view" />
                </summary>
                <div className="wb-view-menu-panel">{viewControls}</div>
              </details>
            ) : (
              viewControls
            )}
          </div>
        </header>
      )}
      {presenting !== null && (
        <div className="wb-presentation" data-wb-ui>
          <button
            aria-label="Previous step"
            disabled={!currentStep}
            onClick={() => setPresenting(Math.max(0, (currentStep ?? 0) - 1))}
          >
            <BoardIcon name="previous" />
          </button>
          <span>
            {steps.length
              ? `${(currentStep ?? 0) + 1} / ${steps.length} · ${currentArea?.name ?? ''}`
              : 'No presentation steps'}
          </span>
          <button
            aria-label="Next step"
            disabled={(currentStep ?? 0) >= steps.length - 1}
            onClick={() => setPresenting(Math.min(steps.length - 1, (currentStep ?? 0) + 1))}
          >
            <BoardIcon name="next" />
          </button>
          <button aria-label="Hand" aria-pressed={tool === 'hand'} onClick={() => setTool('hand')}>
            <BoardIcon name="hand" />
          </button>
          <button
            aria-label="Laser pointer"
            aria-pressed={tool === 'laser'}
            onClick={() => setTool('laser')}
          >
            <BoardIcon name="laser" />
          </button>
          <button onClick={stopPresentation}>
            <BoardIconLabel name="stop">Exit presentation</BoardIconLabel>
          </button>
        </div>
      )}

      {!readOnly &&
        (selected.length > 0 || !['select', 'hand', 'eraser', 'laser'].includes(tool)) && (
          <aside
            className="wb-inspector"
            data-wb-ui
            aria-label="Properties"
            onKeyDown={event => event.stopPropagation()}
          >
            <header className="wb-inspector-header">
              <h2>
                <BoardIconLabel name={selected.length ? 'layers' : 'stroke'}>
                  {selected.length ? `${selected.length} selected` : 'Style'}
                </BoardIconLabel>
              </h2>
              {selected.length > 0 && (
                <div className="wb-protection-actions">
                  <button
                    aria-label={selectionLocked ? 'Unlock selection' : 'Lock selection'}
                    title={selectionLocked ? 'Unlock selection' : 'Lock selection'}
                    aria-pressed={selectionLocked}
                    onClick={() => store.setSelectedFlags({ locked: !selectionLocked })}
                  >
                    <BoardIcon name={selectionLocked ? 'unlock' : 'lock'} />
                  </button>
                  <button
                    aria-label={
                      selected.some(element => element.hidden) ? 'Show selection' : 'Hide selection'
                    }
                    title={
                      selected.some(element => element.hidden) ? 'Show selection' : 'Hide selection'
                    }
                    aria-pressed={selected.some(element => element.hidden)}
                    onClick={() =>
                      store.setSelectedFlags({ hidden: !selected.some(element => element.hidden) })
                    }
                  >
                    <BoardIcon
                      name={selected.some(element => element.hidden) ? 'visible' : 'hidden'}
                    />
                  </button>
                </div>
              )}
            </header>
            <div className="wb-inspector-body">
              {selectionLocked && (
                <p className="wb-endpoint-hint">Unlock this selection before editing it.</p>
              )}
              {selected.some(element => snapshot.hidden.has(element.id) && !element.hidden) && (
                <p className="wb-endpoint-hint">
                  Some connections are hidden with their endpoints. Show those nodes in Elements
                  first.
                </p>
              )}
              <fieldset className="wb-properties-fields" disabled={selectionLocked}>
                <StyleControls
                  style={displayStyle}
                  colors={theme.colors}
                  onChange={updateStyle}
                  showLineWidth={
                    selected.length
                      ? selected.some(element => element.type !== 'text')
                      : tool !== 'text'
                  }
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
                {(textSelection ||
                  ['text', 'rectangle', 'ellipse', 'diamond', 'edge'].includes(tool)) && (
                  <TypographyControls
                    key={(textSelection?.type ?? tool) === 'text' ? 'text' : 'label'}
                    value={textSelection?.style ?? style}
                    kind={(textSelection?.type ?? tool) === 'text' ? 'text' : 'label'}
                    disabled={isInteracting()}
                    automatic={
                      autoSelection.length
                        ? autoSelection.every(element => element.autoSize)
                        : undefined
                    }
                    onChange={updateTypography}
                    onAutomatic={updateAutoSize}
                  />
                )}
                {(tool === 'edge' || selected.some(element => element.type === 'edge')) && (
                  <ConnectorControls
                    value={selected.find(element => element.type === 'edge') ?? edgeAppearance}
                    selected={selected}
                    store={store}
                    disabled={isInteracting()}
                    onChange={updateEdgeAppearance}
                  />
                )}
                {selected.length > 0 && (
                  <>
                    <TransformControls
                      selected={selected}
                      store={store}
                      disabled={isInteracting()}
                    />
                    <SelectionActions selected={selected} store={store} stacking={stacking} />
                    {!selectionLocked && !store.canRemoveSelection() && (
                      <p className="wb-endpoint-hint">
                        Unlock connected elements before deleting this selection.
                      </p>
                    )}
                  </>
                )}
              </fieldset>
              {selected.length > 0 && (
                <details className="wb-inspector-help">
                  <summary>
                    <BoardIconLabel name="help">Selection tips</BoardIconLabel>
                  </summary>
                  <p>
                    Drag corner handles to resize; hold Shift to keep proportions. Drag the round
                    handle above the selection to rotate; Shift snaps to 15°.
                  </p>
                  <p>
                    Angled groups resize proportionally; external connections stay attached.
                    Double-click to edit a group member, or ungroup to move it separately.
                  </p>
                  <p>
                    All element types share one layer order, from back to front. Auto size fits text
                    content; resizing a corner switches back to fixed size.
                  </p>
                  {selected.some(element => element.type === 'edge') && (
                    <p>
                      Drag a round endpoint to reconnect; release on empty space to detach. Drag
                      square handles to shape the route. Alt-click a polyline bend to remove it.
                    </p>
                  )}
                </details>
              )}
            </div>
            {selected.length > 0 && (
              <footer className="wb-inspector-footer">
                {selected.length === 1 && selected[0].type !== 'stroke' && (
                  <button
                    className="wb-inspector-edit"
                    disabled={selectionLocked || isInteracting()}
                    title="Edit content (Enter)"
                    onClick={() => void edit(selected[0])}
                  >
                    <BoardIconLabel name="edit">
                      {selected[0].type === 'shape' || selected[0].type === 'edge'
                        ? 'Edit label'
                        : 'Edit content'}
                    </BoardIconLabel>
                  </button>
                )}
                <button
                  aria-label="Duplicate selection"
                  title="Duplicate selection (Ctrl / ⌘ + D)"
                  disabled={isInteracting()}
                  onClick={store.duplicateSelected}
                >
                  <BoardIcon name="duplicate" />
                </button>
                <button
                  className="wb-danger-action"
                  aria-label="Delete selection"
                  title="Delete selection"
                  disabled={!store.canRemoveSelection() || isInteracting()}
                  onClick={store.removeSelected}
                >
                  <BoardIcon name="delete" />
                </button>
              </footer>
            )}
          </aside>
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
        <WorkspaceFileDialog
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
      {saveAs && (
        <WorkspaceFileDialog
          mode="save"
          title={snapshot.document.title}
          directory={filepath?.slice(0, filepath.lastIndexOf('/')) || undefined}
          onClose={() => setSaveAs(false)}
          onChoose={async target => {
            if (localStorage.getItem(`yoz.whiteboard.v1:${target}`))
              throw new Error('A local draft already exists at that path. Choose another filename.')
            const slash = target.lastIndexOf('/')
            const current = store.getDocument()
            const created = await createWhiteboardFile(
              target.slice(0, slash) || '/',
              target.slice(slash + 1),
              JSON.stringify(current, null, 2),
            )
            const key = `yoz.whiteboard.v1:${created.filepath}`
            if (localStorage.getItem(key))
              throw new Error(
                `Created ${created.filepath}; an existing local draft was preserved. Open the file separately to review it.`,
              )
            createdFileDocument.current = current
            if (store.getDocument() !== current) {
              try {
                localStorage.setItem(
                  key,
                  JSON.stringify({ document: store.getDocument(), revision: created.revision }),
                )
              } catch {
                throw new Error(
                  `Created ${created.filepath}, but newer changes could not be saved as a local draft. Export them before leaving this board.`,
                )
              }
            }
            window.location.assign(
              `/whiteboard?${new URLSearchParams({ filepath: created.filepath })}`,
            )
          }}
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
