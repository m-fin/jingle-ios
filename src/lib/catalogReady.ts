const listeners = new Set<() => void>();

/** Fired after a catalog wake clip is stored, so scheduled notifications can pick it up. */
export function onCatalogReady(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function emitCatalogReady(): void {
  for (const listener of listeners) listener();
}
