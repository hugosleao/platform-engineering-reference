# 04-platform — ponto de entrada
# Todos os recursos estão nos arquivos .tf deste módulo:
#   argocd.tf      — ArgoCD via Helm
#   backstage.tf   — Backstage via Helm
#   crossplane.tf  — Crossplane via Helm
#   postgresql.tf  — PostgreSQL in-cluster via Helm
#   kaniko.tf      — ServiceAccount para build de imagens
#   outputs.tf     — outputs do módulo
#
# providers.tf já define: terraform backend, providers aws/kubernetes/helm,
# data sources (EKS remote state) e namespaces.
#
# Não há recursos adicionais aqui — tudo está organizado nos arquivos acima.
