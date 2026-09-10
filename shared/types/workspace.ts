export interface ILegacyWorkspace {
  readonly tag: string
  readonly path: string
}

export interface IWorkspaceConfig {
  readonly defaultWorkspaceRoots: string[]
  readonly legacyWorkspaces: ILegacyWorkspace[]
}

export interface IWorkspaceFiles {
  readonly root: string
  readonly files: string[]
}
