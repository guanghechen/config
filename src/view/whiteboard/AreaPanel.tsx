import React from 'react'
import { VirtualList } from '@/common/component/virtual-list/VirtualList'
import type { IRegion, IWhiteboardDocument } from '@/shared/whiteboard/model'
import { elementBounds, unionBounds } from '@/shared/whiteboard/geometry'
import { viewportBounds } from '@/shared/whiteboard/navigation'
import { parseDocument } from '@/shared/whiteboard/document'
import type { BoardStore } from './store'

export const AreaPanel = React.memo<{
  document: IWhiteboardDocument
  selected: ReadonlySet<string>
  store: BoardStore
  size: { width: number; height: number }
  readOnly: boolean
  busy: boolean
  onFocus: (region: IRegion) => void
  onPresent: () => void
  onClose: () => void
}>(({ document, selected, store, size, readOnly, busy, onFocus, onPresent, onClose }) => {
  const [name, setName] = React.useState('')
  const [source, setSource] = React.useState(selected.size ? 'selection' : 'view')
  const [renaming, setRenaming] = React.useState<{ id: string; name: string } | null>(null)
  const [error, setError] = React.useState('')
  const regions = document.regions ?? [],
    steps = document.presentation ?? regions.map(r => r.id)
  const commit = (next: IWhiteboardDocument): boolean => {
    if (readOnly) return false
    try {
      store.commit(parseDocument(JSON.stringify(next)))
      setError('')
      return true
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : String(reason))
      return false
    }
  }
  const step = (index: number, delta: number): void => {
    const next = [...steps],
      target = index + delta
    if (target < 0 || target >= next.length) return
    ;[next[index], next[target]] = [next[target], next[index]]
    commit({ ...document, presentation: next })
  }
  return (
    <aside className="wb-area-panel" data-wb-ui aria-label="Navigate">
      <header>
        <strong>Named areas</strong>
        <button aria-label="Close navigation" onClick={onClose}>
          ×
        </button>
      </header>
      {!readOnly && (
        <form
          onSubmit={event => {
            event.preventDefault()
            const snapshot = store.getSnapshot(),
              map = new Map(snapshot.document.elements.map(e => [e.id, e]))
            const bounds =
              source === 'selection'
                ? unionBounds(
                    snapshot.document.elements
                      .filter(e => snapshot.selected.has(e.id) && !snapshot.hidden.has(e.id))
                      .map(e => elementBounds(e, map)),
                  )
                : viewportBounds(snapshot.camera, size.width, size.height)
            if (!bounds) {
              setError('Select visible elements first')
              return
            }
            const region = {
              ...bounds,
              width: Math.max(1, bounds.width),
              height: Math.max(1, bounds.height),
              id: crypto.randomUUID(),
              name: name.trim() || `Area ${regions.length + 1}`,
            }
            if (
              commit({
                ...document,
                regions: [...regions, region],
                presentation: [...steps, region.id],
              })
            )
              setName('')
          }}
        >
          <input
            aria-label="Area name"
            placeholder="Name this area…"
            maxLength={256}
            value={name}
            onChange={event => setName(event.target.value)}
          />
          <div className="wb-area-create">
            <select
              aria-label="Area bounds"
              value={source}
              onChange={event => setSource(event.target.value)}
            >
              <option value="view">Current view</option>
              <option value="selection" disabled={!selected.size}>
                Selection
              </option>
            </select>
            <button type="submit">Add area</button>
          </div>
        </form>
      )}
      <VirtualList
        items={regions}
        itemHeight={38}
        getItemKey={r => r.id}
        className="wb-area-list"
        renderItem={region => (
          <div className="wb-area-row">
            <button
              className="wb-area-name"
              title={region.id}
              aria-label={`Focus area ${region.name}`}
              disabled={busy}
              onClick={() => onFocus(region)}
            >
              {region.name}
            </button>
            <button
              disabled={readOnly}
              aria-label={`Rename ${region.name}`}
              onClick={() => setRenaming({ id: region.id, name: region.name })}
            >
              ✎
            </button>
            <button
              disabled={readOnly}
              aria-label={`Add ${region.name} to presentation`}
              onClick={() => commit({ ...document, presentation: [...steps, region.id] })}
            >
              +
            </button>
            <button
              disabled={readOnly}
              aria-label={`Remove area ${region.name}`}
              onClick={() =>
                commit({
                  ...document,
                  regions: regions.filter(r => r.id !== region.id),
                  presentation: steps.filter(id => id !== region.id),
                })
              }
            >
              ×
            </button>
          </div>
        )}
      />
      {!regions.length && <p>Create an area from the current view or selection.</p>}
      {renaming && !readOnly && (
        <form
          className="wb-area-create"
          onSubmit={event => {
            event.preventDefault()
            commit({
              ...document,
              regions: regions.map(r => (r.id === renaming.id ? { ...r, name: renaming.name } : r)),
            })
            if (renaming.name.trim()) setRenaming(null)
          }}
        >
          <input
            aria-label="Rename area"
            value={renaming.name}
            maxLength={256}
            onChange={event => setRenaming({ ...renaming, name: event.target.value })}
          />
          <button type="submit">Save</button>
          <button type="button" onClick={() => setRenaming(null)}>
            Cancel
          </button>
        </form>
      )}
      <header>
        <strong>Presentation · {steps.length}</strong>
        <button disabled={!steps.length || busy} onClick={onPresent}>
          Present
        </button>
      </header>
      <VirtualList
        items={steps}
        itemHeight={36}
        getItemKey={(_id, index) => index}
        className="wb-step-list"
        renderItem={(id, index) => (
          <div className="wb-area-row">
            <span className="wb-area-name">
              {index + 1}. {regions.find(r => r.id === id)?.name}
            </span>
            <button
              disabled={readOnly || index === 0}
              aria-label={`Move step ${index + 1} up`}
              onClick={() => step(index, -1)}
            >
              ↑
            </button>
            <button
              disabled={readOnly || index === steps.length - 1}
              aria-label={`Move step ${index + 1} down`}
              onClick={() => step(index, 1)}
            >
              ↓
            </button>
            <button
              disabled={readOnly}
              aria-label={`Remove step ${index + 1}`}
              onClick={() =>
                commit({ ...document, presentation: steps.filter((_value, i) => i !== index) })
              }
            >
              ×
            </button>
          </div>
        )}
      />
      {error && <p role="alert">{error}</p>}
    </aside>
  )
})
AreaPanel.displayName = 'WhiteboardAreaPanel'
