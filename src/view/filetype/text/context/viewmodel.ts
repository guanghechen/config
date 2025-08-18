/* eslint-disable no-template-curly-in-string */
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ITextTransformConfig, ITextTransformedNode } from '@/shared/types'
import type { IChainPath, ITextViewData } from './types'
import { ModeEnum, ViewModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly viewMode?: ViewModeEnum
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly transformConfig?: ITextTransformConfig
  readonly chainPaths?: IChainPath[]
  readonly activeRecordIndex?: number | null
}

const DEFAULT_TRANSFORM_CONFIG: ITextTransformConfig = {
  name: 'unnamed',
  split: '/\\n/',
  steps: [],
  uuid: '(item, index) => `item-${index}`',
  parents: '() => []',
}

const DEFAULT_TEXT_VIEW_DATA: ITextViewData = {
  mode: ModeEnum.CONTENT,
  viewMode: ViewModeEnum.ORIGINAL,
  transformConfig: DEFAULT_TRANSFORM_CONFIG,
  chainPaths: [],
}

export class TextViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly viewMode$: IState<ViewModeEnum>
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>
  public readonly content$: IState<string | null>
  public readonly contentError: IState<string | null>
  public readonly transformConfig$: IState<ITextTransformConfig>
  public readonly transformedNodes$: IState<ITextTransformedNode[] | null>
  public readonly chainPaths$: IState<IChainPath[]>
  public readonly activeRecordIndex$: IState<number | null>
  public readonly expandTick$: IState<number>

  public static fromData(data: Partial<ITextViewData> | undefined): TextViewViewModel {
    const { mode, viewMode, transformConfig, chainPaths }: ITextViewData = this.normalize(
      DEFAULT_TEXT_VIEW_DATA,
      data,
    )
    return new TextViewViewModel({ mode, viewMode, transformConfig, chainPaths })
  }

  public static normalize(
    base: ITextViewData,
    data: Partial<ITextViewData> | undefined,
  ): ITextViewData {
    const { mode, viewMode, transformConfig, chainPaths } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedViewMode: ViewModeEnum =
      viewMode === ViewModeEnum.ORIGINAL ||
      viewMode === ViewModeEnum.LIST ||
      viewMode === ViewModeEnum.GRAPH
        ? viewMode
        : base.viewMode
    const normalizedTransformConfig: ITextTransformConfig = transformConfig || base.transformConfig!
    const normalizedChainPaths: IChainPath[] = Array.isArray(chainPaths)
      ? chainPaths
      : base.chainPaths
    const normalizedData: ITextViewData = {
      mode: normalizedMode,
      viewMode: normalizedViewMode,
      transformConfig: normalizedTransformConfig,
      chainPaths: normalizedChainPaths,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()

    const {
      mode = ModeEnum.CONTENT,
      viewMode = ViewModeEnum.ORIGINAL,
      workspace = null,
      filepath = null,
      transformConfig = DEFAULT_TRANSFORM_CONFIG,
      chainPaths = [],
      activeRecordIndex = 0,
    } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.viewMode$ = new State<ViewModeEnum>(viewMode)
    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string | null>(filepath)
    this.content$ = new State<string | null>(null)
    this.contentError = new State<string | null>(null)
    this.transformConfig$ = new State<ITextTransformConfig>(transformConfig)
    this.transformedNodes$ = new State<ITextTransformedNode[] | null>(null)
    this.chainPaths$ = new State<IChainPath[]>(chainPaths)
    this.activeRecordIndex$ = new State<number | null>(activeRecordIndex)
    this.expandTick$ = new State<number>(0)
  }

  public dump = (): ITextViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const viewMode: ViewModeEnum = this.viewMode$.getSnapshot()
    const transformConfig: ITextTransformConfig = this.transformConfig$.getSnapshot()
    const chainPaths: IChainPath[] = this.chainPaths$.getSnapshot()
    return {
      mode,
      viewMode,
      transformConfig,
      chainPaths,
    }
  }

  public load = (data: Partial<ITextViewData> | undefined): void => {
    const { mode, viewMode, transformConfig, chainPaths }: ITextViewData =
      TextViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
    this.viewMode$.next(viewMode)
    this.transformConfig$.next(transformConfig!)
    this.chainPaths$.next(chainPaths)
  }
}
