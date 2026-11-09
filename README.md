# Banxico SIE API — Secure AWS Deployment

API desarrollada en Python para consultar información del Sistema de Información Económica (SIE) del Banco de México, desplegada en AWS mediante infraestructura como código con Terraform y contenedores Docker.

El proyecto busca demostrar un flujo de despliegue seguro, considerando la protección de credenciales, segmentación de red, control de acceso, ejecución de contenedores y administración de infraestructura.

## 1. Objetivos

- Consumir información del API de Banxico mediante autenticación por token.
- Exponer endpoints para consultar series económicas y el tipo de cambio FIX.
- Desplegar la aplicación en AWS utilizando ECS Fargate.
- Administrar la infraestructura mediante Terraform.
- Mantener las credenciales fuera del código fuente y de las imágenes Docker.
- Aplicar controles de seguridad en infraestructura, contenedores y ejecución.

## 2. Arquitectura

La solución utiliza una arquitectura basada en contenedores sobre AWS.

flowchart TD
    U["Cliente"] --> ALB["Application Load Balancer"]
    ALB --> ECS["ECS Fargate"]
    ECS --> API["Python API"]
    API --> B["Banxico SIE API"]
    ECS -. "Recuperación del secreto" .-> SM["AWS Secrets Manager"]
    ECS -. "Logs" .-> CW["CloudWatch Logs"]
    TF["Terraform"] --> AWS["AWS Infrastructure"]
    AWS --> VPC["VPC"]
    VPC --> ALB
    VPC --> ECS


### Componentes principales

| Componente | Responsabilidad |
|---|---|
| Python API | Lógica de aplicación y consumo de Banxico |
| Docker | Empaquetado y ejecución de la aplicación |
| Amazon ECR | Almacenamiento privado de imágenes |
| Amazon ECS Fargate | Ejecución de contenedores |
| Application Load Balancer | Entrada de tráfico HTTP |
| Amazon VPC | Segmentación de red |
| NAT Gateway | Conectividad saliente desde subredes privadas |
| AWS Secrets Manager | Almacenamiento del token de Banxico |
| AWS IAM | Control de acceso entre servicios |
| Amazon CloudWatch | Centralización de logs |
| Terraform | Aprovisionamiento de infraestructura |

## 3. Infraestructura de red

La infraestructura se despliega en `us-east-2` (Ohio).

| Recurso | CIDR |
|---|---|
| VPC | `10.20.0.0/16` |
| Public Subnet 1 | `10.20.1.0/24` |
| Public Subnet 2 | `10.20.2.0/24` |
| Private Subnet 1 | `10.20.11.0/24` |
| Private Subnet 2 | `10.20.12.0/24` |

El Application Load Balancer se encuentra en las subredes públicas. Las tareas ECS se ejecutan en subredes privadas.

La salida hacia servicios externos se realiza mediante un NAT Gateway.

## 4. API

### Endpoints disponibles

| Método | Endpoint | Descripción |
|---|---|---|
| GET | `/healthz` | Verificación de disponibilidad de la aplicación |
| GET | `/series/{ids}` | Consulta de series económicas |
| GET | `/series/{ids}/rango` | Consulta de observaciones dentro de un rango de fechas |
| GET | `/tipo-cambio` | Consulta del tipo de cambio FIX |

Serie utilizada para el tipo de cambio:

- Identificador: `SF43718`
- Fuente: Banco de México — Sistema de Información Económica.
- Información: tipo de cambio para solventar obligaciones denominadas en moneda extranjera, fecha de determinación (FIX).

### Ejemplos

```http
GET /healthz
GET /series/SF43718
GET /series/SF43718/rango?inicio=2026-11-01&fin=2026-11-06
GET /tipo-cambio
```

### Health Check

El endpoint `/healthz` permite verificar que la aplicación está operativa sin depender de la disponibilidad de Banxico.
Esto permite distinguir entre la disponibilidad del servicio y la disponibilidad de su proveedor externo.

## 5. Manejo de errores

La aplicación contempla errores relacionados con las solicitudes HTTP y la comunicación con el proveedor externo.
Se busca diferenciar entre errores de autenticación, solicitudes inválidas, límites de consumo, tiempos de espera y fallos del servicio externo.
Los errores deben proporcionar información suficiente para el diagnóstico sin exponer tokens, credenciales ni información sensible.

## 6. Construcción de la imagen Docker

La imagen utiliza un proceso multi-stage:

- Etapa de construcción: instalación de dependencias y preparación del entorno virtual.
- Etapa de ejecución: incorporación únicamente de los componentes necesarios para ejecutar la aplicación.

La imagen utiliza una versión de Python fijada mediante digest, ejecuta el proceso con un usuario no privilegiado y contiene un health check.

### Construcción

```powershell
docker build -t banxico-api:local .
```

### Ejecución local

Utilizar un token de prueba válido únicamente en un entorno local controlado. No incluir credenciales reales en comandos que puedan quedar almacenados en el historial.

```powershell
docker run --rm -p 8000:8000 --env-file .env banxico-api:local
```

### Verificación

```powershell
Invoke-RestMethod http://localhost:8000/healthz
```

## 7. Terraform

La infraestructura se separa en dos etapas:

- `bootstrap`: creación y configuración del almacenamiento remoto del estado de Terraform.
- `infrastructure`: aprovisionamiento de la infraestructura de aplicación y red.

El estado remoto utiliza Amazon S3 con versionamiento, cifrado y bloqueo mediante lockfile.

### Inicialización

Desde el directorio correspondiente:

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=deployment.tfplan
terraform apply deployment.tfplan
```

El proceso de bootstrap debe completarse antes de inicializar la infraestructura que utiliza el backend remoto.

### Organización

```text
terraform/
├── bootstrap/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
└── infrastructure/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    └── ...
```

La estructura representa la separación lógica de responsabilidades; consultar los archivos del repositorio para conocer todos los recursos definidos.

## 8. Despliegue en AWS

La imagen se almacena en un repositorio privado de Amazon ECR y es utilizada por la definición de tarea de ECS.

Repositorio:

```text
747301448948.dkr.ecr.us-east-2.amazonaws.com/banxico-api
```

Cluster:

```text
banxico-api-development
```

Servicio:

```text
banxico-api-api
```

La tarea ECS obtiene el token de Banxico desde AWS Secrets Manager durante su inicialización.

### Configuración del secreto

El recurso de Secrets Manager es administrado mediante Terraform. El valor del token se configura por separado y no se incorpora al código de infraestructura.

Variable utilizada por la aplicación:

```text
BANXICO_TOKEN
```

## 9. Verificación del despliegue

URL del Application Load Balancer:

```text
http://banxico-api-alb-851452176.us-east-2.elb.amazonaws.com
```

Pruebas realizadas:

| Prueba | Resultado |
|---|---|
| `/healthz` | Correcto |
| `/openapi.json` | Correcto |
| `/series/SF43718` | Correcto |
| `/tipo-cambio` | Correcto |
| Consulta real a Banxico | Correcto |
| Ejecución de contenedor en ECS | Correcto |

Los endpoints de consulta devolvieron información real de Banxico durante las pruebas de despliegue.

## 10. Documentación adicional

Las decisiones de arquitectura y seguridad se documentan por separado:

- [`docs/SECURITY-DECISIONS.md`](docs/SECURITY-DECISIONS.md)

Este documento describe las amenazas consideradas, las alternativas evaluadas, los controles implementados y las mejoras identificadas.

## 11. Limitaciones y consideraciones

La implementación corresponde a un entorno de desarrollo y evaluación técnica.

Entre sus limitaciones actuales:

- El Application Load Balancer utiliza HTTP y no cuenta todavía con un certificado TLS de ACM.
- Se utiliza una sola tarea ECS.
- Se utiliza un NAT Gateway compartido por las subredes privadas.
- No se ha implementado escalamiento automático.
- No se ha integrado todavía un pipeline CI/CD con análisis de seguridad automatizados.
- CloudTrail y VPC Flow Logs no forman parte de la infraestructura desplegada actualmente.

## 12. Costos

La infraestructura puede generar cargos por:

- NAT Gateway.
- Application Load Balancer.
- Ejecución de tareas ECS Fargate.
- Almacenamiento de imágenes en ECR.
- Almacenamiento y procesamiento de logs.
- AWS Secrets Manager.
- Almacenamiento de estado en S3.
