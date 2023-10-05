# IBM-Cloud-Satellite-Configuracion
En esta guía se presenta un paso a paso para crear una location de IBM Cloud Satellite, desplegar un clúster de Openshift y configurar el storage de dicho clúster.


## Contenido
1. [Pre-Requisitos](#pre-requisitos-pencil)
    1. [Creación de máquinas virtuales en IBM Cloud](#creación-de-máquinas-virtuales-en-ibm-cloud)
    1. [Creación y configuración de Block Storage en IBM Cloud](#creación-y-configuración-de-block-storage-en-ibm-cloud)
    1. [Creación de File Storage en IBM Cloud](#creación-de-file-storage-en-ibm-cloud)
    1. [Configuración de File Storage en IBM Cloud](#configuración-de-file-storage-en-ibm-cloud)
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

En este caso, se realizó un ambiente de prueba en IBM Cloud, por lo cual a continuación se presenta el proceso para desplegar la infraestructura de cómputo en IBM Cloud, que servirá para desplegar los servicios de IBM Cloud Satellite.

### Creación de máquinas virtuales en IBM Cloud
Hay varias formas de crear estas máquinas virtuales, desde la interfáz gráfica de [ibm cloud](https://cloud.ibm.com/login), con el shell de ibm o con una máquina virtual de linux. Las útlimas dos formas son bastantes similares y en este caso se hará con una máquina virtual. 

En la máquina virtual debe tener instalado los cli de [ibmcloud](https://cloud.ibm.com/docs/cli?topic=cli-install-ibmcloud-cli) y de [Openshift](https://www.ibm.com/docs/en/eam/4.2?topic=cli-installing-cloudctl-kubectl-oc), este último no es necesario para la creación de las máquinas virtuales pero será utilizado en pasos de gestión del clsuter. Estsos comandos ya están instalados en el shell de ibm cloud. También debería tener el comnado ```curl```. 

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

4.  Para crear una sola máquina virtual ejecute este comando (Si desea puede pasar al siguiente paso si quiere crear todas las máquinas del ejercicio al tiempo).
    
    ```
    ibmcloud sl vs create -H host01-openshift -D ibm-satellite.cloud -c 4 -m 16384 -d dal13 -o REDHAT_8_64 --disk 100 --disk 200
    ```

    El ```-H host01-openshift``` indica el hostname que tendrá el server, ``` -D ibm-satellite.cloud ``` indica el dominio donde se creará, coloque el dominio que usted desee o tenga, ```-c 4 -m 16384 -d dal13 -o REDHAT_8_64``` indica los cores, la memoria RAM y el sistema operativo de las máquinas, en este caso, se usarán máquinas de RHEL 8. Se recomienda que el sistema operativos sea RHEL o CoreOS ya que otro sistema linux podrían fallar o no poder instalarse el cluster de Openshift. Para toda la guía se usaran comandos que solo funcionan con RHEL 8. Por último, ```--disk 100 --disk 200``` son los discos que tendrá la máquina en Gb, para esta guía se recomienda colocar al menos uno de 100G y otro de 200G.

    Tenga en consideración que este comando pedirá confirmación ya que generará la facturación por el uso del servicio. si quiere que al ejecutar no pida esta confirmación agregue al final de la linea del comando ``` -f ``` 

5. Se necesita crear 5 servers para los worker nodes y los worker nodes, realice el paso anterior 5 veces más con los nombre  ```host02-openshift```, ```host03-openshift```, ```control-plane-virtual-server-1```, ```control-plane-virtual-server-2``` y ```control-plane-virtual-server-3```. estos útlimos 3 con un solo disco de 300GB 
   

### Creación y configuración de Block Storage en IBM Cloud

1.  Hay varias formas para crear los block storage en ibm cloud, en esta guía, se creará desde la vista de ibmcloud. dirijase al siguiente [link](https://cloud.ibm.com/cloud-storage/block/order) 

Enesta vista solicite el storage de tipo block que usted necesite, para este ejemplo puede solicitar un block storgae de tipo Endurance de 4IOPS/GB, con un tamaño de 200GB, con 0GB de snapshot, con sistema operativo LINUX y en la región US SOUTH Dallas, dal13. Acepte los términos y condiciones y haga clic en aceptar.

Esto habrá creado una solicitud de volumen, luego de unos minutos se debería crear su volumen. 

2. Para la configuración del block storage, el primer paso es asignarle el storage a la máquina virtual determinada. para esto vaya a la vista de detalle del block storage recién creado. luego haga click en ```Actions``` y luego en ```Authorize host```, seleccione virtual server en el tipo de dispositivo y seleccione el host que quiera asignarle el storage, en este caso  ```host01-openshift```.

3. Ahora es necesario realizar una configuración en el virtual server, para ello debe acceder de manera remoto, para ello, desde su máquina linux, ejecute el siguiente comando (si no el comando sshpass ejecute ```sudo spt install sshpass```).

```
sshpass -p <password> ssh -o StrictHostKeyChecking=no root@<ip-public>
```
Donde el password y la ip pública son propias del virtual server. para obtenerlas puede ejecutar primero el siguiente comando:

```
ibmcloud sl vs list
```
Con este comando enlistará todos los virtual server quetenga creados en ese grupo de recursos. También visualizará el id e ip pública de cada virtual server, esta ip será la que debe colocar en ```<ip-publica>```. El id lo usaremos para obtener las credenciales para acceder al servidor.

```
ibmcloud sl vs credentials <id>
```

su terminal deberá mostrar la siguiente linea:
```
Register this system with Red Hat Insights: insights-client --register
Create an account or view all your systems at https://red.ht/insights-dashboard
Last failed login: Thu Oct  5 15:44:00 CDT 2023 from 72.17.53.251 on ssh:notty
There were 2259 failed login attempts since the last successful login.
Last login: Tue Oct  3 10:08:25 2023 from 129.41.86.4
[root@host01-openshift ~]#
```
En esta nueva linea de comando ejecutaremos los siguientes códigos. 

ejecute este comando para descargar los paquetes necearios para realizar la configuración 
```
sudo dnf -y install iscsi-initiator-utils device-mapper-multipath
```

habilite la opción de habilitar la configuración de mapeo de configuración

```
mpathconf --enable --user_friendly_names n
```

Ahora deberá modificar un archivo de configuración, para ello ejecute el siguiente comando:
```
vi /etc/multipath.conf
```

Aquí borre todo el archivo y pegue la siguiente configuración (recuerde que para borrar dentro del comando vi, puede oprimir dos veces la tecla dd, esto eleiminará una linea)

```
defaults {
user_friendly_names no
max_fds max
flush_on_last_del yes
queue_without_daemon no
dev_loss_tmo infinity
fast_io_fail_tmo 5
}
# All data in the following section must be specific to your system.
blacklist {
wwid "SAdaptec*"
devnode "^hd[a-z]"
devnode "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*"
devnode "^cciss.*"
}
devices {
device {
vendor "NETAPP"
product "LUN"
path_grouping_policy group_by_prio
features "2 pg_init_retries 50"
no_path_retry queue
prio "alua"
path_checker tur
failback immediate
path_selector "round-robin 0"
hardware_handler "1 alua"
rr_weight uniform
rr_min_io 128
}
}
```
Luego de pegar el archivo, salga y guarde de la configuración, para ello, digite ```:wq```. El siguiente paso será empezar el servico de multipath, ejecute el siguiente comando.
```
systemctl start multipathd.service
```

Ahora se deberá modificar la configuración de conexión entre el servidor y el block storage.

```
vi /etc/iscsi/initiatorname.iscsi
```

Ahora copie en el lo siguiente;

```
InitiatorName=<value-from-the-Portal>
```

Donde ```<value-from-the-Portal>``` para obtener el IQN, la ip target, username y password, necesarios para vincular el block storage y el virtual server puede ejecutar el siguietne comando
```
ibmcloud sl vs storage <id>
```
con este obtendrá el IQN, el username y el password, El IQN será el que coloca en vez de ```<value-from-the-Portal>```


4. 

### Creación y configuración de File Storage en IBM Cloud




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
