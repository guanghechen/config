import { useStateValue } from '@guanghechen/react-viewmodel'
import React, { useState } from 'react'
import { useDrawboardContext } from '../../context'
import { ToolMode } from '../../context/types'
import {
  ArrowIcon,
  CircleIcon,
  DiamondIcon,
  EraserIcon,
  FrameIcon,
  FreedrawIcon,
  ImageIcon,
  LaserIcon,
  LassoIcon,
  LineIcon,
  PanIcon,
  RectangleIcon,
  SelectIcon,
  TextIcon,
} from '../icons/MaterialIcons'
import { Island, ToolButton } from '../ui'

interface IToolDefinition {
  mode: ToolMode
  icon: React.ComponentType<{ className?: string }>
  label: string
}

const createToolDefinition = (
  mode: ToolMode,
  icon: React.ComponentType<{ className?: string }>,
  label: string,
): IToolDefinition => ({
  mode,
  icon,
  label,
})

// Essential tools for mobile
const MOBILE_TOOLS: IToolDefinition[] = [
  createToolDefinition(ToolMode.SELECT, SelectIcon, 'Select'),
  createToolDefinition(ToolMode.PAN, PanIcon, 'Hand'),
  createToolDefinition(ToolMode.RECTANGLE, RectangleIcon, 'Rectangle'),
  createToolDefinition(ToolMode.CIRCLE, CircleIcon, 'Ellipse'),
  createToolDefinition(ToolMode.ARROW, ArrowIcon, 'Arrow'),
  createToolDefinition(ToolMode.LINE, LineIcon, 'Line'),
  createToolDefinition(ToolMode.FREEDRAW, FreedrawIcon, 'Draw'),
  createToolDefinition(ToolMode.TEXT, TextIcon, 'Text'),
]

// Additional tools that can be accessed via dropdown
const ADDITIONAL_TOOLS: IToolDefinition[] = [
  createToolDefinition(ToolMode.LASSO, LassoIcon, 'Lasso'),
  createToolDefinition(ToolMode.DIAMOND, DiamondIcon, 'Diamond'),
  createToolDefinition(ToolMode.IMAGE, ImageIcon, 'Image'),
  createToolDefinition(ToolMode.ERASER, EraserIcon, 'Eraser'),
  createToolDefinition(ToolMode.FRAME, FrameIcon, 'Frame'),
  createToolDefinition(ToolMode.LASER, LaserIcon, 'Laser'),
]

export const MobileToolbar: React.FC = () => {
  const { ui } = useDrawboardContext()
  const selectedTool = useStateValue(ui.selectedTool$)
  const [showAdditionalTools, setShowAdditionalTools] = useState(false)

  return (
    <div className="fixed bottom-4 left-1/2 -translate-x-1/2 z-30">
      <div className="flex flex-col gap-2">
        {/* Additional Tools Dropdown */}
        {showAdditionalTools && (
          <Island className="flex flex-wrap justify-center gap-1 max-w-xs" padding="sm">
            {ADDITIONAL_TOOLS.map(tool => (
              <ToolButton
                key={tool.mode}
                icon={tool.icon}
                label={tool.label}
                isActive={selectedTool === tool.mode}
                onClick={() => {
                  ui.setTool(tool.mode)
                  setShowAdditionalTools(false)
                }}
                size="large"
                aria-label={`${tool.label} tool`}
              />
            ))}
          </Island>
        )}

        {/* Main Mobile Toolbar */}
        <Island className="flex gap-1" padding="sm">
          {/* Essential Tools */}
          {MOBILE_TOOLS.map(tool => (
            <ToolButton
              key={tool.mode}
              icon={tool.icon}
              label={tool.label}
              isActive={selectedTool === tool.mode}
              onClick={() => ui.setTool(tool.mode)}
              size="large"
              aria-label={`${tool.label} tool`}
            />
          ))}

          {/* More Tools Button */}
          <ToolButton
            icon={() => (
              <svg
                className="h-6 w-6"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                viewBox="0 0 24 24"
              >
                <circle cx="12" cy="12" r="1" />
                <circle cx="19" cy="12" r="1" />
                <circle cx="5" cy="12" r="1" />
              </svg>
            )}
            label="More Tools"
            isActive={showAdditionalTools}
            onClick={() => setShowAdditionalTools(!showAdditionalTools)}
            size="large"
            variant="secondary"
            aria-label="Show more tools"
          />
        </Island>
      </div>
    </div>
  )
}
