#!/bin/bash
DOMINIO=$1
IP=$2


#### conseguimos todos los datos necesarios para laburar
IP_DAYTONA="200.68.105.130"
USUARIO_MYSQL="brunod"
CLAVE_MYSQL="Zfjh3c1z_"

NOMBRE_CLIENTE=$(mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL -h ${IP_DAYTONA} daytona2 -se "select cli.cli_nombre from CLIENTEPLANES as clip, cliente as cli, VPS as v where clip.idClientesPlanes=v.idClientesPlanes and clip.cli_codigo=cli.cli_codigo and v.dominio='${DOMINIO}';")
EMAIL1=$(mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL -h ${IP_DAYTONA} daytona2 -se "SELECT cli.cli_email FROM CLIENTEPLANES as clip, cliente as cli, VPS as v where clip.idClientesPlanes=v.idClientesPlanes and clip.cli_codigo=cli.cli_codigo and v.dominio='${DOMINIO}';")
EMAIL2=$(mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL -h ${IP_DAYTONA} daytona2 -se "SELECT cli.cli_email2 FROM CLIENTEPLANES as clip, cliente as cli, VPS as v where clip.idClientesPlanes=v.idClientesPlanes and clip.cli_codigo=cli.cli_codigo and v.dominio='${DOMINIO}';")
USUARIO=`echo $DOMINIO | cut -d"." -f1`
PASSW=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1`
ADMIN="ally"
DISPONIBILIDADIP=$(mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL daytona2 -h${IP_DAYTONA} -se "select estado from PoolIP where dirIP='${IP}';")


crearuser() 
{
	IP="$1"
        NOMBRE_CLIENTE="$2"
        EMAIL1="$3"
        EMAIL2="$4"
        DOMINIO="$5"
        USUARIO="$6"
        PASSW="$7"
	DISPONIBILIDADIP="$8"
	ADMIN="$9"




	
	if [ "$DISPONIBILIDADIP" == "" ]
	then
		mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL daytona2 -h${IP_DAYTONA} -se "insert into PoolIP(dirIP,estado,tipo) values ('${IP}','O','VIR');"
	fi
	#### conseguimos el id del ip 
	IDIP=$(mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL daytona2 -h${IP_DAYTONA} -se "select idIP from PoolIP where dirIP='${IP}';")
	#### chequeamos si esta cargado en la lista relacional de vps e ip, a veces no estan anda a saber porque
	VPSIP=$(mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL daytona2 -h${IP_DAYTONA} -se "select 1 from VPSIP where idIP='${IDIP}';")
	IDVPS=$(mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL daytona2 -h${IP_DAYTONA} -se "select idVPS from VPS where dominio='${DOMINIO}';")
		mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL daytona2 -h${IP_DAYTONA} -se "update VPSIP set idIP='${IDIP}' where idVPS='${IDVPS}'"
		mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL daytona2 -h${IP_DAYTONA} -se "update PoolIP set estado='O' where idIP='${IDIP}';"
	


	#### logueamos en el ispconfig en cuestion (el servidor ya tiene que estar levantado y con internechi)
	SESSIONID=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"username":"automat","password":"CVNQH!ku6h1"}' https://$IP:82/remote/json.php?login | cut -d":" -f4 | cut -d"}" -f1`
	
	
	#### plasmamos la informacion en el json
	sed -i '/contact_name/c\"contact_name":"'"$NOMBRE_CLIENTE"'",' datos.json
	sed -i '/username/c\"username":"'"$USUARIO"'",' datos.json
	sed -i '/password/c\"password":"'"$PASSW"'",' datos.json
	sed -i '/email/c\"email":"'"$EMAIL1"'",' datos.json
	sed -i '/session_id/c\"session_id":'"$SESSIONID"',' datos.json
	
	
	#### creamos el usuario del cliente en ISPCONFIG
	IDUSUARIO=`curl -s --header "Content-Type: application/json" --insecure --request POST --data-binary @datos.json https://$IP:82/remote/json.php?client_add | grep "ok" | cut -d'"' -f12`

	if [ ! $IDUSUARIO == "" ]
        then
                echo "ISPCONFIG= se dio de alta el usuario de panel"
        else
                echo "no pude dar de alta el usuario de panel!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        fi


	#### creamos el dominio en ISPCONFIG y cuardamos su ID
	IDDOMINIO=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"session_id":'"$SESSIONID"',"client_id":"'"$IDUSUARIO"'","params":{"server_id":"1","ip_address":"*","domain":"'"$DOMINIO"'","type":"vhost","parent_domain_id":"0","vhost_type":"name","hd_quota":"-1","traffic_quota":"-1","cgi":"y","ssi":"y","suexec":"y","errordocs":"1","is_subdomainwww":"1","subdomain":"www","php":"fast-cgi","ruby":"n","redirect_type":"","redirect_path":"","ssl":"n","ssl_state":"","ssl_locality":"","ssl_organisation":"","ssl_organisation_unit":"","ssl_country":"","ssl_domain":"","ssl_request":"","ssl_key":"","ssl_cert":"","ssl_bundle":"","ssl_action":"","stats_password":"","stats_type":"webalizer","allow_override":"All","apache_directives":"","php_open_basedir":"/","pm_max_requests":"0","pm_process_idle_timeout":"10","custom_php_ini":"","backup_interval":"","backup_copies":"1","active":"y","traffic_quota_lock":"n","http_port":"80","https_port":"443"}}' https://$IP:82/remote/json.php?sites_web_domain_add | grep "ok" | cut -d'"' -f12`


	if [ ! $IDDOMINIO == "" ]
        then
                echo "ISPCONFIG= se dio de alta el dominio"
        else
                echo "no pude dar de alta el dominio en el panel!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        fi
	
	#### conseguimos el documentroot del dominio recien creado
	DOCUMENTRDOMINIO=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"session_id":'"$SESSIONID"',"primary_id":"'"$IDDOMINIO"'"}' https://$IP:82/remote/json.php?sites_web_domain_get | grep "ok" | cut -d'"' -f66`
	DOCUMENTARREGLADO=`echo $DOCUMENTRDOMINIO | sed  's/\\\\//g'`


	#### conseguimos el usuario de sistema del dominio recien creado
	USERIDWEB=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"session_id":'"$SESSIONID"',"primary_id":"'"$IDDOMINIO"'"}' https://$IP:82/remote/json.php?sites_web_domain_get | grep "ok" | cut -d'"' -f74`	

	#### conseguimos el grupo de sistema del dominio recien creado
	GROUPIDWEB=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"session_id":'"$SESSIONID"',"primary_id":"'"$IDDOMINIO"'"}' https://$IP:82/remote/json.php?sites_web_domain_get | grep "ok" | cut -d'"' -f78`

	#### creamos el usuario FTP en ISPCONFIG
	ALTAFTP=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"session_id":'"$SESSIONID"',"client_id":"'"$IDUSUARIO"'","params":{"server_id":"1","parent_domain_id":"'"$IDDOMINIO"'","username":"'"$USUARIO"'","password":"'"$PASSW"'","quota_size":"-1","active":"y","uid":"'"$USERIDWEB"'","gid":"'"$GROUPIDWEB"'","dir":"'"$DOCUMENTARREGLADO"'","quota_files":"-1","ul_ratio":"-1","dl_ratio":"-1","ul_bandwidth":"-1","dl_bandwidth":"-1"}}' https://$IP:82/remote/json.php?sites_ftp_user_add | grep "ok"`

	if [ ! $ALTAFTP == "" ]
        then
                echo "ISPCONFIG= se dio de alta el usuario FTP"
        else
                echo "no pude dar de alta el usuario FTP en el panel!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        fi

	#### damos de alta el dominio de correo
	ALTADOMINIOMAIL=`curl -s --header "Content-Type: application/json" --insecure --request POST --data '{"session_id":'"$SESSIONID"',"client_id":"'"$IDUSUARIO"'","params":{"server_id":"1","domain":"'"$DOMINIO"'","active":"y"}}' https://$IP:82/remote/json.php?mail_domain_add | grep "ok"`

	if [ ! $ALTADOMINIOMAIL == "" ]
        then
                echo "ISPCONFIG= se dio de alta el dominio de correo"
        else
                echo "no pude dar de alta el dominio de correo en el panel!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        fi	



	#### cargamos los datos en la tabla mail_vps en el daytona para despues mandar el mail
	mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL daytona2 -h${IP_DAYTONA} -se "insert into mail_vps(ip,dominio,usuario,password,admin) values ('${IP}','${DOMINIO}','${USUARIO}','${PASSW}','${ADMIN}');"
	

		

	exit 0
}

cambiardatos()
{
	IP="$1"
	NOMBRE_CLIENTE="$2"
	EMAIL1="$3"
	EMAIL2="$4"
        DOMINIO="$5"
        USUARIO="$6"
        PASSW="$7"
	DISPONIBILIDADIP="$8"
	ADMIN="$9"
	echo ""
	echo "======== que queres cambiar? =========="
	echo "1- Cliente"
	echo "2- Mail"
	echo "3- Usuario"
	echo "4- Contraseña"
	echo "5- Admin"
	read -p "[1/2/3/4/5]" OPCION
	case $OPCION in
	1)
		read -p "[Cliente]:" NUEVOCLIENTE
		NOMBRE_CLIENTE=$NUEVOCLIENTE
	;;
	2)
		read -p "[Mail]:" NUEVOMAIL
		EMAIL1=$NUEVOMAIL
	;;
	3)
		read -p "[Usuario]:" NUEVOUSUARIO
		USUARIO=$NUEVOUSUARIO
	;;
	4)
		read -p "[Contraseña]:" NUEVAPASS
		PASSW=$NUEVAPASS
	;;
	5)
		read -p "[Admin]:" NUEVOADMIN
		ADMIN=$NUEVOADMIN
	;;
	*)
		echo "dale che, es del 1 al 5 las opciones..."
		exit 0
	;;
	esac
	echo ""
	echo ""
	confirmardatos "$IP" "$NOMBRE_CLIENTE" "$EMAIL1" "$EMAIL2" "$DOMINIO" "$USUARIO" "$PASSW" "$DISPONIBILIDADIP" "$ADMIN"
}

confirmardatos()
{
	IP=$1
	NOMBRE_CLIENTE=$2
	EMAIL1=$3
	EMAIL2=$4
	DOMINIO=$5
	USUARIO=$6
	PASSW=$7
	DISPONIBILIDADIP=$8
	ADMIN=$9	

	echo "======================================="
	printf "     Cliente |$NOMBRE_CLIENTE \n     Mail |$EMAIL1\n" | column -t -s "|"
	printf "     Mail 2  |$EMAIL2\n" | column -t -s "|"
	printf "     Dominio |$DOMINIO\n     Usuario |$USUARIO\n" | column -t -s "|"
	printf "     Password|$PASSW\n" | column -t -s "|"
	printf "     Admin   |$ADMIN\n" | column -t -s "|"
	echo "======================================="
	echo "Voy a usar estos datos para dar de alta el VPS, Estas de acuerdo?"
	read -p "[Y/N]" SIONO
	case $SIONO in
	y|Y)
		crearuser "$IP" "$NOMBRE_CLIENTE" "$EMAIL1" "$EMAIL2" "$DOMINIO" "$USUARIO" "$PASSW" "$DISPONIBILIDADIP" "$ADMIN"
	;;
	n|N)
		cambiardatos "$IP" "$NOMBRE_CLIENTE" "$EMAIL1" "$EMAIL2" "$DOMINIO" "$USUARIO" "$PASSW" "$DISPONIBILIDADIP" "$ADMIN"
	;;
	*)
		echo "dale macho, es apretar las teclas [Y] o [N]..."
		exit 0
	;;	
	esac
}



##############################################################################
###################Aca empieza el flujo normal del script
##############################################################################

#### chequeamos la validez de la ip
if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
then


        RANGO=`echo $IP | cut -d"." -f1,2,3`

        ##### definimos el subdominio del hostname
        if [ ! "$RANGO" == "200.68.105" ] && [ ! "$RANGO" == "190.210.162" ] && [ ! "$RANGO" == "190.210.198" ] && [ ! "$RANGO" == "190.210.196" ]
        then
                echo "no reconozco el rango $RANGO como uno dentro de Allytech. Si estas seguro que es correcto, por favor llamalo a Oliver"
                exit 0
        fi
else
	echo "me parece que $IP no es una ip"
	exit 0
fi


HAYDOMINIO=$(mysql -u$USUARIO_MYSQL -p$CLAVE_MYSQL daytona2 -h${IP_DAYTONA} -se "select 1 from VPS where dominio='${DOMINIO}';")
if [ ! "$HAYDOMINIO" == "1" ]
then
        echo "no estaria encontrando el dominio $DOMINIO en el daytona. Por favor chequea ese dato y probemos de nuevo"
        exit 0
fi

if [ "$DISPONIBILIDADIP" == "O" ]
then
	echo "che mira que la ip $IP me figura que ya esta ocupada en el daytona. Por favor asegurate de que figure como disponible y probemos de nuevo"
	exit 0
fi

confirmardatos "$IP" "$NOMBRE_CLIENTE" "$EMAIL1" "$EMAIL2" "$DOMINIO" "$USUARIO" "$PASSW" "$DISPONIBILIDADIP" "$ADMIN"


