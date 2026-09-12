import React from 'react'
import { TOOLS } from '../../interaction/tools'
import type { ITool } from '../../interaction/tools'
import { BoardIcon } from '../BoardIcon'

const COMPACT_TOOLS = new Set<ITool>(['hand', 'select', 'rectangle', 'text'])

export const DrawingTools = React.memo<{
  tool: ITool
  setTool: (tool: ITool) => void
  locked: boolean
  toggleLock: () => void
  compact: boolean
  menuName: string
}>(({ tool, setTool, locked, toggleLock, compact, menuName }) => (
  <div className="wb-tool-area" data-wb-ui>
    <nav className="wb-tools" aria-label="Drawing tools" data-wb-ui>
      {!compact && (
        <button
          className="wb-tool-lock"
          aria-label="Keep drawing"
          aria-pressed={locked}
          title="Keep drawing (Q)"
          onClick={toggleLock}
        >
          <BoardIcon name={locked ? 'lock' : 'unlock'} />
        </button>
      )}
      {!compact && <span className="wb-tool-divider" aria-hidden="true" />}
      {TOOLS.filter(item => !compact || COMPACT_TOOLS.has(item.id)).map(item => (
        <button
          key={item.id}
          aria-label={item.label}
          aria-pressed={tool === item.id}
          title={`${item.label} (${item.key})`}
          onClick={() => setTool(item.id)}
        >
          <BoardIcon name={item.id} />
          <small>{item.key}</small>
        </button>
      ))}
      {compact && (
        <details className="wb-more-tools" name={menuName}>
          <summary
            aria-label="More tools"
            title="More tools"
            data-active={!COMPACT_TOOLS.has(tool)}
          >
            <BoardIcon name={COMPACT_TOOLS.has(tool) ? 'more' : tool} />
          </summary>
          <div className="wb-more-tools-panel">
            {TOOLS.filter(item => !COMPACT_TOOLS.has(item.id)).map(item => (
              <button
                key={item.id}
                aria-label={item.label}
                aria-pressed={tool === item.id}
                title={`${item.label} (${item.key})`}
                onClick={() => setTool(item.id)}
              >
                <BoardIcon name={item.id} />
                <span>{item.label}</span>
                <small>{item.key}</small>
              </button>
            ))}
            <button
              className="wb-more-lock"
              aria-label="Keep drawing"
              aria-pressed={locked}
              title="Keep drawing (Q)"
              onClick={toggleLock}
            >
              <BoardIcon name={locked ? 'lock' : 'unlock'} />
              <span>Keep drawing</span>
              <small>Q</small>
            </button>
          </div>
        </details>
      )}
    </nav>
    <p className="wb-tool-hint">{TOOLS.find(item => item.id === tool)?.hint}</p>
  </div>
))
DrawingTools.displayName = 'WhiteboardDrawingTools'
