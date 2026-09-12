import React from 'react'
import { createDocument } from '@/shared/whiteboard/model'
import { useBoardHost } from '../../HostContext'
import type { BoardStore, IBoardSnapshot } from '../../store'
import type { ITool } from '../../interaction/tools'
import { BoardIcon } from '../BoardIcon'
import { DrawingTools } from './DrawingTools'

export const BoardToolbar: React.FC<{
  snapshot: IBoardSnapshot
  store: BoardStore
  tool: ITool
  locked: boolean
  readOnly: boolean
  reading: boolean
  modeBusy: boolean
  width: number
  showElements: boolean
  showNavigation: boolean
  onToggleElements: () => void
  onToggleNavigation: () => void
  toggleReading: () => void
  chooseTool: (tool: ITool) => void
  setTool: (tool: ITool) => void
  toggleLock: () => void
  onImport: () => void
  download: () => void
  onExportImage: () => void
  onSaveAs: () => void
  onAddImages: () => void
  onReference: () => void
  filepath?: string
  saving: boolean
  loading: boolean
  canSave: boolean
  saveFile: () => Promise<void>
  reloadFile: () => Promise<void>
}> = ({
  snapshot,
  store,
  tool,
  locked,
  readOnly,
  reading,
  modeBusy,
  width,
  showElements,
  showNavigation,
  onToggleElements,
  onToggleNavigation,
  toggleReading,
  chooseTool,
  setTool,
  toggleLock,
  onImport,
  download,
  onExportImage,
  onSaveAs,
  onAddImages,
  onReference,
  filepath,
  saving,
  loading,
  canSave,
  saveFile,
  reloadFile,
}) => {
  const host = useBoardHost()
  const compactToolbar = width < 1000
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
  const viewControls = (
    <>
      <button
        aria-label="Elements"
        aria-pressed={showElements}
        title="Elements and search"
        onClick={onToggleElements}
      >
        <BoardIcon name="layers" />
        <span>Elements</span>
      </button>
      <button
        aria-label="Navigate"
        title="Navigate"
        aria-pressed={showNavigation}
        onClick={onToggleNavigation}
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
      {host.appearance}
    </>
  )

  return (
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
            {host.workspaceHref && (
              <a href={host.workspaceHref} title="Back to workspace" aria-label="Workspace">
                <BoardIcon name="home" />
                <span>Back to workspace</span>
              </a>
            )}
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
            <button onClick={onImport}>
              <BoardIcon name="importBoard" />
              <span>Import .whiteboard</span>
            </button>
            <button onClick={download}>
              <BoardIcon name="exportBoard" />
              <span>Export .whiteboard</span>
            </button>
            <button onClick={onExportImage}>
              <BoardIcon name="exportImage" />
              <span>Export image…</span>
            </button>
            <button disabled={!host.files || !host.FilePicker || !host.openFile} onClick={onSaveAs}>
              <BoardIcon name="saveAs" />
              <span>Save as in workspace…</span>
            </button>
            {filepath && host.files && (
              <button onClick={() => void saveFile()} disabled={saving || !canSave}>
                <BoardIcon name="save" />
                <span>{saving ? 'Saving…' : 'Save to source file'}</span>
              </button>
            )}
            {filepath && host.files && (
              <button onClick={() => void reloadFile()} disabled={loading || saving}>
                <BoardIcon name="reload" />
                <span>Reload source file</span>
              </button>
            )}
            <hr />
            <button disabled={readOnly} onClick={onAddImages}>
              <BoardIcon name="addImage" />
              <span>Add images…</span>
            </button>
            <button disabled={readOnly} onClick={() => setTool('image')}>
              <BoardIcon name="link" />
              <span>Place image from URL or path</span>
            </button>
            <button disabled={readOnly || !host.files || !host.FilePicker} onClick={onReference}>
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
          compact={width < 680}
          menuName={toolbarMenuName}
        />
      )}
      {reading && (
        <div className="wb-reading-tools" data-wb-ui>
          <span>Reading mode</span>
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
  )
}
