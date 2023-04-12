#!/bin/bash
#
#
# Script realizado para la simulación de un SO que utilice
# SRPT para la ejecución de procesos donde las particiones de memoria
# sean según necesidades, la memoria sea contínua y se compacten los
# procesos para evitar la fragmentación.
#
#
# Autores : Miguel Arroyo Pérez y Adrián Pineda Miñón
# Fecha : 01/07/2017
#
#
# -----------------------------------------------------------------------------
#   Función utilizada para colorear lo impreso en pantalla.
#
	# Modify this script for your own purposes.
# It's easier than hand-coding color.
#
# Usage: 
#    cecho "Some text..." $blue  -> Print text in blue colour
#    cecho "Some text..."        -> Print text in black
#    cecho                       -> Print "No message passed."
# -------------------------------------------------------------------------
# ANSI color codes
RS="\033[0m"    # reset
HC="\033[1m"    # hicolor
UL="\033[4m"    # underline
INV="\033[7m"   # inverse background and foreground
FBLK="\033[0;30m" # foreground black
FRED="\033[0;31m" # foreground red
FGRN="\033[0;32m" # foreground green
FYEL="\033[0;33m" # foreground yellow
FBLE="\033[0;34m" # foreground blue
FMAG="\033[0;35m" # foreground magenta
FCYN="\033[0;36m" # foreground cyan
FWHT="\033[0;37m" # foreground white
BBLK="\033[0;40m" # background black
BRED="\033[0;41m" # background red
BGRN="\033[0;42m" # background green
BYEL="\033[0;43m" # background yellow
BBLE="\033[0;44m" # background blue
BMAG="\033[0;45m" # background magenta
BCYN="\033[0;46m" # background cyan
BWHT="\033[0;47m" # background white
# -------------------------------------------------------------------------
#alias Reset="tput sgr0"      #  Reset text attributes to normal
                             #+ without clearing screen.


cecho ()                     # Color-echo.
                             # Argument $1 = message
                             # Argument $2 = color
{
local default_msg="No message passed."
                             # Doesn't really need to be a local variable.
message=${1:-$default_msg}   # Defaults to default message.
color=${2:-$FWHT}           # Defaults to white, if not specified.

  echo -en "$color"
  echo "$message"
tput sgr0
#  Reset                      # Reset to normal.

  return
} 


# -----------------------------------------------------------------------------
#                         Tablas de trabajo (CAMBIAR ARRAYS Y VARIABLES)
# -----------------------------------------------------------------------------
# Declaramos los arrays y variables con los que trabajaremos en el script.
# Los procesos tendrán casi todos los elementos de cada una de estas tablas.
# A cada proceso se le asocia un índice, que será el mismo en todas las tablas,
# es decir, el proceso 1 tendrá la primera posición de cada array.
#
#     En nprocesos tendremos el número total de procesos.
#     En procesos() daremos un nombre al proceso.
#     En entradas() tendremos el tiempo de llegada de los procesos.
#     En ejecucion() tendremos el tiempo de ejecución de los procesos
#     En tamemory() tendremos cuánta memoria necesita cada proceso.
#     En temp_wait() iremos acumulando el tiempo de espera.
#     En temp_exec() iremos acumulando el tiempo de ejecución.
#
#     En pos_inicio() tendremos la posicion de inicio en memoria.
#     En pos_final() tendremos la posicion de final en memoria.
#
#     Para estos dos arrays (que deberán ser dinámicos) tendrémos los valores
#     de la memoria que están ocupados por un proceso, el valor de inicio en
#     memoria y el valor al final.
#
#     En mem_total tendremos el tamaño total de la memoria que se va a usar.
#
#     En encola() tendremos qué procesos pueden entrar en memoria.
#     Los valores son:
#	   	0 : El proceso no ha entrado en la cola (no ha "llegado")
#         	1 : El proceso está en la cola
#
#     En enmemoria() tendremos los procesos que se encuentran en memoria.
#     Los valores son:
#		0 : El proceso no está en memoria
#		1 : El proceso está en memoria esperando a ejecutarse
#
#     En ejecucion tendremos el número de proceso que está ejecutándose
#
#     En tiempo tendremos el instante de tiempo que se está tratando en el
#     programa.
#
# Cada array tendrá de tamaño el valor de nprocesos, excepto los relacionados
# con la memoria que serán dinámicos.
# -----------------------------------------------------------------------------
# Declaración de los arrays:
#

declare -a numeroProcesos
declare -a procesos
declare -a entradas
declare -a ejecucion
declare -a tamemory
declare -a temp_exec
declare -a temp_wait
declare -a pos_inicio #Cambiar a vector dinámico
declare -a pos_final  #Cambiar a vector dinámico
declare -a ordenEntrada #Añadir al comentario principal
declare -a entradaAuxiliar #Añadir al comentario principal
declare -a ejecucionAuxiliar #Añadir al comentario principal
declare -a tamemoryAuxiliar #Añadir al comentario principal
declare -a nollegado #Añadir al comentario principal
declare -a encola
declare -a enmemoria
declare -a enejecucion #Añadir al comentario principal
declare -a bloqueados #Añadir al comentario principal
declare -a terminados #Añadir al comentario principal
declare -a pausados #Añadir al comentario principal

declare -A estado #Añadir al comentario principal
######################################################################################################################################################################################################
###########################################################################                         ##################################################################################################
###########################################################################   Funciones             ##################################################################################################
###########################################################################   Generales             ##################################################################################################
###########################################################################                         ##################################################################################################
######################################################################################################################################################################################################



#-----------------------------------------------------------------------------
#                   FUNCIÓN SIMULACIÓN
#-----------------------------------------------------------------------------
function simulacion {
	cecho "Se están realizando cálculos..." $RS
# -----------------------------------------------------------------------------
# Inicilizamos las tablas indicadoras de la situación del proceso
# -----------------------------------------------------------------------------
for (( i=0; i<$nprocesos; i++ )) 
do     temp_wait[$i]=0
       pos_inicio[$i]=0
       pos_final[$i]=0
       ordenEntrada[$i]=0
       entradaAuxiliar[$i]=0
       ejecucionAuxiliar[$i]=0
       tamemoryAuxiliar[$i]=0
       encola[$i]=0
       enmemoria[$i]=0
       enejecucion[$i]=0
       bloqueados[$i]=0
       terminados[$i]=0
       nollegado[$i]=0
       posMemFinal[$i]=0
       posMemInicial[$i]=0
done

#Asignamos un 1 a la posicion donde la memoria termina, posicion 1 + de donde se acaba
#Y un 0 a las posiciones de memoria que tenemos que usar, [0 - mem_total]
for (( i = 0; i < $mem_total+1; i++ )); do
    posMem[$i]=0
    if [[ $i -eq $mem_total ]]; then
        posMem[$i]=1
    fi
done


#------------------------------------------------------------------------------
#    O R D E N     P A R A    E N T R A R    E N    M E M O R I A
#
# Bucle que ordena según el tiempo de llegada todos los procesos.
#
# 
#------------------------------------------------------------------------------

for (( i=0; i<$nprocesos; i++ )) #Copia de todas las listas para luego ponerlas en orden
do
	numeroProcesos[$i]=$i
	ordenEntrada[$i]=${procesos[$i]}
	entradaAuxiliar[$i]=${entradas[$i]} 
	ejecucionAuxiliar[$i]=${ejecucion[$i]}
	tamemoryAuxiliar[$i]=${tamemory[$i]}
	encola[$i]=0
        enmemoria[$i]=0
        enejecucion[$i]=0
        bloqueados[$i]=0
	pausados[$i]=0
done


for (( i=0; i<$nprocesos; i++ )) #Bucle que reordena por tiempo de llegada todos los arrays.
do
  	for (( j=$i; j<$nprocesos; j++ ))
	do
	    if [[ ${entradaAuxiliar[$j]} -le ${entradaAuxiliar[$i]} ]] ; then #Probar con -ge si falla
		if [[ ${ordenEntrada[$j]} -lt ${ordenEntrada[$i]} ]] ; then #Probar con -gt si falla
	       	   auxiliar1=${ordenEntrada[$i]}
		   auxiliar2=${entradaAuxiliar[$i]}
		   auxiliar3=${ejecucionAuxiliar[$i]}
		   auxiliar4=${tamemoryAuxiliar[$i]}
		   auxiliar5=${encola[$i]}
		   auxiliar6=${enmemoria[$i]}
		   auxiliar7=${enejecucion[$i]}
		   auxiliar8=${bloqueados[$i]}
		   auxiliar9=${numeroProcesos[$i]}
		   ordenEntrada[$i]=${ordenEntrada[$j]}
		   entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
		   ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
		   tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
		   encola[$i]=${encola[$j]}
		   enmemoria[$i]=${enmemoria[$j]}
		   enejecucion[$i]=${enejecucion[$j]}
		   bloqueados[$i]=${bloqueados[$j]}
		   numeroProcesos[$i]=${numeroProcesos[$j]}
		   ordenEntrada[$j]=$auxiliar1
		   entradaAuxiliar[$j]=$auxiliar2
		   ejecucionAuxiliar[$j]=$auxiliar3
		   tamemoryAuxiliar[$j]=$auxiliar4
		   encola[$j]=$auxiliar5
		   enmemoria[$j]=$auxiliar6
		   enejecucion[$j]=$auxiliar7
		   bloqueados[$j]=$auxiliar8
		   numeroProcesos[$j]=$auxiliar9
		fi
		   auxiliar1=${ordenEntrada[$i]}
		   auxiliar2=${entradaAuxiliar[$i]}
		   auxiliar3=${ejecucionAuxiliar[$i]}
		   auxiliar4=${tamemoryAuxiliar[$i]}
		   auxiliar5=${encola[$i]}
		   auxiliar6=${enmemoria[$i]}
		   auxiliar7=${enejecucion[$i]}
		   auxiliar8=${bloqueados[$i]}
		   auxiliar9=${numeroProcesos[$i]}
		   ordenEntrada[$i]=${ordenEntrada[$j]}
		   entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
		   ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
		   tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
		   encola[$i]=${encola[$j]}
		   enmemoria[$i]=${enmemoria[$j]}
		   enejecucion[$i]=${enejecucion[$j]}
		   bloqueados[$i]=${bloqueados[$j]}
		   numeroProcesos[$i]=${numeroProcesos[$j]}
		   ordenEntrada[$j]=$auxiliar1
		   entradaAuxiliar[$j]=$auxiliar2
		   ejecucionAuxiliar[$j]=$auxiliar3
		   tamemoryAuxiliar[$j]=$auxiliar4
		   encola[$j]=$auxiliar5
		   enmemoria[$j]=$auxiliar6
		   enejecucion[$j]=$auxiliar7
		   bloqueados[$j]=$auxiliar8
		   numeroProcesos[$j]=$auxiliar9
	     fi
	done
done


for (( i=0; i<$nprocesos; i++ ))
do
   for (( j=$i; j<$nprocesos; j++ ))
   do
	if [[ ${entradaAuxiliar[$i]} -eq ${entradaAuxiliar[$j]} ]] ; then
	   if [[ ${numeroProcesos[$i]} -gt ${numeroProcesos[$j]} ]] ; then
	           auxiliar1=${ordenEntrada[$i]}
		   auxiliar2=${entradaAuxiliar[$i]}
		   auxiliar3=${ejecucionAuxiliar[$i]}
		   auxiliar4=${tamemoryAuxiliar[$i]}
		   auxiliar5=${encola[$i]}
		   auxiliar6=${enmemoria[$i]}
		   auxiliar7=${enejecucion[$i]}
		   auxiliar8=${bloqueados[$i]}
		   auxiliar9=${numeroProcesos[$i]}
		   ordenEntrada[$i]=${ordenEntrada[$j]}
		   entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
		   ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
		   tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
		   encola[$i]=${encola[$j]}
		   enmemoria[$i]=${enmemoria[$j]}
		   enejecucion[$i]=${enejecucion[$j]}
		   bloqueados[$i]=${bloqueados[$j]}
		   numeroProcesos[$i]=${numeroProcesos[$j]}
		   ordenEntrada[$j]=$auxiliar1
		   entradaAuxiliar[$j]=$auxiliar2
		   ejecucionAuxiliar[$j]=$auxiliar3
		   tamemoryAuxiliar[$j]=$auxiliar4
		   encola[$j]=$auxiliar5
		   enmemoria[$j]=$auxiliar6
		   enejecucion[$j]=$auxiliar7
		   bloqueados[$j]=$auxiliar8
		   numeroProcesos[$j]=$auxiliar9
	   fi
	fi
   done
done

#for(( k=0; k<$nprocesos; k++)) PARA PRUEBAS
#	do
#		echo "La posicion $k contiene ${ordenEntrada[$k]}"
#	done
#	read enter

#Para imprimir el tiempo de ejecucion y hacer comparaciones en otros bucles e inicializar los vectores auxiliares o copias.

for (( i=0; i<$nprocesos; i++ ))
do
   tejecucion[$i]=${ejecucionAuxiliar[$i]}
   encolacopia[$i]=0
   enmemoriacopia[$i]=0
   enejecucioncopia[$i]=0
   bloqueadoscopia[$i]=0
   pausadoscopia[$i]=0
   terminadoscopia[$i]=0
done


mem_libre=$mem_total

# -----------------------------------------------------------------------------
#     B U C L E       P R I N C I P A L     D E L       A L G O R I T M O
#
# Bucle principal, desde tiempo=0 hasta que finalice la ejecución
# del último proceso, cuando la variable finalprocesos sea 0.
#
# -----------------------------------------------------------------------------

tiempo=0
parar_proceso="NO"              
cpu_ocupada="NO" 

finalprocesos=$nprocesos
 

while [ "$parar_proceso" == "NO" ]
do
    # -----------------------------------------------------------
    #	E N T R A D A      E N       C O L A
    # -----------------------------------------------------------
    # Si el momento de entrada del proceso coincide con el reloj
    # marcamos el proceso como preparado en encola()
    # -----------------------------------------------------------

    for (( i=0; i<$nprocesos; i++ )) #Bucle que pone en cola los procesos.  ##espera
    do
	if [[ ${entradaAuxiliar[$i]} == $tiempo ]] 
        then
            encola[$i]=1
	    nollegado[$i]=0
	    terminados[$i]=0
        elif [[ ${entradaAuxiliar[$i]} -lt $tiempo ]] ; then 
	    nollegado[$i]=0
	else
	    nollegado[$i]=1
	    terminados[$i]=0
	fi

    done

    # ------------------------------------------------------------
    #    G U A R D A D O      E N       M E M O R I A
    # ------------------------------------------------------------
    # Si un proceso está encola(), intento guardarlo en memoria
    # si cabe.
    # Si lo consigo, lo marco como listo enmemoria().
    # ------------------------------------------------------------

    for (( i=0; i<$nprocesos; i++ ))
    do



      if [[ ${encola[$i]} -eq 1 ]] && [[ ${bloqueados[$i]} -eq 0 ]] #Para cada proceso en cola y no bloqueado
      then
#####################################################################################################################################
      	metido="NO"
	    hueco="NO"
	    espacioEncontrado="NO"
	    counter=0
	    # for (( y = 0; y < $mem_total+1; y++ )); do
	    # 	echo "${posMem[$y]}"
	    # done
	    # read enter

    	#Buscamos el hueco donde lo vamos a meter
    	while [[ $iterar -le $mem_total ]] && [[ "$metido" == "NO" ]]; do
    		        #Buscamos donde empieza el posible hueco
	        while [[ "$hueco" == "NO" ]]; do
	            if [[ "${posMem[$counter]}" == "0" ]]; then
	             pos1=$counter
	             hueco="SI"
	             #echo "entra en hueco| counter = $counter "
	            else
	            counter=$(( counter + 1 ))
	            fi
	        done

	        let espacioLibre=0
	        let k=$counter

	        if [[ $hueco == "SI" ]]; then
	        #Calculamos el espacio disponible en el hueco.
	        salir="NO"
	        	while [[ "$espacioEncontrado" == "NO" ]] && [[ "$salir" == "NO" ]]; do
	            if [[ ${posMem[$k]} -eq 0 ]]; then
	                espacioLibre=$(( espacioLibre + 1 ))
	                k=$(( k + 1 ))
	             #echo "$espacioLibre"
	            #echo "k = $k"

			        #Comprobamos si podemos reubicar al no haber encontrado hueco
			        if [[ "$hueco" == "NO" ]] && [[ $mem_libre -ge ${tamemoryAuxiliar[$i]} ]]; then
			        	#echo"Reubicamos"
			        	IFS=$'\n' sorted=($(sort <<<"${posMem[*]}")); unset IFS #Reordenamos el vector
			        	#Volvemos a buscar el hueco
			        	while [[ "$hueco" == "NO" ]]; do
				            if [[ "${posMem[$counter]}" == "0" ]]; then
					             pos1=$counter
					             hueco="SI"
					            #echo "entra en hueco| counter = $counter "
				            else
				            	counter=$(( counter + 1 ))
				            fi
			        	done
			        fi

	            fi
		        #Comprobamos si el hueco encontrado posee le tamaño suficiente para albergar al proceso
	            if [[ $k -eq $mem_total ]] && [[ $espacioLibre -ge ${tamemoryAuxiliar[$i]} ]]; then
	            	#echo "libre: $espacioLibre - Mem: ${tamemoryAuxiliar[$i]}"
	                espacioEncontrado="SI"
	                #echo "espero 1"


	            elif [[ $k -eq $mem_total ]] && [[ $espacioLibre -lt ${tamemoryAuxiliar[$i]} ]]; then
	            	iterar=$(( mem_total + 1 ))
	            	#echo "MT: $mem_total - Iterar: $iterar"
	            	#echo "libre: $espacioLibre - Mem: ${tamemoryAuxiliar[$i]}"
	            	#echo "espero 0.5"
	            	salir="SI"
	            fi
	        done

	        if [[ $espacioLibre -ge ${tamemoryAuxiliar[$i]} ]]; then
	        	posMemInicial[$i]=$pos1
		            posMemFinal[$i]=$(( posMemInicial[$i] + tamemoryAuxiliar[$i] - 1 ))
		            tamannno=$(( posMemFinal[$i] - posMemFinal[$i] ))
		             #echo "antes || pos1 = $pos1 || tamMem = ${tamemoryAuxiliar[$i]}"
		            for (( b=$pos1; b<$pos1+${tamemoryAuxiliar[$i]}; b++ )); do
		                posMem[$b]=${ordenEntrada[$i]}
		                #echo "Memoria: ${posMem[$b]}"
		            done
		           #  echo "despues"
		            metido="SI"
	        fi
	        fi
	        

    	done

#####################################################################################################################################
         mem_libre=`expr $mem_libre - ${tamemoryAuxiliar[$i]}`
	 if [[  $mem_libre -lt "0" ]] ; then
		#echo no entra
	
	     mem_libre=`expr $mem_libre + ${tamemoryAuxiliar[$i]}`
	     for (( j=$i; j<$nprocesos; j++ )) #Bucle para bloquear los procesos
	     do
	     	#echo "aqui"
		bloqueados[$j]=1
		terminados[$j]=0

	     done

	 elif [[ ${bloqueados[$i]} -eq 0 ]] ; then
	     enmemoria[$i]=1
	     encola[$i]=0     #Este proceso ya solo estará en memoria, ejecutandose, pausado o habrá acabado
	     terminados[$i]=0
	     for (( j=0; j<$nprocesos; j++ )) #Bucle para desbloquear los procesos
	     do
	     	#echo "alli"
		bloqueados[$j]=0
	     done
	 fi
    fi
    #  echo "i = $i . nprocesos = $nprocesos"
    done
    	#echo me sumo al bucle

    # ----------------------------------------------------------------
    #  P L A N I F I C A D O R    D E    P R O C E S O S   -  S R P T
    # ----------------------------------------------------------------
    #           
    # Si tenemos procesos listos enmemoria(), ejecutamos el que 
    # corresponde en función del criterio de planificación
    # que en este caso es el que tenga una ejecución más corta de
    # todos los procesos. Se puede expulsar a un proceso de la CPU
    # aunque no haya acabado.
    #
    # ----------------------------------------------------------------

    # ------------------------------------------------------------
    # Si un proceso finaliza su tiempo de ejecucion, lo ponemos a 
    # 0 en la lista de enejecucion y liberamos la memoria que 
    # estaba ocupando
    # ------------------------------------------------------------


    indice_aux=-1
    temp_aux=9999999   
               
        for (( i=0; i<$nprocesos; i++ ))  #Establecemos que proceso tiene menor tiempo de ejecucion de todos los que se encuentran en memoria
        do
            if [[ ${enmemoria[$i]} -eq 1 ]]
            then
                if [ ${ejecucionAuxiliar[$i]} -lt $temp_aux ]
                then
                    indice_aux=$i                 	   #Proceso de ejecución más corta hasta ahora
                    temp_aux=${ejecucionAuxiliar[$i]}      #Tiempo de ejecución menor hasta ahora
                fi
            fi
        done



        if ! [ "$indice_aux" -eq -1 ]       #Hemos encontrado el proceso más corto
        then 
            enejecucion[$indice_aux]=1      #Marco el proceso para ejecutarse
            pausados[$indice_aux]=0         #Quitamos el estado pausado si el proceso lo estaba anteriormente
	    terminados[$indice_aux]=0
	    cpu_ocupada=SI                  #La CPU está ocupada por un proceso
        fi

    
    # ----------------------------------------------------------------
    # Bucle que establece si un proceso estaba en ejecución y ha   
    # pasado a estar en espera, pausado.
    # ----------------------------------------------------------------

	for (( i=0; i<$nprocesos; i++ ))
	do
	   if [[ ${enmemoria[$i]} -eq 1 ]] && [[ ${ejecucionAuxiliar[$i]} -lt ${tejecucion[$i]} ]] && [[ ${enejecucion[$i]} -eq 0 ]] ; then
		pausados[$i]=1
		terminados[$i]=0
	   fi
	done

   
    # ----------------------------------------------------------------
    # Incrementamos el contador de tiempos de ejecución y de espera 
    # de los procesos y decrementamos el tiempo de ejecución que 
    # tiene el proceso que se encuentra en ejecución.
    # ----------------------------------------------------------------
    for (( i=0; i<$nprocesos; i++ )) #Bucle que añade los tiempos de espera y ejecución a cada proceso. También quita el segundo del tiempo de ejecución
    do
        #if [[ ${encola[$i]} -eq 1 ]] || [[ ${enmemoria[$i]} -eq 1 ]] PRUEBAS
        #then
        #    temp_ret[$i]=`expr ${temp_ret[$i]} + 1`
        #fi

        if [[ ${enejecucion[$i]} -eq 1 ]]
        then  
	    ejecucionAuxiliar[$i]=`expr ${ejecucionAuxiliar[$i]} - 1`
        fi
    done



    for (( i=0; i<$nprocesos; i++ )) #Bucle que comprueba si el proceso en ejecución ha finalizado.
    do
        if [[ ${enejecucion[$i]} -eq 1 ]]
        then 
            if [ ${ejecucionAuxiliar[$i]} -eq 0 ] 
            then
                enejecucion[$i]=0
		enmemoria[$i]=0
		mem_libre=`expr $mem_libre + ${tamemoryAuxiliar[$i]}` #Recuperamos la memoria que ocupaba el proceso
                cpu_ocupada=NO
		finalprocesos=`expr $finalprocesos - 1`
		#echo ${posMemInicial[$i]}
		for (( p = ${posMemInicial[$i]}; p <= ${posMemFinal[$i]} ; p++ )); do
             posMem[$p]=0
        done
		#echo "      $finalprocesos"
		terminados[$i]=1
            fi
        fi
    done

#GUARDAR LOS ESTADOS DEL ULTIMO CICLO EN UNA COPIA EN CADA BUCLE DONDE SE PUEDA CAMBIAR UN ESTADO
#COMPARAR AQUI

#Hace falta poner a cero el evento cuando no suceda nada¿?

for (( i=0; i<$nprocesos; i++ ))
do
   if [[ ${terminados[$i]} -ne ${terminadoscopia[$i]} ]] ; then
	evento[$tiempo]=1
	#echo "Tiempo $tiempo: Terminados --- ${terminados[$i]} -ne ${terminadoscopia[$i]} ---- ${ordenEntrada[$i]}" 
   fi
   if [[ ${pausados[$i]} -ne ${pausadoscopia[$i]} ]] ; then
	evento[$tiempo]=1
	#echo "Tiempo $tiempo: Pausados   --- ${pausados[$i]} -ne ${pausadoscopia[$i]} ---- ${ordenEntrada[$i]}"
   fi
   if [[ ${bloqueados[$i]} -ne ${bloqueadoscopia[$i]} ]] ; then
	evento[$tiempo]=1
	#echo "Tiempo $tiempo: Bloqueados --- ${bloqueados[$i]} -ne ${bloqueadoscopia[$i]} ---- ${ordenEntrada[$i]}"
   fi
   if [[ ${enejecucion[$i]} -ne ${enejecucioncopia[$i]} ]] ; then
	evento[$tiempo]=1
	#echo "Tiempo $tiempo: En ejecucion - ${enejecucion[$i]} -ne ${enejecucioncopia[$i]} ---- ${ordenEntrada[$i]}"
   fi
   if [[ ${enmemoria[$i]} -ne ${enmemoriacopia[$i]} ]] ; then
	evento[$tiempo]=1
	#echo "Tiempo $tiempo: En memoria --- ${enmemoria[$i]} -ne ${enmemoriacopia[$i]} ---- ${ordenEntrada[$i]}"
   fi
   if [[ ${encola[$i]} -ne ${encolacopia[$i]} ]] ; then
	evento[$tiempo]=1
	#echo "Tiempo $tiempo: En cola    --- ${encola[$i]} -ne ${encolacopia[$i]} ---- ${ordenEntrada[$i]}"
   fi

done

#COMPROBAMOS SI SUCEDE UN EVENTO EN EL PROGRAMA, PARA IMPRIMIR LA TABLA CON LOS DATOS.
#PARA ELLO COMPARAMOS SI SON IGUALES EL ESTADO DE LA COPIA Y EL ACTUAL, SE COMPARA ANTES DE ESTABLECER LOS ESTADOS DEL TIEMPO ACTUAL

for (( i=0; i<$nprocesos; i++ ))
do
   encolacopia[$i]=${encola[$i]}
   enmemoriacopia[$i]=${enmemoria[$i]}
   enejecucioncopia[$i]=${enejecucion[$i]}
   terminadoscopia[$i]=${terminados[$i]}
   bloqueadoscopia[$i]=${bloqueados[$i]}
   pausadoscopia[$i]=${pausados[$i]}
done



#Declarar un vector eventos


    # Incrementamos el reloj
    tiempo=`expr $tiempo + 1`
    

    if [ "$finalprocesos" -eq 0 ] #En caso de que finalprocesos sea 0, se termina con el programa.
        then parar_proceso=SI
    fi

# --------------------------------------------------------------------
#   D I B U J O    D E    L A    B A R R A    D E    M E M O R I A  
# -------------------------------------------------------------------- 


#Ponemos todas las posiciones del vector enejecucion a 0, se establecerá qué proceso está a 1 en cada ciclo del programa.

   for (( i=0; i<$nprocesos; i++ ))
   do
	enejecucion[$i]=0
	bloqueados[$i]=0 #También se establecen los procesos bloqueados en cada ciclo.
   done

# echo "Parar Proceso = $parar_proceso"
# for (( u = 0; u < ${#bloqueados[@]}; u++ )); do
# 	echo Bloqueado $i = ${bloqueados[$u]}
# done

done

for (( i=0; i<$nprocesos; i++ ))
do
   temp_ret[$i]=`expr ${tejecucion[$i]} + ${temp_resp[$i]} + ${temp_wait[$i]}`
done

echo " "
cecho "Cálculos realizados. (Pulse enter para comenzar el proceso de visualización)" $RS
#read enter

# -----------------------------------------------------------------------------
#             F I N       D E L       B U C L E  
# -----------------------------------------------------------------------------
}


#-----------------------------------------------------------------------------
#                   FUNCIÓN READFILE
#-----------------------------------------------------------------------------

function readfile {
	OIFS=$IFS               #Guardamos el separador de campos inicial
IFS=":"                 #Carácter que separa los campos en el fichero
n=-1
nprocesos=0
mem_total=0
    coloresTemp[0]=$FRED
    coloresTemp[1]=$FGRN
    coloresTemp[2]=$FYEL
    coloresTemp[3]=$FBLE
    coloresTemp[4]=$FMAG
    coloresTemp[5]=$FCYN
    coloresTemp[6]=$FRED
    coloresTemp[7]=$FGRN
    coloresTemp[8]=$FYEL
    coloresTemp[9]=$FBLE
    coloresTemp[10]=$FMAG
    coloresTemp[11]=$FCYN
    coloresTemp[12]=$FRED
    coloresTemp[13]=$FGRN
    coloresTemp[14]=$FYEL
    coloresTemp[15]=$FBLE
    coloresTemp[16]=$FMAG
    coloresTemp[17]=$FCYN
    coloresTemp[18]=$FRED
    coloresTemp[19]=$FGRN
    coloresTemp[20]=$FYEL


while read line; do
     # Convertimos el registro leído en un array
     lineArray=($line)

     # Guardamos cada campo en su array correspondiente
     if [[ $n -eq -1 ]]; then
         mem_total=${lineArray[0]}
         mem_total1=${lineArray[0]}
     else
     entradas[$n]=${lineArray[0]}
     ejecucion[$n]=${lineArray[1]}
     tamemory[$n]=${lineArray[2]}
     entradas1[$n]=${lineArray[0]}
     ejecucion1[$n]=${lineArray[1]}
     tamemory1[$n]=${lineArray[2]}
     fi

     if ! [[ $n -eq -1 ]]; then
        nprocesos=$(( $nprocesos + 1 ))
        temp=$(( n + 1 ))
        if [[ $nprocesos -lt 10 ]]; then
          procesos[$n]="P0"$temp      # Los procesos se llamarán P01, P02,...
       else
          procesos[$n]="P"$temp      # Los procesos se llamarán P10, P11, P12,...
       fi
     fi
     n=$(( $n + 1  ))
done < datos.txt

nprocesos=$n
pcounter=$(( $nprocesos - 1 ))
IFS=$OIFS               # Recuperamos el separador de campos inicial


for(( i=0; i<$nprocesos; i++)) #Copia de todas las listas para luego ponerlas en orden
do
  numeroProcesos[$i]=$i
  ordenEntrada[$i]=${procesos[$i]}
  entradaAuxiliar[$i]=${entradas[$i]}
  ejecucionAuxiliar[$i]=${ejecucion[$i]}
  tamemoryAuxiliar[$i]=${tamemory[$i]}
  encola[$i]=0
    enmemoria[$i]=0
    enejecucion[$i]=0
    bloqueados[$i]=0
    pausados[$i]=0
    terminados[$i]=0
    nollegado[$i]=0
    estado[$i]=0
    temp_wait[$i]=0
    temp_resp[$i]=0
    temp_ret[$i]=0
done



for (( i=0; i<$nprocesos; i++ )) #Bucle que reordena por tiempo de llegada todos los arrays.
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
      if [[ ${entradaAuxiliar[$j]} -le ${entradaAuxiliar[$i]} ]] ; then #Probar con -ge si falla
    if [[ ${ordenEntrada[$j]} -lt ${ordenEntrada[$i]} ]] ; then #Probar con -gt si falla
            auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
    auxiliar1=${ordenEntrada[$i]}
    auxiliar2=${entradaAuxiliar[$i]}
    auxiliar3=${ejecucionAuxiliar[$i]}
    auxiliar4=${tamemoryAuxiliar[$i]}
    auxiliar5=${encola[$i]}
    auxiliar6=${enmemoria[$i]}
    auxiliar7=${enejecucion[$i]}
    auxiliar8=${bloqueados[$i]}
    auxiliar9=${numeroProcesos[$i]}
    ordenEntrada[$i]=${ordenEntrada[$j]}
    entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
    ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
    tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
    encola[$i]=${encola[$j]}
    enmemoria[$i]=${enmemoria[$j]}
    enejecucion[$i]=${enejecucion[$j]}
    bloqueados[$i]=${bloqueados[$j]}
    numeroProcesos[$i]=${numeroProcesos[$j]}
    ordenEntrada[$j]=$auxiliar1
    entradaAuxiliar[$j]=$auxiliar2
    ejecucionAuxiliar[$j]=$auxiliar3
    tamemoryAuxiliar[$j]=$auxiliar4
    encola[$j]=$auxiliar5
    enmemoria[$j]=$auxiliar6
    enejecucion[$j]=$auxiliar7
    bloqueados[$j]=$auxiliar8
    numeroProcesos[$j]=$auxiliar9
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
   if [[ ${entradaAuxiliar[$i]} -eq ${entradaAuxiliar[$j]} ]] ; then
    if [[ ${numeroProcesos[$i]} -gt ${numeroProcesos[$j]} ]] ; then
        auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
fi
done
done

for (( i=0; i<$nprocesos; i++ ))
do
 tejecucion[$i]=${ejecucionAuxiliar[$i]}
done

for (( i = 0; i < ${#ordenEntrada[@]}; i++ )); do
  if [[ "${ordenEntrada[$i]}" == "P01" ]]; then
    colores[$i]="${coloresTemp[1]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P02" ]]; then
    colores[$i]="${coloresTemp[2]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P03" ]]; then
    colores[$i]="${coloresTemp[3]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P04" ]]; then
    colores[$i]="${coloresTemp[4]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P05" ]]; then
    colores[$i]="${coloresTemp[5]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P06" ]]; then
    colores[$i]="${coloresTemp[6]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P07" ]]; then
    colores[$i]="${coloresTemp[7]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P08" ]]; then
    colores[$i]="${coloresTemp[8]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P09" ]]; then
    colores[$i]="${coloresTemp[9]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P10" ]]; then
    colores[$i]="${coloresTemp[10]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P11" ]]; then
    colores[$i]="${coloresTemp[11]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P12" ]]; then
    colores[$i]="${coloresTemp[12]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P13" ]]; then
    colores[$i]="${coloresTemp[13]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P14" ]]; then
    colores[$i]="${coloresTemp[14]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P15" ]]; then
    colores[$i]="${coloresTemp[15]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P16" ]]; then
    colores[$i]="${coloresTemp[16]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P17" ]]; then
    colores[$i]="${coloresTemp[17]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P18" ]]; then
    colores[$i]="${coloresTemp[18]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P19" ]]; then
    colores[$i]="${coloresTemp[19]}"
  fi
done

blanco="\e[37m"

mem_libre=$mem_total
mem_aux=$mem_libre






printf "\n"
cecho "Estos son los datos de partida:" $FBLE
printf "\n"

#####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll  Tej  Mem" $FYEL

for (( i=0; i<$n; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n"
      done


printf "\n\n"

cecho "MEMORIA TOTAL: $mem_total M" $FCYN
cecho "---------------------------------------------" $FRED
cecho "¿Está de acuerdo con estos datos? (s/n)" $FYEL
read ok
if ! [ "$ok" == "s" ] && ! [ "$ok" == "" ]
then cecho "Programa cancelado, modifique los valores desde el .txt y reinicie." $FRED
     exit 0
fi
cecho "---------------------------------------------" $FRED



echo "Estos son los datos de partida:" >> informebn.txt
printf "\n" >> informebn.txt

echo "-----------------------------------------------------------------" >> informebn.txt
echo "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |" >> informebn.txt
echo "-----------------------------------------------------------------" >> informebn.txt

   for (( i=0; i<$nprocesos; i++))
   do
	printf "|\t${procesos[$i]}\t|\t${entradas[$i]}\t|\t${ejecucion[$i]}\t|\t${tamemory[$i]}\t|\n" >> informebn.txt
   done
echo "-----------------------------------------------------------------" >> informebn.txt

printf "\n\n" >> informebn.txt

echo "MEMORIA TOTAL: $mem_total M" >> informebn.txt
echo "---------------------------------------------" >> informebn.txt




cecho "Estos son los datos de partida:" >> informecolor.txt $FBLE
printf "\n" >> informebn.txt

cecho "-----------------------------------------------------------------" >> informecolor.txt $FYEL
cecho "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |" >> informecolor.txt $FYEL
cecho "-----------------------------------------------------------------" >> informecolor.txt $FYEL

   for (( i=0; i<$nprocesos; i++))
   do
	printf "|\t${procesos[$i]}\t|\t${entradas[$i]}\t|\t${ejecucion[$i]}\t|\t${tamemory[$i]}\t|\n" >> informecolor.txt
   done
echo "-----------------------------------------------------------------" >> informecolor.txt

printf "\n\n" >> informecolor.txt

cecho "MEMORIA TOTAL: $mem_total M" >> informecolor.txt $FCYN
cecho "---------------------------------------------" >> informecolor.txt $FRED

}

#--------------------------------------------------------------------------
#                        FUNCIÓN READFILE2
#--------------------------------------------------------------------------
function readfile2 {
	
OIFS=$IFS               #Guardamos el separador de campos inicial
IFS=":"                 #Carácter que separa los campos en el fichero
n=-1
nprocesos=0
mem_total=0
    coloresTemp[0]=$FRED
    coloresTemp[1]=$FGRN
    coloresTemp[2]=$FYEL
    coloresTemp[3]=$FBLE
    coloresTemp[4]=$FMAG
    coloresTemp[5]=$FCYN
    coloresTemp[6]=$FRED
    coloresTemp[7]=$FGRN
    coloresTemp[8]=$FYEL
    coloresTemp[9]=$FBLE
    coloresTemp[10]=$FMAG
    coloresTemp[11]=$FCYN
    coloresTemp[12]=$FRED
    coloresTemp[13]=$FGRN
    coloresTemp[14]=$FYEL
    coloresTemp[15]=$FBLE
    coloresTemp[16]=$FMAG
    coloresTemp[17]=$FCYN
    coloresTemp[18]=$FRED
    coloresTemp[19]=$FGRN
    coloresTemp[20]=$FYEL


while read line; do
     # Convertimos el registro leído en un array
     lineArray=($line)

     # Guardamos cada campo en su array correspondiente
     if [[ $n -eq -1 ]]; then
         mem_total=${lineArray[0]}
         mem_total1=${lineArray[0]}
     else
     entradas[$n]=${lineArray[0]}
     ejecucion[$n]=${lineArray[1]}
     tamemory[$n]=${lineArray[2]}
     entradas1[$n]=${lineArray[0]}
     ejecucion1[$n]=${lineArray[1]}
     tamemory1[$n]=${lineArray[2]}
     fi

     if ! [[ $n -eq -1 ]]; then
        nprocesos=$(( $nprocesos + 1 ))
        temp=$(( n + 1 ))
        if [[ $nprocesos -lt 10 ]]; then
          procesos[$n]="P0"$temp      # Los procesos se llamarán P01, P02,...
       else
          procesos[$n]="P"$temp      # Los procesos se llamarán P10, P11, P12,...
       fi
     fi
     n=$(( $n + 1  ))
done < $leerFichero

nprocesos=$n
pcounter=$(( $nprocesos - 1 ))
IFS=$OIFS               # Recuperamos el separador de campos inicial


for(( i=0; i<$nprocesos; i++)) #Copia de todas las listas para luego ponerlas en orden
do
  numeroProcesos[$i]=$i
  ordenEntrada[$i]=${procesos[$i]}
  entradaAuxiliar[$i]=${entradas[$i]}
  ejecucionAuxiliar[$i]=${ejecucion[$i]}
  tamemoryAuxiliar[$i]=${tamemory[$i]}
  encola[$i]=0
    enmemoria[$i]=0
    enejecucion[$i]=0
    bloqueados[$i]=0
    pausados[$i]=0
    terminados[$i]=0
    nollegado[$i]=0
    estado[$i]=0
    temp_wait[$i]=0
    temp_resp[$i]=0
    temp_ret[$i]=0
done



for (( i=0; i<$nprocesos; i++ )) #Bucle que reordena por tiempo de llegada todos los arrays.
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
      if [[ ${entradaAuxiliar[$j]} -le ${entradaAuxiliar[$i]} ]] ; then #Probar con -ge si falla
    if [[ ${ordenEntrada[$j]} -lt ${ordenEntrada[$i]} ]] ; then #Probar con -gt si falla
            auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
    auxiliar1=${ordenEntrada[$i]}
    auxiliar2=${entradaAuxiliar[$i]}
    auxiliar3=${ejecucionAuxiliar[$i]}
    auxiliar4=${tamemoryAuxiliar[$i]}
    auxiliar5=${encola[$i]}
    auxiliar6=${enmemoria[$i]}
    auxiliar7=${enejecucion[$i]}
    auxiliar8=${bloqueados[$i]}
    auxiliar9=${numeroProcesos[$i]}
    ordenEntrada[$i]=${ordenEntrada[$j]}
    entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
    ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
    tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
    encola[$i]=${encola[$j]}
    enmemoria[$i]=${enmemoria[$j]}
    enejecucion[$i]=${enejecucion[$j]}
    bloqueados[$i]=${bloqueados[$j]}
    numeroProcesos[$i]=${numeroProcesos[$j]}
    ordenEntrada[$j]=$auxiliar1
    entradaAuxiliar[$j]=$auxiliar2
    ejecucionAuxiliar[$j]=$auxiliar3
    tamemoryAuxiliar[$j]=$auxiliar4
    encola[$j]=$auxiliar5
    enmemoria[$j]=$auxiliar6
    enejecucion[$j]=$auxiliar7
    bloqueados[$j]=$auxiliar8
    numeroProcesos[$j]=$auxiliar9
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
   if [[ ${entradaAuxiliar[$i]} -eq ${entradaAuxiliar[$j]} ]] ; then
    if [[ ${numeroProcesos[$i]} -gt ${numeroProcesos[$j]} ]] ; then
        auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
fi
done
done

for (( i=0; i<$nprocesos; i++ ))
do
 tejecucion[$i]=${ejecucionAuxiliar[$i]}
done

for (( i = 0; i < ${#ordenEntrada[@]}; i++ )); do
  if [[ "${ordenEntrada[$i]}" == "P01" ]]; then
    colores[$i]="${coloresTemp[1]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P02" ]]; then
    colores[$i]="${coloresTemp[2]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P03" ]]; then
    colores[$i]="${coloresTemp[3]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P04" ]]; then
    colores[$i]="${coloresTemp[4]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P05" ]]; then
    colores[$i]="${coloresTemp[5]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P06" ]]; then
    colores[$i]="${coloresTemp[6]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P07" ]]; then
    colores[$i]="${coloresTemp[7]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P08" ]]; then
    colores[$i]="${coloresTemp[8]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P09" ]]; then
    colores[$i]="${coloresTemp[9]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P10" ]]; then
    colores[$i]="${coloresTemp[10]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P11" ]]; then
    colores[$i]="${coloresTemp[11]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P12" ]]; then
    colores[$i]="${coloresTemp[12]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P13" ]]; then
    colores[$i]="${coloresTemp[13]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P14" ]]; then
    colores[$i]="${coloresTemp[14]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P15" ]]; then
    colores[$i]="${coloresTemp[15]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P16" ]]; then
    colores[$i]="${coloresTemp[16]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P17" ]]; then
    colores[$i]="${coloresTemp[17]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P18" ]]; then
    colores[$i]="${coloresTemp[18]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P19" ]]; then
    colores[$i]="${coloresTemp[19]}"
  fi
done

blanco="\e[37m"

mem_libre=$mem_total
mem_aux=$mem_libre






printf "\n"
cecho "Estos son los datos de partida:" $FBLE
printf "\n"

#####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll  Tej  Mem" $FYEL

for (( i=0; i<$n; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n"
      done


printf "\n\n"

cecho "MEMORIA TOTAL: $mem_total M" $FCYN
cecho "---------------------------------------------" $FRED
cecho "¿Está de acuerdo con estos datos? (s/n)" $FYEL
read ok
if ! [ "$ok" == "s" ] && ! [ "$ok" == "" ]
then cecho "Programa cancelado, modifique los valores desde el .txt y reinicie." $FRED
     exit 0
fi
cecho "---------------------------------------------" $FRED



echo "Estos son los datos de partida:" >> informebn.txt
printf "\n" >> informebn.txt

echo "-----------------------------------------------------------------" >> informebn.txt
echo "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |" >> informebn.txt
echo "-----------------------------------------------------------------" >> informebn.txt

   for (( i=0; i<$nprocesos; i++))
   do
	printf "|\t${procesos[$i]}\t|\t${entradas[$i]}\t|\t${ejecucion[$i]}\t|\t${tamemory[$i]}\t|\n" >> informebn.txt
   done
echo "-----------------------------------------------------------------" >> informebn.txt

printf "\n\n" >> informebn.txt

echo "MEMORIA TOTAL: $mem_total M" >> informebn.txt
echo "---------------------------------------------" >> informebn.txt




cecho "Estos son los datos de partida:" >> informecolor.txt $FBLE
printf "\n" >> informebn.txt

cecho "-----------------------------------------------------------------" >> informecolor.txt $FYEL
cecho "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |" >> informecolor.txt $FYEL
cecho "-----------------------------------------------------------------" >> informecolor.txt $FYEL

   for (( i=0; i<$nprocesos; i++))
   do
	printf "|\t${procesos[$i]}\t|\t${entradas[$i]}\t|\t${ejecucion[$i]}\t|\t${tamemory[$i]}\t|\n" >> informecolor.txt
   done
echo "-----------------------------------------------------------------" >> informecolor.txt

printf "\n\n" >> informecolor.txt

cecho "MEMORIA TOTAL: $mem_total M" >> informecolor.txt $FCYN
cecho "---------------------------------------------" >> informecolor.txt $FRED

}

#--------------------------------------------------------------------------
#                        FUNCIÓN READFILEALEATORIO
#--------------------------------------------------------------------------

function readfilealeatorio {
	OIFS=$IFS               #Guardamos el separador de campos inicial
IFS=":"                 #Carácter que separa los campos en el fichero
n=-1
nprocesos=0
mem_total=0
    coloresTemp[0]=$FRED
    coloresTemp[1]=$FGRN
    coloresTemp[2]=$FYEL
    coloresTemp[3]=$FBLE
    coloresTemp[4]=$FMAG
    coloresTemp[5]=$FCYN
    coloresTemp[6]=$FRED
    coloresTemp[7]=$FGRN
    coloresTemp[8]=$FYEL
    coloresTemp[9]=$FBLE
    coloresTemp[10]=$FMAG
    coloresTemp[11]=$FCYN
    coloresTemp[12]=$FRED
    coloresTemp[13]=$FGRN
    coloresTemp[14]=$FYEL
    coloresTemp[15]=$FBLE
    coloresTemp[16]=$FMAG
    coloresTemp[17]=$FCYN
    coloresTemp[18]=$FRED
    coloresTemp[19]=$FGRN
    coloresTemp[20]=$FYEL


while read line; do
     # Convertimos el registro leído en un array
     lineArray=($line)

     # Guardamos cada campo en su array correspondiente
     if [[ $n -eq -1 ]]; then
         mem_total=${lineArray[0]}
         mem_total1=${lineArray[0]}
     else
     entradas[$n]=${lineArray[0]}
     ejecucion[$n]=${lineArray[1]}
     tamemory[$n]=${lineArray[2]}
     entradas1[$n]=${lineArray[0]}
     ejecucion1[$n]=${lineArray[1]}
     tamemory1[$n]=${lineArray[2]}
     fi

     if ! [[ $n -eq -1 ]]; then
        nprocesos=$(( $nprocesos + 1 ))
        temp=$(( n + 1 ))
        if [[ $nprocesos -lt 10 ]]; then
          procesos[$n]="P0"$temp      # Los procesos se llamarán P01, P02,...
       else
          procesos[$n]="P"$temp      # Los procesos se llamarán P10, P11, P12,...
       fi
     fi
     n=$(( $n + 1  ))
done < datosrangos.txt 

nprocesos=$n
pcounter=$(( $nprocesos - 1 ))
IFS=$OIFS               # Recuperamos el separador de campos inicial


for(( i=0; i<$nprocesos; i++)) #Copia de todas las listas para luego ponerlas en orden
do
  numeroProcesos[$i]=$i
  ordenEntrada[$i]=${procesos[$i]}
  entradaAuxiliar[$i]=${entradas[$i]}
  ejecucionAuxiliar[$i]=${ejecucion[$i]}
  tamemoryAuxiliar[$i]=${tamemory[$i]}
  encola[$i]=0
    enmemoria[$i]=0
    enejecucion[$i]=0
    bloqueados[$i]=0
    pausados[$i]=0
    terminados[$i]=0
    nollegado[$i]=0
    estado[$i]=0
    temp_wait[$i]=0
    temp_resp[$i]=0
    temp_ret[$i]=0
done



for (( i=0; i<$nprocesos; i++ )) #Bucle que reordena por tiempo de llegada todos los arrays.
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
      if [[ ${entradaAuxiliar[$j]} -le ${entradaAuxiliar[$i]} ]] ; then #Probar con -ge si falla
    if [[ ${ordenEntrada[$j]} -lt ${ordenEntrada[$i]} ]] ; then #Probar con -gt si falla
            auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
    auxiliar1=${ordenEntrada[$i]}
    auxiliar2=${entradaAuxiliar[$i]}
    auxiliar3=${ejecucionAuxiliar[$i]}
    auxiliar4=${tamemoryAuxiliar[$i]}
    auxiliar5=${encola[$i]}
    auxiliar6=${enmemoria[$i]}
    auxiliar7=${enejecucion[$i]}
    auxiliar8=${bloqueados[$i]}
    auxiliar9=${numeroProcesos[$i]}
    ordenEntrada[$i]=${ordenEntrada[$j]}
    entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
    ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
    tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
    encola[$i]=${encola[$j]}
    enmemoria[$i]=${enmemoria[$j]}
    enejecucion[$i]=${enejecucion[$j]}
    bloqueados[$i]=${bloqueados[$j]}
    numeroProcesos[$i]=${numeroProcesos[$j]}
    ordenEntrada[$j]=$auxiliar1
    entradaAuxiliar[$j]=$auxiliar2
    ejecucionAuxiliar[$j]=$auxiliar3
    tamemoryAuxiliar[$j]=$auxiliar4
    encola[$j]=$auxiliar5
    enmemoria[$j]=$auxiliar6
    enejecucion[$j]=$auxiliar7
    bloqueados[$j]=$auxiliar8
    numeroProcesos[$j]=$auxiliar9
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
   if [[ ${entradaAuxiliar[$i]} -eq ${entradaAuxiliar[$j]} ]] ; then
    if [[ ${numeroProcesos[$i]} -gt ${numeroProcesos[$j]} ]] ; then
        auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
fi
done
done

for (( i=0; i<$nprocesos; i++ ))
do
 tejecucion[$i]=${ejecucionAuxiliar[$i]}
done

for (( i = 0; i < ${#ordenEntrada[@]}; i++ )); do
  if [[ "${ordenEntrada[$i]}" == "P01" ]]; then
    colores[$i]="${coloresTemp[1]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P02" ]]; then
    colores[$i]="${coloresTemp[2]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P03" ]]; then
    colores[$i]="${coloresTemp[3]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P04" ]]; then
    colores[$i]="${coloresTemp[4]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P05" ]]; then
    colores[$i]="${coloresTemp[5]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P06" ]]; then
    colores[$i]="${coloresTemp[6]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P07" ]]; then
    colores[$i]="${coloresTemp[7]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P08" ]]; then
    colores[$i]="${coloresTemp[8]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P09" ]]; then
    colores[$i]="${coloresTemp[9]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P10" ]]; then
    colores[$i]="${coloresTemp[10]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P11" ]]; then
    colores[$i]="${coloresTemp[11]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P12" ]]; then
    colores[$i]="${coloresTemp[12]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P13" ]]; then
    colores[$i]="${coloresTemp[13]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P14" ]]; then
    colores[$i]="${coloresTemp[14]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P15" ]]; then
    colores[$i]="${coloresTemp[15]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P16" ]]; then
    colores[$i]="${coloresTemp[16]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P17" ]]; then
    colores[$i]="${coloresTemp[17]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P18" ]]; then
    colores[$i]="${coloresTemp[18]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P19" ]]; then
    colores[$i]="${coloresTemp[19]}"
  fi
done

blanco="\e[37m"

mem_libre=$mem_total
mem_aux=$mem_libre






printf "\n"
cecho "Estos son los datos de partida:" $FBLE
printf "\n"

#####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll  Tej  Mem" $FYEL

for (( i=0; i<$n; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n"
      done


printf "\n\n"

cecho "MEMORIA TOTAL: $mem_total M" $FCYN
cecho "---------------------------------------------" $FRED
cecho "¿Está de acuerdo con estos datos? (s/n)" $FYEL
read ok
if ! [ "$ok" == "s" ] && ! [ "$ok" == "" ]
then cecho "Programa cancelado, modifique los valores desde el .txt y reinicie." $FRED
     exit 0
fi
cecho "---------------------------------------------" $FRED



echo "Estos son los datos de partida:" >> informebn.txt
printf "\n" >> informebn.txt

echo "-----------------------------------------------------------------" >> informebn.txt
echo "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |" >> informebn.txt
echo "-----------------------------------------------------------------" >> informebn.txt

   for (( i=0; i<$nprocesos; i++))
   do
	printf "|\t${procesos[$i]}\t|\t${entradas[$i]}\t|\t${ejecucion[$i]}\t|\t${tamemory[$i]}\t|\n" >> informebn.txt
   done
echo "-----------------------------------------------------------------" >> informebn.txt

printf "\n\n" >> informebn.txt

echo "MEMORIA TOTAL: $mem_total M" >> informebn.txt
echo "---------------------------------------------" >> informebn.txt




cecho "Estos son los datos de partida:" >> informecolor.txt $FBLE
printf "\n" >> informebn.txt

cecho "-----------------------------------------------------------------" >> informecolor.txt $FYEL
cecho "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |" >> informecolor.txt $FYEL
cecho "-----------------------------------------------------------------" >> informecolor.txt $FYEL

   for (( i=0; i<$nprocesos; i++))
   do
	printf "|\t${procesos[$i]}\t|\t${entradas[$i]}\t|\t${ejecucion[$i]}\t|\t${tamemory[$i]}\t|\n" >> informecolor.txt
   done
echo "-----------------------------------------------------------------" >> informecolor.txt

printf "\n\n" >> informecolor.txt

cecho "MEMORIA TOTAL: $mem_total M" >> informecolor.txt $FCYN
cecho "---------------------------------------------" >> informecolor.txt $FRED

}

#--------------------------------------------------------------------------
#                        FUNCIÓN READFILEALEATORIO2						
#--------------------------------------------------------------------------

function readfilealeatorio2 {
	OIFS=$IFS               #Guardamos el separador de campos inicial
IFS=":"                 #Carácter que separa los campos en el fichero
n=-1
nprocesos=0
mem_total=0
    coloresTemp[0]=$FRED
    coloresTemp[1]=$FGRN
    coloresTemp[2]=$FYEL
    coloresTemp[3]=$FBLE
    coloresTemp[4]=$FMAG
    coloresTemp[5]=$FCYN
    coloresTemp[6]=$FRED
    coloresTemp[7]=$FGRN
    coloresTemp[8]=$FYEL
    coloresTemp[9]=$FBLE
    coloresTemp[10]=$FMAG
    coloresTemp[11]=$FCYN
    coloresTemp[12]=$FRED
    coloresTemp[13]=$FGRN
    coloresTemp[14]=$FYEL
    coloresTemp[15]=$FBLE
    coloresTemp[16]=$FMAG
    coloresTemp[17]=$FCYN
    coloresTemp[18]=$FRED
    coloresTemp[19]=$FGRN
    coloresTemp[20]=$FYEL


while read line; do
     # Convertimos el registro leído en un array
     lineArray=($line)

     # Guardamos cada campo en su array correspondiente
     if [[ $n -eq -1 ]]; then
         mem_total=${lineArray[0]}
         mem_total1=${lineArray[0]}
     else
     entradas[$n]=${lineArray[0]}
     ejecucion[$n]=${lineArray[1]}
     tamemory[$n]=${lineArray[2]}
     entradas1[$n]=${lineArray[0]}
     ejecucion1[$n]=${lineArray[1]}
     tamemory1[$n]=${lineArray[2]}
     fi

     if ! [[ $n -eq -1 ]]; then
        nprocesos=$(( $nprocesos + 1 ))
        temp=$(( n + 1 ))
        if [[ $nprocesos -lt 10 ]]; then
          procesos[$n]="P0"$temp      # Los procesos se llamarán P01, P02,...
       else
          procesos[$n]="P"$temp      # Los procesos se llamarán P10, P11, P12,...
       fi
     fi
     n=$(( $n + 1  ))
done < $guardarFicheroAleatorio

nprocesos=$n
pcounter=$(( $nprocesos - 1 ))
IFS=$OIFS               # Recuperamos el separador de campos inicial


for(( i=0; i<$nprocesos; i++)) #Copia de todas las listas para luego ponerlas en orden
do
  numeroProcesos[$i]=$i
  ordenEntrada[$i]=${procesos[$i]}
  entradaAuxiliar[$i]=${entradas[$i]}
  ejecucionAuxiliar[$i]=${ejecucion[$i]}
  tamemoryAuxiliar[$i]=${tamemory[$i]}
  encola[$i]=0
    enmemoria[$i]=0
    enejecucion[$i]=0
    bloqueados[$i]=0
    pausados[$i]=0
    terminados[$i]=0
    nollegado[$i]=0
    estado[$i]=0
    temp_wait[$i]=0
    temp_resp[$i]=0
    temp_ret[$i]=0
done



for (( i=0; i<$nprocesos; i++ )) #Bucle que reordena por tiempo de llegada todos los arrays.
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
      if [[ ${entradaAuxiliar[$j]} -le ${entradaAuxiliar[$i]} ]] ; then #Probar con -ge si falla
    if [[ ${ordenEntrada[$j]} -lt ${ordenEntrada[$i]} ]] ; then #Probar con -gt si falla
            auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
    auxiliar1=${ordenEntrada[$i]}
    auxiliar2=${entradaAuxiliar[$i]}
    auxiliar3=${ejecucionAuxiliar[$i]}
    auxiliar4=${tamemoryAuxiliar[$i]}
    auxiliar5=${encola[$i]}
    auxiliar6=${enmemoria[$i]}
    auxiliar7=${enejecucion[$i]}
    auxiliar8=${bloqueados[$i]}
    auxiliar9=${numeroProcesos[$i]}
    ordenEntrada[$i]=${ordenEntrada[$j]}
    entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
    ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
    tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
    encola[$i]=${encola[$j]}
    enmemoria[$i]=${enmemoria[$j]}
    enejecucion[$i]=${enejecucion[$j]}
    bloqueados[$i]=${bloqueados[$j]}
    numeroProcesos[$i]=${numeroProcesos[$j]}
    ordenEntrada[$j]=$auxiliar1
    entradaAuxiliar[$j]=$auxiliar2
    ejecucionAuxiliar[$j]=$auxiliar3
    tamemoryAuxiliar[$j]=$auxiliar4
    encola[$j]=$auxiliar5
    enmemoria[$j]=$auxiliar6
    enejecucion[$j]=$auxiliar7
    bloqueados[$j]=$auxiliar8
    numeroProcesos[$j]=$auxiliar9
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
   if [[ ${entradaAuxiliar[$i]} -eq ${entradaAuxiliar[$j]} ]] ; then
    if [[ ${numeroProcesos[$i]} -gt ${numeroProcesos[$j]} ]] ; then
        auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
fi
done
done

for (( i=0; i<$nprocesos; i++ ))
do
 tejecucion[$i]=${ejecucionAuxiliar[$i]}
done

for (( i = 0; i < ${#ordenEntrada[@]}; i++ )); do
  if [[ "${ordenEntrada[$i]}" == "P01" ]]; then
    colores[$i]="${coloresTemp[1]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P02" ]]; then
    colores[$i]="${coloresTemp[2]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P03" ]]; then
    colores[$i]="${coloresTemp[3]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P04" ]]; then
    colores[$i]="${coloresTemp[4]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P05" ]]; then
    colores[$i]="${coloresTemp[5]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P06" ]]; then
    colores[$i]="${coloresTemp[6]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P07" ]]; then
    colores[$i]="${coloresTemp[7]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P08" ]]; then
    colores[$i]="${coloresTemp[8]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P09" ]]; then
    colores[$i]="${coloresTemp[9]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P10" ]]; then
    colores[$i]="${coloresTemp[10]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P11" ]]; then
    colores[$i]="${coloresTemp[11]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P12" ]]; then
    colores[$i]="${coloresTemp[12]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P13" ]]; then
    colores[$i]="${coloresTemp[13]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P14" ]]; then
    colores[$i]="${coloresTemp[14]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P15" ]]; then
    colores[$i]="${coloresTemp[15]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P16" ]]; then
    colores[$i]="${coloresTemp[16]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P17" ]]; then
    colores[$i]="${coloresTemp[17]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P18" ]]; then
    colores[$i]="${coloresTemp[18]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P19" ]]; then
    colores[$i]="${coloresTemp[19]}"
  fi
done

blanco="\e[37m"

mem_libre=$mem_total
mem_aux=$mem_libre






printf "\n"
cecho "Estos son los datos de partida:" $FBLE
printf "\n"
printf "\n" >> informecolor.txt
cecho "Estos son los datos de partida:" >> informecolor.txt $FBLE
printf "\n" >> informecolor.txt
printf "\n" >> informebn.txt
cecho "Estos son los datos de partida:" >> informebn.txt
printf "\n" >> informebn.txt

#####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll  Tej  Mem" $FYEL

for (( i=0; i<$n; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n"
      done


printf "\n\n"

cecho "MEMORIA TOTAL: $mem_total M" $FCYN
cecho "---------------------------------------------" $FRED
cecho "¿Está de acuerdo con estos datos? (s/n)" $FYEL
read ok
if ! [ "$ok" == "s" ] && ! [ "$ok" == "" ]
then cecho "Programa cancelado, modifique los valores desde el .txt y reinicie." $FRED
     exit 0
fi
cecho "---------------------------------------------" $FRED



echo "Estos son los datos de partida:" >> informebn.txt
printf "\n" >> informebn.txt

echo "-----------------------------------------------------------------" >> informebn.txt
echo "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |" >> informebn.txt
echo "-----------------------------------------------------------------" >> informebn.txt

   for (( i=0; i<$nprocesos; i++))
   do
	printf "|\t${procesos[$i]}\t|\t${entradas[$i]}\t|\t${ejecucion[$i]}\t|\t${tamemory[$i]}\t|\n" >> informebn.txt
   done
echo "-----------------------------------------------------------------" >> informebn.txt

printf "\n\n" >> informebn.txt

echo "MEMORIA TOTAL: $mem_total M" >> informebn.txt
echo "---------------------------------------------" >> informebn.txt




cecho "Estos son los datos de partida:" >> informecolor.txt $FBLE
printf "\n" >> informebn.txt

cecho "-----------------------------------------------------------------" >> informecolor.txt $FYEL
cecho "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |" >> informecolor.txt $FYEL
cecho "-----------------------------------------------------------------" >> informecolor.txt $FYEL

   for (( i=0; i<$nprocesos; i++))
   do
	printf "|\t${procesos[$i]}\t|\t${entradas[$i]}\t|\t${ejecucion[$i]}\t|\t${tamemory[$i]}\t|\n" >> informecolor.txt
   done
echo "-----------------------------------------------------------------" >> informecolor.txt

printf "\n\n" >> informecolor.txt

cecho "MEMORIA TOTAL: $mem_total M" >> informecolor.txt $FCYN
cecho "---------------------------------------------" >> informecolor.txt $FRED

}

#--------------------------------------------------------------------------
#                        FUNCIÓN READPROCESOS					
#--------------------------------------------------------------------------

function readprocesos {
	
   n=-1
   blanco="\e[37m"
   col=1
   aux=0
   continuar="s"
   nprocesos=1
   pcounter=0 # Variable para controlar el numero de iteracciones que llevamos, y asi poder asignar el P0n
   cecho "Introduzca el tamaño total de la memoria" $FYEL
   echo "Introduzca el tamaño total de la memoria" >> informebn.txt
   cecho "Introduzca el tamaño total de la memoria" $FYEL >> informecolor.txt
   read mem_total
   echo "$mem_total" >> informebn.txt
   echo "$mem_total" >> informecolor.txt
   while ! [[ $mem_total =~ ^[0-9]+$ ]]
   do
       cecho "Tiene que ser un valor entero" $FRED
       echo "Tiene que ser un valor entero" >> informebn.txt
       cecho "Tiene que ser un valor entero" $FRED >> informecolor.txt
       read mem_total
       echo "$mem_total" >> informebn.txt                                              
       echo "$mem_total" >> informecolor.txt
   done

   clear


    ############ PONEMOS LOS COLORES, SEGURO QUE HAY UNA IMPLEMENTACION MEJOR, PERO ESTAMOS EN MAYO Y NO COMO PARA PERDER EL TIEMPO

#for (( i = 30; i < 38; i++ )); do echo -e "\033[0;"$i"m Normal: (0;$i); \033[1;"$i"m Light: (1;$i)"; done
    coloresTemp[0]=$FRED
    coloresTemp[1]=$FGRN
    coloresTemp[2]=$FYEL
    coloresTemp[3]=$FBLE
    coloresTemp[4]=$FMAG
    coloresTemp[5]=$FCYN
    coloresTemp[6]=$FRED
    coloresTemp[7]=$FGRN
    coloresTemp[8]=$FYEL
    coloresTemp[9]=$FBLE
    coloresTemp[10]=$FMAG
    coloresTemp[11]=$FCYN
    coloresTemp[12]=$FRED
    coloresTemp[13]=$FGRN
    coloresTemp[14]=$FYEL
    coloresTemp[15]=$FBLE
    coloresTemp[16]=$FMAG
    coloresTemp[17]=$FCYN
    coloresTemp[18]=$FRED
    coloresTemp[19]=$FGRN
    coloresTemp[20]=$FYEL



   while [[ $continuar = s ]]
   do
      pcounter=$(( $nprocesos - 1 ))
       n=$(( $n + 1 ))
       
       
       
   
       
      
        #####################################################################################
        #  C A B E C E R A
        #####################################################################################
          cecho " Ref Tll Tej Mem" $FYEL
          echo " Ref Tll Tej Mem" >> informebn.txt
          cecho " Ref Tll Tej Mem" $FYEL >> informecolor.txt

  for (( i=1; i<$n+2; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
        printf " ${ordenEntrada[$i]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n" >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n" >> informecolor.txt
      done
  if [[ $[ nprocesos - 1 ] -gt 0 ]]; then
    if [[ $nprocesos -lt 10 ]]; then
     cecho " P0$nprocesos   "    $FWHT
     echo " P0$nprocesos   "    >> informebn.txt
     cecho " P0$nprocesos   "    $FWHT >> informecolor.txt
   else 
     cecho " P$nprocesos    "  $FWHT
     echo " P$nprocesos   "    >> informebn.txt
     cecho " P$nprocesos   "    $FWHT >> informecolor.txt
    fi

  fi
     
  

      
       cecho "Tiempo de llegada del proceso $[ n + 1 ]" $FYEL
       echo "Tiempo de llegada del proceso $[ n + 1 ]" >> informebn.txt
       cecho "Tiempo de llegada del proceso $[ n + 1 ]" $FYEL >> informecolor.txt
       read entrada
       echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt

       while ! [[ $entrada =~ ^[0-9]+$ ]]
       do
  	cecho "Tiene que ser un valor entero" $FRED
    echo "Tiene que ser un valor entero" >> informebn.txt
    cecho "Tiene que ser un valor entero" $FRED >> informecolor.txt
  	read entrada
    echo "$entrada" >> informebn.txt
    echo "$entrada" >> informecolor.txt
       done

       entradas[$n]=$entrada
       if [[ $nprocesos -lt 10 ]]; then
          procesos[$n]="P0"$[ n + 1 ]       # Los procesos se llamarán P01, P02,...
       else
          procesos[$n]="P"$[n + 1 ]       # Los procesos se llamarán P10, P11, P12,...
       fi

      
  clear

 #####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll Tej Mem" $FYEL

  for (( i=1; i<$n+2; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
        printf " ${ordenEntrada[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n"  >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n"  >> informecolor.txt
      done
      printf " $blanco${procesos[-1]}" 
        printf " "
        printf "%3s" "${entradas[-1]}" 
        printf "\n" 
       cecho "Tiempo de ejecución del proceso $[ n + 1 ]" $FYEL
       printf " ${procesos[-1]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradas[-1]}" >> informebn.txt
        printf "\n" >> informebn.txt
       echo "Tiempo de ejecución del proceso $[ n + 1 ]" >> informebn.txt
       printf " $blanco${procesos[-1]}" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradas[-1]}"  >> informecolor.txt
        printf "\n"  >> informecolor.txt
       cecho "Tiempo de ejecución del proceso $[ n + 1 ]" $FYEL >> informecolor.txt
       read entrada
       echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt
       while ! [[ $entrada =~ ^[0-9]+$ ]]
       do
  	cecho "Tiene que ser un valor entero" $FRED
     echo "Tiene que ser un valor entero" >> informebn.txt
    cecho "Tiene que ser un valor entero" $FRED >> informecolor.txt
  	read entrada
           echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt
       done

       ejecucion[$n]=$entrada
  clear

#####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll Tej Mem" $FYEL

  for (( i=1; i<$n+2; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
        printf " ${ordenEntrada[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n"  >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n"  >> informecolor.txt
      done
            printf " ${procesos[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradas[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${ejecucion[-1]}"  >> informebn.txt
        printf "\n"  >> informebn.txt
      printf " $blanco${procesos[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradas[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${ejecucion[-1]}"  >> informebn.txt
        printf "\n"  >> informebn.txt
            printf " $blanco${procesos[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradas[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${ejecucion[-1]}"  >> informecolor.txt
        printf "\n"  >> informecolor.txt



       cecho "Cantidad de memoria que ocupa el proceso $[ n + 1 ]" $FYEL
       echo "Cantidad de memoria que ocupa el proceso $[ n + 1 ]" >> informebn.txt
       cecho "Cantidad de memoria que ocupa el proceso $[ n + 1 ]" $FYEL >> informecolor.txt
       read entrada
              echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt
       while ! [[ $entrada =~ ^[0-9]+$ ]]
       do
  	cecho "Tiene que ser un valor entero" $FRED
  	read entrada
           echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt
       done

       tamemory[$n]=$entrada
  clear

#####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll Tej Mem" $FYEL

for (( i=0; i<$n+1; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
                printf " ${ordenEntrada[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n"  >> informebn.txt
                printf " ${colores[$i]}${ordenEntrada[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n"  >> informecolor.txt
      done
        printf " $blanco${procesos[-1]}" 
        printf " "
        printf "%3s" "${entradas[-1]}" 
        printf " "
        printf "%3s" "${ejecucion[-1]}" 
        printf " "
        printf "%3s" "${tamemory[-1]}"
        printf "\n" 
        printf " ${procesos[-1]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradas[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${ejecucion[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemory[-1]}" >> informebn.txt
        printf "\n" >> informebn.txt
        printf " $blanco${procesos[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradas[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${ejecucion[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemory[-1]}" >> informecolor.txt
        printf "\n" >> informecolor.txt


###################################################################################
# GUARDADO EN FICHERO
###################################################################################
                                     
              #Si el usuario escoge la opción 1
                                                     
>  datos.txt

for (( i=0; i<$n+1; i++ ))
  do
     if [[ $i -eq 0 ]] ; then
        echo "$mem_total" >> datos.txt #entrada.txt
        echo "${entradas[$i]}:${ejecucion[$i]}:${tamemory[$i]}" >>  datos.txt  #entrada.txt
     else
        echo "${entradas[$i]}:${ejecucion[$i]}:${tamemory[$i]}" >> datos.txt #entrada.txt
     fi
  done
############

    cecho "¿Continuar introduciendo procesos? (s/n)" $FYEL
       echo "¿Continuar introduciendo procesos? (s/n)" >> informebn.txt
       cecho "¿Continuar introduciendo procesos? (s/n)" $FYEL >> informecolor.txt
       read continuar
       while ! [[ $continuar =~ ^[sn]$ ]]
       do
  	cecho "Error, introduzca otra vez (s/n)" $FRED
    echo "Error, introduzca otra vez (s/n)" >> informebn.txt
    cecho "Error, introduzca otra vez (s/n)" $FRED >> informecolor.txt
  	read continuar
    echo "$continuar" >> informebn.txt
    echo "$continuar" >> informecolor.txt
       done
  echo "Hay $nprocesos procesos"
  echo "Hay $nprocesos procesos" >> informebn.txt
  echo "Hay $nprocesos procesos" >> informecolor.txt

  	if [ $continuar = s ]
  	then
  	   nprocesos=$(( $nprocesos + 1 ))
  	fi
  	clear

       #ASIGNAMOS UN COLOR
       colores[$nprocesos-1]=${coloresTemp[$nprocesos-1]}







##########################################################################################################
#
#       ORDENAR PROCESOS SEGUN TIEMPO DE LLEGADA

        for(( i=0; i<$nprocesos; i++)) #Copia de todas las listas para luego ponerlas en orden
do
  numeroProcesos[$i]=$i
  ordenEntrada[$i]=${procesos[$i]}
  entradaAuxiliar[$i]=${entradas[$i]}
  ejecucionAuxiliar[$i]=${ejecucion[$i]}
  tamemoryAuxiliar[$i]=${tamemory[$i]}
  encola[$i]=0
    enmemoria[$i]=0
    enejecucion[$i]=0
    bloqueados[$i]=0
    pausados[$i]=0
    terminados[$i]=0
    nollegado[$i]=0
    estado[$i]=0
    temp_wait[$i]=0
    temp_resp[$i]=0
    temp_ret[$i]=0
done



for (( i=0; i<$nprocesos; i++ )) #Bucle que reordena por tiempo de llegada todos los arrays.
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
      if [[ ${entradaAuxiliar[$j]} -le ${entradaAuxiliar[$i]} ]] ; then #Probar con -ge si falla
    if [[ ${ordenEntrada[$j]} -lt ${ordenEntrada[$i]} ]] ; then #Probar con -gt si falla
            auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
    auxiliar1=${ordenEntrada[$i]}
    auxiliar2=${entradaAuxiliar[$i]}
    auxiliar3=${ejecucionAuxiliar[$i]}
    auxiliar4=${tamemoryAuxiliar[$i]}
    auxiliar5=${encola[$i]}
    auxiliar6=${enmemoria[$i]}
    auxiliar7=${enejecucion[$i]}
    auxiliar8=${bloqueados[$i]}
    auxiliar9=${numeroProcesos[$i]}
    ordenEntrada[$i]=${ordenEntrada[$j]}
    entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
    ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
    tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
    encola[$i]=${encola[$j]}
    enmemoria[$i]=${enmemoria[$j]}
    enejecucion[$i]=${enejecucion[$j]}
    bloqueados[$i]=${bloqueados[$j]}
    numeroProcesos[$i]=${numeroProcesos[$j]}
    ordenEntrada[$j]=$auxiliar1
    entradaAuxiliar[$j]=$auxiliar2
    ejecucionAuxiliar[$j]=$auxiliar3
    tamemoryAuxiliar[$j]=$auxiliar4
    encola[$j]=$auxiliar5
    enmemoria[$j]=$auxiliar6
    enejecucion[$j]=$auxiliar7
    bloqueados[$j]=$auxiliar8
    numeroProcesos[$j]=$auxiliar9
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
   if [[ ${entradaAuxiliar[$i]} -eq ${entradaAuxiliar[$j]} ]] ; then
    if [[ ${numeroProcesos[$i]} -gt ${numeroProcesos[$j]} ]] ; then
        auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 tejecucion[$i]=${ejecucionAuxiliar[$i]}
done

# for (( i = 0; i < 20; i++ )); do
#   echo "$i -> ${procesos[$i]} - ${ordenEntrada[$i]}"
# done
# for (( i = 0; i < ${#colores[@]}; i++ )); do
#   colTemp[$i]="${colores[$i]}"
# done

# for (( i = 1; i < ${#ordenEntrada[@]}; i++ )); do
#   for (( i = 1; i < ${#ordenEntrada[@]}; i++ )); do
#     if [[ "${procesos[$i-1]}" == "${ordenEntrada[$j]}" ]]; then
#       colores[$j]="${colTemp[$i]}"
#     fi
#   done
# done

for (( i = 1; i < ${#ordenEntrada[@]}; i++ )); do
  if [[ "${ordenEntrada[$i]}" == "P01" ]]; then
    colores[$i]="${coloresTemp[1]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P02" ]]; then
    colores[$i]="${coloresTemp[2]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P03" ]]; then
    colores[$i]="${coloresTemp[3]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P04" ]]; then
    colores[$i]="${coloresTemp[4]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P05" ]]; then
    colores[$i]="${coloresTemp[5]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P06" ]]; then
    colores[$i]="${coloresTemp[6]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P07" ]]; then
    colores[$i]="${coloresTemp[7]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P08" ]]; then
    colores[$i]="${coloresTemp[8]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P09" ]]; then
    colores[$i]="${coloresTemp[9]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P10" ]]; then
    colores[$i]="${coloresTemp[10]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P11" ]]; then
    colores[$i]="${coloresTemp[11]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P12" ]]; then
    colores[$i]="${coloresTemp[12]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P13" ]]; then
    colores[$i]="${coloresTemp[13]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P14" ]]; then
    colores[$i]="${coloresTemp[14]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P15" ]]; then
    colores[$i]="${coloresTemp[15]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P16" ]]; then
    colores[$i]="${coloresTemp[16]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P17" ]]; then
    colores[$i]="${coloresTemp[17]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P18" ]]; then
    colores[$i]="${coloresTemp[18]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P19" ]]; then
    colores[$i]="${coloresTemp[19]}"
  fi
done






blanco="\e[37m"

mem_libre=$mem_total
mem_aux=$mem_libre


done
for (( i = 0; i < ${#ordenEntrada[@]}; i++ )); do
  if [[ "${ordenEntrada[$i]}" == "P01" ]]; then
    colores[$i]="${coloresTemp[1]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P02" ]]; then
    colores[$i]="${coloresTemp[2]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P03" ]]; then
    colores[$i]="${coloresTemp[3]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P04" ]]; then
    colores[$i]="${coloresTemp[4]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P05" ]]; then
    colores[$i]="${coloresTemp[5]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P06" ]]; then
    colores[$i]="${coloresTemp[6]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P07" ]]; then
    colores[$i]="${coloresTemp[7]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P08" ]]; then
    colores[$i]="${coloresTemp[8]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P09" ]]; then
    colores[$i]="${coloresTemp[9]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P10" ]]; then
    colores[$i]="${coloresTemp[10]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P11" ]]; then
    colores[$i]="${coloresTemp[11]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P12" ]]; then
    colores[$i]="${coloresTemp[12]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P13" ]]; then
    colores[$i]="${coloresTemp[13]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P14" ]]; then
    colores[$i]="${coloresTemp[14]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P15" ]]; then
    colores[$i]="${coloresTemp[15]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P16" ]]; then
    colores[$i]="${coloresTemp[16]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P17" ]]; then
    colores[$i]="${coloresTemp[17]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P18" ]]; then
    colores[$i]="${coloresTemp[18]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P19" ]]; then
    colores[$i]="${coloresTemp[19]}"
  fi
done

  # -----------------------------------------------------------------------------
  #  Mostramos los datos cargados y pedimos confirmación
  #  para realizar el proceso
  # -----------------------------------------------------------------------------
  printf "\n"
  cecho "Estos son los datos de partida:" $FBLE
  printf "\n"

  #####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " REF  TLL  TEJ  MEM" $FYEL

  for (( i=0; i<$n+1; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf "  "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf "  "
        printf "%3s" "${tejecucion[$i]}" 
        printf "  "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
      done


  printf "\n\n"
  cecho "MEMORIA TOTAL: $mem_total M" $FCYN
  cecho "---------------------------------------------" $FRED
  cecho "¿Está de acuerdo con estos datos? (s/n)" $FYEL
  read ok
  if ! [ "$ok" == "s" ] && ! [ "$ok" == "" ]
  then cecho "Programa cancelado, reinicie" $FRED
       exit 0
  fi
  cecho "---------------------------------------------" $FRED

  # -----------------------------------------------------------------------------
  #         VALIDACIÓN DE LOS DATOS DE ENTRADA
  # (COMPROBAR QUE TODOS LOS PROCESOS OCUPAN MENOS QUE EL TAMAÑO TOTAL)
  # -----------------------------------------------------------------------------
  #  Comprobamos que con los datos de los procesos a ejecutar, no tengamos uno
  #  cuya memoria sea mayor que el tamaño de la partición más grande definida
  # -----------------------------------------------------------------------------
  contador=0

  for (( contador=0; contador <= nprocesos; ++contador )) #Bucle que comprueba que todos los tamaños de memoria de los procesos son menores que la memoria total.
  do
     while [[ ${tamemory[$contador]} -gt $mem_total ]]
     do
  	cecho " El proceso $contador no cabe en memoria. Vuelva a introducir datos." $FRED
    echo " El proceso $contador no cabe en memoria. Vuelva a introducir datos." >> informebn.txt
    cecho " El proceso $contador no cabe en memoria. Vuelva a introducir datos." $FRED >> informecolor.txt
  	echo " Introduzca un nuevo valor para la memoria que va a ocupar el P$contador . "
    echo " Introduzca un nuevo valor para la memoria que va a ocupar el P$contador . " >> informebn.txt
    echo " Introduzca un nuevo valor para la memoria que va a ocupar el P$contador . " >> informecolor.txt
  	read tamemory[$contador]
    echo "${tamemory[$contador]}" >> informebn.txt
    echo "${tamemory[$contador]}" >> informecolor.txt
    done
    done

  	#Permite la modificacion del tamaño de la memoria de dicho proceso

#####################################################################################
#  C A B E C E R A
#####################################################################################
  # cecho " Ref Tll Tej  Mem" $FYEL

  # for (( i=0; i<$n+2; i++ ))
  # do
  #       printf " ${ordenEntrada[$i]}" 
  #       printf " "
  #       printf "%3s" "${entradaAuxiliar[$i]}" 
  #       printf " "
  #       printf "%3s" "${tejecucion[$i]}" 
  #       printf " "
  #       printf "%3s" "${tamemoryAuxiliar[$i]}"
  #       printf "\n" 
  # done

  # 		printf "\n\n"
  # 		cecho "MEMORIA TOTAL: $mem_total M" $FCYN
  # 		cecho "---------------------------------------------" $FRED
  #    done
  # done

  #------------------------------------------------------------
  # Movemos los datos de ejecución al fichero resumen de salida
  #------------------------------------------------------------

  echo "------------------------------------------------" >> informebn.txt
  echo "-                R E S U M E N                 -" >> informebn.txt
  echo "------------------------------------------------" >> informebn.txt
  echo "Estos son los datos de partida:" >> informebn.txt
  printf "\n" >> informebn.txt

  cecho " Ref Tll Tej Mem" >> informebn.txt

  for (( i=0; i<$nprocesos; i++ )) 
  do
        printf " ${ordenEntrada[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n"  >> informebn.txt
  done


  printf "\n\n" >> informebn.txt
  echo "MEMORIA TOTAL: $mem_total M" >> informebn.txt
  echo "---------------------------------------------" >> informebn.txt


  cecho "------------------------------------------------" >> informecolor.txt $FBLE
  cecho "-                R E S U M E N                 -" >> informecolor.txt $FBLE
  cecho "------------------------------------------------" >> informecolor.txt $FBLE
  cecho "Estos son los datos de partida:" >> informecolor.txt $FCYN
  printf "\n" >> informecolor.txt

  cecho " Ref Tll Tej Mem" $FYEL >> informecolor.txt

  for (( i=0; i<$nprocesos; i++ )) 
  do
        printf " ${colores[$i]}${ordenEntrada[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n"  >> informecolor.txt
  done
  echo "-----------------------------------------------------------------" >> informecolor.txt

  printf "\n\n"
  cecho "MEMORIA TOTAL: $mem_total M" >> informecolor.txt $FCYN
  cecho "---------------------------------------------" >> informecolor.txt $FRED



  cecho "Datos correctos. Comienza." $FYEL
  echo "Datos correctos. Comienza." >> informebn.txt
  cecho "Datos correctos. Comienza." $FYEL >> informecolor.txt

}


#--------------------------------------------------------------------------
#                        FUNCIÓN READPROCESOS OPCIÓN 2					
#--------------------------------------------------------------------------

function readprocesosopcion2 {
	  n=-1
   blanco="\e[37m"
   col=1
   aux=0
   continuar="s"
   nprocesos=1
   pcounter=0 # Variable para controlar el numero de iteracciones que llevamos, y asi poder asignar el P0n
   cecho "Introduzca el tamaño total de la memoria" $FYEL
   echo "Introduzca el tamaño total de la memoria" >> informebn.txt
   cecho "Introduzca el tamaño total de la memoria" $FYEL >> informecolor.txt
   read mem_total
   echo "$mem_total" >> informebn.txt
   echo "$mem_total" >> informecolor.txt
   while ! [[ $mem_total =~ ^[0-9]+$ ]]
   do
       cecho "Tiene que ser un valor entero" $FRED
       echo "Tiene que ser un valor entero" >> informebn.txt
       cecho "Tiene que ser un valor entero" $FRED >> informecolor.txt
       read mem_total
       echo "$mem_total" >> informebn.txt                                              
       echo "$mem_total" >> informecolor.txt
   done

   clear


    ############ PONEMOS LOS COLORES, SEGURO QUE HAY UNA IMPLEMENTACION MEJOR, PERO ESTAMOS EN MAYO Y NO COMO PARA PERDER EL TIEMPO

#for (( i = 30; i < 38; i++ )); do echo -e "\033[0;"$i"m Normal: (0;$i); \033[1;"$i"m Light: (1;$i)"; done
    coloresTemp[0]=$FRED
    coloresTemp[1]=$FGRN
    coloresTemp[2]=$FYEL
    coloresTemp[3]=$FBLE
    coloresTemp[4]=$FMAG
    coloresTemp[5]=$FCYN
    coloresTemp[6]=$FRED
    coloresTemp[7]=$FGRN
    coloresTemp[8]=$FYEL
    coloresTemp[9]=$FBLE
    coloresTemp[10]=$FMAG
    coloresTemp[11]=$FCYN
    coloresTemp[12]=$FRED
    coloresTemp[13]=$FGRN
    coloresTemp[14]=$FYEL
    coloresTemp[15]=$FBLE
    coloresTemp[16]=$FMAG
    coloresTemp[17]=$FCYN
    coloresTemp[18]=$FRED
    coloresTemp[19]=$FGRN
    coloresTemp[20]=$FYEL



   while [[ $continuar = s ]]
   do
      pcounter=$(( $nprocesos - 1 ))
       n=$(( $n + 1 ))
       
       
       
   
       
      
        #####################################################################################
        #  C A B E C E R A
        #####################################################################################
          cecho " Ref Tll Tej Mem" $FYEL
          echo " Ref Tll Tej Mem" >> informebn.txt
          cecho " Ref Tll Tej Mem" $FYEL >> informecolor.txt

  for (( i=1; i<$n+2; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
        printf " ${ordenEntrada[$i]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n" >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n" >> informecolor.txt
      done
  if [[ $[ nprocesos - 1 ] -gt 0 ]]; then
    if [[ $nprocesos -lt 10 ]]; then
     cecho " P0$nprocesos   "    $FWHT
     echo " P0$nprocesos   "    >> informebn.txt
     cecho " P0$nprocesos   "    $FWHT >> informecolor.txt
   else 
     cecho " P$nprocesos    "  $FWHT
     echo " P$nprocesos   "    >> informebn.txt
     cecho " P$nprocesos   "    $FWHT >> informecolor.txt
    fi

  fi
     
  

      
       cecho "Tiempo de llegada del proceso $[ n + 1 ]" $FYEL
       echo "Tiempo de llegada del proceso $[ n + 1 ]" >> informebn.txt
       cecho "Tiempo de llegada del proceso $[ n + 1 ]" $FYEL >> informecolor.txt
       read entrada
       echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt

       while ! [[ $entrada =~ ^[0-9]+$ ]]
       do
  	cecho "Tiene que ser un valor entero" $FRED
    echo "Tiene que ser un valor entero" >> informebn.txt
    cecho "Tiene que ser un valor entero" $FRED >> informecolor.txt
  	read entrada
    echo "$entrada" >> informebn.txt
    echo "$entrada" >> informecolor.txt
       done

       entradas[$n]=$entrada
       if [[ $nprocesos -lt 10 ]]; then
          procesos[$n]="P0"$[ n + 1 ]       # Los procesos se llamarán P01, P02,...
       else
          procesos[$n]="P"$[n + 1 ]       # Los procesos se llamarán P10, P11, P12,...
       fi

      
  clear

 #####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll Tej Mem" $FYEL

  for (( i=1; i<$n+2; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
        printf " ${ordenEntrada[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n"  >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n"  >> informecolor.txt
      done
      printf " $blanco${procesos[-1]}" 
        printf " "
        printf "%3s" "${entradas[-1]}" 
        printf "\n" 
       cecho "Tiempo de ejecución del proceso $[ n + 1 ]" $FYEL
       printf " ${procesos[-1]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradas[-1]}" >> informebn.txt
        printf "\n" >> informebn.txt
       echo "Tiempo de ejecución del proceso $[ n + 1 ]" >> informebn.txt
       printf " $blanco${procesos[-1]}" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradas[-1]}"  >> informecolor.txt
        printf "\n"  >> informecolor.txt
       cecho "Tiempo de ejecución del proceso $[ n + 1 ]" $FYEL >> informecolor.txt
       read entrada
       echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt
       while ! [[ $entrada =~ ^[0-9]+$ ]]
       do
  	cecho "Tiene que ser un valor entero" $FRED
     echo "Tiene que ser un valor entero" >> informebn.txt
    cecho "Tiene que ser un valor entero" $FRED >> informecolor.txt
  	read entrada
           echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt
       done

       ejecucion[$n]=$entrada
  clear

#####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll Tej Mem" $FYEL

  for (( i=1; i<$n+2; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
        printf " ${ordenEntrada[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n"  >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n"  >> informecolor.txt
      done
            printf " ${procesos[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradas[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${ejecucion[-1]}"  >> informebn.txt
        printf "\n"  >> informebn.txt
      printf " $blanco${procesos[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradas[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${ejecucion[-1]}"  >> informebn.txt
        printf "\n"  >> informebn.txt
            printf " $blanco${procesos[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradas[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${ejecucion[-1]}"  >> informecolor.txt
        printf "\n"  >> informecolor.txt



       cecho "Cantidad de memoria que ocupa el proceso $[ n + 1 ]" $FYEL
       echo "Cantidad de memoria que ocupa el proceso $[ n + 1 ]" >> informebn.txt
       cecho "Cantidad de memoria que ocupa el proceso $[ n + 1 ]" $FYEL >> informecolor.txt
       read entrada
              echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt
       while ! [[ $entrada =~ ^[0-9]+$ ]]
       do
  	cecho "Tiene que ser un valor entero" $FRED
  	read entrada
           echo "$entrada" >> informebn.txt
       echo "$entrada" >> informecolor.txt
       done

       tamemory[$n]=$entrada
  clear

#####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " Ref Tll Tej Mem" $FYEL

for (( i=0; i<$n+1; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf " "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf " "
        printf "%3s" "${tejecucion[$i]}" 
        printf " "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
                printf " ${ordenEntrada[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n"  >> informebn.txt
                printf " ${colores[$i]}${ordenEntrada[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n"  >> informecolor.txt
      done
        printf " $blanco${procesos[-1]}" 
        printf " "
        printf "%3s" "${entradas[-1]}" 
        printf " "
        printf "%3s" "${ejecucion[-1]}" 
        printf " "
        printf "%3s" "${tamemory[-1]}"
        printf "\n" 
        printf " ${procesos[-1]}" >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradas[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${ejecucion[-1]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemory[-1]}" >> informebn.txt
        printf "\n" >> informebn.txt
        printf " $blanco${procesos[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradas[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${ejecucion[-1]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemory[-1]}" >> informecolor.txt
        printf "\n" >> informecolor.txt


###################################################################################
# GUARDADO EN FICHERO
###################################################################################
                                     
              #Si el usuario escoge la opción 1
                                                     
>  $guardarFichero

for (( i=0; i<$n+1; i++ ))
  do
     if [[ $i -eq 0 ]] ; then
        echo "$mem_total" >> $guardarFichero #entrada.txt
        echo "${entradas[$i]}:${ejecucion[$i]}:${tamemory[$i]}" >>  $guardarFichero  #entrada.txt
     else
        echo "${entradas[$i]}:${ejecucion[$i]}:${tamemory[$i]}" >> $guardarFichero #entrada.txt
     fi
  done
############

    cecho "¿Continuar introduciendo procesos? (s/n)" $FYEL
       echo "¿Continuar introduciendo procesos? (s/n)" >> informebn.txt
       cecho "¿Continuar introduciendo procesos? (s/n)" $FYEL >> informecolor.txt
       read continuar
       while ! [[ $continuar =~ ^[sn]$ ]]
       do
  	cecho "Error, introduzca otra vez (s/n)" $FRED
    echo "Error, introduzca otra vez (s/n)" >> informebn.txt
    cecho "Error, introduzca otra vez (s/n)" $FRED >> informecolor.txt
  	read continuar
    echo "$continuar" >> informebn.txt
    echo "$continuar" >> informecolor.txt
       done
  echo "Hay $nprocesos procesos"
  echo "Hay $nprocesos procesos" >> informebn.txt
  echo "Hay $nprocesos procesos" >> informecolor.txt

  	if [ $continuar = s ]
  	then
  	   nprocesos=$(( $nprocesos + 1 ))
  	fi
  	clear

       #ASIGNAMOS UN COLOR
       colores[$nprocesos-1]=${coloresTemp[$nprocesos-1]}







##########################################################################################################
#
#       ORDENAR PROCESOS SEGUN TIEMPO DE LLEGADA

        for(( i=0; i<$nprocesos; i++)) #Copia de todas las listas para luego ponerlas en orden
do
  numeroProcesos[$i]=$i
  ordenEntrada[$i]=${procesos[$i]}
  entradaAuxiliar[$i]=${entradas[$i]}
  ejecucionAuxiliar[$i]=${ejecucion[$i]}
  tamemoryAuxiliar[$i]=${tamemory[$i]}
  encola[$i]=0
    enmemoria[$i]=0
    enejecucion[$i]=0
    bloqueados[$i]=0
    pausados[$i]=0
    terminados[$i]=0
    nollegado[$i]=0
    estado[$i]=0
    temp_wait[$i]=0
    temp_resp[$i]=0
    temp_ret[$i]=0
done



for (( i=0; i<$nprocesos; i++ )) #Bucle que reordena por tiempo de llegada todos los arrays.
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
      if [[ ${entradaAuxiliar[$j]} -le ${entradaAuxiliar[$i]} ]] ; then #Probar con -ge si falla
    if [[ ${ordenEntrada[$j]} -lt ${ordenEntrada[$i]} ]] ; then #Probar con -gt si falla
            auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
    auxiliar1=${ordenEntrada[$i]}
    auxiliar2=${entradaAuxiliar[$i]}
    auxiliar3=${ejecucionAuxiliar[$i]}
    auxiliar4=${tamemoryAuxiliar[$i]}
    auxiliar5=${encola[$i]}
    auxiliar6=${enmemoria[$i]}
    auxiliar7=${enejecucion[$i]}
    auxiliar8=${bloqueados[$i]}
    auxiliar9=${numeroProcesos[$i]}
    ordenEntrada[$i]=${ordenEntrada[$j]}
    entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
    ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
    tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
    encola[$i]=${encola[$j]}
    enmemoria[$i]=${enmemoria[$j]}
    enejecucion[$i]=${enejecucion[$j]}
    bloqueados[$i]=${bloqueados[$j]}
    numeroProcesos[$i]=${numeroProcesos[$j]}
    ordenEntrada[$j]=$auxiliar1
    entradaAuxiliar[$j]=$auxiliar2
    ejecucionAuxiliar[$j]=$auxiliar3
    tamemoryAuxiliar[$j]=$auxiliar4
    encola[$j]=$auxiliar5
    enmemoria[$j]=$auxiliar6
    enejecucion[$j]=$auxiliar7
    bloqueados[$j]=$auxiliar8
    numeroProcesos[$j]=$auxiliar9
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
   if [[ ${entradaAuxiliar[$i]} -eq ${entradaAuxiliar[$j]} ]] ; then
    if [[ ${numeroProcesos[$i]} -gt ${numeroProcesos[$j]} ]] ; then
        auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 tejecucion[$i]=${ejecucionAuxiliar[$i]}
done

# for (( i = 0; i < 20; i++ )); do
#   echo "$i -> ${procesos[$i]} - ${ordenEntrada[$i]}"
# done
# for (( i = 0; i < ${#colores[@]}; i++ )); do
#   colTemp[$i]="${colores[$i]}"
# done

# for (( i = 1; i < ${#ordenEntrada[@]}; i++ )); do
#   for (( i = 1; i < ${#ordenEntrada[@]}; i++ )); do
#     if [[ "${procesos[$i-1]}" == "${ordenEntrada[$j]}" ]]; then
#       colores[$j]="${colTemp[$i]}"
#     fi
#   done
# done

for (( i = 1; i < ${#ordenEntrada[@]}; i++ )); do
  if [[ "${ordenEntrada[$i]}" == "P01" ]]; then
    colores[$i]="${coloresTemp[1]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P02" ]]; then
    colores[$i]="${coloresTemp[2]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P03" ]]; then
    colores[$i]="${coloresTemp[3]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P04" ]]; then
    colores[$i]="${coloresTemp[4]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P05" ]]; then
    colores[$i]="${coloresTemp[5]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P06" ]]; then
    colores[$i]="${coloresTemp[6]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P07" ]]; then
    colores[$i]="${coloresTemp[7]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P08" ]]; then
    colores[$i]="${coloresTemp[8]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P09" ]]; then
    colores[$i]="${coloresTemp[9]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P10" ]]; then
    colores[$i]="${coloresTemp[10]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P11" ]]; then
    colores[$i]="${coloresTemp[11]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P12" ]]; then
    colores[$i]="${coloresTemp[12]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P13" ]]; then
    colores[$i]="${coloresTemp[13]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P14" ]]; then
    colores[$i]="${coloresTemp[14]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P15" ]]; then
    colores[$i]="${coloresTemp[15]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P16" ]]; then
    colores[$i]="${coloresTemp[16]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P17" ]]; then
    colores[$i]="${coloresTemp[17]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P18" ]]; then
    colores[$i]="${coloresTemp[18]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P19" ]]; then
    colores[$i]="${coloresTemp[19]}"
  fi
done






blanco="\e[37m"

mem_libre=$mem_total
mem_aux=$mem_libre


done
for (( i = 0; i < ${#ordenEntrada[@]}; i++ )); do
  if [[ "${ordenEntrada[$i]}" == "P01" ]]; then
    colores[$i]="${coloresTemp[1]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P02" ]]; then
    colores[$i]="${coloresTemp[2]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P03" ]]; then
    colores[$i]="${coloresTemp[3]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P04" ]]; then
    colores[$i]="${coloresTemp[4]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P05" ]]; then
    colores[$i]="${coloresTemp[5]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P06" ]]; then
    colores[$i]="${coloresTemp[6]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P07" ]]; then
    colores[$i]="${coloresTemp[7]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P08" ]]; then
    colores[$i]="${coloresTemp[8]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P09" ]]; then
    colores[$i]="${coloresTemp[9]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P10" ]]; then
    colores[$i]="${coloresTemp[10]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P11" ]]; then
    colores[$i]="${coloresTemp[11]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P12" ]]; then
    colores[$i]="${coloresTemp[12]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P13" ]]; then
    colores[$i]="${coloresTemp[13]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P14" ]]; then
    colores[$i]="${coloresTemp[14]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P15" ]]; then
    colores[$i]="${coloresTemp[15]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P16" ]]; then
    colores[$i]="${coloresTemp[16]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P17" ]]; then
    colores[$i]="${coloresTemp[17]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P18" ]]; then
    colores[$i]="${coloresTemp[18]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P19" ]]; then
    colores[$i]="${coloresTemp[19]}"
  fi
done

  # -----------------------------------------------------------------------------
  #  Mostramos los datos cargados y pedimos confirmación
  #  para realizar el proceso
  # -----------------------------------------------------------------------------
  printf "\n"
  cecho "Estos son los datos de partida:" $FBLE
  printf "\n"

  #####################################################################################
#  C A B E C E R A
#####################################################################################
  cecho " REF  TLL  TEJ  MEM" $FYEL

  for (( i=0; i<$n+1; i++ ))
      do
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf "  "
        printf "%3s" "${entradaAuxiliar[$i]}" 
        printf "  "
        printf "%3s" "${tejecucion[$i]}" 
        printf "  "
        printf "%3s" "${tamemoryAuxiliar[$i]}"
        printf "\n" 
      done


  printf "\n\n"
  cecho "MEMORIA TOTAL: $mem_total M" $FCYN
  cecho "---------------------------------------------" $FRED
  cecho "¿Está de acuerdo con estos datos? (s/n)" $FYEL
  read ok
  if ! [ "$ok" == "s" ] && ! [ "$ok" == "" ]
  then cecho "Programa cancelado, reinicie" $FRED
       exit 0
  fi
  cecho "---------------------------------------------" $FRED

  # -----------------------------------------------------------------------------
  #         VALIDACIÓN DE LOS DATOS DE ENTRADA
  # (COMPROBAR QUE TODOS LOS PROCESOS OCUPAN MENOS QUE EL TAMAÑO TOTAL)
  # -----------------------------------------------------------------------------
  #  Comprobamos que con los datos de los procesos a ejecutar, no tengamos uno
  #  cuya memoria sea mayor que el tamaño de la partición más grande definida
  # -----------------------------------------------------------------------------
  contador=0

  for (( contador=0; contador <= nprocesos; ++contador )) #Bucle que comprueba que todos los tamaños de memoria de los procesos son menores que la memoria total.
  do
     while [[ ${tamemory[$contador]} -gt $mem_total ]]
     do
  	cecho " El proceso $contador no cabe en memoria. Vuelva a introducir datos." $FRED
    echo " El proceso $contador no cabe en memoria. Vuelva a introducir datos." >> informebn.txt
    cecho " El proceso $contador no cabe en memoria. Vuelva a introducir datos." $FRED >> informecolor.txt
  	echo " Introduzca un nuevo valor para la memoria que va a ocupar el P$contador . "
    echo " Introduzca un nuevo valor para la memoria que va a ocupar el P$contador . " >> informebn.txt
    echo " Introduzca un nuevo valor para la memoria que va a ocupar el P$contador . " >> informecolor.txt
  	read tamemory[$contador]
    echo "${tamemory[$contador]}" >> informebn.txt
    echo "${tamemory[$contador]}" >> informecolor.txt
    done 
    done

  	#Permite la modificacion del tamaño de la memoria de dicho proceso

#####################################################################################
#  C A B E C E R A
#####################################################################################
  # cecho " Ref Tll Tej  Mem" $FYEL

  # for (( i=0; i<$n+2; i++ ))
  # do
  #       printf " ${ordenEntrada[$i]}" 
  #       printf " "
  #       printf "%3s" "${entradaAuxiliar[$i]}" 
  #       printf " "
  #       printf "%3s" "${tejecucion[$i]}" 
  #       printf " "
  #       printf "%3s" "${tamemoryAuxiliar[$i]}"
  #       printf "\n" 
  # done

  # 		printf "\n\n"
  # 		cecho "MEMORIA TOTAL: $mem_total M" $FCYN
  # 		cecho "---------------------------------------------" $FRED
  #    done
  # done

  #------------------------------------------------------------
  # Movemos los datos de ejecución al fichero resumen de salida
  #------------------------------------------------------------

  echo "------------------------------------------------" >> informebn.txt
  echo "-                R E S U M E N                 -" >> informebn.txt
  echo "------------------------------------------------" >> informebn.txt
  echo "Estos son los datos de partida:" >> informebn.txt
  printf "\n" >> informebn.txt

  cecho " Ref Tll Tej Mem" >> informebn.txt

  for (( i=0; i<$nprocesos; i++ )) 
  do
        printf " ${ordenEntrada[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tejecucion[$i]}"  >> informebn.txt
        printf " " >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "\n"  >> informebn.txt
  done


  printf "\n\n" >> informebn.txt
  echo "MEMORIA TOTAL: $mem_total M" >> informebn.txt
  echo "---------------------------------------------" >> informebn.txt


  cecho "------------------------------------------------" >> informecolor.txt $FBLE
  cecho "-                R E S U M E N                 -" >> informecolor.txt $FBLE
  cecho "------------------------------------------------" >> informecolor.txt $FBLE
  cecho "Estos son los datos de partida:" >> informecolor.txt $FCYN
  printf "\n" >> informecolor.txt

  cecho " Ref Tll Tej Mem" $FYEL >> informecolor.txt

  for (( i=0; i<$nprocesos; i++ )) 
  do
        printf " ${colores[$i]}${ordenEntrada[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "\n"  >> informecolor.txt
  done
  echo "-----------------------------------------------------------------" >> informecolor.txt

  printf "\n\n"
  cecho "MEMORIA TOTAL: $mem_total M" >> informecolor.txt $FCYN
  cecho "---------------------------------------------" >> informecolor.txt $FRED



  cecho "Datos correctos. Comienza." $FYEL
  echo "Datos correctos. Comienza." >> informebn.txt
  cecho "Datos correctos. Comienza." $FYEL >> informecolor.txt

}

#--------------------------------------------------------------------------
#                        FUNCIÓN ALEATORIO						#Esta funcion no se usa, se usa la de abajo que es la misma funcion pero definiendo los rangos el propio usuario 
#--------------------------------------------------------------------------
	 #function crearFicheroAleatorio {			
	#				rm aleatorio.txt
	#				echo "$(seq 26 30 | shuf -n 1)" >> aleatorio.txt
	#				echo "$(seq  0 20 | shuf -n 1):$(shuf -i 10-20 -n 1):$(shuf -i 1-7 -n 1):" >> aleatorio.txt
	#				p=0; while [[ $p -lt 4 ]]; do
	#				e=0; while [[ $e -lt 3 ]]; do
	#		echo -n "$(shuf -i 0-15 -n 1):" >> aleatorio.txt;
	#		e=$((e+1));
	#		done 
	#		p=$((p+1));
	#				echo  "">>aleatorio.txt
	#				done
	#		}
#-----------------------------------------------------------------------------
#				FUNCIÓN TABLA-RESUMEN ALEATORIOS
#-----------------------------------------------------------------------------

function tablaresumen {
	echo ""
	cecho "Resumen" $FYEL
	cecho "-------------------------------------------------------------------------------" $FRED
	cecho "Rango de memoria: $rangoMemoriaMinimo - $rangoMemoriaMaximo | $memoriaresumen" $FYEL
	cecho "Rango de procesos: $rangoProcesosMinimo - $rangoProcesosMaximo | $rangoprocesosresumen" $FYEL
	cecho "Rango de tiempo de llegada: $rangoLlegadaMinimo - $rangoLlegadaMaximo | $rangollegadaresumen" $FYEL
	cecho "Rango de tiempo de ejecución: $rangoTiempoEjMinimo - $rangoTiempoEjMaximo | $rangotiempoejecucionresumen" $FYEL
	cecho "Rango de memoria que ocupa el proceso: $rangoMemoriaProcesoMinimo - $rangoMemoriaProcesoMaximo | $rangomemoriaprocesoresumen" $FYEL
	cecho "-------------------------------------------------------------------------------" $FRED
	
	echo "" >> informecolor.txt
	cecho "Resumen" >> informecolor.txt $FYEL
	cecho "-------------------------------------------------------------------------------" >> informecolor.txt $FRED
	cecho "Rango de memoria: $rangoMemoriaMinimo - $rangoMemoriaMaximo | $memoriaresumen" >> informecolor.txt $FYEL
	cecho "Rango de procesos: $rangoProcesosMinimo - $rangoProcesosMaximo | $rangoprocesosresumen" >> informecolor.txt $FYEL
	cecho "Rango de tiempo de llegada: $rangoLlegadaMinimo - $rangoLlegadaMaximo | $rangollegadaresumen" >> informecolor.txt $FYEL
	cecho "Rango de tiempo de ejecución: $rangoTiempoEjMinimo - $rangoTiempoEjMaximo | $rangotiempoejecucionresumen" >> informecolor.txt $FYEL
	cecho "Rango de memoria que ocupa el proceso: $rangoMemoriaProcesoMinimo - $rangoMemoriaProcesoMaximo | $rangomemoriaprocesoresumen" >> informecolor.txt $FYEL
	cecho "-------------------------------------------------------------------------------" >> informecolor.txt$FRED
	
	echo "" >> informebn.txt
	cecho "Resumen" >> informebn.txt 
	cecho "-------------------------------------------------------------------------------" >> informebn.txt 
	cecho "Rango de memoria: $rangoMemoriaMinimo - $rangoMemoriaMaximo | $memoriaresumen" >> informebn.txt  
	cecho "Rango de procesos: $rangoProcesosMinimo - $rangoProcesosMaximo | $rangoprocesosresumen" >> informebn.txt 
	cecho "Rango de tiempo de llegada: $rangoLlegadaMinimo - $rangoLlegadaMaximo | $rangollegadaresumen" >> informebn.txt 
	cecho "Rango de tiempo de ejecución: $rangoTiempoEjMinimo - $rangoTiempoEjMaximo | $rangotiempoejecucionresumen" >> informebn.txt
	cecho "Rango de memoria que ocupa el proceso: $rangoMemoriaProcesoMinimo - $rangoMemoriaProcesoMaximo | $rangomemoriaprocesoresumen" >> informebn.txt 
	cecho "-------------------------------------------------------------------------------" >> informebn.txt 
	
}
	
			
#-----------------------------------------------------------------------------
#                   FUNCIÓN ALEATORIO POR RANGOS - OPCION 1 (datosrangos.txt)
#-----------------------------------------------------------------------------
function ficheroAleatorioRangos1 {
	
					rm datosrangos.txt
					tablaresumen
					echo "Valor mínimo del rango de Memoria:"
					echo "Valor mínimo del rango de Memoria:" >> informecolor.txt
					echo "Valor mínimo del rango de Memoria:" >> informebn.txt
					read rangoMemoriaMinimo
					  while ! [[ $rangoMemoriaMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoMemoriaMinimo
							echo "$rangoMemoriaMinimo" >> informebn.txt
							echo "$rnagoMemoriaMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de Memoria:"
					echo "Valor máximo del rango de Memoria:" >> informecolor.txt
					echo "Valor máximo del rango de Memoria:" >> informebn.txt
					read rangoMemoriaMaximo
					  while ! [[ $rangoMemoriaMaximo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoMemoriaMaximo
							echo "$rangoMemoriaMaximo" >> informebn.txt
							echo "$rangoMemoriaMaximo" >> informecolor.txt
						done
						memoriaresumen=$(seq $rangoMemoriaMinimo $rangoMemoriaMaximo | shuf -n 1)
						clear
						tablaresumen
						#####
					echo "Valor mínimo del rango de procesos: "
					echo "Valor mínimo del rango de procesos: " >> informecolor.txt
					echo "Valor mínimo del rango de procesos: " >> informebn.txt
					read rangoProcesosMinimo
					  while ! [[ $rangoProcesosMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt
							read rangoProcesosMinimo
							echo "$rangoProcesosMinimo" >> informebn.txt
							echo "$rangoProcesosMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de procesos: "
					echo "Valor máximo del rango de procesos: " >> informecolor.txt
					echo "Valor máximo del rango de procesos: " >> informebn.txt
					read rangoProcesosMaximo
					  while ! [[ $rangoProcesosMaximo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoProcesosMaximo
							echo "$rangoProcesosMaximo" >> informebn.txt
							echo "$rangoProcesosMaximo" >> informecolor.txt
						done
						rangoprocesosresumen=$((rangoProcesosMinimo+1))
						clear
						tablaresumen
						#####
					echo "Valor mínimo del rango de tiempo de llegada: "
					echo "Valor mínimo del rango de tiempo de llegada: " >> informecolor.txt
					echo "Valor mínimo del rango de tiempo de llegada: " >> informebn.txt
					read rangoLlegadaMinimo
					  while ! [[ $rangoLlegadaMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoLlegadaMinimo
							echo "$rangoLlegadaMinimo" >> informebn.txt
							echo "$rangoLlegadaMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de tiempo de llegada: "
					echo "Valor máximo del rango de tiempo de llegada: " >> informecolor.txt
					echo "Valor máximo del rango de tiempo de llegada: " >> informebn.txt
					read rangoLlegadaMaximo
					  while ! [[ $rangoLlegadaMaximo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoLlegadaMaximo
							echo "$rangoLlegadoMaximo" >> informebn.txt
							echo "$rangoLlegadoMaximo" >> informecolor.txt
						done
						rangollegadaresumen=$(seq  $rangoLlegadaMinimo $rangoLlegadaMaximo | shuf -n 1)
						clear
						tablaresumen
					echo "Valor mínimo del rango de tiempo de ejecución: "
					echo "Valor mínimo del rango de tiempo de ejecución: " >> informecolor.txt
					echo "Valor mínimo del rango de tiempo de ejecución: " >> informebn.txt
					read rangoTiempoEjMinimo
					  while ! [[ $rangoTiempoEjMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt
							read rangoTiempoEjMinimo
							echo "$rangoTiempoEjMinimo" >> informebn.txt
							echo "$rangoTiempoEjMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de tiempo de ejecución: "
					echo "Valor máximo del rango de tiempo de ejecución: " >> informecolor.txt
					echo "Valor máximo del rango de tiempo de ejecución: " >> informebn.txt
					read rangoTiempoEjMaximo
					  while ! [[ $rangoTiempoEjMaximo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoTiempoEjMaximo
							echo "$rangoTiempoEjMaximo" >> informebn.txt
							echo "$rangoTiempoEjMaximo" >> informecolor.txt
						done
						rangotiempoejecucionresumen=$(shuf -i $rangoTiempoEjMinimo-$rangoTiempoEjMaximo -n 1)
						clear
						tablaresumen
					echo "Valor mínimo del rango de memoria que ocupa el proceso: "
					echo "Valor mínimo del rango de memoria que ocupa el proceso: " >> informecolor.txt
					echo "Valor mínimo del rango de memoria que ocupa el proceso: " >> informebn.txt
					read rangoMemoriaProcesoMinimo
					  while ! [[ $rangoMemoriaProcesoMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoMemoriaProcesoMinimo
							echo "$rangoMemoriaProcesoMinimo" >> informebn.txt
							echo "$rangoMemoriaProcesoMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de memoria que ocupa el proceso: "
					echo "Valor máximo del rango de memoria que ocupa el proceso: " >> informecolor.txt
					echo "Valor máximo del rango de memoria que ocupa el proceso: " >> informebn.txt
					read rangoMemoriaProcesoMaximo
					  while ! [[ $rangoMemoriaProcesoMaximo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoMemoriaProcesoMaximo
							echo "$rangoMemoriaProcesoMaximo" >> informebn.txt
							echo "$rangoMemoriaProcesoMaximo" >> informecolor.txt
						done
						rangomemoriaprocesoresumen=$(shuf -i $rangoMemoriaProcesoMinimo-$rangoMemoriaProcesoMaximo -n 1)
						clear
						tablaresumen
						#######
						echo "$rangoMemoriaMinimo:$rangoMemoriaMaximo" >> datosrangos.txt
						echo "$rangoProcesosMinimo:$rangoProcesosMaximo" >> datosrangos.txt
						echo "$rangoLlegadaMinimo:$rangoLlegadaMaximo" >> datosrangos.txt
						echo "$rangoTiempoEjMinimo:$rangoTiempoEjMaximo" >> datosrangos.txt
						echo "$rangoMemoriaProcesoMinimo:$rangoMemoriaProcesoMaximo" >> datosrangos.txt
						#######	
						rangos
		#			echo "$memoriaresumen" >> datosrangos.txt
		#			echo "$rangollegadaresumen:$rangotiempoejecucionresumen:$rangomemoriaprocesoresumen:" >> datosrangos.txt
		#			p=0; while [[ $p -lt $rangoProcesosMinimo ]]; do
		#			e=0; while [[ $e -lt 3 ]]; do
		#	echo -n "$(shuf -i $rangoProcesosMinimo-$rangoProcesosMaximo -n 1):" >> datosrangos.txt; 
		#	e=$((e+1));
		#	done 
		#	p=$((p+1));
		#			echo  "">>datosrangos.txt
		#			done
		#	
		#    readfilealeatorio
			}
			
#-----------------------------------------------------------------------------------
#                   FUNCIÓN ALEATORIO POR RANGOS - OPCION 2 (Otro fichero de datos)
#-----------------------------------------------------------------------------------			
function ficheroAleatorioRangos2 {
	
					rm $guardarFicheroAleatorio
					tablaresumen
					echo "Valor mínimo del rango de Memoria:"
					echo "Valor mínimo del rango de Memoria:" >> informecolor.txt
					echo "Valor mínimo del rango de Memoria:" >> informebn.txt
					read rangoMemoriaMinimo
					  while ! [[ $rangoMemoriaMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoMemoriaMinimo
							echo "$rangoMemoriaMinimo" >> informebn.txt
							echo "$rnagoMemoriaMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de Memoria:"
					echo "Valor máximo del rango de Memoria:" >> informecolor.txt
					echo "Valor máximo del rango de Memoria:" >> informebn.txt
					read rangoMemoriaMaximo
					  while ! [[ $rangoMemoriaMaximo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoMemoriaMaximo
							echo "$rangoMemoriaMaximo" >> informebn.txt
							echo "$rangoMemoriaMaximo" >> informecolor.txt
						done
						memoriaresumen=$(seq $rangoMemoriaMinimo $rangoMemoriaMaximo | shuf -n 1)
						clear
						tablaresumen
						########
					echo "Valor mínimo del rango de procesos: "
					echo "Valor mínimo del rango de procesos: " >> informecolor.txt
					echo "Valor mínimo del rango de procesos: " >> informebn.txt
					read rangoProcesosMinimo
					  while ! [[ $rangoProcesosMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt
							read rangoProcesosMinimo
							echo "$rangoProcesosMinimo" >> informebn.txt
							echo "$rangoProcesosMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de procesos: "
					echo "Valor máximo del rango de procesos: " >> informecolor.txt
					echo "Valor máximo del rango de procesos: " >> informebn.txt
					read rangoProcesosMaximo
					  while ! [[ $rangoProcesosMaximo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoProcesosMaximo
							echo "$rangoProcesosMaximo" >> informebn.txt
							echo "$rangoProcesosMaximo" >> informecolor.txt
						done
						rangoprocesosresumen=$((rangoProcesosMinimo+1))
						clear
						tablaresumen
						########
					echo "Valor mínimo del rango de tiempo de llegada: "
					echo "Valor mínimo del rango de tiempo de llegada: " >> informecolor.txt
					echo "Valor mínimo del rango de tiempo de llegada: " >> informebn.txt
					read rangoLlegadaMinimo
					  while ! [[ $rangoLlegadaMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoLlegadaMinimo
							echo "$rangoLlegadaMinimo" >> informebn.txt
							echo "$rangoLlegadaMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de tiempo de llegada: "
					echo "Valor máximo del rango de tiempo de llegada: " >> informecolor.txt
					echo "Valor máximo del rango de tiempo de llegada: " >> informebn.txt
					read rangoLlegadaMaximo
					  while ! [[ $rangoLlegadaMaximo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoLlegadaMaximo
							echo "$rangoLlegadoMaximo" >> informebn.txt
							echo "$rangoLlegadoMaximo" >> informecolor.txt
						done
						rangollegadaresumen=$(seq  $rangoLlegadaMinimo $rangoLlegadaMaximo | shuf -n 1)
						clear
						tablaresumen
					echo "Valor mínimo del rango de tiempo de ejecución: "
					echo "Valor mínimo del rango de tiempo de ejecución: " >> informecolor.txt
					echo "Valor mínimo del rango de tiempo de ejecución: " >> informebn.txt
					read rangoTiempoEjMinimo
					  while ! [[ $rangoTiempoEjMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt
							read rangoTiempoEjMinimo
							echo "$rangoTiempoEjMinimo" >> informebn.txt
							echo "$rangoTiempoEjMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de tiempo de ejecución: "
					echo "Valor máximo del rango de tiempo de ejecución: " >> informecolor.txt
					echo "Valor máximo del rango de tiempo de ejecución: " >> informebn.txt
					read rangoTiempoEjMaximo
					  while ! [[ $rangoTiempoEjMaximo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoTiempoEjMaximo
							echo "$rangoTiempoEjMaximo" >> informebn.txt
							echo "$rangoTiempoEjMaximo" >> informecolor.txt
						done
						rangotiempoejecucionresumen=$(shuf -i $rangoTiempoEjMinimo-$rangoTiempoEjMaximo -n 1)
						clear
						tablaresumen
					echo "Valor mínimo del rango de memoria que ocupa el proceso: "
					echo "Valor mínimo del rango de memoria que ocupa el proceso: " >> informecolor.txt
					echo "Valor mínimo del rango de memoria que ocupa el proceso: " >> informebn.txt
					read rangoMemoriaProcesoMinimo
					  while ! [[ $rangoMemoriaProcesoMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoMemoriaProcesoMinimo
							echo "$rangoMemoriaProcesoMinimo" >> informebn.txt
							echo "$rangoMemoriaProcesoMinimo" >> informecolor.txt
						done
						clear
						tablaresumen
					echo "Valor máximo del rango de memoria que ocupa el proceso: "
					echo "Valor máximo del rango de memoria que ocupa el proceso: " >> informecolor.txt
					echo "Valor máximo del rango de memoria que ocupa el proceso: " >> informebn.txt
					read rangoMemoriaProcesoMaximo
					  while ! [[ $rangoMemoriaMinimo =~ ^[0-9]+$ ]]
						do
							cecho "Tiene que ser un valor entero" $FRED
							cecho "Tiene que ser un valor entero" >> informecolor.txt $FRED
							cecho "Tiene que ser un valor entero" >> informebn.txt 
							read rangoMemoriaProcesoMaximo
							echo "$rangoMemoriaProcesoMaximo" >> informebn.txt
							echo "$rangoMemoriaProcesoMaximo" >> informecolor.txt
						done
						rangomemoriaprocesoresumen=$(shuf -i $rangoMemoriaProcesoMinimo-$rangoMemoriaProcesoMaximo -n 1)
						clear
						tablaresumen
						########
						echo "$rangoMemoriaMinimo:$rangoMemoriaMaximo" >> $guardarFicheroAleatorio
						echo "$rangoProcesosMinimo:$rangoProcesosMaximo" >> $guardarFicheroAleatorio
						echo "$rangoLlegadaMinimo:$rangoLlegadaMaximo" >> $guardarFicheroAleatorio
						echo "$rangoTiempoEjMinimo:$rangoTiempoEjMaximo" >> $guardarFicheroAleatorio
						echo "$rangoMemoriaProcesoMinimo:$rangoMemoriaProcesoMaximo" >> $guardarFicheroAleatorio
						#######	
						rangos				
		#			echo "$memoriaresumen" >> $guardarFicheroAleatorio
		#			echo "$rangollegadaresumen:$rangotiempoejecucionresumen:$rangomemoriaprocesoresumen:" >> $guardarFicheroAleatorio
		#			p=0; while [[ $p -lt $rangoProcesosMinimo ]]; do
		#			e=0; while [[ $e -lt 3 ]]; do
		#	echo -n "$(shuf -i $rangoProcesosMinimo-$rangoProcesosMaximo -n 1):" >> $guardarFicheroAleatorio; 
		#	e=$((e+1));
		#	done 
		#	p=$((p+1));
		#			echo  "">>$guardarFicheroAleatorio
		#			done
		 #   readfilealeatorio2	
			}
#-----------------------------------------------------------------------------------
#                   FUNCIÓN RANGOS
#-----------------------------------------------------------------------------------
function rangos {
	cecho "estos son los rangos guardados:" $FYEL
	cecho "$rangoMemoriaMinimo - $rangoMemoriaMaximo " 
	cecho "$rangoProcesosMinimo - $rangoProcesosMaximo " 
	cecho "$rangoLlegadaMinimo - $rangoLlegadaMaximo" 
	cecho "$rangoTiempoEjMinimo - $rangoTiempoEjMaximo" 
	cecho "$rangoMemoriaProcesoMinimo - $rangoMemoriaProcesoMaximo" 
	echo ""
	cecho "¿Donde quieres guardar el resultado de los rangos?" $FYEL
	cecho "datos.txt"
	cecho "datos2.txt"
	cecho "datos3.txt"
	cecho "-----------" $FYEL
	read guardarFicheroAleatorio
	
		rm $guardarFicheroAleatorio
					echo "$memoriaresumen" >> $guardarFicheroAleatorio
					echo "$rangollegadaresumen:$rangotiempoejecucionresumen:$rangomemoriaprocesoresumen:" >> $guardarFicheroAleatorio
					p=0; while [[ $p -lt $rangoProcesosMinimo ]]; do
					e=0; while [[ $e -lt 3 ]]; do
			echo -n "$(shuf -i $rangoProcesosMinimo-$rangoProcesosMaximo -n 1):" >> $guardarFicheroAleatorio; 
			e=$((e+1));
			done 
			p=$((p+1));
					echo  "">>$guardarFicheroAleatorio
					done
					
		    readfilealeatorio2
}

#-----------------------------------------------------------------------------------
#                   FUNCIÓN LEER RANGOS OPCIÓN 5
#-----------------------------------------------------------------------------------

 function leerrangos {
	 
	rangoMemoriaMinimo=`cat datosrangos.txt | cut -f 1 -d":" | sed -n 1p`
	rangoMemoriaMaximo=`cat datosrangos.txt | cut -f 2 -d":" | sed -n 1p`
	rangoProcesosMinimo=`cat datosrangos.txt | cut -f 1 -d":" | sed -n 2p`
	rangoProcesosMaximo=`cat datosrangos.txt | cut -f 2 -d":" | sed -n 2p`
	rangoLlegadaMinimo=`cat datosrangos.txt | cut -f 1 -d":" | sed -n 3p`
	rangoLlegadaMaximo=`cat datosrangos.txt | cut -f 2 -d":" | sed -n 3p`
	rangoTiempoEjMinimo=`cat datosrangos.txt | cut -f 1 -d":" | sed -n 4p`
	rangoTiempoEjMaximo=`cat datosrangos.txt | cut -f 2 -d":" | sed -n 4p`
	rangoMemoriaProcesoMinimo=`cat datosrangos.txt | cut -f 1 -d":" | sed -n 5p`
	rangoMemoriaProcesoMaximo=`cat datosrangos.txt | cut -f 2 -d":" | sed -n 5p`
	
	memoriaresumen=$(seq $rangoMemoriaMinimo $rangoMemoriaMaximo | shuf -n 1)
	rangollegadaresumen=$(seq  $rangoLlegadaMinimo $rangoLlegadaMaximo | shuf -n 1)
	rangotiempoejecucionresumen=$(shuf -i $rangoTiempoEjMinimo-$rangoTiempoEjMaximo -n 1)
	rangomemoriaprocesoresumen=$(shuf -i $rangoMemoriaProcesoMinimo-$rangoMemoriaProcesoMaximo -n 1)
	
	rangos 
 }
 
#-----------------------------------------------------------------------------------
#                   FUNCIÓN LEER RANGOS OPCIÓN 5
#-----------------------------------------------------------------------------------
 function leerrangos2 {
	 
	rangoMemoriaMinimo=`cat $guardarFicheroAleatorio | cut -f 1 -d":" | sed -n 1p`
	rangoMemoriaMaximo=`cat $guardarFicheroAleatorio | cut -f 2 -d":" | sed -n 1p`
	rangoProcesosMinimo=`cat $guardarFicheroAleatorio | cut -f 1 -d":" | sed -n 2p`
	rangoProcesosMaximo=`cat $guardarFicheroAleatorio | cut -f 2 -d":" | sed -n 2p`
	rangoLlegadaMinimo=`cat $guardarFicheroAleatorio | cut -f 1 -d":" | sed -n 3p`
	rangoLlegadaMaximo=`cat $guardarFicheroAleatorio | cut -f 2 -d":" | sed -n 3p`
	rangoTiempoEjMinimo=`cat $guardarFicheroAleatorio | cut -f 1 -d":" | sed -n 4p`
	rangoTiempoEjMaximo=`cat $guardarFicheroAleatorio | cut -f 2 -d":" | sed -n 4p`
	rangoMemoriaProcesoMinimo=`cat $guardarFicheroAleatorio | cut -f 1 -d":" | sed -n 5p`
	rangoMemoriaProcesoMaximo=`cat $guardarFicheroAleatorio | cut -f 2 -d":" | sed -n 5p`
	
	memoriaresumen=$(seq $rangoMemoriaMinimo $rangoMemoriaMaximo | shuf -n 1)
	rangollegadaresumen=$(seq  $rangoLlegadaMinimo $rangoLlegadaMaximo | shuf -n 1)
	rangotiempoejecucionresumen=$(shuf -i $rangoTiempoEjMinimo-$rangoTiempoEjMaximo -n 1)
	rangomemoriaprocesoresumen=$(shuf -i $rangoMemoriaProcesoMinimo-$rangoMemoriaProcesoMaximo -n 1)
	 
	 rangos
 }

######################################################################################################################################################################################################
####################################################################                   ###############################################################################################################
####################################################################   FIN FUNCIONES   ###############################################################################################################
####################################################################                   ###############################################################################################################
######################################################################################################################################################################################################
# -----------------------------------------------------------------------------
# Menu principal: entrada manual o de fichero.
# Si es entrada manual pedimos los datos uno a uno.
# -----------------------------------------------------------------------------
clear
cecho "**********************************************************************************" $FCYN
cecho "*                  SISTEMAS OPERATIVOS - PRÁCTICA DE CONTROL                     *" $FCYN
cecho "*                       Curso 2019-20(v1) / 2021-22(v2)                          *" $FCYN
cecho "*                                                                                *" $FCYN
cecho "*                                                                                *" $FCYN
cecho "*              SRPT-SEGÚN NECESIDADES-MEMORIA NO CONTINUA-REUBICABLE             *" $FCYN
cecho "*                                                                                *" $FCYN
cecho "*                                                                                *" $FCYN
cecho "*                              Alumnos antiguos:                                 *" $FCYN
cecho "*                          · Daniel Puente Ramírez (19-20)                       *" $FCYN
cecho "*                                                                                *" $FCYN
cecho "*                              Alumnos nuevos:                                   *" $FCYN
cecho "*                          · Hugo Gómez Martín (21-22)                           *" $FCYN
cecho "**********************************************************************************" $FCYN

> informebn.txt

echo "**********************************************************************************" >> informebn.txt
echo "*                  SISTEMAS OPERATIVOS - PRÁCTICA DE CONTROL                     *" >> informebn.txt
echo "*                       Curso 2019-20(v1) / 2021-22(v2)                          *" >> informebn.txt
echo "*                                                                                *" >> informebn.txt
echo "*                                                                                *" >> informebn.txt
echo "*              SRPT-SEGÚN NECESIDADES-MEMORIA NO CONTINUA-REUBICABLE             *" >> informebn.txt
echo "*                                                                                *" >> informebn.txt
echo "*                                                                                *" >> informebn.txt
echo "*                              Alumnos antiguos:                                 *" >> informebn.txt
echo "*                          · Daniel Puente Ramírez (19-20)                       *" >> informebn.txt
echo "*                                                                                *" >> informebn.txt
echo "*                              Alumnos nuevos:                                   *" >> informebn.txt
echo "*                          · Hugo Gómez Martín (21-22)                           *" >> informebn.txt
echo "**********************************************************************************" >> informebn.txt
echo " " >> informebn.txt
echo " " >> informebn.txt

> informecolor.txt

cecho "**********************************************************************************" >> informecolor.txt $FCYN
cecho "*                  SISTEMAS OPERATIVOS - PRÁCTICA DE CONTROL                     *" >> informecolor.txt $FCYN
cecho "*                       Curso 2019-20(v1) / 2021-22(v2)                          *" >> informecolor.txt $FCYN
cecho "*                                                                                *" >> informecolor.txt $FCYN
cecho "*                                                                                *" >> informecolor.txt $FCYN
cecho "*              SRPT-SEGÚN NECESIDADES-MEMORIA NO CONTINUA-REUBICABLE             *" >> informecolor.txt $FCYN
cecho "*                                                                                *" >> informecolor.txt $FCYN
cecho "*                                                                                *" >> informecolor.txt $FCYN
cecho "*                              Alumnos antiguos:                                 *" >> informecolor.txt $FCYN
cecho "*                          · Daniel Puente Ramírez (19-20)                       *" >> informecolor.txt $FCYN
cecho "*                                                                                *" >> informecolor.txt $FCYN
cecho "*                              Alumnos nuevos:                                   *" >> informecolor.txt $FCYN
cecho "*                          · Hugo Gómez Martín (21-22)                           *" >> informecolor.txt $FCYN
cecho "**********************************************************************************" >> informecolor.txt $FCYN
cecho " " >> informecolor.txt
cecho " " >> informecolor.txt


echo " "
echo " "
cecho "-----------------------------------------------------"  $FRED
cecho "                      M E N Ú " $FYEL
cecho "-----------------------------------------------------"  $FRED
cecho "1) Introducir datos por teclado" $FYEL 
cecho "2) Fichero de datos de última ejecución (datos.txt)" $FYEL #cambiar a datos.txt
cecho "3) Otro fichero de Datos" $FYEL 
cecho "4) Introducción de rangos manualmente" $FYEL 
cecho "5) Fichero de rangos ultima ejecución (datosrangos.txt)" $FYEL
cecho "6) Otro fichero de rangos"  $FYEL 
cecho "7) Salir" $FYEL                 
cecho "-----------------------------------------------------" $FRED   
cecho " "
cecho "Introduce una opcion: " $RS

echo " " >> informecolor.txt
echo " " >> informecolor.txt
cecho "-----------------------------------------------------" >> informecolor.txt  $FRED
cecho "                      M E N Ú " >> informecolor.txt $FYEL
cecho "-----------------------------------------------------" >> informecolor.txt $FRED
cecho "1) Introducir datos por teclado" >> informecolor.txt $FYEL 
cecho "2) Fichero de datos de última ejecución (datos.txt)" >> informecolor.txt $FYEL #cambiar a datos.txt
cecho "3) Otro fichero de Datos" >> informecolor.txt $FYEL 
cecho "4) Introducción de rangos manualmente" >> informecolor.txt $FYEL 
cecho "5) Fichero de rangos ultima ejecución (datosrangos.txt)" >> informecolor.txt $FYEL
cecho "6) Otro fichero de rangos"  >> informecolor.txt $FYEL 
cecho "7) Salir" >> informecolor.txt $FYEL                 
cecho "-----------------------------------------------------" >> informecolor.txt $FRED   
cecho " " >> informecolor.txt
cecho "Introduce una opcion: " >> informecolor.txt $RS

echo " " >> informebn.txt
echo " " >> informebn.txt
cecho "-----------------------------------------------------"  >> informebn.txt 
cecho "                      M E N Ú " >> informebn.txt 
cecho "-----------------------------------------------------"  >> informebn.txt 
cecho "1) Introducir datos por teclado" >> informebn.txt 
cecho "2) Fichero de datos de última ejecución (datos.txt)" >> informebn.txt  #cambiar a datos.txt
cecho "3) Otro fichero de Datos" >> informebn.txt 
cecho "4) Introducción de rangos manualmente" >> informebn.txt 
cecho "5) Fichero de rangos ultima ejecución (datosrangos.txt)" >> informebn.txt 
cecho "6) Otro fichero de rangos"  >> informebn.txt 
cecho "7) Salir" >> informebn.txt 
cecho "-----------------------------------------------------" >> informebn.txt   
cecho " " >> informebn.txt
cecho "Introduce una opcion: " >> informebn.txt 

num=0
continuar="SI"              # Cuando termine la entrada de datos, continuamos

while [ $num -ne 7 ] && [ "$continuar" == "SI" ]
do
  read num
  case $num in
  
#################
################ Opción 1
   "1" )
         # Cargamos los datos por teclado
         cecho "Elige el fichero donde quieres guardar los datos:" $FYEL #Preguntamos antes al usuario donde quiere guardar los datos 
         cecho "1) Fichero de datos de última ejecución (datos.txt)"
         cecho "2) Otro fichero de datos"
			cecho "Introduce una opción" $FYEL
			cecho "-------------------------" $FYEL
			read guardarOpcion ##guardarFichero
		while [ $guardarOpcion != 1 ] && [ $guardarOpcion != 2 ] # Si el fichero no existe, lectura erronea, validación ejecutada
			do
				clear
				cecho "Entrada no válida, vuelve a intentarlo. Introduce ahora una opción correcta" $FRED
				cecho "1) Fichero de datos de última ejecución (datos.txt)"
                cecho "2) Otro fichero de datos"
				cecho "-------------------------" $FYEL
				read guardarOpcion
				
			done
		if [[ $guardarOpcion -eq 1 ]]; then 
		 readprocesos
		 elif [[ $guardarOpcion -eq 2 ]]; then 
		 echo "En que fichero de Otro fichero de datos quieres guardarlos: " 
		# ls | grep Datos
		 echo "datos.txt"
		 echo "datos2.txt"
		 echo "datos3.txt"
		 cecho "-------------------------" $FYEL
		 read guardarFichero
		 while [ ! -f $guardarFichero ] # Si el fichero no existe, lectura erronea, validación ejecutada
			do
				clear
				cecho "No existe el fichero, por lo tanto, crea usted el fichero (introduce el nombre con la extensión):" $FYEL
				read ficheroUsuario
				touch $ficheroUsuario
				
				#cecho "Entrada no válida, vuelve a intentarlo. Introduce uno de los ficheros del listado:" $FRED
				#ls | grep Datos
				#cecho "-------------------------" $FYEL
				#read guardarFichero		
			done
		 readprocesosopcion2
		 fi
         continuar=NO
         ;;
         
##################
################# Opción 2

         "2" )
         # Cargamos el fichero de entrada
         readfile
         continuar=NO
         ;;
			
#################
################ Opción 3
		 "3" ) 
		 cecho "Que fichero quieres leer:" $FYEL
		 #ls | grep Datos
		 echo "datos2.txt"
		 echo "datos3.txt"
		 cecho "-------------------------" $FYEL
		 read leerFichero
		 while [ ! -f $leerFichero ] # Si el fichero no existe, lectura erronea, validación ejecutada
			do
				clear
				cecho "Entrada no válida, vuelve a intentarlo. Introduce uno de los ficheros del listado:" $FRED
				#ls | grep Datos
				echo "datos2.txt"
				echo "datos3.txt"
				cecho "-------------------------" $FYEL
				read leerFichero
				
			done
		 readfile2
		 continuar=NO
		 ;;

#################
################ Opción 4		
		
		 "4" ) 
			  cecho "Elige el fichero donde quieres guardar los rangos:" $FYEL #Preguntamos antes al usuario donde quiere guardar los datos 
         cecho "1) Fichero de datos de última ejecución (datosrangos.txt)"
         cecho "2) Otro fichero de datos"
			cecho "Introduce una opción" $FYEL
			cecho "-------------------------" $FYEL
			read guardarOpcionAleatorio ##guardarFichero
		while [ $guardarOpcionAleatorio != 1 ] && [ $guardarOpcionAleatorio != 2 ] # Si el fichero no existe, lectura erronea, validación ejecutada
			do
				clear
				cecho "Entrada no válida, vuelve a intentarlo. Introduce ahora una opción correcta" $FRED
				cecho "1) Fichero de datos de última ejecución (datos.txt)"
                cecho "2) Otro fichero de datos"
				cecho "-------------------------" $FYEL
				read guardarOpcionAleatorio
			
			done
		if [[ $guardarOpcionAleatorio -eq 1 ]]; then 
		 ficheroAleatorioRangos1
		 elif [[ $guardarOpcionAleatorio -eq 2 ]]; then 
		 echo "En que fichero de Otro fichero de datos quieres guardarlos: " 
		 #ls | grep datosrangos
		 echo "datosrangos.txt"
		 echo "datosrangos2.txt"
		 echo "datosrangos3.txt"
		 cecho "-------------------------" $FYEL
		 read guardarFicheroAleatorio
		 while [ ! -f $guardarFicheroAleatorio ] # Si el fichero no existe, lectura erronea, validación ejecutada
			do
				clear
				cecho "no existe el fichero, por lo tanto, crea usted el fichero (introduce el nombre con la extensión):" $FYEL
				read ficheroUsuario
				touch $ficheroUsuario	
			done
		 ficheroAleatorioRangos2
		 fi
		 continuar=NO
		##########################################################################################################################################################
		;;

		 
#################
################ Opción 5		 
		 "5" )
		#readfilealeatorio
		leerrangos
		 continuar=NO
		 ;;
		 
#################
################ Opción 6		 
         "6" ) 
         cecho "Que fichero de rangos quieres leer:" $FYEL
		 #ls | grep datosrangos
		 echo "datosrangos.txt"
		 echo "datosrangos2.txt"
		 echo "datosrangos3.txt"
		 cecho "-------------------------" $FYEL
		 read guardarFicheroAleatorio
		 while [ ! -f $guardarFicheroAleatorio ] # Si el fichero no existe, lectura erronea, validación ejecutada
			do
				clear
				cecho "Entrada no válida, vuelve a intentarlo. Introduce uno de los ficheros del listado:" $FRED
				#ls | grep datos
				echo "datoseangos1.txt"
				echo "datosrangos2.txt"
				echo "datosrangos3.txt"
				cecho "-------------------------" $FYEL
				read guardarFicheroAleatorio
				
			done
		 leerrangos2
         continuar=NO
		 ;;

#################
################ Opción 7
		 "7" ) exit 0
		 
;;

*) num=0
cecho "Opción errónea, vuelva a introducir" $FRED
esac
done

clear

simulacion

    coloresTemp[0]=$FRED
    coloresTemp[1]=$FGRN
    coloresTemp[2]=$FYEL
    coloresTemp[3]=$FBLE
    coloresTemp[4]=$FMAG
    coloresTemp[5]=$FCYN
    coloresTemp[6]=$FRED
    coloresTemp[7]=$FGRN
    coloresTemp[8]=$FYEL
    coloresTemp[9]=$FBLE
    coloresTemp[10]=$FMAG
    coloresTemp[11]=$FCYN
    coloresTemp[12]=$FRED
    coloresTemp[13]=$FGRN
    coloresTemp[14]=$FYEL
    coloresTemp[15]=$FBLE
    coloresTemp[16]=$FMAG
    coloresTemp[17]=$FCYN
    coloresTemp[18]=$FRED
    coloresTemp[19]=$FGRN
    coloresTemp[20]=$FYEL
# -----------------------------------------------------------------------------
# Inicilizamos las tablas indicadoras de la situación del proceso
# -----------------------------------------------------------------------------
for (( i=1; i<$nprocesos; i++ ))
do 
    posMemInicial[$i]=0
    posMemFinal[$i]=0
    pos_inicio[$i]=0
    pos_final[$i]=0
    ordenEntrada[$i]=0
    entradaAuxiliar[$i]=0
    ejecucionAuxiliar[$i]=0
    tamemoryAuxiliar[$i]=0
    encola[$i]=0
    enmemoria[$i]=0
    enejecucion[$i]=0
    bloqueados[$i]=0
    terminados[$i]=0
    nollegado[$i]=0
done
for (( i = 0; i < $mem_total; i++ )); do
    #posMem[$i]=0
    if [[ ${posMem[$i]} -eq $mem_total-1 ]]; then
        posMem[$i]=1
    fi
done
for (( i = 0; i < 1000; i++ )); do
    procTiempo[$i]=0
done
let lastMemPos=0
let flag=1
let tiempoAnterior=-1
procesoTiempo=""
imprimirYa="NO"
enterLuego=0
#------------------------------------------------------------------------------
#    O R D E N     P A R A    E N T R A R    E N    M E M O R I A
#
# Bucle que ordena según el tiempo de llegada todos los procesos.
#
#
#------------------------------------------------------------------------------

for(( i=0; i<$nprocesos; i++)) #Copia de todas las listas para luego ponerlas en orden
do
	numeroProcesos[$i]=$i
	ordenEntrada[$i]=${procesos[$i]}
	entradaAuxiliar[$i]=${entradas[$i]}
	ejecucionAuxiliar[$i]=${ejecucion[$i]}
	tamemoryAuxiliar[$i]=${tamemory[$i]}
	encola[$i]=0
    enmemoria[$i]=0
    enejecucion[$i]=0
    bloqueados[$i]=0
    pausados[$i]=0
    terminados[$i]=0
    nollegado[$i]=0
    estado[$i]=0
    temp_wait[$i]=0
    temp_resp[$i]=0
    temp_ret[$i]=0
    #procTerminado[$i]=0 #### No tiene nada que ver las posiciones de este vector, con las reales, este vector almacena el orden en el que los procesos terminan.
done
procTerminado=()


# Los siguientes bucles for ordenan los procesos y todos sus datos en función del tiempo de llegada. Nos encontramos esta misma secuencia en todos los ficheros que van junto con el código.
for (( i=0; i<$nprocesos; i++ )) #Bucle que reordena por tiempo de llegada todos los arrays.
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
	    if [[ ${entradaAuxiliar[$j]} -le ${entradaAuxiliar[$i]} ]] ; then #Probar con -ge si falla
		if [[ ${ordenEntrada[$j]} -lt ${ordenEntrada[$i]} ]] ; then #Probar con -gt si falla
            auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
    auxiliar1=${ordenEntrada[$i]}
    auxiliar2=${entradaAuxiliar[$i]}
    auxiliar3=${ejecucionAuxiliar[$i]}
    auxiliar4=${tamemoryAuxiliar[$i]}
    auxiliar5=${encola[$i]}
    auxiliar6=${enmemoria[$i]}
    auxiliar7=${enejecucion[$i]}
    auxiliar8=${bloqueados[$i]}
    auxiliar9=${numeroProcesos[$i]}
    ordenEntrada[$i]=${ordenEntrada[$j]}
    entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
    ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
    tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
    encola[$i]=${encola[$j]}
    enmemoria[$i]=${enmemoria[$j]}
    enejecucion[$i]=${enejecucion[$j]}
    bloqueados[$i]=${bloqueados[$j]}
    numeroProcesos[$i]=${numeroProcesos[$j]}
    ordenEntrada[$j]=$auxiliar1
    entradaAuxiliar[$j]=$auxiliar2
    ejecucionAuxiliar[$j]=$auxiliar3
    tamemoryAuxiliar[$j]=$auxiliar4
    encola[$j]=$auxiliar5
    enmemoria[$j]=$auxiliar6
    enejecucion[$j]=$auxiliar7
    bloqueados[$j]=$auxiliar8
    numeroProcesos[$j]=$auxiliar9
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 for (( j=$i; j<$nprocesos; j++ ))
 do
   if [[ ${entradaAuxiliar[$i]} -eq ${entradaAuxiliar[$j]} ]] ; then
    if [[ ${numeroProcesos[$i]} -gt ${numeroProcesos[$j]} ]] ; then
        auxiliar1=${ordenEntrada[$i]}
        auxiliar2=${entradaAuxiliar[$i]}
        auxiliar3=${ejecucionAuxiliar[$i]}
        auxiliar4=${tamemoryAuxiliar[$i]}
        auxiliar5=${encola[$i]}
        auxiliar6=${enmemoria[$i]}
        auxiliar7=${enejecucion[$i]}
        auxiliar8=${bloqueados[$i]}
        auxiliar9=${numeroProcesos[$i]}
        ordenEntrada[$i]=${ordenEntrada[$j]}
        entradaAuxiliar[$i]=${entradaAuxiliar[$j]}
        ejecucionAuxiliar[$i]=${ejecucionAuxiliar[$j]}
        tamemoryAuxiliar[$i]=${tamemoryAuxiliar[$j]}
        encola[$i]=${encola[$j]}
        enmemoria[$i]=${enmemoria[$j]}
        enejecucion[$i]=${enejecucion[$j]}
        bloqueados[$i]=${bloqueados[$j]}
        numeroProcesos[$i]=${numeroProcesos[$j]}
        ordenEntrada[$j]=$auxiliar1
        entradaAuxiliar[$j]=$auxiliar2
        ejecucionAuxiliar[$j]=$auxiliar3
        tamemoryAuxiliar[$j]=$auxiliar4
        encola[$j]=$auxiliar5
        enmemoria[$j]=$auxiliar6
        enejecucion[$j]=$auxiliar7
        bloqueados[$j]=$auxiliar8
        numeroProcesos[$j]=$auxiliar9
    fi
fi
done
done


for (( i=0; i<$nprocesos; i++ ))
do
 tejecucion[$i]=${ejecucionAuxiliar[$i]}
done

for (( i = 0; i < ${#ordenEntrada[@]}; i++ )); do
  if [[ "${ordenEntrada[$i]}" == "P01" ]]; then
    colores[$i]="${coloresTemp[1]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P02" ]]; then
    colores[$i]="${coloresTemp[2]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P03" ]]; then
    colores[$i]="${coloresTemp[3]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P04" ]]; then
    colores[$i]="${coloresTemp[4]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P05" ]]; then
    colores[$i]="${coloresTemp[5]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P06" ]]; then
    colores[$i]="${coloresTemp[6]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P07" ]]; then
    colores[$i]="${coloresTemp[7]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P08" ]]; then
    colores[$i]="${coloresTemp[8]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P09" ]]; then
    colores[$i]="${coloresTemp[9]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P10" ]]; then
    colores[$i]="${coloresTemp[10]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P11" ]]; then
    colores[$i]="${coloresTemp[11]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P12" ]]; then
    colores[$i]="${coloresTemp[12]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P13" ]]; then
    colores[$i]="${coloresTemp[13]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P14" ]]; then
    colores[$i]="${coloresTemp[14]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P15" ]]; then
    colores[$i]="${coloresTemp[15]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P16" ]]; then
    colores[$i]="${coloresTemp[16]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P17" ]]; then
    colores[$i]="${coloresTemp[17]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P18" ]]; then
    colores[$i]="${coloresTemp[18]}"
  fi  
  if [[ "${ordenEntrada[$i]}" == "P19" ]]; then
    colores[$i]="${coloresTemp[19]}"
  fi
done

blanco="\e[37m" # blanco 
RS="\033[0m"    # reset

mem_libre66=$mem_total
mem_total66=$mem_total
mem_libre=$mem_total
mem_aux=$mem_libre
mem=$mem_total

reubica=0
nprocTerminados=0

echo ""


echo " "

clear





echo " "
echo "Iniciando el proceso de visualización..."
echo "Iniciando el proceso de visualización..." >> informecolor.txt
echo "Iniciando el proceso de visualización..." >> informebn.txt
wait 
#read enter

echo " "
echo " "
cecho " -----------------------------------------------------"  $FRED
cecho "                  E J E C U C I Ó N " $FYEL
cecho " -----------------------------------------------------"  $FRED
cecho " 1) Por eventos (Pulsado enter)" $FYEL 
cecho " 2) Por eventos automático (Introduciendo segundos)" $FYEL 
cecho " 3) Completa" $FYEL               
cecho " -----------------------------------------------------" $FRED   
cecho " "
cecho " Introduce una opcion: " $RS

echo " " >> informecolor.txt
echo " " >> informecolor.txt
cecho " -----------------------------------------------------" >> informecolor.txt $FRED
cecho "                  E J E C U C I Ó N " >> informecolor.txt  $FYEL
cecho " -----------------------------------------------------" >> informecolor.txt $FRED
cecho " 1) Por eventos (Pulsado enter)" >> informecolor.txt $FYEL 
cecho " 2) Por eventos automático (Introduciendo segundos)" >> informecolor.txt $FYEL 
cecho " 3) Completa" >> informecolor.txt $FYEL               
cecho " -----------------------------------------------------" >> informecolor.txt $FRED   
cecho " " >> informecolor.txt
cecho " Introduce una opcion: " >> informecolor.txt $RS

echo " " >> informebn.txt
echo " " >> informebn.txt
cecho " -----------------------------------------------------"  >> informebn.txt 
cecho "                  E J E C U C I Ó N " >> informebn.txt 
cecho " -----------------------------------------------------" >> informebn.txt 
cecho " 1) Por eventos (Pulsado enter)"  >> informebn.txt 
cecho " 2) Por eventos automático (Introduciendo segundos)" >> informebn.txt 
cecho " 3) Completa" >> informebn.txt 
cecho " -----------------------------------------------------" >> informebn.txt   
cecho " " >> informebn.txt
cecho " Introduce una opcion: " >> informebn.txt 

read ejecucion


if [[ $ejecucion -eq 2 ]] ; then 
	echo "Selecciona el tiempo de la interrupcion de los eventos:"
	echo "Selecciona el tiempo de la interrupcion de los eventos:" >> informecolor.txt
	echo "Selecciona el tiempo de la interrupcion de los eventos:" >> informebn.txt
	read tiempousuario

fi

# ----------------------------------------------------------------------------
#   C A B E C E R A   I N I C I A L    T = 0
#   Caberea de inicio en la que mostramos todos los procesos en T=0
#
# ----------------------------------------------------------------------------
for (( i = 0; i < $nprocesos; i++ )); do
    if [[ ${entradaAuxiliar[$i]} -eq 0 ]]; then
        let flag=0
    fi
done
if [[ flag -eq 1 ]]; then

    echo " "
    echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"
    echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"  >> informebn.txt
    echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"   >> informecolor.txt
    echo " T = 0          Memoria Total = $mem_libre"  
    echo " T = 0          Memoria Total = $mem_libre"  >> informebn.txt
    echo " T = 0          Memoria Total = $mem_libre"   >> informecolor.txt
     
    cecho " ┌─────┬─────┬─────┬─────┬──────┬──────┬──────┬──────┬──────┬───────────────────┐ " $RS
    cecho " │ Ref │ Tll │ Tej │ Mem │ Tesp │ Tret │ Trej │ Mini │ Mfin │ ESTADO            │ " $RS
    cecho " ├─────┼─────┼─────┼─────┼──────┼──────┼──────┼──────┼──────┼───────────────────┤ " $RS

      for (( i=0; i<$nprocesos; i++ ))
      do
		printf "$RS │" 
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}"
        printf "$RS │" 
        printf " " 
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%-20s\n" "Fuera del sistema |" 
        #printf "$RS |------------------------------------------------------------------------------|\n" 
        printf " ${ordenEntrada[$i]}" >> informebn.txt
        printf " "  >> informebn.txt
        printf "%3s" "${entradaAuxiliar[$i]}"   >> informebn.txt
        printf " "  >> informebn.txt
        printf "%3s" "${tejecucion[$i]}"   >> informebn.txt
        printf " "  >> informebn.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}"  >> informebn.txt
        printf " "   >> informebn.txt
        printf "%4s" "-"   >> informebn.txt
        printf " "  >> informebn.txt
        printf "%4s" "-"   >> informebn.txt
        printf " "  >> informebn.txt
        printf "%4s" "-"   >> informebn.txt
        printf " "  >> informebn.txt
        printf "%4s" "-"   >> informebn.txt
        printf " "  >> informebn.txt
        printf "%4s" "-"   >> informebn.txt
        printf " "  >> informebn.txt
        printf "%-20s\n" "Fuera del sistema"  >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${entradaAuxiliar[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tejecucion[$i]}"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf " "  >> informecolor.txt
        printf "%4s" "-"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%4s" "-"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%4s" "-"  >> informecolor.txt "-"
        printf " " >> informecolor.txt
        printf "%4s" "-"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%4s" "-"  >> informecolor.txt
        printf " " >> informecolor.txt
        printf "%-20s\n" "Fuera del sistema |" >> informecolor.txt                                
      done                                                                   
      printf "$RS └─────┴─────┴─────┴─────┴──────┴──────┴──────┴──────┴──────┴───────────────────┘\n" 

    cecho " Tiempo Medio Espera = 0         Tiempo Medio de Retorno = 0" $RS
    cecho " Tiempo Medio Espera = 0         Tiempo Medio de Retorno = 0" >> informebn.txt
    cecho " Tiempo Medio Espera = 0         Tiempo Medio de Retorno = 0"  >> informecolor.txt

    columns=`tput cols`
    memAImprimir=$(( mem_total66 * 3 ))
    memAImprimir=$(( memAImprimir + 5 ))
    if [[ $memAImprimir -lt $columns ]]; then
          for (( i = 0; i < $mem_libre; i++ )); do
            if [[ $i -eq 0 ]]; then
                printf "    |   " 
            else if [[ $i -eq $mem_libre-1 ]]; then
                printf "   " " $mem_libre" #sustituimos el %-3s $mem_libreya que no nos interesa el tiempo, si no nos intereas que | vaya al final corriendose con la barra final
                printf "$RS|\n"
            else
                printf "   "
            fi
            fi
        done
        printf " BM |" 
        cecho "    |" >> informebn.txt
        printf " BM |" >> informebn.txt
        cecho "    |" $FWHT  >> informecolor.txt
        printf " BM |" >> informecolor.txt
        for (( i = 0; i < $mem_libre; i++ )); do
            printf ""$RS███""
            printf "|||" >> informebn.txt
            printf ""$RS███""  >> informecolor.txt
        done
        printf "$RS|M=$mem_total"
        printf "\n"
        printf "\n"  >> informebn.txt
        printf "\n"  >> informecolor.txt
        for (( i = 0; i < $mem_libre; i++ )); do
            if [[ $i -eq 0 ]]; then
                printf "    |  0"
                printf "    |  0" >> informebn.txt
                printf "    |  0" >> informecolor.txt
            else if [[ $i -eq $mem_libre-1 ]]; then
                printf "%-3s" " $mem_libre"
                printf "%-3s" " $mem_libre" >> informebn.txt
                printf "%-3s" " $mem_libre" >> informecolor.txt
                printf "$RS|"
            else
                printf "   "
                printf "   " >> informebn.txt
                printf "   " >> informecolor.txt
            fi
            fi
        done
    else     
        memRestante=$memAImprimir
        saltos=0

        #Determinamos el numero de saltos que tiene que realizar, completando el tamaño del terminal y dejando un espacio a la derecha
        while [[ $memRestante -gt $columns ]]; do
            memRestante=$(( $memRestante - $columns ))
            saltos=$(( saltos + 1 ))
            #echo "memRestante = $memRestante -> saltos = $saltos"
        done
        memRestante=$(( $memRestante - 3 ))
        memRestante=$(( $memRestante / 3 ))

        columns1=$(( $columns - 6 ))
        ggg=$(( $columns1 % 3 ))
        if [[ $ggg -eq 0  ]]; then
            longitud=$(( $columns1 / 3 ))
        else 
            longitud=$(( $columns1 / 3 ))
            longitud=$(( $longitud - 1 ))
        fi
        for (( i = 0; i <= $saltos; i++ )); do
            printf "\n"
            cecho "    |" $FWHT
            printf "\n" >> informebn.txt
            cecho "    |"  >> informebn.txt
            printf "\n" >> informecolor.txt
            cecho "    |" $FWHT >> informecolor.txt
            if [[ $i -eq 0 ]]; then
                #statements
            printf " BM |"
            printf " BM |" >> informebn.txt
            printf " BM |"  >> informecolor.txt
        else
            printf "     "
            printf "     " >> informebn.txt
            printf "     " >> informecolor.txt
            fi
            if [[ $i -eq $saltos ]]; then
                for (( t = 0; t < $memRestante; t++ )); do
                    printf ""$RS███""
                    printf "|||" >> informebn.txt
                    printf ""$RS███"" >> informecolor.txt
                done
                printf "███  $mem_total"
                printf "|||  $mem_total" >> informebn.txt
                printf "███  $mem_total" >> informecolor.txt
            else
                for (( t = 0; t < $longitud; t++ )); do
                    printf ""$RS███""
                    printf "|||" >> informebn.txt
                    printf ""$RS███"" >> informecolor.txt
                done
            fi
            printf "\n"
            printf "\n" >> informebn.txt
            printf "\n" >> informecolor.txt
            for (( t = 0; t < $longitud; t++ )); do
                if [[ $t -eq 0 ]] && [[ $i -eq 0 ]]; then
                    printf "    |  0"
                    printf "    |  0" >> informebn.txt
                    printf "    |  0" >> informecolor.txt
                else if [[ $t -eq 0 ]]; then
                    printf "    |"
                    printf "    |" >> informebn.txt
                    printf "    |" >> informecolor.txt
                
                else if [[ $t -eq $longitud-1 ]] && [[ $i -eq $saltos-1 ]]; then
                    printf "%3s" " "
                    printf "%3s" " " >> informebn.txt
                    printf "%3s" " " >> informecolor.txt
                else
                    printf "   "
                    printf "   " >> informebn.txt
                    printf "   " >> informecolor.txt
                fi
                fi
                fi
            done
        done
    fi

    echo " "
    printf "\n"
    echo "    |P01|"
    cecho " BT |   |T=0 " $RS
    cecho "    |  0|" $RS
    echo " " >> informebn.txt
    printf "\n" >> informebn.txt
    echo "    |P01|" >> informebn.txt
    cecho " BT |   |T=0 "  >> informebn.txt
    cecho "    |  0|"  >> informebn.txt
    echo " " >> informecolor.txt
    printf "\n" >> informecolor.txt
    echo "    |P01|" >> informecolor.txt
    cecho " BT |   |T=0 " $FWHT >> informecolor.txt
    cecho "    |  0|" $FWHT >> informecolor.txt
	
	
    #read enter
    if [[ ${evento[$tiempo]} -eq 1 && $enterLuego -eq 1 && $ejecucion -eq 1 ]] ; then
#########################3
	cecho " Pulse enter para continuar..." $RS
	read enter
########################
	elif [[ ${evento[$tiempo]} -eq 1 && $enterLuego -eq 1 && $ejecucion -eq 2 ]] ; then
	sleep $tiempousuario
	
	elif [[ ${evento[$tiempo]} -eq 1 && $enterLuego -eq 1 && $ejecucion -eq 3 ]] ; then
	cecho " " $RS
	 
fi
fi
 



# -----------------------------------------------------------------------------
#     B U C L E       P R I N C I P A L     D E L       A L G O R I T M O
#
# Bucle principal, desde tiempo=0 hasta que finalice la ejecución
# del último proceso, cuando la variable finalprocesos sea 0.
#
# -----------------------------------------------------------------------------

tiempo=0
ordenTiempo=0
parar_proceso="NO"
cpu_ocupada="NO"

finalprocesos=$nprocesos

temp_wait=0
temp_resp=0
temp_ret=0

realizadoAntes=0

while [ "$parar_proceso" == "NO" ]
do
    imprimirYa="NO"
    timepoAux=`expr $tiempo + 1`


let memVacia=0
for (( i = 0; i < ${#posMem[@]}; i++ )); do
    if [[ "${posMem[$i]}" == "0" ]]; then
        memVacia=$(( memVacia + 1))
        #echo $i
    fi
done



printf "\n"
imprimirYa="NO"
imprimirT="NO"
 

    # -----------------------------------------------------------
    #	E N T R A D A      E N       C O L A
    # -----------------------------------------------------------
    # Si el momento de entrada del proceso coincide con el reloj
    # marcamos el proceso como preparado en encola()
    # -----------------------------------------------------------

    for (( i=0; i<$nprocesos; i++ )) #Bucle que pone en cola los procesos.
    do
       if [[ ${entradaAuxiliar[$i]} == $tiempo ]]
       then
        encola[$i]=1
        nollegado[$i]=0
        if [[ ${evento[$tiempo]} -eq 1 ]] ; then
        procesoTiempo="${ordenEntrada[$i]}"
        imprimirYa="SI"
        if [[ "$imprimirT" == "NO" ]]; then
            echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"
			echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"  >> informebn.txt
			echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"   >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" $RS
          echo " " >> informebn.txt
          echo " T = $tiempo            Memoria Total = $memVacia" >> informebn.txt
          echo " " >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" >> informecolor.txt $FYEL
          imprimirT="SI"
        fi
         cecho " El proceso ${ordenEntrada[$i]} ha entrado en la cola." $RS
         printf " El proceso %s ha entrado en la cola.\n" $tiempo ${ordenEntrada[$i]} >> informebn.txt
         cecho " El proceso ${ordenEntrada[$i]} ha entrado en la cola." >> informecolor.txt 
         fi
         elif [[ ${entradaAuxiliar[$i]} -lt $tiempo ]] ; then
           nollegado[$i]=0
        else
           nollegado[$i]=1
        fi
    done

    # ------------------------------------------------------------
    #    G U A R D A D O      E N       M E M O R I A
    # ------------------------------------------------------------
    # Si un proceso está encola(), intento guardarlo en memoria
    # si cabe.
    # Si lo consigo, lo marco como listo enmemoria().
    # ------------------------------------------------------------

#Comprobamos si ha terminado un proceso de ejecutarse



for (( i=0; i<$nprocesos; i++ )) #Bucle que comprueba si el proceso en ejecución ha finalizado.
do
    if [[ ${enejecucion[$i]} -eq 1 ]]
    then
        if [ ${ejecucionAuxiliar[$i]} -eq 0 ]
        then
            enejecucion[$i]=0
            enmemoria[$i]=0
		mem_libre=`expr $mem_libre + ${tamemoryAuxiliar[$i]}` #Recuperamos la memoria que ocupaba el proceso
        mem_libre66=$(( mem_libre66 + ${tamemoryAuxiliar[$i]} ))
		if [[ ${evento[$tiempo]} -eq 1 ]] ; then
        # cecho "procTiempo = ${procTiempo[$ordenTiempo]}" $FRED
        procesoTiempo="${ordenEntrada[$i]}"
        if [[ "$imprimirT" == "NO" ]]; then
            echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"
			echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"  >> informebn.txt
			echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"   >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" $RS
          echo " " >> informebn.txt
          echo " T = $tiempo             Memoria Total = $memVacia" >> informebn.txt
          echo " " >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" >> informecolor.txt $FYEL
          imprimirT="SI"
        fi
         cecho " El proceso ${ordenEntrada[$i]} ha terminado su ejecución. $mem_libre M restantes" $FBLE
         for (( p = 0; p < ${#posMem[@]} ; p++ )); do
             if [[ "${posMem[$p]}" == "${ordenEntrada[$i]}" ]]; then
                 posMem[$p]=0
             fi
         done
         posMemInicial[$i]=0
         posMemFinal[$i]=0
         procTerminado[$nprocTerminados]="${ordenEntrada[$i]}"
         nprocTerminados=$(( nprocTerminados + 1 ))
         printf " El proceso %s ha terminado su ejecución.\n" ${ordenEntrada[$i]} >> informebn.txt
         cecho " El proceso ${ordenEntrada[$i]} ha terminado su ejecución. $mem_libre M restantes" >> informecolor.txt $FBLE
         imprimirYa="SI"
     fi
     cpu_ocupada=NO
     finalprocesos=`expr $finalprocesos - 1`
     terminados[$i]=1
     enejecucion[$i]=0

		#Miramos ahora que ha acabado un proceso el siguiente que se ejecutará
		indice_aux=-1
      temp_aux=9999999

      for (( j=0; j<$nprocesos; j++ ))
      do
        if [[ ${enmemoria[$j]} -eq 1 ]]
        then
           if [ ${ejecucionAuxiliar[$j]} -lt $temp_aux ]
           then
                    		indice_aux=$j                 	   #Proceso de ejecución más corta hasta ahora
                    		temp_aux=${ejecucionAuxiliar[$j]}      #Tiempo de ejecución menor hasta ahora
                       fi
                   fi
               done

   		if ! [ "$indice_aux" -eq -1 ]       #Hemos encontrado el proceso más corto
           then
             		enejecucion[$indice_aux]=1       #Marco el proceso para ejecutarse
            		pausados[$indice_aux]=0         #Quitamos el estado pausado si el proceso lo estaba anteriormente
	    		cpu_ocupada=SI                   #La CPU está ocupada por un proceso
           fi

           realizadoAntes=1


		#temp_waitAux=`expr $temp_waitAux + ${temp_wait[$i]}`
		#temp_retAux=`expr $temp_retAux + ${temp_ret[$i]}`
    fi
fi
done






for (( i=0; i<$nprocesos; i++ ))
do
  if [[ ${encola[$i]} -eq 1 ]] && [[ ${bloqueados[$i]} -eq 0 ]]
  then
   mem_libre=`expr $mem_libre - ${tamemoryAuxiliar[$i]}`
   if [[ $mem_libre -lt "0" ]] ; then
    reubica=0
      if [[ ${evento[$tiempo]} -eq 1 ]] ; then
        procesoTiempo="${ordenEntrada[$i]}"
        if [[ "$imprimirT" == "NO" ]]; then
            echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"
			echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"  >> informebn.txt
			echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"   >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" $FWHT
          echo " " >> informebn.txt
          echo " T = $tiempo            Memoria Total = $memVacia" >> informebn.txt
          echo " " >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" >> informecolor.txt $FYEL
          imprimirT="SI"
        fi
       cecho " El proceso ${ordenEntrada[$i]} no cabe en memoria en este momento." $FRED
       printf " El proceso %s no cabe en memoria en este momento.\n" ${ordenEntrada[$i]} >> informebn.txt
       cecho " El proceso ${ordenEntrada[$i]} no cabe en memoria en este momento." >> informecolor.txt $FRED
       imprimirYa="SI"
   fi
   mem_libre=`expr $mem_libre + ${tamemoryAuxiliar[$i]}`
	     for (( j=$i; j<$nprocesos; j++ )) #Bucle para bloquear los procesos
	     do
          bloqueados[$j]=1
      done
      if [[ ${evento[$tiempo]} -eq 1 ]] ; then
        procesoTiempo="${ordenEntrada[$i]}"
        if [[ "$imprimirT" == "NO" ]]; then
            echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"
            echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"  >> informebn.txt
            echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"   >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" $FWHT
          echo " " >> informebn.txt
          echo " T = $tiempo            Memoria Total = $memVacia" >> informebn.txt
          echo " " >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" >> informecolor.txt $FYEL
          imprimirT="SI"
        fi
         cecho " Se bloquean todos los procesos siguientes, para que el siguiente en entrar a memoria sea ${ordenEntrada[$i]}." $FRED
         printf " Se bloquean todos los procesos siguientes, para que el siguiente en entrar a memoria sea %s. \n" ${ordenEntrada[$i]} >> informebn.txt
         cecho " Se bloquean todos los procesos siguientes, para que el siguiente en entrar a memoria sea ${ordenEntrada[$i]}." >> informecolor.txt $FRED
         imprimirYa="SI"
     fi
 elif [[ ${bloqueados[$i]} -eq 0 ]] ; then
    reubica=1
  if [[ ${evento[$tiempo]} -eq 1 ]] ; then
    metido="NO"
    hueco="NO"
    espacioEncontrado="NO"
    counter=0
    


    #Buscamos el hueco donde lo vamos a meter

        #Buscamos donde empieza el posible hueco
        while [[ "$hueco" == "NO" ]]; do
            if [[ "${posMem[$counter]}" == "0" ]]; then
             pos1=$counter
             hueco="SI"
            #echo "entra en hueco| counter = $counter "
            else
            counter=$(( counter + 1 ))
            fi
        done
        #echo "counter = $counter"
        let espacioLibre=0
        let k=$counter
        #Calculamos el espacio disponible en el hueco.

         while [[ "$espacioEncontrado" == "NO" ]] && [[ "$hueco" == "SI" ]]; do
                    while [[ "${posMem[$k]}" == "0" ]]; do 
                        espacioLibre=$(( espacioLibre + 1 ))
                        k=$(( k + 1 ))

                    done

                    #Comprobamos si el hueco encontrado posee le tamaño suficiente para albergar al proceso
                    if [[ $espacioLibre -ge ${tamemoryAuxiliar[$i]} ]]; then
                        #echo "libre: $espacioLibre - Mem: ${tamemoryAuxiliar[$i]}"
                        espacioEncontrado="SI"

                    elif [[ $espacioLibre -lt ${tamemoryAuxiliar[$i]} ]]; then
                        hueco="NO"
                    fi

        done
        #Comprobamos si reubicando entraría en memoria
        let mem_libreR=0
        for (( r = 0; r < ${#posMem[@]}; r++ )); do
            if [[ "${posMem[$r]}" == "0" ]]; then
                mem_libreR=$(( mem_libreR + 1 ))
            fi
        done
        if [[ $mem_libreR -ge ${tamemoryAuxiliar[$i]} ]] && [[ "$hueco" == "NO" ]]; then
            let counterAux=0
            #Ordenamos el vector
            puntero=0
            new_array=()
            new_array1=()

            for value in "${posMem[@]}"; do
                [[ $value != 0 ]] && new_array+=($value)
            done
            posMem=("${new_array[@]}")
            for value in "${posMem[@]}"; do
                [[ $value != 1 ]] && new_array1+=($value)
            done
            posMem=("${new_array1[@]}")
            #Volvemos a poner 0 en las posiciones vacias
            for (( r = ${#posMem[@]}; r < $mem_total+1; r++ )); do
                posMem[$r]=0
            done
            #Ponemos un 1 en la primera posicion fuera del array de memoria
            let posMem[-1]=1

            #Buscamos el hueco
            let y=0
            let espacioLibre=0
            while [[ "${posMem[$y]}" != "0" ]]; do
                y=$(( y + 1))
            #echo 4
            done
                
            pos1="$y"

            for (( r = $y; r < ${#posMem[@]}; r++ )); do
                espacioLibre=$(( espacioLibre + 1 ))
            done

            #Colocamos las nuevas posiciones de inicio y fin de cada proceso
            let counterAux=0
            let controlPrimerP=0
            for (( r = 0; r < ${#posMem[@]}; r++ )); do
                if [[ "${posMem[$r]}" == "${posMem[$r+1]}" ]]; then
                    counterAux=$(( counterAux + 1))
                else
                    for (( u = 0; u < $nprocesos; u++ )); do
                        if [[ "${posMem[$r]}" == "${ordenEntrada[$u]}" ]]; then
                            posMemFinal[$u]=$(( counterAux ))
                            counterAux=$(( counterAux + 1))
                            if [[ $controlPrimerP -eq 0 ]]; then
                                posMemInicial[$u]=$(( ${posMemFinal[$u]} - ${tamemoryAuxiliar[$u]} ))
                                let controlPrimerP=1
                            else
                                posMemInicial[$u]=$(( ${posMemFinal[$u]} - ${tamemoryAuxiliar[$u]} + 1 ))
                            fi
                        fi
                    done
                fi

            done
        fi
        for (( r = 0; r < $nprocesos; r++ )); do
            if [[ "${posMemInicial[$r]}" == "-1" ]]; then
                posMemInicial[$r]=0
            fi
        done

        #Comprobamos si el hueco encontrado posee le tamaño suficiente para albergar al proceso
        if [[ $espacioLibre -ge ${tamemoryAuxiliar[$i]} ]]; then
            posMemInicial[$i]=$pos1
            posMemFinal[$i]=$(( posMemInicial[$i] + tamemoryAuxiliar[$i] - 1 ))
            tamannno=$(( posMemFinal[$i] - posMemFinal[$i] ))
            for (( b=$pos1; b<$pos1+${tamemoryAuxiliar[$i]}; b++ )); do
                posMem[$b]=${ordenEntrada[$i]}
            done
            mem_libre66=$(( mem_libre66 - ${tamemoryAuxiliar[$i]} ))
            metido="SI"
        fi


     procesoTiempo="${ordenEntrada[$i]}"
     if [[ "$imprimirT" == "NO" ]]; then
         echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"
         echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"  >> informebn.txt
         echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"   >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" $FWHT
          echo " " >> informebn.txt
          echo " T = $tiempo            Memoria Total = $memVacia" >> informebn.txt
          echo " " >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" >> informecolor.txt $FYEL
          imprimirT="SI"
        fi
     cecho " El proceso ${ordenEntrada[$i]} entra en memoria. $mem_libre M restante." $FCYN

     printf " El proceso %s entra en memoria. %s M restante.\n" ${ordenEntrada[$i]} $mem_libre >> informebn.txt
     cecho " El proceso ${ordenEntrada[$i]} entra en memoria. $mem_libre M restante." >> informecolor.txt $FCYN
     imprimirYa="SI"
 fi
 enmemoria[$i]=1
 realizadoAntes=0
	     for (( j=0; j<$nprocesos; j++ )) #Reestablecemos cual es el proceso que debe entrar a ejecucion
	     do
          enejecucion[$j]=0
      done
	     encola[$i]=0     #Este proceso ya solo estará en memoria, ejecutandose o habrá acabado
	     for (( j=0; j<$nprocesos; j++ )) #Bucle para desbloquear los procesos
	     do
          bloqueados[$j]=0
      done
  fi
fi
done


    # ----------------------------------------------------------------
    #  P L A N I F I C A D O R    D E    P R O C E S O S   -  S R P T
    # ----------------------------------------------------------------
    #
    # Si tenemos procesos listos enmemoria(), ejecutamos el que
    # corresponde en función del criterio de planificación
    # que en este caso es el que tenga una ejecución más corta de
    # todos los procesos. Se puede expulsar a un proceso de la CPU
    # aunque no haya acabado.
    #
    # ----------------------------------------------------------------

    # ------------------------------------------------------------
    # Si un proceso finaliza su tiempo de ejecucion, lo ponemos a
    # 0 en la lista de enejecucion y liberamos la memoria que
    # estaba ocupando
    # ------------------------------------------------------------

    if [[ $realizadoAntes -eq 0 ]] ; then
        indice_aux=-1
        temp_aux=9999999

        for (( i=0; i<$nprocesos; i++ ))  #Establecemos que proceso tiene menor tiempo de ejecucion de todos los que se encuentran en memoria
        do
            if [[ ${enmemoria[$i]} -eq 1 ]]
            then
                if [ ${ejecucionAuxiliar[$i]} -lt $temp_aux ]
                then
                    indice_aux=$i                 	   #Proceso de ejecución más corta hasta ahora
                    temp_aux=${ejecucionAuxiliar[$i]}      #Tiempo de ejecución menor hasta ahora
                fi
            fi
        done


        if ! [ "$indice_aux" -eq -1 ]       #Hemos encontrado el proceso más corto
        then
            enejecucion[$indice_aux]=1       #Marco el proceso para ejecutarse
            pausados[$indice_aux]=0         #Quitamos el estado pausado si el proceso lo estaba anteriormente
	    cpu_ocupada=SI                   #La CPU está ocupada por un proceso
    fi
fi
    # ----------------------------------------------------------------
    # Bucle que establece si un proceso estaba en ejecución y ha
    # pasado a estar en espera, pausado.
    # ----------------------------------------------------------------

    for (( i=0; i<$nprocesos; i++ ))
    do
        if [[ ${enmemoria[$i]} -eq 1 ]] && [[ ${ejecucionAuxiliar[$i]} -lt ${tejecucion[$i]} ]] && [[ ${enejecucion[$i]} -eq 0 ]] ; then
          pausados[$i]=1
          enejecucion[$i]=0
        
          if [[ ${evento[$tiempo]} -eq 1 ]] ; then
            if [[ "$imprimirT" == "NO" ]]; then
           echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"
           echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"  >> informebn.txt
           echo " SRPT - Según necesidades - Memoria No Continua - Reubicable"   >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" $FWHT
          echo " " >> informebn.txt
          echo " T = $tiempo            Memoria Total = $memVacia" >> informebn.txt
          echo " " >> informecolor.txt
          cecho " T = $tiempo            Memoria Total = $memVacia" >> informecolor.txt $FYEL
          imprimirT="SI"
        fi
              cecho " El proceso ${ordenEntrada[$i]} está pausado." $FMAG
              procesoTiempo="${ordenEntrada[$i]}"
              printf " El proceso ${ordenEntrada[$i]} está pausado.\n" >> informebn.txt $i
              cecho " El proceso ${ordenEntrada[$i]} está pausado." >> informecolor.txt $FMAG
              imprimirYa="SI"
          fi
      fi
  done


#ESTADO DE CADA PROCESO
#Modificamos los valores de los arrays, restando de lo que quede<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#ESTADO DE CADA PROCESO EN EL TIEMPO ACTUAL Y HALLAMOS LAS VARIABLES. (Las cuentas se realizaran tras imprimir.)

for (( i=0; i<$nprocesos; i++ ))
do
 if [[ ${nollegado[$i]} -eq 1 ]] ; then
   estado[$i]="Fuera del sistema"
        #temp_wait[$i]=`expr ${temp_wait[$i]} + 0` #No hace falta poner la suma, es solo para una mejor interpretación
    fi

    if [[ ${encola[$i]} -eq 1 ]] && [[ ${bloqueados[$i]} -eq 1 ]] ; then
       estado[$i]="En espera"
        #temp_wait[$i]=`expr ${temp_wait[$i]} + 1`
	#temp_ret[$i]=`expr ${temp_ret[$i]} + 1`
fi

if [[ ${enmemoria[$i]} -eq 1 ]] && [[ ${enejecucion[$i]} -eq 1 ]] ; then
	estado[$i]="En ejecucion"
elif [[ ${enmemoria[$i]} -eq 1 ]] && [[ ${pausados[$i]} -eq 1 ]] ; then
	estado[$i]="Pausado"
elif [[ ${enmemoria[$i]} -eq 1 ]] ; then
	estado[$i]="En memoria"
fi

if [[ ${terminados[$i]} -eq 1 ]] ; then
	estado[$i]="Terminado"
    fi
done

#Ponemos el estado del siguiente que se vaya a ejecutar (si algún proceso ha terminado) "En ejecucion"<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#SUMAR EL SEGUNDO DEL CICLO ANTES DE PONER ESTE ESTADO
    if [ "$finalprocesos" -eq 0 ] #En caso de que finalprocesos sea 0, se termina con el programa.
        then parar_proceso=SI
fi

# --------------------------------------------------------------------
#   D I B U J O    D E    L A    T A B L A    D E    D A T O S
# --------------------------------------------------------------------

#PARA QUE EN EL PROGRAMA SE REALICE EL DIBUJO DEBE SUCEDER UN EVENTO.
#Los eventos suceden cuando se realiza un cambio en los estados de cualquiera de los procesos.

#Además de esto, los tiempos T.ESPERA, T.RESPUESTA y T.RESTANTE solo se mostrarán en la tabla cuando el estado del proceso sea distinto de "No ha llegado".
#Para realizar esto hacemos un bucle que pase por todos los procesos que compruebe si el estado nollegado() es 0 y para cada uno de los tiempos, si se debe mostrar se guarda el tiempo, si no se mostrará un guión

#CUADRAR LAS TABLAS.


if [[ ${evento[$tiempo]} -eq 1 && "$imprimirYa" == "SI" ]] ; then
    #Nos aseguramos de no imprimir niongun proceso que ya haya terminado.
    for (( i = 0; i < $nprocesos; i++ )); do
        if [[ "${estado[$i]}" == "Terminado" ]]; then
            for (( p = 0; p < ${#posMem[@]} ; p++ )); do
             if [[ "${posMem[$p]}" == "${ordenEntrada[$i]}" ]]; then
                 posMem[$p]=0
             fi
         done
        fi
    done


    #cecho "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |    T.ESPERA   |   T.RETORNO   |  T.RESTANTE   |    ESTADO     |" $FYEL
    cecho " ┌─────┬─────┬─────┬─────┬──────┬──────┬──────┬──────┬──────┬───────────────────┐ " $RS
    cecho " │ Ref │ Tll │ Tej │ Mem │ Tesp │ Tret │ Trej │ Mini │ Mfin │ ESTADO            │ " $RS
    cecho " ├─────┼─────┼─────┼─────┼──────┼──────┼──────┼──────┼──────┼───────────────────┤ " $RS

    for (( i=0; i<$nprocesos; i++ ))
    do
      if [[ ${nollegado[$i]} -eq 1 ]] ; then
		printf "$RS │" 
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}"
        printf "$RS │" 
        printf " " 
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%-18s" "${estado[$i]}" 
        printf "$RS│\n" 
        #printf "$RS |------------------------------------------------------------------------------|\n" 
   elif [[ ${nollegado[$i]} -eq 0 ]] && [[ ${enejecucion[$i]} -eq 1 ]] ; then
		printf "$RS │" 
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}"
        printf "$RS │" 
        printf " " 
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${posMemInicial[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${posMemFinal[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%-18s" "${estado[$i]}"
        printf "$RS│\n" 
        #printf "$RS |------------------------------------------------------------------------------|\n" 
        procEnEjecucion="${ordenEntrada[$i]}"
        procTiempo[$tiempo]="${ordenEntrada[$i]}"
       #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   ${posMemInicial[$i]}    ${posMemFinal[$i]}    ${estado[$i]}\n" 
   elif [[ ${terminados[$i]} -eq 1 ]] ; then
		printf "$RS │" 
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}"
        printf "$RS │" 
        printf " " 
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "-" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%-18s" "${estado[$i]}"
        printf "$RS│\n" 
        #printf "$RS |------------------------------------------------------------------------------|\n" 
       #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   0    0    ${estado[$i]}\n"  
  elif [[ ${enmemoria[$i]} -eq 1 ]] && [[ ${pausados[$i]} -eq 1 ]] ; then
		printf "$RS │" 
        printf " ${colores[$i]}${ordenEntrada[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}"
        printf "$RS │" 
        printf " " 
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${posMemInicial[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${posMemFinal[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%-18s" "${estado[$i]}"
        printf "$RS│\n" 
        #printf "$RS |------------------------------------------------------------------------------|\n" 
        #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   ${posMemInicial[$i]}    ${posMemFinal[$i]}      ${estado[$i]}\n" 
elif [[ ${enmemoria[$i]} -eq 1 ]] || [[ ${encola[$i]} -eq 1 ]]; then
		printf "$RS │" 
	    printf " ${colores[$i]}${ordenEntrada[$i]}" 
	    printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}"
        printf "$RS │" 
        printf " " 
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${posMemInicial[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%4s" "${posMemFinal[$i]}" 
        printf "$RS │" 
        printf " "
        printf "${colores[$i]}%-18s" "${estado[$i]}"
        printf "$RS│\n" 
        #printf "$RS |------------------------------------------------------------------------------|\n"  
       #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   ${posMemInicial[$i]}    ${posMemFinal[$i]}    ${estado[$i]}\n" 
fi
enterLuego=1
done
      printf "$RS └─────┴─────┴─────┴─────┴──────┴──────┴──────┴──────┴──────┴───────────────────┘\n" 
#printf ""$blanco"---------------------------------------------------------------------------------------------------------------------------------\n"
mediaTEspera=0
mediaTRetorno=0
nprocT=0
nprocR=0
printf ""$RS""

# Los tiempos de ejecucion los hace mal, no muestra correctamente los decimales, unicamente los redondea.
for (( i = 0; i < $nprocesos; i++ )); do
    if ! [[ ${temp_wait[$i]} -eq 0 ]]; then
        nprocT=$(( nprocT + 1 ))
        mediaTEspera=$(( mediaTEspera + ${temp_wait[$i]} ))
    fi
    if ! [[ ${temp_ret[$i]} -eq 0 ]]; then
        nprocR=$(( nprocT + 1 ))
        mediaTRetorno=$(( mediaTRetorno + ${temp_ret[$i]} ))
    fi
done
if [[ $nprocT -eq 0 ]]; then
    printf " Tiempo Medio Espera = 0\t"
else
    printf ' Tiempo Medio Espera = %.2f\t' $(( mediaTEspera / $nprocT ))
fi
if [[ $nprocR -eq 0 ]]; then
    printf " Tiempo Medio de Retorno = 0\n"
else
    printf ' Tiempo Medio Retorno = %.2f\n' $(( mediaTRetorno / $nprocR ))
fi


echo " "


j=0
k=0
cont=0
posPrevia=0



for (( i=$posPrevia; i<$nprocesos; i++ ))
do
    if [[ ${enmemoria[$i]} -eq 1 ]]; then
        enmemoriavec[$cont]=$i
        cont=$[ cont + 1 ]
        if [[ $reunbica -eq 1 ]]; then
            if [[ ${guardados[0]} -eq $i ]]; then
                pos_inicio[$i]=0
                pos_final[$i]=$[ ${tamemoryAuxiliar[$i]} ]
                mem_aux=`expr $mem_aux - ${tamemoryAuxiliar[$i]}`
                pos_aux=${pos_final[$i]}
            else
                pos_inicio[$i]=$[pos_aux+1]
                pos_final[$i]=`expr $mem_aux - ${tamemoryAuxiliar[$i]}`
                pos_aux=${pos_final[$i]}
            fi
        fi
    fi
done





j=0
k=0
columns=`tput cols`
memAImprimir=$(( mem_total66 * 3 ))
memAImprimir=$(( memAImprimir + 10 ))
if [[ $memAImprimir -lt $columns ]]; then
    todoOK="SI"
else
    todoOK="NO"
    let aImprimir=$memAImprimir/$columns
fi
partirImpresion="NO"
if [[ $memAImprimir -lt $columns ]]; then
    partirImpresion="NO"
        printf "    |"
        for (( i = $posPrevia; i < ${#posMem[@]}-1; i++ )); do
            if [[ "${posMem[$i]}" = "0" ]]; then
                printf "   "
            else
                if [[ "${posMem[$i]}" != "${posMem[$i-1]}" ]]; then
                    for (( t = 0; t < $nprocesos; t++ )); do
                    if [[ "${posMem[$i]}" == "${ordenEntrada[$t]}" ]]; then
                        colorProcesoAImprimir=${colores[$t]}
                    fi
                done
                printf "$colorProcesoAImprimir${posMem[$i]}"
                else
                    printf "   "
                fi
            fi
        done
	printf "$RS|"
    printf "\n"


    col=0
    aux=0
     
        printf "$RS BM |"
        for (( i = $posPrevia; i < $mem_total; i++ )); do
            if [[ "${posMem[$i]}" == "0" ]]; then
                printf "$RS███"
            else
                colorProcesoAImprimir=""
                for (( t = 0; t < $nprocesos; t++ )); do
                    if [[ "${posMem[$i]}" == "${ordenEntrada[$t]}" ]]; then
                        colorProcesoAImprimir=${colores[$t]}
                    fi
                done
                printf "$colorProcesoAImprimir███"
            fi
        done


    printf "$RS|M=$mem_total\n"




    memBMImprimir=0
    YA="NO"
    #Barra 3 - Posiciones de memoria dinales de cada proceso  
        printf "$RS    |"
        for (( i = 0; i < ${#posMem[@]}-1; i++ )); do #Sería -1 pero para cuadrar el valor final de la memoria, debemos de poner el -2. Sino sale descuadrado por una unidad = 3
                    for (( o = 0; o < $nprocesos; o++ )); do
                        if [[ "${posMem[$i]}" == "${ordenEntrada[$o]}" ]]; then
                            procImprimir=$o                         
                        fi
                    done
            if [[ $i -eq 0 ]]; then
                printf "  0"
            else if [[ "${posMem[$i]}" == "0" ]]; then
                if [[ "${posMem[$i]}"  != "${posMem[$i-1]}" && "$YA" = "NO" ]]; then
                    memBMImprimir=$(( memBMImprimir + 1 ))
                    printf "%3s" "$memBMImprimir"
                    YA="SI"
                else
                    memBMImprimir=$(( memBMImprimir + 1 ))
                    printf "%3s" " "
                fi
                 else
                if [[ "${posMem[$i]}" == "${posMem[$i-1]}" ]]; then
                    memBMImprimir=$(( memBMImprimir + 1 ))
                    printf "   "
                else
                    memBMImprimir=$(( memBMImprimir + 1 ))
                    printf "%3s" "${posMemInicial[$procImprimir]}"
                    YA="NO"
                fi
            fi

            fi
        done
        printf "$RS|"

    #) | fmt -w$columns


        printf "\n"
        printf "\n"
else
        partirImpresion="SI"
        posPrevia=0
        memRestante=$memAImprimir
        saltos=0

        #Determinamos el numero de saltos que tiene que realizar, completando el tamaño del terminal y dejando un espacio a la derecha
        while [[ $memRestante -gt $columns ]]; do
            memRestante=$(( $memRestante - $columns ))
            saltos=$(( saltos + 1 ))
            #echo "memRestante = $memRestante -> saltos = $saltos"
        done
        memRestante=$(( $memRestante ))
        memRestante=$(( $memRestante / 3 ))

        columns1=$(( $columns - 6 ))
        ggg=$(( $columns1 % 3 ))
        
        if [[ $ggg -eq 0  ]]; then
            longitud=$(( $columns1 / 3 ))
            memRestante=$(( $memRestante - 1 ))
        else 
            memRestante=$(( $memRestante + $ggg - 1 ))
            longitud=$(( $columns1 / 3 ))
            longitud=$(( $longitud - 1 ))
        fi
        #echo "longitud = $longitud"

        temp1=0
        temp2=0
        temp3=0
        memBMImprimir=0
        YA="NO"
        lastIMM="0"

        for (( p = 0; p <= $saltos; p++ )); do

                if [[ $p -eq 0 ]]; then
                printf "    |"
                else
                    printf "     "
                fi
                if [[ $p -eq $saltos ]]; then
                    for (( i = 0; i < $memRestante; i++ )); do
                        if [[ "${posMem[$temp1]}" = "0" ]]; then
                            printf "   "
                        else
                            if [[ "${posMem[$temp1]}" != "${posMem[$temp1-1]}" ]]; then
                                for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            if ! [[ "${posMem[$temp1]}" == "1" ]]; then
                            printf "$colorProcesoAImprimir${posMem[$temp1]}"
                            fi
                            else
                                printf "   "
                            fi
                        fi
                        temp1=$(( temp1 + 1 ))
                    done
                else
                    for (( i = 0; i < $longitud; i++ )); do
                        if [[ "${posMem[$temp1]}" = "0" ]]; then
                            printf "   "
                        else
                            if [[ "${posMem[$temp1]}" != "${posMem[$temp1-1]}" ]]; then
                                for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            if ! [[ "${posMem[$temp1]}" == "1" ]]; then
                            printf "$colorProcesoAImprimir${posMem[$temp1]}"
                            fi
                            else
                                printf "   "
                            fi
                        fi
                        temp1=$(( temp1 + 1 ))
                    done
                fi

        printf "\n"


        col=0
        aux=0
                if [[ $p -eq 0 ]]; then
                            printf "$RS BM |"
                            else
                    printf "     "
                fi

                if [[ $p -eq $saltos ]]; then
                    for (( i = 0; i < $memRestante; i++ )); do
                        if [[ "${posMem[$temp2]}" == "0" ]]; then
                            printf "$RS███"
                        else
                            colorProcesoAImprimir=""
                            for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            printf "$colorProcesoAImprimir███"
                        fi
                        temp2=$(( temp2 + 1 ))
                    done
                else
                    for (( i = 0; i < $longitud; i++ )); do
                        if [[ "${posMem[$temp2]}" == "0" ]]; then
                            printf "$RS███"
                        else
                            colorProcesoAImprimir=""
                            for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            printf "$colorProcesoAImprimir███"
                        fi
                        temp2=$(( temp2 + 1 ))
                    done
                fi
            if [[ $p -eq $saltos ]]; then
        printf "%4s" " $mem_total"
        fi
        printf "\n"

        #Barra 3 - Posiciones de memoria dinales de cada proceso  
                if [[ $p -eq 0 ]]; then
                printf "$RS    |"
                else
                    printf "     "
                fi

            if [[ $p -eq $saltos ]]; then
                for (( i = 0; i < $memRestante; i++ )); do
                    for (( o = 0; o < $nprocesos; o++ )); do
                            if [[ "${posMem[$temp3]}" == "${ordenEntrada[$o]}" ]]; then
                                procImprimir=$o                         
                            fi
                    done
                    if [[ $p -eq 0 ]] && [[ $i -eq 0 ]]; then
                        printf "  0"
                    else if [[ "${posMem[$temp3]}" = "0" ]]; then
                        if [[ "${posMem[$temp3]}" != "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" "$memBMImprimir"
                        else
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " "
                        fi
                    else
                        if [[ "${posMem[$temp3]}" == "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " "
                        else
                            if ! [[ "$lastIMM" == "${posMemInicial[$procImprimir]}" ]]; then
                                #statements
                                memBMImprimir=$(( memBMImprimir + 1 ))
                                printf "%3s" "${posMemInicial[$procImprimir]}"
                                lastIMM="${posMemInicial[$procImprimir]}"
                            fi
                            
                            
                        fi
                    fi

                    fi
                    temp3=$(( temp3 + 1 ))
            done
            else
                for (( i = 0; i < $longitud; i++ )); do
                    for (( o = 0; o < $nprocesos; o++ )); do
                            if [[ "${posMem[$temp3]}" == "${ordenEntrada[$o]}" ]]; then
                                procImprimir=$o                         
                            fi
                    done
                    if [[ $p -eq 0 ]] && [[ $i -eq 0 ]]; then
                        printf "  0"
                    else if [[ "${posMem[$temp3]}" = "0" ]]; then
                        if [[ "${posMem[$temp3]}" != "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" "$memBMImprimir"
                        else
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " "
                        fi
                    else
                        if [[ "${posMem[$temp3]}" == "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " "
                        else
                            if ! [[ "$lastIMM" == "${posMemInicial[$procImprimir]}" ]]; then
                                #statements
                                memBMImprimir=$(( memBMImprimir + 1 ))
                                printf "%3s" "${posMemInicial[$procImprimir]}"
                                lastIMM="${posMemInicial[$procImprimir]}"
                            fi
                            
                            
                        fi
                    fi

                    fi
                    temp3=$(( temp3 + 1 ))
            done
            fi

        
        printf "\n"

        done
        
fi


empieza=${entradaAuxiliar[0]}

#BARRA DE TIEMPO
previoYa="NO"
lastYa="NO"
partirTiempo="NO"
temp=0

#####################################################################
for (( i = 0; i < $nprocesos; i++ )); do
    if [[ "${estado[$i]}" == "Terminado" ]]; then
        procQueMarcanComoTerminados[$temp]="${ordenEntrada[$i]}"
        temp=$(( temp + 1 ))
    fi
done

for (( i = 0; i < $nprocesos; i++ )); do
    tocaImprimir[$i]=0
done
for (( i = $empieza; i < $tiempo; i++ )); do
    if [[ "${procTiempo[$i]}" == "0" && "$previoYa" == "NO" ]]; then
        procPrevio=$(( i - 1 ))
        previoYa="SI"
    fi
done
for (( i = $tiempo; $empieza < i; i-- )); do
    if [[ "${procTiempo[i]}" == "0" && "$lastYa" == "NO" ]]; then
        procLast=$(( i + 1 ))
        lastYa="SI"
    fi
done
if [[ "$previoYa" == "SI" && "$lastYa" == "SI" ]]; then
    for (( i = $procPrevio; i < $procLast ; i++ )); do
        procTiempo[$i]="${procTiempo[$procPrevio]}"
    done
fi
arrayAux3=() #Inicializar array
posAux=""
#Buscamos si no ha terminado ningun proceso y no ha sido referenciado
for (( i = 0; i < ${#procQueMarcanComoTerminados[@]}; i++ )); do
    if [[ ! " ${procTerminado[@]} " =~ " ${procQueMarcanComoTerminados[$i]} " ]]; then
        posAux="${procQueMarcanComoTerminados[$i]}"
    fi
done

echo "" > diff.txt
for (( k = 0; k < $nprocesos; k++ )); do
    echo "procTerminadoOK - ${procTerminado[$k]} || procTerminadosTotal - ${procQueMarcanComoTerminados[$k]} || Diff - $posAux" >> diff.txt
done
#Si ha encontrado un proceso, la varible no esta vacia
for (( i = 0; i < $nprocesos; i++ )); do
    if [[ "$posAux" == "${ordenEntrada[$i]}" ]]; then
        for (( k = $tiempo-1; k > ${temp_ret[$i]}; k-- )); do
            procTiempo[$k]=0
        done
    fi
done

#####################################################################




tamannoTiempo=$(( ${#posProcesoTiempo[@]} * 3 ))
tamannoTiempo=$(( $tiempo * 3 ))
tamannoTiempo=$(( $tamannoTiempo + 5 ))
    procTiempo[-1]="$procesoTiempo"
    impreso=0
if [[ $tamannoTiempo -lt $columns1 ]]; then
#Primera linea
    echo " "
    printf "    |"
    for (( i = 0; i <= $tiempo; i++ )); do
        if [[ "${procTiempo[$i]}" == "0" ]]; then
            printf "   "
        else if [[ "${procTiempo[$i]}" == "${procTiempo[$i-1]}" ]]; then
                printf "   "
            else
            for (( t = 0; t < $nprocesos; t++ )); do
                if [[ "${procTiempo[$i]}" == "${ordenEntrada[$t]}" ]]; then
                    colorProcTiempo=${colores[$t]}
                fi
            done
            printf "$colorProcTiempo${procTiempo[$i]}"
            tocaImprimir[$i]=1
            lastTiempo="${procTiempo[$i]}"
        fi
        fi
    done
    printf "$RS|"
    printf ""$RS""
    printf "\n"

    #Segunda linea

    printf " BT |"
    for (( i = 0; i <= $tiempo; i++ )); do
        if [[ "${procTiempo[$i]}" == "0" ]]; then
            printf "$RS███"
        else
            for (( t = 0; t < $nprocesos; t++ )); do
                if [[ "${procTiempo[$i]}" == "${ordenEntrada[$t]}" ]]; then
                    colorProcTiempo=${colores[$t]}
                fi
            done
            printf "$colorProcTiempo███"
        fi
    done
    printf "$RS|T=$tiempo\n"
    #printf ""$RS""
    #printf "\n"

    #Tercera linea
    re='^[1-9]+$'

    for (( i = $tiempoAnterior+1; i <= $tiempo; i++ )); do
        if [[ $i -lt $tiempo ]]; then
            posProcesoTiempo[$i]=0
        else
            posProcesoTiempo[$i]=$(( tiempo ))
        fi
        #echo $i
    done


    printf "    |"
    for (( i = 0; i < ${#posProcesoTiempo[@]}; i++ )); do
        if [[ $i -eq 0 ]]; then
            printf "%3s" "$i"
        else
        if [[ ${tocaImprimir[$i]} -eq 0 ]]; then
            printf "   "
        else if [[ ${tocaImprimir[$i]} -eq 1 ]]; then
           printf "%3s" "${posProcesoTiempo[$i]}"
        fi
    fi
        fi
    done
    printf "$RS|"
    echo " "
     #for (( i = 0; i < ${#posProcesoTiempo[@]}; i++ )); do  
      #  echo "T = $tiempo -> i: $i -> ${tocaImprimir[$i]}" 
     #done                                                   
    tiempoAnterior=$tiempo
else
        partirTiempo="SI"
        nIteraciones=1
        posPrevia=0
        tiempoRestante=$tamannoTiempo
        tiempoRRR=$tamannoTiempo
        saltos=0
        imprimirTiempoFinal=0
        #Determinamos el numero de saltos que tiene que realizar, completando el tamaño del terminal y dejando un espacio a la derecha
        columns1=$(( $columns - 6 )) #Ancho del que disponemos para imprimir
        while [[ $tiempoRestante -gt $columns1 ]]; do
            tiempoRestante=$(( $tiempoRestante - $columns1 ))
            saltos=$(( saltos + 1 ))
            #echo "memRestante = $memRestante -> saltos = $saltos"
        done

        calcTemp=$(( $columns1 % 3 ))
        
        if [[ $calcTemp -eq 0 ]]; then
            longitud=$(( $columns1 / 3 ))
            longitud=$(( $longitud - 1 ))
            longitudExtra=$(( $saltos * 3 ))
            tiempoRestante=$(( $tiempoRestante + $longitudExtra ))
            if [[ $tiempoRestante -gt $columns1 ]]; then
                saltos=$(( saltos + 1 ))
                tiempoRestante=$(( $tiempoRestante - $columns1 ))
            fi
        else
            columns1=$(( $columns1 - $calcTemp ))
            longitud=$(( $columns1 / 3 ))
            longitud=$(( $longitud - 1 ))
            longitudExtra=$(( $saltos * 3 ))
            tiempoRestante=$(( $tiempoRestante + $longitudExtra ))
            if [[ $tiempoRestante -gt $columns1 ]]; then
                saltos=$(( saltos + 1 ))
                tiempoRestante=$(( $tiempoRestante - $columns1 ))
            fi
            tiempoRestante=$(( $tiempoRestante - 9 ))

        fi

        calcTemp=$(( $tiempoRestante % 3 ))
        if [[ $calcTemp -eq 0 ]]; then
            tiempoRestante=$(( $tiempoRestante / 3 ))
            nIteraciones=$(( $nIteraciones + 2 ))
            tiempoRestante=$(( $tiempoRestante + $nIteraciones ))
        else
            tiempoRestante=$(( $tiempoRestante / 3 ))
            tiempoRestante=$(( $tiempoRestante ))
        fi
        for (( p = 0; p < $nprocesos; p++ )); do
            if [[ "${estado[$p]}" == "En ejecucion" ]]; then
                procEnEjecucion="${ordenEntrada[$p]}"
            fi
        done


        nblancos=$(( ${entradaAuxiliar[0]} + 1 ))
        nblancosImpresos=0
        temp1=0
        temp2=0
        temp3=0
        primera=0
        
            
    for (( p = 0; p <= $saltos; p++ )); do
            echo " "
                
            if [[ $p -eq 0 ]]; then
            printf "    |"
            else
                    printf "     "
            fi

            if [[ $p -eq $saltos ]]; then
                for (( i = 0; i < $tiempoRestante; i++ )); do
                    if [[ "${procTiempo[$temp1]}" == "0" ]]; then
                        printf "%3s" " "
                    else if [[ "${procTiempo[$temp1]}" == "${procTiempo[$temp1-1]}" ]]; then
                        printf "%3s" " "
                        
                    else
                        for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "${procTiempo[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}
                            fi
                        done
                        
                        printf "$colorProcTiempo${procTiempo[$temp1]}"
                        ultimoImpresoTiempo="${procTiempo[$temp1]}"
                        tocaImprimir[$temp1]=1
                        lastTiempo="${procTiempo[$temp1]}"
                    fi
                    fi
                    temp1=$(( temp1 + 1 ))
                    impreso=$(( impreso + 1 ))
                done
                if [[ "$ultimoImpresoTiempo" != "$procEnEjecucion" ]]; then
                    for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "$procEnEjecucion" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}
                            fi
                    done
                    printf "$colorProcTiempo$procEnEjecucion"
                fi
            else
                for (( i = 0; i < $longitud; i++ )); do
                    if [[ "${procTiempo[$temp1]}" == "0" ]]; then
                        printf "%3s" " "
                    else if [[ "${procTiempo[$temp1]}" == "${procTiempo[$temp1-1]}" ]]; then
                        printf "%3s" " "
                        
                    else
                        for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "${procTiempo[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}
                            fi
                        done
                        
                        printf "$colorProcTiempo${procTiempo[$temp1]}"
                        tocaImprimir[$temp1]=1
                        lastTiempo="${procTiempo[$temp1]}"
                        ultimoImpresoTiempo="${procTiempo[$temp1]}"
                    fi
                    fi
                    temp1=$(( temp1 + 1 ))
                    impreso=$(( impreso + 1 ))
                done
            fi
        printf "$RS|"
        printf ""$RS""
        printf "\n"

        #Segunda linea
            
        if [[ $p -eq 0 ]]; then
        printf " BT |"
        else
                    printf "     "
        fi
        if [[ $p -eq $saltos ]]; then
            for (( i = 0; i < $tiempoRestante; i++ )); do
                if [[ "${procTiempo[$temp2]}" == "0" ]]; then
                    printf "$RS███"
                    nblancosImpresos=$(( nblancosImpresos + 1 ))
                    if [[ $nblancosImpresos -eq $nblancos+1 ]]; then
                      primera=$(( $saltos * $longitud + $i ))
                    fi
                else
                    for (( t = 0; t < $nprocesos; t++ )); do
                        if [[ "${procTiempo[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                            colorProcTiempo=${colores[$t]}
                        fi
                    done
                    printf "$colorProcTiempo███"
                fi
                temp2=$(( temp2 + 1 ))
            done
            if [[ "$ultimoImpresoTiempo" != "$procEnEjecucion" ]]; then
                    for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "$procEnEjecucion" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}                                
                            fi
                    done
                    printf "$colorProcTiempo███"
                    imprimirTiempoFinal=1
                    
                fi
        else
            for (( i = 0; i < $longitud; i++ )); do
                if [[ "${procTiempo[$temp2]}" == "0" ]]; then
                    printf "$RS███"
                    nblancosImpresos=$(( nblancosImpresos + 1 ))
                    if [[ $nblancosImpresos -eq $nblancos+1 ]]; then
                      primera=$(( $p * $longitud + $i ))            
                    fi
                else
                    for (( t = 0; t < $nprocesos; t++ )); do
                        if [[ "${procTiempo[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                            colorProcTiempo=${colores[$t]}
                        fi
                    done
                    printf "$colorProcTiempo███"
                fi
                temp2=$(( temp2 + 1 ))
            done
        fi
        printf "$RS|T=$tiempo\n"
        #printf ""$RS""
        #printf "\n"

        #Tercera linea
        re='^[1-9]+$'

        for (( i = $tiempoAnterior+1; i <= $tiempo; i++ )); do
            if [[ $i -lt $tiempo ]]; then
                posProcesoTiempo[$i]=0
            else
                posProcesoTiempo[$i]=$(( tiempo ))
            fi
            #echo $i
        done
        
        if [[ $p -eq 0 ]]; then
        printf "    |"
        else
                    printf "     "
        fi
        if [[ $p -eq $saltos ]]; then
             for (( i = 0; i < $tiempoRestante; i++ )); do
                if [[ $i -eq 0 ]] && [[ $p -eq 0 ]]; then
                    printf "%3s" "$temp3"
                else
                if [[ ${tocaImprimir[$temp3]} -eq 0 ]]; then
                    if [[ $temp3+1 -eq $primera ]]; then
                      primera=$(( primera - 1 ))
                      printf "%3s" "$primera"
                    else
                    printf "   "
                    fi
                else if [[ ${tocaImprimir[$temp3]} -eq 1 ]]; then
                   printf "%3s" "${posProcesoTiempo[$temp3]}"
                fi
                fi
                fi
                temp3=$(( temp3 + 1 ))
            done
            if [[ $imprimirTiempoFinal -eq 1 ]]; then
                    printf "%3s" "$tiempo"
                fi
        else
            for (( i = 0; i < $longitud; i++ )); do
                if [[ $i -eq 0 ]] && [[ $p -eq 0 ]]; then
                    printf "%3s" "$temp3"
                else
                if [[ ${tocaImprimir[$temp3]} -eq 0 ]]; then
                    if [[ $temp3+1 -eq $primera ]]; then
                      primera=$(( primera - 1 ))
                      printf "%3s" "$primera"
                    else
                    printf "   "
                    fi
                else if [[ ${tocaImprimir[$temp3]} -eq 1 ]]; then
                   printf "%3s" "${posProcesoTiempo[$temp3]}"
                fi
                fi
                fi
                temp3=$(( temp3 + 1 ))
            done
        fi
    done
    printf "$RS|"
    echo " "
    tiempoAnterior=$tiempo
fi
echo "procTiempo - ${procTiempo[$temp3]} -> procEnEjecucion - $procEnEjecucion" > impresion.txt
for (( i = 0; i < ${#procTiempo[@]}/3; i++ )); do
    echo "$i - ${procTiempo[$i]}" >> impresion.txt
done



#########################################################################################################
#           
#                    A  P A R T I R  D E  A Q U Í  T O D O  E S  D E  F I C H E R O S 
#
#########################################################################################################



if [[ ${evento[$tiempo]} -eq 1 ]] ; then

    echo  -e "\e[0m" 
    echo " " >> informebn.txt
    #cecho "|    PROCESOS   |    T.LLEG.    |     T.EJEC.   |     MEMORIA   |    T.ESPERA   |   T.RETORNO   |  T.RESTANTE   |    ESTADO     |" $FYEL
    cecho " ┌─────┬─────┬─────┬─────┬──────┬──────┬──────┬──────┬──────┬───────────────────┐ " >> informebn.txt $RS
    cecho " │ Ref │ Tll │ Tej │ Mem │ Tesp │ Tret │ Trej │ Mini │ Mfin │ ESTADO            │ " >> informebn.txt $RS
    cecho " ├─────┼─────┼─────┼─────┼──────┼──────┼──────┼──────┼──────┼───────────────────┤ " >> informebn.txt $RS

    for (( i=0; i<$nprocesos; i++ ))
    do
      if [[ ${nollegado[$i]} -eq 1 ]] ; then
		printf "$RS │" >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " ">> informebn.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " ">> informebn.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " ">> informebn.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "-" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "-" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "-" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "-" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "-" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informebn.txt
        printf "$RS│\n" >> informebn.txt
        #printf "$RS |------------------------------------------------------------------------------|\n" 
   elif [[ ${nollegado[$i]} -eq 0 ]] && [[ ${enejecucion[$i]} -eq 1 ]] ; then
		printf "$RS │" >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${posMemInicial[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${posMemFinal[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informebn.txt
        printf "$RS│\n" >> informebn.txt
        #printf "$RS |------------------------------------------------------------------------------|\n" 
        procEnEjecucion="${ordenEntrada[$i]}"
        procTiempo[$tiempo]="${ordenEntrada[$i]}"
       #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   ${posMemInicial[$i]}    ${posMemFinal[$i]}    ${estado[$i]}\n" 
   elif [[ ${terminados[$i]} -eq 1 ]] ; then
		printf "$RS │" >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "-" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "-" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informebn.txt
        printf "$RS│\n" >> informebn.txt
        #printf "$RS |------------------------------------------------------------------------------|\n" 
       #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   0    0    ${estado[$i]}\n"  
  elif [[ ${enmemoria[$i]} -eq 1 ]] && [[ ${pausados[$i]} -eq 1 ]] ; then
		printf "$RS │" >> informebn.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${posMemInicial[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${posMemFinal[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informebn.txt
        printf "$RS│\n" >> informebn.txt
        #printf "$RS |------------------------------------------------------------------------------|\n" 
        #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   ${posMemInicial[$i]}    ${posMemFinal[$i]}      ${estado[$i]}\n" 
elif [[ ${enmemoria[$i]} -eq 1 ]] || [[ ${encola[$i]} -eq 1 ]]; then
		printf "$RS │" >> informebn.txt
	    printf " ${colores[$i]}${ordenEntrada[$i]}" >> informebn.txt
	    printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${posMemInicial[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%4s" "${posMemFinal[$i]}" >> informebn.txt
        printf "$RS │" >> informebn.txt
        printf " " >> informebn.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informebn.txt
        printf "$RS│\n" >> informebn.txt
        #printf "$RS |------------------------------------------------------------------------------|\n"  
       #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   ${posMemInicial[$i]}    ${posMemFinal[$i]}    ${estado[$i]}\n" 
fi
enterLuego=1
done
      printf "$RS └─────┴─────┴─────┴─────┴──────┴──────┴──────┴──────┴──────┴───────────────────┘\n" >> informebn.txt
#echo "---------------------------------------------------------------------------------------------------------------------------------" >> informebn.txt
if [[ $nprocT -eq 0 ]]; then
    printf "Tiempo Medio Espera = 0\t" >> informebn.txt
else
    # total66=`echo $mediaTEspera / $nprocT | bc`
    # cecho $total66 $FRED
    printf 'Tiempo Medio Espera = %.2f\t' $(( mediaTEspera / $nprocT )) >> informebn.txt
fi
if [[ $nprocR -eq 0 ]]; then
    printf "Tiempo Medio de Retorno = 0\n" >> informebn.txt
else
    # total66=`echo $mediaTRetorno / $nprocR | bc`
    # cecho $total66 $FRED
    printf 'Tiempo Medio Retorno = %.2f\n' $(( mediaTRetorno / $nprocR )) >> informebn.txt
fi
printf "\n" >> informebn.txt
echo " " >> informebn.txt


j=0
k=0


for (( i=0; i<$nprocesos; i++ ))
do
 if [[ ${enmemoria[$i]} -eq 1 ]] ; then
   	guardados[$j]=$i #Se guardan en cada posición el número del proceso correspondiente <<<<<<<<<<<F A L L O?
	coloresAux[$k]=${colores[$i]}  #<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<F A L L O? Cambiar por k?
	j=`expr $j + 1`
fi
k=`expr $k + 1`
done

j=0
k=0


if [[ "$partirImpresion"  == "NO" ]]; then
# Primera línea, en la que mostramos el nombre del proceso, por debajo de ella se encuentra la representación gráfica de la memoria
printf "    |"  >> informebn.txt
        for (( i = $posPrevia; i < ${#posMem[@]}-1; i++ )); do
            if [[ "${posMem[$i]}" = "0" ]]; then
                printf "   "  >> informebn.txt
            else
                if [[ "${posMem[$i]}" != "${posMem[$i-1]}" ]]; then
                    for (( t = 0; t < $nprocesos; t++ )); do
                    if [[ "${posMem[$i]}" == "${ordenEntrada[$t]}" ]]; then
                        colorProcesoAImprimir=${colores[$t]}
                    fi
                done
                printf "${posMem[$i]}"  >> informebn.txt
                else
                    printf "   "  >> informebn.txt
                fi
            fi
        done

    printf "\n"  >> informebn.txt


    col=0
    aux=0
     
        printf " BM |"  >> informebn.txt
        for (( i = $posPrevia; i < $mem_total; i++ )); do
            if [[ "${posMem[$i]}" == "0" ]]; then
                printf "|||"  >> informebn.txt
            else
                colorProcesoAImprimir=""
                for (( t = 0; t < $nprocesos; t++ )); do
                    if [[ "${posMem[$i]}" == "${ordenEntrada[$t]}" ]]; then
                        colorProcesoAImprimir=${colores[$t]}
                    fi
                done
                printf "███"  >> informebn.txt
            fi
        done

        printf " $mem_total" >> informebn.txt
    printf "\n"  >> informebn.txt




    memBMImprimir=0
    YA="NO"
    #Barra 3 - Posiciones de memoria dinales de cada proceso  
        printf "    |"  >> informebn.txt
        for (( i = 0; i < ${#posMem[@]}-2; i++ )); do #Sería -1 pero para cuadrar el valor final de la memoria, debemos de poner el -2. Sino sale descuadrado por una unidad = 3
                    for (( o = 0; o < $nprocesos; o++ )); do
                        if [[ "${posMem[$i]}" == "${ordenEntrada[$o]}" ]]; then
                            procImprimir=$o                         
                        fi
                    done
            if [[ $i -eq 0 ]]; then
                printf "  0"  >> informebn.txt
            else if [[ "${posMem[$i]}" == "0" ]]; then
                if [[ "${posMem[$i]}"  != "${posMem[$i-1]}" && "$YA" = "NO" ]]; then
                    memBMImprimir=$(( memBMImprimir + 1 ))
                    printf "%3s" "$memBMImprimir"  >> informebn.txt
                    YA="SI"
                else
                    memBMImprimir=$(( memBMImprimir + 1 ))
                    printf "%3s" " "  >> informebn.txt
                fi
                 else
                if [[ "${posMem[$i]}" == "${posMem[$i-1]}" ]]; then
                    memBMImprimir=$(( memBMImprimir + 1 ))
                    printf "   "  >> informebn.txt
                else
                    memBMImprimir=$(( memBMImprimir + 1 ))
                    printf "%3s" "${posMemInicial[$procImprimir]}"  >> informebn.txt
                    YA="NO"
                fi
            fi

            fi
        done
fi
if [[ "$partirImpresion" == "SI" ]]; then
            saltos=0
            memRestante=$memAImprimir
         while [[ $memRestante -gt $columns ]]; do
            memRestante=$(( $memRestante - $columns ))
            saltos=$(( saltos + 1 ))
            #echo "memRestante = $memRestante -> saltos = $saltos"
        done
        memRestante=$(( $memRestante - 3 ))
        memRestante=$(( $memRestante / 3 ))

        columns1=$(( $columns - 6 ))
        ggg=$(( $columns1 % 3 ))
        if [[ $ggg -eq 0  ]]; then
            longitud=$(( $columns1 / 3 ))
        else 
            longitud=$(( $columns1 / 3 ))
            longitud=$(( $longitud - 1 ))
        fi
        #echo "longitud = $longitud"

        temp1=0
        temp2=0
        temp3=0
        memBMImprimir=0
        YA="NO"
        lastIMM="0"

        for (( p = 0; p <= $saltos; p++ )); do

                if [[ $p -eq 0 ]]; then
                printf "    |" >> informebn.txt
                else
                    printf "     " >> informebn.txt
                fi
                if [[ $p -eq $saltos ]]; then
                    for (( i = 0; i < $memRestante; i++ )); do
                        if [[ "${posMem[$temp1]}" = "0" ]]; then
                            printf "   " >> informebn.txt
                        else
                            if [[ "${posMem[$temp1]}" != "${posMem[$temp1-1]}" ]]; then
                                for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            if ! [[ "${posMem[$temp1]}" == "1" ]]; then
                            printf "${posMem[$temp1]}" >> informebn.txt
                            fi
                            else
                                printf "   " >> informebn.txt
                            fi
                        fi
                        temp1=$(( temp1 + 1 ))
                    done
                else
                    for (( i = 0; i < $longitud; i++ )); do
                        if [[ "${posMem[$temp1]}" = "0" ]]; then
                            printf "   " >> informebn.txt
                        else
                            if [[ "${posMem[$temp1]}" != "${posMem[$temp1-1]}" ]]; then
                                for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            if ! [[ "${posMem[$temp1]}" == "1" ]]; then
                            printf "${posMem[$temp1]}" >> informebn.txt
                            fi
                            else
                                printf "   " >> informebn.txt
                            fi
                        fi
                        temp1=$(( temp1 + 1 ))
                    done
                fi

        printf "\n" >> informebn.txt


        col=0
        aux=0
                if [[ $p -eq 0 ]]; then
                            printf " BM |" >> informebn.txt
                            else
                    printf "     " >> informebn.txt
                fi

                if [[ $p -eq $saltos ]]; then
                    for (( i = 0; i < $memRestante; i++ )); do
                        if [[ "${posMem[$temp2]}" == "0" ]]; then
                            printf "|||" >> informebn.txt
                        else
                            colorProcesoAImprimir=""
                            for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            printf "███" >> informebn.txt
                        fi
                        temp2=$(( temp2 + 1 ))
                    done
                else
                    for (( i = 0; i < $longitud; i++ )); do
                        if [[ "${posMem[$temp2]}" == "0" ]]; then
                            printf "|||" >> informebn.txt
                        else
                            colorProcesoAImprimir=""
                            for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            printf "███" >> informebn.txt
                        fi
                        temp2=$(( temp2 + 1 ))
                    done
                fi
            if [[ $p -eq $saltos ]]; then
        printf "%4s" "$mem_total" >> informebn.txt
        fi
        printf "\n" >> informebn.txt

        #Barra 3 - Posiciones de memoria dinales de cada proceso  
                if [[ $p -eq 0 ]]; then
                printf "$RS    |" >> informebn.txt
                else
                    printf "     " >> informebn.txt
                fi

            if [[ $p -eq $saltos ]]; then
                for (( i = 0; i < $memRestante; i++ )); do
                    for (( o = 0; o < $nprocesos; o++ )); do
                            if [[ "${posMem[$temp3]}" == "${ordenEntrada[$o]}" ]]; then
                                procImprimir=$o                         
                            fi
                    done
                    if [[ $p -eq 0 ]] && [[ $i -eq 0 ]]; then
                        printf "  0" >> informebn.txt
                    else if [[ "${posMem[$temp3]}" = "0" ]]; then
                        if [[ "${posMem[$temp3]}" != "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" "$memBMImprimir" >> informebn.txt
                        else
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " " >> informebn.txt
                        fi
                    else
                        if [[ "${posMem[$temp3]}" == "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " " >> informebn.txt
                        else
                            if ! [[ "$lastIMM" == "${posMemInicial[$procImprimir]}" ]]; then
                                #statements
                                memBMImprimir=$(( memBMImprimir + 1 ))
                                printf "%3s" "${posMemInicial[$procImprimir]}" >> informebn.txt
                                lastIMM="${posMemInicial[$procImprimir]}"
                            fi
                            
                            
                        fi
                    fi

                    fi
                    temp3=$(( temp3 + 1 ))
            done
            else
                for (( i = 0; i < $longitud; i++ )); do
                    for (( o = 0; o < $nprocesos; o++ )); do
                            if [[ "${posMem[$temp3]}" == "${ordenEntrada[$o]}" ]]; then
                                procImprimir=$o                         
                            fi
                    done
                    if [[ $p -eq 0 ]] && [[ $i -eq 0 ]]; then
                        printf "  0" >> informebn.txt
                    else if [[ "${posMem[$temp3]}" = "0" ]]; then
                        if [[ "${posMem[$temp3]}" != "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" "$memBMImprimir" >> informebn.txt
                        else
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " " >> informebn.txt
                        fi
                    else
                        if [[ "${posMem[$temp3]}" == "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " " >> informebn.txt
                        else
                            if ! [[ "$lastIMM" == "${posMemInicial[$procImprimir]}" ]]; then
                                #statements
                                memBMImprimir=$(( memBMImprimir + 1 ))
                                printf "%3s" "${posMemInicial[$procImprimir]}" >> informebn.txt
                                lastIMM="${posMemInicial[$procImprimir]}"
                            fi
                            
                            
                        fi
                    fi

                    fi
                    temp3=$(( temp3 + 1 ))
            done
            fi

        
        printf "\n" >> informebn.txt

        done

fi
if [[ "$partirTiempo" == "NO" ]]; then
  echo " " >> informebn.txt
    printf "    |">> informebn.txt
    for (( i = 0; i <= $tiempo; i++ )); do
        if [[ "${procTiempo[$i]}" == "0" ]]; then
            printf "   ">> informebn.txt
        else if [[ "${procTiempo[$i]}" == "${procTiempo[$i-1]}" ]]; then
                printf "   ">> informebn.txt
            else
            
            printf "${procTiempo[$i]}">> informebn.txt
            tocaImprimir[$i]=1
        fi
        fi
    done
    printf "\n" >> informebn.txt

    #Segunda linea

    printf " BT |">> informebn.txt
    for (( i = 0; i <= $tiempo; i++ )); do
        if [[ "${procTiempo[$i]}" == "0" ]]; then
            printf "|||" >> informebn.txt
        else
     
            printf "███" >> informebn.txt
        fi
        
    done
    printf "\n" >> informebn.txt


    printf "    |" >> informebn.txt
    for (( i = 0; i < ${#posProcesoTiempo[@]}; i++ )); do
        if [[ $i -eq 0 ]]; then
            printf "%3s" "$i" >> informebn.txt
            
        else
        if [[ ${tocaImprimir[$i]} -eq 0 ]]; then
            printf "   " >> informebn.txt
        else if [[ ${tocaImprimir[$i]} -eq 1 ]]; then
           printf "%3s" "${posProcesoTiempo[$i]}" >> informebn.txt
        fi
    fi
        fi
    done
    echo " " >> informebn.txt
fi


if [[ "$partirTiempo" == "SI" ]]; then



        posPrevia=0
        tiempoRestante=$tamannoTiempo
        saltos=0

        #Determinamos el numero de saltos que tiene que realizar, completando el tamaño del terminal y dejando un espacio a la derecha
        while [[ $tiempoRestante -gt $columns ]]; do
            tiempoRestante=$(( $tiempoRestante - $columns ))
            saltos=$(( saltos + 1 ))
            #echo "memRestante = $memRestante -> saltos = $saltos"
        done
        tiempoRestante=$(( $tiempoRestante - 3 ))
        tiempoRestante=$(( $tiempoRestante / 3 ))

        columns1=$(( $columns - 6 ))
        cgg=$(( $columns1 % 3 ))
        if [[ $cgg -eq 0  ]]; then
            longitud=$(( $columns1 / 3 ))
        else 
            longitud=$(( $columns1 / 3 ))
            longitud=$(( $longitud - 1 ))
        fi

        nblancos=$(( ${entradaAuxiliar[0]} + 1 ))
        nblancosImpresos=0
        temp1=0
        temp2=0
        temp3=0
        primera=0
        
            
    for (( p = 0; p <= $saltos; p++ )); do
            echo " " >> informebn.txt
                
            if [[ $p -eq 0 ]]; then
            printf "    |" >> informebn.txt
            else
                    printf "     " >> informebn.txt
            fi

            if [[ $p -eq $saltos ]]; then
                for (( i = 0; i < $tiempoRestante; i++ )); do
                    if [[ "${procTiempo[$temp1]}" == "0" ]]; then
                        printf "%3s" " " >> informebn.txt
                    else if [[ "${procTiempo[$temp1]}" == "${procTiempo[$temp1-1]}" ]]; then
                        printf "%3s" " " >> informebn.txt
                        
                    else
                        
                        
                        printf "${procTiempo[$temp1]}" >> informebn.txt
                        ultimoImpresoTiempo="${procTiempo[$temp1]}"
                        tocaImprimir[$temp1]=1
                      
                    fi
                    fi
                    temp1=$(( temp1 + 1 ))
                    impreso=$(( impreso + 1 ))
                done
                if [[ "$ultimoImpresoTiempo" != "$procEnEjecucion" ]]; then
                    for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "$procEnEjecucion" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}
                            fi
                    done
                    printf "$procEnEjecucion" >> informebn.txt
                fi
            else
                for (( i = 0; i < $longitud; i++ )); do
                    if [[ "${procTiempo[$temp1]}" == "0" ]]; then
                        printf "%3s" " " >> informebn.txt
                    else if [[ "${procTiempo[$temp1]}" == "${procTiempo[$temp1-1]}" ]]; then
                        printf "%3s" " " >> informebn.txt
                        
                    else
                        
                        
                        printf "${procTiempo[$temp1]}" >> informebn.txt
                        tocaImprimir[$temp1]=1

                        ultimoImpresoTiempo="${procTiempo[$temp1]}"
                    fi
                    fi
                    temp1=$(( temp1 + 1 ))
                    impreso=$(( impreso + 1 ))
                done
            fi
        printf "\n" >> informebn.txt

        #Segunda linea
            
        if [[ $p -eq 0 ]]; then
        printf " BT |" >> informebn.txt
        else
                    printf "     " >> informebn.txt
        fi
        if [[ $p -eq $saltos ]]; then
            for (( i = 0; i < $tiempoRestante; i++ )); do
                if [[ "${procTiempo[$temp2]}" == "0" ]]; then
                    printf "|||" >> informebn.txt
                    nblancosImpresos=$(( nblancosImpresos + 1 ))
                    if [[ $nblancosImpresos -eq $nblancos+1 ]]; then
                      primera=$(( $saltos * $longitud + $i ))
                    fi
                else
                    for (( t = 0; t < $nprocesos; t++ )); do
                        if [[ "${procTiempo[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                            colorProcTiempo=${colores[$t]}
                        fi
                    done
                    printf "███" >> informebn.txt
                fi
                temp2=$(( temp2 + 1 ))
            done
            if [[ "$ultimoImpresoTiempo" != "$procEnEjecucion" ]]; then
                    for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "$procEnEjecucion" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}
                            fi
                    done
                    printf "███" >> informebn.txt
                    imprimirTiempoFinal=1
                fi
        else
            for (( i = 0; i < $longitud; i++ )); do
                if [[ "${procTiempo[$temp2]}" == "0" ]]; then
                    printf "|||" >> informebn.txt
                    nblancosImpresos=$(( nblancosImpresos + 1 ))
                    if [[ $nblancosImpresos -eq $nblancos+1 ]]; then
                      primera=$(( $p * $longitud + $i ))
                    fi
                else
                   
                    printf "███" >> informebn.txt
                fi
                temp2=$(( temp2 + 1 ))
                
            done
        fi     
        printf "\n" >> informebn.txt

        #Tercera linea


        
        if [[ $p -eq 0 ]]; then
        printf "    |" >> informebn.txt
        else
                    printf "     " >> informebn.txt
        fi
        if [[ $p -eq $saltos ]]; then
             for (( i = 0; i < $tiempoRestante; i++ )); do
                if [[ $i -eq 0 ]] && [[ $p -eq 0 ]]; then
                    printf "%3s" "$temp3" >> informebn.txt
                else
                if [[ ${tocaImprimir[$temp3]} -eq 0 ]]; then
                    if [[ $temp3+1 -eq $primera ]]; then
                      primera=$(( primera - 1 ))
                      printf "%3s" "$primera" >> informebn.txt
                    else
                    printf "   " >> informebn.txt
                    fi
                else if [[ ${tocaImprimir[$temp3]} -eq 1 ]]; then
                   printf "%3s" "${posProcesoTiempo[$temp3]}" >> informebn.txt
                fi
                fi
                fi
                temp3=$(( temp3 + 1 ))
            done
            if [[ $imprimirTiempoFinal -eq 1 ]]; then
                    printf "%3s" "$tiempo" >> informebn.txt
                fi
        else
            for (( i = 0; i < $longitud; i++ )); do
                if [[ $i -eq 0 ]] && [[ $p -eq 0 ]]; then
                    printf "%3s" "$temp3" >> informebn.txt
                else
                if [[ ${tocaImprimir[$temp3]} -eq 0 ]]; then
                    if [[ $temp3+1 -eq $primera ]]; then
                      primera=$(( primera - 1 ))
                      printf "%3s" "$primera" >> informebn.txt
                    else
                    printf "   " >> informebn.txt
                    fi
                else if [[ ${tocaImprimir[$temp3]} -eq 1 ]]; then
                   printf "%3s" "${posProcesoTiempo[$temp3]}" >> informebn.txt
                fi
                fi
                fi
                temp3=$(( temp3 + 1 ))
            done
        fi
    done
    
    echo " " >> informebn.txt
fi





#Metemos los mismos datos al fichero informecolor.txt
    echo " " >> informecolor.txt
    echo  -e "\e[0m" 

    cecho " ┌─────┬─────┬─────┬─────┬──────┬──────┬──────┬──────┬──────┬───────────────────┐ " >> informecolor.txt $RS
    cecho " │ Ref │ Tll │ Tej │ Mem │ Tesp │ Tret │ Trej │ Mini │ Mfin │ ESTADO            │ " >> informecolor.txt $RS
    cecho " ├─────┼─────┼─────┼─────┼──────┼──────┼──────┼──────┼──────┼───────────────────┤ " >> informecolor.txt $RS

    for (( i=0; i<$nprocesos; i++ ))
    do
      if [[ ${nollegado[$i]} -eq 1 ]] ; then
		printf "$RS │" >> informecolor.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " ">> informecolor.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " ">> informecolor.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " ">> informecolor.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "-" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "-" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "-" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "-" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "-" >> informebn.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informebn.txt
        printf "$RS│\n" >> informecolor.txt
        #printf "$RS |------------------------------------------------------------------------------|\n" 
   elif [[ ${nollegado[$i]} -eq 0 ]] && [[ ${enejecucion[$i]} -eq 1 ]] ; then
		printf "$RS │" >> informecolor.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${posMemInicial[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${posMemFinal[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informecolor.txt
        printf "$RS│\n" >> informecolor.txt
        #printf "$RS |------------------------------------------------------------------------------|\n" 
        procEnEjecucion="${ordenEntrada[$i]}"
        procTiempo[$tiempo]="${ordenEntrada[$i]}"
       #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   ${posMemInicial[$i]}    ${posMemFinal[$i]}    ${estado[$i]}\n" 
   elif [[ ${terminados[$i]} -eq 1 ]] ; then
		printf "$RS │" >> informecolor.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "-" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "-" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informecolor.txt
        printf "$RS│\n" >> informecolor.txt
        #printf "$RS |------------------------------------------------------------------------------|\n" 
       #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   0    0    ${estado[$i]}\n"  
  elif [[ ${enmemoria[$i]} -eq 1 ]] && [[ ${pausados[$i]} -eq 1 ]] ; then
		printf "$RS │" >> informecolor.txt
        printf " ${colores[$i]}${ordenEntrada[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${posMemInicial[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${posMemFinal[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informecolor.txt
        printf "$RS│\n" >> informecolor.txt
        #printf "$RS |------------------------------------------------------------------------------|\n" 
        #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   ${posMemInicial[$i]}    ${posMemFinal[$i]}      ${estado[$i]}\n" 
elif [[ ${enmemoria[$i]} -eq 1 ]] || [[ ${encola[$i]} -eq 1 ]]; then
		printf "$RS │" >> informecolor.txt
	    printf " ${colores[$i]}${ordenEntrada[$i]}" >> informecolor.txt
	    printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${entradaAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${tejecucion[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%3s" "${tamemoryAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${temp_wait[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${temp_ret[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${ejecucionAuxiliar[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${posMemInicial[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%4s" "${posMemFinal[$i]}" >> informecolor.txt
        printf "$RS │" >> informecolor.txt
        printf " " >> informecolor.txt
        printf "${colores[$i]}%-18s" "${estado[$i]}" >> informecolor.txt
        printf "$RS│\n" >> informecolor.txt
        #printf "$RS |------------------------------------------------------------------------------|\n"  
       #printf "${colores[$i]} ${ordenEntrada[$i]}   ${entradaAuxiliar[$i]}    ${tejecucion[$i]}    ${tamemoryAuxiliar[$i]}   ${temp_wait[$i]}     ${temp_ret[$i]}    ${ejecucionAuxiliar[$i]}   ${posMemInicial[$i]}    ${posMemFinal[$i]}    ${estado[$i]}\n" 
fi
enterLuego=1
done
      printf "$RS └─────┴─────┴─────┴─────┴──────┴──────┴──────┴──────┴──────┴───────────────────┘\n" >> informecolor.txt
#echo "---------------------------------------------------------------------------------------------------------------------------------" >> informecolor.txt
if [[ $nprocT -eq 0 ]]; then
    printf "Tiempo Medio Espera = 0\t" >> informecolor.txt
else
    # total66=`echo $mediaTEspera / $nprocT | bc`
    # cecho $total66 $FRED
    printf 'Tiempo Medio Espera = %.2f\t' $(( mediaTEspera / $nprocT )) >> informecolor.txt
fi
if [[ $nprocR -eq 0 ]]; then
    printf "Tiempo Medio de Retorno = 0\n" >> informecolor.txt
else
    # total66=`echo $mediaTRetorno / $nprocR | bc`
    # cecho $total66 $FRED
    printf 'Tiempo Medio Retorno = %.2f\n' $(( mediaTRetorno / $nprocR )) >> informecolor.txt
fi
printf "\n" >> informecolor.txt
echo " " >> informecolor.txt


j=0
k=0


for (( i=0; i<$nprocesos; i++ ))
do
 if [[ ${enmemoria[$i]} -eq 1 ]] ; then
    guardados[$j]=$i #Se guardan en cada posición el número del proceso correspondiente <<<<<<<<<<<F A L L O?
    coloresAux[$k]=${colores[$i]}  #<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<F A L L O? Cambiar por k?
    j=`expr $j + 1`
fi
k=`expr $k + 1`
done

j=0
k=0


if [[ "$partirImpresion" == "NO" ]]; then
    # Primera línea, en la que mostramos el nombre del proceso, por debajo de ella se encuentra la representación gráfica de la memoria
    printf "    |" >> informecolor.txt
            for (( i = $posPrevia; i < ${#posMem[@]}-1; i++ )); do
                if [[ "${posMem[$i]}" = "0" ]]; then
                    printf "   " >> informecolor.txt
                else
                    if [[ "${posMem[$i]}" != "${posMem[$i-1]}" ]]; then
                        for (( t = 0; t < $nprocesos; t++ )); do
                        if [[ "${posMem[$i]}" == "${ordenEntrada[$t]}" ]]; then
                            colorProcesoAImprimir=${colores[$t]}
                        fi
                    done
                    printf "$colorProcesoAImprimir${posMem[$i]}" >> informecolor.txt
                    else
                        printf "   " >> informecolor.txt
                    fi
                fi
            done

        printf "\n" >> informecolor.txt


        col=0
        aux=0
         
            printf "$FWHT BM |" >> informecolor.txt
            for (( i = $posPrevia; i < $mem_total; i++ )); do
                if [[ "${posMem[$i]}" == "0" ]]; then
                    printf "$RS███" >> informecolor.txt
                else
                    colorProcesoAImprimir=""
                    for (( t = 0; t < $nprocesos; t++ )); do
                        if [[ "${posMem[$i]}" == "${ordenEntrada[$t]}" ]]; then
                            colorProcesoAImprimir=${colores[$t]}
                        fi
                    done
                    printf "$colorProcesoAImprimir███" >> informecolor.txt
                fi
            done

        printf " $RS$mem_total" >> informecolor.txt
        printf "\n" >> informecolor.txt




        memBMImprimir=0
        YA="NO"
        #Barra 3 - Posiciones de memoria dinales de cada proceso  
            printf "$RS    |" >> informecolor.txt
            for (( i = 0; i < ${#posMem[@]}-2; i++ )); do #Sería -1 pero para cuadrar el valor final de la memoria, debemos de poner el -2. Sino sale descuadrado por una unidad = 3
                        for (( o = 0; o < $nprocesos; o++ )); do
                            if [[ "${posMem[$i]}" == "${ordenEntrada[$o]}" ]]; then
                                procImprimir=$o                         
                            fi
                        done
                if [[ $i -eq 0 ]]; then
                    printf "  0" >> informecolor.txt
                else if [[ "${posMem[$i]}" == "0" ]]; then
                    if [[ "${posMem[$i]}"  != "${posMem[$i-1]}" && "$YA" = "NO" ]]; then
                        memBMImprimir=$(( memBMImprimir + 1 ))
                        printf "%3s" "$memBMImprimir" >> informecolor.txt
                        YA="SI"
                    else
                        memBMImprimir=$(( memBMImprimir + 1 ))
                        printf "%3s" " " >> informecolor.txt
                    fi
                     else
                    if [[ "${posMem[$i]}" == "${posMem[$i-1]}" ]]; then
                        memBMImprimir=$(( memBMImprimir + 1 ))
                        printf "   " >> informecolor.txt
                    else
                        memBMImprimir=$(( memBMImprimir + 1 ))
                        printf "%3s" "${posMemInicial[$procImprimir]}" >> informecolor.txt
                        YA="NO"
                    fi
                fi

                fi
            done
fi

if [[ "$partirImpresion" == "SI" ]]; then
        saltos=0
        memRestante=$memAImprimir
        while [[ $memRestante -gt $columns ]]; do
            memRestante=$(( $memRestante - $columns ))
            saltos=$(( saltos + 1 ))
            #echo "memRestante = $memRestante -> saltos = $saltos"
        done
        memRestante=$(( $memRestante - 3 ))
        memRestante=$(( $memRestante / 3 ))

        columns1=$(( $columns - 6 ))
        ggg=$(( $columns1 % 3 ))
        if [[ $ggg -eq 0  ]]; then
            longitud=$(( $columns1 / 3 ))
        else 
            longitud=$(( $columns1 / 3 ))
            longitud=$(( $longitud - 1 ))
        fi
        #echo "longitud = $longitud"

        temp1=0
        temp2=0
        temp3=0
        memBMImprimir=0
        YA="NO"
        lastIMM="0"

        for (( p = 0; p <= $saltos; p++ )); do

                if [[ $p -eq 0 ]]; then
                printf "    |" >> informecolor.txt
                else
                    printf "     " >> informecolor.txt
                fi
                if [[ $p -eq $saltos ]]; then
                    for (( i = 0; i < $memRestante; i++ )); do
                        if [[ "${posMem[$temp1]}" = "0" ]]; then
                            printf "   " >> informecolor.txt
                        else
                            if [[ "${posMem[$temp1]}" != "${posMem[$temp1-1]}" ]]; then
                                for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            if ! [[ "${posMem[$temp1]}" == "1" ]]; then
                            printf "$colorProcesoAImprimir${posMem[$temp1]}" >> informecolor.txt
                            fi
                            else
                                printf "   " >> informecolor.txt
                            fi
                        fi
                        temp1=$(( temp1 + 1 ))
                    done
                else
                    for (( i = 0; i < $longitud; i++ )); do
                        if [[ "${posMem[$temp1]}" = "0" ]]; then
                            printf "   " >> informecolor.txt
                        else
                            if [[ "${posMem[$temp1]}" != "${posMem[$temp1-1]}" ]]; then
                                for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            if ! [[ "${posMem[$temp1]}" == "1" ]]; then
                            printf "$colorProcesoAImprimir${posMem[$temp1]}" >> informecolor.txt
                            fi
                            else
                                printf "   " >> informecolor.txt
                            fi
                        fi
                        temp1=$(( temp1 + 1 ))
                    done
                fi

        printf "\n" >> informecolor.txt


        col=0
        aux=0
                if [[ $p -eq 0 ]]; then
                            printf "$FWHT BM |" >> informecolor.txt
                            else
                    printf "     " >> informecolor.txt
                fi

                if [[ $p -eq $saltos ]]; then
                    for (( i = 0; i < $memRestante; i++ )); do
                        if [[ "${posMem[$temp2]}" == "0" ]]; then
                            printf "$RS███" >> informecolor.txt
                        else
                            colorProcesoAImprimir=""
                            for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            printf "$colorProcesoAImprimir███" >> informecolor.txt
                        fi
                        temp2=$(( temp2 + 1 ))
                    done
                else
                    for (( i = 0; i < $longitud; i++ )); do
                        if [[ "${posMem[$temp2]}" == "0" ]]; then
                            printf "$RS███" >> informecolor.txt
                        else
                            colorProcesoAImprimir=""
                            for (( t = 0; t < $nprocesos; t++ )); do
                                if [[ "${posMem[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                                    colorProcesoAImprimir=${colores[$t]}
                                fi
                            done
                            printf "$colorProcesoAImprimir███" >> informecolor.txt
                        fi
                        temp2=$(( temp2 + 1 ))
                    done
                fi
            if [[ $p -eq $saltos ]]; then
        printf "%4s" "$mem_total" >> informecolor.txt
        fi
        printf "\n" >> informecolor.txt

        #Barra 3 - Posiciones de memoria dinales de cada proceso  
                if [[ $p -eq 0 ]]; then
                printf "$RS    |" >> informecolor.txt
                else
                    printf "     " >> informecolor.txt
                fi

            if [[ $p -eq $saltos ]]; then
                for (( i = 0; i < $memRestante; i++ )); do
                    for (( o = 0; o < $nprocesos; o++ )); do
                            if [[ "${posMem[$temp3]}" == "${ordenEntrada[$o]}" ]]; then
                                procImprimir=$o                         
                            fi
                    done
                    if [[ $p -eq 0 ]] && [[ $i -eq 0 ]]; then
                        printf "  0" >> informecolor.txt
                    else if [[ "${posMem[$temp3]}" = "0" ]]; then
                        if [[ "${posMem[$temp3]}" != "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" "$memBMImprimir" >> informecolor.txt
                        else
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " " >> informecolor.txt
                        fi
                    else
                        if [[ "${posMem[$temp3]}" == "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " " >> informecolor.txt
                        else
                            if ! [[ "$lastIMM" == "${posMemInicial[$procImprimir]}" ]]; then
                                #statements
                                memBMImprimir=$(( memBMImprimir + 1 ))
                                printf "%3s" "${posMemInicial[$procImprimir]}" >> informecolor.txt
                                lastIMM="${posMemInicial[$procImprimir]}"
                            fi
                            
                            
                        fi
                    fi

                    fi
                    temp3=$(( temp3 + 1 ))
            done
            else
                for (( i = 0; i < $longitud; i++ )); do
                    for (( o = 0; o < $nprocesos; o++ )); do
                            if [[ "${posMem[$temp3]}" == "${ordenEntrada[$o]}" ]]; then
                                procImprimir=$o                         
                            fi
                    done
                    if [[ $p -eq 0 ]] && [[ $i -eq 0 ]]; then
                        printf "  0" >> informecolor.txt
                    else if [[ "${posMem[$temp3]}" = "0" ]]; then
                        if [[ "${posMem[$temp3]}" != "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" "$memBMImprimir" >> informecolor.txt
                        else
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " " >> informecolor.txt
                        fi
                    else
                        if [[ "${posMem[$temp3]}" == "${posMem[$temp3-1]}" ]]; then
                            memBMImprimir=$(( memBMImprimir + 1 ))
                            printf "%3s" " " >> informecolor.txt
                        else
                            if ! [[ "$lastIMM" == "${posMemInicial[$procImprimir]}" ]]; then
                                #statements
                                memBMImprimir=$(( memBMImprimir + 1 ))
                                printf "%3s" "${posMemInicial[$procImprimir]}" >> informecolor.txt
                                lastIMM="${posMemInicial[$procImprimir]}"
                            fi
                            
                            
                        fi
                    fi

                    fi
                    temp3=$(( temp3 + 1 ))
            done
            fi

        
        printf "\n" >> informecolor.txt

        done
fi
if [[ "$partirTiempo" == "NO" ]]; then
  echo " " >> informecolor.txt
    printf "    |" >> informecolor.txt
    for (( i = 0; i <= $tiempo; i++ )); do
        if [[ "${procTiempo[$i]}" == "0" ]]; then
            printf "   " >> informecolor.txt
        else if [[ "${procTiempo[$i]}" == "${procTiempo[$i-1]}" ]]; then
                printf "   " >> informecolor.txt
            else
            for (( t = 0; t < $nprocesos; t++ )); do
                if [[ "${procTiempo[$i]}" == "${ordenEntrada[$t]}" ]]; then
                    colorProcTiempo=${colores[$t]}
                fi
            done
            printf "$colorProcTiempo${procTiempo[$i]}" >> informecolor.txt
            tocaImprimir[$i]=1
        fi
        fi
    done
    printf ""$RS"" >> informecolor.txt
    printf "\n" >> informecolor.txt

    #Segunda linea

    printf " BT |" >> informecolor.txt
    for (( i = 0; i <= $tiempo; i++ )); do
        if [[ "${procTiempo[$i]}" == "0" ]]; then
            printf "$RS███" >> informecolor.txt
        else
            for (( t = 0; t < $nprocesos; t++ )); do
                if [[ "${procTiempo[$i]}" == "${ordenEntrada[$t]}" ]]; then
                    colorProcTiempo=${colores[$t]}
                fi
            done
            printf "$colorProcTiempo███" >> informecolor.txt
        fi
    done
    printf ""$RS"" >> informecolor.txt
    printf "\n" >> informecolor.txt

    #Tercera linea

    printf "    |" >> informecolor.txt
    for (( i = 0; i < ${#posProcesoTiempo[@]}; i++ )); do
        if [[ $i -eq 0 ]]; then
            printf "%3s" "$i" >> informecolor.txt
        else
        if [[ ${tocaImprimir[$i]} -eq 0 ]]; then
            printf "   " >> informecolor.txt
        else if [[ ${tocaImprimir[$i]} -eq 1 ]]; then
           printf "%3s" "${posProcesoTiempo[$i]}" >> informecolor.txt
        fi
    fi
        fi
    done
    echo " " >> informecolor.txt
fi
if [[ "$partirTiempo" == "SI" ]]; then

        posPrevia=0
        tiempoRestante=$tamannoTiempo
        saltos=0

        #Determinamos el numero de saltos que tiene que realizar, completando el tamaño del terminal y dejando un espacio a la derecha
        while [[ $tiempoRestante -gt $columns ]]; do
            tiempoRestante=$(( $tiempoRestante - $columns ))
            saltos=$(( saltos + 1 ))
            #echo "memRestante = $memRestante -> saltos = $saltos"
        done
        tiempoRestante=$(( $tiempoRestante - 3 ))
        tiempoRestante=$(( $tiempoRestante / 3 ))

        columns1=$(( $columns - 6 ))
        cgg=$(( $columns1 % 3 ))
        if [[ $cgg -eq 0  ]]; then
            longitud=$(( $columns1 / 3 ))
        else 
            longitud=$(( $columns1 / 3 ))
            longitud=$(( $longitud - 1 ))
        fi

                nblancos=$(( ${entradaAuxiliar[0]} + 1 ))
        nblancosImpresos=0
        temp1=0
        temp2=0
        temp3=0
        primera=0
        
            
    for (( p = 0; p <= $saltos; p++ )); do
            echo " " >> informecolor.txt
                
            if [[ $p -eq 0 ]]; then
            printf "    |" >> informecolor.txt
            else
                    printf "     " >> informecolor.txt
            fi

            if [[ $p -eq $saltos ]]; then
                for (( i = 0; i < $tiempoRestante; i++ )); do
                    if [[ "${procTiempo[$temp1]}" == "0" ]]; then
                        printf "%3s" " " >> informecolor.txt
                    else if [[ "${procTiempo[$temp1]}" == "${procTiempo[$temp1-1]}" ]]; then
                        printf "%3s" " " >> informecolor.txt
                        
                    else
                        for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "${procTiempo[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}
                            fi
                        done
                        
                        printf "$colorProcTiempo${procTiempo[$temp1]}" >> informecolor.txt
                        ultimoImpresoTiempo="${procTiempo[$temp1]}"
                        tocaImprimir[$temp1]=1
                    fi
                    fi
                    temp1=$(( temp1 + 1 ))
                    impreso=$(( impreso + 1 ))
                done
                if [[ "$ultimoImpresoTiempo" != "$procEnEjecucion" ]]; then
                    for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "$procEnEjecucion" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}
                            fi
                    done
                    printf "$colorProcTiempo$procEnEjecucion" >> informecolor.txt
                fi
            else
                for (( i = 0; i < $longitud; i++ )); do
                    if [[ "${procTiempo[$temp1]}" == "0" ]]; then
                        printf "%3s" " " >> informecolor.txt
                    else if [[ "${procTiempo[$temp1]}" == "${procTiempo[$temp1-1]}" ]]; then
                        printf "%3s" " " >> informecolor.txt
                        
                    else
                        for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "${procTiempo[$temp1]}" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}
                            fi
                        done
                        
                        printf "$colorProcTiempo${procTiempo[$temp1]}" >> informecolor.txt
                        tocaImprimir[$temp1]=1
                        ultimoImpresoTiempo="${procTiempo[$temp1]}"
                    fi
                    fi
                    temp1=$(( temp1 + 1 ))
                    impreso=$(( impreso + 1 ))
                done
            fi
        printf ""$RS"" >> informecolor.txt
        printf "\n" >> informecolor.txt

        #Segunda linea
            
        if [[ $p -eq 0 ]]; then
        printf " BT |" >> informecolor.txt
        else
                    printf "      " >> informecolor.txt
        fi
        if [[ $p -eq $saltos ]]; then
            for (( i = 0; i < $tiempoRestante; i++ )); do
                if [[ "${procTiempo[$temp2]}" == "0" ]]; then
                    printf "$RS███" >> informecolor.txt
                    nblancosImpresos=$(( nblancosImpresos + 1 ))
                    if [[ $nblancosImpresos -eq $nblancos+1 ]]; then
                      primera=$(( $saltos * $longitud + $i ))
                    fi
                else
                    for (( t = 0; t < $nprocesos; t++ )); do
                        if [[ "${procTiempo[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                            colorProcTiempo=${colores[$t]}
                        fi
                    done
                    printf "$colorProcTiempo███" >> informecolor.txt
                fi
                temp2=$(( temp2 + 1 ))
            done
            if [[ "$ultimoImpresoTiempo" != "$procEnEjecucion" ]]; then
                    for (( t = 0; t < $nprocesos; t++ )); do
                            if [[ "$procEnEjecucion" == "${ordenEntrada[$t]}" ]]; then
                                colorProcTiempo=${colores[$t]}
                            fi
                    done
                    printf "$colorProcTiempo███" >> informecolor.txt
                    imprimirTiempoFinal=1
                fi
        else
            for (( i = 0; i < $longitud; i++ )); do
                if [[ "${procTiempo[$temp2]}" == "0" ]]; then
                    printf "$RS███" >> informecolor.txt
                    nblancosImpresos=$(( nblancosImpresos + 1 ))
                    if [[ $nblancosImpresos -eq $nblancos+1 ]]; then
                      primera=$(( $p * $longitud + $i ))
                    fi
                else
                    for (( t = 0; t < $nprocesos; t++ )); do
                        if [[ "${procTiempo[$temp2]}" == "${ordenEntrada[$t]}" ]]; then
                            colorProcTiempo=${colores[$t]}
                        fi
                    done
                    printf "$colorProcTiempo███" >> informecolor.txt
                fi
                temp2=$(( temp2 + 1 ))
            done
        fi
        printf ""$RS"" >> informecolor.txt
        printf "\n" >> informecolor.txt

        #Tercera linea
        re='^[1-9]+$'

        for (( i = $tiempoAnterior+1; i <= $tiempo; i++ )); do
            if [[ $i -lt $tiempo ]]; then
                posProcesoTiempo[$i]=0
            else
                posProcesoTiempo[$i]=$(( tiempo ))
            fi
            #echo $i
        done

        
        if [[ $p -eq 0 ]]; then
        printf "    |" >> informecolor.txt
        else
                    printf "     " >> informecolor.txt
        fi
        if [[ $p -eq $saltos ]]; then
             for (( i = 0; i < $tiempoRestante; i++ )); do
                if [[ $i -eq 0 ]] && [[ $p -eq 0 ]]; then
                    printf "%3s" "$temp3" >> informecolor.txt
                else
                if [[ ${tocaImprimir[$temp3]} -eq 0 ]]; then
                    if [[ $temp3+1 -eq $primera ]]; then
                      primera=$(( primera - 1 ))
                      printf "%3s" "$primera" >> informecolor.txt
                    else
                    printf "   " >> informecolor.txt
                    fi
                else if [[ ${tocaImprimir[$temp3]} -eq 1 ]]; then
                   printf "%3s" "${posProcesoTiempo[$temp3]}" >> informecolor.txt
                fi
                fi
                fi
                temp3=$(( temp3 + 1 ))
            done
            if [[ $imprimirTiempoFinal -eq 1 ]]; then
                    printf "%3s" "$tiempo" >> informecolor.txt
                fi
        else
            for (( i = 0; i < $longitud; i++ )); do
                if [[ $i -eq 0 ]] && [[ $p -eq 0 ]]; then
                    printf "%3s" "$temp3" >> informecolor.txt
                else
                if [[ ${tocaImprimir[$temp3]} -eq 0 ]]; then
                    if [[ $temp3+1 -eq $primera ]]; then
                      primera=$(( primera - 1 ))
                      printf "%3s" "$primera" >> informecolor.txt
                    else
                    printf "   " >> informecolor.txt
                    fi
                else if [[ ${tocaImprimir[$temp3]} -eq 1 ]]; then
                   printf "%3s" "${posProcesoTiempo[$temp3]}" >> informecolor.txt
                fi
                fi
                fi
                temp3=$(( temp3 + 1 ))
            done
        fi
    done
    
    echo " " >> informecolor.txt


fi


fi



fi

    # ----------------------------------------------------------------
    # Incrementamos el contador de tiempos de ejecución y de espera
    # de los procesos y decrementamos el tiempo de ejecución que
    # tiene el proceso que se encuentra en ejecución.
    # ----------------------------------------------------------------
    for (( i=0; i<$nprocesos; i++ )) #Bucle que añade los tiempos de espera y ejecución a cada proceso. También quita el segundo del tiempo de ejecución
    do
        if [[ ${enejecucion[$i]} -eq 1 ]]
        then
           ejecucionAuxiliar[$i]=`expr ${ejecucionAuxiliar[$i]} - 1`
	    temp_ret[$i]=`expr ${temp_ret[$i]} + 1` #Sumamos aquí para evitar que en el ultimo segundo de ejecucion no se sume el segundo de retorno
    fi
done

#ESTADO DE CADA PROCESO
#Modificamos los valores de los arrays, restando de lo que quede<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#ESTADO DE CADA PROCESO EN EL TIEMPO ACTUAL Y HALLAMOS LAS VARIABLES.

for (( i=0; i<$nprocesos; i++ ))
do
 if [[ ${nollegado[$i]} -eq 1 ]] ; then
	#estado[$i]="No ha llegado"
        temp_wait[$i]=`expr ${temp_wait[$i]} + 0` #No hace falta poner la suma, es solo para una mejor interpretación
    fi

    if [[ ${encola[$i]} -eq 1 ]] && [[ ${bloqueados[$i]} -eq 1 ]] ; then
	#estado[$i]="Bloqueado"
    temp_wait[$i]=`expr ${temp_wait[$i]} + 1`
    temp_ret[$i]=`expr ${temp_ret[$i]} + 1`
fi

if [[ ${enmemoria[$i]} -eq 1 ]] && [[ ${enejecucion[$i]} -eq 1 ]] ; then
	#estado[$i]="En ejecucion"
    temp_wait[$i]=`expr ${temp_wait[$i]} + 0`
	#temp_ret[$i]=`expr ${temp_ret[$i]} + 1`   #Si está en ejecución se suma anteriormente.
elif [[ ${enmemoria[$i]} -eq 1 ]] && [[ ${pausados[$i]} -eq 1 ]] ; then
	#estado[$i]="Pausado"
    temp_wait[$i]=`expr ${temp_wait[$i]} + 1`
    temp_ret[$i]=`expr ${temp_ret[$i]} + 1`
elif [[ ${enmemoria[$i]} -eq 1 ]] ; then
	#estado[$i]="En memoria"
    temp_wait[$i]=`expr ${temp_wait[$i]} + 1`
    temp_ret[$i]=`expr ${temp_ret[$i]} + 1`
fi

if [[ ${terminados[$i]} -eq 1 ]] ; then
	#estado[$i]="Terminado"
        temp_wait[$i]=`expr ${temp_wait[$i]} + 0` #No hace falta poner la suma, es solo para una mejor interpretación
    fi
done


#Ponemos todas las posiciones del vector enejecucion a 0, se establecerá qué proceso está a 1 en cada ciclo del programa.

for (( i=0; i<$nprocesos; i++ ))
do
	bloqueados[$i]=0 #También se establecen los procesos bloqueados en cada ciclo.
done
if [[ ${evento[$tiempo]} -eq 1 && $enterLuego -eq 1 && $ejecucion -eq 1 ]] ; then
#########################3
	cecho " Pulse enter para continuar..." $RS
	read enter
########################
	elif [[ ${evento[$tiempo]} -eq 1 && $enterLuego -eq 1 && $ejecucion -eq 2 ]] ; then
	sleep $tiempousuario
	
	elif [[ ${evento[$tiempo]} -eq 1 && $enterLuego -eq 1 && $ejecucion -eq 3 ]] ; then
	cecho " " $RS
fi
    enterLuego=0

    # Incrementamos el reloj
    tiempo=`expr $tiempo + 1`


done
# ---------------------------------------------------z--------------------------
#             F I N       D E L       B U C L E
# -----------------------------------------------------------------------------
tiempofinal=`expr $tiempo - 1`
echo " "
cecho " Tiempo: $tiempofinal  " $FYEL
cecho " Ejecución terminada." $FMAG
cecho "-----------------------------------------------------------" $FRED
echo " "

    
echo " "
echo "procTiempo - ${procTiempo[$temp3]} -> procEnEjecucion - $procEnEjecucion" > impresion.txt
for (( i = 0; i < ${#procTiempo[@]}/3; i++ )); do
    echo "$i - ${procTiempo[$i]}" >> impresion.txt
done
#Ahora lo metemos en el fichero

echo " " >> informebn.txt
echo " Tiempo: $tiempofinal  " >> informebn.txt 
echo " Ejecución terminada." >> informebn.txt
echo "-----------------------------------------------------------" >> informebn.txt
echo " " >> informebn.txt

echo " " >> informecolor.txt
cecho " Tiempo: $tiempofinal  " >> informecolor.txt $FYEL
cecho " Ejecución terminada." >> informecolor.txt $FMAG
cecho "-----------------------------------------------------------" >> informecolor.txt $FRED
echo " " >> informecolor.txt



echo " "


cecho " Final del proceso, puede consultar la salida en el fichero informebn.txt" $FMAG
echo " "
cecho " Pulse enter para las opciones de visualización del fichero informebn.txt..." $RS
read enter

clear
cecho " -----------------------------------------------------"  $FRED
cecho "          V I S U A L I Z A C I Ó N " $FYEL
cecho " -----------------------------------------------------"  $FRED
cecho " 1) Leer el fichero informebn.txt en el terminal" $FYEL
cecho " 2) Leer el fichero informebn.txt en el editor gedit" $FYEL
cecho " 3) Leer el fichero informecolor.txt en el terminal" $FYEL
cecho " 4) Salir y terminar"  $FYEL
cecho " -----------------------------------------------------" $FRED
cecho " "
cecho " Introduce una opcion: " $RS

num=0
continuar="SI"

while [ $num -ne 4 ] && [ "$continuar" == "SI" ]
do
  read num
  case $num in
   "1" )
cat informebn.txt
exit 0
;;

"2" )
gedit informebn.txt
exit 0
;;

"3" )
cat informecolor.txt
exit 0
;;

"4" )
exit 0
;;
*) num=0
cecho "Opción errónea, vuelva a introducir:" $FRED
esac
done




