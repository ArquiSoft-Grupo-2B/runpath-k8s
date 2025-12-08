# Script para restaurar deployments desde k8s-raw-backup
# Elimina deployments actuales y restaura desde backup

Write-Host "=== RESTAURACION DE DEPLOYMENTS AL ESTADO PRE-SEGMENTACION ===" -ForegroundColor Cyan
Write-Host ""

# Paso 1: Eliminar NetworkPolicies
Write-Host "[1/6] Eliminando NetworkPolicies..." -ForegroundColor Yellow
kubectl delete networkpolicies --all -n backend 2>$null
kubectl delete networkpolicies --all -n orchestration 2>$null
kubectl delete networkpolicies --all -n presentation 2>$null
kubectl delete networkpolicies --all -n edge 2>$null
kubectl delete networkpolicies --all -n data 2>$null
kubectl delete networkpolicies --all -n default 2>$null
Write-Host "OK - NetworkPolicies eliminadas" -ForegroundColor Green
Write-Host ""

# Paso 2: Eliminar ingresses y statefulsets conflictivos
Write-Host "[2/6] Eliminando recursos conflictivos..." -ForegroundColor Yellow
kubectl delete ingress -n presentation frontend-ingress --ignore-not-found=true 2>$null
kubectl delete ingress -n orchestration mobile-ingress --ignore-not-found=true 2>$null
kubectl delete statefulset -n backend rabbitmq --ignore-not-found=true 2>$null
Write-Host "OK - Recursos conflictivos eliminados" -ForegroundColor Green
Write-Host ""

# Paso 3: Eliminar deployments actuales
Write-Host "[3/6] Eliminando deployments actuales..." -ForegroundColor Yellow
kubectl delete deployment auth-deployment -n backend --ignore-not-found=true 2>$null
kubectl delete deployment routes-deployment -n backend --ignore-not-found=true 2>$null
kubectl delete deployment distance-deployment -n backend --ignore-not-found=true 2>$null
kubectl delete deployment notification-deployment -n backend --ignore-not-found=true 2>$null
kubectl delete deployment api-gateway-deployment -n orchestration --ignore-not-found=true 2>$null
kubectl delete deployment frontend-deployment -n presentation --ignore-not-found=true 2>$null
kubectl delete deployment postgres-deployment -n default --ignore-not-found=true 2>$null
Write-Host "OK - Deployments eliminados" -ForegroundColor Green
Write-Host ""

# Paso 4: Esperar a que los pods terminen
Write-Host "[4/6] Esperando terminacion de pods (20 segundos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 20
Write-Host "OK - Pods terminados" -ForegroundColor Green
Write-Host ""

# Paso 5: Aplicar configuracion del backup
Write-Host "[5/6] Aplicando configuracion desde backup..." -ForegroundColor Yellow
Set-Location "c:\Users\DANIEL\Documents\UNI\sem 8\arquiSoft\proyecto\K8s-repo\k8s-raw-backup"

Write-Host "  - Aplicando ConfigMaps..."
kubectl apply -f configmaps.yaml 2>&1 | Out-Null
Write-Host "  - Aplicando Services..."
kubectl apply -f services.yaml 2>&1 | Out-Null
Write-Host "  - Aplicando Ingresses..."
kubectl apply -f ingresses.yaml 2>&1 | Out-Null
Write-Host "  - Aplicando StatefulSets..."
kubectl apply -f statefulsets.yaml 2>&1 | Select-String -Pattern "rabbitmq" | Out-Null
Write-Host "OK - Configuracion base aplicada" -ForegroundColor Green
Write-Host ""

# Paso 6: Aplicar deployments con server-side apply
Write-Host "[6/6] Aplicando Deployments..." -ForegroundColor Yellow
kubectl apply -f deployments.yaml --server-side=true --force-conflicts=true 2>&1 | Select-String -Pattern "deployment.*default" | ForEach-Object { Write-Host "  $_" }
Write-Host "OK - Deployments aplicados" -ForegroundColor Green
Write-Host ""

# Verificacion
Write-Host "=== VERIFICACION ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pods en namespace default:" -ForegroundColor Yellow
kubectl get pods -n default -o wide
Write-Host ""
Write-Host "NetworkPolicies restantes:" -ForegroundColor Yellow
$npCount = (kubectl get networkpolicies -A 2>$null | Measure-Object).Count - 1
if ($npCount -le 0) {
    Write-Host "  OK - No hay NetworkPolicies" -ForegroundColor Green
}
else {
    Write-Host "  ADVERTENCIA - Aun hay $npCount NetworkPolicies" -ForegroundColor Red
}
Write-Host ""
Write-Host "=== RESTAURACION COMPLETADA ===" -ForegroundColor Green
