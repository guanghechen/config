export enum ApiRoutePathEnum {
  AUTH = '/api/auth',
  LOGOUT = '/api/logout',
  ME = '/api/me',
  FILE = '/api/file',
  FILE_RAW = '/api/file/raw',
  FILE_SAVE = '/api/file/save',
  FILE_SWITCH = '/api/file-switch',
  TRANSFORM_TEXT_LIST = '/api/transform/text/list',
  WORKSPACES = '/api/workspaces',
  WORKSPACE_FILES = '/api/workspace/files',

  // Dynamic routes (use these as templates)
  TRANSFORM_TEXT = '/api/transform/text',
  CODE_DEFAULT = '/api/config/code-default',
}
