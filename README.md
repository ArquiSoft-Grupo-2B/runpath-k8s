# Kubernetes Infrastructure Repository

Este repositorio contiene la configuración de infraestructura para el proyecto RunPath en Kubernetes.

## Estructura de Carpetas

### 📂 `k8s/` (Fuente de Verdad)
Contiene la configuración **limpia y estructurada** de la aplicación.
- Esta es la carpeta principal de trabajo ("Infrastructure as Code").
- Los archivos han sido limpiados de metadatos de runtime (status, uids, timestamps).
- Se han eliminado componentes del sistema (kube-system, gke-managed) para enfocar la configuración en la lógica de negocio.
- **Uso:** Aquí es donde se deben realizar los cambios y aplicar al clúster (`kubectl apply -f k8s/`).

### 📂 `k8s-raw-backup/` (Backup Crudo)
Contiene una "foto" (snapshot) del estado del clúster tomada directamente con `kubectl get ... -o yaml`.
- Incluye todos los campos de runtime y recursos del sistema.
- **Propósito:** Referencia histórica y backup de seguridad. No se debe editar ni aplicar directamente a menos que sea estrictamente necesario para recuperación.
