/* eslint-disable no-template-curly-in-string */
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ITextTransformConfig, ITextTransformedNode } from '@/shared/types'
import { validateTransformConfig } from '@/shared/util'
import type { ITextViewData } from './types'
import { ModeEnum, ViewModeEnum } from './types'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly viewMode?: ViewModeEnum
  readonly transformConfig?: ITextTransformConfig
}

const DEFAULT_DATA: ITextViewData = {
  mode: ModeEnum.CONTENT,
  viewMode: ViewModeEnum.ORIGINAL,
  transformConfig: {
    name: 'unnamed',
    split: '/\\n/',
    steps: [],
    uuid: '(item, index) => `item-${index}`',
    parents: '() => []',
  },
}

export class TextViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly mode$: IState<ModeEnum>
  public readonly viewMode$: IState<ViewModeEnum>
  public readonly transformConfig$: IState<ITextTransformConfig>

  public readonly content$: IState<string | null>
  public readonly records$: IState<ITextTransformedNode[]>
  public readonly activeRecordIndex$: IState<number>
  public readonly expandTick$: IState<number>

  constructor(props: IProps) {
    super()

    const {
      workspace,
      filepath,
      mode = DEFAULT_DATA.mode,
      viewMode = DEFAULT_DATA.viewMode,
      transformConfig = DEFAULT_DATA.transformConfig,
    } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.mode$ = new State<ModeEnum>(mode)
    this.viewMode$ = new State<ViewModeEnum>(viewMode)
    this.transformConfig$ = new State<ITextTransformConfig>(transformConfig)

    this.content$ = new State<string | null>(null)
    this.records$ = new State<ITextTransformedNode[]>([])
    this.activeRecordIndex$ = new State<number>(0)
    this.expandTick$ = new State<number>(0)
  }

  public static normalize(
    data: Partial<ITextViewData> | undefined,
    base: ITextViewData = DEFAULT_DATA,
  ): ITextViewData {
    const { mode, viewMode, transformConfig } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedViewMode: ViewModeEnum =
      viewMode === ViewModeEnum.ORIGINAL ||
      viewMode === ViewModeEnum.LIST ||
      viewMode === ViewModeEnum.GRAPH
        ? viewMode
        : base.viewMode
    const normalizedTransformConfig: ITextTransformConfig = validateTransformConfig(transformConfig)
      ? transformConfig
      : base.transformConfig!
    const viewData: ITextViewData = {
      mode: normalizedMode,
      viewMode: normalizedViewMode,
      transformConfig: normalizedTransformConfig,
    }
    return viewData
  }

  public dump = (): ITextViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const viewMode: ViewModeEnum = this.viewMode$.getSnapshot()
    const transformConfig: ITextTransformConfig = this.transformConfig$.getSnapshot()
    return { mode, viewMode, transformConfig }
  }

  public load = (data: Partial<ITextViewData> | undefined): void => {
    const base: ITextViewData = this.dump()
    const { mode, viewMode, transformConfig } = TextViewViewModel.normalize(data, base)
    this.mode$.next(mode)
    this.viewMode$.next(viewMode)
    this.transformConfig$.next(transformConfig!)
  }
}
