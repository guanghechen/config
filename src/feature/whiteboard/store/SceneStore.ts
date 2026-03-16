import type { IWhiteboardDocument, IWhiteboardDocumentData } from '@/feature/whiteboard/model'
import { hydrateDocument } from '@/feature/whiteboard/runtime'

type ISceneListener = (snapshot: IWhiteboardDocument) => void

export class SceneStore {
  private snapshot: IWhiteboardDocument
  private readonly listeners = new Set<ISceneListener>()

  constructor(initialData: IWhiteboardDocumentData) {
    this.snapshot = hydrateDocument(initialData)
  }

  public getSnapshot(): IWhiteboardDocument {
    return this.snapshot
  }

  public updateData(
    updater: (current: IWhiteboardDocumentData) => IWhiteboardDocumentData,
  ): IWhiteboardDocument {
    const nextData = updater(this.snapshot.data)
    this.snapshot = hydrateDocument(nextData)
    this.emit()
    return this.snapshot
  }

  public replaceData(data: IWhiteboardDocumentData): IWhiteboardDocument {
    this.snapshot = hydrateDocument(data)
    this.emit()
    return this.snapshot
  }

  public subscribe(listener: ISceneListener): () => void {
    this.listeners.add(listener)

    return (): void => {
      this.listeners.delete(listener)
    }
  }

  private emit(): void {
    for (const listener of this.listeners) {
      listener(this.snapshot)
    }
  }
}
