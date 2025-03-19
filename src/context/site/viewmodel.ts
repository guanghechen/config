import type { IState } from '@guanghechen/react-viewmodel'
import { State, Subscriber, ViewModel } from '@guanghechen/react-viewmodel'
import type { IWorkspaceItem } from '@/types/api'

export enum SiteTheme {
  LIGHTEN = 'lighten',
  DARKEN = 'darken',
}

export interface ISiteData {
  readonly theme: SiteTheme
}

interface IProps {
  /**
   * Site theme.
   */
  readonly theme: SiteTheme
}

const DEFAULT_SITE_DATA: ISiteData = {
  theme: SiteTheme.LIGHTEN,
}

export class SiteViewModel extends ViewModel {
  public readonly filepath$: IState<string | null>
  public readonly filepathDirtyTick$: IState<number>
  public readonly theme$: IState<SiteTheme>
  public readonly workspace$: IState<string | null>
  public readonly workspaces$: IState<IWorkspaceItem[]>
  public readonly workspacesDirtyTick$: IState<number>

  public static fromData(data: Partial<ISiteData> | undefined): SiteViewModel {
    const { theme }: ISiteData = this.normalize(DEFAULT_SITE_DATA, data)
    return new SiteViewModel({ theme })
  }

  public static normalize(base: ISiteData, data: Partial<ISiteData> | undefined): ISiteData {
    const { theme = base.theme } = data && typeof data === 'object' ? data : {}
    return { theme }
  }

  constructor(props: IProps) {
    super()

    const { theme } = props
    this.filepath$ = new State<string | null>(null)
    this.filepathDirtyTick$ = new State<number>(0)
    this.theme$ = new State<SiteTheme>(theme)
    this.workspace$ = new State<string | null>(null)
    this.workspaces$ = new State<IWorkspaceItem[]>([])
    this.workspacesDirtyTick$ = new State<number>(0)

    this.workspace$.subscribe(
      new Subscriber({
        onNext: () => {
          const workspace = this.workspace$.getSnapshot()
          const workspaces = this.workspaces$.getSnapshot()

          if (workspaces.length === 0) {
            this.filepath$.next(null)
            this.workspace$.next(null)
            return
          }

          if (workspaces.some(item => item.tag === workspace)) return
          this.filepath$.next(null)
          this.workspace$.next(workspaces[0].tag)
        },
      }),
    )
  }

  public markFilepathDirty = (): void => {
    const tick: number = this.filepathDirtyTick$.getSnapshot()
    this.filepathDirtyTick$.next(tick + 1)
  }

  public markWorkspaceDirty = (): void => {
    const tick: number = this.workspacesDirtyTick$.getSnapshot()
    this.workspacesDirtyTick$.next(tick + 1)
  }

  public onSearchChange = (): void => {
    const usp = new URLSearchParams(window.location.search)
    const workspace: string | null = decodeURIComponent(usp.get('workspace') || '') || null
    const filepath: string | null = decodeURIComponent(usp.get('filepath') || '') || null
    this.workspace$.next(workspace)
    this.filepath$.next(filepath)
  }

  public dump = (): ISiteData => {
    const theme: SiteTheme = this.theme$.getSnapshot()
    return { theme }
  }

  public load = (data: Partial<ISiteData> | undefined): void => {
    const { theme }: ISiteData = SiteViewModel.normalize(this.dump(), data)
    this.theme$.next(theme)
  }
}
