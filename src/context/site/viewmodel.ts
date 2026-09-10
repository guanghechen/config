import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'

export enum SiteTheme {
  LIGHTEN = 'lighten',
  DARKEN = 'darken',
}

export type SiteThemePreference = SiteTheme | 'system'

export interface ISiteData {
  readonly name?: string
  readonly theme: SiteThemePreference
}

interface IProps {
  readonly name?: string
  /**
   * Site theme.
   */
  readonly theme: SiteThemePreference
}

const DEFAULT_DATA: ISiteData = {
  theme: 'system',
}

export class SiteViewModel extends ViewModel {
  public readonly name: string
  public readonly theme$: IState<SiteTheme>
  public readonly themePreference$: IState<SiteThemePreference>
  private deviceTheme: SiteTheme

  public static fromData(
    data: Partial<ISiteData> | undefined,
    deviceTheme: SiteTheme = SiteTheme.LIGHTEN,
  ): SiteViewModel {
    const { theme }: ISiteData = this.normalize(DEFAULT_DATA, data)
    return new SiteViewModel({ name: data?.name, theme }, deviceTheme)
  }

  public static normalize(base: ISiteData, data: Partial<ISiteData> | undefined): ISiteData {
    const { theme = base.theme } = data && typeof data === 'object' ? data : {}
    return {
      theme:
        theme === SiteTheme.LIGHTEN || theme === SiteTheme.DARKEN || theme === 'system'
          ? theme
          : base.theme,
    }
  }

  constructor(props: IProps, deviceTheme: SiteTheme = SiteTheme.LIGHTEN) {
    super()

    const { name = 'SiteViewModel', theme } = props

    this.name = name
    this.deviceTheme = deviceTheme
    this.themePreference$ = new State<SiteThemePreference>(theme)
    this.theme$ = new State<SiteTheme>(theme === 'system' ? deviceTheme : theme)
  }

  public dump = (): ISiteData => {
    const theme: SiteThemePreference = this.themePreference$.getSnapshot()
    return { theme }
  }

  public load = (data: Partial<ISiteData> | undefined): void => {
    const { theme }: ISiteData = SiteViewModel.normalize(this.dump(), data)
    this.setThemePreference(theme)
  }

  public setThemePreference = (theme: SiteThemePreference): void => {
    this.themePreference$.next(theme)
    this.theme$.next(theme === 'system' ? this.deviceTheme : theme)
  }

  public setDeviceTheme = (theme: SiteTheme): void => {
    this.deviceTheme = theme
    if (this.themePreference$.getSnapshot() === 'system') this.theme$.next(theme)
  }
}
