import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../../context'
import { ToolMode } from '../../context/types'
import { getToolNumericShortcut, getToolShortcut } from '../../hook/useKeyboardShortcuts'
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
  LockIcon,
  MoreHorizontalIcon,
  PanIcon,
  RectangleIcon,
  SelectIcon,
  TextIcon,
  UnlockIcon,
} from '../icons/MaterialIcons'
import { Dropdown, Island, ToolButton, ToolSeparator } from '../ui'

interface IToolDefinition {
  mode: ToolMode
  icon: React.ComponentType<{ className?: string }>
  label: string
  shortcut?: string
  numericKey?: string
}

const createToolDefinition = (
  mode: ToolMode,
  icon: React.ComponentType<{ className?: string }>,
  label: string,
): IToolDefinition => ({
  mode,
  icon,
  label,
  shortcut: getToolShortcut(mode),
  numericKey: getToolNumericShortcut(mode),
})

// Main drawing tools following Excalidraw's ShapesSwitcher exact order
const MAIN_TOOLS: IToolDefinition[] = [
  // Exact Excalidraw order - ShapesSwitcher tools
  createToolDefinition(ToolMode.SELECT, SelectIcon, 'Selection'),
  createToolDefinition(ToolMode.RECTANGLE, RectangleIcon, 'Rectangle'),
  createToolDefinition(ToolMode.DIAMOND, DiamondIcon, 'Diamond'),
  createToolDefinition(ToolMode.CIRCLE, CircleIcon, 'Ellipse'),
  createToolDefinition(ToolMode.ARROW, ArrowIcon, 'Arrow'),
  createToolDefinition(ToolMode.LINE, LineIcon, 'Line'),
  createToolDefinition(ToolMode.FREEDRAW, FreedrawIcon, 'Draw'),
  createToolDefinition(ToolMode.TEXT, TextIcon, 'Text'),
  createToolDefinition(ToolMode.IMAGE, ImageIcon, 'Image'),
  createToolDefinition(ToolMode.ERASER, EraserIcon, 'Eraser'),
]

// Extra tools in dropdown (following Excalidraw pattern)
const EXTRA_TOOLS: IToolDefinition[] = [
  createToolDefinition(ToolMode.FRAME, FrameIcon, 'Frame'),
  createToolDefinition(ToolMode.LASER, LaserIcon, 'Laser Pointer'),
  createToolDefinition(ToolMode.LASSO, LassoIcon, 'Lasso Select'),
]

const formatShortcut = (tool: IToolDefinition): string => {
  if (tool.numericKey && tool.shortcut) {
    return `${tool.numericKey}`
  }
  return tool.shortcut?.toUpperCase() || ''
}

export const MainToolbar: React.FC = () => {
  const { viewmodel } = useDrawboardContext()
  const appState = useStateValue(viewmodel.appState$)

  const extraToolItems = EXTRA_TOOLS.map(tool => ({
    id: tool.mode.toString(),
    label: tool.label,
    icon: tool.icon,
    shortcut: formatShortcut(tool),
    onClick: () => viewmodel.setTool(tool.mode),
  }))

  const hasActiveExtraTool = EXTRA_TOOLS.some(tool => appState.selectedTool === tool.mode)

  return (
    <Island className="flex flex-row items-center gap-1" padding="sm">
      <ToolButton
        icon={appState.toolLocked ? LockIcon : UnlockIcon}
        label={appState.toolLocked ? 'Unlock' : 'Lock'}
        isActive={appState.toolLocked}
        onClick={() => viewmodel.toggleToolLock()}
        variant="secondary"
        size="medium"
        aria-label={`${appState.toolLocked ? 'Unlock' : 'Lock'} tool selection`}
      />

      {/* Divider - matches Excalidraw */}
      <ToolSeparator orientation="vertical" />

      {/* Hand Tool - separate like Excalidraw */}
      <ToolButton
        icon={PanIcon}
        label="Hand"
        shortcut={formatShortcut(createToolDefinition(ToolMode.PAN, PanIcon, 'Hand'))}
        numericKey={getToolNumericShortcut(ToolMode.PAN)}
        isActive={appState.selectedTool === ToolMode.PAN}
        onClick={() => viewmodel.setTool(ToolMode.PAN)}
        size="medium"
        aria-label="Hand tool"
      />

      {/* Main Drawing Tools - exact Excalidraw ShapesSwitcher order */}
      {MAIN_TOOLS.map(tool => (
        <ToolButton
          key={tool.mode}
          icon={tool.icon}
          label={tool.label}
          shortcut={formatShortcut(tool)}
          numericKey={tool.numericKey}
          isActive={appState.selectedTool === tool.mode}
          onClick={() => viewmodel.setTool(tool.mode)}
          size="medium"
          aria-label={`${tool.label} tool`}
          aria-keyshortcuts={formatShortcut(tool)}
        />
      ))}

      {/* Divider before extra tools - matches Excalidraw */}
      <ToolSeparator orientation="vertical" />

      {/* Extra Tools Dropdown - matches Excalidraw */}
      <Dropdown
        trigger={
          <ToolButton
            icon={MoreHorizontalIcon}
            label="Extra Tools"
            isActive={hasActiveExtraTool}
            onClick={() => {}} // Dropdown handles the click
            variant="secondary"
            size="medium"
            aria-label="Open extra tools menu"
          />
        }
        items={extraToolItems}
        placement="bottom"
        align="center"
      />
    </Island>
  )
}
