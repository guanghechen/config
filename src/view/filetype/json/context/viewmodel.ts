import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ModeEnum } from './types'

export interface IJsonViewViewModelProps {
  readonly mode?: ModeEnum
  readonly content?: string | null
}

export class JsonViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly content$: IState<string | null>

  constructor(props: IJsonViewViewModelProps = {}) {
    super()
    this.mode$ = new State<ModeEnum>(props.mode ?? 1)
    this.content$ = new State<string | null>(props.content ?? null)
  }
}
