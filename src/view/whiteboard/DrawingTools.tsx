import React from 'react'
import { TOOLS } from './tools'
import type { ITool } from './tools'
import { BoardIcon } from './BoardIcon'

export const DrawingTools = React.memo<{
  tool: ITool
  setTool: (tool: ITool) => void
  locked: boolean
  toggleLock: () => void
}>(({ tool, setTool, locked, toggleLock }) => (
  <div className="wb-tool-area" data-wb-ui>
    <nav className="wb-tools" aria-label="Drawing tools" data-wb-ui>
      <button
        className="wb-tool-lock"
        aria-label="Keep drawing"
        aria-pressed={locked}
        title="Keep drawing (Q)"
        onClick={toggleLock}
      >
        <BoardIcon name={locked ? 'lock' : 'unlock'} />
      </button>
      <span className="wb-tool-divider" aria-hidden="true" />
      {TOOLS.map(item => (
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
    </nav>
    <p className="wb-tool-hint">{TOOLS.find(item => item.id === tool)?.hint}</p>
  </div>
))
DrawingTools.displayName = 'WhiteboardDrawingTools'
