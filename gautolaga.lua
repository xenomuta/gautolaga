--[[

Gautolaga: 
Galaga autómata controlado por red neuronal

- Rilke Petrosky <xenomuta@gmail.com>

]]
require "cerebro"

-- Premios y Castigos
local MORIR         = -2.8
local SER_VAGO      = -.1
local MATAR         = 1.2
local ROMPER_RECORD = .5

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
function colores (activo)
  if activo then
    return "#11dd22"
  else
    return "#dd1122"
  end
end

-- Avanza el frame del emulador, dibuja texto y pulsa botones
function siguiente ()
  emu.frameadvance()
  for i = 1, 3 do
    gui.drawtext(10, 10 + (i * 10), textoBotones[i], "black", colores(botones[textoBotones[i]]))
  end
  gui.drawtext(10, 60, "Mato: "..matar, "black", colores(lmatar ~= matar))
  gui.drawtext(10, 10, "Ciclos: "..ciclos..", Pts: "..puntos.."/"..maxpuntos.." X: "..posX[4], colores(vivo), "black")
  joypad.set(1, botones)
end

-- Guardar estado
function guardar ()
  -- guarda solo si supero la puntuacion anterior
  if puntos >= maxpuntos then
    savestate.save(estado)
    maxpuntos = math.max(puntos, maxpuntos)
    -- no mas de 1 vez por cada 10 segundos
    if (os.clock() - ultimoGuardar > 10) then
      local mente = {}
      local archivo = "mente-ciclos-"..ciclos.."-puntos-"..puntos.."-.dat"
      mente["cerebro"]=cerebro
      mente["estado"]=torch.IntTensor{maxpuntos,ciclos}
      print("Guardando mente")
      torch.save(archivo, mente, "binary")
      os.execute("ln -sf "..archivo.." mente-ultima")
      ultimoGuardar = os.clock()
    end
  end
end

-- Reinicia el estado
reinicio()

-- Espera el Cerebro
while not cerebro.listo do --[[...]] end

-- Carga la ultima "mente" ( cerebro y estado )
if io.open("mente-ultima","r") ~= nil then
  print("Cargando mente")
  local mente = torch.load("mente-ultima", "binary")
  cerebro   = mente["cerebro"]
  maxpuntos = mente["estado"][1]
  ciclos    = mente["estado"][2]
end

-- Loop principal
while true do
  -- Acumula 4 frames y 4 posiciones
  posX[4] = memory.readbyte(MEM_POSX)
  pantalla[4] = memory.readbyterange(0x2000, 960)
  for i = 1, 3 do
    posX[i] = posX[i + 1]
    pantalla[i] = pantalla[i + 1]
  end

  -- Nuevo frame, nueva experiencia ;)
  experiencia = 0

  -- Cuando tengamos los primeros 4 frames listos empezamos
  if pantalla[1] ~= nil and posX[1] ~= nil then
    
    -- Procesa las pantallas y las posiciones X y presiona los botones
    botones = piensa(pantalla, posX)

    -- Avanza el frame
    siguiente()

    -- Actualiza datos de comparación    
    lvivo = vivo
    lmatar = matar
    matar  = memory.readbyte(MEM_MATO)
    vivo  = memory.readbyte(MEM_VIVO) == 0
    movimiento = math.abs(posX[3] - posX[4])

    -- Premios y Castigos:
    if lvivo and not vivo then
      -- Morir es definitivamente malo
      experiencia = experiencia + MORIR
      if emu.framecount() - ultimoReset > 2 then
        reinicio()
      else
        print("- Posible callejon sin salida. Mucha muerte rápida.")
      end
    elseif movimiento < 3 then
      -- Ser vago es malo
      experiencia = experiencia + (SER_VAGO * (4 - movimiento))
    elseif matar ~= lmatar then
      -- Matar (insectos alienigenas) es muy bueno
      puntos = puntos + 1
      if puntos >= maxpuntos then
        experiencia = experiencia + ROMPER_RECORD
      else
        experiencia = experiencia + MATAR
      end
      guardar()
    else
      -- si nada pasa tambien es malo
      experiencia = experiencia + SER_VAGO
    end
  
    -- Aprende de la experiencia el 90% de las veces
    if vivo and math.random() <= 0.90 then
      aprende(experiencia)
    end
  end
end
