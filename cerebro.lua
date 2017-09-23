require 'torch'
require 'nn'

--[[ # Red Neuronal sequencial:

- Capa de entrada de 3,856 neuronas:
	- 3,840 => 4 ultimas pantallas de 960 bytes, 32x30 posiciones de cuadros
	- 4		=> 4 ultimas posiciones X
	- 12	=> 4 ultimos comandos de 3 botones [<] [B] [>]

- Capa profunda, 1,000 neuronas:
	- 5x 200 => Tanh()

- Capa de salida de 3 neuronas:
	- Una para cada boton: (izquierda) (fuego) (derecha)
	 
]]
-- parametros
local entradas = 3856
local capaProfunda = {200,5}
local salidas = 3
local ratioAprendizaje = 0.01

-- criterio de aprendizaje (Media Square Error)
-- local criterion = nn.ParallelCriterion()
local criterion = nn.MSECriterion()

-- cerebro
cerebro = nn.Sequential();
cerebro:add(nn.Linear(entradas, capaProfunda[1]))
cerebro:add(nn.Sigmoid())
for i = 1, capaProfunda[2] do
	cerebro:add(nn.Linear(capaProfunda[1], capaProfunda[1]))
	cerebro:add(nn.Tanh())
end
cerebro:add(nn.Linear(capaProfunda[1], salidas))
-- cerebro:add(nn.LogSoftMax())

-- Prepara estado
local ultima_entrada = nil
local salidas_anteriores = torch.DoubleTensor{{0,0,0},{0,0,0},{0,0,0},{0,0,0}}
cerebro:forward(torch.DoubleTensor(entradas))

-- Activa la red neuronal para decide los botones
function piensa (pantalla, posX)
	local botones = {}
	local entrada = torch.DoubleTensor(4*960)
	-- Setea las pantallas anteriores normalizadas
	for i = 1, 4 do
		for j = 1,960 do
			entrada[j+((i-1)*960)] = (pantalla[i]:byte(j) / (5-i))
		end
	end

	-- Agrega las posiciones X anteriores
	for i = 1, 4 do
		entrada = entrada:cat(torch.DoubleTensor{posX[i]} / (5-i))
	end

	-- Agrega las salidas anteriores
	for i = 1, 4 do
		entrada = entrada:cat(torch.DoubleTensor(salidas_anteriores[i]) / (5-i))
	end

	-- Actualiza estados anteriores
	ultima_entrada = entrada
	salida = cerebro:forward(entrada)
	for i = 1, 3 do
		salidas_anteriores[i] = salidas_anteriores[i + 1]
	end
	salidas_anteriores[4] = salida

	-- Prepara botones
	botones['left'] = salida[1] > salida[2]
	botones['right'] = salida[1] < salida[2]
	botones['B'] = salida[3] > 0
	return botones
end

-- Aprende de la experiencia
function aprende (experiencia)
  local mejora = cerebro.output * experiencia
  criterion:forward(cerebro.output, mejora)
  cerebro:zeroGradParameters()
  local error = cerebro:backward(
  	ultima_entrada,
  	criterion:backward(cerebro.output, mejora)
  )
  cerebro:updateParameters(ratioAprendizaje)
end

-- Todo ready
cerebro.listo = true