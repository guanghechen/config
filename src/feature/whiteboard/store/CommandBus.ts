import { IdFactory } from '@/feature/whiteboard/model'
import type { IWhiteboardDocumentData } from '@/feature/whiteboard/model'
import type { HistoryStore } from './HistoryStore'
import type { SceneStore } from './SceneStore'
import type { ICommand, ITransactionRecord } from './types'

interface IActiveTransaction {
  readonly id: string
  readonly label: string
  readonly before: IWhiteboardDocumentData
}

const finalizeCommittedData = (
  before: IWhiteboardDocumentData,
  after: IWhiteboardDocumentData,
): IWhiteboardDocumentData => {
  if (before === after) return after

  return {
    ...after,
    version: before.version + 1,
    meta: {
      ...after.meta,
      updatedAt: Date.now(),
    },
  }
}

export class CommandBus {
  private readonly sceneStore: SceneStore
  private readonly historyStore: HistoryStore
  private activeTransaction: IActiveTransaction | null = null

  constructor(sceneStore: SceneStore, historyStore: HistoryStore) {
    this.sceneStore = sceneStore
    this.historyStore = historyStore
  }

  public execute(command: ICommand): IWhiteboardDocumentData {
    const before = this.sceneStore.getSnapshot().data
    const rawAfter = command.apply(before)

    if (rawAfter === before) {
      return before
    }

    const after = finalizeCommittedData(before, rawAfter)
    this.sceneStore.replaceData(after)
    this.historyStore.push(this.createRecord(command.label, before, after))
    return after
  }

  public beginTransaction(label: string): void {
    if (this.activeTransaction) {
      throw new Error('Transaction already active')
    }

    this.activeTransaction = {
      id: IdFactory.createCommandId(),
      label,
      before: this.sceneStore.getSnapshot().data,
    }
  }

  public updateDraft(mutator: (data: IWhiteboardDocumentData) => IWhiteboardDocumentData): void {
    if (!this.activeTransaction) {
      throw new Error('No active transaction')
    }

    this.sceneStore.updateData(mutator)
  }

  public commitTransaction(labelOverride?: string): IWhiteboardDocumentData {
    const tx = this.activeTransaction
    if (!tx) {
      return this.sceneStore.getSnapshot().data
    }

    this.activeTransaction = null

    const rawAfter = this.sceneStore.getSnapshot().data
    if (rawAfter === tx.before) {
      return rawAfter
    }

    const after = finalizeCommittedData(tx.before, rawAfter)
    this.sceneStore.replaceData(after)
    this.historyStore.push(this.createRecord(labelOverride ?? tx.label, tx.before, after))
    return after
  }

  public rollbackTransaction(): IWhiteboardDocumentData {
    const tx = this.activeTransaction
    if (!tx) {
      return this.sceneStore.getSnapshot().data
    }

    this.activeTransaction = null
    this.sceneStore.replaceData(tx.before)
    return tx.before
  }

  public hasActiveTransaction(): boolean {
    return this.activeTransaction !== null
  }

  public undo(): IWhiteboardDocumentData | null {
    if (this.activeTransaction) {
      this.rollbackTransaction()
    }

    const record = this.historyStore.undo()
    if (!record) return null

    this.sceneStore.replaceData(record.before)
    return record.before
  }

  public redo(): IWhiteboardDocumentData | null {
    if (this.activeTransaction) {
      this.rollbackTransaction()
    }

    const record = this.historyStore.redo()
    if (!record) return null

    this.sceneStore.replaceData(record.after)
    return record.after
  }

  public canUndo(): boolean {
    return this.historyStore.canUndo()
  }

  public canRedo(): boolean {
    return this.historyStore.canRedo()
  }

  private createRecord(
    label: string,
    before: IWhiteboardDocumentData,
    after: IWhiteboardDocumentData,
  ): ITransactionRecord {
    return {
      id: IdFactory.createCommandId(),
      label,
      before,
      after,
      timestamp: Date.now(),
    }
  }
}
