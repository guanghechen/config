import { State, Subscriber, ViewModel } from '@guanghechen/react-viewmodel'
import debounce from 'lodash.debounce'
import { FileTreeModeEnum } from '@/component/filetree/context/types'
import type { IWorkspaceData, IWorkspaceItem } from './types'

interface IProps {
  readonly filepath: string | null
  readonly workspace: string | null
  readonly workspaces: IWorkspaceItem[]

  readonly filetreeKeyword: string
  readonly filetreeMode: FileTreeModeEnum

  readonly sidebarVisible: boolean
  readonly sidebarWidth: number
}

const DEFAULT_VIEWMODEL_DATA: IWorkspaceData = {
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
  public readonly workspace$: State<string | null>
  public readonly workspaces$: State<IWorkspaceItem[]>

  public readonly filetreeKeyword$: State<string>
  public readonly filetreeMode$: State<FileTreeModeEnum>

  public readonly sidebarVisible$: State<boolean>
  public readonly sidebarWidth$: State<number>

  public readonly tocActivatedIdentifier$: State<string | null>
  public readonly specifiedTocActivatedIdentifier$: State<string | null>

  public readonly filepathDirtyTick$: State<number>
  public readonly revealTick$: State<number>
  public readonly workspacesDirtyTick$: State<number>

  public readonly mainScrollableContainer$: State<HTMLDivElement | null>

  public readonly updateSidebarWidthDebounced: (nextWidth: number) => void

  public static fromData(data: Partial<IWorkspaceData> | undefined): WorkspaceViewViewModel {
    const {
      filepath,
      workspace,
      workspaces,
      filetreeKeyword,
      filetreeMode,
      sidebarVisible,
      sidebarWidth,
    }: IWorkspaceData = this.normalize(DEFAULT_VIEWMODEL_DATA, data)
    return new WorkspaceViewViewModel({
      filepath,
      workspace,
      workspaces,
      filetreeKeyword,
      filetreeMode,
      sidebarVisible,
      sidebarWidth,
    })
  }

  public static normalize(
    base: IWorkspaceData,
    data: Partial<IWorkspaceData> | undefined,
  ): IWorkspaceData {
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
    const normalizedData: IWorkspaceData = {
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

  constructor(props: IProps) {
    super()

    const {
      filepath,
      workspace,
      workspaces,
      filetreeKeyword,
      filetreeMode,
      sidebarWidth,
      sidebarVisible,
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
    this.mainScrollableContainer$ = mainScrollableContainer$
    this.updateSidebarWidthDebounced = debounce(function (nextWidth: number): void {
      sidebarWidth$.next(nextWidth)
    }, 100)

    workspace$.subscribe(
      new Subscriber({
        onNext: value => {
          if (value === null) return

          const workspaces = workspaces$.getSnapshot()
          if (workspaces.length === 0) return

          if (workspaces.some(item => item.tag === value)) return
          filepath$.next(null)
          workspace$.next(workspaces[0].tag)
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

  public load = (data: Partial<IWorkspaceData> | undefined): void => {
    const {
      filepath,
      workspace,
      workspaces,
      filetreeKeyword,
      filetreeMode,
      sidebarVisible,
      sidebarWidth,
    }: IWorkspaceData = WorkspaceViewViewModel.normalize(this.dump(), data)
    this.workspaces$.next(workspaces)
    this.workspace$.next(workspace)
    this.filetreeKeyword$.next(filetreeKeyword)
    this.filetreeMode$.next(filetreeMode)
    this.filepath$.next(filepath)
    this.sidebarVisible$.next(sidebarVisible)
    this.sidebarWidth$.next(sidebarWidth)
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
