# Testing Network Segmentation Pattern - RunPath Kubernetes

**Última actualización**: 8 de diciembre, 2025  
**Estado**: ⚠️ **PARCIALMENTE FUNCIONAL** - Distance service Pending por falta de recursos

---

## 📊 Estado Actual del Cluster

### ⚠️ Servicios por Tier (Total: 17/18 pods Running)

```
Tier 0 (Security):      ingress-nginx-controller   1/1 Running  (namespace: ingress-nginx)
Tier 1 (Presentation):  frontend-deployment        3/3 Running
Tier 3 (Orchestration): api-gateway-deployment     1/1 Running
Tier 5 (Backend):       auth-deployment            3/3 Running
                        routes-deployment          1/1 Running
                        distance-deployment        0/1 Pending ❌ (recursos insuficientes)
                        notification-deployment    3/3 Running
                        rabbitmq                   3/3 Running ✅
Tier 7 (Data):          postgres-deployment        1/1 Running (en default*)
```

### ⚠️ Problemas Detectados
- **Distance service**: ❌ Pending - cluster sin recursos CPU/memoria disponibles
- **Calico Typha**: ⚠️ 1 réplica Pending (no crítico para funcionamiento)

### ✅ Funcionando Correctamente
- **RabbitMQ**: ✅ 3 réplicas Running (PVCs aprovisionados)
- **NetworkPolicies**: ✅ 18 policies aplicadas
- **TLS Ingress**: ✅ Certificados Let's Encrypt activos

### ⚠️ Nota Temporal
- **Postgres en `default`**: Por migración de PVC pendiente (funcional con NetworkPolicy especial)

---

## 🧪 Pruebas de Segmentación por Tiers

### Comando Rápido: Obtener Nombres de Pods

```powershell
# Frontend
$FRONTEND_POD = kubectl get pods -n presentation -l app=frontend -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

# API Gateway  
$GATEWAY_POD = kubectl get pods -n orchestration -l app=api-gateway -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

# Auth
$AUTH_POD = kubectl get pods -n backend -l app=auth -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

# Routes
$ROUTES_POD = kubectl get pods -n backend -l app=routes -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

# Verificar
echo "Frontend: $FRONTEND_POD"
echo "Gateway: $GATEWAY_POD"
echo "Auth: $AUTH_POD"
echo "Routes: $ROUTES_POD"
```

---

### 1. Verificar Namespaces y Labels

**Objetivo**: Confirmar que los tiers están creados con las etiquetas correctas.

```powershell
kubectl get namespaces --show-labels | Select-String "tier"
```

**Resultado esperado**:
```
ingress-nginx     tier=security,tier-level=tier-0    (✅ Tier 0 real)
security          tier=security,tier-level=0          (namespace vacío - legacy)
presentation      tier=presentation,tier-level=1
edge              tier=edge,tier-level=2
orchestration     tier=orchestration,tier-level=3
backend           tier=backend,tier-level=5
data              tier=data,tier-level=7
```

**⚠️ Nota**: El namespace `security` está vacío. El Ingress Controller está en `ingress-nginx`.

---

### 2. Verificar Network Policies Aplicadas

**Objetivo**: Confirmar que las NetworkPolicies están activas.

```powershell
kubectl get networkpolicies -A
```

**Resultado esperado** (18 policies):
```
NAMESPACE       NAME                                         POD-SELECTOR         AGE
presentation    presentation-default-deny                    <none>               Xh
presentation    presentation-allow-from-security             tier=presentation    Xh
presentation    presentation-allow-to-orchestration          tier=presentation    Xh
orchestration   orchestration-default-deny                   <none>               Xh
orchestration   orchestration-allow-from-presentation-edge   tier=orchestration   Xh
orchestration   orchestration-allow-to-backend               tier=orchestration   Xh
backend         backend-default-deny                         <none>               Xh
backend         backend-allow-from-orchestration             tier=backend         Xh
backend         backend-allow-internal                       tier=backend         Xh
backend         backend-allow-to-data                        tier=backend         Xh
backend         backend-allow-to-default-postgres            tier=backend         Xh
data            data-default-deny                            <none>               Xh
data            data-allow-from-backend                      tier=data            Xh
data            data-allow-minimal-egress                    tier=data            Xh
default         default-allow-postgres-from-backend          app=postgres         Xh
edge            edge-default-deny                            <none>               Xh
edge            edge-allow-from-security                     tier=edge            Xh
edge            edge-allow-to-orchestration                  tier=edge            Xh
```

✅ **Total esperado**: **18 NetworkPolicies**

**Desglose por namespace**:
- `presentation`: 3 policies (deny + allow-from-security + allow-to-orchestration)
- `orchestration`: 3 policies (deny + allow-from-presentation-edge + allow-to-backend)
- `backend`: 5 policies (deny + allow-from-orchestration + allow-internal + allow-to-data + allow-to-default-postgres)
- `data`: 3 policies (deny + allow-from-backend + allow-minimal-egress)
- `edge`: 3 policies (deny + allow-from-security + allow-to-orchestration)
- `default`: 1 policy (allow-postgres-from-backend) - temporal

---

### 3. Prueba de Conectividad Permitida (Tier Adyacente)

#### 3.1. Frontend → API Gateway (Presentation → Orchestration) ✅

**Objetivo**: Verificar que el frontend puede conectarse al API Gateway.

```powershell
# Obtener pod automáticamente
$FRONTEND_POD = kubectl get pods -n presentation -l app=frontend -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

# Probar conexión
kubectl exec -n presentation $FRONTEND_POD -- wget -O- --timeout=10 http://api-gateway-service.orchestration.svc.cluster.local:80
```

**Resultado esperado**: 
- Conexión TCP exitosa (puede ser 404 si el endpoint no existe, pero la conexión debe establecerse)
- **NO debe haber timeout**

---

#### 3.2. API Gateway → Auth Service (Orchestration → Backend) ✅

**Objetivo**: Verificar que el API Gateway puede conectarse al servicio de autenticación.

```powershell
# Obtener pod automáticamente
$GATEWAY_POD = kubectl get pods -n orchestration -l app=api-gateway -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

# Probar conexión
kubectl exec -n orchestration $GATEWAY_POD -- wget -O- --timeout=10 http://auth-service.backend.svc.cluster.local:80
```

**Resultado esperado**: 
- Conexión TCP exitosa
- **NO debe haber timeout**

---

#### 3.3. Routes → PostgreSQL (Backend → Data/Default) ✅

**Objetivo**: Verificar que el servicio routes puede conectarse a la base de datos.

```powershell
# Obtener pod automáticamente
$ROUTES_POD = kubectl get pods -n backend -l app=routes -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

# Probar conexión a PostgreSQL (puerto 5432)
kubectl exec -n backend $ROUTES_POD -- sh -c "timeout 3 nc -zv postgres.default.svc.cluster.local 5432"
```

**Resultado esperado**:
```
postgres.default.svc.cluster.local (34.118.231.222:5432) open
```

⚠️ **Nota**: PostgreSQL está temporalmente en `default` namespace debido a PVC. La NetworkPolicy `backend-allow-to-default-postgres` permite este tráfico específicamente.

---

#### 3.4. Routes → RabbitMQ (Backend interno) ✅

**Objetivo**: Verificar conectividad interna dentro del tier backend.

```powershell
$ROUTES_POD = kubectl get pods -n backend -l app=routes -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

kubectl exec -n backend $ROUTES_POD -- sh -c "timeout 3 nc -zv rabbitmq.backend.svc.cluster.local 5672"
```

**Resultado esperado**:
```
rabbitmq.backend.svc.cluster.local (34.118.xxx.xxx:5672) open
```

---

### 4. Prueba de Conectividad BLOQUEADA (Salto de Tier) ❌

Estas pruebas **deben fallar** para confirmar que la segmentación está funcionando.

#### 4.1. Frontend → PostgreSQL (Presentation → Data) ❌ BLOQUEADO

**Objetivo**: Verificar que el frontend NO puede conectarse directamente a la base de datos.

```powershell
$FRONTEND_POD = kubectl get pods -n presentation -l app=frontend -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

kubectl exec -n presentation $FRONTEND_POD -- sh -c "timeout 5 wget -O- http://postgres.default.svc.cluster.local:5432" 2>&1
```

**Resultado esperado**: 
```
wget: download timed out
```
O `Resource temporarily unavailable` después de 5 segundos.

✅ **Si da timeout = NetworkPolicy está bloqueando correctamente**

---

#### 4.2. Frontend → Auth Service (Presentation → Backend) ❌ BLOQUEADO

**Objetivo**: Verificar que el frontend NO puede saltarse el API Gateway.

```powershell
$FRONTEND_POD = kubectl get pods -n presentation -l app=frontend -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

kubectl exec -n presentation $FRONTEND_POD -- sh -c "timeout 5 wget -O- http://auth-service.backend.svc.cluster.local:80" 2>&1
```

**Resultado esperado**: Timeout después de 5 segundos.

✅ **Si da timeout = Segmentación funcionando**

---

#### 4.3. API Gateway → PostgreSQL (Orchestration → Data) ❌ BLOQUEADO

**Objetivo**: Verificar que el orchestration tier NO puede saltarse el backend tier.

```powershell
$GATEWAY_POD = kubectl get pods -n orchestration -l app=api-gateway -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }

kubectl exec -n orchestration $GATEWAY_POD -- sh -c "timeout 5 nc -zv postgres.default.svc.cluster.local 5432" 2>&1
```

**Resultado esperado**: Connection timeout después de 5 segundos.

✅ **Si da timeout = Orchestration no puede acceder a Data directamente**

---

### 5. Verificar DNS Interno (Permitido en todos los tiers) ✅

**Objetivo**: Confirmar que todos los pods pueden resolver nombres DNS.

```powershell
# Desde presentation
$FRONTEND_POD = kubectl get pods -n presentation -l app=frontend -o name | Select-Object -First 1 | ForEach-Object { $_ -replace 'pod/', '' }
kubectl exec -n presentation $FRONTEND_POD -- nslookup api-gateway-service.orchestration.svc.cluster.local

# Desde backend
kubectl exec -it -n backend <routes-pod-name> -- nslookup postgres.default.svc.cluster.local

# Desde orchestration
kubectl exec -it -n orchestration <api-gateway-pod-name> -- nslookup auth-service.backend.svc.cluster.local
```

**Resultado esperado**: Todas las resoluciones DNS deben funcionar correctamente.

```
Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   <service>.<namespace>.svc.cluster.local
Address: 10.X.X.X
```

---

### 6. Verificar Ingress Público (Tier Security → Presentation/Orchestration)

#### 6.1. Ingress Web (runpath.duckdns.org)

**Objetivo**: Verificar que el tráfico público llega al frontend correctamente.

```bash
curl -k https://runpath.duckdns.org
```

**Resultado esperado**: HTML del frontend NextJS (código 200).

---

#### 6.2. Ingress Mobile (mobile.runpath.duckdns.org)

**Objetivo**: Verificar que el tráfico móvil llega al API Gateway.

```bash
curl -k https://mobile.runpath.duckdns.org/health
```

**Resultado esperado**: Respuesta del API Gateway.

---

#### 6.3. Verificar TLS Certificates

**Objetivo**: Confirmar que los certificados Let's Encrypt están activos.

```bash
kubectl get certificates -A
kubectl get ingress -A
```

**Resultado esperado**:
```
NAMESPACE       NAME               READY   AGE
presentation    frontend-tls       True    Xh
orchestration   api-gateway-tls    True    Xh

NAMESPACE       NAME               HOSTS                        ADDRESS          PORTS
presentation    frontend-ingress   runpath.duckdns.org          136.114.109.33   80,443
orchestration   mobile-ingress     mobile.runpath.duckdns.org   136.114.109.33   80,443
```

---

### 7. Verificar Egress a Servicios Externos (Backend → Internet)

**Objetivo**: Confirmar que los servicios backend pueden acceder a APIs externas (Firebase, SMTP).

```bash
# Probar HTTPS (443) a Firebase
kubectl exec -it -n backend <auth-pod-name> -- wget -O- --timeout=10 https://www.google.com

# Probar DNS externo
kubectl exec -it -n backend <notification-pod-name> -- nslookup smtp.gmail.com
```

**Resultado esperado**: Ambas conexiones deben funcionar (Network Policy permite egress 443/587).

---

### 8. Verificar Labels de Pods

**Objetivo**: Confirmar que todos los pods tienen las etiquetas tier correctas.

```bash
kubectl get pods -n presentation --show-labels
kubectl get pods -n orchestration --show-labels
kubectl get pods -n backend --show-labels
kubectl get pods -n default -l tier=data --show-labels
```

**Resultado esperado**: Todos los pods deben tener `tier=<tier-name>` y `tier-level=<number>`.

---

### 9. Prueba de Segmentación con Network Policy Describe

**Objetivo**: Inspeccionar las reglas aplicadas a un namespace específico.

```bash
# Ver reglas de backend
kubectl describe networkpolicy -n backend backend-allow-ingress
kubectl describe networkpolicy -n backend backend-allow-egress
kubectl describe networkpolicy -n backend backend-default-deny
```

**Resultado esperado**: Las políticas deben mostrar:
- **backend-default-deny**: Bloquea todo por defecto
- **backend-allow-ingress**: Permite desde `orchestration` tier
- **backend-allow-egress**: Permite hacia `data` tier, DNS, y puertos externos (443, 587)

---

### 10. Prueba de Fail-Safe: Reiniciar Pod y Verificar Segmentación

**Objetivo**: Confirmar que las Network Policies persisten después de reiniciar pods.

```bash
# Reiniciar un pod de frontend
kubectl rollout restart deployment frontend-deployment -n presentation

# Esperar a que vuelva a estar Running
kubectl get pods -n presentation -w

# Volver a probar conectividad bloqueada
kubectl exec -it -n presentation <nuevo-frontend-pod> -- wget -O- --timeout=5 http://postgres.default.svc.cluster.local:5432
```

**Resultado esperado**: La conexión debe seguir bloqueada (timeout).

---

## Pruebas de Funcionalidad End-to-End

### 11. Flujo Completo: Usuario Web → Frontend → API Gateway → Backend → Database

**Objetivo**: Verificar que el flujo completo de la aplicación funciona con la segmentación.

#### Paso 1: Acceder al frontend
```bash
curl -k https://runpath.duckdns.org
```
**Esperado**: HTML del frontend.

#### Paso 2: Verificar logs del frontend
```bash
kubectl logs -n presentation <frontend-pod-name> --tail=20
```
**Esperado**: Requests exitosos al API Gateway.

#### Paso 3: Verificar logs del API Gateway
```bash
kubectl logs -n orchestration <api-gateway-pod-name> --tail=20
```
**Esperado**: Proxying requests a backend services.

#### Paso 4: Verificar logs de auth
```bash
kubectl logs -n backend <auth-pod-name> --tail=20
```
**Esperado**: Requests de autenticación procesados.

#### Paso 5: Verificar logs de routes
```bash
kubectl logs -n backend <routes-pod-name> --tail=20
```
**Esperado**: Conexiones a PostgreSQL y RabbitMQ.

---

## Checklist de Validación Final

- [ ] 6 namespaces creados con labels tier correctos
- [ ] 18 Network Policies aplicadas
- [ ] Frontend (3 pods) Running en `presentation`
- [ ] API Gateway (1 pod) Running en `orchestration`
- [ ] Auth (3 pods) Running en `backend`
- [ ] Routes (1 pod) Running en `backend`
- [ ] Notifications (3 pods) Running en `backend`
- [ ] RabbitMQ (1 pod) Running en `backend`
- [ ] PostgreSQL (1 pod) Running en `default` (temporal)
- [ ] Ingress web funcional con TLS
- [ ] Ingress mobile funcional con TLS
- [ ] Frontend puede conectarse a API Gateway ✅
- [ ] API Gateway puede conectarse a backend services ✅
- [ ] Backend puede conectarse a PostgreSQL ✅
- [ ] Backend puede conectarse a RabbitMQ ✅
- [ ] Frontend NO puede conectarse a PostgreSQL ❌
- [ ] Frontend NO puede conectarse a backend services ❌
- [ ] API Gateway NO puede conectarse a PostgreSQL ❌
- [ ] DNS funciona en todos los tiers ✅
- [ ] Egress externo funciona desde backend (443, 587) ✅

---

## Limitaciones y Trabajo Pendiente

### Recursos Insuficientes
- **Distance deployment**: Requiere más CPU/memoria en el cluster
  - Solución: Escalar cluster GKE o reducir recursos de otros pods
  - Comando temporal: `kubectl scale deployment distance-deployment -n backend --replicas=0`

### Cuota de Disco Excedida
- **RabbitMQ replicas 2-3**: GKE tiene límite de 250GB SSD en us-central1
  - Solución: Solicitar aumento de cuota en Google Cloud Console
  - Alternativa: Cambiar a `standard` storage class (HDD) en lugar de `standard-rwo` (SSD)

### Postgres en Namespace Incorrecto
- **postgres-deployment**: Está en `default` en lugar de `data` por constraint del PVC
  - Solución futura: Migrar PVC con backup/restore
  - Network Policy ajustada: backend tiene egress permitido a default namespace

### Pods Zombie
- **auth-deployment**: 2 pods en ContainerStatusUnknown
  - Solución: `kubectl delete pod -n backend <pod-name> --force --grace-period=0`

---

## Comandos de Limpieza (Opcional)

```bash
# Limpiar pods zombie de auth
kubectl delete pod -n backend auth-deployment-6984fdb75d-t9rpl --force --grace-period=0
kubectl delete pod -n backend auth-deployment-6984fdb75d-wwn4c --force --grace-period=0

# Escalar distance a 0 hasta resolver recursos
kubectl scale deployment distance-deployment -n backend --replicas=0

# Reducir RabbitMQ a 1 réplica hasta resolver cuota SSD
kubectl scale statefulset rabbitmq -n backend --replicas=1
```

---

## Beneficios de Seguridad Demostrados

1. **Defensa en Profundidad**: 6 capas de segmentación (Security → Presentation → Edge → Orchestration → Backend → Data)
2. **Zero Trust**: Ningún tier puede comunicarse directamente con otro excepto adyacentes
3. **Blast Radius Limitado**: Compromiso en presentation no permite acceso a data
4. **Auditoría Clara**: Network Policies declarativas y versionadas
5. **Compliance**: Cumple principios de micro-segmentación
6. **DNS Seguro**: Resolución permitida sin bypass de segmentación
7. **TLS End-to-End**: Certificados Let's Encrypt en ingress

---

## Próximos Pasos (Mejoras Futuras)

1. **mTLS con Service Mesh**: Encriptar tráfico inter-tier con Istio/Linkerd
2. **OPA/Gatekeeper**: Validar labels tier en admission
3. **Falco**: Runtime security monitoring
4. **Pod Security Standards**: Restringir capabilities
5. **RBAC estricto**: Limitar modificación de Network Policies
6. **WAF**: ModSecurity en Ingress Controller
7. **Rate Limiting**: Limitar requests por tier
8. **Logging centralizado**: Fluentd/Elasticsearch para auditoría
