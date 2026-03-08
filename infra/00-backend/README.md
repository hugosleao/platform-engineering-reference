# 00-backend: Terraform State Backend

Cria infraestrutura para armazenar Terraform state de forma segura.

## Recursos Criados

- **S3 Bucket**: `hugosleao-terraform-state-{account_id}`
  - Versioning habilitado
  - Encryption AES256
  - Public access bloqueado

- **DynamoDB Table**: `hugosleao-terraform-locks`
  - State locking
  - Pay-per-request (sem custo fixo)

- **S3 Bucket**: `hugosleao-lab-backup-{account_id}`
  - Para backups Backstage/ArgoCD
  - Lifecycle: 30 dias
  - Versioning habilitado

## Deploy

```bash
cd terraform/00-backend

# Inicializar (state local apenas neste módulo)
terraform init

# Planejar
terraform plan

# Aplicar
terraform apply

# Copiar outputs para usar nos próximos módulos
terraform output
```

## Custo Estimado

| Recurso | Custo/Mês |
|---------|-----------|
| S3 State (1GB) | $0,02 |
| S3 Backup (5GB) | $0,12 |
| DynamoDB (baixo uso) | $0,01 |
| **TOTAL** | **~$0,15/mês (R$ 0,80)** |

## Importante

⚠️ **Este módulo NÃO usa remote state** (chicken-egg problem).

Após criar, configure os outros módulos para usar este backend.
