IP=$1

#### mostramos como usar el script si el campo 1 esta vacio

if [ $IP == "" ]
then
	echo "Para usar este script tenes que definir que ip queres que tenga"
	echo "ASEGURATE DE QUE NO ESTE SIENDO USADA!!!"
	echo "altaVPS.sh [IP A USAR]"
fi


#### chequeamos la validez de la ip
if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
then


	RANGO=`echo $IP | cut -d"." -f1,2,3`
	NUMERO=`echo $IP | cut -d"." -f4`
	
	##### definimos el subdominio del hostname
	if [ $RANGO == "200.68.105" ]
	then
		SUBDOMINIO="smtp$NUMERO"
	elif [ $RANGO == "190.210.162" ]
	then
		SUBDOMINIO="srvi$NUMERO"
	elif [ $RANGO == "190.210.198" ]
	then
		SUBDOMINIO="host$NUMERO"
	elif [ $RANGO == "190.210.196" ]
	then
		SUBDOMINIO="srvk$NUMERO"
	else
		echo "no reconozco el rango $RANGO como uno dentro de Allytech, por favor llamalo a Oliver"
		exit 0
	fi


	##### la edicion de interfas web
	sed -i "/address/c\address $IP" /etc/network/interfaces
	sed -i "/netmask/c\netmask 255.255.255.0" /etc/network/interfaces
	sed -i "/network [0-9]/c\network $RANGO.0" /etc/network/interfaces
	sed -i "/broadcast/c\broadcast $RANGO.255" /etc/network/interfaces
	sed -i "/gateway/c\gateway $RANGO.254" /etc/network/interfaces
	
	##### nos aseguramos de que levante internechi
	ip addr flush eth0
	service networking restart
	
	##### cambiamos el hostname
	hostnamectl set-hostname $SUBDOMINIO.allytech.com
	
	##### Logueamos en el ISPCONFIG
	SESSIONID=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"username":"automat","password":"CVNQH!ku6h1"}' https://localhost:82/remote/json.php?login | cut -d":" -f4 | cut -d"}" -f1`
	
	
	#### cambiando el hostname en el ispconfig
	CAMBIOHOSTNAME=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"session_id":'"$SESSIONID"',"server_id":"1","section":"server","key":"hostname","value":"'"$SUBDOMINIO"'.allytech.com"}' https://localhost:82/remote/json.php?server_config_set | grep "ok"`
	
	if [ ! $CAMBIOHOSTNAME == "" ]
	then
		echo "ISPCONFIG= se actualizo el hostname"
	else
		echo "no pude cambiar el hostname de ispconfig!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	fi
	
	#### cambiando la ip en el ispconfig
	CAMBIOIP=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"session_id":'"$SESSIONID"',"server_id":"1","section":"server","key":"ip_address","value":"'"$IP"'"}' https://localhost:82/remote/json.php?server_config_set | grep "ok"`
	
	if [ ! $CAMBIOIP == "" ]
	then
		echo "ISPCONFIG= se cambio la ip"
	else
		echo "no pude cambiar la ip de ispconfig !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	fi
	
	#### cambiando el gateway en el ispconfig
	CAMBIOGATE=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"session_id":'"$SESSIONID"',"server_id":"1","section":"server","key":"gateway","value":"'"$RANGO"'.254"}' https://localhost:82/remote/json.php?server_config_set | grep "ok"`
	
	if [ ! $CAMBIOGATE == "" ]
	then
		echo "ISPCONFIG= se cambio el gateway"
	else
		echo "no pude cambiar el gateway de ispconfig!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	fi
	
	#### cambiando el servername en el ispconfig
	mysql -uroot -pRinGuinta56 dbispconfig -e "update server set server_name='$SUBDOMINIO.allytech.com' where server_id=1;"
	
	echo "ISPCONFIG= se cambio el servername"
	
	#### actualizando el hostname en el servidor
	sed -i "/allytech/c\ $IP  $SUBDOMINIO.allytech.com     $SUBDOMINIO" /etc/hosts
	
	
else
	echo "Necesito un numero de ip que no este siendo usado en este momento para funcionar"
fi

