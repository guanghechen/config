import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IPdfViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly url: string | null
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly multiview?: boolean
  readonly pageNo?: number
  readonly pageTotal?: number
}

const DEFAULT_DATA: IPdfViewData = {
  mode: ModeEnum.CONTENT,
  scale: 1,
  multiview: false,
  pageNo: 1,
  pageTotal: 1,
}

export class PdfViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly scale$: IState<number>
  public readonly multiview$: IState<boolean>

  public readonly pageNo$: IState<number>
  public readonly pageTotal$: IState<number>

  public readonly url$: IState<string | null>

  constructor(props: IProps) {
    super()

    const {
      url,
      mode = DEFAULT_DATA.mode,
      scale = DEFAULT_DATA.scale,
      multiview = DEFAULT_DATA.multiview,
      pageNo = DEFAULT_DATA.pageNo,
      pageTotal = DEFAULT_DATA.pageTotal,
    } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.scale$ = new State<number>(scale)
    this.multiview$ = new State<boolean>(multiview)

    this.pageNo$ = new State<number>(pageNo)
    this.pageTotal$ = new State<number>(pageTotal)

    this.url$ = new State<string | null>(url)
  }

  public static normalize(
    data: Partial<IPdfViewData> | undefined,
    base: IPdfViewData = DEFAULT_DATA,
  ): IPdfViewData {
    const { mode, scale, multiview, pageNo, pageTotal } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedScale: number = typeof scale === 'number' && scale > 0 ? scale : base.scale
    const normalizedMultiview: boolean = typeof multiview === 'boolean' ? multiview : base.multiview
    const normalizedPageno: number =
      typeof pageNo === 'number' && pageNo >= 1 && Number.isInteger(pageNo) ? pageNo : base.pageNo
    const normalizedPageTotal: number =
      typeof pageTotal === 'number' && pageTotal >= 1 && Number.isInteger(pageTotal)
        ? pageTotal
        : base.pageTotal
    const normalizedData: IPdfViewData = {
      mode: normalizedMode,
      scale: normalizedScale,
      multiview: normalizedMultiview,
      pageNo: normalizedPageno,
      pageTotal: normalizedPageTotal,
    }
    return normalizedData
  }

  public dump = (): IPdfViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const scale: number = this.scale$.getSnapshot()
    const multiview: boolean = this.multiview$.getSnapshot()
    const pageNo: number = this.pageNo$.getSnapshot()
    const pageTotal: number = this.pageTotal$.getSnapshot()
    return { mode, scale, multiview, pageNo, pageTotal }
  }

  public load = (data: Partial<IPdfViewData> | undefined): void => {
    const base: IPdfViewData = this.dump()
    const { mode, scale, multiview, pageNo, pageTotal }: IPdfViewData = PdfViewViewModel.normalize(
      data,
      base,
    )
    this.mode$.next(mode)
    this.scale$.next(scale)
    this.multiview$.next(multiview)
    this.pageNo$.next(pageNo)
    this.pageTotal$.next(pageTotal)
  }

  public setPageTotal = (total: number): void => {
    if (total >= 1 && Number.isInteger(total)) {
      this.pageTotal$.next(total)
      // Ensure current page doesn't exceed total pages
      const currentPage = this.pageNo$.getSnapshot()
      if (currentPage > total) {
        this.pageNo$.next(total)
      }
    }
  }

  public setPageNo = (pageNo: number): void => {
    const total = this.pageTotal$.getSnapshot()
    if (pageNo >= 1 && pageNo <= total && Number.isInteger(pageNo)) {
      this.pageNo$.next(pageNo)
    }
  }

  public goToNextPage = (): boolean => {
    const current = this.pageNo$.getSnapshot()
    const total = this.pageTotal$.getSnapshot()
    if (current < total) {
      this.pageNo$.next(current + 1)
      return true
    }
    return false
  }

  public goToPreviousPage = (): boolean => {
    const current = this.pageNo$.getSnapshot()
    if (current > 1) {
      this.pageNo$.next(current - 1)
      return true
    }
    return false
  }

  public goToFirstPage = (): void => {
    this.pageNo$.next(1)
  }

  public goToLastPage = (): void => {
    const total = this.pageTotal$.getSnapshot()
    this.pageNo$.next(total)
  }

  public isFirstPage = (): boolean => {
    return this.pageNo$.getSnapshot() === 1
  }

  public isLastPage = (): boolean => {
    const current = this.pageNo$.getSnapshot()
    const total = this.pageTotal$.getSnapshot()
    return current === total
  }
}
