/* eslint-disable no-template-curly-in-string */
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ITextTransformConfig, ITextTransformedNode } from '@/shared/types'
import { validateTransformConfig } from '@/shared/util'
import type { ITextViewData } from './types'
import { ContentModeEnum, ModeEnum } from './types'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly contentMode?: ContentModeEnum
  readonly transformConfig?: ITextTransformConfig
}

const DEFAULT_DATA: ITextViewData = {
  mode: ModeEnum.CONTENT,
  contentMode: ContentModeEnum.ORIGINAL,
  transformConfig: {
    name: 'unnamed',
    desc: "(element, index) => ''",
    split: 'line => line.split(/\\n/g)',
    steps: [],
    uuid: '(item, index) => `item-${index}`',
    parents: '() => []',
    title: "(element, index) => ''",
  },
}

export class TextViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly mode$: IState<ModeEnum>
  public readonly contentMode$: IState<ContentModeEnum>
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
      contentMode = DEFAULT_DATA.contentMode,
      transformConfig = DEFAULT_DATA.transformConfig,
    } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.mode$ = new State<ModeEnum>(mode)
    this.contentMode$ = new State<ContentModeEnum>(contentMode)
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
    const { mode, contentMode, transformConfig } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedContentMode: ContentModeEnum =
      contentMode === ContentModeEnum.ORIGINAL ||
      contentMode === ContentModeEnum.LIST ||
      contentMode === ContentModeEnum.GRAPH
        ? contentMode
        : base.contentMode
    const normalizedTransformConfig: ITextTransformConfig = validateTransformConfig(transformConfig)
      ? transformConfig
      : base.transformConfig!
    const viewData: ITextViewData = {
      mode: normalizedMode,
      contentMode: normalizedContentMode,
      transformConfig: normalizedTransformConfig,
    }
    return viewData
  }

  public dump = (): ITextViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const contentMode: ContentModeEnum = this.contentMode$.getSnapshot()
    const transformConfig: ITextTransformConfig = this.transformConfig$.getSnapshot()
    return { mode, contentMode, transformConfig }
  }

  public load = (data: Partial<ITextViewData> | undefined): void => {
    const base: ITextViewData = this.dump()
    const { mode, contentMode, transformConfig } = TextViewViewModel.normalize(data, base)
    this.mode$.next(mode)
    this.contentMode$.next(contentMode)
    this.transformConfig$.next(transformConfig!)
  }
}
