# IBM-Cloud-Satellite-Configuracion
En esta guía se presenta un paso a paso para crear una location de IBM Cloud Satellite, desplegar un clúster de Openshift y configurar el storage de dicho clúster.


## Contenido
1. [Pre-Requisitos](#pre-requisitos-pencil)
    1. [Creación de máquinas virtuales en IBM Cloud](#creación-de-máquinas-virtuales-en-ibm-cloud)
2. [Creación de Satellite Location]()
3. [Configurar y attachar máquinas a la ubicación de Satellite]()
4. [Despliegue de un clúster de Openshift]()
5. [Configuración de Local Storage en la Satellite Location]()
6. [Configuración de ODF Storage en la Satellite Location]()
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
1. El primer paso es instalar todos los plugins del cli de ibmcloud para la realización de todos los comandos. 

```
ibmcloud plugin install -a
```

2. Desde el terminal de linux, ejecute este comando

    ```
   ibmcloud login -sso
    ```
 
    Esto le pedirá una confirmación para abrir un buscador, coloque ```y``` o ```yes```. En el buscador ingrese con su cuenta de ibm, al final le dará un código de la forma: ```abc1abcAB2```, ingreselo en la terminal de linux, tenga en cuenta que al escribirlo o pegarlo no lo verá.
Luego debe seleccionar la cuenta en la que desea crear la máquinas, ingrese el número correspondiente.

3. Ya estaría dentro de la ceunta en la que desea crear sus Virtual Servers, pero aún le va a solicitar en qué grupo de recursos deberá crear los difernetes servicios. Ejecute el sieguiente comanddo 

    ```
   ibmcloud target -g RESOURCE_GROUP
    ```

    Donde el ```RESOURCE_GROUP``` es el nombre del grupo de recursos donde va a crear los servicios. Después de esto, su máquina virtual debería estar siempre logeada a la cuentad e ibm cloud en ese grupo de recursos en específico

 4. Lo primero que podemos hacer es visualizar las máquinas virtuales que ya estén creadas:

    ```
    ibmcloud sl vs list
    ```

    Con este comando verá el id, los hostname, el dominio y demás información del hardaware y la network de los Virtual server que ya están creados.

5.  Para crear una sola máquina virtual ejecute este comando.
    
    ```
    ibmcloud sl vs create -H host01-openshift -D ibm-satellite.cloud -c 4 -m 16384 -d dal13 -o REDHAT_8_64 --disk 25 --disk 100
    ```

    El ```-H host01-openshift``` indica el hostname que tendrá el server, ``` -D ibm-satellite.cloud ``` indica el dominio donde se creará, coloque el dominio que usted desee o tenga, ```-c 4 -m 16384 -d dal13 -o REDHAT_8_64``` indica los cores, la memoria RAM y el sistema operativo de las máquinas, en este caso, se usarán máquinas de RHEL 8. Para cualquier arquiectura, el sistema operativo será el mismo. Para toda la guía se usaran comandos que solo funcionan con RHEL 8. Por último, ```--disk 25 --disk 100``` son los discos que tendrá la máquina en Gb. Cree cada una de las máquinas de la arquitectura, con la cantidad y tamaño de disco mostrada. 

    Tenga en consideración que este comando pedirá confirmación ya que generará la facturación por el uso del servicio. si quiere que al ejecutar no pida esta confirmación agregue al final del comando ``` -f ```:
    ```
    ibmcloud sl vs create -H host01-openshift -D ibm-satellite.cloud -c 4 -m 16384 -d dal13 -o REDHAT_8_64 --disk 25 --disk 100 -f
    ```

## Creación de un Satellite Location.
Para la creación de una ubicación de satellite corra este comando en su máquina virtual:

```
ibmcloud sat location create --managed-from dal13 --name $location -q
```
Esto creará una ubicación en dallas 13, con el nombre de la variale $location, aquí puede colocar el nombre que desee de la ubicación. Tenga en cuenta que el nombre debe empezar una letra, puede contener letras, números, puntos o guiones, los demás caracteres no se aceptan. 

El despliegue o creación de este servicio se suele demorar 5 minutos, para vereficar que el servicio se creó correctamente, ejecute el siguiente comnado.

```
ibmcloud sat location get --location $location --json 
```

Este comando retornará un archivo json, busque el atributo ```deployments.message``` si el mensaje que retoran es un código diferente a ```R0012``` , el ambiente aún no está listo. Este mensaje ```R0012``` indica que la ubicación necesita que se añadan y configuren las máquinas que tengan el rol de control plane. Si desea entender los demás posibles errores que se le presenten en el despliegue en cualquier paso relacionado a la ubicación, puede ver la siguiente [documentación](https://cloud.ibm.com/docs/satellite?topic=satellite-ts-locations-debug)

También puede ver este estado desde la vista de ibm cloud, en la sección de satellite y ubicaciones y seleccionando la ubicación correspondiente. 

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/b8270ed9-50e1-491d-b25a-26f7d3c8b4fd" alt="Arquitectura-local-storage" width="600" >

Hasta que vea la siguiente imagen:

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/cf0b2493-72f3-4822-809a-b9bfabd5c05d" alt="Arquitectura-local-storage" width="600" >


## Configurar y attachar máquinas a la ubicación de Satellite

Para este paso es necesario que tenga instalado en su máquina el comando ```sshpass```
Ahora se debe configurar y attachar las máquinas a la ubicación, para ello, es necesario descargar un script que genera la ubicación para agreagar máquinas, para descargar este script ejecute el siguiente comando:

```
ibmcloud sat host attach --location $location 
```

Esto descargará un archivo en la carpeta tmp de la máquina virtual con el nombre register-host_(nombre de su ubicación)-xxxxxxx, este archivo lo debe subir o agregar a cada una de las máquinas que desea attachar a la ubicación. Para ello los siguientes pasos.

Para ingresar a las máquinas, es necesario obtener la ip y la contraseña, para ello ejecute los siguientes comandos:

```
ibmcloud sl vs list
```

ESto retornará algo similar a lo siguiente:
<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/f029364f-2b65-402d-8c46-f375c8906c8c" alt="Arquitectura-local-storage" width="1000" >

Para obtener la contraseña ejecute el sieguiente comando:

```
ibmcloud sl vs credentials $id
```

Donde el id de cada máquina será el número de la primera carpeta. Esto devolverá una respuesta con la contraseña necesaria para ingresar. Luego es necesario ingresar a la instancia del virtual server.

```
sshpass -p $pwd  ssh -o StrictHostKeyChecking=no root@$ip
```
Donde $pwd es la contraseña que obtuvo anteriormente y $ip es la dirección ip pública del servidor. Al ingresar lo verá lo siguiente

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/f3b0806c-f6c2-461a-bd01-ad0519702de3" width="600" >

Si no pudo ingresar al virtual server instance puede ser debído a la configuración de ssh de su máquina virtual. Ejecute los isguiente comandos y vuelva inetntar ingresar. 

```
cd ~/.ssh
rm *
```
Esto eliminará todas los elementos de esta carpeta.
Acá deberá actualizar e instalar varios repositorios de Red Hat, para ello, ejecute los siguientes comandos:
```
subscription-manager refresh
subscription-manager repos --enable rhel-8-for-x86_64-appstream-rpms
subscription-manager repos --enable rhel-8-for-x86_64-baseos-rpms
```

Luego salga de la máquina ingresando el comando ```exit```. Al volver a su máquina virtual deberá cargar el script de attach a la máquina. Ejecute el siguiente comando para subir el archivo a la máquina.

```
sshpass -p $pwd  scp $nombre_script root@$ip:/home
```
Dónde $pwd es la contraseña, $ip es la ip pública y $nombre_script es la ruta absoluto y el nombre del script ternimado en .sh. Recuerde que si está ejecutando este comando desde la carpeta donde se encuentra el script no es necesario colocar la ruta completa si no solo el nombre del archivo. 

Este paso deberá realizarlo con todas las máquinas que desee agregar al satellite location. Al final deberá ver algo similar a lo siguiente desde ibm cloud y la ubicación de su satellite.
<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/7f5fcdb9-4697-4d5e-8063-34f0d308af20" width="1000" >

La diferencia será que ninguna de las máquinas estará asignada a ningún tipo de servicio o infraestructura. Por lo que el paso siguiente será asignar las maquinas que tendrán el rol de control plane:

```
ibmcloud sat host assign --host $name --location $location --zone us-south-$zone
```
donde $name es el nombre de la máquina que desea assiganar como control plane y $zone es un número entre 1 y 3. Como va a asignar 3 máquinas, cada una debe quedar asignada en zonas diferentes. 

Lueego de asignar estas máquinas como control planes, en la vista de ibm cloud podrá ver que ya se encontrarán asignadas pero en estado de aprovisionamiento, espere a que el estado sea ready. También puede ver el estado de las máquinas desde la consola de su maquina virtual:

```
ibmcloud sat host list --location $name-location
```

Donde $name-location es el nombre de su ubicación. El siguiente paso será crear un cluster de Openshift.

## Despliegue de un clúster de Openshift
Lo primero que se debe realizar es etiquetar las máquinas que estarán en Openshift. Si está realizando la configuración de storage local, esta etiqueta se colocará a todas las máuinas restantes. Si esta realizando la configuración de ODF, se hace igual, menos a las maquinas destiandas a ODF.
```
ibmcloud sat host update --host $name --host-label $namelabel=$label --location $location
```
Para la creación de un cluster de openshift en satellite desde consola puede ejecutar el sisguiente comando
```
ibmcloud oc cluster create satellite --location $location --name $nombreOpenshift --version 4.12.37_openshift --workers 3 --operating-system RHEL8 --enable-config-admin --host-label $namelabel=$label 
```

Los parámetros cmabiarán si desea instalar otra versión de OP o las máquinas tienen otro sistema operativo. Luego de su creación podrá ver el estado del cluster desde ibm cloud, luego de que el cluster esté desplegado correctamente deberá ver lo siguiente:
<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/0a365411-2d83-4680-b36a-62b609f55459" width="1000" >

Aquí podrá ingresar al cluster con el botón azul. Para verificar que el cluster está creado completamente, ingrese a Openshift.

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/6c261177-2053-4cc3-a2cc-d826f96bdfde" width="1000" >

Haga click sobre el botón copy login command, copie el comando log in with this token e ingreselo en la consola de su máquina virtual, recuerde que es necesario tener el cli de OC en su consola. Habrá ingresado a su cluster desde consola para poder ejecutar comandos oc. Ahora ejecute el comando ```oc get co```. Debe ver algo similar a lo siguiente:

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/6f9810a2-59f8-40ee-9e74-f8dd2e39907c" width="800" >

Todos los elementos deben estar disponibles y no en estado progressing o degraded.

## Configuración de Local Storage en la Satellite Location

Si está realizando el despliegue de arquitectura con la configuración de storage local. Luego de haber ingresado desde la consola a Openshift, se debe ingresar a cada uno de los nodos de forma debug para ver los discos disponibles. Esto se debe realizar de esta forma debido a que se pierde el acceso de forma habitual a la máquina luego de instalar Openshift. para ello primero liste los nodos con el comando ```oc get nodes```. Verá los siguientes nodos a excepción de los nodos con nombre ODF. 


<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/0d0c57f3-97e9-4257-b3eb-9ec2f3fcd648" width="800" >

Teniendo en cuenta el nombre de cada nodo, ejecute el comando:
``` 
oc debug node/$nombre_nodo
```
Deberá ver algo similar a lo siguiente:


<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/b2d7ae38-7039-4357-abce-fe900b4316c3" width="1000" >

Ejecute el comando que le sugiere ```chroot /host```. Luego es necesario identificar los discos que tendrán la característica de block y de file. Ejecute el comando  ```lsblk```, verá el siguiente resultado:

 <img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/1ff23269-61b3-4bbc-a26a-f58de4173d98" width="400" >

Acá podrá veririficar el tamaño de los discos, para el caso de local storage debe estar disponibles dos discos de 100G( que no tengan Mount point). Guarde el nombre de los discos. Para que la configuración de storage pueda usar estos elementos como persistent volumes es necesario que estos discos estén desmontados (que no tengan ruta de montaje) y que no tengan ningún formato (unformatted). Para verificar estas dos condiciones, ejecute el comando ```lsblk -f``` va obtener un resultado similar al siguiente.

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/4333457b-c2cd-4546-9079-c26ae46c68f3" width="800" >

Verifique que los discos que desea usar no tengan niguna información en las demás columnas. Teniendo claro los discos que se usaran se puede pasar a la creación de la configuración. Para crear la configuración de storage ejecute el siguiente comando
```
ibmcloud sat storage config create --location $nombre_ubicacion --name $nombre_config --tempalte-name local-storage-operator --template-version 1.0.0
ibmcloud sat storage assignment create --location $nombre_ubicacion --config $nombre_config --cluster $nombre_cluster 
```

Esto creará un operador en el namespace openshift-local-storage
## Configuración de ODF Storage en la Satellite Location

Para la configuración de storage de ODF también debe verficar las mismas condiciones de los discos que para Local Storage. verifique el tamaño, el formato y el mountponit y que cumplan también con las características de la arquitectura mostrada en las priemras imagenes. Luego deberá ejecutar los siguientes comandos.
```
ibmcloud sat storage config create --location $nombre_ubicacion --name $nombre_config --tempalte-name odf-local --template-version 4.12 -p "auto-discover-devices=flase" -p "billing-type=advanced" -p "cluster-encryption=false" -p "ignore-noobaa=false" -p "kms-encryption=false" -p "num-of-osd=1" -p "odf-upgrade=false" -p "osd-device-path=/dev/$nombre_disco" -p "perform-cleanup=false" -p "worker-nodes=$nombres_nodos" -p "iam-api-key=$api_key"
ibmcloud sat storage assignment create --location $nombre_ubicacion --config $nombre_config --cluster $nombre_cluster 
```
La versión puede cambiar según la versión de cluster, verifique que sea la misma versión de su cluster, en este caso 4.12.

- Para $nombre_ ubuicación es el nombre de la ubicación de satellite
- $nombre_config es el nombre que desea colocarle a la configuración de storage
- $nombre_disco es el nombre del disco de 500G
- $nombe_ndos es el nombre de cada nodo separado por comas ejemplo: nodo1,nodo2,nodo3
- $api_key es la api_key de sus usuario que se puede generar desde ibm cloud, puede ver la siguiente [documentación](https://www.ibm.com/docs/en/storagevirtualizecl/8.1.x?topic=installing-creating-api-key)
- $nombre_cluster es el nombre del cluster de Openshift

  Luego de crear y asignar la configuración de storage al cluster, se crearan varios operadores de ODF, esto tomará hasta 20 minutos en completarse, después de esto, deberá entrar a la sección de storage classs, para verificar que esten creados los SC. Debe ver algo similar a lo siguiente. Esta configuración también se puede realizar desde la consola de IBM cloud, en la sección de storage de la ubicación de satellite. Tenga en cuenta llenar los mismos parámetros que se muestran en el comando anterior.

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/bce63998-a8fc-495b-821d-aa16f2ec2e5e3" width="1000" >

También deberá ver que, los persistent volumes estén creados.

<img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/6e913827-281f-4bed-ba70-f24733ddc703" width="1000">

 Debe ser un totoal de 5. Por último, verifique qeu tenga la sección Data Foudation dentro de Storage, al entrar deberá ver algo similar a esto:
 
 <img src="https://github.com/emeloibmco/IBM-Cloud-Satellite-Configuracion/assets/52113892/1c8010b5-2e2b-4b23-b37a-f3b7e745208a" width="1000">

Verifique que la capacidad del sistema total sea la suma totla de los discos de 500 g o el tamaño con el cual lo haya creado.

## Referencias :page_facing_up:
- [Local Storage Operator - Block](https://cloud.ibm.com/docs/satellite?topic=satellite-storage-local-volume-block&interface=ui)
- [Local Storage Operator - File](https://cloud.ibm.com/docs/satellite?topic=satellite-storage-local-volume-file&interface=ui)
- [Mounting File Storage](https://cloud.ibm.com/docs/FileStorage?topic=FileStorage-mountingLinux&interface=ui)
- [ODF](https://cloud.ibm.com/docs/satellite?topic=satellite-storage-odf-local&interface=ui)
- [mounting block storage](https://cloud.ibm.com/docs/BlockStorage?topic=BlockStorage-mountingRHEL8&interface=ui)
- []()
- []()



## Autores :black_nib:
Equipo IBM Cloud Tech Sales Colombia
