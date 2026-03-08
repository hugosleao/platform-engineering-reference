import { createPlugin, createComponentExtension } from '@backstage/core-plugin-api';

export const scorecardPlugin = createPlugin({ id: 'scorecard' });

export const ScorecardCard = scorecardPlugin.provide(
  createComponentExtension({
    name: 'ScorecardCard',
    component: {
      lazy: () => import('./components/ScorecardCard').then(m => m.ScorecardCard),
    },
  }),
);
