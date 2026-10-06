"""Procedurální materiály radnice a domů: kámen, dřevo, doškové střechy, hliněná omítka, udusaná hlína a světla.

Paleta je tlumená a zemitá, aby grafika zapadla do vizuálu Factoria (porovnávat s vanilla sprity v náhledu).
Materiály jsou jen pro Cycles (AO, Bevel). Svítící materiály (okna, vatry) mají emisi řízenou set_glow:
v základní vrstvě jsou tmavé, ve světelné vrstvě svítí.
"""

import bpy

# Paleta (lineární RGB) – laditelné hodnoty vzhledu, tlumené kvůli souladu s vanillou.
PALETTE = {
    "stone": (0.20, 0.185, 0.165),
    "stone_dark": (0.10, 0.095, 0.085),
    "wood": (0.13, 0.085, 0.05),
    "wood_dark": (0.055, 0.037, 0.024),
    "thatch": (0.24, 0.19, 0.11),
    "thatch_dark": (0.11, 0.085, 0.045),
    "plaster": (0.30, 0.27, 0.22),
    "clay": (0.17, 0.13, 0.085),
    "clay_dark": (0.09, 0.07, 0.045),
    "plaster_ochre": (0.30, 0.22, 0.12),
    "plaster_grey": (0.23, 0.22, 0.20),
    "plaster_pink": (0.29, 0.20, 0.16),
    "shingle": (0.15, 0.105, 0.07),
    "slate": (0.12, 0.125, 0.135),
    "foliage": (0.055, 0.085, 0.025),
    "foliage_dark": (0.02, 0.035, 0.012),
    "grass": (0.07, 0.09, 0.035),
    "hay": (0.30, 0.23, 0.10),
    "cloth_red": (0.22, 0.07, 0.05),
    "cloth_blue": (0.07, 0.10, 0.15),
    "glass_off": (0.02, 0.022, 0.025),
    "fire": (1.0, 0.45, 0.12),
    "window": (1.0, 0.68, 0.32),
}
GRIME = (0.018, 0.016, 0.013)
#: Síla emise svítících materiálů ve světelné vrstvě.
GLOW_STRENGTH = 0.9


def _socket(node, name, kind):
    """Najde vstup uzlu podle jména a typu (ShaderNodeMix má víc vstupů stejného jména)."""
    return next(s for s in node.inputs if s.name == name and s.type == kind)


def _set(nt, socket, value):
    """Do vstupu zapojí výstup jiného uzlu, nebo nastaví konstantu."""
    if isinstance(value, bpy.types.NodeSocket):
        nt.links.new(value, socket)
    elif isinstance(value, (tuple, list)) and len(value) == 3:
        socket.default_value = (*value, 1.0)
    else:
        socket.default_value = value


def math(nt, op, a, b=0.0, clamp=False):
    """Uzel Math; vrátí jeho výstup."""
    node = nt.nodes.new("ShaderNodeMath")
    node.operation = op
    node.use_clamp = clamp
    _set(nt, node.inputs[0], a)
    _set(nt, node.inputs[1], b)
    return node.outputs[0]


def mix(nt, factor, a, b):
    """Uzel Mix pro barvy; vrátí výstupní barvu."""
    node = nt.nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    node.clamp_factor = True
    _set(nt, _socket(node, "Factor", "VALUE"), factor)
    _set(nt, _socket(node, "A", "RGBA"), a)
    _set(nt, _socket(node, "B", "RGBA"), b)
    return next(s for s in node.outputs if s.type == "RGBA")


def ramp(nt, value, low, high):
    """Plynulé prahování hodnoty mezi low a high (0 → 1)."""
    node = nt.nodes.new("ShaderNodeMapRange")
    node.interpolation_type = "SMOOTHSTEP"
    _set(nt, node.inputs["Value"], value)
    node.inputs["From Min"].default_value = low
    node.inputs["From Max"].default_value = high
    return node.outputs["Result"]


def noise(nt, coords, scale, detail=8.0, roughness=0.6, stretch=None):
    """Šumová textura; stretch=(x, y, z) protáhne vzor (vlákna dřeva, stébla doškové střechy)."""
    if stretch:
        mapping = nt.nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = stretch
        nt.links.new(coords, mapping.inputs["Vector"])
        coords = mapping.outputs["Vector"]
    node = nt.nodes.new("ShaderNodeTexNoise")
    node.inputs["Scale"].default_value = scale
    node.inputs["Detail"].default_value = detail
    node.inputs["Roughness"].default_value = roughness
    nt.links.new(coords, node.inputs["Vector"])
    return node.outputs["Fac"]


def _masks(nt):
    """Společné masky: souřadnice (svět – textury navazují přes díly), kouty (AO) a hrany (Bevel)."""
    coords = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.25
    ao.samples = 16
    crevice = ramp(nt, math(nt, "SUBTRACT", 1.0, ao.outputs["AO"]), 0.05, 0.7)
    bevel = nt.nodes.new("ShaderNodeBevel")
    bevel.inputs["Radius"].default_value = 0.04
    geometry = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    nt.links.new(bevel.outputs["Normal"], dot.inputs[0])
    nt.links.new(geometry.outputs["Normal"], dot.inputs[1])
    edge = ramp(nt, math(nt, "SUBTRACT", 1.0, dot.outputs["Value"]), 0.01, 0.12)
    return coords, crevice, edge


def _new(name):
    """Vytvoří (nebo vyprázdní) materiál a vrátí (materiál, strom uzlů, Principled BSDF)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat, nt, bsdf


def _bump(nt, bsdf, height, strength):
    """Zapojí výškovou mapu jako bump do normály."""
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = 0.02
    nt.links.new(height, bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


#: Patina – laditelné síly: odchylka odstínu dílů, šmouhy od deště, špína u země.
AGE_VARIATION = 0.6
AGE_STREAKS = 0.4
AGE_GROUND_DIRT = 0.6
MUD = (0.05, 0.038, 0.025)


def _age(nt, color):
    """Patina: každý díl trochu jiný odstín (náhoda objektu), svislé šmouhy od deště a špína u země."""
    info = nt.nodes.new("ShaderNodeObjectInfo")
    color = mix(nt, math(nt, "MULTIPLY", info.outputs["Random"], AGE_VARIATION), color, mix(nt, 0.25, color, GRIME))
    coords = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    streaks = ramp(nt, noise(nt, coords, 5.0, detail=6.0, stretch=(7.0, 7.0, 0.35)), 0.55, 0.75)
    color = mix(nt, math(nt, "MULTIPLY", streaks, AGE_STREAKS), color, GRIME)
    position = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(nt.nodes.new("ShaderNodeNewGeometry").outputs["Position"], position.inputs["Vector"])
    low = ramp(nt, position.outputs["Z"], 0.5, 0.06)
    splash = ramp(nt, noise(nt, coords, 9.0), 0.35, 0.65)
    return mix(nt, math(nt, "MULTIPLY", math(nt, "MULTIPLY", low, splash), AGE_GROUND_DIRT), color, MUD)


def _finish(nt, bsdf, color, crevice, grime=0.6, roughness=0.85):
    """Patina, špína v koutech, drsnost a výstup barvy."""
    color = _age(nt, color)
    color = mix(nt, math(nt, "MULTIPLY", crevice, grime, clamp=True), color, GRIME)
    nt.links.new(color, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness


def stone(name="RT_Stone", base=None, dark=None, scale=3.0):
    """Lomový kámen: nepravidelné kameny (Voronoi) s tmavými spárami a skvrnami."""
    base, dark = base or PALETTE["stone"], dark or PALETTE["stone_dark"]
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    voronoi = nt.nodes.new("ShaderNodeTexVoronoi")
    voronoi.feature = "DISTANCE_TO_EDGE"
    voronoi.inputs["Scale"].default_value = scale
    nt.links.new(coords, voronoi.inputs["Vector"])
    joints = ramp(nt, voronoi.outputs["Distance"], 0.06, 0.02)
    blotch = noise(nt, coords, 4.0)
    color = mix(nt, math(nt, "MULTIPLY", blotch, 0.6), base, tuple(c * 1.3 for c in base))
    color = mix(nt, math(nt, "MULTIPLY", edge, 0.35), color, tuple(c * 1.5 for c in base))
    color = mix(nt, joints, color, dark)
    # Mech a lišejník v nepravidelných skvrnách.
    moss = ramp(nt, noise(nt, coords, 2.2, detail=8.0), 0.62, 0.78)
    color = mix(nt, math(nt, "MULTIPLY", moss, 0.45), color, PALETTE["foliage"])
    _finish(nt, bsdf, color, crevice)
    _bump(nt, bsdf, math(nt, "SUBTRACT", math(nt, "MULTIPLY", blotch, 0.3), joints), 0.6)
    return mat


def wood(name="RT_Wood", base=None, dark=None, along="z"):
    """Zašlé dřevo: vlákna podél osy along ('x', 'y', 'z'), tmavší spáry prken."""
    base, dark = base or PALETTE["wood"], dark or PALETTE["wood_dark"]
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    stretch = {"x": (0.15, 4.0, 4.0), "y": (4.0, 0.15, 4.0), "z": (4.0, 4.0, 0.15)}[along]
    grain = noise(nt, coords, 6.0, detail=6.0, stretch=stretch)
    color = mix(nt, grain, dark, base)
    color = mix(nt, math(nt, "MULTIPLY", edge, 0.3), color, tuple(c * 1.6 for c in base))
    _finish(nt, bsdf, color, crevice, grime=0.7)
    _bump(nt, bsdf, grain, 0.4)
    return mat


def thatch(name="RT_Thatch"):
    """Došková střecha: stébla po spádu (osa z protažená), tmavší šmouhy a mech v koutech."""
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    straw = noise(nt, coords, 14.0, detail=4.0, roughness=0.7, stretch=(6.0, 6.0, 0.4))
    patches = noise(nt, coords, 2.5)
    color = mix(nt, straw, PALETTE["thatch_dark"], PALETTE["thatch"])
    color = mix(nt, ramp(nt, patches, 0.5, 0.75), color, PALETTE["thatch_dark"])
    _finish(nt, bsdf, color, crevice, grime=0.8, roughness=0.95)
    _bump(nt, bsdf, straw, 0.8)
    return mat


def plaster(name="RT_Plaster", base=None):
    """Hliněná omítka (vybílená, zašlá): jemné skvrny, odprýsknuté místo s hlínou."""
    base = base or PALETTE["plaster"]
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    blotch = noise(nt, coords, 5.0)
    chips = ramp(nt, noise(nt, coords, 12.0, detail=10.0), 0.66, 0.7)
    color = mix(nt, math(nt, "MULTIPLY", blotch, 0.5), base, tuple(c * 0.8 for c in base))
    color = mix(nt, chips, color, PALETTE["clay"])
    _finish(nt, bsdf, color, crevice, grime=0.5)
    _bump(nt, bsdf, math(nt, "MULTIPLY", chips, -1.0), 0.3)
    return mat


def packed_earth(name="RT_Earth"):
    """Udusaná hlína nádvoří: skvrny, vyšlapané cesty světlejší, drobné kamínky."""
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    blotch = noise(nt, coords, 1.2, detail=6.0)
    pebbles = ramp(nt, noise(nt, coords, 40.0, detail=2.0), 0.68, 0.72)
    color = mix(nt, blotch, PALETTE["clay_dark"], PALETTE["clay"])
    color = mix(nt, math(nt, "MULTIPLY", pebbles, 0.7), color, PALETTE["stone"])
    _finish(nt, bsdf, color, crevice, grime=0.4, roughness=0.95)
    _bump(nt, bsdf, math(nt, "ADD", blotch, pebbles), 0.3)
    return mat


def shingles(name, base, scale=9.0):
    """Šindel / břidlice: řady destiček (vlny podél spádu) s nepravidelným odstínem a mechem."""
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = 1.5
    nt.links.new(coords, wave.inputs["Vector"])
    rows = ramp(nt, wave.outputs["Fac"], 0.2, 0.9)
    tiles = noise(nt, coords, 22.0, detail=2.0)
    moss = ramp(nt, noise(nt, coords, 3.0), 0.62, 0.75)
    color = mix(nt, math(nt, "MULTIPLY", tiles, 0.8), tuple(c * 0.7 for c in base), tuple(c * 1.4 for c in base))
    color = mix(nt, math(nt, "MULTIPLY", rows, 0.4), color, tuple(c * 0.5 for c in base))
    color = mix(nt, math(nt, "MULTIPLY", moss, 0.7), color, PALETTE["foliage"])
    _finish(nt, bsdf, color, crevice, grime=0.6, roughness=0.8)
    _bump(nt, bsdf, math(nt, "ADD", rows, tiles), 0.7)
    return mat


def foliage(name="RT_Foliage", base=None, dark=None, scale=6.0):
    """Listí, keře, tráva: shluky lístků (šum) s tmavými mezerami a světlejšími okraji."""
    base, dark = base or PALETTE["foliage"], dark or PALETTE["foliage_dark"]
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    leaves = noise(nt, coords, scale * 3, detail=6.0, roughness=0.75)
    clumps = noise(nt, coords, scale)
    color = mix(nt, ramp(nt, leaves, 0.35, 0.65), dark, base)
    color = mix(nt, math(nt, "MULTIPLY", ramp(nt, clumps, 0.6, 0.8), 0.5), color, tuple(c * 1.6 for c in base))
    _finish(nt, bsdf, color, crevice, grime=0.7, roughness=0.9)
    _bump(nt, bsdf, leaves, 1.2)
    return mat


def cloth(name, base):
    """Plátno (stříšky stánků): zašlé, s vybledlými pruhy."""
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    fade = noise(nt, coords, 4.0)
    color = mix(nt, math(nt, "MULTIPLY", fade, 0.6), base, tuple(c * 1.5 for c in base))
    _finish(nt, bsdf, color, crevice, grime=0.4, roughness=0.9)
    return mat


def glow(name, color, base=None):
    """Svítící materiál (okno, vatra): v základní vrstvě tmavý base, ve světelné vrstvě emise color."""
    mat, nt, bsdf = _new(name)
    bsdf.inputs["Base Color"].default_value = (*(base or PALETTE["glass_off"]), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.4
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 0.0
    mat["rt_glow"] = True
    return mat


def set_glow(on):
    """Zapne/vypne emisi všech svítících materiálů (světelná vrstva / základní vrstva)."""
    for mat in bpy.data.materials:
        if mat.get("rt_glow"):
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Emission Strength"].default_value = GLOW_STRENGTH if on else 0.0
        elif mat.get("rt_unlit"):
            # Neosvětlené sprity (vanilla stromy) ve světelné vrstvě zhasnout – samy nesvítí.
            emission = next(n for n in mat.node_tree.nodes if n.type == "EMISSION")
            emission.inputs["Strength"].default_value = 0.0 if on else 1.0


def library():
    """Všechny materiály radnice (vzhled 1) podle jména dílu."""
    return {
        "stone": stone(),
        "stone_wall": stone("RT_StoneWall", scale=5.0),
        "wood": wood(),
        "wood_beam": wood("RT_WoodBeam", base=PALETTE["wood_dark"], dark=(0.03, 0.02, 0.014), along="x"),
        "planks": wood("RT_Planks", along="y"),
        "thatch": thatch(),
        "plaster": plaster(),
        "plaster_ochre": plaster("RT_PlasterOchre", PALETTE["plaster_ochre"]),
        "plaster_grey": plaster("RT_PlasterGrey", PALETTE["plaster_grey"]),
        "plaster_pink": plaster("RT_PlasterPink", PALETTE["plaster_pink"]),
        "shingle": shingles("RT_Shingle", PALETTE["shingle"]),
        "slate": shingles("RT_Slate", PALETTE["slate"], scale=14.0),
        "cobble": stone("RT_Cobble", base=(0.12, 0.11, 0.095), dark=(0.05, 0.045, 0.04), scale=14.0),
        "foliage": foliage(),
        "foliage_light": foliage("RT_FoliageLight", base=(0.08, 0.10, 0.03), scale=8.0),
        "grass": foliage("RT_Grass", base=PALETTE["grass"], scale=14.0),
        "hay": thatch(),
        "cloth_red": cloth("RT_ClothRed", PALETTE["cloth_red"]),
        "cloth_blue": cloth("RT_ClothBlue", PALETTE["cloth_blue"]),
        "earth": packed_earth(),
        "window": glow("RT_Window", PALETTE["window"]),
        "fire": glow("RT_Fire", PALETTE["fire"], base=(0.03, 0.02, 0.015)),
    }
