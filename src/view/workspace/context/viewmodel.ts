import type { IState } from '@guanghechen/react-viewmodel'
import { State, Subscriber, ViewModel } from '@guanghechen/react-viewmodel'
import type { IWorkspaceItem } from '@/types/api'

export interface IWorkspaceData {
  readonly filepath: string | null
  readonly workspace: string | null
  readonly workspaces: IWorkspaceItem[]

  readonly sidebarVisible: boolean
  readonly sidebarWidth: number
}

interface IProps {
  readonly filepath: string | null
  readonly workspace: string | null
  readonly workspaces: IWorkspaceItem[]

  readonly sidebarVisible: boolean
  readonly sidebarWidth: number
}

const DEFAULT_WORKSPACE_DATA: IWorkspaceData = {
  filepath: null,
  workspace: null,
  workspaces: [],
  sidebarVisible: true,
  sidebarWidth: 300,
}

export class WorkspaceViewModel extends ViewModel {
  public readonly filepath$: IState<string | null>
  public readonly workspace$: IState<string | null>
  public readonly workspaces$: IState<IWorkspaceItem[]>

  public readonly sidebarVisible$: IState<boolean>
  public readonly sidebarWidth$: IState<number>

  public readonly filepathDirtyTick$: IState<number>
  public readonly workspacesDirtyTick$: IState<number>

  public static fromData(data: Partial<IWorkspaceData> | undefined): WorkspaceViewModel {
    const { filepath, workspace, workspaces, sidebarVisible, sidebarWidth }: IWorkspaceData =
      this.normalize(DEFAULT_WORKSPACE_DATA, data)
    return new WorkspaceViewModel({ filepath, workspace, workspaces, sidebarVisible, sidebarWidth })
  }

  public static normalize(
    base: IWorkspaceData,
    data: Partial<IWorkspaceData> | undefined,
  ): IWorkspaceData {
    const { filepath, workspace, workspaces, sidebarVisible, sidebarWidth } = data || {}
    const normalizedFilepath = typeof filepath === 'string' ? filepath : base.filepath
    const normalizedWorkspace = typeof workspace === 'string' ? workspace : base.workspace
    let normalizedWorkspaces: IWorkspaceItem[] = []
    if (Array.isArray(workspaces)) {
      for (const item of workspaces) {
        if (!!item && typeof item.tag === 'string') {
          normalizedWorkspaces.push({ tag: item.tag })
        }
      }
    } else {
      normalizedWorkspaces = base.workspaces
    }

    const normalizedVisible: boolean = typeof sidebarVisible === 'boolean' ? sidebarVisible : true
    const normalizedWidth: number = typeof sidebarWidth === 'number' ? sidebarWidth : 300
    return {
      filepath: normalizedFilepath,
      workspace: normalizedWorkspace,
      workspaces: normalizedWorkspaces,
      sidebarVisible: normalizedVisible,
      sidebarWidth: normalizedWidth,
    }
  }

  constructor(props: IProps) {
    super()

    const { filepath, workspace, workspaces, sidebarWidth, sidebarVisible } = props
    this.filepath$ = new State<string | null>(filepath)
    this.workspace$ = new State<string | null>(workspace)
    this.workspaces$ = new State<IWorkspaceItem[]>(workspaces)

    this.sidebarVisible$ = new State<boolean>(sidebarVisible)
    this.sidebarWidth$ = new State<number>(sidebarWidth)

    this.workspacesDirtyTick$ = new State<number>(0)
    this.filepathDirtyTick$ = new State<number>(0)

    this.workspace$.subscribe(
      new Subscriber({
        onNext: () => {
          const workspace = this.workspace$.getSnapshot()
          const workspaces = this.workspaces$.getSnapshot()
          if (workspaces.length === 0) return

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

  public dump = (): IWorkspaceData => {
    const filepath: string | null = this.filepath$.getSnapshot()
    const workspace: string | null = this.workspace$.getSnapshot()
    const workspaces: IWorkspaceItem[] = this.workspaces$.getSnapshot()
    const sidebarVisible: boolean = this.sidebarVisible$.getSnapshot()
    const sidebarWidth: number = this.sidebarWidth$.getSnapshot()
    return { filepath, workspace, workspaces, sidebarVisible, sidebarWidth }
  }

  public load = (data: Partial<IWorkspaceData> | undefined): void => {
    const { filepath, workspace, workspaces, sidebarVisible, sidebarWidth }: IWorkspaceData =
      WorkspaceViewModel.normalize(this.dump(), data)
    this.workspaces$.next(workspaces)
    this.workspace$.next(workspace)
    this.filepath$.next(filepath)
    this.sidebarVisible$.next(sidebarVisible)
    this.sidebarWidth$.next(sidebarWidth)
  }
}
