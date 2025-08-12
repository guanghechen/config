import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly pages?: number
  readonly pageno?: number
  readonly scale?: number
  readonly multiview?: boolean
}

export interface IPdfViewData {
  readonly scale: number
  readonly multiview: boolean
}

const DEFAULT_PDF_VIEW_DATA: IPdfViewData = {
  scale: 1,
  multiview: false,
}

export class PdfViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly pages$: IState<number>
  public readonly pageno$: IState<number>
  public readonly scale$: IState<number>
  public readonly multiview$: IState<boolean>

  public static fromData(data: Partial<IPdfViewData> | undefined): PdfViewViewModel {
    const { scale, multiview }: IPdfViewData = this.normalize(DEFAULT_PDF_VIEW_DATA, data)
    return new PdfViewViewModel({
      workspace: null,
      filepath: '',
      scale,
      multiview,
    })
  }

  public static normalize(
    base: IPdfViewData,
    data: Partial<IPdfViewData> | undefined,
  ): IPdfViewData {
    const { scale, multiview } = data || {}
    const normalizedScale: number = typeof scale === 'number' && scale > 0 ? scale : base.scale
    const normalizedMultiview: boolean = typeof multiview === 'boolean' ? multiview : base.multiview
    const normalizedData: IPdfViewData = {
      scale: normalizedScale,
      multiview: normalizedMultiview,
    }
    return normalizedData
  }

  constructor(props: IProps) {
    super()

    const {
      workspace,
      filepath,
      pages = 1,
      pageno = 1,
      scale = DEFAULT_PDF_VIEW_DATA.scale,
      multiview = DEFAULT_PDF_VIEW_DATA.multiview,
    } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.pages$ = new State<number>(pages)
    this.pageno$ = new State<number>(pageno)
    this.scale$ = new State<number>(scale)
    this.multiview$ = new State<boolean>(multiview)
  }

  public dump = (): IPdfViewData => {
    const scale: number = this.scale$.getSnapshot()
    const multiview: boolean = this.multiview$.getSnapshot()
    return {
      scale,
      multiview,
    }
  }

  public load = (data: Partial<IPdfViewData> | undefined): void => {
    const { scale, multiview }: IPdfViewData = PdfViewViewModel.normalize(this.dump(), data)
    this.scale$.next(scale)
    this.multiview$.next(multiview)
  }
}
