#!/bin/bash
# Script de validación local de workflows

echo "=========================================="
echo "🧪 VALIDACIÓN LOCAL DE WORKFLOWS"
echo "=========================================="
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# PASO 1: Validar yamllint
echo "📋 PASO 1: Validando sintaxis YAML..."
echo ""

if ! command -v yamllint &> /dev/null; then
    echo -e "${YELLOW}⚠️  yamllint no instalado${NC}"
    echo "Instalar con: pip install yamllint --break-system-packages"
    ERRORS=$((ERRORS + 1))
else
    echo "Validando ci.yaml..."
    if yamllint .github/workflows/ci.yaml; then
        echo -e "${GREEN}✅ ci.yaml correcto${NC}"
    else
        echo -e "${RED}❌ ci.yaml tiene errores${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    echo ""

    echo "Validando deploy.yml..."
    if yamllint .github/workflows/deploy.yml; then
        echo -e "${GREEN}✅ deploy.yml correcto${NC}"
    else
        echo -e "${RED}❌ deploy.yml tiene errores${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    echo ""

    echo "Validando tag.yml..."
    if yamllint .github/workflows/tag.yml; then
        echo -e "${GREEN}✅ tag.yml correcto${NC}"
    else
        echo -e "${RED}❌ tag.yml tiene errores${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

echo ""
echo "=========================================="
echo "📋 PASO 2: Verificando estructura de archivos..."
echo ""

# Verificar que ci.yaml tiene yaml-lint job
if grep -q "yaml-lint:" .github/workflows/ci.yaml; then
    echo -e "${GREEN}✅ Job yaml-lint encontrado en ci.yaml${NC}"
else
    echo -e "${RED}❌ Job yaml-lint NO encontrado en ci.yaml${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Verificar que NO existe download-artifact
if grep -q "download-artifact" .github/workflows/ci.yaml; then
    echo -e "${RED}❌ download-artifact encontrado (debe eliminarse)${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ download-artifact eliminado correctamente${NC}"
fi

# Verificar que deploy.yml tiene 3 jobs separados
DEPLOY_JOBS=$(grep -c "deploy-" .github/workflows/deploy.yml)
if [ "$DEPLOY_JOBS" -eq 3 ]; then
    echo -e "${GREEN}✅ 3 jobs de deploy encontrados${NC}"
else
    echo -e "${RED}❌ Se esperaban 3 jobs, encontrados: $DEPLOY_JOBS${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Verificar needs en deploy
if grep -q "needs: deploy-dev" .github/workflows/deploy.yml && \
   grep -q "needs: deploy-staging" .github/workflows/deploy.yml; then
    echo -e "${GREEN}✅ Dependencias entre jobs correctas${NC}"
else
    echo -e "${RED}❌ Dependencias entre jobs incorrectas${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=========================================="
echo "📋 PASO 3: Validando manifiestos K8s (si existen)..."
echo ""

if [ -d "k8n" ]; then
    K8S_ERRORS=0
    find k8n -name "*.yaml" -o -name "*.yml" | while read -r file; do
        if yamllint -d relaxed "$file" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $file${NC}"
        else
            echo -e "${YELLOW}⚠️  $file tiene warnings${NC}"
        fi
    done

    # Verificar con kubectl dry-run si está disponible
    if command -v kubectl &> /dev/null; then
        echo ""
        echo "Validando con kubectl dry-run..."
        for env in dev staging prod; do
            if [ -d "k8n/overlays/$env" ]; then
                if kubectl apply -k k8n/overlays/$env \
                   --dry-run=client > /dev/null 2>&1; then
                    echo -e "${GREEN}✅ k8n/overlays/$env válido${NC}"
                else
                    echo -e "${RED}❌ k8n/overlays/$env inválido${NC}"
                    ERRORS=$((ERRORS + 1))
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠️  kubectl no disponible, \
saltando validación${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Directorio k8n no encontrado${NC}"
fi

echo ""
echo "=========================================="
echo "📊 RESUMEN"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ TODOS LOS TESTS PASARON${NC}"
    echo ""
    echo "Próximos pasos:"
    echo "1. git add .github/workflows/"
    echo "2. git commit -m 'fix: corregir workflows y añadir promotions'"
    echo "3. git push origin master"
    echo ""
    echo "Recuerda configurar en GitHub:"
    echo "- Settings → Environments → staging → Required reviewers"
    echo "- Settings → Environments → prod → Required reviewers"
    exit 0
else
    echo -e "${RED}❌ SE ENCONTRARON $ERRORS ERRORES${NC}"
    echo ""
    echo "Por favor, revisa los errores arriba y corrígelos."
    exit 1
fi