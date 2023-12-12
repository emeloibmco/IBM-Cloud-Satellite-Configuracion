#!/bin/bash
dominioControlPlane="dominio-control-plane.cloud"
listaControlPlaneVS=$(ibmcloud sl vs list -D $dominioControlPlane)
cantidad_filas_control_plane=$(echo "$listaControlPlaneVS" |wc -l )
for ((i = 2; i <= cantidad_filas_control_plane; i++)); do
	linea=$(awk -v num="$i" 'NR == num' FS='\t' <<< $listaControlPlaneVS)
	id=$(echo "$linea" | awk '{print $1}')
	ibmcloud sl vs cancel $id -f 
done
dominioWorkerNodes="dominio-worker-nodes.cloud"
listaWorkerNodesVS=$(ibmcloud sl vs list -D $dominioWorkerNodes)
cantidad_filas_worker_nodes=$(echo "$listaWorkerNodesVS" |wc -l )
for ((i = 2; i <= cantidad_filas_worker_nodes; i++)); do
	linea=$(awk -v num="$i" 'NR == num' FS='\t' <<<$listaWorkerNodesVS)
	id=$(echo "$linea" | awk '{print $1}')
	ibmcloud sl vs cancel $id -f 
done
