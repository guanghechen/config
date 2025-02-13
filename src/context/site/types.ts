import type { IState } from '@guanghechen/react-viewmodel'

export enum SiteTheme {
  LIGHTEN = 'lighten',
  DARKEN = 'darken',
}

export interface ISiteData {
  readonly theme: SiteTheme
}

export interface ISiteViewModel {
  readonly theme$: IState<SiteTheme>
  dump(): ISiteData
  load(data: Partial<ISiteData> | undefined): void
}

export interface ISiteContext {
  readonly viewmodel: ISiteViewModel
}
