extends Node
## Datos fijos del juego: terrenos, herramientas, regiones y especies.

const C := 44
const R := 44
const MAXH := 5
const DAY := 300.0
const AFW := float(C * R) / 900.0   # más fauna en mapas grandes
const HS := 0.42          # altura de un escalón de terreno (unidades de mundo)

const TY := ["tox","dirt","grass","forest","water","wet","flower","rock","mnt","sea","sand","mang","ash","ice","lava","oil","bed"]
const BL := ["","tur","dep","asp","geo","sol","nub","fri","obs","viv","col","hid","pum","cal","mon"]

const GREEN := ["grass","forest","wet","flower","mang"]
const NOLAND := ["rock","mnt","sea","lava","oil"]
const DIRTY := ["tox","ash","oil"]
const WATERY := ["water","wet","sea","mang","oil"]
const SUNK := ["water","wet","sea","mang","oil","bed"]
const NEEDPOW := ["dep","asp","sol","nub","fri","pum","viv","hid","mon"]
const NOBUILD3 := ["tur","geo","dep","asp","pum","can","sol","nub","fri","viv","col","hid","cal","mon"]

const TNAME := {
	"tox":"Suelo tóxico","dirt":"Tierra limpia","grass":"Pasto","forest":"Bosque","water":"Agua dulce",
	"wet":"Humedal","flower":"Prado de flores","rock":"Roca","mnt":"Montaña","sea":"Mar","sand":"Arena",
	"mang":"Manglar","ash":"Ceniza","ice":"Hielo","lava":"Lava","oil":"Petróleo","bed":"Cauce seco"}

const TDESC := {
	"tox":"Tierra envenenada. Un depurador la limpia.",
	"dirt":"Lista para sembrar: los aspersores la convierten en pasto.",
	"grass":"La base de todo. Se extiende sola con la lluvia.",
	"forest":"Crece con viveros. Necesita humedad ≥ 40% y 4–28 °C.",
	"water":"Sale de canales y bombas. Hace crecer pasto en sus orillas.",
	"wet":"Hidropónico junto al agua. Necesita humedad ≥ 50%.",
	"flower":"Las colmenas lo siembran cerca del bosque. Fertilidad ≥ 30%.",
	"rock":"Lugar ideal para turbinas.","mnt":"Turbinas con mayor alcance.",
	"sea":"El borde del mapa. Los manglares crecen en su orilla.",
	"sand":"Junto al mar se puede plantar manglar.",
	"mang":"Bosque costero. Necesita ≥ 10 °C.",
	"ash":"Restos de incendios. Un depurador la limpia.",
	"ice":"Permafrost. Se derrite con calor o espejos solares.",
	"lava":"Solo para plantas geotérmicas.",
	"oil":"Mar contaminado. Un depurador lo limpia.",
	"bed":"Cauce sin agua. Se llena al tocar agua o con una bomba."}

const REGIONS := {
	"valle":{"n":"Valle templado","d":"Un valle entre montañas nevadas y el mar, envenenado por décadas de industria. El clima ya es amable.",
		"t0":15.0,"h0":38.0,"g1":0.45,"climPh":2,"fn":"Bosque","sp":["deer","beaver","frog","bear","heron","butterfly"],
		"sea":Color("#3274a9"),"col":Color("#84bb53"),
		"g2":[["Bosque","forest",0.12],["Humedal","wet",0.05],["Flores","flower",0.06],["Manglar","mang",0.03],["Limpio","clean",0.95]]},
	"tropico":{"n":"Archipiélago tropical","d":"Islas cubiertas de residuos en un mar manchado de petróleo. Hace calor: la selva necesita que enfríes el aire.",
		"t0":31.0,"h0":60.0,"g1":0.40,"climPh":1,"fn":"Selva","sp":["parrot","turtle","flamingo","manta","butterfly","bee"],
		"sea":Color("#2b9bb5"),"col":Color("#2b9bb5"),
		"g2":[["Selva","forest",0.12],["Manglar","mang",0.06],["Flores","flower",0.05],["Limpio","clean",0.95]]},
	"polar":{"n":"Tundra helada","d":"Permafrost y minas abandonadas junto a un mar frío. Sin calor no crece nada: derrite el hielo con espejos solares.",
		"t0":-8.0,"h0":34.0,"g1":0.35,"climPh":1,"fn":"Taiga","sp":["reindeer","fox","hare","seal","wolf","whale"],
		"sea":Color("#2f5f8a"),"col":Color("#e6f0f6"),
		"g2":[["Taiga","forest",0.10],["Humedal","wet",0.04],["Flores","flower",0.04],["Deshielo","melt",0.75],["Limpio","clean",0.95]]},
	"volcan":{"n":"Caldera volcánica","d":"Ríos de lava, ceniza y aire muy seco. La energía sale de la tierra y la humedad hay que fabricarla.",
		"t0":22.0,"h0":14.0,"g1":0.35,"climPh":1,"fn":"Bosque","sp":["goat","lizard","rabbit","bee","butterfly","duck"],
		"sea":null,"col":Color("#ff7a1a"),
		"g2":[["Bosque","forest",0.08],["Flores","flower",0.05],["Humedal","wet",0.04],["Limpio","clean",0.95]]}}
const RORDER := ["valle","tropico","polar","volcan"]

const TOOLS := [
	{"id":"tur","n":"Turbina","c":6,"ph":1,"b":true,"d":"Sobre roca o montaña: energía en radio 3 (4 en montaña) para 6 edificios"},
	{"id":"geo","n":"Geotérmica","c":10,"ph":1,"b":true,"r":["volcan"],"d":"Sobre lava: energía en radio 4 y +1 °C"},
	{"id":"dep","n":"Depurador","c":8,"ph":1,"b":true,"d":"Limpia toxinas, ceniza y petróleo en radio 2"},
	{"id":"asp","n":"Aspersor","c":10,"ph":1,"b":true,"d":"Convierte tierra limpia en pasto en radio 2"},
	{"id":"pum","n":"Bomba","c":8,"ph":1,"b":true,"d":"Sobre un cauce seco: lo llena de agua"},
	{"id":"cal","n":"Calcificador","c":12,"ph":1,"b":true,"d":"Junto al agua: la usa para convertir la tierra de alrededor en roca (más sitio para turbinas)"},
	{"id":"can","n":"Canal","c":2,"ph":1,"d":"Excava un cauce; se llena si toca agua"},
	{"id":"sol","n":"Espejo solar","c":12,"clim":true,"b":true,"d":"+3 °C y derrite hielo en radio 3"},
	{"id":"nub","n":"Torre de nubes","c":12,"clim":true,"b":true,"d":"+10% de humedad"},
	{"id":"fri","n":"Enfriador","c":12,"clim":true,"b":true,"d":"−3 °C"},
	{"id":"viv","n":"Vivero","c":10,"ph":2,"b":true,"d":"Sobre pasto: hace crecer bosque en radio 2"},
	{"id":"col","n":"Colmena","c":8,"ph":2,"b":true,"d":"Sobre bosque: siembra flores en el pasto a 3 casillas"},
	{"id":"hid","n":"Hidropónico","c":10,"ph":2,"b":true,"d":"Sobre un aspersor a 3 casillas del agua: crea humedal"},
	{"id":"mon","n":"Torre monzón","c":30,"ph":2,"b":true,"d":"Siembra nubes: provoca lluvias seguidas y todo crece más rápido"},
	{"id":"man","n":"Manglar","c":5,"ph":2,"r":["valle","tropico"],"d":"Sobre arena que toque el mar"},
	{"id":"obs","n":"Observatorio","c":15,"ph":3,"b":true,"d":"Registra animales en radio 3"},
	{"id":"rec","n":"Reciclar","c":0,"ph":1,"d":"Un dron se lleva el edificio y te devuelve el 50%"}]

const SPEC := {
	"deer":{"n":"Venado","d":"Pasta en los claros y descansa bajo los árboles.","req":"Aparece con bosques extensos."},
	"rabbit":{"n":"Conejo","d":"Salta entre el pasto y los prados.","req":"Aparece con mucho pasto y flores."},
	"heron":{"n":"Garza","d":"Camina despacio en el humedal buscando peces.","req":"Aparece con humedales."},
	"duck":{"n":"Pato","d":"Flota en los canales y deja estelas en el agua.","req":"Aparece con canales de agua dulce."},
	"bee":{"n":"Abeja","d":"Poliniza el prado y lo ayuda a expandirse.","req":"Aparece con prados de flores."},
	"butterfly":{"n":"Mariposa","d":"Revolotea sobre las flores en los días soleados.","req":"Aparece con prados de flores amplios."},
	"parrot":{"n":"Guacamaya","d":"Vuela en parejas entre las copas de la selva.","req":"Aparece con selva densa."},
	"turtle":{"n":"Tortuga marina","d":"Sube a la arena a descansar cerca de los manglares.","req":"Aparece con manglares."},
	"reindeer":{"n":"Reno","d":"Recorre la taiga en busca de líquenes.","req":"Aparece con taiga."},
	"fox":{"n":"Zorro ártico","d":"Su pelaje blanco lo esconde en la nieve.","req":"Aparece con praderas en la tundra."},
	"hare":{"n":"Liebre ártica","d":"Más grande que un conejo, con orejas de punta negra.","req":"Aparece con mucho pasto."},
	"seal":{"n":"Foca","d":"Descansa flotando cerca de la costa limpia.","req":"Aparece cuando la costa reverdece."},
	"goat":{"n":"Cabra montés","d":"Trepa entre rocas y pastizales sin miedo al vacío.","req":"Aparece con pasto cerca de las rocas."},
	"lizard":{"n":"Lagartija","d":"Toma el sol sobre piedras calientes.","req":"Aparece cuando la caldera reverdece."},
	"beaver":{"n":"Castor","d":"Nada en los canales y construye diques con ramas del bosque.","req":"Necesita canales de agua junto a un bosque."},
	"frog":{"n":"Rana","d":"Salta entre nenúfares y croa al anochecer.","req":"Aparece con humedales."},
	"bear":{"n":"Oso","d":"Recorre el bosque buscando bayas y flores.","req":"Necesita un bosque grande y prados de flores."},
	"flamingo":{"n":"Flamenco","d":"Descansa en una pata en las aguas someras.","req":"Aparece con humedales o manglares extensos."},
	"manta":{"n":"Mantarraya","d":"Planea bajo el agua turquesa cerca de los manglares.","req":"Aparece con manglares grandes."},
	"wolf":{"n":"Lobo","d":"Sigue a las manadas de renos a distancia.","req":"Solo llega cuando hay renos que seguir."},
	"whale":{"n":"Ballena","d":"Sale a respirar lanzando un chorro de agua.","req":"Aparece cuando gran parte de la tierra reverdece."}}

const HAB := {"deer":["forest","grass","flower"],"rabbit":["grass","flower"],"heron":["wet"],"duck":["water"],"bee":["flower"],
	"butterfly":["flower"],"parrot":["forest"],"turtle":["sand","mang"],"reindeer":["forest","grass","flower"],
	"fox":["grass","flower","forest"],"hare":["grass","flower"],"seal":["sea"],"goat":["grass","flower","rock"],
	"lizard":["grass","rock","sand","flower"],"beaver":["water"],"frog":["wet"],"bear":["forest","grass","flower"],
	"flamingo":["wet","mang"],"manta":["sea"],"wolf":["forest","grass","flower"],"whale":["sea"]}
const SPD := {"deer":.45,"rabbit":.7,"heron":.18,"duck":.25,"bee":.9,"butterfly":.5,"parrot":1.0,"turtle":.12,
	"reindeer":.4,"fox":.6,"hare":.75,"seal":.15,"goat":.45,"lizard":.8,"beaver":.3,"frog":.5,"bear":.3,
	"flamingo":.15,"manta":.3,"wolf":.55,"whale":.12}

const NEED := {"grass":{"T":[0,99]},"forest":{"H":40,"T":[4,28]},"flower":{"F":30,"T":[4,32]},"wet":{"H":50},"mang":{"T":[10,99]}}
const SPR := {"water":["dirt",.35],"forest":["grass",.08],"flower":["grass",.13],"wet":["grass",.06],"mang":["sand",.09]}
const PHN := ["","Sanar el suelo","Devolver la vida","Registrar y partir"]

func want(k: String, s: Dictionary) -> int:
	var gl: float = s.green + s.flower
	match k:
		"deer": return mini(int(8 * AFW), s.forest / 8)
		"rabbit": return mini(int(6 * AFW), (s.grass + s.flower) / 25)
		"heron": return mini(int(6 * AFW), s.wet / 4)
		"duck": return mini(int(6 * AFW), s.water / 6)
		"bee": return mini(int(10 * AFW), s.flower / 5)
		"butterfly": return mini(int(8 * AFW), s.flower / 7)
		"parrot": return mini(int(8 * AFW), s.forest / 6)
		"turtle": return mini(int(5 * AFW), s.mang / 4)
		"reindeer": return mini(int(6 * AFW), s.forest / 7)
		"fox": return mini(int(4 * AFW), (s.grass + s.flower) / 22)
		"hare": return mini(int(6 * AFW), (s.grass + s.flower) / 18)
		"seal": return mini(int(4 * AFW), s.green / 35)
		"goat": return mini(int(6 * AFW), (s.grass + s.flower) / 20)
		"lizard": return mini(int(6 * AFW), s.green / 25)
		"beaver": return mini(int(3 * AFW), s.water / 6) if s.forest >= 6 else 0
		"frog": return mini(int(6 * AFW), s.wet / 3)
		"bear": return mini(int(2 * AFW), s.forest / 20) if (s.forest >= 20 and s.flower >= 8) else 0
		"flamingo": return mini(int(6 * AFW), (s.wet + s.mang) / 6)
		"manta": return mini(int(3 * AFW), s.mang / 6)
		"wolf": return mini(int(3 * AFW), maxi(0, s.get("reindeer", 0) - 1))
		"whale":
			var r: float = float(s.green) / s.land
			return (2 if r > .6 else 1) if r > .4 else 0
	return 0

func tool(id: String) -> Dictionary:
	for t in TOOLS:
		if t.id == id: return t
	return {}

func tname(t: Dictionary, reg: Dictionary) -> String:
	return t.n

func ty(i: int) -> String:
	return TY[i]

## Misiones secundarias: k = métrica, g = meta, r = recompensa en hojas, ph = fase mínima, reg = regiones
const MISSIONS := [
	{"id":"tur3","n":"Levanta 3 turbinas","k":"b_tur","g":3,"r":8},
	{"id":"geo3","n":"Construye 3 plantas geotérmicas","k":"b_geo","g":3,"r":15,"reg":["volcan"]},
	{"id":"dep5","n":"Construye 5 depuradores","k":"b_dep","g":5,"r":12},
	{"id":"clean60","n":"Limpia 60 casillas contaminadas","k":"clean","g":60,"r":15},
	{"id":"oil40","n":"Limpia 40 casillas de petróleo","k":"oil","g":40,"r":20,"reg":["tropico"]},
	{"id":"melt150","n":"Derrite 150 casillas de hielo","k":"melt","g":150,"r":20,"reg":["polar"]},
	{"id":"grass80","n":"Haz crecer 80 casillas de pasto","k":"grass","g":80,"r":15},
	{"id":"can8","n":"Excava 8 canales","k":"can","g":8,"r":10},
	{"id":"fill15","n":"Llena de agua 15 casillas de cauce","k":"fill","g":15,"r":12},
	{"id":"asp6","n":"Ten 6 aspersores con energía a la vez","k":"pow_asp","g":6,"r":15},
	{"id":"rain2","n":"Vive 2 lluvias","k":"rain","g":2,"r":10},
	{"id":"green25","n":"Reverdece el 25% de la tierra","k":"green","g":25,"r":15},
	{"id":"warm5","n":"Sube la temperatura a 5 °C","k":"T_hi","g":5,"r":15,"reg":["polar"]},
	{"id":"cool26","n":"Baja la temperatura a 26 °C","k":"T_lo","g":26,"r":15,"reg":["tropico"]},
	{"id":"hum45","n":"Sube la humedad al 45%","k":"H","g":45,"r":15,"reg":["volcan"]},
	{"id":"day3","n":"Llega al día 3","k":"days","g":3,"r":10},
	{"id":"forest40","n":"Haz crecer 40 casillas de bosque","k":"forest","g":40,"r":20,"ph":2},
	{"id":"flower25","n":"Siembra 25 casillas de flores","k":"flower","g":25,"r":20,"ph":2},
	{"id":"wet15","n":"Crea 15 casillas de humedal","k":"wet","g":15,"r":20,"ph":2,"reg":["valle","tropico","polar","volcan"]},
	{"id":"col3","n":"Instala 3 colmenas","k":"b_col","g":3,"r":12,"ph":2},
	{"id":"man8","n":"Planta 8 manglares","k":"man","g":8,"r":15,"ph":2,"reg":["valle","tropico"]},
	{"id":"sp4","n":"Descubre 4 especies","k":"species","g":4,"r":20},
	{"id":"bear","n":"Atrae al oso al bosque","k":"sp_bear","g":1,"r":25,"reg":["valle"]},
	{"id":"whale","n":"Avista la ballena","k":"sp_whale","g":1,"r":25,"reg":["polar"]},
	{"id":"manta","n":"Avista la mantarraya","k":"sp_manta","g":1,"r":25,"reg":["tropico"]},
	{"id":"goat","n":"Atrae a la cabra montés","k":"sp_goat","g":1,"r":25,"reg":["volcan"]},
	{"id":"anim25","n":"Ten 25 animales en la parcela","k":"animals","g":25,"r":25},
	{"id":"rec15","n":"Recicla 15 edificios","k":"rec","g":15,"r":20,"ph":3}]
