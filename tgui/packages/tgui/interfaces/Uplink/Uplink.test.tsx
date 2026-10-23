import { describe, expect, it } from 'bun:test';
import { act, render } from '@testing-library/react';
import { createRef } from 'react';
import { gameDataAtom, store } from '../../events/store';

import { Uplink } from './index';

// Mirrors code/__DEFINES/uplink.dm
const UPLINK_TRAITORS = 1 << 0;
const UPLINK_NUKE_OPS = 1 << 1;

function makeItem(id: string, purchasable_from: number) {
  return {
    id,
    name: id,
    icon: '',
    icon_state: '',
    cost: 1,
    desc: '',
    category: 'Stuff',
    purchasable_from,
    restricted: 0,
    limited_stock: -1,
    stock_key: id,
    restricted_roles: [],
    restricted_species: [],
    population_minimum: 0,
    cost_override_string: '',
    lock_other_purchases: 0,
  };
}

const uplinkJson = {
  categories: ['Stuff'],
  items: [
    makeItem('traitor only', UPLINK_TRAITORS),
    makeItem('nukie only', UPLINK_NUKE_OPS),
    makeItem('shared', UPLINK_TRAITORS | UPLINK_NUKE_OPS),
  ],
};

globalThis.fetch = (async () =>
  new Response(JSON.stringify(uplinkJson))) as unknown as typeof fetch;

function setUplinkData(uplink_flag: number) {
  store.set(gameDataAtom, {
    telecrystals: 20,
    lockable: 0,
    uplink_flag,
    assigned_role: 'Assistant',
    assigned_species: 'human',
    debug: 0,
    extra_purchasable: [],
    extra_purchasable_stock: {},
    current_stock: {},
    primary_objectives: [],
    purchased_items: 0,
    shop_locked: 0,
    can_renegotiate: 0,
  });
}

async function openUplink(uplink_flag: number): Promise<string[]> {
  setUplinkData(uplink_flag);
  const ref = createRef<Uplink>();
  const view = render(<Uplink ref={ref} />);
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 10));
  });
  const names = (ref.current?.state.allItems ?? []).map((item) => item.name);
  view.unmount();
  return names.sort();
}

describe('Uplink', () => {
  // https://github.com/tgstation/tgstation/issues/81741
  it('keeps each uplink type its own stock when several are opened', async () => {
    expect(await openUplink(UPLINK_TRAITORS)).toEqual([
      'shared',
      'traitor only',
    ]);
    expect(await openUplink(UPLINK_NUKE_OPS)).toEqual([
      'nukie only',
      'shared',
    ]);
    expect(await openUplink(UPLINK_TRAITORS)).toEqual([
      'shared',
      'traitor only',
    ]);
  });
});
