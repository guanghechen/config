import type { IWhiteboardDocumentData } from './data'
import { IdFactory } from './id'

export const createEmptyWhiteboardDocumentData = (
  title: string = 'Untitled',
): IWhiteboardDocumentData => {
  const now = Date.now()

  return {
    id: IdFactory.createDocId(),
    kind: 'yoz.whiteboard',
    schemaVersion: 1,
    version: 1,
    meta: {
      title,
      createdAt: now,
      updatedAt: now,
    },
    graph: {
      viewport: {
        zoom: 1,
        offsetX: 0,
        offsetY: 0,
        gridSize: 24,
        showGrid: false,
      },
      edgeOrder: [],
      nodesById: {},
      portsById: {},
      edgesById: {},
    },
  }
}
