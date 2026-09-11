import React from 'react'
import { TOOLS } from './interaction'
import type { ITool } from './interaction'

export const DrawingTools = React.memo<{ tool: ITool; setTool: (tool: ITool) => void }>(
  ({ tool, setTool }) => (
    <nav className="wb-tools" aria-label="Drawing tools" data-wb-ui>
      {TOOLS.map(item => (
        <button
          key={item.id}
          aria-label={item.label}
          aria-pressed={tool === item.id}
          title={`${item.label} (${item.key})`}
          onClick={() => setTool(item.id)}
        >
          <span>
            {item.id === 'hand' ? (
              <svg
                width="23"
                height="23"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
                aria-hidden="true"
              >
                <path d="M8 12V6a1.5 1.5 0 0 1 3 0v5-7a1.5 1.5 0 0 1 3 0v7-5a1.5 1.5 0 0 1 3 0v6-3a1.5 1.5 0 0 1 3 0v6c0 4-2 7-6 7h-1c-2 0-4-1-5-3l-4-6a1.5 1.5 0 0 1 2-2l2 2Z" />
              </svg>
            ) : (
              item.icon
            )}
          </span>
          <small>{item.key}</small>
        </button>
      ))}
    </nav>
  ),
)
DrawingTools.displayName = 'WhiteboardDrawingTools'
