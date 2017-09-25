# Gautolaga

![Gautolaga](screenshot.png "Gautolaga")

_por Rilke Petrosky <xenomuta@gmail.com>_

Gautolaga es una inteligencia artificial que juega se auto-entrena jugando Galaga via la interfaz Lua del emulador FCEUX para Nintendo.
Esto implementando una red neuronal con los valores de la RAM del Nintendo como entrada y pulsando los botones como salida, corriegiendo el error en base a un propósito definido ( sobrevivir, acumular puntos, etc... ). 

Se puede fácilmente adaptar a cualquier otro juego de NES. 

## Red neuronal

La red neuronal implementa por Gautolaga es una sencilla red secuencial, con varias capas lineares:

### Parametros

Parametros de la Red Neuronal sequencial:

(*) Capa de entrada de 4608 neuronas:
|  - 3x 1536 (valores en la RAM del Nintendo 0x200 - 0x800)
|  - 3x 1 (3 ultimas posiciones X)
|  - 3x 6 (3 ultimas desiciones de 6 botones
|
(*) Funcion Sigmoide
|
(*)-- 3x Capas ocultas lineales de 50 neuronas cada una 
`-(*)-Tangente Hiperbólica 
|
(*) Capa de salida de 6 neuronas: 
    [<] [^] [>] [v] [B] [A]
     1   2   3   4   5   6

### Diagrama

![Diagrama red neuronal](gautolaga-nn.svg "Diagrama")

## Como utilizar

- Abrir FCEUX, cargar el ROM de Galaga y guardar un estado en el slot 1 justo al empezar el Nivel 1
- Cargar el script [gautolaga.lua](./gautolaga.lua)
- Para futuros casos simplemente ejecutar `./run.sh` desde la consola.

## Dependencias

- [FCEUX](http://fceux.com): Emulador de Nintendo Entertainment System
- ROM de Galaga para NES.
- [torch7](https://github.com/torch/torch7): Framework de computación científica para LuaJIT
- [torch/nn](https://github.com/torch/nn): Librería de redes neuronales para Torch

## Notas

- Gautolaga constantemente se entrena en base a la experiencia:
	- Premia el matar ( insectos espaciales ) y la supervivencia.
	- Castiga la pereza ( no moverse ) y la muerte.
	- Sus parámetros de experiencia estan en [experiencia.lua](./experiencia.lua)

		```lua
		-- Parametros de experiencia (Premios y Castigos)
		PEREZA = -.5
		MUERTE = -2.5
		MATAR  = 1.75
		-- Un cobarde tendría un MIEDO = -.1
		-- Un asesino, MATAR = 3.5
		```
	- Desbalancear estos valores puede generar loops infinitos en el entrenamiento (desaparición o explosión del descenso de la degriente).

- Cada estado se almacena en archivos de ~15 MB (`mente-{ciclos}-{puntos}.dat`)
- Se hace un link simbólico al último (`mente.dat`)
- Con poco esfuerzo se pueden encontrar las direcciones apropiadas para otro juego de NES.

## Bugs

- Aveces restaura un estado de muerte inevitable resultando en degradar los pesos de la capa oculta.
- No detecta las pantalla de demo, game over y menu principal, resultando en falso entrenamiento impredecible.

## Mejoras e Ideas para algún día

- Agregar redes neuronales recurrentes LSTM para nocion temporal
- Agregar control completo y desambiguar de __galaga__ para emplearse en cualquier ROM
- Mejor entrenamiento (optimizadores, momentum, ratio de aprendizaje ajustable)
