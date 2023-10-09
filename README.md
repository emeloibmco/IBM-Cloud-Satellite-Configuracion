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
Si no ve esta linea y ve algo similar a los siqguiente, deberá borrar las claves ssh que se guardaron automáticamnete en su máquina virtual por realizar conexiones ssh previas a otros dispositivos. 
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ED25519 key sent by the remote host is
SHA256:Xxxxxxxxxxxxxxxxxxxxxxxxxxx.
Please contact your system administrator.
Add correct host key in /home/sebastian/.ssh/known_hosts to get rid of this message.
Offending ECDSA key in /home/sebastian/.ssh/known_hosts:3
  remove with:
  ssh-keygen -f "/home/sebastian/.ssh/known_hosts" -R "169.59.2.86"
Password authentication is disabled to avoid man-in-the-middle attacks.
Keyboard-interactive authentication is disabled to avoid man-in-the-middle attacks.
UpdateHostkeys is disabled because the host key is not trusted.
root@169.59.2.86: Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password).
```
Ejecute el comando : ```cd ~/.ssh```, esto lo dirijirá a la carpeta donde se encuentran todas las claves ssh que tiene su sistema, ejecute ```rm *``` para borrarlas todas las claves que tenga guardadas. Vuelta a ejecutra el comando de sshpass para conectarse con el servidor, recuerde salir de la carpeta ~/.ssh.

En esta nueva linea de comando ejecutaremos los siguientes códigos. 

Ejecute este comando para descargar los paquetes necearios para realizar la configuración 
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
Para obtener el IQN, la ip target, username y password, necesarios para vincular el block storage y el virtual server puede ejecutar el siguietne comando no el terminal del virtual server si no de su máquina lonux
```
ibmcloud sl vs storage <id>
```
Con este obtendrá el IQN, el username y el password, El IQN será el que coloca en vez de ```<value-from-the-Portal>```. Para obtner la ip target debe ejecutar el sieguiente comando
```
ibmcloud sl block volume-list
```
el resultado debe ser una lista de los diferentes block storage que usted haya creado o solicitado, en la columna 8 debe estar el ip_addr, este es el target IP que necesitaremos para pasos posteriores.
Ahora deberá cambiar la configuración de las credenciales. Ejecute el siguiente comando para editar el archivo de configuración de credenciales.
```
vi /etc/iscsi/iscsid.conf
```
Ahora busque, descomente y complete la información con el usuario y contraseña que obtuvo anteriormente de las siguiente lineas.
```
node.session.auth.authmethod = CHAP
node.session.auth.username = <Username-value-from-Portal>
node.session.auth.password = <Password-value-from-Portal>
discovery.sendtargets.auth.authmethod = CHAP
discovery.sendtargets.auth.username = <Username-value-from-Portal>
discovery.sendtargets.auth.password = <Password-value-from-Portal>
```
El siguiente paso es indicarle al servido la ip target a la cual se tiene que conectar con el block storage. Ejecute el siguiente comando:
```
iscsiadm -m discovery -t sendtargets -p <ip-target>
```
Luego deberá loguearse en el arreglo ISCSI, ejecute el siguiente comando:
```
iscsiadm -m node --login
```

Puede validar que la sesion ISCSI está establecida
```
iscsiadm -m session -o show
```
También verifique que existe el multipath 
```
multipath -l
```

por último puede verificar la creación del disco 
```
fdisk -l | grep /dev/mapper
```
De manera predeterminada, el disco se crea en el path ```/dev/mapper```. Acá o ejecutando el comando ```lsblk``` verá que el disco que añadió tiene una partición creada y para que el operador de block storage en el cluster de openshift, identifique qel disco, este debe estar "unmounted" y "unformatted", el primer requisito lo cumplimos, ya que al ejecutar el "lsblk" veremos que el path del mount point está vacio, esto significa que no está montado en ningún path. Para verificar que nuestro disco tampoco tiene algún formato o partición, puede ejecutar el comando ```sudo fdisk /dev/mapper/3600xxxxxxxxxxxxx``` donde el "3600xxxxxxxxxxxxx es el número que verá al lado de ```/dev/mapper``` al ejecutar el comando ```fdisk -l | grep /dev/mapper```. Se habría una linea de comandos exclusiva para realizar acciones de consulta sobre el disko que añadimos, digite ```p``` y oprima enter, verá infromación del disño y sus particiones, si aparece una información similar a la siguiente, significa que el disco no tiene particiones
```
Disk /dev/mapper/3600xxxxxxxxxxxxxxxxx: 200 GiB, 214748364800 bytes, 419430400 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 65536 bytes
Disklabel type: gpt
Disk identifier: XXXX-XXXX-XXXXXX-XXX
```

Si le aparece un información como la siguiente, significará que si tiene particiones:
```
Disk /dev/xvda: 100 GiB, 107374632960 bytes, 209716080 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0xxxxx

Device     Boot   Start       End   Sectors Size Id Type
/dev/xvda1 *       2048   2099199   2097152   1G 83 Linux
/dev/xvda2      2099200 209715199 207616000  99G 83 Linux
```


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
