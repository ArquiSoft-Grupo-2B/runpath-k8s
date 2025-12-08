# GUÍA PASO A PASO: Restaurar al estado pre-segmentación
# Ejecuta estos comandos UNO POR UNO y verifica cada resultado

# ========================================
# PASO 1: ELIMINAR NETWORKPOLICIES
# ========================================
Write-Host "`n=== PASO 1: Eliminar NetworkPolicies ===" -ForegroundColor Cyan
kubectl delete networkpolicies --all -n backend
kubectl delete networkpolicies --all -n orchestration
kubectl delete networkpolicies --all -n presentation
kubectl delete networkpolicies --all -n edge
kubectl delete networkpolicies --all -n data
kubectl delete networkpolicies --all -n default

# Verificar que se eliminaron
kubectl get networkpolicies -A

# ========================================
# PASO 2: ELIMINAR DEPLOYMENTS ACTUALES
# ========================================
Write-Host "`n=== PASO 2: Eliminar deployments actuales ===" -ForegroundColor Cyan
kubectl delete deployment -n backend --all
kubectl delete deployment -n orchestration --all
kubectl delete deployment -n presentation --all
kubectl delete deployment -n default postgres-deployment

# Verificar que se eliminaron
kubectl get deployments -A | Select-String "backend|orchestration|presentation|default"

# ========================================
# PASO 3: ESPERAR LIMPIEZA
# ========================================
Write-Host "`n=== PASO 3: Esperando limpieza (30s) ===" -ForegroundColor Cyan
Start-Sleep -Seconds 30
kubectl get pods -n backend
kubectl get pods -n orchestration
kubectl get pods -n presentation

# ========================================
# PASO 4: RESTAURAR DESDE BACKUP
# ========================================
Write-Host "`n=== PASO 4: Restaurar configuración ===" -ForegroundColor Cyan

# Ir al directorio de backup
Set-Location "c:\Users\DANIEL\Documents\UNI\sem 8\arquiSoft\proyecto\K8s-repo\k8s-raw-backup"

# Aplicar en orden
kubectl apply -f configmaps.yaml
kubectl apply -f services.yaml
kubectl apply -f ingresses.yaml
kubectl apply -f statefulsets.yaml

# Aplicar deployments con server-side apply (ignora metadatos de runtime)
kubectl apply -f deployments.yaml --server-side=true --force-conflicts=true

# ========================================
# PASO 5: VERIFICACIÓN FINAL
# ========================================
Write-Host "`n=== PASO 5: Verificación ===" -ForegroundColor Cyan
kubectl get pods -n default -o wide
kubectl get services -n default
kubectl get ingress -A
kubectl get networkpolicies -A

Write-Host "`n✓ Restauración completada" -ForegroundColor Green
Write-Host "`nSi hay pods en Pending, espera unos minutos para que se programen." -ForegroundColor Yellow
