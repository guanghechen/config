import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'

interface IProps {
  readonly placeholder?: boolean
}

export class UnknownViewViewModel extends ViewModel {
  public readonly placeholder$: IState<boolean>

  constructor(props: IProps = {}) {
    super()
    this.placeholder$ = new State<boolean>(props.placeholder ?? true)
  }
}
