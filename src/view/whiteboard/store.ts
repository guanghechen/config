import { createDocument } from '../../../shared/whiteboard/model.ts'
import type { ICamera, IElement, IWhiteboardDocument } from '../../../shared/whiteboard/model.ts'
import {
  arrangeElements,
  expandSelection,
  groupElements,
  ungroupElements,
} from '../../../shared/whiteboard/organization.ts'
import type { ILayoutAxis, ILayoutMode } from '../../../shared/whiteboard/organization.ts'
import { orderedDocument, reorderElements } from '../../../shared/whiteboard/stacking.ts'
import type { IStackingOrder } from '../../../shared/whiteboard/stacking.ts'
import { applyCommands, removeElements } from '../../../shared/whiteboard/commands.ts'
import { flipElements, rotateElements } from '../../../shared/whiteboard/transforms.ts'
import { duplicateElements } from '../../../shared/whiteboard/geometry.ts'
import {
  changedLockedElement,
  hiddenElements,
  lockedElements,
  removalIds,
  setElementFlags,
} from '../../../shared/whiteboard/visibility.ts'

export interface IBoardSnapshot {
  readonly document: IWhiteboardDocument
  readonly selected: ReadonlySet<string>
  readonly camera: ICamera
  readonly locked: ReadonlySet<string>
  readonly hidden: ReadonlySet<string>
}

export class BoardStore {
  private snapshot: IBoardSnapshot
  private listeners = new Set<() => void>()
  private past: IWhiteboardDocument[] = []
  private future: IWhiteboardDocument[] = []
  private transaction: IWhiteboardDocument | null = null
  private committed: IWhiteboardDocument
  private normalize: (document: IWhiteboardDocument) => IWhiteboardDocument

  constructor(
    document: IWhiteboardDocument = createDocument(),
    normalize = (value: IWhiteboardDocument): IWhiteboardDocument => value,
  ) {
    this.normalize = normalize
    this.committed = normalize(orderedDocument(document))
    this.snapshot = {
      document: this.committed,
      selected: new Set(),
      camera: { x: 0, y: 0, zoom: 1 },
      locked: lockedElements(this.committed.elements),
      hidden: hiddenElements(this.committed.elements),
    }
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
    this.snapshot = {
      ...this.snapshot,
      ...update,
      ...(update.document
        ? {
            locked: lockedElements(update.document.elements),
            hidden: hiddenElements(update.document.elements),
          }
        : {}),
    }
    for (const listener of this.listeners) listener()
  }
  public select = (selected: ReadonlySet<string>): void => {
    this.publish({ selected: expandSelection(this.snapshot.document.elements, selected) })
  }
  public canEditSelection = (): boolean =>
    this.snapshot.selected.size > 0 &&
    ![...this.snapshot.selected].some(id => this.snapshot.locked.has(id))
  public canRemoveSelection = (): boolean =>
    this.canEditSelection() &&
    ![...removalIds(this.snapshot.document.elements, this.snapshot.selected)].some(id =>
      this.snapshot.locked.has(id),
    )
  public duplicateSelected = (): void => {
    const { document, selected } = this.snapshot
    const copies = duplicateElements(document.elements, selected)
    this.commit({ ...document, elements: [...document.elements, ...copies] })
    this.select(new Set(copies.map(element => element.id)))
  }
  public setSelectedFlags = (flags: { locked?: boolean; hidden?: boolean }): void => {
    const { document, selected } = this.snapshot
    this.commitChange(
      { ...document, elements: setElementFlags(document.elements, selected, flags) },
      false,
    )
  }
  public setFlags = (
    ids: ReadonlySet<string>,
    flags: { locked?: boolean; hidden?: boolean },
  ): void => {
    const { document } = this.snapshot
    this.commitChange(
      {
        ...document,
        elements: setElementFlags(
          document.elements,
          expandSelection(document.elements, ids),
          flags,
        ),
      },
      false,
    )
  }
  public groupSelected = (): void => {
    if (!this.canEditSelection()) return
    const { document, selected } = this.snapshot
    this.commit({
      ...document,
      elements: groupElements(document.elements, selected, crypto.randomUUID()),
    })
  }
  public ungroupSelected = (): void => {
    if (!this.canEditSelection()) return
    const { document, selected } = this.snapshot
    this.commit({ ...document, elements: ungroupElements(document.elements, selected) })
  }
  public arrangeSelected = (axis: ILayoutAxis, mode: ILayoutMode): void => {
    if (!this.canEditSelection()) return
    const { document, selected } = this.snapshot
    this.commit({ ...document, elements: arrangeElements(document.elements, selected, axis, mode) })
  }
  public reorderSelected = (order: IStackingOrder): void => {
    if (!this.canEditSelection()) return
    const { document, selected } = this.snapshot
    const elements = reorderElements(document.elements, selected, order)
    if (elements !== document.elements) this.commit({ ...document, elements })
  }
  public camera = (camera: ICamera): void => {
    this.publish({ camera })
  }
  public rotateSelected = (degrees: number): void => {
    if (!this.canEditSelection()) return
    const { document, selected } = this.snapshot
    this.commit({ ...document, elements: rotateElements(document.elements, selected, degrees) })
  }
  public flipSelected = (axis: 'x' | 'y'): void => {
    if (!this.canEditSelection()) return
    const { document, selected } = this.snapshot
    this.commit({ ...document, elements: flipElements(document.elements, selected, axis) })
  }
  public begin = (): void => {
    this.transaction ??= this.committed
  }
  public preview = (elements: ReadonlyArray<IElement>): void => {
    if (changedLockedElement(this.committed.elements, elements)) return
    this.begin()
    this.publish({ document: this.normalize({ ...this.snapshot.document, elements }) })
  }
  public commit = (document: IWhiteboardDocument = this.snapshot.document): void => {
    this.commitChange(document, true)
  }
  private commitChange(document: IWhiteboardDocument, guarded: boolean): void {
    const normalized = this.normalize(orderedDocument(document))
    const previous = this.transaction ?? this.committed
    if (guarded && changedLockedElement(previous.elements, normalized.elements)) {
      this.cancel()
      return
    }
    this.transaction = null
    if (normalized === previous || JSON.stringify(normalized) === JSON.stringify(previous)) {
      this.publish({ document: previous })
      return
    }
    this.past.push(previous)
    if (this.past.length > 100) this.past.shift()
    this.future = []
    this.committed = normalized
    this.publish({ document: normalized })
  }
  public cancel = (): void => {
    this.transaction = null
    this.publish({ document: this.committed })
  }
  public replace = (document: IWhiteboardDocument): void => {
    this.transaction = null
    this.past = []
    this.future = []
    this.committed = this.normalize(orderedDocument(document))
    this.publish({ document: this.committed, selected: new Set() })
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
    if (!this.canRemoveSelection()) return
    const { document, selected } = this.snapshot
    const elements = removeElements(document.elements, selected)
    this.commit({ ...document, elements })
    this.select(new Set())
  }
  public applyCommands = (batch: unknown): void => {
    this.commitChange(applyCommands(this.snapshot.document, batch), false)
    const ids = new Set(this.snapshot.document.elements.map(element => element.id))
    this.select(new Set([...this.snapshot.selected].filter(id => ids.has(id))))
  }
}
