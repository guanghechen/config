import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IState } from '@guanghechen/react-viewmodel'
import type { ILayerManagerData } from './layers'

export interface IHistoryState {
  readonly layerData: ILayerManagerData
}

interface IProps {
  maxHistorySize?: number
}

export class HistoryViewModel extends ViewModel {
  public readonly layerData$: IState<ILayerManagerData | null>

  private history: IHistoryState[] = []
  private historyIndex = -1
  private readonly maxHistorySize: number

  constructor(props: IProps = {}) {
    super()

    const { maxHistorySize = 50 } = props
    this.maxHistorySize = maxHistorySize
    this.layerData$ = new State<ILayerManagerData | null>(null)
  }

  public initializeWith = (initialLayerData: ILayerManagerData): void => {
    this.layerData$.next(initialLayerData)
    this.pushToHistory()
  }

  private pushToHistory = (): void => {
    const layerData = this.layerData$.getSnapshot()

    if (!layerData) return

    const currentState: IHistoryState = {
      layerData: structuredClone(layerData),
    }

    this.history = this.history.slice(0, this.historyIndex + 1)
    this.history.push(currentState)

    if (this.history.length > this.maxHistorySize) {
      this.history = this.history.slice(-this.maxHistorySize)
      this.historyIndex = this.maxHistorySize - 1
    } else {
      this.historyIndex = this.history.length - 1
    }
  }

  private restoreFromHistory = (state: IHistoryState): void => {
    this.layerData$.next(structuredClone(state.layerData))
  }

  public saveToHistory = (): void => {
    this.pushToHistory()
  }

  public updateLayerData = (layerData: ILayerManagerData): void => {
    this.layerData$.next(layerData)
  }

  public undo = (): void => {
    if (this.historyIndex > 0) {
      this.historyIndex--
      this.restoreFromHistory(this.history[this.historyIndex])
    }
  }

  public redo = (): void => {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++
      this.restoreFromHistory(this.history[this.historyIndex])
    }
  }

  public canUndo = (): boolean => this.historyIndex > 0

  public canRedo = (): boolean => this.historyIndex < this.history.length - 1

  public clearHistory = (): void => {
    this.history = []
    this.historyIndex = -1
    const layerData = this.layerData$.getSnapshot()
    if (layerData) {
      this.pushToHistory()
    }
  }
}
