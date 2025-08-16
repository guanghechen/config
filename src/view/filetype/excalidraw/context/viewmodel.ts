import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { SiteTheme } from '@/context/site'
import type { IJsonFileData } from '@/hook/api/file'

export interface IExcalidrawViewViewModelProps {
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly theme?: SiteTheme
  readonly error?: string | null
}

export class ExcalidrawViewViewModel extends ViewModel {
  public readonly elements$: IState<ReadonlyArray<ExcalidrawElement>>
  public readonly content$: IState<string | null>
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>
  public readonly theme$: IState<SiteTheme | null>
  public readonly error$: IState<string | null>
  public readonly data$: IState<IJsonFileData | null>

  constructor(props: IExcalidrawViewViewModelProps = {}) {
    super()
    this.elements$ = new State<ReadonlyArray<ExcalidrawElement>>(props.elements ?? [])
    this.content$ = new State<string | null>(props.content ?? null)
    this.workspace$ = new State<string | null>(props.workspace ?? null)
    this.filepath$ = new State<string | null>(props.filepath ?? null)
    this.theme$ = new State<SiteTheme | null>(props.theme ?? null)
    this.error$ = new State<string | null>(props.error ?? null)
    this.data$ = new State<IJsonFileData | null>(null)
  }
}
