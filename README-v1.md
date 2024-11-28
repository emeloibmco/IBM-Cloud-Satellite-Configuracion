# **IBM Cloud Satellite - Configuración**

Esta guía ofrece un paso a paso para crear una ubicación de IBM Cloud Satellite, desplegar un clúster de OpenShift y configurar Satellite Config.

**Nota:** Esta guía está diseñada para un despliegue rápido e intuitivo de un clúster y una aplicación, sin requerir conocimientos técnicos profundos. Para un entendimiento más detallado de la solución IBM Cloud Satellite y su gestión, consulta el otro archivo `README.md`.


## **Contenido**

1. [Pre-requisitos](#pre-requisitos)
2. [Creación de la ubicación de Satellite](#creación-de-la-ubicación-de-satellite)
3. [Schematics y Terraform](#schematics-y-terraform)
   1. [Creación del workspace](#creación-del-workspace)
   2. [Generación del plan](#generación-del-plan)
   3. [Ejecución del plan](#ejecución-del-plan)
4. [Asignación de hosts al control plane](#asignación-de-hosts-al-control-plane)
5. [Instalación de OpenShift](#instalación-de-openshift)
6. [Satellite config](#Satellite-config)
7. [Eliminación](#eliminación)

---

## **Pre-requisitos** :pencil:

- Contar con una cuenta en [IBM Cloud](https://cloud.ibm.com/).
- Permisos sobre **Schematics**, **Satellite**, **OpenShift** e infraestructura clásica. 

Se utilizará un pequeño proyecto de Terraform para levantar la infraestructura necesaria en IBM Cloud, facilitando el despliegue de los servicios de IBM Cloud Satellite de manera rápida y sencilla.

---

## **Creación de la ubicación de Satellite**

1. En el menú principal, selecciona **On-premises & Edge**.

   ![image](https://github.com/user-attachments/assets/b6871219-0100-4387-9660-78bef70fb078)

2. Utiliza un grupo de recursos con los permisos necesarios y selecciona la opción de **RHEL**.

   ![image](https://github.com/user-attachments/assets/2c2691ff-9d23-444d-959e-f1839fd37f0d)

3. Descarga el script para la asignación de hosts.

   ![image](https://github.com/user-attachments/assets/44eb01d9-91ea-40ad-a805-b964bd833ae8)

---

## **Schematics y Terraform**

Antes de comenzar con **Schematics**, realiza un fork de este repositorio e intercambia el archivo `attachHost-satellite-location.sh` con el que descargaste en el paso anterior.

   ![image](https://github.com/user-attachments/assets/2bfec9a6-150e-437c-8a26-da17a580c6d8)

### **Creación del workspace**

1. A partir del fork del repositorio, crea un **workspace** en Schematics apuntando al directorio `terraform-infraestructura`.

   ![image](https://github.com/user-attachments/assets/54abe4a3-48ef-4ac6-85dc-bffb9e778874)

2. Utiliza el grupo de recursos con los permisos necesarios. Los permisos sobre infraestructura clásica recaen en el usuario.

   ![image](https://github.com/user-attachments/assets/1b27be25-42ec-4e0e-b357-a6fcd5fa2aab)

---

### **Generación del plan**

En este proecso se analiza la infraestructura actual y compara los cambios definidos en el código de configuración. Esto genera un plan detallado que muestra las acciones que se tomarán (crear, modificar o eliminar recursos) sin aplicarlas aún.

1. Antes de generar el plan, verifica las variables que se utilizarán.
   - Los valores predeterminados funcionan correctamente en la mayoría de los casos.
   - Si necesitas realizar cambios, es preferible editarlas directamente en los archivos de Terraform con un editor de código. Las listas de hosts pueden ser especialmente propensas a errores si se editan desde la consola de IBM Cloud.

   ![image](https://github.com/user-attachments/assets/616c53f8-082e-468b-93c4-0cc962e9f71f)

2. Una vez revisadas las variables, procede a generar el plan.

   ![image](https://github.com/user-attachments/assets/008875f9-338e-472e-a0e8-f53e9c9152a9)

---

### **Ejecución del plan**

Terraform realiza las acciones especificadas para alinear la infraestructura con el estado deseado definido en el código.

1. Después de generar el plan correctamente, aplica el plan y revisa los logs generados.

   ![image](https://github.com/user-attachments/assets/2d91bc9b-e4a8-4a81-85e5-b84f30cffaf0)

2. La ejecución del plan será exitosa si todos los hosts creados son visibles en la consola de Satellite con el estado **Ready**.

   ![image](https://github.com/user-attachments/assets/15ecfaf3-16b3-4166-a968-a167e75741c4)

---

## **Asignación de hosts al control plane**

Asigna los hosts correspondientes al control plane en las zonas correspondientes. Los hosts para los workers se asignarán durante la instalación de OpenShift.

![image](https://github.com/user-attachments/assets/1434fea6-2501-479e-9402-e0d586379cb9)

---

## **Instalación de OpenShift**

1. Desde la consola de IBM Cloud, selecciona la infraestructura de Satellite.
2. Escoge la ubicación creada previamente, el grupo de recursos con los permisos necesarios y define las características de los hosts existentes en la ubicación.

   ![image](https://github.com/user-attachments/assets/6a33fc08-16a0-4314-84a7-41083b0282f6)

   **Nota:** para usar satellite config es necesario habilites el acceso de administracion de satellite al momento de desplegar el cluster.

---

## Satellite-config

Satellite Config es una herramienta de IBM Cloud que permite gestionar la implementación de recursos de Kubernetes en clústeres de Red Hat OpenShift, ya sea en ubicaciones de IBM Cloud Satellite o en IBM Cloud. Soporta configuraciones basadas en GitOps o mediante carga directa, facilitando el despliegue automatizado y consistente al integrarse con repositorios Git.

![image](https://github.com/user-attachments/assets/0e1d9dbb-d956-4530-baf0-e16a9882ebf6)

Al crear una configuración, utiliza la opción de GitOps y configura GitHub como proveedor.

![image](https://github.com/user-attachments/assets/6879dd26-8b10-4d4d-85b7-efaf95e6568f)

![image](https://github.com/user-attachments/assets/82f49391-d0ff-4b85-9c50-2018982f44ca)

Aplica la siguiente configuración para añadir el ejemplo contenido en este repositorio.

![image](https://github.com/user-attachments/assets/0833053f-fb7c-43f3-82e9-b83bac357ca7)

Antes de proceder, crea un grupo de clústeres; en este, debes añadir las ubicaciones sobre las cuales se desea probar el Satellite Config.

![image](https://github.com/user-attachments/assets/fafcf24b-672c-450b-bb32-6d272f8b0a02)

Para verificar la correcta implementación del Satellite Config, accede a la consola de OpenShift del location donde se implementará y revisa el namespace/proyecto `razeedeploy`. En este, deberás observar un *Deployment*, un *Service* y un *Route*.

---

## **Eliminación**

1. Elimina los nodos de la ubicación.
2. Borra el clúster de OpenShift.
3. Elimina la ubicación de Satellite.
4. Desde el workspace de Schematics, destruye los recursos con la opción **Destroy resources**.
