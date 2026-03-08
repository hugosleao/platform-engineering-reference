import { createApiRef, DiscoveryApi, FetchApi } from '@backstage/core-plugin-api';

export interface CreateServiceRequest {
  name: string;
  description: string;
  team: string;
  private?: boolean;
  infra?: {
    kind: 'RDSInstance' | 'S3Bucket' | 'SQSQueue';
    spec: Record<string, unknown>;
  };
}

export interface CreateServiceResponse {
  repo: {
    name: string;
    full_name: string;
    html_url: string;
    clone_url: string;
  };
  argocd?: {
    name: string;
    namespace: string;
  };
  infra?: {
    name: string;
    kind: string;
    status: string;
  };
}

export interface AuditEntry {
  id: string;
  action: string;
  actor: string;
  resource: string;
  status: string;
  message?: string;
  timestamp: string;
}

export const platformBrokerApiRef = createApiRef<PlatformBrokerApi>({
  id: 'plugin.platform-broker.service',
});

export interface PlatformBrokerApi {
  createService(req: CreateServiceRequest): Promise<CreateServiceResponse>;
  listAudit(): Promise<AuditEntry[]>;
  health(): Promise<{ status: string; version: string }>;
}

export class PlatformBrokerClient implements PlatformBrokerApi {
  private readonly discoveryApi: DiscoveryApi;
  private readonly fetchApi: FetchApi;

  constructor(options: { discoveryApi: DiscoveryApi; fetchApi: FetchApi }) {
    this.discoveryApi = options.discoveryApi;
    this.fetchApi = options.fetchApi;
  }

  private async baseUrl(): Promise<string> {
    return this.discoveryApi.getBaseUrl('platform-broker');
  }

  async createService(req: CreateServiceRequest): Promise<CreateServiceResponse> {
    const base = await this.baseUrl();

    const repoRes = await this.fetchApi.fetch(`${base}/v1/github/repos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: req.name,
        description: req.description,
        team: req.team,
        private: req.private ?? true,
      }),
    });

    if (!repoRes.ok) {
      const err = await repoRes.json();
      throw new Error(err.error ?? 'Erro ao criar repositório');
    }

    const repo = await repoRes.json();

    const argoRes = await this.fetchApi.fetch(`${base}/v1/argocd/apps`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: req.name,
        repo_url: repo.clone_url,
        path: 'k8s',
        namespace: req.name,
      }),
    });

    const argocd = argoRes.ok ? await argoRes.json() : undefined;

    let infra;
    if (req.infra) {
      const infraRes = await this.fetchApi.fetch(`${base}/v1/crossplane/claims`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: `${req.name}-${req.infra.kind.toLowerCase()}`,
          namespace: req.name,
          kind: req.infra.kind,
          spec: req.infra.spec,
        }),
      });
      infra = infraRes.ok ? await infraRes.json() : undefined;
    }

    return { repo, argocd, infra };
  }

  async listAudit(): Promise<AuditEntry[]> {
    const base = await this.baseUrl();
    const res = await this.fetchApi.fetch(`${base}/v1/audit`);
    if (!res.ok) throw new Error('Erro ao buscar audit log');
    return res.json();
  }

  async health(): Promise<{ status: string; version: string }> {
    const base = await this.baseUrl();
    const res = await this.fetchApi.fetch(`${base}/v1/health`);
    return res.json();
  }
}
