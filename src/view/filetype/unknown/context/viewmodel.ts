import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'

export interface IUnknownViewViewModelProps {
  readonly placeholder?: boolean
}

export class UnknownViewViewModel extends ViewModel {
  public readonly placeholder$: IState<boolean>

  constructor(props: IUnknownViewViewModelProps = {}) {
    super()
    this.placeholder$ = new State<boolean>(props.placeholder ?? true)
  }
}
