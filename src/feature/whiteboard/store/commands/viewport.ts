import type { ICanvasViewport, IWhiteboardDocumentData } from '@/feature/whiteboard/model'
import { WHITEBOARD_ZOOM } from '@/feature/whiteboard/model'
import type { ICommand } from '../types'

const clampZoom = (zoom: number): number => {
  return Math.max(WHITEBOARD_ZOOM.MIN, Math.min(WHITEBOARD_ZOOM.MAX, zoom))
}

export const createSetZoomCommand = (zoom: number): ICommand => {
  return {
    type: 'SET_ZOOM',
    label: 'Set zoom',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      const nextZoom = clampZoom(zoom)
      if (data.graph.viewport.zoom === nextZoom) return data

      return {
        ...data,
        graph: {
          ...data.graph,
          viewport: {
            ...data.graph.viewport,
            zoom: nextZoom,
          },
        },
      }
    },
  }
}

export const createPanViewportCommand = (deltaX: number, deltaY: number): ICommand => {
  return {
    type: 'PAN_VIEWPORT',
    label: 'Pan viewport',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      if (deltaX === 0 && deltaY === 0) return data

      return {
        ...data,
        graph: {
          ...data.graph,
          viewport: {
            ...data.graph.viewport,
            offsetX: data.graph.viewport.offsetX + deltaX,
            offsetY: data.graph.viewport.offsetY + deltaY,
          },
        },
      }
    },
  }
}

export const createSetViewportCommand = (nextViewport: Partial<ICanvasViewport>): ICommand => {
  return {
    type: 'SET_VIEWPORT',
    label: 'Set viewport',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      const nextZoom =
        typeof nextViewport.zoom === 'number'
          ? clampZoom(nextViewport.zoom)
          : data.graph.viewport.zoom

      const offsetX =
        typeof nextViewport.offsetX === 'number'
          ? nextViewport.offsetX
          : data.graph.viewport.offsetX
      const offsetY =
        typeof nextViewport.offsetY === 'number'
          ? nextViewport.offsetY
          : data.graph.viewport.offsetY

      const gridSize =
        typeof nextViewport.gridSize === 'number'
          ? nextViewport.gridSize
          : data.graph.viewport.gridSize
      const showGrid =
        typeof nextViewport.showGrid === 'boolean'
          ? nextViewport.showGrid
          : data.graph.viewport.showGrid

      if (
        nextZoom === data.graph.viewport.zoom &&
        offsetX === data.graph.viewport.offsetX &&
        offsetY === data.graph.viewport.offsetY &&
        gridSize === data.graph.viewport.gridSize &&
        showGrid === data.graph.viewport.showGrid
      ) {
        return data
      }

      return {
        ...data,
        graph: {
          ...data.graph,
          viewport: {
            ...data.graph.viewport,
            zoom: nextZoom,
            offsetX,
            offsetY,
            gridSize,
            showGrid,
          },
        },
      }
    },
  }
}
