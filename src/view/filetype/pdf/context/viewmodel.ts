import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IPdfFileData } from '@/hook/api/file'
import type { IPdfViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly pages?: number
  readonly pageno?: number
  readonly scale?: number
  readonly multiview?: boolean
}

const DEFAULT_DATA: IPdfViewData = {
  mode: ModeEnum.CONTENT,
  scale: 1,
  multiview: false,
}

export class PdfViewViewModel extends ViewModel {
  public readonly filepath$: IState<string>
  public readonly mode$: IState<ModeEnum>
  public readonly pages$: IState<number>
  public readonly pageno$: IState<number>
  public readonly scale$: IState<number>
  public readonly multiview$: IState<boolean>
  public readonly data$: IState<IPdfFileData | null>
  public readonly error$: IState<string | null>

  public static fromData(data: Partial<IPdfViewData> | undefined): PdfViewViewModel {
    const { mode, scale, multiview }: IPdfViewData = this.normalize(DEFAULT_DATA, data)
    return new PdfViewViewModel({
      filepath: '',
      mode,
      scale,
      multiview,
    })
  }

  public static normalize(
    base: IPdfViewData,
    data: Partial<IPdfViewData> | undefined,
  ): IPdfViewData {
    const { mode, scale, multiview } = data || {}
    const normalizedMode: ModeEnum = typeof mode === 'number' ? mode : base.mode
    const normalizedScale: number = typeof scale === 'number' && scale > 0 ? scale : base.scale
    const normalizedMultiview: boolean = typeof multiview === 'boolean' ? multiview : base.multiview
    const normalizedData: IPdfViewData = {
      mode: normalizedMode,
      scale: normalizedScale,
      multiview: normalizedMultiview,
    }
    return normalizedData
  }

  constructor(props: IProps) {
    super()

    const {
      filepath,
      mode = DEFAULT_DATA.mode,
      pages = 1,
      pageno = 1,
      scale = DEFAULT_DATA.scale,
      multiview = DEFAULT_DATA.multiview,
    } = props

    this.filepath$ = new State<string>(filepath)
    this.mode$ = new State<ModeEnum>(mode)
    this.pages$ = new State<number>(pages)
    this.pageno$ = new State<number>(pageno)
    this.scale$ = new State<number>(scale)
    this.multiview$ = new State<boolean>(multiview)
    this.data$ = new State<IPdfFileData | null>(null)
    this.error$ = new State<string | null>(null)
  }

  public dump = (): IPdfViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const scale: number = this.scale$.getSnapshot()
    const multiview: boolean = this.multiview$.getSnapshot()
    return {
      mode,
      scale,
      multiview,
    }
  }

  public load = (data: Partial<IPdfViewData> | undefined): void => {
    const { mode, scale, multiview }: IPdfViewData = PdfViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
    this.scale$.next(scale)
    this.multiview$.next(multiview)
  }
}
