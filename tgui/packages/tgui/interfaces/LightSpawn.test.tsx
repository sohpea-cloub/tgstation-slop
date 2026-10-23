import { describe, expect, it, mock } from 'bun:test';
import { act, fireEvent, render } from '@testing-library/react';

const acts: [string, Record<string, unknown>][] = [];

mock.module('../events/act', () => ({
  sendAct: (action: string, payload: Record<string, unknown>) => {
    acts.push([action, payload]);
  },
}));

import { gameDataAtom, store } from '../events/store';
import { LightSpawn } from './LightSpawn';

store.set(gameDataAtom, {
  templates: {
    bulb: {
      light_info: {
        name: 'Bulb',
        power: 1,
        range: 5,
        color: '#ffffff',
        angle: 360,
      },
      description: 'A bulb',
      id: 'bulb',
      category: 'Lights',
    },
  },
  default_id: 'bulb',
  default_category: 'Lights',
  category_ids: { Lights: ['bulb'] },
});

describe('LightSpawn tests', () => {
  it('spawns with the selected direction', () => {
    const { container } = render(<LightSpawn />);

    const click = (icon: string) => {
      const el = container.querySelector(`.fa-${icon}`);
      expect(el).not.toBeNull();
      act(() => {
        fireEvent.click(el!.closest('button, .Button')!);
      });
    };
    const spawn = () => click('wrench');

    spawn();
    expect(acts.at(-1)).toEqual([
      'spawn_template',
      { id: 'bulb', dir: 1 },
    ]);

    click('arrow-left');
    spawn();
    expect(acts.at(-1)).toEqual([
      'spawn_template',
      { id: 'bulb', dir: 8 },
    ]);

    click('arrow-down');
    spawn();
    expect(acts.at(-1)).toEqual([
      'spawn_template',
      { id: 'bulb', dir: 2 },
    ]);
  });
});
