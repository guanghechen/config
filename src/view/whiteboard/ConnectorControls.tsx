import React from 'react'
import { BoardIcon, BoardIconLabel } from './BoardIcon'
import { InspectorSection } from './InspectorSection'
import { addConnectorBend, connectorControls } from '@/shared/whiteboard/edges'
import { resolveEndpoint } from '@/shared/whiteboard/geometry'
import { DEFAULT_EDGE_APPEARANCE } from '@/shared/whiteboard/model'
import type { IEdge, IEdgeAppearance, IElement } from '@/shared/whiteboard/model'
import type { BoardStore } from './store'

export const ConnectorControls = React.memo<{
  value: IEdgeAppearance
  selected: ReadonlyArray<IElement>
  store: BoardStore
  disabled: boolean
  onChange: (patch: IEdgeAppearance) => void
}>(({ value, selected, store, disabled, onChange }) => {
  const single = selected.length === 1 && selected[0].type === 'edge' ? selected[0] : undefined
  const editControls = (
    edit: (
      edge: IEdge,
      from: ReturnType<typeof resolveEndpoint>,
      to: ReturnType<typeof resolveEndpoint>,
    ) => IEdge,
  ): void => {
    if (!single) return
    const current = store.getSnapshot().document
    const map = new Map(current.elements.map(element => [element.id, element]))
    const edge = map.get(single.id)
    if (edge?.type !== 'edge') return
    const updated = edit(edge, resolveEndpoint(edge.from, map), resolveEndpoint(edge.to, map))
    store.commit({
      ...current,
      elements: current.elements.map(element => (element === edge ? updated : element)),
    })
  }
  return (
    <InspectorSection title="Connection" icon="edge" initiallyOpen disabled={disabled}>
      <label>
        <BoardIconLabel name="curve">Route</BoardIconLabel>
        <select
          aria-label="Connection route"
          value={value.routing ?? 'straight'}
          onChange={event =>
            onChange({ routing: event.target.value as IEdgeAppearance['routing'] })
          }
        >
          <option value="straight">Straight</option>
          <option value="polyline">Polyline</option>
          <option value="curve">Curve</option>
        </select>
      </label>
      {(['arrowStart', 'arrowEnd'] as const).map(key => (
        <label key={key}>
          <BoardIconLabel name={key === 'arrowStart' ? 'previous' : 'next'}>
            {key === 'arrowStart' ? 'Start' : 'End'}
          </BoardIconLabel>
          <select
            aria-label={key === 'arrowStart' ? 'Start arrowhead' : 'End arrowhead'}
            value={value[key] ?? DEFAULT_EDGE_APPEARANCE[key]}
            onChange={event => onChange({ [key]: event.target.value })}
          >
            <option value="none">None</option>
            <option value="arrow">Arrow</option>
          </select>
        </label>
      ))}
      <label>
        <BoardIconLabel name="lineWidth">Line</BoardIconLabel>
        <select
          aria-label="Connection line style"
          value={value.lineStyle ?? 'solid'}
          onChange={event =>
            onChange({ lineStyle: event.target.value as IEdgeAppearance['lineStyle'] })
          }
        >
          <option value="solid">Solid</option>
          <option value="dashed">Dashed</option>
          <option value="dotted">Dotted</option>
        </select>
      </label>
      <div className="wb-icon-actions" role="group" aria-label="Route controls">
        {single?.routing === 'polyline' && (
          <>
            <button
              aria-label="Add bend"
              title="Add bend"
              disabled={(single.controls?.length ?? 2) >= 64}
              onClick={() => editControls(addConnectorBend)}
            >
              <BoardIcon name="addBend" />
            </button>
            <button
              aria-label="Remove last bend"
              title="Remove last bend"
              disabled={single.controls?.length === 0}
              onClick={() =>
                editControls((edge, from, to) => ({
                  ...edge,
                  controls: connectorControls(edge, from, to).slice(0, -1),
                }))
              }
            >
              <BoardIcon name="removeBend" />
            </button>
          </>
        )}
        {single && single.routing && single.routing !== 'straight' && (
          <button
            aria-label="Reset route controls"
            title="Reset route controls"
            disabled={single.controls === undefined}
            onClick={() =>
              editControls(edge => {
                const { controls: _, ...updated } = edge
                return updated
              })
            }
          >
            <BoardIcon name="reload" />
          </button>
        )}
      </div>
    </InspectorSection>
  )
})
ConnectorControls.displayName = 'WhiteboardConnectorControls'
