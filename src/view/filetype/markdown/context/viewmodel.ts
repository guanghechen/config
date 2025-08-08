import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import { ModeEnum } from './types'

export interface IMarkdownViewViewModelProps {
  readonly tocActivatedIdentifier?: string | null
  readonly specifiedTocActivatedIdentifier?: string | null
  readonly mode?: ModeEnum
}

export class MarkdownViewViewModel extends ViewModel {
  public readonly tocActivatedIdentifier$: IState<string | null>
  public readonly specifiedTocActivatedIdentifier$: IState<string | null>
  public readonly mode$: IState<ModeEnum>

  constructor(props: IMarkdownViewViewModelProps = {}) {
    super()
    this.tocActivatedIdentifier$ = new State<string | null>(props.tocActivatedIdentifier ?? null)
    this.specifiedTocActivatedIdentifier$ = new State<string | null>(
      props.specifiedTocActivatedIdentifier ?? null,
    )
    this.mode$ = new State<ModeEnum>(props.mode ?? ModeEnum.VIEW)
  }
}
