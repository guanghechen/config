import { Subscriber } from '@guanghechen/subscriber'
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import debounce from '@/common/util/debounce'
import {
  isFilepathWithinRoot,
  normalizeAbsoluteFilepath,
  relativeWorkspaceFilepath,
  resolveWorkspaceFilepath,
} from '@/common/util/path'
import { FileTreeModeEnum } from '@/container/filetree/context/types'
import type { ILegacyWorkspace } from '@/shared/types'
import type { IWorkspaceViewData } from './types'

interface IProps {
  readonly filepath?: string | null
  readonly workspaceRoot?: string | null
  readonly workspaceRoots?: string[]
  readonly workspaceRootsInitialized?: boolean
  readonly legacyWorkspaces?: ILegacyWorkspace[]
  readonly workspaceConfigLoaded?: boolean
  readonly workspaceError?: string | null

  readonly filetreeKeyword?: string
  readonly filetreeMode?: FileTreeModeEnum

  readonly sidebarVisible?: boolean
  readonly sidebarWidth?: number
}

const DEFAULT_DATA: IWorkspaceViewData = {
  filepath: null,
  workspaceRoot: null,
  workspaceRoots: [],
  workspaceRootsInitialized: false,
  filetreeKeyword: '',
  filetreeMode: FileTreeModeEnum.TREE,
  sidebarVisible: true,
  sidebarWidth: 300,
}

export class WorkspaceViewViewModel extends ViewModel {
  public readonly filepath$: State<string | null>
  public readonly workspaceRoot$: IState<string | null>
  public readonly workspaceRoots$: IState<string[]>
  public readonly workspaceRootsInitialized$: IState<boolean>
  public readonly legacyWorkspaces: readonly ILegacyWorkspace[]
  public readonly workspaceConfigLoaded: boolean
  public readonly workspaceError$: IState<string | null>

  public readonly filetreeKeyword$: IState<string>
  public readonly filetreeMode$: IState<FileTreeModeEnum>

  public readonly sidebarVisible$: IState<boolean>
  public readonly sidebarWidth$: IState<number>

  public readonly tocActivatedIdentifier$: IState<string | null>
  public readonly specifiedTocActivatedIdentifier$: IState<string | null>

  public readonly filepathDirtyTick$: IState<number>
  public readonly revealTick$: IState<number>
  public readonly filetreeDirtyTick$: IState<number>

  public readonly mainScrollableContainer$: IState<HTMLDivElement | null>

  public readonly updateSidebarWidthDebounced: (nextWidth: number) => void

  constructor(props: IProps) {
    super()

    const {
      filepath = DEFAULT_DATA.filepath,
      workspaceRoot = DEFAULT_DATA.workspaceRoot,
      workspaceRoots = DEFAULT_DATA.workspaceRoots,
      workspaceRootsInitialized = DEFAULT_DATA.workspaceRootsInitialized,
      legacyWorkspaces = [],
      workspaceConfigLoaded = true,
      workspaceError = null,
      filetreeKeyword = DEFAULT_DATA.filetreeKeyword,
      filetreeMode = DEFAULT_DATA.filetreeMode,
      sidebarWidth = DEFAULT_DATA.sidebarWidth,
      sidebarVisible = DEFAULT_DATA.sidebarVisible,
    } = props

    const filepath$ = new State<string | null>(filepath)
    const workspaceRoot$ = new State<string | null>(workspaceRoot)
    const workspaceRoots$ = new State<string[]>(workspaceRoots)
    const workspaceRootsInitialized$ = new State<boolean>(workspaceRootsInitialized)
    const workspaceError$ = new State<string | null>(workspaceError)

    const filetreeKeyword$ = new State<string>(filetreeKeyword)
    const filetreeMode$ = new State<FileTreeModeEnum>(filetreeMode)

    const sidebarVisible$ = new State<boolean>(sidebarVisible)
    const sidebarWidth$ = new State<number>(sidebarWidth)

    const tocActivatedIdentifier$ = new State<string | null>(null)
    const specifiedTocActivatedIdentifier$ = new State<string | null>(null)

    const filepathDirtyTick$ = new State<number>(0)
    const revealTick$ = new State<number>(0)
    const filetreeDirtyTick$ = new State<number>(0)

    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)

    this.filepath$ = filepath$
    this.workspaceRoot$ = workspaceRoot$
    this.workspaceRoots$ = workspaceRoots$
    this.workspaceRootsInitialized$ = workspaceRootsInitialized$
    this.legacyWorkspaces = legacyWorkspaces
    this.workspaceConfigLoaded = workspaceConfigLoaded
    this.workspaceError$ = workspaceError$
    this.filetreeKeyword$ = filetreeKeyword$
    this.filetreeMode$ = filetreeMode$
    this.sidebarVisible$ = sidebarVisible$
    this.sidebarWidth$ = sidebarWidth$
    this.tocActivatedIdentifier$ = tocActivatedIdentifier$
    this.specifiedTocActivatedIdentifier$ = specifiedTocActivatedIdentifier$
    this.filepathDirtyTick$ = filepathDirtyTick$
    this.revealTick$ = revealTick$
    this.filetreeDirtyTick$ = filetreeDirtyTick$
    this.mainScrollableContainer$ = mainScrollableContainer$
    this.updateSidebarWidthDebounced = debounce(function (nextWidth: number): void {
      sidebarWidth$.next(nextWidth)
    }, 100)

    workspaceRoot$.subscribe(
      new Subscriber({
        onNext: (value, prevValue) => {
          if (value !== prevValue) {
            filetreeDirtyTick$.setState(tick => tick + 1)
          }
        },
      }),
    )
  }

  public static normalize(
    data: Partial<IWorkspaceViewData> | null | undefined,
    base: IWorkspaceViewData = DEFAULT_DATA,
  ): IWorkspaceViewData {
    const {
      filepath,
      workspaceRoot,
      workspaceRoots,
      workspaceRootsInitialized,
      filetreeKeyword,
      filetreeMode,
      sidebarVisible,
      sidebarWidth,
    } = data || {}
    const normalizedFilepath = typeof filepath === 'string' ? filepath : base.filepath
    const normalizedWorkspaceRoot =
      typeof workspaceRoot === 'string'
        ? normalizeAbsoluteFilepath(workspaceRoot)
        : base.workspaceRoot
    const normalizedWorkspaceRoots = Array.isArray(workspaceRoots)
      ? Array.from(
          new Set(
            workspaceRoots
              .filter((root): root is string => typeof root === 'string')
              .map(normalizeAbsoluteFilepath)
              .filter((root): root is string => !!root),
          ),
        )
      : base.workspaceRoots
    const normalizedWorkspaceRootsInitialized =
      typeof workspaceRootsInitialized === 'boolean'
        ? workspaceRootsInitialized
        : base.workspaceRootsInitialized

    const normalizedFiletreeKeyword = typeof filetreeKeyword === 'string' ? filetreeKeyword : ''
    const normalizedFiletreeMode: FileTreeModeEnum =
      filetreeMode === FileTreeModeEnum.TREE || filetreeMode === FileTreeModeEnum.LIST
        ? filetreeMode
        : base.filetreeMode

    const normalizedVisible: boolean = typeof sidebarVisible === 'boolean' ? sidebarVisible : true
    const normalizedWidth: number = typeof sidebarWidth === 'number' ? sidebarWidth : 300
    const normalizedData: IWorkspaceViewData = {
      filepath: normalizedFilepath,
      workspaceRoot: normalizedWorkspaceRoot,
      workspaceRoots: normalizedWorkspaceRoots,
      workspaceRootsInitialized: normalizedWorkspaceRootsInitialized,
      filetreeKeyword: normalizedFiletreeKeyword,
      filetreeMode: normalizedFiletreeMode,
      sidebarVisible: normalizedVisible,
      sidebarWidth: normalizedWidth,
    }
    return normalizedData
  }

  public dump = (): IWorkspaceViewData => {
    const filepath: string | null = this.filepath$.getSnapshot()
    const workspaceRoot: string | null = this.workspaceRoot$.getSnapshot()
    const workspaceRoots: string[] = this.workspaceRoots$.getSnapshot()
    const workspaceRootsInitialized: boolean = this.workspaceRootsInitialized$.getSnapshot()
    const filetreeKeyword: string = this.filetreeKeyword$.getSnapshot()
    const filetreeMode: FileTreeModeEnum = this.filetreeMode$.getSnapshot()
    const sidebarVisible: boolean = this.sidebarVisible$.getSnapshot()
    const sidebarWidth: number = this.sidebarWidth$.getSnapshot()
    return {
      filepath,
      workspaceRoot,
      workspaceRoots,
      workspaceRootsInitialized,
      filetreeKeyword,
      filetreeMode,
      sidebarVisible,
      sidebarWidth,
    }
  }

  public load = (data: Partial<IWorkspaceViewData> | undefined): void => {
    const {
      filepath,
      workspaceRoot,
      workspaceRoots,
      workspaceRootsInitialized,
      filetreeKeyword,
      filetreeMode,
      sidebarVisible,
      sidebarWidth,
    }: IWorkspaceViewData = WorkspaceViewViewModel.normalize(data, this.dump())
    this.workspaceRoots$.next(workspaceRoots)
    this.workspaceRootsInitialized$.next(workspaceRootsInitialized)
    this.workspaceRoot$.next(workspaceRoot)
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

  public addWorkspaceRoot = (root: string): void => {
    const normalizedRoot = normalizeAbsoluteFilepath(root)
    if (!normalizedRoot) return
    this.workspaceRoots$.setState(roots =>
      roots.includes(normalizedRoot) ? roots : [...roots, normalizedRoot],
    )
    this.workspaceRootsInitialized$.next(true)
  }

  public removeWorkspaceRoot = (root: string): void => {
    this.workspaceRoots$.setState(roots => roots.filter(item => item !== root))
    this.workspaceRootsInitialized$.next(true)
  }

  public replaceWorkspaceRoot = (root: string, canonicalRoot: string): void => {
    const roots = this.workspaceRoots$.getSnapshot()
    if (roots.includes(root)) {
      this.workspaceRoots$.next(
        Array.from(new Set(roots.map(item => (item === root ? canonicalRoot : item)))),
      )
    }
    if (this.workspaceRoot$.getSnapshot() === root) {
      const filepath = this.filepath$.getSnapshot()
      this.workspaceRoot$.next(canonicalRoot)
      if (filepath && isFilepathWithinRoot(filepath, root)) {
        this.filepath$.next(
          resolveWorkspaceFilepath(canonicalRoot, relativeWorkspaceFilepath(filepath, root)),
        )
      }
    }
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
