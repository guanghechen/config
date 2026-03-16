import type { IWhiteboardDocumentData } from '@/feature/whiteboard/model'

export interface ICommand {
  readonly type: string
  readonly label: string
  apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData
}

export interface ITransactionRecord {
  readonly id: string
  readonly label: string
  readonly before: IWhiteboardDocumentData
  readonly after: IWhiteboardDocumentData
  readonly timestamp: number
}
