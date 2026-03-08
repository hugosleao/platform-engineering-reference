import React, { useState } from 'react';
import {
  Progress,
  InfoCard,
  StructuredMetadataTable,
} from '@backstage/core-components';
import { useCreateService } from '../hooks/usePlatformBroker';

export function CreateServiceForm() {
  const { execute, loading, error, result } = useCreateService();

  const [form, setForm] = useState({
    name: '',
    description: '',
    team: '',
    private: true,
    withRDS: false,
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await execute({
      name: form.name,
      description: form.description,
      team: form.team,
      private: form.private,
      infra: form.withRDS
        ? { kind: 'RDSInstance', spec: { engine: 'postgres', size: 'small' } }
        : undefined,
    });
  };

  if (loading) return <Progress />;

  if (result) {
    return (
      <InfoCard title="Serviço criado com sucesso">
        <StructuredMetadataTable
          metadata={{
            Repositório: result.repo.html_url,
            ArgoCD: result.argocd?.name ?? 'N/A',
            Infra: result.infra?.kind ?? 'Nenhuma',
            'Status Infra': result.infra?.status ?? '-',
          }}
        />
      </InfoCard>
    );
  }

  return (
    <InfoCard title="Criar Novo Serviço">
      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '12px', maxWidth: 480 }}>
        <label>
          Nome do serviço
          <input
            required
            value={form.name}
            onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
            placeholder="payment-service"
            style={{ display: 'block', width: '100%', marginTop: 4 }}
          />
        </label>
        <label>
          Descrição
          <input
            value={form.description}
            onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
            style={{ display: 'block', width: '100%', marginTop: 4 }}
          />
        </label>
        <label>
          Time (slug GitHub)
          <input
            required
            value={form.team}
            onChange={e => setForm(f => ({ ...f, team: e.target.value }))}
            placeholder="squad-payments"
            style={{ display: 'block', width: '100%', marginTop: 4 }}
          />
        </label>
        <label>
          <input
            type="checkbox"
            checked={form.withRDS}
            onChange={e => setForm(f => ({ ...f, withRDS: e.target.checked }))}
          />{' '}
          Provisionar banco de dados (RDS PostgreSQL)
        </label>
        {error && <p style={{ color: 'red' }}>{error}</p>}
        <button type="submit" disabled={loading}>
          Criar Serviço
        </button>
      </form>
    </InfoCard>
  );
}
