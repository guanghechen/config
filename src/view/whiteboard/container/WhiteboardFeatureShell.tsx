import cn from 'clsx'
import React from 'react'
import {
  type IEdgeValidationDetail,
  type INodeValidationDetail,
  type IWhiteboardPointerInput,
  type IWhiteboardViewState,
  MarkdownFloatingEditor,
  WhiteboardCanvasShell,
  createWhiteboardRuntime,
} from '@/feature/whiteboard'

const toCanvasPoint = (event: React.PointerEvent<HTMLCanvasElement>): { x: number; y: number } => {
  const rect = event.currentTarget.getBoundingClientRect()
  return {
    x: event.clientX - rect.left,
    y: event.clientY - rect.top,
  }
}

const toWheelCanvasPoint = (
  event: React.WheelEvent<HTMLCanvasElement>,
): { x: number; y: number } => {
  const rect = event.currentTarget.getBoundingClientRect()
  return {
    x: event.clientX - rect.left,
    y: event.clientY - rect.top,
  }
}

/* ── Island: Excalidraw-style floating panel ── */

const islandClass =
  'flex items-center gap-0.5 rounded-[12px] border border-slate-200/90 bg-white p-1 shadow-[0_1px_4px_rgba(15,23,42,0.08),0_8px_20px_rgba(15,23,42,0.06)]'

const toolbarIslandClass =
  'flex items-center gap-0.5 rounded-[11px] border border-[#d8dce6] bg-[#fcfcff] px-2 py-1.5 shadow-[0_1px_0_rgba(15,23,42,0.04),0_2px_9px_rgba(15,23,42,0.08)]'

const toolbarDividerEl = <span className="mx-1 h-6 w-px bg-[#e2e5ed]" />

interface IToolbarIconButtonProps {
  readonly title: string
  readonly shortcut?: string
  readonly active?: boolean
  readonly onClick?: () => void
  readonly children: React.ReactNode
}

const ToolbarIconButton: React.FC<IToolbarIconButtonProps> = ({
  title,
  shortcut,
  active = false,
  onClick,
  children,
}) => {
  return (
    <button
      type="button"
      title={title}
      className={cn(
        'relative inline-flex h-8 w-8 items-center justify-center rounded-[8px] transition-colors',
        active
          ? 'bg-[#e6e5ff] text-[#4b4ccf]'
          : 'text-[#3f4b61] hover:bg-[#f1f3f8] active:bg-[#e7ebf4]',
      )}
      onClick={onClick}
    >
      {children}
      {shortcut && (
        <span className="pointer-events-none absolute -bottom-[1px] right-[1px] text-[9px] leading-none text-[#9fa7b7]">
          {shortcut}
        </span>
      )}
    </button>
  )
}

const iconClass = 'h-[17px] w-[17px] stroke-[1.8]' as const

/* ── Buttons ── */

const actionBtnClass = (enabled = true): string =>
  cn(
    'inline-flex h-8 min-w-8 items-center justify-center rounded-lg px-2 text-[12px] font-medium transition-colors select-none',
    enabled
      ? 'text-slate-600 hover:bg-slate-100 active:bg-slate-200'
      : 'pointer-events-none text-slate-300',
  )

const dangerBtnClass = (enabled = true): string =>
  cn(
    'inline-flex h-8 min-w-8 items-center justify-center rounded-lg px-2 text-[12px] font-medium transition-colors select-none',
    enabled
      ? 'text-rose-500 hover:bg-rose-50 active:bg-rose-100'
      : 'pointer-events-none text-slate-300',
  )

const dividerEl = <span className="mx-0.5 h-4 w-px bg-slate-200" />

/* ── Validation badge ── */

const ValidationBadge: React.FC<{
  readonly warnCount: number
  readonly errorCount: number
  readonly onClick: () => void
}> = ({ warnCount, errorCount, onClick }) => {
  if (warnCount === 0 && errorCount === 0) return null
  return (
    <button
      type="button"
      onClick={onClick}
      className="inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[11px] font-medium text-amber-700 hover:bg-amber-50"
    >
      {errorCount > 0 && <span className="text-rose-500">{errorCount}E</span>}
      {warnCount > 0 && <span>{warnCount}W</span>}
    </button>
  )
}

const ValidationList: React.FC<{
  readonly title: string
  readonly details: ReadonlyArray<INodeValidationDetail | IEdgeValidationDetail>
}> = ({ title, details }) => {
  if (details.length === 0) {
    return <div className="px-2 py-1 text-[11px] text-slate-400">{title}: no issues</div>
  }

  return (
    <div className="space-y-0.5 p-1">
      <div className="px-1 text-[11px] font-semibold text-slate-500">{title}</div>
      {details.slice(0, 6).map(detail => {
        const detailId = 'nodeId' in detail ? detail.nodeId : detail.edgeId
        const issueCode = detail.issues[0]?.code ?? 'UNKNOWN'
        return (
          <div key={detailId} className="rounded-md bg-slate-50 px-2 py-1 text-[11px]">
            <span className="font-medium text-slate-600">
              {detail.level === 'error' ? 'ERR' : 'WARN'}
            </span>
            <span className="ml-1 text-slate-400">{detailId.slice(0, 12)}</span>
            <span className="ml-1 text-slate-500">{issueCode}</span>
          </div>
        )
      })}
    </div>
  )
}

/* ── Main component ── */

export const WhiteboardFeatureShell: React.FC = () => {
  const canvasRef = React.useRef<HTMLCanvasElement | null>(null)
  const spacePressedRef = React.useRef<boolean>(false)
  const runtime = React.useMemo(() => createWhiteboardRuntime(), [])

  const [viewState, setViewState] = React.useState<IWhiteboardViewState>(runtime.getViewState())
  const [editingNodeId, setEditingNodeId] = React.useState<string | null>(null)
  const [showDiagnostics, setShowDiagnostics] = React.useState<boolean>(false)

  React.useEffect(() => {
    return runtime.subscribe(setViewState)
  }, [runtime])

  React.useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    runtime.attach(canvas)

    const resizeObserver = new ResizeObserver(entries => {
      const entry = entries[0]
      if (!entry) return

      runtime.resize(
        entry.contentRect.width,
        entry.contentRect.height,
        globalThis.devicePixelRatio || 1,
      )
    })

    resizeObserver.observe(canvas)

    return (): void => {
      resizeObserver.disconnect()
      runtime.dispose()
    }
  }, [runtime])

  React.useEffect(() => {
    const isTypingTarget = (target: EventTarget | null): boolean => {
      if (!(target instanceof HTMLElement)) return false
      const tagName = target.tagName.toLowerCase()
      return (
        target.isContentEditable ||
        tagName === 'input' ||
        tagName === 'textarea' ||
        tagName === 'select'
      )
    }

    const onKeyDown = (event: KeyboardEvent): void => {
      if (event.code === 'Space') {
        spacePressedRef.current = true
      }

      if (isTypingTarget(event.target)) {
        return
      }

      if (editingNodeId) {
        if (event.key === 'Escape') {
          event.preventDefault()
          setEditingNodeId(null)
        }
        return
      }

      if (event.code === 'Space') {
        event.preventDefault()
        return
      }

      const isMeta = event.metaKey || event.ctrlKey

      if (isMeta && event.key.toLowerCase() === 'z' && !event.shiftKey) {
        event.preventDefault()
        runtime.undo()
        return
      }

      if (isMeta && event.key.toLowerCase() === 'z' && event.shiftKey) {
        event.preventDefault()
        runtime.redo()
        return
      }

      if (isMeta && event.key.toLowerCase() === 'y') {
        event.preventDefault()
        runtime.redo()
        return
      }

      if (isMeta && event.key.toLowerCase() === 'a') {
        event.preventDefault()
        runtime.selectAllNodes()
        return
      }

      if (event.key.toLowerCase() === 'n') {
        event.preventDefault()
        runtime.createShapeNodeAtViewportCenter('shape.rectangle')
        return
      }

      if (isMeta && event.key.toLowerCase() === 'c') {
        event.preventDefault()
        runtime.copySelection()
        return
      }

      if (isMeta && event.key.toLowerCase() === 'v') {
        event.preventDefault()
        runtime.pasteClipboard()
        return
      }

      if (isMeta && event.key.toLowerCase() === 'd') {
        event.preventDefault()
        runtime.duplicateSelection()
        return
      }

      if (isMeta && event.key === ']') {
        event.preventDefault()
        if (event.shiftKey) {
          runtime.bringSelectionToFront()
        } else {
          runtime.bringSelectionForward()
        }
        return
      }

      if (isMeta && event.key === '[') {
        event.preventDefault()
        if (event.shiftKey) {
          runtime.sendSelectionToBack()
        } else {
          runtime.sendSelectionBackward()
        }
        return
      }

      if (event.key === 'Escape') {
        event.preventDefault()
        runtime.cancelInteraction()
        runtime.clearSelection()
        return
      }

      if (event.key === 'Delete' || event.key === 'Backspace') {
        event.preventDefault()
        runtime.deleteSelectedNodes()
      }
    }

    const onKeyUp = (event: KeyboardEvent): void => {
      if (event.code === 'Space') {
        spacePressedRef.current = false
      }
    }

    window.addEventListener('keydown', onKeyDown)
    window.addEventListener('keyup', onKeyUp)
    return (): void => {
      window.removeEventListener('keydown', onKeyDown)
      window.removeEventListener('keyup', onKeyUp)
    }
  }, [runtime, editingNodeId])

  const buildPointerInput = React.useCallback(
    (event: React.PointerEvent<HTMLCanvasElement>): IWhiteboardPointerInput => {
      const point = toCanvasPoint(event)
      return {
        x: point.x,
        y: point.y,
        button: event.button,
        spaceKey: spacePressedRef.current || event.altKey,
        shiftKey: event.shiftKey,
      }
    },
    [],
  )

  const onDoubleClick = React.useCallback(
    (event: React.MouseEvent<HTMLCanvasElement>): void => {
      const rect = event.currentTarget.getBoundingClientRect()
      const x = event.clientX - rect.left
      const y = event.clientY - rect.top

      const nodeId = runtime.getNodeIdAtCanvasPoint(x, y)
      if (!nodeId) return

      const node = runtime.getViewState().snapshot.data.graph.nodesById[nodeId]
      if (!node || node.type !== 'node.markdown') return

      setEditingNodeId(nodeId)
    },
    [runtime],
  )

  const onPointerDown = React.useCallback(
    (event: React.PointerEvent<HTMLCanvasElement>): void => {
      const target = event.currentTarget
      target.setPointerCapture(event.pointerId)
      runtime.handlePointerDown(buildPointerInput(event))
    },
    [runtime, buildPointerInput],
  )

  const onPointerMove = React.useCallback(
    (event: React.PointerEvent<HTMLCanvasElement>): void => {
      runtime.handlePointerMove(buildPointerInput(event))
    },
    [runtime, buildPointerInput],
  )

  const onPointerUp = React.useCallback(
    (event: React.PointerEvent<HTMLCanvasElement>): void => {
      runtime.handlePointerUp(buildPointerInput(event))
      event.currentTarget.releasePointerCapture(event.pointerId)
    },
    [runtime, buildPointerInput],
  )

  const onPointerCancel = React.useCallback((): void => {
    runtime.cancelInteraction()
  }, [runtime])

  const onWheel = React.useCallback(
    (event: React.WheelEvent<HTMLCanvasElement>): void => {
      event.preventDefault()
      const point = toWheelCanvasPoint(event)
      runtime.handleWheel({
        x: point.x,
        y: point.y,
        deltaY: event.deltaY,
      })
    },
    [runtime],
  )

  const viewport = viewState.snapshot.data.graph.viewport
  const hasSelection = viewState.selectedNodeIds.length > 0
  const isEmptyScene = Object.keys(viewState.snapshot.data.graph.nodesById).length === 0

  const markdownEditorValue =
    editingNodeId && viewState.snapshot.data.graph.nodesById[editingNodeId]
      ? String(viewState.snapshot.data.graph.nodesById[editingNodeId].payload.markdown ?? '')
      : ''

  const totalWarn =
    viewState.nodeValidationSummary.warnCount + viewState.edgeValidationSummary.warnCount
  const totalError =
    viewState.nodeValidationSummary.errorCount + viewState.edgeValidationSummary.errorCount

  const createRectangleNode = (): void => {
    runtime.createShapeNodeAtViewportCenter('shape.rectangle')
  }

  const createDiamondNode = (): void => {
    runtime.createShapeNodeAtViewportCenter('shape.diamond')
  }

  const createEllipseNode = (): void => {
    runtime.createShapeNodeAtViewportCenter('shape.ellipse')
  }

  const createTextNode = (): void => {
    runtime.createShapeNodeAtViewportCenter('node.text', { text: 'New text node' })
  }

  const createImageNode = (): void => {
    runtime.createShapeNodeAtViewportCenter('node.image', { src: './assets/image.png' })
  }

  const createMarkdownNode = (): void => {
    runtime.createShapeNodeAtViewportCenter('node.markdown', {
      markdown: '# New Markdown Node\n\nStart typing...',
    })
  }

  return (
    <React.Fragment>
      <WhiteboardCanvasShell
        canvasRef={canvasRef}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerCancel}
        onDoubleClick={onDoubleClick}
        onWheel={onWheel}
        centerOverlay={
          isEmptyScene ? (
            <div className="pointer-events-auto select-none text-center">
              <div className="text-[52px] font-black tracking-tight text-violet-700">YOZBOARD</div>
              <p className="mx-auto mt-4 max-w-[560px] text-[15px] leading-6 text-slate-400">
                Your drawings are saved in workspace cache. Save snapshots to file regularly to
                avoid losing work.
              </p>
              <div className="mx-auto mt-8 w-[340px] space-y-2 text-left text-[24px] text-slate-400">
                <div className="flex items-center justify-between rounded-lg px-2 py-1.5 hover:bg-slate-100/60">
                  <span>Open</span>
                  <span className="text-[18px]">Ctrl+O</span>
                </div>
                <div className="flex items-center justify-between rounded-lg px-2 py-1.5 hover:bg-slate-100/60">
                  <span>Help</span>
                  <span className="text-[18px]">?</span>
                </div>
                <div className="flex items-center justify-between rounded-lg px-2 py-1.5 hover:bg-slate-100/60">
                  <span>Collaboration</span>
                  <span className="text-[18px]">Soon</span>
                </div>
              </div>
            </div>
          ) : null
        }
        topCenterIsland={
          <div className={toolbarIslandClass}>
            <ToolbarIconButton title="Lock tool">
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <rect x="5" y="11" width="14" height="10" rx="2.1" stroke="currentColor" />
                <path d="M8 11V8a4 4 0 0 1 8 0v3" stroke="currentColor" />
              </svg>
            </ToolbarIconButton>
            {toolbarDividerEl}
            <ToolbarIconButton title="Hand tool">
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <path
                  d="M8.5 12V6.8a1.3 1.3 0 1 1 2.6 0V11M11.1 11V5.8a1.3 1.3 0 1 1 2.6 0V11"
                  stroke="currentColor"
                  strokeLinecap="round"
                />
                <path
                  d="M13.7 11V7.3a1.3 1.3 0 1 1 2.6 0v6.4c0 3-2.4 5.3-5.3 5.3h-.4c-2 0-3.8-1.2-4.7-3.1L4.5 13"
                  stroke="currentColor"
                  strokeLinecap="round"
                />
              </svg>
            </ToolbarIconButton>
            <ToolbarIconButton title="Select" active={true} shortcut="1">
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <path d="M5 4.5 16 12l-5 1.5 1.8 4.5-1.8.8-2-4.6-3.8 1.8Z" fill="currentColor" />
              </svg>
            </ToolbarIconButton>
            <ToolbarIconButton title="Rectangle" shortcut="2" onClick={createRectangleNode}>
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <rect x="4.5" y="6" width="15" height="11" rx="1.5" stroke="currentColor" />
              </svg>
            </ToolbarIconButton>
            <ToolbarIconButton title="Diamond" shortcut="3" onClick={createDiamondNode}>
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <path d="m12 5 6.5 6.5L12 18l-6.5-6.5Z" stroke="currentColor" />
              </svg>
            </ToolbarIconButton>
            <ToolbarIconButton title="Ellipse" shortcut="4" onClick={createEllipseNode}>
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <ellipse cx="12" cy="12" rx="6.5" ry="5.5" stroke="currentColor" />
              </svg>
            </ToolbarIconButton>
            <ToolbarIconButton title="Arrow" shortcut="5">
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <path d="M4.5 12h13.5" stroke="currentColor" strokeLinecap="round" />
                <path d="m14 8.5 4 3.5-4 3.5" stroke="currentColor" strokeLinecap="round" />
              </svg>
            </ToolbarIconButton>
            <ToolbarIconButton title="Line" shortcut="6">
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <path d="M5 15 19 9" stroke="currentColor" strokeLinecap="round" />
              </svg>
            </ToolbarIconButton>
            <ToolbarIconButton title="Draw" shortcut="7">
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <path d="m5 18.5 3.2-.8 8.1-8.1-2.4-2.4-8 8.1Z" stroke="currentColor" />
                <path d="m13.9 7.1 2.4 2.4" stroke="currentColor" />
              </svg>
            </ToolbarIconButton>
            <ToolbarIconButton title="Text" shortcut="8" onClick={createTextNode}>
              <span className="text-[15px] font-semibold leading-none">A</span>
            </ToolbarIconButton>
            <ToolbarIconButton title="Image" shortcut="9" onClick={createImageNode}>
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <rect x="5" y="6" width="14" height="12" rx="2" stroke="currentColor" />
                <circle cx="10" cy="10" r="1.2" fill="currentColor" />
                <path d="m7 16 3.3-3.2 2.4 2.2 2.4-2.4L17 16" stroke="currentColor" />
              </svg>
            </ToolbarIconButton>
            <ToolbarIconButton title="Eraser" shortcut="0">
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <path d="m6.2 13.7 5.6-5.6 5.1 5.1-3.7 3.7H7.9l-1.7-1.7Z" stroke="currentColor" />
                <path d="M13.2 16.9h4.3" stroke="currentColor" strokeLinecap="round" />
              </svg>
            </ToolbarIconButton>
            {toolbarDividerEl}
            <ToolbarIconButton title="Markdown library" onClick={createMarkdownNode}>
              <svg viewBox="0 0 24 24" fill="none" className={iconClass}>
                <path
                  d="m7 16.5 3.3-7.5M10.3 9l3.2 7.5M15 16.5 18 9"
                  stroke="currentColor"
                  strokeLinecap="round"
                />
                <path d="M6.5 17.5h11" stroke="currentColor" strokeLinecap="round" />
              </svg>
            </ToolbarIconButton>
          </div>
        }
        topRightIsland={
          <div className={islandClass}>
            <button
              type="button"
              title="Yozboard+ (coming soon)"
              className={actionBtnClass()}
              onClick={() => undefined}
            >
              Yozboard+
            </button>
            <button
              type="button"
              title="Share (coming soon)"
              className={actionBtnClass()}
              onClick={() => undefined}
            >
              Share
            </button>
            {dividerEl}
            <button
              type="button"
              title="Toggle grid"
              className={cn(actionBtnClass(), viewport.showGrid && 'text-violet-600')}
              onClick={() => runtime.toggleGrid()}
            >
              Grid
            </button>
          </div>
        }
        floatingRightPanel={
          showDiagnostics ? (
            <div className="rounded-xl border border-slate-200/80 bg-white p-2 shadow-[0_2px_12px_rgba(0,0,0,0.08)]">
              <div className="flex items-center justify-between px-1 pb-1">
                <span className="text-[11px] font-semibold uppercase tracking-wide text-slate-400">
                  Diagnostics
                </span>
                <button
                  type="button"
                  className="rounded px-1.5 py-0.5 text-[11px] text-slate-400 hover:bg-slate-100 hover:text-slate-600"
                  onClick={() => setShowDiagnostics(false)}
                >
                  ✕
                </button>
              </div>
              <ValidationList title="Node" details={viewState.nodeValidationDetails} />
              <ValidationList title="Edge" details={viewState.edgeValidationDetails} />
            </div>
          ) : null
        }
        bottomLeftIsland={
          <div className="flex items-center gap-2">
            <div className={islandClass}>
              <button
                type="button"
                title="Zoom out"
                className={actionBtnClass()}
                onClick={() => runtime.zoomByFactor(1 / 1.15)}
              >
                −
              </button>
              <button
                type="button"
                title="Reset zoom"
                className={cn(actionBtnClass(), 'min-w-12 tabular-nums text-[12px] text-slate-500')}
                onClick={() => runtime.resetViewport()}
              >
                {Math.round(viewport.zoom * 100)}%
              </button>
              <button
                type="button"
                title="Zoom in"
                className={actionBtnClass()}
                onClick={() => runtime.zoomByFactor(1.15)}
              >
                +
              </button>
            </div>
            <div className={islandClass}>
              <button
                type="button"
                title="Undo (Ctrl+Z)"
                disabled={!viewState.canUndo}
                className={actionBtnClass(viewState.canUndo)}
                onClick={() => runtime.undo()}
              >
                ↶
              </button>
              <button
                type="button"
                title="Redo (Ctrl+Shift+Z)"
                disabled={!viewState.canRedo}
                className={actionBtnClass(viewState.canRedo)}
                onClick={() => runtime.redo()}
              >
                ↷
              </button>
            </div>
          </div>
        }
        bottomCenterIsland={
          hasSelection ? (
            <div className={islandClass}>
              <button
                type="button"
                title="Copy (Ctrl+C)"
                className={actionBtnClass()}
                onClick={() => runtime.copySelection()}
              >
                Copy
              </button>
              <button
                type="button"
                title="Paste (Ctrl+V)"
                disabled={!viewState.clipboard.hasData}
                className={actionBtnClass(viewState.clipboard.hasData)}
                onClick={() => runtime.pasteClipboard()}
              >
                Paste
              </button>
              <button
                type="button"
                title="Duplicate (Ctrl+D)"
                className={actionBtnClass()}
                onClick={() => runtime.duplicateSelection()}
              >
                Dup
              </button>
              {dividerEl}
              <button
                type="button"
                title="Bring to front"
                className={actionBtnClass()}
                onClick={() => runtime.bringSelectionToFront()}
              >
                ↑↑
              </button>
              <button
                type="button"
                title="Bring forward"
                className={actionBtnClass()}
                onClick={() => runtime.bringSelectionForward()}
              >
                ↑
              </button>
              <button
                type="button"
                title="Send backward"
                className={actionBtnClass()}
                onClick={() => runtime.sendSelectionBackward()}
              >
                ↓
              </button>
              <button
                type="button"
                title="Send to back"
                className={actionBtnClass()}
                onClick={() => runtime.sendSelectionToBack()}
              >
                ↓↓
              </button>
              {dividerEl}
              <button
                type="button"
                title="Delete (Del)"
                className={dangerBtnClass()}
                onClick={() => runtime.deleteSelectedNodes()}
              >
                Delete
              </button>
            </div>
          ) : null
        }
        bottomRightIsland={
          <div className="flex items-center gap-2">
            <ValidationBadge
              warnCount={totalWarn}
              errorCount={totalError}
              onClick={() => setShowDiagnostics(v => !v)}
            />
            <button
              type="button"
              title="Help"
              className={cn(actionBtnClass(), 'rounded-full border border-slate-200 bg-white px-2')}
              onClick={() => undefined}
            >
              ?
            </button>
            {viewState.statusMessage && (
              <span className="max-w-48 truncate text-[11px] text-slate-400">
                {viewState.statusMessage}
              </span>
            )}
          </div>
        }
      />
      <MarkdownFloatingEditor
        open={editingNodeId !== null}
        value={markdownEditorValue}
        onClose={() => setEditingNodeId(null)}
        onSave={value => {
          if (!editingNodeId) return
          runtime.updateNodePayload(editingNodeId, { markdown: value })
          setEditingNodeId(null)
        }}
      />
    </React.Fragment>
  )
}

WhiteboardFeatureShell.displayName = 'WhiteboardFeatureShell'
