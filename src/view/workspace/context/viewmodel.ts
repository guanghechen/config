import type { IState } from '@guanghechen/react-viewmodel'
import { State, Subscriber, ViewModel } from '@guanghechen/react-viewmodel'
import debounce from 'lodash.debounce'
import { FileTreeModeEnum } from '@/component/filetree/context/types'
import type { IWorkspaceItem, IWorkspaceViewData } from './types'

interface IProps {
  readonly filepath?: string | null
  readonly workspace?: string | null
  readonly workspaces?: IWorkspaceItem[]

  readonly filetreeKeyword?: string
  readonly filetreeMode?: FileTreeModeEnum

  readonly sidebarVisible?: boolean
  readonly sidebarWidth?: number
}

const DEFAULT_DATA: IWorkspaceViewData = {
  filepath: null,
  workspace: null,
  workspaces: [],
  filetreeKeyword: '',
  filetreeMode: FileTreeModeEnum.TREE,
  sidebarVisible: true,
  sidebarWidth: 300,
}

export class WorkspaceViewViewModel extends ViewModel {
  public readonly filepath$: State<string | null>
  public readonly workspace$: IState<string | null>
  public readonly workspaces$: IState<IWorkspaceItem[]>

  public readonly filetreeKeyword$: IState<string>
  public readonly filetreeMode$: IState<FileTreeModeEnum>

  public readonly sidebarVisible$: IState<boolean>
  public readonly sidebarWidth$: IState<number>

  public readonly tocActivatedIdentifier$: IState<string | null>
  public readonly specifiedTocActivatedIdentifier$: IState<string | null>

  public readonly filepathDirtyTick$: IState<number>
  public readonly revealTick$: IState<number>
  public readonly workspacesDirtyTick$: IState<number>
  public readonly filetreeDirtyTick$: IState<number>

  public readonly mainScrollableContainer$: IState<HTMLDivElement | null>

  public readonly updateSidebarWidthDebounced: (nextWidth: number) => void

  constructor(props: IProps) {
    super()

    const {
      filepath = DEFAULT_DATA.filepath,
      workspace = DEFAULT_DATA.workspace,
      workspaces = DEFAULT_DATA.workspaces,
      filetreeKeyword = DEFAULT_DATA.filetreeKeyword,
      filetreeMode = DEFAULT_DATA.filetreeMode,
      sidebarWidth = DEFAULT_DATA.sidebarWidth,
      sidebarVisible = DEFAULT_DATA.sidebarVisible,
    } = props

    const filepath$ = new State<string | null>(filepath)
    const workspace$ = new State<string | null>(workspace)
    const workspaces$ = new State<IWorkspaceItem[]>(workspaces)

    const filetreeKeyword$ = new State<string>(filetreeKeyword)
    const filetreeMode$ = new State<FileTreeModeEnum>(filetreeMode)

    const sidebarVisible$ = new State<boolean>(sidebarVisible)
    const sidebarWidth$ = new State<number>(sidebarWidth)

    const tocActivatedIdentifier$ = new State<string | null>(null)
    const specifiedTocActivatedIdentifier$ = new State<string | null>(null)

    const filepathDirtyTick$ = new State<number>(0)
    const revealTick$ = new State<number>(0)
    const workspacesDirtyTick$ = new State<number>(0)
    const filetreeDirtyTick$ = new State<number>(0)

    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)

    this.filepath$ = filepath$
    this.workspace$ = workspace$
    this.workspaces$ = workspaces$
    this.filetreeKeyword$ = filetreeKeyword$
    this.filetreeMode$ = filetreeMode$
    this.sidebarVisible$ = sidebarVisible$
    this.sidebarWidth$ = sidebarWidth$
    this.tocActivatedIdentifier$ = tocActivatedIdentifier$
    this.specifiedTocActivatedIdentifier$ = specifiedTocActivatedIdentifier$
    this.filepathDirtyTick$ = filepathDirtyTick$
    this.revealTick$ = revealTick$
    this.workspacesDirtyTick$ = workspacesDirtyTick$
    this.filetreeDirtyTick$ = filetreeDirtyTick$
    this.mainScrollableContainer$ = mainScrollableContainer$
    this.updateSidebarWidthDebounced = debounce(function (nextWidth: number): void {
      sidebarWidth$.next(nextWidth)
    }, 100)

    workspace$.subscribe(
      new Subscriber({
        onNext: (value, prevValue) => {
          if (value !== prevValue) {
            filepath$.next(null)
            filetreeDirtyTick$.setState(tick => tick + 1)
          }
        },
      }),
    )
  }

  public static normalize(
    data: Partial<IWorkspaceViewData> | undefined,
    base: IWorkspaceViewData = DEFAULT_DATA,
  ): IWorkspaceViewData {
    const {
      filepath,
      workspace,
      workspaces,
      filetreeKeyword,
      filetreeMode,
      sidebarVisible,
      sidebarWidth,
    } = data || {}
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

    const normalizedFiletreeKeyword = typeof filetreeKeyword === 'string' ? filetreeKeyword : ''
    const normalizedFiletreeMode: FileTreeModeEnum =
      filetreeMode === FileTreeModeEnum.TREE || filetreeMode === FileTreeModeEnum.LIST
        ? filetreeMode
        : base.filetreeMode

    const normalizedVisible: boolean = typeof sidebarVisible === 'boolean' ? sidebarVisible : true
    const normalizedWidth: number = typeof sidebarWidth === 'number' ? sidebarWidth : 300
    const normalizedData: IWorkspaceViewData = {
      filepath: normalizedFilepath,
      workspace: normalizedWorkspace,
      workspaces: normalizedWorkspaces,
      filetreeKeyword: normalizedFiletreeKeyword,
      filetreeMode: normalizedFiletreeMode,
      sidebarVisible: normalizedVisible,
      sidebarWidth: normalizedWidth,
    }
    return normalizedData
  }

  public dump = (): IWorkspaceViewData => {
    const filepath: string | null = this.filepath$.getSnapshot()
    const workspace: string | null = this.workspace$.getSnapshot()
    const workspaces: IWorkspaceItem[] = this.workspaces$.getSnapshot()
    const filetreeKeyword: string = this.filetreeKeyword$.getSnapshot()
    const filetreeMode: FileTreeModeEnum = this.filetreeMode$.getSnapshot()
    const sidebarVisible: boolean = this.sidebarVisible$.getSnapshot()
    const sidebarWidth: number = this.sidebarWidth$.getSnapshot()
    return {
      filepath,
      workspace,
      workspaces,
      filetreeKeyword,
      filetreeMode,
      sidebarVisible,
      sidebarWidth,
    }
  }

  public load = (data: Partial<IWorkspaceViewData> | undefined): void => {
    const {
      filepath,
      workspace,
      workspaces,
      filetreeKeyword,
      filetreeMode,
      sidebarVisible,
      sidebarWidth,
    }: IWorkspaceViewData = WorkspaceViewViewModel.normalize(data, this.dump())
    this.workspaces$.next(workspaces)
    this.workspace$.next(workspace)
    this.filetreeKeyword$.next(filetreeKeyword)
    this.filetreeMode$.next(filetreeMode)
    this.filepath$.next(filepath)
    this.sidebarVisible$.next(sidebarVisible)
    this.sidebarWidth$.next(sidebarWidth)
  }

  public markFilepathDirty = (): void => {
    const tick: number = this.filepathDirtyTick$.getSnapshot()
    this.filepathDirtyTick$.next(tick + 1)
  }

  public markWorkspaceDirty = (): void => {
    const tick: number = this.workspacesDirtyTick$.getSnapshot()
    this.workspacesDirtyTick$.next(tick + 1)
  }

  public markFiletreeDirty = (): void => {
    const tick: number = this.filetreeDirtyTick$.getSnapshot()
    this.filetreeDirtyTick$.next(tick + 1)
  }

  public toggleBothSidebarAndTopbar = (): void => {
    const sidebarVisible = this.sidebarVisible$.getSnapshot()
    const newVisibility = !sidebarVisible
    this.sidebarVisible$.next(newVisibility)
  }

  public revealInSidebar = (): void => {
    this.sidebarVisible$.next(true)
    setTimeout(() => {
      const tick = this.revealTick$.getSnapshot()
      this.revealTick$.next(tick + 1)
    }, 50)
  }
}
