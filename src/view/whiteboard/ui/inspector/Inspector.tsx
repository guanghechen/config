import React from 'react'
import type { IWhiteboardTheme } from '../../theme'
import type { IEdgeAppearance, IElement, IStyle } from '@/shared/whiteboard/model'
import { stackingDirections } from '@/shared/whiteboard/stacking'
import { hasText } from '@/shared/whiteboard/text'
import type { ITextStyle } from '@/shared/whiteboard/text'
import type { BoardStore, IBoardSnapshot } from '../../store'
import type { ITool } from '../../interaction/tools'
import { BoardIcon, BoardIconLabel } from '../BoardIcon'
import { SelectionActions } from './SelectionActions'
import { StyleControls } from './StyleControls'
import { TypographyControls } from './TypographyControls'
import { ConnectorControls } from './ConnectorControls'
import { TransformControls } from './TransformControls'

export const Inspector: React.FC<{
  theme: IWhiteboardTheme
  snapshot: IBoardSnapshot
  store: BoardStore
  tool: ITool
  style: IStyle
  edgeAppearance: IEdgeAppearance
  busy: boolean
  updateStyle: (patch: Partial<IStyle>) => void
  updateTypography: (patch: ITextStyle) => void
  updateAutoSize: (value: boolean) => void
  updateEdgeAppearance: (patch: IEdgeAppearance) => void
  edit: (node: IElement) => void | Promise<void>
}> = ({
  theme,
  snapshot,
  store,
  tool,
  style,
  edgeAppearance,
  busy,
  updateStyle,
  updateTypography,
  updateAutoSize,
  updateEdgeAppearance,
  edit,
}) => {
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
  return (
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
              title={selected.some(element => element.hidden) ? 'Show selection' : 'Hide selection'}
              aria-pressed={selected.some(element => element.hidden)}
              onClick={() =>
                store.setSelectedFlags({ hidden: !selected.some(element => element.hidden) })
              }
            >
              <BoardIcon name={selected.some(element => element.hidden) ? 'visible' : 'hidden'} />
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
            Some connections are hidden with their endpoints. Show those nodes in Elements first.
          </p>
        )}
        <fieldset className="wb-properties-fields" disabled={selectionLocked}>
          <StyleControls
            style={displayStyle}
            colors={theme.colors}
            onChange={updateStyle}
            showLineWidth={
              selected.length ? selected.some(element => element.type !== 'text') : tool !== 'text'
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
              disabled={busy}
              automatic={
                autoSelection.length ? autoSelection.every(element => element.autoSize) : undefined
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
              disabled={busy}
              onChange={updateEdgeAppearance}
            />
          )}
          {selected.length > 0 && (
            <>
              <TransformControls selected={selected} store={store} disabled={busy} />
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
              Drag corner handles to resize; hold Shift to keep proportions. Drag the round handle
              above the selection to rotate; Shift snaps to 15°.
            </p>
            <p>
              Angled groups resize proportionally; external connections stay attached. Double-click
              to edit a group member, or ungroup to move it separately.
            </p>
            <p>
              All element types share one layer order, from back to front. Auto size fits text
              content; resizing a corner switches back to fixed size.
            </p>
            {selected.some(element => element.type === 'edge') && (
              <p>
                Drag a round endpoint to reconnect; release on empty space to detach. Drag square
                handles to shape the route. Alt-click a polyline bend to remove it.
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
              disabled={selectionLocked || busy}
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
            disabled={busy}
            onClick={store.duplicateSelected}
          >
            <BoardIcon name="duplicate" />
          </button>
          <button
            className="wb-danger-action"
            aria-label="Delete selection"
            title="Delete selection"
            disabled={!store.canRemoveSelection() || busy}
            onClick={store.removeSelected}
          >
            <BoardIcon name="delete" />
          </button>
        </footer>
      )}
    </aside>
  )
}
