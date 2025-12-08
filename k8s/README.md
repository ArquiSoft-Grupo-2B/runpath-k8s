# RunPath Kubernetes Configuration

Esta carpeta contiene la definición declarativa de la infraestructura de la aplicación RunPath con **Network Segmentation Pattern** implementado mediante namespaces y NetworkPolicies.

## 🔒 Arquitectura de Seguridad

RunPath implementa una arquitectura de **segmentación por tiers** que replica y mejora el patrón que anteriormente usábamos con Docker networks. Cada tier está aislado en su propio namespace y solo puede comunicarse con los tiers adyacentes mediante NetworkPolicies estrictas.

**Flujo de tráfico:**
```
Internet → [Security/Ingress] → [Presentation/Edge] → [Orchestration] → [Backend] → [Data]
```

📖 **Documentación completa**:
- [NETWORK-SEGMENTATION-IMPLEMENTATION.md](./NETWORK-SEGMENTATION-IMPLEMENTATION.md) - ⭐ **NUEVO:** Documentación completa del patrón implementado
- [NETWORK-SEGMENTATION.md](./NETWORK-SEGMENTATION.md) - Arquitectura y deployment (original)
- [TESTING-NETWORK-SEGMENTATION.md](./TESTING-NETWORK-SEGMENTATION.md) - Pruebas de validación
- [CLEANUP-GUIDE.md](./CLEANUP-GUIDE.md) - Guía para eliminar recursos duplicados

## Estructura

La configuración está organizada por tipo de recurso para facilitar la navegación y el mantenimiento:

### Namespaces por Tier
*   **`namespaces/`**: Definición de los 6 namespaces que segmentan la aplicación por tiers de seguridad
    - `ingress-nginx` (Tier 0) - Ingress Controller NGINX ⚠️ **namespace real del tier 0**
    - `security` (Tier 0) - WAF y Security Gateway (actualmente vacío - legacy)
    - `presentation` (Tier 1) - Frontend Web
    - `edge` (Tier 2) - Mobile Gateway (actualmente sin pods)
    - `orchestration` (Tier 3) - API Gateway
    - `backend` (Tier 5) - Microservices y RabbitMQ
    - `data` (Tier 7) - PostgreSQL (⚠️ temporalmente en `default` por migración PVC)

### Recursos de Aplicación
*   **`deployments/`**: Definiciones de los microservicios y aplicaciones
    - `frontend-deployment.yaml` (→ namespace `presentation`)
    - `api-gateway-deployment.yaml` (→ namespace `orchestration`)
    - `auth-deployment.yaml` (→ namespace `backend`)
    - `routes-deployment.yaml` (→ namespace `backend`)
    - `distance-deployment.yaml` (→ namespace `backend`)
    - `notification-deployment.yaml` (→ namespace `backend`)
    - `postgres-deployment.yaml` (→ namespace `data`)

*   **`statefulsets/`**: Aplicaciones con estado
    - `rabbitmq.yaml` (→ namespace `backend`)

*   **`services/`**: Servicios ClusterIP para comunicación interna (cada uno en su namespace correcto)

*   **`ingresses/`**: Reglas de entrada pública
    - `frontend-ingress.yaml` (→ `presentation` namespace)
    - `mobile-ingress.yaml` (→ `orchestration` namespace)

*   **`configmaps/`**: Configuración de aplicaciones (migrados a sus namespaces)
    - Usan FQDNs para cross-namespace: `service.namespace.svc.cluster.local`

### Network Policies (⚠️ Crítico para Seguridad)
*   **`network-policies/`**: Políticas de segmentación de red
    - `tier-segmentation.yaml`: NetworkPolicies que implementan el patrón de segmentación
        - Default Deny All en cada namespace
        - Allow solo entre tiers adyacentes
        - Excepciones para DNS y comunicación interna

## 🚀 Deployment

### Orden de aplicación IMPORTANTE:

```bash
# 1. Crear namespaces primero
kubectl apply -f namespaces/namespaces.yaml

# 2. ConfigMaps (antes de deployments que los referencian)
kubectl apply -f configmaps/

# 3. Data tier primero (stateful)
kubectl apply -f deployments/postgres-deployment.yaml
kubectl apply -f services/postgres.yaml

# 4. Backend tier
kubectl apply -f statefulsets/rabbitmq.yaml
kubectl apply -f services/rabbitmq.yaml
kubectl apply -f deployments/auth-deployment.yaml
kubectl apply -f deployments/routes-deployment.yaml
kubectl apply -f deployments/distance-deployment.yaml
kubectl apply -f deployments/notification-deployment.yaml
kubectl apply -f services/auth-service.yaml
kubectl apply -f services/routes-service.yaml
kubectl apply -f services/distance-service.yaml
kubectl apply -f services/notification-deployment-service.yaml

# 5. Orchestration tier
kubectl apply -f deployments/api-gateway-deployment.yaml
kubectl apply -f services/api-gateway-service.yaml

# 6. Presentation tier
kubectl apply -f deployments/frontend-deployment.yaml
kubectl apply -f services/frontend-deployment-service.yaml

# 7. Ingresses
kubectl apply -f ingresses/frontend-ingress.yaml
kubectl apply -f ingresses/mobile-ingress.yaml

# 8. Network Policies (AL FINAL para no bloquear durante deployment)
kubectl apply -f network-policies/tier-segmentation.yaml
```

### Aplicación rápida (una vez que el orden esté claro):
```bash
# Aplicar toda la configuración
kubectl apply -f namespaces/
kubectl apply -f configmaps/
kubectl apply -f deployments/
kubectl apply -f statefulsets/
kubectl apply -f services/
kubectl apply -f ingresses/
kubectl apply -f network-policies/
```

## 🔍 Verificación

```bash
# Ver estado de todos los namespaces
kubectl get namespaces --show-labels

# Ver pods por tier
kubectl get pods -n ingress-nginx  # Tier 0
kubectl get pods -n presentation
kubectl get pods -n orchestration
kubectl get pods -n backend
kubectl get pods -n default  # PostgreSQL temporal

# Ver Network Policies aplicadas (deberían ser 18)
kubectl get networkpolicies -A

# Probar conectividad permitida (frontend → api-gateway)
kubectl exec -it -n presentation <frontend-pod> -- wget -O- http://api-gateway-service.orchestration.svc.cluster.local:80/health

# Verificar que conectividad prohibida falla (presentation → default/postgres)
kubectl exec -it -n presentation <frontend-pod> -- wget -O- --timeout=5 http://postgres.default.svc.cluster.local:5432
# Debe fallar por Network Policy (timeout esperado)
```

## Convenciones

*   **Namespaces**: Cada componente está en el namespace de su tier de seguridad
*   **Labels**: Todos los recursos tienen labels `tier` y `tier-level` para identificación
*   **FQDNs**: Las referencias cross-namespace usan FQDNs completos: `service.namespace.svc.cluster.local`
*   **Services**: Todos ClusterIP (internos), excepto LoadBalancer/NodePort si es necesario
*   **Limpieza**: Los archivos YAML no contienen campos de estado (`status`), UIDs, ni `resourceVersion`
*   **Seguridad**: Network Policies en modo "default deny" con allows explícitos

## 📚 Documentación Adicional

- **[NETWORK-SEGMENTATION.md](./NETWORK-SEGMENTATION.md)**: Documentación completa del patrón de segmentación
- Detalles de cada tier y sus componentes
- Mapeo desde Docker networks a Kubernetes namespaces
- Troubleshooting y verificación
- Security benefits y próximos pasos

## ⚠️ Notas Importantes

1. **Network Policies**: Aplicar AL FINAL del deployment para evitar bloquear pods durante la creación
2. **ConfigMaps**: Deben existir ANTES de crear deployments que los referencian
3. **Secrets**: No están en este repo (se crean manualmente o con herramientas de CI/CD)
4. **DNS**: Los pods pueden tardar unos segundos en resolver FQDNs después de crearse los services
5. **RabbitMQ**: Es un StatefulSet que requiere almacenamiento persistente configurado en el cluster

## 🚨 Problemas Conocidos (Estado Actual)

1. **Distance Service**: Pod en estado `Pending` por recursos insuficientes en el cluster (requiere scale-up de nodos o liberar recursos)
2. **Namespace `security`**: Está vacío - el Tier 0 usa `ingress-nginx` namespace (considerar eliminar `security` o consolidar)
3. **PostgreSQL en `default`**: Por migración de PVC pendiente - funciona con NetworkPolicy especial `backend-allow-to-default-postgres`
4. **Calico Typha**: 1 réplica en Pending (no crítico - 1 réplica funcional es suficiente para 2 nodos)
