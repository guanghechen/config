/* eslint-disable no-template-curly-in-string */
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ITextTransformConfig, ITextTransformedNode } from '@/shared/types'
import { validateTransformConfig } from '@/shared/util'
import type { ITextViewData } from './types'
import { ContentModeEnum, ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly contentMode?: ContentModeEnum
  readonly nodeDetailsPaneWidth?: number
  readonly transformConfig?: ITextTransformConfig
}

const DEFAULT_DATA: ITextViewData = {
  mode: ModeEnum.CONTENT,
  contentMode: ContentModeEnum.PLAIN,
  nodeDetailsPaneWidth: 480,
  transformConfig: {
    name: 'unnamed',
    desc: "(element, index) => ''",
    split: 'line => line.split(/\\n/g)',
    steps: [],
    uuid: '(item, index, items) => `item-${index}`',
    parents: '(item, index, items) => []',
    parents_virtual: '(item, index, items) => []',
    title: "(element, index) => ''",
  },
}

export class TextViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly contentMode$: IState<ContentModeEnum>
  public readonly nodeDetailsPaneWidth$: IState<number>
  public readonly transformConfig$: IState<ITextTransformConfig>

  public readonly content$: IState<string | null>
  public readonly records$: IState<ITextTransformedNode[]>
  public readonly activeRecordIndex$: IState<number>
  public readonly expandTick$: IState<number>

  constructor(props: IProps) {
    super()

    const {
      mode = DEFAULT_DATA.mode,
      contentMode = DEFAULT_DATA.contentMode,
      nodeDetailsPaneWidth = DEFAULT_DATA.nodeDetailsPaneWidth!,
      transformConfig = DEFAULT_DATA.transformConfig,
    } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.contentMode$ = new State<ContentModeEnum>(contentMode)
    this.nodeDetailsPaneWidth$ = new State<number>(nodeDetailsPaneWidth)
    this.transformConfig$ = new State<ITextTransformConfig>(transformConfig)

    this.content$ = new State<string | null>(null)
    this.records$ = new State<ITextTransformedNode[]>([])
    this.activeRecordIndex$ = new State<number>(0)
    this.expandTick$ = new State<number>(0)
  }

  public static normalize(
    data: Partial<ITextViewData> | null | undefined,
    base: ITextViewData = DEFAULT_DATA,
  ): ITextViewData {
    const { mode, contentMode, nodeDetailsPaneWidth, transformConfig } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedContentMode: ContentModeEnum =
      contentMode === ContentModeEnum.PLAIN ||
      contentMode === ContentModeEnum.LIST ||
      contentMode === ContentModeEnum.GRAPH
        ? contentMode
        : base.contentMode
    const normalizedNodeDetailsPaneWidth: number =
      typeof nodeDetailsPaneWidth === 'number' && nodeDetailsPaneWidth >= 320
        ? nodeDetailsPaneWidth
        : base.nodeDetailsPaneWidth!
    const normalizedTransformConfig: ITextTransformConfig = validateTransformConfig(transformConfig)
      ? transformConfig
      : base.transformConfig!
    const viewData: ITextViewData = {
      mode: normalizedMode,
      contentMode: normalizedContentMode,
      nodeDetailsPaneWidth: normalizedNodeDetailsPaneWidth,
      transformConfig: normalizedTransformConfig,
    }
    return viewData
  }

  public dump = (): ITextViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const contentMode: ContentModeEnum = this.contentMode$.getSnapshot()
    const nodeDetailsPaneWidth: number = this.nodeDetailsPaneWidth$.getSnapshot()
    const transformConfig: ITextTransformConfig = this.transformConfig$.getSnapshot()
    return { mode, contentMode, nodeDetailsPaneWidth, transformConfig }
  }

  public load = (data: Partial<ITextViewData> | undefined): void => {
    const base: ITextViewData = this.dump()
    const { mode, contentMode, nodeDetailsPaneWidth, transformConfig } =
      TextViewViewModel.normalize(data, base)
    this.mode$.next(mode)
    this.contentMode$.next(contentMode)
    this.nodeDetailsPaneWidth$.next(nodeDetailsPaneWidth!)
    this.transformConfig$.next(transformConfig!)
  }
}
