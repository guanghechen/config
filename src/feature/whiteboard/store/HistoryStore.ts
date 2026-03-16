import type { ITransactionRecord } from './types'

const DEFAULT_HISTORY_LIMIT = 100

export class HistoryStore {
  private readonly limit: number
  private readonly undoStack: ITransactionRecord[] = []
  private readonly redoStack: ITransactionRecord[] = []

  constructor(limit: number = DEFAULT_HISTORY_LIMIT) {
    this.limit = limit
  }

  public push(record: ITransactionRecord): void {
    this.undoStack.push(record)
    this.redoStack.length = 0

    if (this.undoStack.length > this.limit) {
      this.undoStack.shift()
    }
  }

  public undo(): ITransactionRecord | null {
    const record = this.undoStack.pop()
    if (!record) return null

    this.redoStack.push(record)
    return record
  }

  public redo(): ITransactionRecord | null {
    const record = this.redoStack.pop()
    if (!record) return null

    this.undoStack.push(record)
    return record
  }

  public canUndo(): boolean {
    return this.undoStack.length > 0
  }

  public canRedo(): boolean {
    return this.redoStack.length > 0
  }

  public clear(): void {
    this.undoStack.length = 0
    this.redoStack.length = 0
  }

  public getUndoSize(): number {
    return this.undoStack.length
  }

  public getRedoSize(): number {
    return this.redoStack.length
  }
}
