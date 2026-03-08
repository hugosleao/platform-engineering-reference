import { Entity } from '@backstage/catalog-model';

export interface MaturityCheck {
  id: string;
  title: string;
  description: string;
  category: 'observability' | 'security' | 'docs' | 'gitops' | 'infra';
  weight: number;
  pass: (entity: Entity) => boolean;
}

export const maturityChecks: MaturityCheck[] = [
  // Docs
  {
    id: 'has-techdocs',
    title: 'TechDocs configurado',
    description: 'Componente possui anotação backstage.io/techdocs-ref',
    category: 'docs',
    weight: 10,
    pass: e => !!e.metadata.annotations?.['backstage.io/techdocs-ref'],
  },
  {
    id: 'has-description',
    title: 'Descrição preenchida',
    description: 'Componente possui descrição no catálogo',
    category: 'docs',
    weight: 5,
    pass: e => !!e.metadata.description && e.metadata.description.length > 10,
  },
  {
    id: 'has-owner',
    title: 'Owner definido',
    description: 'Componente possui owner (spec.owner)',
    category: 'docs',
    weight: 10,
    pass: e => !!(e.spec as any)?.owner,
  },

  // Observability
  {
    id: 'has-grafana',
    title: 'Dashboard Grafana vinculado',
    description: 'Anotação grafana/dashboard-url presente',
    category: 'observability',
    weight: 15,
    pass: e => !!e.metadata.annotations?.['grafana/dashboard-url'],
  },
  {
    id: 'has-pagerduty',
    title: 'Alertas configurados',
    description: 'Anotação pagerduty.com/integration-key presente',
    category: 'observability',
    weight: 10,
    pass: e => !!e.metadata.annotations?.['pagerduty.com/integration-key'],
  },

  // Security
  {
    id: 'has-sonar',
    title: 'SonarQube configurado',
    description: 'Anotação sonarqube.org/project-key presente',
    category: 'security',
    weight: 15,
    pass: e => !!e.metadata.annotations?.['sonarqube.org/project-key'],
  },
  {
    id: 'has-veracode',
    title: 'Veracode configurado',
    description: 'Anotação veracode.com/app-profile presente',
    category: 'security',
    weight: 10,
    pass: e => !!e.metadata.annotations?.['veracode.com/app-profile'],
  },

  // GitOps
  {
    id: 'has-argocd',
    title: 'ArgoCD configurado',
    description: 'Anotação argocd/app-name presente',
    category: 'gitops',
    weight: 15,
    pass: e => !!e.metadata.annotations?.['argocd/app-name'],
  },
  {
    id: 'has-pipeline',
    title: 'Pipeline CI/CD definido',
    description: 'Anotação github.com/project-slug presente',
    category: 'gitops',
    weight: 10,
    pass: e => !!e.metadata.annotations?.['github.com/project-slug'],
  },
];

export interface ScorecardResult {
  score: number;
  maxScore: number;
  percentage: number;
  level: 'bronze' | 'silver' | 'gold' | 'platinum';
  checks: Array<MaturityCheck & { passed: boolean }>;
}

export function calculateScore(entity: Entity): ScorecardResult {
  const checks = maturityChecks.map(c => ({ ...c, passed: c.pass(entity) }));
  const score = checks.filter(c => c.passed).reduce((acc, c) => acc + c.weight, 0);
  const maxScore = checks.reduce((acc, c) => acc + c.weight, 0);
  const percentage = Math.round((score / maxScore) * 100);

  let level: ScorecardResult['level'] = 'bronze';
  if (percentage >= 90) level = 'platinum';
  else if (percentage >= 70) level = 'gold';
  else if (percentage >= 50) level = 'silver';

  return { score, maxScore, percentage, level, checks };
}
