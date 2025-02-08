import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { SiteTheme } from './types'

export interface ISiteViewModelProps {
  /**
   * Site theme.
   */
  readonly theme: SiteTheme
}

export class SiteViewModel extends ViewModel {
  public readonly theme$: IState<SiteTheme>

  constructor(props: ISiteViewModelProps) {
    super()

    const { theme } = props
    this.theme$ = new State<SiteTheme>(theme)
  }
}
