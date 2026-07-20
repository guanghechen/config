export interface IRepositoryResolver {
  resolveRepository(candidatePath: string): Promise<string>
}

export async function resolveRepositoryCandidates(
  candidates: ReadonlyArray<string>,
  repositoryResolver: IRepositoryResolver,
): Promise<ReadonlyArray<string>> {
  const uniqueCandidates = [...new Set(candidates)]
  const resolvedCandidates = await Promise.all(
    uniqueCandidates.map(async candidate => {
      try {
        return await repositoryResolver.resolveRepository(candidate)
      } catch {
        return null
      }
    }),
  )
  return [...new Set(resolvedCandidates.filter(candidate => candidate !== null))]
}
