import {
  createPlugin,
  createRouteRef,
  createRoutableExtension,
  createApiFactory,
  discoveryApiRef,
  fetchApiRef,
} from '@backstage/core-plugin-api';
import { PlatformBrokerClient, platformBrokerApiRef } from './api/PlatformBrokerClient';

export const rootRouteRef = createRouteRef({ id: 'platform-broker' });
export const auditRouteRef = createRouteRef({ id: 'platform-broker-audit' });

export const platformBrokerPlugin = createPlugin({
  id: 'platform-broker',
  apis: [
    createApiFactory({
      api: platformBrokerApiRef,
      deps: { discoveryApi: discoveryApiRef, fetchApi: fetchApiRef },
      factory: ({ discoveryApi, fetchApi }) =>
        new PlatformBrokerClient({ discoveryApi, fetchApi }),
    }),
  ],
  routes: {
    root: rootRouteRef,
    audit: auditRouteRef,
  },
});

export const PlatformBrokerPage = platformBrokerPlugin.provide(
  createRoutableExtension({
    name: 'PlatformBrokerPage',
    component: () =>
      import('./components/CreateServiceForm').then(m => m.CreateServiceForm),
    mountPoint: rootRouteRef,
  }),
);

export const AuditLogPage = platformBrokerPlugin.provide(
  createRoutableExtension({
    name: 'AuditLogPage',
    component: () =>
      import('./components/AuditLogTable').then(m => m.AuditLogTable),
    mountPoint: auditRouteRef,
  }),
);
