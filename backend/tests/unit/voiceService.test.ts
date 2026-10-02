import { describe, expect, it } from 'vitest';
import { findContactByTarget } from '../../src/modules/voice/voice.service';
import type { EmergencyContactRecord } from '../../src/modules/emergency/emergency.types';

function contact(overrides: Partial<EmergencyContactRecord>): EmergencyContactRecord {
  return {
    id: 'id',
    elderId: 'elder',
    name: 'Jane',
    phone: '555',
    relationship: null,
    priority: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

describe('findContactByTarget', () => {
  it('matches by relationship before name', () => {
    const contacts = [contact({ id: '1', name: 'Jane', relationship: 'Daughter' }), contact({ id: '2', name: 'Son Bob', relationship: 'Son' })];
    expect(findContactByTarget(contacts, 'son')?.id).toBe('2');
  });

  it('falls back to matching by name', () => {
    const contacts = [contact({ id: '1', name: 'Priya', relationship: 'Neighbor' })];
    expect(findContactByTarget(contacts, 'priya')?.id).toBe('1');
  });

  it('returns undefined when nothing matches', () => {
    const contacts = [contact({ id: '1', name: 'Priya', relationship: 'Neighbor' })];
    expect(findContactByTarget(contacts, 'doctor')).toBeUndefined();
  });

  it('returns undefined for an empty target', () => {
    expect(findContactByTarget([contact({})], '')).toBeUndefined();
  });
});
