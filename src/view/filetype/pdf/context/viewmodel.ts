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

export class PdfViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly pages$: IState<number>
  public readonly pageno$: IState<number>
  public readonly scale$: IState<number>
  public readonly multiview$: IState<boolean>

  constructor(props: IProps) {
    super()

    const { workspace, filepath } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.pages$ = new State<number>(props.pages ?? 1)
    this.pageno$ = new State<number>(props.pageno ?? 1)
    this.scale$ = new State<number>(props.scale ?? 1)
    this.multiview$ = new State<boolean>(props.multiview ?? false)
  }
}
