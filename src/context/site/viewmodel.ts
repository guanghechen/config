import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ISiteData, ISiteViewModel } from './types'
import { SiteTheme } from './types'

export interface ISiteViewModelProps {
  /**
   * Site theme.
   */
  readonly theme: SiteTheme
}

const DEFAULT_SITE_DATA: ISiteData = {
  theme: SiteTheme.LIGHTEN,
}

export class SiteViewModel extends ViewModel implements ISiteViewModel {
  public readonly theme$: IState<SiteTheme>

  constructor(props: ISiteViewModelProps) {
    super()

    const { theme } = props
    this.theme$ = new State<SiteTheme>(theme)
  }

  public static fromData(data: Partial<ISiteData> | undefined): SiteViewModel {
    const { theme }: ISiteData = this.normalize(DEFAULT_SITE_DATA, data)
    return new SiteViewModel({ theme })
  }

  public static normalize(base: ISiteData, data: Partial<ISiteData> | undefined): ISiteData {
    const { theme = base.theme } = data && typeof data === 'object' ? data : {}
    return { theme }
  }

  public dump(): ISiteData {
    const theme: SiteTheme = this.theme$.getSnapshot()
    return { theme }
  }

  public load(data: Partial<ISiteData> | undefined): void {
    const { theme }: ISiteData = SiteViewModel.normalize(this.dump(), data)
    this.theme$.next(theme)
  }
}
