import {type Entity, type Activity, spaces} from './core';

export const isOpen = (e: Entity) => !['done', 'archived', 'REJECTED', 'Lost'].includes(e.status);
export function continueItem(items: Entity[], activity: Activity[], focus: string, recent?: string): Entity | null {
  const saved = items.find(e => e.id === recent && isOpen(e));
  if (focus === 'all' || saved?.space === focus) return saved || null;
  // A focused continuation uses actual edited work, never a fabricated recommendation.
  const touched = [...activity].sort((a,b) => b.at.localeCompare(a.at));
  for (const event of touched) {
    const item = items.find(e => e.id === event.entityId && e.space === focus && isOpen(e));
    if (item) return item;
  }
  return saved || null;
}
export function meaningfulUpdates(items: Entity[], focus='all', now = new Date()) {
  const dueSoon = (e: Entity) => e.kind === 'exam' && !!e.due && new Date(e.due).getTime() > now.getTime() && new Date(e.due).getTime() < now.getTime() + 2*86400000;
  return items.filter(e => isOpen(e) && (
    (e.kind === 'website' && e.data.deploymentStatus?.toLowerCase() === 'failed') || dueSoon(e) ||
    (e.kind === 'thread' && e.status === 'CANON' && !e.data.payoff && now.getTime()-new Date(e.updated).getTime()>14*86400000)
  )).sort((a,b) => Number(dueSoon(b))-Number(dueSoon(a)) || Number(b.space===focus)-Number(a.space===focus) || b.updated.localeCompare(a.updated));
}
export function orderedSpaces(focus: string) {
  return [...spaces].sort((a,b) => Number(b.id===focus)-Number(a.id===focus));
}
