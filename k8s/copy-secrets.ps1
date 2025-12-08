# Script to copy secrets from default namespace to tier namespaces
# Run this after creating the tier namespaces but before deploying applications

Write-Host "🔐 Copying secrets to tier namespaces..." -ForegroundColor Cyan
Write-Host ""

# Backend namespace secrets
Write-Host "Backend namespace:" -ForegroundColor Yellow
$backendSecrets = @(
    "rabbitmq-cookie",
    "auth-env",
    "firebase-key",
    "firebase-config",
    "routes-secret"
)

foreach ($secret in $backendSecrets) {
    try {
        kubectl get secret $secret -n default -o yaml 2>$null | 
            ForEach-Object { $_ -replace 'namespace: default', 'namespace: backend' -replace 'creationTimestamp:.*', '' -replace 'resourceVersion:.*', '' -replace 'uid:.*', '' } | 
            kubectl apply -f - 2>&1 | Out-Null
        Write-Host "  ✓ $secret" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ $secret (not found or error)" -ForegroundColor Red
    }
}

# Orchestration namespace secrets
Write-Host "`nOrchestration namespace:" -ForegroundColor Yellow
$orchestrationSecrets = @(
    "api-gateway-env",
    "api-gateway-credentials"
)

foreach ($secret in $orchestrationSecrets) {
    try {
        kubectl get secret $secret -n default -o yaml 2>$null | 
            ForEach-Object { $_ -replace 'namespace: default', 'namespace: orchestration' -replace 'creationTimestamp:.*', '' -replace 'resourceVersion:.*', '' -replace 'uid:.*', '' } | 
            kubectl apply -f - 2>&1 | Out-Null
        Write-Host "  ✓ $secret" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ $secret (not found or error)" -ForegroundColor Red
    }
}

# Data namespace secrets
Write-Host "`nData namespace:" -ForegroundColor Yellow
# Postgres typically doesn't need secrets if using ConfigMap, but check anyway
Write-Host "  (No additional secrets needed - credentials in ConfigMap)" -ForegroundColor Gray

Write-Host "`n✓ Secret migration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Verify with:" -ForegroundColor Cyan
Write-Host "  kubectl get secrets -n backend" -ForegroundColor White
Write-Host "  kubectl get secrets -n orchestration" -ForegroundColor White
