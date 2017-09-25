require 'torch'
require 'nn'

--[[

Parametros de la Red Neuronal sequencial:

(*) Capa de entrada de 4608 neuronas:
|  - 3x 1536 (valores en la RAM del Nintendo 0x200 - 0x800)
|  - 3x 1 (3 ultimas posiciones X)
|  - 3x 6 (3 ultimas desiciones de 6 botones
|
(*) Funcion Sigmoide
|
(*)-- 5x Capas ocultas lineales de 200 neuronas cada una 
`-(*)-Tangente Hiperbólica 
|
(*) Capa de salida de 6 neuronas: 
    [<] [^] [>] [v] [B] [A]
     1   2   3   4   5   6
]]--
local T = 3 -- evaluar los 3 ultimos estados en el tiempo
local entradas = (1536 + 1 + 6) * T
local capaOculta = { unidades = 50, profundidad = 3 }
local salidas = 6
local ratioAprendizaje = 0.01

-- cerebro
cerebro = nn.Sequential();
cerebro:add(nn.Linear(entradas, capaOculta.unidades))
cerebro:add(nn.Sigmoid())
for i = 1, capaOculta.profundidad do
  cerebro:add(nn.Linear(capaOculta.unidades, capaOculta.unidades))
  cerebro:add(nn.Tanh())
end
cerebro:add(nn.Linear(capaOculta.unidades, salidas))

-- Criterio de aprendizaje por la media error cuadratico medio
local criterion = nn.MSECriterion()

-- Criterio de aprendizaje por entropía cruzada  
-- local criterion = nn.ClassNLLCriterion()

-- Prepara estado
local pasado = { entradas = {}, salidas = {} }
local ultimaEntrada

cerebro:forward(torch.randn(entradas))

-- Activa la red neuronal para decide los botones
function piensa (ram, posX)
  local botones = {}
  local entrada = torch.DoubleTensor(#ram + 1)

  -- Utima RAM
  for i = 1, ram:len() do
    entrada[i] = ram:byte(i) / 255
  end
  -- Utima posición
  entrada[#ram + 1] = posX / 255
  -- Utima salida
  entrada = entrada:cat(cerebro.output)

  -- Setea las pantallas anteriores
  for i = 1, T do
    pasado.entradas[i] = pasado.entradas[i + 1] or entrada
  end

  -- Agrega el pasado degradando su peso por tiempo
  for i = 1, T - 1 do
    entrada = entrada:cat(pasado.entradas[i])
  end
  ultimaEntrada = entrada

  -- Activa red neuronal
  -- print(entrada:size())
  salida = cerebro:forward(entrada)

  -- Actualiza estados anteriores
  for i = 1, T do
    pasado.salidas[i] = pasado.salidas[i + 1] or salida
  end

  -- Retorna los botones
  return {
    left  = salida[1] > 0 and salida[1] > salida[2],
    right = salida[2] > 0 and salida[2] > salida[1],
    up    = salida[3] > 0 and salida[3] > salida[4],
    down  = salida[4] > 0 and salida[4] > salida[3],
    B     = salida[5] > 0,
    A     = salida[6] > 0
  }
end

-- Aprende de la experiencia
local lErr = {}
function aprende (experiencia)
  local mejora = cerebro.output:clone()

  for i = 1, cerebro.output:size(1) do
    if (cerebro.output[i] == cerebro.output:max()) then
      mejora[i] = mejora[i] * experiencia
    else
      mejora[i] = mejora[i] / experiencia
    end
  end
  local err = criterion:forward(cerebro.output, mejora)
  cerebro:zeroGradParameters()
  cerebro:backward(ultimaEntrada, criterion:backward(cerebro.output, mejora))
  cerebro:updateParameters(ratioAprendizaje)
  return err
end

-- Todo ready
cerebro.listo = true