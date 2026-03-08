import React from 'react';
import { useEntity } from '@backstage/plugin-catalog-react';
import { InfoCard, Progress } from '@backstage/core-components';
import { calculateScore } from '../checks/maturityChecks';

const LEVEL_COLOR: Record<string, string> = {
  bronze: '#cd7f32',
  silver: '#c0c0c0',
  gold: '#ffd700',
  platinum: '#00bcd4',
};

const CATEGORY_LABEL: Record<string, string> = {
  docs: 'Documentação',
  observability: 'Observabilidade',
  security: 'Segurança',
  gitops: 'GitOps',
  infra: 'Infraestrutura',
};

export function ScorecardCard() {
  const { entity } = useEntity();
  const result = calculateScore(entity);

  const byCategory = result.checks.reduce((acc, c) => {
    if (!acc[c.category]) acc[c.category] = [];
    acc[c.category].push(c);
    return acc;
  }, {} as Record<string, typeof result.checks>);

  return (
    <InfoCard title="Scorecard de Maturidade">
      <div style={{ marginBottom: 16, textAlign: 'center' }}>
        <span style={{
          fontSize: 48,
          fontWeight: 'bold',
          color: LEVEL_COLOR[result.level],
        }}>
          {result.percentage}%
        </span>
        <div style={{
          fontSize: 18,
          textTransform: 'uppercase',
          color: LEVEL_COLOR[result.level],
          letterSpacing: 2,
        }}>
          {result.level}
        </div>
        <div style={{ color: '#888', fontSize: 13 }}>
          {result.score} / {result.maxScore} pontos
        </div>
      </div>

      {Object.entries(byCategory).map(([cat, checks]) => (
        <div key={cat} style={{ marginBottom: 16 }}>
          <div style={{ fontWeight: 'bold', marginBottom: 6 }}>
            {CATEGORY_LABEL[cat] ?? cat}
          </div>
          {checks.map(c => (
            <div key={c.id} style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              marginBottom: 4,
              fontSize: 13,
            }}>
              <span>{c.passed ? '✅' : '❌'}</span>
              <span style={{ flex: 1 }}>{c.title}</span>
              <span style={{ color: '#888' }}>{c.weight}pts</span>
            </div>
          ))}
        </div>
      ))}
    </InfoCard>
  );
}
