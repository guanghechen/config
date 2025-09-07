import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../../context'
import { ToolMode } from '../../context/types'
import { useContextMenu } from '../../hook/useContextMenu'
import {
  ArrowIcon,
  CircleIcon,
  ExportIcon,
  GridIcon,
  LineIcon,
  RectangleIcon,
} from '../icons/MaterialIcons'
import { ContextMenu, type IContextMenuItem } from '../ui/ContextMenu'

export const DrawboardContextMenu: React.FC = () => {
  const { ui, grid, layers, history } = useDrawboardContext()
  const backgroundColor = useStateValue(ui.backgroundColor$)
  const gridVisible = useStateValue(grid.visible$)
  const { contextMenu, showContextMenu, hideContextMenu } = useContextMenu()

  const getContextMenuItems = React.useCallback((): IContextMenuItem[] => {
    const layerData = history.layerData$.getSnapshot()
    if (!layerData) return []

    const allElements = layers.allElements$.getSnapshot()
    const selectedElements = ui.getSelectedElements(allElements)

    const items: Array<IContextMenuItem | null> = []

    // Drawing tools section
    items.push({
      id: 'rectangle',
      label: 'Rectangle',
      icon: RectangleIcon,
      shortcut: 'R',
      action: () => ui.setTool(ToolMode.RECTANGLE),
    })

    items.push({
      id: 'circle',
      label: 'Ellipse',
      icon: CircleIcon,
      shortcut: 'O',
      action: () => ui.setTool(ToolMode.CIRCLE),
    })

    items.push({
      id: 'arrow',
      label: 'Arrow',
      icon: ArrowIcon,
      shortcut: 'A',
      action: () => ui.setTool(ToolMode.ARROW),
    })

    items.push({
      id: 'line',
      label: 'Line',
      icon: LineIcon,
      shortcut: 'L',
      action: () => ui.setTool(ToolMode.LINE),
    })

    // Separator
    items.push({ id: 'sep1', label: '', separator: true, action: () => {} })

    // Element actions (only if elements are selected)
    if (selectedElements.length > 0) {
      items.push({
        id: 'duplicate',
        label: `Duplicate ${selectedElements.length} element${selectedElements.length > 1 ? 's' : ''}`,
        shortcut: 'Ctrl+D',
        action: () => {
          ui.duplicateSelectedElements(allElements, duplicatedElements => {
            if (duplicatedElements.length > 0) {
              layers.addElementsToActiveLayer(duplicatedElements)
              const newLayerData = layers.dump()
              history.updateLayerData(newLayerData)
              history.saveToHistory()
            }
          })
        },
      })

      items.push({
        id: 'delete',
        label: `Delete ${selectedElements.length} element${selectedElements.length > 1 ? 's' : ''}`,
        shortcut: 'Delete',
        action: () => {
          ui.deleteSelectedElements(allElements, () => {
            const elementIds = selectedElements.map(el => el.id)
            layers.removeElementsFromActiveLayer(elementIds)
            const newLayerData = layers.dump()
            history.updateLayerData(newLayerData)
            history.saveToHistory()
          })
        },
      })

      items.push({ id: 'sep2', label: '', separator: true, action: () => {} })
    }

    // View actions
    items.push({
      id: 'toggle-grid',
      label: gridVisible ? 'Hide Grid' : 'Show Grid',
      icon: GridIcon,
      shortcut: "Ctrl+'",
      action: () => grid.toggleGridVisibility(),
    })

    items.push({
      id: 'zoom-to-fit',
      label: 'Zoom to Fit',
      shortcut: 'Ctrl+0',
      action: () => ui.zoomToFit(allElements),
    })

    items.push({ id: 'sep3', label: '', separator: true, action: () => {} })

    // Export
    items.push({
      id: 'export',
      label: 'Export as PNG',
      icon: ExportIcon,
      shortcut: 'Ctrl+E',
      action: () => {
        void (async (): Promise<void> => {
          try {
            const layerData = history.layerData$.getSnapshot()
            if (!layerData) return

            const allElements = layers.allElements$.getSnapshot()
            const { exportToPNG } = await import('../../util/export')
            const blob = await exportToPNG(allElements, {
              backgroundColor,
            })
            const url = URL.createObjectURL(blob)
            const a = document.createElement('a')
            a.href = url
            a.download = 'drawboard-drawing.png'
            a.click()
            URL.revokeObjectURL(url)
          } catch (error) {
            console.error('Export failed:', error)
          }
        })()
      },
    })

    return items.filter(Boolean) as IContextMenuItem[]
  }, [ui, grid, layers, history, gridVisible, backgroundColor])

  // Expose the context menu trigger for use in canvas components
  React.useEffect(() => {
    const updateContextMenu = (): void => {
      ;(ui as any).showContextMenu = (event: React.MouseEvent) => {
        showContextMenu(event, getContextMenuItems())
      }
    }
    updateContextMenu()
  }, [showContextMenu, ui, getContextMenuItems])

  return (
    <ContextMenu
      items={contextMenu.items}
      position={contextMenu.position}
      visible={contextMenu.visible}
      onClose={hideContextMenu}
    />
  )
}
