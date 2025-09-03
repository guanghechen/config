// Union types for all API interfaces
import type {
  IFileSaveRequestParams,
  IFileSaveRequestPayload,
  IFileSaveResponseResult,
} from './file'
import type {
  ITransformerListRequestParams,
  ITransformerListRequestPayload,
  ITransformerListResponseResult,
  ITransformerResolveRequestParams,
  ITransformerResolveRequestPayload,
  ITransformerResolveResponseResult,
  ITransformerSaveRequestParams,
  ITransformerSaveRequestPayload,
  ITransformerSaveResponseResult,
} from './transform'
import type {
  IUserAuthRequestParams,
  IUserAuthRequestPayload,
  IUserAuthResponseResult,
  IUserLogoutRequestParams,
  IUserLogoutRequestPayload,
  IUserLogoutResponseResult,
  IUserProfileRequestParams,
  IUserProfileRequestPayload,
  IUserProfileResponseResult,
} from './user'

export * from './event'
export * from './file'
export * from './transform'
export * from './user'

export type IRequestParams =
  | IFileSaveRequestParams
  | IUserAuthRequestParams
  | IUserLogoutRequestParams
  | IUserProfileRequestParams
  | ITransformerListRequestParams
  | ITransformerResolveRequestParams
  | ITransformerSaveRequestParams

export type IRequestPayload =
  | IFileSaveRequestPayload
  | IUserAuthRequestPayload
  | IUserLogoutRequestPayload
  | IUserProfileRequestPayload
  | ITransformerListRequestPayload
  | ITransformerResolveRequestPayload
  | ITransformerSaveRequestPayload

export type IResponseResult =
  | IFileSaveResponseResult
  | IUserAuthResponseResult
  | IUserLogoutResponseResult
  | IUserProfileResponseResult
  | ITransformerListResponseResult
  | ITransformerResolveResponseResult
  | ITransformerSaveResponseResult
