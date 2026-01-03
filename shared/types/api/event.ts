export enum ServerCustomEventType {
  FILE_CHANGED = 'guanghechen/file-changed',
  FILE_SWITCHED = 'guanghechen/file-switch',
  FILE_SWITCH_ASK = 'guanghechen/file-switch-ask',
}

export interface IResponsePayloadFileChanged {
  readonly workspace: string | null
  readonly filepath: string
}

export interface IResponsePayloadFileSwitch {
  readonly workspace: string | null
  readonly filepath: string
}

export interface IResponsePayloadWorkspaces {
  readonly workspaces: Array<{ readonly tag: string }>
}
