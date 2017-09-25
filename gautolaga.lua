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
local memoria = {
  -- es > 0 al morir
  vida = 0x200,
  -- cambia al matar enemigo
  mato = 0x4AF,
  -- Nuestra posicion X
  posX = 0x203,
  -- posiciones y los estados de los elementos en pantalla
  -- desde = 0x120,
  -- hasta = 0x2f0 - 0x120
  -- Toda la RAM del Nintendo
  desde = 0x200,
  hasta = 0x800 - 0x200 
}

-- Variables de estado
local botones = {}
local posX = 0
local ciclos = 0
local ultimoCiclo = 0
local ultimoGuardar = os.clock()
local puntos = 0
local maxpuntos = 0
local experiencia = 0
local histograma = {}
local matoEnemigo = false
local vivia = false
local muerto = false
local lerr = 0
local err = 0

function log(...)
  for i, v in ipairs(arg) do
    print(("%c[1;32m*%c[37m Gautolaga:%c[0m "):format(0x1b,0x1b,0x1b)..tostring(v))
  end
end

-- Reinicio de estado y valores
function reinicioEstado (tranque)
  if tranque then
    savestate.load(savestate.object(9))
    savestate.save(savestate.object(1))
  else
    savestate.load(savestate.object(1))
    savestate.save(savestate.object(9))
  end
  leeMemoria()
  puntos = 0
  ciclos = ciclos + 1
  ultimoCiclo = os.clock()

  botones = {left=false, right=false, B=false}
end
-- primer estado
savestate.create(9)
savestate.load(savestate.object(9))

-- Lee de memoria posiciones y estados en pantalla
function leeMemoria ()
  local diff = memory.readbyte(memoria.mato)
  matoEnemigo = diff ~= dmato; dmato = diff
  vivia = muerto
  muerto = memory.readbyte(memoria.vida) ~= 0
  posX = memory.readbyte(memoria.posX)
  pantalla = memory.readbyterange(memoria.desde, memoria.hasta)
end

-- Avanza el frame del emulador y actualiza datos de comparación    
function siguiente ()
  emu.frameadvance()
  leeMemoria()
  actualizaStatus()
end

-- Dibuja el status de botones, valores y experiencia
local control = {
  color = {
    lefttrue = "#777777",  
    righttrue = "#777777",  
    uptrue = "#777777",  
    downtrue = "#777777",  
    Btrue = "#ee3322",  
    Atrue = "#ee3322",  
    leftfalse = "#555555",  
    rightfalse = "#555555",  
    upfalse = "#555555",  
    downfalse = "#555555",  
    Bfalse = "#551100",  
    Afalse = "#551100"
  },
  txt = {
    left = 'O',
    right = 'O',
    up = 'O',
    down = 'O',
    B = 'B',
    A = 'A'
  },
  pos = {
    left = {5,25},
    right = {15,25},
    up = {10,20},
    down = {10,30},
    B = {25,25},
    A = {35,25}
  }
}

function actualizaStatus()
  -- Estado de botones
  for boton, activo in pairs(botones) do
    gui.drawtext(control.pos[boton][1],control.pos[boton][2], control.txt[boton]
      , control.color[boton..tostring(activo)], control.color[boton..tostring(activo)])
  end

  gui.opacity(0.75)
  -- Dibuja Histograma de Error red neuronal y Experiencia
  local el = {
    {f = "Err: %4f", v = err, c = "#2ecc71"},
    {f = "Exp: %4f", v = experiencia, c= "#3498db"}
  }
  gui.drawtext(5, 10, ("Ciclo #%d - Puntos: %d/%d, x: %d"):format(ciclos, puntos, maxpuntos, posX), "#ccc", "clear")
  gui.drawline(5, 40, 5, 60, "#7f7f7f", true)
  gui.drawline(5, 50, 50, 50, "#7f7f7f",true)
  gui.opacity(.4)
  for j = 1,2 do
    local x = 5
    local y = 50
    local xp = false
    for i = 1, #histograma do
      local lx = x
      local ly = y
      x = 5 + (i * 45 / #histograma)
      y = 50 - (histograma[i][j] * 10)
      gui.drawline(lx, ly, x, y, el[j].c, true)
    end
    gui.drawtext(10, 50+(10*j), (el[j].f):format(el[j].v), el[j].c, "clear")
  end
  gui.opacity(1)
end

-- Guardar estado
function guardarEstado ()
  -- guarda solo si supero la puntuacion anterior o si ha sobrevivido 10 segundos
  if puntos >= maxpuntos or (os.clock() - ultimoGuardar > 5) then
    savestate.save(savestate.object(1))
    maxpuntos = math.max(puntos, maxpuntos)
    -- no mas de 1 vez por cada 5 segundos
    if (os.clock() - ultimoGuardar > 5 and ultimoGuardar < ultimoCiclo) then
      log("Guardando mente")
      local mente = { cerebro, maxpuntos, ciclos }
      for i = 2,1,-1 do
        os.execute(("/bin/mv mente-%d mente-%d"):format(i,1+i))
      end
      torch.save("mente-1.dat", mente, "binary")
    end
    ultimoGuardar = os.clock()
  end
end

-- Premia
function premia(premio)
  return math.tanh(math.max(experiencia / 2, experiencia) + premio)
end

-- Castiga
function castiga(castigo)
  return math.tanh(math.min(experiencia / 2, experiencia) + castigo)
end

-- Funcion principal
function Gautolaga()
  -- Reinicia el estado
  reinicioEstado()

  -- Carga la ultima "mente" ( cerebro y estado )
  if io.open("mente.dat","r") ~= nil then
    log("Cargando mente")
    cerebro, maxpuntos, ciclos = unpack(torch.load("mente.dat", "binary"))
  end

  -- Espera el Cerebro
  while not cerebro.listo do
  end

  -- Loop principal
  local primerLoop = true
  local loopPrincipal = function ()
    -- No procesar el primer loop
    if primerLoop then
      primerLoop = false
      siguiente()
      return
    end

    -- Procesa las posiciones de los enemigos y el personaje en pantalla
    botones = piensa(pantalla, posX)


    -- Presiona los botones
    joypad.set(1, botones)

    -- Avanza al siguiente frame
    siguiente()

    -- Premios y Castigos:
    if vivia and muerto then
      experiencia = castiga(MUERTE)   -- Morir es definitivamente malo
      if os.clock() - ultimoCiclo > 1 then
        reinicioEstado()
      else
        log("Posible callejon sin salida. Mucha muerte rápida.")
        reinicioEstado(9)
      end
    elseif matoEnemigo then
      experiencia = premia(MATAR)     -- Matar (insectos espaciales) es muy bueno
      puntos = puntos + 1
      guardarEstado()
    else
      experiencia = castiga(PEREZA)   -- La pereza tambien es mala
    end

    -- log(('Experiencia: %f'):format(experiencia))
    -- Aprende de la experiencia el 90% de las veces para evitar ciclos infinitos
    if not muerto and math.random() <= .9 then
      local e = aprende(experiencia)
      if emu.framecount() % 5 == 0 then
        lerr = err or 0
        err = e
      end
      -- Histograma de experiencia
      for i = 1, 10 do
        histograma[i] = histograma[i + 1] or {(3*math.tanh(err - lerr)),experiencia}
      end

    end
  end

  while true do
    loopPrincipal()
  end
end

Gautolaga()