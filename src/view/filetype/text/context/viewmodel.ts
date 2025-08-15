import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { INode, ITextViewData, ITransformConfig } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly transformConfig?: ITransformConfig
}

const DEFAULT_TRANSFORM_CONFIG: ITransformConfig = {
  split: '/\\n/',
  transformers: [],
  uuidFunction: '(item, index) => `item-${index}`',
  parentUuidFunction: '() => null',
}

const DEFAULT_TEXT_VIEW_DATA: ITextViewData = {
  mode: ModeEnum.VIEW,
  transformConfig: DEFAULT_TRANSFORM_CONFIG,
}

export class TextViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>
  public readonly content$: IState<string | null>
  public readonly error$: IState<string | null>
  public readonly transformConfig$: IState<ITransformConfig>
  public readonly transformedNodes$: IState<INode[] | null>

  public static fromData(data: Partial<ITextViewData> | undefined): TextViewViewModel {
    const { mode, transformConfig }: ITextViewData = this.normalize(DEFAULT_TEXT_VIEW_DATA, data)
    return new TextViewViewModel({ mode, transformConfig })
  }

  public static normalize(
    base: ITextViewData,
    data: Partial<ITextViewData> | undefined,
  ): ITextViewData {
    const { mode, transformConfig } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedTransformConfig: ITransformConfig = transformConfig || base.transformConfig!
    const normalizedData: ITextViewData = {
      mode: normalizedMode,
      transformConfig: normalizedTransformConfig,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()

    const {
      mode = ModeEnum.VIEW,
      workspace = null,
      filepath = null,
      transformConfig = DEFAULT_TRANSFORM_CONFIG,
    } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string | null>(filepath)
    this.content$ = new State<string | null>(null)
    this.error$ = new State<string | null>(null)
    this.transformConfig$ = new State<ITransformConfig>(transformConfig)
    this.transformedNodes$ = new State<INode[] | null>(null)
  }

  public dump = (): ITextViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const transformConfig: ITransformConfig = this.transformConfig$.getSnapshot()
    return {
      mode,
      transformConfig,
    }
  }

  public load = (data: Partial<ITextViewData> | undefined): void => {
    const { mode, transformConfig }: ITextViewData = TextViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
    this.transformConfig$.next(transformConfig!)
  }
}
