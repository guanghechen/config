import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'

interface IProps {
  readonly workspace?: string | null
  readonly filepath?: string | null
}

export class HtmlViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>

  constructor(props: IProps = {}) {
    super()
    this.workspace$ = new State<string | null>(props.workspace ?? null)
    this.filepath$ = new State<string | null>(props.filepath ?? null)
  }
}
