/* eslint-disable no-template-curly-in-string */
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ITextTransformConfig, ITextTransformedNode } from '@/shared/transform/types'
import type { ITextViewData } from './types'
import { ModeEnum, ViewModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly viewMode?: ViewModeEnum
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly transformConfig?: ITextTransformConfig
}

const DEFAULT_TRANSFORM_CONFIG: ITextTransformConfig = {
  name: 'unnamed',
  split: '/\\n/',
  steps: [],
  uuid: '(item, index) => `item-${index}`',
  parents: '() => []',
}

const DEFAULT_TEXT_VIEW_DATA: ITextViewData = {
  mode: ModeEnum.VIEW,
  viewMode: ViewModeEnum.ORIGINAL,
  transformConfig: DEFAULT_TRANSFORM_CONFIG,
}

export class TextViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly viewMode$: IState<ViewModeEnum>
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>
  public readonly content$: IState<string | null>
  public readonly error$: IState<string | null>
  public readonly transformConfig$: IState<ITextTransformConfig>
  public readonly transformedNodes$: IState<ITextTransformedNode[] | null>

  public static fromData(data: Partial<ITextViewData> | undefined): TextViewViewModel {
    const { mode, viewMode, transformConfig }: ITextViewData = this.normalize(
      DEFAULT_TEXT_VIEW_DATA,
      data,
    )
    return new TextViewViewModel({ mode, viewMode, transformConfig })
  }

  public static normalize(
    base: ITextViewData,
    data: Partial<ITextViewData> | undefined,
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
    const normalizedTransformConfig: ITextTransformConfig = transformConfig || base.transformConfig!
    const normalizedData: ITextViewData = {
      mode: normalizedMode,
      viewMode: normalizedViewMode,
      transformConfig: normalizedTransformConfig,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()

    const {
      mode = ModeEnum.VIEW,
      viewMode = ViewModeEnum.ORIGINAL,
      workspace = null,
      filepath = null,
      transformConfig = DEFAULT_TRANSFORM_CONFIG,
    } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.viewMode$ = new State<ViewModeEnum>(viewMode)
    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string | null>(filepath)
    this.content$ = new State<string | null>(null)
    this.error$ = new State<string | null>(null)
    this.transformConfig$ = new State<ITextTransformConfig>(transformConfig)
    this.transformedNodes$ = new State<ITextTransformedNode[] | null>(null)
  }

  public dump = (): ITextViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const viewMode: ViewModeEnum = this.viewMode$.getSnapshot()
    const transformConfig: ITextTransformConfig = this.transformConfig$.getSnapshot()
    return {
      mode,
      viewMode,
      transformConfig,
    }
  }

  public load = (data: Partial<ITextViewData> | undefined): void => {
    const { mode, viewMode, transformConfig }: ITextViewData = TextViewViewModel.normalize(
      this.dump(),
      data,
    )
    this.mode$.next(mode)
    this.viewMode$.next(viewMode)
    this.transformConfig$.next(transformConfig!)
  }
}
