import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ITextViewData } from './types'

interface IProps {
  readonly workspace?: string | null
  readonly filepath?: string | null
}

const DEFAULT_TEXT_VIEW_DATA: ITextViewData = {}

export class TextViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>
  public readonly content$: IState<string | null>
  public readonly error$: IState<string | null>

  public static fromData(data: Partial<ITextViewData> | undefined): TextViewViewModel {
    return new TextViewViewModel({
      workspace: null,
      filepath: null,
    })
  }

  public static normalize(
    base: ITextViewData,
    data: Partial<ITextViewData> | undefined,
  ): ITextViewData {
    return base
  }

  constructor(props: IProps = {}) {
    super()

    const { workspace = null, filepath = null } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string | null>(filepath)
    this.content$ = new State<string | null>(null)
    this.error$ = new State<string | null>(null)
  }

  public dump = (): ITextViewData => {
    return DEFAULT_TEXT_VIEW_DATA
  }

  public load = (data: Partial<ITextViewData> | undefined): void => {
    // No additional data to load for text view
  }
}
