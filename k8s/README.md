# RunPath Kubernetes Configuration

Esta carpeta contiene la definición declarativa de la infraestructura de la aplicación RunPath. Es la fuente de verdad para el despliegue en el clúster usado para la aplcaion runpath.

## Estructura

La configuración está organizada por tipo de recurso para facilitar la navegación y el mantenimiento:

*   **`deployments/`**: Definiciones de los microservicios y aplicaciones (Auth, API Gateway, Frontend, etc.).
*   **`services/`**: Servicios de Kubernetes para la comunicación interna y descubrimiento de servicios.
*   **`ingresses/`**: Reglas de entrada para exponer servicios al exterior (Frontend, Mobile Proxy).
*   **`configmaps/`**: Archivos de configuración y variables de entorno no sensibles.
*   **`statefulsets/`**: Aplicaciones con estado (ej. RabbitMQ).
*   **`security-baseline.yaml`**: Políticas de red base (ej. Deny-All por defecto).
*   **`network-policies-allow.yaml`**: Excepciones y reglas de permiso de tráfico entre servicios.

## Convenciones

*   **Limpieza**: Los archivos YAML no contienen campos de estado (`status`), UIDs, ni `resourceVersion`.
*   **Enfoque**: Solo se incluyen recursos pertenecientes a la aplicación. Los recursos de sistema (`kube-system`, `cert-manager`, etc.) se gestionan por separado o son nativos del clúster.

## Uso

Para aplicar cambios en el clúster:

```bash
# Aplicar toda la configuración
kubectl apply -R -f .

# Aplicar un recurso específico
kubectl apply -f deployments/auth-deployment.yaml
```
