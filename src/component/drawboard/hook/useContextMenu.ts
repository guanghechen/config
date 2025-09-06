import React from 'react'
import type { IContextMenuItem } from '../component/ui/ContextMenu'

interface IContextMenuState {
  visible: boolean
  position: { x: number; y: number }
  items: IContextMenuItem[]
}

export const useContextMenu = (): {
  contextMenu: IContextMenuState
  showContextMenu: (event: React.MouseEvent, items: IContextMenuItem[]) => void
  hideContextMenu: () => void
} => {
  const [contextMenu, setContextMenu] = React.useState<IContextMenuState>({
    visible: false,
    position: { x: 0, y: 0 },
    items: [],
  })

  const showContextMenu = (event: React.MouseEvent, items: IContextMenuItem[]): void => {
    event.preventDefault()
    event.stopPropagation()

    const { clientX, clientY } = event

    // Adjust position to prevent menu from going off-screen
    const menuWidth = 200
    const menuHeight = items.length * 40
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight

    let x = clientX
    let y = clientY

    if (x + menuWidth > viewportWidth) {
      x = clientX - menuWidth
    }

    if (y + menuHeight > viewportHeight) {
      y = clientY - menuHeight
    }

    setContextMenu({
      visible: true,
      position: { x, y },
      items: items.filter(item => item !== null) as IContextMenuItem[],
    })
  }

  const hideContextMenu = (): void => {
    setContextMenu(prev => ({ ...prev, visible: false }))
  }

  return {
    contextMenu,
    showContextMenu,
    hideContextMenu,
  }
}
