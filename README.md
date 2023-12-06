# IBM-Cloud-Satellite-Configuracion
En esta guía se presenta un paso a paso para crear una location de IBM Cloud Satellite, desplegar un clúster de Openshift y configurar el storage de dicho clúster.


## Contenido
1. [Pre-Requisitos](#pre-requisitos-pencil)
    1. [Creación de máquinas virtuales en IBM Cloud](#creación-de-máquinas-virtuales-en-ibm-cloud)
2. [Creación de Satellite Location]()
3. [Configurar y attachar máquinas a la Satellite Location]()
4. [Despliegue de un clúster de Openshift]()
5. [Configuración de Block Storage en la Satellite Location]()
6. [Configuración de File Storage en la Satellite Location]()
7. [Agregar Storage a una máquina cuando ya se tiene un clúster creado]()
4. [Referencias](#referencias-📄)
4. [Autores](#autores-black_nib)

## Pre-Requisitos :pencil:

- Contar con una cuenta en [IBM Cloud](https://cloud.ibm.com/)
- [Infraestructura de cómputo](https://cloud.ibm.com/docs/satellite?topic=satellite-host-reqs) (IBM Cloud Satellite se puede desplegar sobre infraestructura de cómputo en ambientes on-premises o cualquier proveedor de nube.)

En este caso, se realizó un ambiente de prueba en IBM Cloud, por lo cual a continuación se presenta el proceso para desplegar la infraestructura de cómputo en IBM Cloud, que servirá para desplegar los servicios de IBM Cloud Satellite. Antes de crear las máquinas es necesario entender la arquitectura de la demostración que se va a montar. Esta cambia depenendiendo si se desea hacer la gestión del storage de forma dinámica o no. Si se escoge la primera, es necesario añadir 3 worker nodes de infraestrutura que se encagarán de hacer la gestión de almacenamiento y tendrán instalados los operadores de ODF (Openshift Data Foudation).

Arquitectura para un storage local no dinámico:

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/9e8298e2-0c5b-489e-92b1-83a828980dab" alt="Arquitectura-local-storage" width="800" >

Los discos de 25G representa el disco minimo para la instalación del sistema Operativo, el disco de 100G de los control plane y de los worker nodes, son el espacio necesario para el funcionamiento mínimo de Satellite y Openshift. Las máquinas que se asignarán como worker nodes al cluster de OP, tiene 2 discos extra de 100G, que serán usados como Persistent Volumes (PV) de tipo File y Block para la creación de aplicaciones. Estos PVs son de storage no dinámico, esto quiere decir que si un pod crea un Persisten Volume Claim (PVC) de una storage class que bridne la configuración de storage que tiene Satellite, el cluster le asignará cualquier PV del mismo tipo sin importar el tamaño. Esto quiere decir que si se solicita 20G y solo hay PVs de 100G, se usarán todo el almacenamiento del PV. Por lo tanto no se optimiza la utilización del disco. Por ello, en ambiente de producción es necesario usar ODF o tener una muy buena gestión de disco manual, para agregar a las máquinas discos del mismo tamaño que se solicite en los PVCs. 

Arquitectura para un storage local dinámico con ODF.

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/fcc2c746-54b0-4f01-97c5-c8a086368b49" alt="Arquitectura-local-storage" width="1000" >

Para los Worker nodes, no es necesario los dos discos extra que se vieron anterirormente. Pero ahora las máquinas que tengan la configuración de ODF necesaitan dos discos, uno de 100G para la componente de Monitoreo de ODF y otra de 500G (mínimo de 250G). Este último será el almacenamiento disponible final en el cluster (Multiplicacdo por la cantidad de nodos de ODF), el cual no estará vinculado directamente a un PV de cierto Storage class, por lo que los pods podrán solicitar cualquier tamaño y se le asginará automáticamente un PV de ese mismo tamaño y tipo. 

### Creación de máquinas virtuales en IBM Cloud
Dependiendo la arquitectura que se desea implementar, la cantidad de máquinas y los parámetros de los códigos que verá acontinuación variarán.

Hay varias formas de crear estas máquinas virtuales, desde la interfáz gráfica de [ibm cloud](https://cloud.ibm.com/login), con el shell de ibm o con una máquina virtual de linux. Las útlimas dos formas son bastantes similares y en este caso se hará con una máquina virtual. 

En la máquina virtual debe tener instalado los cli de [ibmcloud](https://cloud.ibm.com/docs/cli?topic=cli-install-ibmcloud-cli) y de [Openshift](https://www.ibm.com/docs/en/eam/4.2?topic=cli-installing-cloudctl-kubectl-oc), este último no es necesario para la creación de las máquinas virtuales pero será utilizado en pasos de gestión del cluster. Estos comandos ya están instalados en el shell de ibm cloud. También debería tener el comnado ```curl```. 

1. Desde el terminal de linux, ejecute este comando

    ```
   ibmcloud login -sso
    ```
 
    Esto le pedirá una confirmación para abrir un buscador, coloque ```y``` o ```yes```. En el buscador ingrese con su cuenta de ibm, al final le dará un código de la forma: ```abc1abcAB2```, ingreselo en la terminal de linux, tenga en cuenta que al escribirlo o pegarlo no lo verá.
Luego debe seleccionar la cuenta en la que desea crear la máquinas, ingrese el número correspondiente.

2. Ya estaría dentro de la ceunta en la que desea crear sus Virtual Servers, pero aún le va a solicitar en qué grupo de recursos deberá crear los difernetes servicios. Ejecute el sieguiente comanddo 

    ```
   ibmcloud target -g RESOURCE_GROUP
    ```

    Donde el ```RESOURCE_GROUP``` es el nombre del grupo de recursos donde va a crear los servicios. Después de esto, su máquina virtual debería estar siempre logeada a la cuentad e ibm cloud en ese grupo de recursos en específico

 3. Lo primero que podemos hacer es visualizar las máquinas virtuales que ya estén creadas:

    ```
    ibmcloud sl vs list
    ```

    Con este comando verá el id, los hostname, el dominio y demás información del hardaware y la network de los Virtual server que ya están creados.

4.  Para crear una sola máquina virtual ejecute este comando.
    
    ```
    ibmcloud sl vs create -H host01-openshift -D ibm-satellite.cloud -c 4 -m 16384 -d dal13 -o REDHAT_8_64 --disk 25 --disk 100
    ```

    El ```-H host01-openshift``` indica el hostname que tendrá el server, ``` -D ibm-satellite.cloud ``` indica el dominio donde se creará, coloque el dominio que usted desee o tenga, ```-c 4 -m 16384 -d dal13 -o REDHAT_8_64``` indica los cores, la memoria RAM y el sistema operativo de las máquinas, en este caso, se usarán máquinas de RHEL 8. Para cualquier arquiectura, el sistema operativo será el mismo. Para toda la guía se usaran comandos que solo funcionan con RHEL 8. Por último, ```--disk 25 --disk 100``` son los discos que tendrá la máquina en Gb. Cree cada una de las máquinas de la arquitectura, con la cantidad y tamaño de disco mostrada. 

    Tenga en consideración que este comando pedirá confirmación ya que generará la facturación por el uso del servicio. si quiere que al ejecutar no pida esta confirmación agregue al final del comando ``` -f ```:
    ```
    ibmcloud sl vs create -H host01-openshift -D ibm-satellite.cloud -c 4 -m 16384 -d dal13 -o REDHAT_8_64 --disk 25 --disk 100 -f
    ```

### Creación de un Satellite Location.

### Referencias :page_facing_up:
- [Local Storage Operator - Block](https://cloud.ibm.com/docs/satellite?topic=satellite-storage-local-volume-block&interface=ui)
- [Local Storage Operator - File](https://cloud.ibm.com/docs/satellite?topic=satellite-storage-local-volume-file&interface=ui)
- [Mounting File Storage](https://cloud.ibm.com/docs/FileStorage?topic=FileStorage-mountingLinux&interface=ui)
- [ODF](https://cloud.ibm.com/docs/satellite?topic=satellite-storage-odf-local&interface=ui)
- [mounting block storage](https://cloud.ibm.com/docs/BlockStorage?topic=BlockStorage-mountingRHEL8&interface=ui)
- []()
- []()



## Autores :black_nib:
Equipo IBM Cloud Tech Sales Colombia
