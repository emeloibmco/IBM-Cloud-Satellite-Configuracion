#!/bin/bash

# Comandos para setear las variables iniciales para la creación de todo el ambiente
echo "Para crear el ambiente de demostración OpenShift sobre Satellite usando virtual server for classic que emulan un servidor OnPremise, es necesario que brinde la siguiente información" 

#DOminio COntrol Plane
echo "Nombre del dominio para los control Plane /finalizado en (.cloud)"
read dominioControlPlane 

#Dominio WorkerNodes
echo "Nombre del dominio para los worker nodes finalizado en (.cloud)"
read dominioWorkerNodes

#Dominio ODF
echo "Nombre del dominio para los nodos de ODF Finalizado en (.cloud)"
read dominioODF

#Nombre location
echo "Nombre de la ubicación (location) para el Satellite"
read location

#Nombre cluster
echo "Nombre para el cluster de Openshift"
read nombreOpenshift

#Cantidad de workerNodes
echo "Cantidad de worker nodes, debe ser un múltiplo de 3 (1 por zona), se recomienda hacer la prueba con 3"
read cantidadWorkers
if [ $((cantidadWorkers % 3)) -ne 0 ]; then
	echo "Debe ingresar un número múltiplo de 3"
	exit 1 
fi
if [[ ! $cantidadWorkers =~ ^[0-9]+$ ]]; then
	echo "Debe escribir solo datos numéricos"
	exit 1
fi

#Cores
echo "Ingrese la cantidad de cores por nodo, se recomienda que sea 4 cores, para saber cuales son los perfiles de cores y ram permitidos vaya a la página : https://cloud.ibm.com/docs/virtual-servers?topic=virtual-servers-about-virtual-server-profiles&locale=es"
read cores
if [[ ! $cores =~ ^[0-9]+$ ]]; then
	echo " Debe escribir solo datos numéricos"
	exit 1
fi

#Ram 
echo "ingrese la cantidad de ram por nodo en MB, se recomienda que sea 16384 MB y recuerde que 1GB=1024MB"
read memoria 
if [[ ! $memoria =~ ^[0-9]+$ ]]; then
	echo "Debe escribir solo datos numéricos"
	exit 1

fi
tput setaf 2 
date
tput sgr0 





## Creación de los virtual server 

for ((i = 1; i <=$cantidadWorkers ; i++)); do
	if [ $i -le 3 ]; then
		ibmcloud sl vs create -H control-plane-vs-0$i -D $dominioControlPlane  -c 4 -m 16384 -d dal13 -o REDHAT_8_64 --disk 25 --disk 100 -f
		echo "se solitictó la máquina: control-plane-vs-0$i"
		ibmcloud sl vs create -H host-odf-0$i -D $dominioODF -c 16 -m 65536 -d dal13 -o REDHAT_8_64 --disk 25 --disk 100 --disk 100 --disk 500 -f
		echo "se solitictó la máquina: host-odf-0$i"
	fi
	ibmcloud sl vs create -H host0$i-openshift -D $dominioWorkerNodes -c $cores -m $memoria -d dal13 -o REDHAT_8_64 --disk 25 --disk 100 --disk 100 --disk 100 -f
	echo "se solitictó la máquina: host0$i-openshift"
done
sleep 300
tput setaf 2 
date
tput sgr0 
echo "se crearon las máquinas"
ibmcloud sl vs list 
ibmcloud sat location create --managed-from dal13 --name $location -q
echo "Empezó la creación de la ubicación"
creacion=false
while [ $creacion = false ]; do
	codigo=$(echo $(ibmcloud sat location get --location $location --json | jq '.deployments.message') | awk -F: '{print $1}')
	codigo=${codigo//\"/}
	if [ "$codigo" = "R0012" ]; then
		creacion=true	
	else
		echo "Se está desplegando la location"
		sleep 30df-01.ibm-satellite-odf.cloud
	fi
done
tput setaf 2 
date
tput sgr0 
echo "Se creo la ubicación"
ibmcloud sat location ls 

ruta=$(ibmcloud sat host attach --location $location)

ruta=$(echo "$ruta" | grep -o '/tmp/register-host[^ ]*' | awk '{print $1}')
mv $ruta .

script_attach=$(basename "$ruta")

rm  ~/.ssh/*
attachar_host(){
	lista=$(ibmcloud sl vs list -D $1)
	cantidad_filas=$(echo "$lista" |wc -l )
	for ((i = 2; i <= cantidad_filas, i++)); do
		linea=$(awk -v num="$i" 'NR == num' FS='\t' <<<$lista)
	
		#Extraer el valor de la sexta columna (ip pública)
		ip=$(echo "$linea" | awk '{print $6}')
		# Extraer el valor de la primera columna columna (id)
		id=$(echo "$linea" | awk '{print $1}')
    
    		# extrae las credenciales del host con el id especificado 
		pwd=$(ibmcloud sl vs credentials "$id"| grep root | awk '{print $2}')
		echo "ip publica: $ip, id: $id, password: $pwd"
	
		## comando para pasar el archivo setup_satellite a el virtual server, darle permiso de ejecución al script y su ejecución de manera remota sin entrar al server
		##Este sh coloca librearías necesarias para que los host sean attachados.
		sshpass -p $pwd  ssh -o StrictHostKeyChecking=no root@$ip 'subscription-manager refresh'
		sshpass -p $pwd  ssh root@$ip 'subscription-manager repos --enable rhel-8-for-x86_64-appstream-rpms'
		sshpass -p $pwd  ssh root@$ip 'subscription-manager repos --enable rhel-8-for-x86_64-baseos-rpms'

		sshpass -p $pwd  scp $script_attach root@$ip:/home
		sshpass -p $pwd  ssh root@$ip "chmod +x /home/$script_attach"
		sshpass -p $pwd  ssh root@$ip "/home/$script_attach"
 	
	done 
}
attachar_host $dominioControlPlane
attachar_host $dominioWorkerNodes
attachar_host $dominioODF
tput setaf 2 
date
tput sgr0 
echo "Se attacharon todas las máquinas"
for ((i = 2; i <= cantidad_filas_control_plane; i++)); do
	linea=$(awk -v num="$i" 'NR == num' FS='\t' <<<$listaControlPlaneVS)
	#Extraer el nombre del host
	name=$(echo "$linea" | awk '{print $2}')
	echo  "nombre: $name"
	zone=$((i-1))
	echo $zone
	## Asignar host como control plane
	ibmcloud sat host assign --host $name --location $location --zone us-south-$zone
done 
funcionetiquetar(){
	lista=$(ibmcloud sl vs list -D $1)
	cantidad_filas=$(echo "$lista" |wc -l )
	for ((i = 2; i <= cantidad_filas; i++)); do
		linea=$(awk -v num="$i" 'NR == num' FS='\t' <<<$lista)
		#Extraer el nombre del host
		name=$(echo "$linea" | awk '{print $2}')
		ibmcloud sat host update --host $name --host-label $2--location $location
	done 

}
labelworkers='nodos=workers'
funcionetiquetar $dominioControlPlane $labelworkers
labelodf='nodos=odf'
funcionetiquetar $dominioControlPlane $labelodf

tput setaf 2 
date
tput sgr0 
sleep 30
asignacion=false
while [ $asignacion = false ]; do
	
	codigo1=$(echo $(ibmcloud sat host get --host control-plane-vs-01 --location $location --json | jq '.state') | awk -F: '{print $1}')
	codigo1=${codigo1//\"/}
	codigo2=$(echo $(ibmcloud sat host get --host control-plane-vs-02 --location $location --json | jq '.state') | awk -F: '{print $1}')
	codigo2=${codigo2//\"/}
	codigo3=$(echo $(ibmcloud sat host get --host control-plane-vs-03 --location $location --json | jq '.state') | awk -F: '{print $1}')
	codigo3=${codigo3//\"/}
	if [ "$codigo1" = "assigned" ] && [ "$codigo2" = "assigned" ] && [ "$codigo3" = "assigned" ]
	then
		asignacion=true	
	else
		echo "Se está asignando los controlplane al location "
		sleep 30
	fi
done
tput setaf 2 
date
tput sgr0 
echo "Se asignaron los control plane"
location_ready=false
while [ $loaction_ready = false ]; do
	codigo=$(echo $(ibmcloud sat location get --location $location --json | jq '.deployments.message') | awk -F: '{print $1}')
	codigo=${codigo//\"/}
	if [ "$codigo" = "R0001" ]; then
		location_ready=true	
	else
		echo "Se está terminado de configurar los control plane"
		sleep 30
	fi
	
done
echo "Terminó la asignación y configuración de los control plane"
tput setaf 2 
date
tput sgr0 
echo "Empezará la creación de OPenshift"
ibmcloud oc cluster create satellite --location $location --name $nombreOpenshift --version 4.12.44_openshift --workers 1 --operating-system RHEL8 --enable-config-admin --host-label 
sleep 300
creacion_cluster=false
while [ $creacion_cluster = false ]; do
	codigo=$(echo $(ibmcloud oc cluster get --cluster $nombreOpenshift--json | jq '.ingress.status') | awk -F: '{print $1}')
	codigo=${codigo//\"/}
	if [ "$codigo" = "healthy" ]; then
		creacion_cluster=true	
	else
		echo "Se está creando el cluster"https://lc493cc0816ac2efa0474-6b64a6ccc9c596bf59a86625d8fa2202-ce00.us-south.satellite.appdomain.cloud:30449/console
		sleep 30
	fi
	
done
tput setaf 2 
date
tput sgr0 
echo "Terminó la creación del cluster"

url=$(echo $(ibmcloud oc cluster get -c cluster-satellite --json | jq '.locationEndpointURL') | sed 's/^"\(.*\)"$/\1/' )
apikey=$(echo $(ibmcloud iam api-key-create prueba-op --output json| jq '.apikey') | sed 's/^"\(.*\)"$/\1/' )
oc login -u apikey -p $apikey --server $url
validacion=false
while [ $validacion = false ]; do
	oc_get_co_output=$(oc get co)
	# Verificar si todos los elementos tienen el campo AVAILABLE en "True"
	if [[ $(echo "$oc_get_co_output" | grep -c 'True') -eq $(echo "$oc_get_co_output" | wc -l) ]]; then
  		echo "Se ha creado correctamente el cluster"
  		validacion=true
	else
  		echo "Aún no se ha desplehgado correctamente el cluster"
  		sleep 30
	fi
done 
ibmcloud sat storage config create --location $location --name config-odf --template-name odf-local --template-version 4.12 -p "auto-discover-devices=false" -p "billing-type=advanced" -p "cluster-encryption=false" -p "ignore-noobaa=false" -p "kms-encryption=false" -p "num-of-osd=1" -p "odf-upgrade=false" -p "osd-device-path=/dev/xvdf" -p "perform-cleanup=false" -p "worker-nodes=host-odf-01.$dominioODF,host-odf-02.$dominioODF,host-odf-03.$dominioODF" -p "iam-api-key=$apikey"
listacluster=$(ibmcloud ks cluster ls --provider=satellite)
lineacluster=$(awk -v num="3" 'NR == num' FS='\t' <<<$listacluster)
id_cluster=$(echo "$lineacluster" | awk '{print $2}')
ibmcloud sat storage assignment create  --config config-odf --cluster $id_cluster


