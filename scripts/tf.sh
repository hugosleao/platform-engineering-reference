#!/bin/bash
# ==========================================
# Terraform Wrapper com Infracost
# Uso: ./tf.sh {plan|apply|destroy}
# ==========================================

set -e

COMMAND="${1:-plan}"

# Buscar API key do Infracost automaticamente
if [ -z "$INFRACOST_API_KEY" ]; then
    INFRACOST_API_KEY=$(infracost configure get api_key 2>/dev/null || echo "")
    export INFRACOST_API_KEY
fi

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==========================================
# Função: Verificar Infracost
# ==========================================
check_infracost() {
    if ! command -v infracost &> /dev/null; then
        echo -e "${YELLOW}⚠️  Infracost não instalado. Instalando...${NC}"
        brew install infracost || {
            echo -e "${RED}❌ Falha ao instalar Infracost${NC}"
            echo "Instale manualmente: brew install infracost"
            exit 1
        }
    fi
    
    if [ -z "$INFRACOST_API_KEY" ]; then
        echo -e "${YELLOW}⚠️  INFRACOST_API_KEY não configurada${NC}"
        echo "Configure: infracost auth login"
        echo "Ou defina: export INFRACOST_API_KEY=your_key"
        echo ""
        echo -e "${BLUE}Continuando sem estimativa de custo...${NC}"
        return 1
    fi
    
    return 0
}

# ==========================================
# Função: Salvar Timestamp de Criação
# ==========================================
save_creation_time() {
    local timestamp_file=".terraform-created-at"
    date +%s > "$timestamp_file"
    echo -e "${GREEN}📝 Timestamp de criação salvo${NC}"
}

# ==========================================
# Função: Calcular Tempo de Vida
# ==========================================
calculate_lifetime() {
    local timestamp_file=".terraform-created-at"
    
    if [ ! -f "$timestamp_file" ]; then
        echo -e "${YELLOW}⚠️  Timestamp de criação não encontrado${NC}"
        return 1
    fi
    
    local created_at=$(cat "$timestamp_file")
    local now=$(date +%s)
    local lifetime=$((now - created_at))
    
    local hours=$((lifetime / 3600))
    local minutes=$(((lifetime % 3600) / 60))
    
    echo "$hours:$minutes"
}

# ==========================================
# Função: Terraform Plan com Infracost
# ==========================================
terraform_plan() {
    echo -e "${BLUE}📊 Executando: terraform plan${NC}"
    terraform plan -out=tfplan
    
    if check_infracost; then
        echo ""
        echo -e "${BLUE}💰 Calculando custos estimados...${NC}"
        infracost breakdown --path tfplan --format table --show-skipped
        
        echo ""
        echo -e "${GREEN}💡 Custo por hora e por mês:${NC}"
        infracost breakdown --path tfplan --format json | jq -r '
            .projects[].breakdown.resources[] | 
            select(.hourlyCost != null) | 
            "\(.name): $\(.hourlyCost)/hora ($\(.monthlyCost)/mês)"
        '
    fi
}

# ==========================================
# Função: Terraform Apply com Infracost
# ==========================================
terraform_apply() {
    echo -e "${BLUE}🚀 Executando: terraform apply${NC}"
    
    if check_infracost; then
        # Gerar breakdown antes de aplicar
        terraform plan -out=tfplan_apply
        
        echo ""
        echo -e "${YELLOW}💰 CUSTO ESTIMADO ANTES DE APLICAR:${NC}"
        infracost breakdown --path tfplan_apply --format table
        
        echo ""
        read -p "Continuar com terraform apply? (yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            echo -e "${RED}❌ Apply cancelado${NC}"
            rm -f tfplan_apply
            exit 0
        fi
        
        rm -f tfplan_apply
    fi
    
    terraform apply
    
    # Salvar timestamp após apply bem-sucedido
    save_creation_time
    
    if check_infracost; then
        echo ""
        echo -e "${GREEN}✅ INFRAESTRUTURA CRIADA!${NC}"
        echo ""
        echo -e "${BLUE}💰 CUSTO ATUAL:${NC}"
        infracost breakdown --path . --format table
    fi
}

# ==========================================
# Função: Terraform Destroy com Custo Total
# ==========================================
terraform_destroy() {
    local lifetime_str=$(calculate_lifetime)
    
    if check_infracost; then
        echo ""
        echo -e "${BLUE}💰 CUSTO ATUAL DA INFRAESTRUTURA:${NC}"
        infracost breakdown --path . --format table
        
        # Calcular custo total baseado no tempo de vida
        if [ -n "$lifetime_str" ]; then
            local hours=$(echo "$lifetime_str" | cut -d: -f1)
            local minutes=$(echo "$lifetime_str" | cut -d: -f2)
            
            echo ""
            echo -e "${YELLOW}⏱️  TEMPO DE VIDA:${NC}"
            echo "   ${hours}h ${minutes}min"
            
            # Pegar custo por hora do Infracost
            local hourly_cost=$(infracost breakdown --path . --format json | jq -r '.totalHourlyCost // "0"')
            
            if [ "$hourly_cost" != "0" ]; then
                local total_hours=$(echo "$hours + ($minutes / 60)" | bc -l)
                local total_cost=$(echo "$hourly_cost * $total_hours" | bc -l)
                
                echo ""
                echo -e "${GREEN}💵 CUSTO TOTAL ESTIMADO:${NC}"
                printf "   \$%.2f/hora × %.2fh = \$%.2f\n" "$hourly_cost" "$total_hours" "$total_cost"
            fi
        fi
        
        echo ""
        read -p "Confirmar destroy? (yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            echo -e "${RED}❌ Destroy cancelado${NC}"
            exit 0
        fi
    fi
    
    echo -e "${RED}🗑️  Executando: terraform destroy${NC}"
    terraform destroy
    
    # Limpar timestamp após destroy
    rm -f .terraform-created-at
    
    echo ""
    echo -e "${GREEN}✅ Infraestrutura destruída!${NC}"
    
    if [ -n "$lifetime_str" ]; then
        echo -e "${BLUE}📊 RESUMO FINAL:${NC}"
        echo "   Tempo de vida: $lifetime_str"
        if [ "$hourly_cost" != "0" ]; then
            printf "   Custo total: \$%.2f\n" "$total_cost"
        fi
    fi
}

# ==========================================
# Menu Principal
# ==========================================
case "$COMMAND" in
    plan)
        terraform_plan
        ;;
    apply)
        terraform_apply
        ;;
    destroy)
        terraform_destroy
        ;;
    *)
        echo "Uso: $0 {plan|apply|destroy}"
        exit 1
        ;;
esac
