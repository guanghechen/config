import React from 'react'
import { VirtualList } from '@/common/component/virtual-list/VirtualList'
import type { IElement } from '@/shared/whiteboard/model'
import type { BoardStore, IBoardSnapshot } from './store'
import type { IMarkdownResources } from './resources'
import { elementName } from './elementName'
import { BoardIcon, BoardIconLabel } from './BoardIcon'

function searchable(element: IElement): string {
  const content =
    element.type === 'text'
      ? element.text
      : element.type === 'markdown'
        ? element.source.kind === 'file'
          ? element.source.filepath
          : element.source.content
        : element.type === 'shape' || element.type === 'edge'
          ? (element.label ?? '')
          : element.type === 'image'
            ? element.url.startsWith('data:')
              ? ''
              : element.url
            : ''
  return content
}

interface IElementListProps {
  snapshot: IBoardSnapshot
  store: BoardStore
  busy: boolean
  editable: boolean
  resources: IMarkdownResources
  onClose: () => void
  onFocus: (id: string) => void
}

export const ElementList = React.memo<IElementListProps>(
  ({ snapshot, store, busy, editable, resources, onClose, onFocus }) => {
    const [query, setQuery] = React.useState('')
    const deferred = React.useDeferredValue(query)
    const files = React.useMemo(
      () => [
        ...new Set(
          snapshot.document.elements.flatMap(element =>
            element.type === 'markdown' && element.source.kind === 'file'
              ? [element.source.filepath]
              : [],
          ),
        ),
      ],
      [snapshot.document.elements],
    )
    const searching = !!deferred.trim()
    const referenceStore = React.useMemo(() => {
      const paths = searching ? files : []
      let current = paths.map(resources.get)
      return {
        getSnapshot: () => {
          const next = paths.map(resources.get)
          if (next.some((value, index) => value !== current[index])) current = next
          return current
        },
        subscribe: (listener: () => void) => {
          const stops = paths.map(filepath => resources.subscribe(filepath, listener))
          return () => {
            for (const stop of stops) stop()
          }
        },
      }
    }, [files, resources, searching])
    const resolved = React.useSyncExternalStore(
      referenceStore.subscribe,
      referenceStore.getSnapshot,
    )
    const referenced = React.useMemo(() => {
      const content = new Map<string, string>()
      let pending = 0,
        errors = 0
      resolved.forEach((resource, index) => {
        if (resource.error) errors++
        else if (!resource.data) pending++
        if (resource.data) content.set(files[index], resource.data.content.toLowerCase())
      })
      return { content, pending, errors }
    }, [files, resolved])
    const items = React.useMemo(() => {
      const result: IElement[] = []
      const needle = deferred.trim().toLowerCase()
      for (let index = snapshot.document.elements.length - 1; index >= 0; index--) {
        const element = snapshot.document.elements[index]
        if (
          !needle ||
          element.id.toLowerCase().includes(needle) ||
          element.type.includes(needle) ||
          searchable(element).toLowerCase().includes(needle) ||
          (element.type === 'markdown' &&
            element.source.kind === 'file' &&
            referenced.content.get(element.source.filepath)?.includes(needle))
        )
          result.push(element)
      }
      return result
    }, [snapshot.document.elements, deferred, referenced.content])
    return (
      <aside className="wb-element-list" data-wb-ui aria-label="Elements">
        <header>
          <strong>
            <BoardIconLabel name="layers">
              Elements <small>{items.length}</small>
            </BoardIconLabel>
          </strong>
          <button aria-label="Close elements" onClick={onClose}>
            <BoardIcon name="close" />
          </button>
        </header>
        <input
          aria-label="Find element"
          placeholder="Search content or ID…"
          value={query}
          onChange={event => setQuery(event.target.value)}
        />
        <p className="wb-endpoint-hint">
          Front to back. Double-click to focus. Shift-click to add a group.
        </p>
        {referenced.pending > 0 && (
          <p className="wb-endpoint-hint">Searching {referenced.pending} referenced files…</p>
        )}
        {referenced.errors > 0 && (
          <p className="wb-endpoint-hint">
            {referenced.errors} referenced files are unavailable; results may be incomplete.
          </p>
        )}
        <VirtualList
          items={items}
          itemHeight={42}
          getItemKey={element => element.id}
          className="wb-element-rows"
          renderItem={element => {
            const name = elementName(element),
              locked = snapshot.locked.has(element.id),
              hidden = snapshot.hidden.has(element.id)
            const endpointHidden =
              element.type === 'edge' &&
              (snapshot.hidden.has(element.from.nodeId ?? '') ||
                snapshot.hidden.has(element.to.nodeId ?? ''))
            return (
              <div className="wb-element-row" data-element-id={element.id}>
                <button
                  className="wb-element-select"
                  aria-label={`Select ${name}`}
                  aria-pressed={snapshot.selected.has(element.id)}
                  disabled={busy}
                  title={`${element.type} · ${element.id}${element.groupId ? ' · Group' : ''}`}
                  onClick={event => {
                    const current = store.getSnapshot()
                    if (!event.shiftKey) store.select(new Set([element.id]))
                    else {
                      const selected = new Set(current.selected)
                      const group = current.document.elements.filter(
                        item =>
                          item.id === element.id ||
                          (element.groupId && item.groupId === element.groupId),
                      )
                      const remove = selected.has(element.id)
                      for (const item of group) {
                        if (remove) selected.delete(item.id)
                        else selected.add(item.id)
                      }
                      store.select(selected)
                    }
                  }}
                  onDoubleClick={() => {
                    if (!hidden) onFocus(element.id)
                  }}
                >
                  <BoardIcon name={element.type === 'shape' ? element.shape : element.type} />
                  <span className="wb-element-label">
                    <span>{name}</span>
                    {element.groupId && <small>Group</small>}
                  </span>
                </button>
                <button
                  aria-label={
                    endpointHidden
                      ? `Hidden endpoint: ${name}`
                      : `${hidden ? 'Show' : 'Hide'} ${name}`
                  }
                  title={
                    endpointHidden
                      ? 'Show the connected nodes first'
                      : hidden
                        ? 'Show group or element'
                        : 'Hide group or element'
                  }
                  disabled={busy || !editable || endpointHidden}
                  onClick={() => store.setFlags(new Set([element.id]), { hidden: !hidden })}
                >
                  <BoardIcon name={hidden ? 'hidden' : 'visible'} />
                </button>
                <button
                  aria-label={`${locked ? 'Unlock' : 'Lock'} ${name}`}
                  title={locked ? 'Unlock group or element' : 'Lock group or element'}
                  disabled={busy || !editable}
                  onClick={() => store.setFlags(new Set([element.id]), { locked: !locked })}
                >
                  <BoardIcon name={locked ? 'lock' : 'unlock'} />
                </button>
              </div>
            )
          }}
        />
        {!items.length && <p>No matching elements.</p>}
      </aside>
    )
  },
  (previous, next) => {
    if (
      previous.busy !== next.busy ||
      previous.editable !== next.editable ||
      previous.resources !== next.resources ||
      previous.store !== next.store ||
      previous.onClose !== next.onClose ||
      previous.onFocus !== next.onFocus
    )
      return false
    const a = previous.snapshot,
      b = next.snapshot
    if (
      a.selected.size !== b.selected.size ||
      [...a.selected].some(id => !b.selected.has(id)) ||
      a.document.elements.length !== b.document.elements.length
    )
      return false
    return a.document.elements.every((element, index) => {
      const other = b.document.elements[index]
      return (
        element.id === other.id &&
        element.type === other.type &&
        element.groupId === other.groupId &&
        element.locked === other.locked &&
        element.hidden === other.hidden &&
        searchable(element) === searchable(other)
      )
    })
  },
)
ElementList.displayName = 'WhiteboardElementList'
