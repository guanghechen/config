import { createDocument } from '../../../shared/whiteboard/model.ts'
import type { ICamera, IElement, IWhiteboardDocument } from '../../../shared/whiteboard/model.ts'
import {
  arrangeElements,
  expandSelection,
  groupElements,
  ungroupElements,
} from '../../../shared/whiteboard/organization.ts'
import type { ILayoutAxis, ILayoutMode } from '../../../shared/whiteboard/organization.ts'
import { reorderElements } from '../../../shared/whiteboard/stacking.ts'
import type { IStackingOrder } from '../../../shared/whiteboard/stacking.ts'

export interface IBoardSnapshot {
  readonly document: IWhiteboardDocument
  readonly selected: ReadonlySet<string>
  readonly camera: ICamera
}

export class BoardStore {
  private snapshot: IBoardSnapshot
  private listeners = new Set<() => void>()
  private past: IWhiteboardDocument[] = []
  private future: IWhiteboardDocument[] = []
  private transaction: IWhiteboardDocument | null = null
  private committed: IWhiteboardDocument

  constructor(document: IWhiteboardDocument = createDocument()) {
    this.committed = document
    this.snapshot = { document, selected: new Set(), camera: { x: 0, y: 0, zoom: 1 } }
  }

  public getSnapshot = (): IBoardSnapshot => this.snapshot
  public getDocument = (): IWhiteboardDocument => this.committed
  public subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener)
    return () => {
      this.listeners.delete(listener)
    }
  }
  private publish(update: Partial<IBoardSnapshot>): void {
    this.snapshot = { ...this.snapshot, ...update }
    for (const listener of this.listeners) listener()
  }
  public select = (selected: ReadonlySet<string>): void => {
    this.publish({ selected: expandSelection(this.snapshot.document.elements, selected) })
  }
  public groupSelected = (): void => {
    const { document, selected } = this.snapshot
    this.commit({
      ...document,
      elements: groupElements(document.elements, selected, crypto.randomUUID()),
    })
  }
  public ungroupSelected = (): void => {
    const { document, selected } = this.snapshot
    this.commit({ ...document, elements: ungroupElements(document.elements, selected) })
  }
  public arrangeSelected = (axis: ILayoutAxis, mode: ILayoutMode): void => {
    const { document, selected } = this.snapshot
    this.commit({ ...document, elements: arrangeElements(document.elements, selected, axis, mode) })
  }
  public reorderSelected = (order: IStackingOrder): void => {
    const { document, selected } = this.snapshot
    const elements = reorderElements(document.elements, selected, order)
    if (elements !== document.elements) this.commit({ ...document, elements })
  }
  public camera = (camera: ICamera): void => {
    this.publish({ camera })
  }
  public begin = (): void => {
    this.transaction ??= this.committed
  }
  public preview = (elements: ReadonlyArray<IElement>): void => {
    this.begin()
    this.publish({ document: { ...this.snapshot.document, elements } })
  }
  public commit = (document: IWhiteboardDocument = this.snapshot.document): void => {
    const previous = this.transaction ?? this.committed
    this.transaction = null
    if (document === previous || JSON.stringify(document) === JSON.stringify(previous)) {
      this.publish({ document: previous })
      return
    }
    this.past.push(previous)
    if (this.past.length > 100) this.past.shift()
    this.future = []
    this.committed = document
    this.publish({ document })
  }
  public cancel = (): void => {
    this.transaction = null
    this.publish({ document: this.committed })
  }
  public replace = (document: IWhiteboardDocument): void => {
    this.transaction = null
    this.past = []
    this.future = []
    this.committed = document
    this.publish({ document, selected: new Set() })
  }
  public undo = (): void => {
    if (this.transaction) {
      this.cancel()
      return
    }
    const document = this.past.pop()
    if (!document) return
    this.future.push(this.committed)
    this.committed = document
    this.publish({ document, selected: new Set() })
  }
  public redo = (): void => {
    const document = this.future.pop()
    if (!document) return
    this.past.push(this.committed)
    this.committed = document
    this.publish({ document, selected: new Set() })
  }
  public removeSelected = (): void => {
    const { document, selected } = this.snapshot
    const elements = document.elements.filter(
      element =>
        !selected.has(element.id) &&
        !(
          element.type === 'edge' &&
          (selected.has(element.from.nodeId ?? '') || selected.has(element.to.nodeId ?? ''))
        ),
    )
    this.commit({ ...document, elements })
    this.select(new Set())
  }
}
