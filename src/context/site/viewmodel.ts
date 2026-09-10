import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ColorPalette, DarkPalette, LightPalette } from '@/common/style/palette'
import { DARK_PALETTES, LIGHT_PALETTES } from '@/common/style/palette'

export enum SiteTheme {
  LIGHTEN = 'lighten',
  DARKEN = 'darken',
}

export type SiteThemePreference = SiteTheme | 'system'

export interface ISiteData {
  readonly name?: string
  readonly theme: SiteThemePreference
  readonly lightPalette: LightPalette
  readonly darkPalette: DarkPalette
}

interface IProps {
  readonly name?: string
  readonly theme: SiteThemePreference
  readonly lightPalette: LightPalette
  readonly darkPalette: DarkPalette
}

const DEFAULT_DATA: ISiteData = {
  theme: 'system',
  lightPalette: 'vsc-light-modern',
  darkPalette: 'vsc-dark-modern',
}

const lightPaletteIds = new Set<unknown>(LIGHT_PALETTES.map(palette => palette.id))
const darkPaletteIds = new Set<unknown>(DARK_PALETTES.map(palette => palette.id))

export class SiteViewModel extends ViewModel {
  public readonly name: string
  public readonly theme$: IState<SiteTheme>
  public readonly themePreference$: IState<SiteThemePreference>
  public readonly lightPalette$: IState<LightPalette>
  public readonly darkPalette$: IState<DarkPalette>
  public readonly palette$: IState<ColorPalette>
  private deviceTheme: SiteTheme

  public static fromData(
    data: Partial<ISiteData> | undefined,
    deviceTheme: SiteTheme = SiteTheme.LIGHTEN,
  ): SiteViewModel {
    const { theme, lightPalette, darkPalette }: ISiteData = this.normalize(DEFAULT_DATA, data)
    return new SiteViewModel({ name: data?.name, theme, lightPalette, darkPalette }, deviceTheme)
  }

  public static normalize(base: ISiteData, data: Partial<ISiteData> | undefined): ISiteData {
    const source = data && typeof data === 'object' ? data : {}
    const theme =
      source.theme === SiteTheme.LIGHTEN ||
      source.theme === SiteTheme.DARKEN ||
      source.theme === 'system'
        ? source.theme
        : base.theme
    const lightPalette = lightPaletteIds.has(source.lightPalette)
      ? (source.lightPalette as LightPalette)
      : base.lightPalette
    const darkPalette = darkPaletteIds.has(source.darkPalette)
      ? (source.darkPalette as DarkPalette)
      : base.darkPalette
    return { theme, lightPalette, darkPalette }
  }

  constructor(props: IProps, deviceTheme: SiteTheme = SiteTheme.LIGHTEN) {
    super()

    const { name = 'SiteViewModel', theme, lightPalette, darkPalette } = props
    const effectiveTheme = theme === 'system' ? deviceTheme : theme

    this.name = name
    this.deviceTheme = deviceTheme
    this.themePreference$ = new State<SiteThemePreference>(theme)
    this.theme$ = new State<SiteTheme>(effectiveTheme)
    this.lightPalette$ = new State<LightPalette>(lightPalette)
    this.darkPalette$ = new State<DarkPalette>(darkPalette)
    this.palette$ = new State<ColorPalette>(
      effectiveTheme === SiteTheme.DARKEN ? darkPalette : lightPalette,
    )
  }

  public dump = (): ISiteData => {
    return {
      theme: this.themePreference$.getSnapshot(),
      lightPalette: this.lightPalette$.getSnapshot(),
      darkPalette: this.darkPalette$.getSnapshot(),
    }
  }

  public load = (data: Partial<ISiteData> | undefined): void => {
    const { theme, lightPalette, darkPalette }: ISiteData = SiteViewModel.normalize(
      this.dump(),
      data,
    )
    this.lightPalette$.next(lightPalette)
    this.darkPalette$.next(darkPalette)
    this.setThemePreference(theme)
  }

  public setThemePreference = (theme: SiteThemePreference): void => {
    const effectiveTheme = theme === 'system' ? this.deviceTheme : theme
    this.themePreference$.next(theme)
    this.theme$.next(effectiveTheme)
    this.syncPalette(effectiveTheme)
  }

  public setDeviceTheme = (theme: SiteTheme): void => {
    this.deviceTheme = theme
    if (this.themePreference$.getSnapshot() === 'system') {
      this.theme$.next(theme)
      this.syncPalette(theme)
    }
  }

  public setLightPalette = (palette: LightPalette): void => {
    this.lightPalette$.next(palette)
    if (this.theme$.getSnapshot() === SiteTheme.LIGHTEN) this.palette$.next(palette)
  }

  public setDarkPalette = (palette: DarkPalette): void => {
    this.darkPalette$.next(palette)
    if (this.theme$.getSnapshot() === SiteTheme.DARKEN) this.palette$.next(palette)
  }

  private syncPalette = (theme: SiteTheme): void => {
    this.palette$.next(
      theme === SiteTheme.DARKEN
        ? this.darkPalette$.getSnapshot()
        : this.lightPalette$.getSnapshot(),
    )
  }
}
