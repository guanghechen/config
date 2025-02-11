import type { IState } from '@guanghechen/react-viewmodel'

export enum SiteTheme {
  LIGHTEN = 'lighten',
  DARKEN = 'darken',
}

export interface ISiteViewModel {
  readonly theme$: IState<SiteTheme>
}

export interface ISiteContext {
  readonly viewmodel: ISiteViewModel
}
