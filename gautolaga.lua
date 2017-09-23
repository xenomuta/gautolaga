--[[

 Gautolaga: 
 Galaga autómata controlado por red neuronal.
 por Rilke Petrosky <xenomuta@gmail.com>

 Dependencias:
 - FCEUX emulador de Nintendo Entertainment System
 - ROM de Galaga para NES
 - torch7: Computación científica en Lua
 - torch-nn: Librería de redes neuronales para Torch

]]
require "cerebro"
require "experiencia"

-- Direcciones de memoria
local MEM_VIVO = 0x200  -- es > 0 al morir
local MEM_MATO = 0x4AF  -- cambia al matar
local MEM_POSX = 0x0203 -- posicion X

-- Variables de estado
local ciclos = 0
local pantalla = {}
local ultimoReset = 0
local ultimoGuardar = os.clock()
local estado = savestate.object(1)
local botones = {}
local posX = {0,0,0,0}
local puntos = 0
local lpuntos = 0
local maxpuntos = 0
local experiencia = 0
local hist_experiencia = {}
local textoBotones = {"left","right","B"}

-- Reinicio de valores
function reinicio (e)
  savestate.load(estado)
  vivo    = memory.readbyte(MEM_VIVO)
  matar   = memory.readbyte(MEM_MATO)
  puntos  = 0
  lpuntos = 0
  botones["left"]  = false
  botones["right"] = false
  botones["B"]     = false
  ultimoReset = emu.framecount()
  ciclos = ciclos + 1
end

-- Colores por Activos/Inactivos
function color (activo)
  if activo then
    return "#11bb22"
  else
    return "#bb1122"
  end
end

-- Avanza el frame del emulador, dibuja texto y pulsa botones
function siguiente ()
  emu.frameadvance()
  joypad.set(1, botones)

  for i = 1, 3 do
    gui.drawtext(5 + ((i-1) * 20), 10, " "..textoBotones[i]:sub(1,1):upper().." ", "white", color(botones[textoBotones[i]]))
  end
  gui.drawtext(75, 10, " Ciclo #"..ciclos.." Puntos: "..puntos.."/"..maxpuntos.." X: "..posX[4].." ", "#ccc", "#333")
  gui.drawline(5, 20, 5, 40, "#777777")
  gui.drawline(5, 30, 60, 30, "#777777")

  local x = 5
  local y = 30
  local xp = false
  for i = 1, #hist_experiencia do
    local lx = x
    local ly = y
    xp = xp or hist_experiencia[i] > 0
    x = 5 + (i * 50 / #hist_experiencia)
    y = 30 - (hist_experiencia[i] * 10)
    gui.drawline(lx, ly, x, y, color(xp))
  end
end

-- Guardar estado
function guardar ()
  -- guarda solo si supero la puntuacion anterior o si ha sobrevivido 10 segundos
  if puntos >= maxpuntos or (os.clock() - ultimoGuardar > 5) then
    savestate.save(estado)
    maxpuntos = math.max(puntos, maxpuntos)
    -- no mas de 1 vez por cada 5 segundos
    if (os.clock() - ultimoGuardar > 5) then
      local mente = {}
      local archivo = "mente-c"..ciclos.."-p"..puntos..".dat"
      mente["cerebro"]=cerebro
      mente["estado"]=torch.IntTensor{maxpuntos, ciclos}
      print("Guardando mente")
      torch.save(archivo, mente, "binary")
      os.execute("ln -sf "..archivo.." mente.dat")
    end
    ultimoGuardar = os.clock()
  end
end

-- Reinicia el estado
reinicio()

-- Espera el Cerebro
while not cerebro.listo do --[[...]] end

-- Carga la ultima "mente" ( cerebro y estado )
if io.open("mente.dat","r") ~= nil then
  print("Cargando mente")
  local mente = torch.load("mente.dat", "binary")
  cerebro   = mente["cerebro"]
  maxpuntos = math.ceil(mente["estado"][1])
  ciclos    = math.ceil(mente["estado"][2])
end

-- Loop principal
experiencia = 0
while true do
  -- Acumula 4 frames y 4 posiciones
  posX[4] = memory.readbyte(MEM_POSX)
  pantalla[4] = memory.readbyterange(0x2000, 960)
  for i = 1, 3 do
    posX[i] = posX[i + 1]
    pantalla[i] = pantalla[i + 1]
  end

  -- Nuevo frame, nueva experiencia ;)
  experiencia = math.tanh(experiencia)

  -- Cuando tengamos los primeros 4 frames listos empezamos
  if pantalla[1] ~= nil and posX[1] ~= nil then
    
    -- Procesa las pantallas y las posiciones X y presiona los botones
    botones = piensa(pantalla, posX)

    -- Avanza el frame
    siguiente()

    -- Actualiza datos de comparación    
    lvivo = vivo
    matar  = memory.readbyte(MEM_MATO)
    vivo  = memory.readbyte(MEM_VIVO) == 0
    movimiento = math.abs(posX[#posX - 1] - posX[#posX]) or 0
    
    -- Premios y Castigos:
    if lvivo and not vivo then
      -- Morir es definitivamente malo
      experiencia = math.min(experiencia, 0) + MUERTE
      if emu.framecount() - ultimoReset > 4 then
          reinicio()
      else
        print("- Posible callejon sin salida. Mucha muerte rápida.")
      end
    elseif matar ~= lmatar then
      -- Matar (insectos espaciales) es muy bueno
      lmatar = matar
      puntos = puntos + 1
      experiencia = math.max(experiencia, 0) + MATAR
      guardar()
    elseif movimiento < 4 then
      -- Ser miedoso es malo
      experiencia = math.min(experiencia, 0) + MIEDO
    else
      -- La pereza tambien es mala
      experiencia = math.min(experiencia, 0) + PEREZA
    end
  
    -- Aprende de la experiencia el 90% de las veces
    if vivo and math.random() <= 0.90 then
      -- altera ligeramente la experiencia para evitar loops infinitos
      aprende(experiencia * math.random())
    end

    -- Histograma de experiencia
    for i = 1, 10 do
      local n = hist_experiencia[i + 1] or (experiencia - math.tanh(experiencia / 4))
      hist_experiencia[i] = n
    end
  end
end
