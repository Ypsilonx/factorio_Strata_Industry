"""Procedurální materiály radnice a domů: kámen, dřevo, doškové střechy, hliněná omítka, udusaná hlína a světla.

Paleta je tlumená a zemitá, aby grafika zapadla do vizuálu Factoria (porovnávat s vanilla sprity v náhledu).
Materiály jsou jen pro Cycles (AO, Bevel). Svítící materiály (okna, vatry) mají emisi řízenou set_glow:
v základní vrstvě jsou tmavé, ve světelné vrstvě svítí.
"""

import bpy

import rt_terrain

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
    "brick": (0.20, 0.085, 0.05),
    "metal": (0.085, 0.085, 0.08),
    "iron": (0.06, 0.06, 0.062),
    "rust": (0.17, 0.065, 0.025),
    "glass_off": (0.02, 0.022, 0.025),
    "fire": (1.0, 0.45, 0.12),
    "window": (1.0, 0.68, 0.32),
}
#: Zesílení sytosti celé palety (1.0 = beze změny) – vanilla budovy jsou sytější, než by odpovídalo realitě.
PALETTE_SATURATION = 1.3


def _saturate(color, factor):
    """Roztáhne barvu (lineární RGB) od její šedé (průměru složek) o factor; záporné složky ořízne."""
    grey = sum(color) / 3.0
    return tuple(max(0.0, grey + (c - grey) * factor) for c in color)


PALETTE = {key: _saturate(color, PALETTE_SATURATION) for key, color in PALETTE.items()}
GRIME = (0.018, 0.016, 0.013)
#: Podíl mechu na střechách (tráva ze hry) a síla rzi na plechu – laditelné.
MOSS = 0.8
#: Ztmavení terénu ze hry – textury jsou předem nasvícené, pod sluncem renderu by byly přepálené.
GROUND_TINT = 0.6
RUST = 0.7
#: Počet řad došků na metr spádu (hustota vrstev doškové střechy).
THATCH_ROWS = 4.5
#: Odstíny tašek: násobky barvy šindele (každý dům si vybere jeden) – terakota, hnědá, tmavá, okrová.
ROOF_TINTS = [(1.6, 0.9, 0.7), (1.0, 1.0, 1.0), (0.6, 0.62, 0.7), (1.5, 1.2, 0.7)]
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


#: Vzhled jako vanilla budovy: světlé ošoupané hrany (podíl zesvětlení) a hlubší tma v koutech (násobič grime).
EDGE_HIGHLIGHT = 0.45
EDGE_LIGHTEN = 2.2
CREVICE_DEPTH = 1.5


def _finish(nt, bsdf, color, crevice, edge, grime=0.6, roughness=0.85):
    """Patina, světlé ošoupané hrany, špína v koutech, drsnost a výstup barvy."""
    color = _age(nt, color)
    lighter = nt.nodes.new("ShaderNodeMix")
    lighter.data_type = "RGBA"
    lighter.blend_type = "MULTIPLY"
    lighter.clamp_result = True
    _set(nt, _socket(lighter, "Factor", "VALUE"), 1.0)
    _set(nt, _socket(lighter, "A", "RGBA"), color)
    _set(nt, _socket(lighter, "B", "RGBA"), (EDGE_LIGHTEN,) * 3)
    lighter = next(s for s in lighter.outputs if s.type == "RGBA")
    color = mix(nt, math(nt, "MULTIPLY", edge, EDGE_HIGHLIGHT), color, lighter)
    color = mix(nt, math(nt, "MULTIPLY", crevice, grime * CREVICE_DEPTH, clamp=True), color, GRIME)
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
    color = mix(nt, math(nt, "MULTIPLY", moss, 0.45 * MOSS), color, rt_terrain.color(nt, "moss", scale=3.0))
    _finish(nt, bsdf, color, crevice, edge)
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
    _finish(nt, bsdf, color, crevice, edge, grime=0.7)
    _bump(nt, bsdf, grain, 0.4)
    return mat


def thatch(name="RT_Thatch"):
    """Došková střecha: řady došků po spádu (tmavé spáry mezi vrstvami), stébla, světlejší konce stébel
    na spodní hraně řady, tmavší šmouhy a mech z trávy ze hry."""
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.wave_profile = "SAW"
    wave.inputs["Scale"].default_value = THATCH_ROWS
    wave.inputs["Distortion"].default_value = 2.0
    wave.inputs["Detail"].default_value = 3.0
    nt.links.new(coords, wave.inputs["Vector"])
    rows = wave.outputs["Fac"]
    straw = noise(nt, coords, 22.0, detail=4.0, roughness=0.75, stretch=(8.0, 8.0, 0.3))
    patches = noise(nt, coords, 2.5)
    moss = ramp(nt, noise(nt, coords, 2.0), 0.62, 0.75)
    color = mix(nt, straw, PALETTE["thatch_dark"], PALETTE["thatch"])
    color = mix(nt, math(nt, "MULTIPLY", ramp(nt, rows, 0.75, 1.0), 0.5), color, tuple(c * 1.5 for c in PALETTE["thatch"]))
    color = mix(nt, ramp(nt, rows, 0.3, 0.0), color, tuple(c * 0.5 for c in PALETTE["thatch_dark"]))
    color = mix(nt, math(nt, "MULTIPLY", ramp(nt, patches, 0.5, 0.75), 0.6), color, PALETTE["thatch_dark"])
    color = mix(nt, math(nt, "MULTIPLY", moss, 0.6 * MOSS), color, rt_terrain.color(nt, "moss", scale=3.0))
    _finish(nt, bsdf, color, crevice, edge, grime=0.8, roughness=0.95)
    _bump(nt, bsdf, math(nt, "ADD", rows, math(nt, "MULTIPLY", straw, 0.5)), 1.0)
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
    _finish(nt, bsdf, color, crevice, edge, grime=0.5)
    _bump(nt, bsdf, math(nt, "MULTIPLY", chips, -1.0), 0.3)
    return mat


def shingles(name, base, scale=9.0, tints=None):
    """Šindel / břidlice: řady destiček (vlny podél spádu) s nepravidelným odstínem a mechem z trávy ze hry.
    tints = násobky barvy, z nichž si každá střecha vybere podle náhody objektu (každý dům jiné tašky)."""
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
    moss = ramp(nt, noise(nt, coords, 3.0), 0.6, 0.72)
    if tints:
        # Barva střechy podle náhody objektu: skokový přechod mezi odstíny tints.
        variety = nt.nodes.new("ShaderNodeValToRGB")
        variety.color_ramp.interpolation = "CONSTANT"
        elements = variety.color_ramp.elements
        while len(elements) < len(tints):
            elements.new(0.0)
        for i, (element, tint) in enumerate(zip(elements, tints)):
            element.position = i / len(tints)
            element.color = (*(min(1.0, b * t) for b, t in zip(base, tint)), 1.0)
        nt.links.new(nt.nodes.new("ShaderNodeObjectInfo").outputs["Random"], variety.inputs["Fac"])
        roof = variety.outputs["Color"]
    else:
        roof = base
    shade = math(nt, "MULTIPLY", tiles, 0.8)
    color = mix(nt, shade, _scaled(nt, roof, 0.7), _scaled(nt, roof, 1.4))
    color = mix(nt, math(nt, "MULTIPLY", rows, 0.4), color, _scaled(nt, roof, 0.5))
    color = mix(nt, math(nt, "MULTIPLY", moss, MOSS), color, rt_terrain.color(nt, "moss", scale=3.0))
    _finish(nt, bsdf, color, crevice, edge, grime=0.6, roughness=0.8)
    _bump(nt, bsdf, math(nt, "ADD", rows, tiles), 0.7)
    return mat


def ground(name, key, grime=0.4, fade=False):
    """Terén ze hry (rt_terrain: hlína, tráva, dlažba, beton) – nádvoří, cesty, plochy; tmavší v koutech.
    fade = okraj plochy se nepravidelně rozplyne do průhledna (trávník přechází do hlíny jako ve hře)."""
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    color = _scaled(nt, rt_terrain.color(nt, key), GROUND_TINT)
    if fade:
        _fade_edge(mat, nt, bsdf, coords)
    color = mix(nt, math(nt, "MULTIPLY", crevice, grime, clamp=True), color, GRIME)
    nt.links.new(color, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


def _fade_edge(mat, nt, bsdf, coords):
    """Rozplyne okraj plochy (vzdálenost od středu v Generated souřadnicích + šum) do průhledna."""
    generated = nt.nodes.new("ShaderNodeTexCoord").outputs["Generated"]
    center = nt.nodes.new("ShaderNodeVectorMath")
    center.operation = "SUBTRACT"
    nt.links.new(generated, center.inputs[0])
    center.inputs[1].default_value = (0.5, 0.5, 0.5)
    flat = nt.nodes.new("ShaderNodeVectorMath")
    flat.operation = "MULTIPLY"
    nt.links.new(center.outputs["Vector"], flat.inputs[0])
    flat.inputs[1].default_value = (2.0, 2.0, 0.0)
    distance = nt.nodes.new("ShaderNodeVectorMath")
    distance.operation = "LENGTH"
    nt.links.new(flat.outputs["Vector"], distance.inputs[0])
    ragged = math(nt, "ADD", distance.outputs["Value"], math(nt, "MULTIPLY", noise(nt, coords, 3.0), 0.5))
    opacity = ramp(nt, ragged, 1.15, 0.7)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    shader = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(opacity, shader.inputs["Fac"])
    nt.links.new(nt.nodes.new("ShaderNodeBsdfTransparent").outputs["BSDF"], shader.inputs[1])
    nt.links.new(bsdf.outputs["BSDF"], shader.inputs[2])
    nt.links.new(shader.outputs["Shader"], out.inputs["Surface"])


def _scaled(nt, color, factor):
    """Barva (konstanta nebo výstup uzlu) vynásobená číslem."""
    if not isinstance(color, bpy.types.NodeSocket):
        return tuple(c * factor for c in color)
    node = nt.nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    node.blend_type = "MULTIPLY"
    _set(nt, _socket(node, "Factor", "VALUE"), 1.0)
    _set(nt, _socket(node, "A", "RGBA"), color)
    _set(nt, _socket(node, "B", "RGBA"), (factor,) * 3)
    return next(s for s in node.outputs if s.type == "RGBA")


def brick(name="RT_Brick", base=None):
    """Cihlové zdivo: vazba cihel (Brick Texture), tmavá malta, každá cihla jiný odstín, okoralé hrany."""
    base = base or PALETTE["brick"]
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    tex = nt.nodes.new("ShaderNodeTexBrick")
    tex.inputs["Scale"].default_value = 9.0
    tex.inputs["Mortar Size"].default_value = 0.025
    tex.inputs["Color1"].default_value = (*base, 1.0)
    tex.inputs["Color2"].default_value = (*(c * 0.72 for c in base), 1.0)
    tex.inputs["Mortar"].default_value = (0.09, 0.085, 0.075, 1.0)
    nt.links.new(coords, tex.inputs["Vector"])
    soot = ramp(nt, noise(nt, coords, 3.0), 0.6, 0.8)
    color = mix(nt, math(nt, "MULTIPLY", soot, 0.4), tex.outputs["Color"], GRIME)
    _finish(nt, bsdf, color, crevice, edge, grime=0.6)
    _bump(nt, bsdf, math(nt, "SUBTRACT", 1.0, tex.outputs["Fac"]), 0.6)
    return mat


def concrete(name="RT_Concrete", base=(0.17, 0.165, 0.155)):
    """Betonové desky: čtvercová mřížka spár (Brick Texture se čtvercovými cihlami), skvrny, šmouhy."""
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    tex = nt.nodes.new("ShaderNodeTexBrick")
    tex.offset = 0.0
    tex.inputs["Scale"].default_value = 1.0
    tex.inputs["Brick Width"].default_value = 1.0
    tex.inputs["Row Height"].default_value = 1.0
    tex.inputs["Mortar Size"].default_value = 0.012
    tex.inputs["Color1"].default_value = (*base, 1.0)
    tex.inputs["Color2"].default_value = (*(c * 0.88 for c in base), 1.0)
    tex.inputs["Mortar"].default_value = (*(c * 0.45 for c in base), 1.0)
    nt.links.new(coords, tex.inputs["Vector"])
    stains = noise(nt, coords, 2.0, detail=8.0)
    color = mix(nt, math(nt, "MULTIPLY", ramp(nt, stains, 0.45, 0.75), 0.4), tex.outputs["Color"], GRIME)
    _finish(nt, bsdf, color, crevice, edge, grime=0.4, roughness=0.9)
    _bump(nt, bsdf, math(nt, "SUBTRACT", 1.0, tex.outputs["Fac"]), 0.4)
    return mat


def corrugated(name="RT_Corrugated", base=None):
    """Vlnitý plech: vlny po spádu, zašlý zinek se skvrnami rzi a stékajícími šmouhami."""
    base = base or PALETTE["metal"]
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.wave_profile = "SIN"
    wave.inputs["Scale"].default_value = 30.0
    nt.links.new(coords, wave.inputs["Vector"])
    # Rez stéká v pruzích po spádu a sedí v koutech a u hran – ne v kropenatých skvrnách.
    streaks = ramp(nt, noise(nt, coords, 3.0, detail=4.0, stretch=(10.0, 10.0, 0.5)), 0.55, 0.8)
    tone = noise(nt, coords, 0.8, detail=2.0)
    color = mix(nt, math(nt, "MULTIPLY", wave.outputs["Fac"], 0.25), base, tuple(c * 1.25 for c in base))
    color = mix(nt, math(nt, "MULTIPLY", tone, 0.35), color, tuple(c * 0.75 for c in base))
    rust = math(nt, "ADD", math(nt, "MULTIPLY", streaks, RUST), math(nt, "MULTIPLY", crevice, RUST), clamp=True)
    color = mix(nt, rust, color, PALETTE["rust"])
    _finish(nt, bsdf, color, crevice, edge, grime=0.5, roughness=0.6)
    bsdf.inputs["Metallic"].default_value = 0.4
    _bump(nt, bsdf, wave.outputs["Fac"], 0.5)
    return mat


def tank(name="RT_Tank", base=(0.07, 0.08, 0.07)):
    """Natřená ocelová nádrž: vodorovné spáry plechů, ošoupaná barva na hranách, rez stékající v pruzích
    (jako vanilla nádrže a potrubí)."""
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    seams = nt.nodes.new("ShaderNodeTexWave")
    seams.wave_type = "BANDS"
    seams.bands_direction = "Z"
    seams.inputs["Scale"].default_value = 3.0
    nt.links.new(coords, seams.inputs["Vector"])
    seam = ramp(nt, seams.outputs["Fac"], 0.05, 0.0)
    streaks = ramp(nt, noise(nt, coords, 3.5, detail=4.0, stretch=(10.0, 10.0, 0.5)), 0.55, 0.8)
    tone = noise(nt, coords, 1.0, detail=2.0)
    color = mix(nt, math(nt, "MULTIPLY", tone, 0.4), base, tuple(c * 1.4 for c in base))
    color = mix(nt, seam, color, GRIME)
    color = mix(nt, math(nt, "MULTIPLY", streaks, RUST), color, PALETTE["rust"])
    _finish(nt, bsdf, color, crevice, edge, grime=0.5, roughness=0.5)
    bsdf.inputs["Metallic"].default_value = 0.5
    _bump(nt, bsdf, seam, 0.4)
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
    _finish(nt, bsdf, color, crevice, edge, grime=0.7, roughness=0.9)
    _bump(nt, bsdf, leaves, 1.2)
    return mat


def cloth(name, base):
    """Plátno (stříšky stánků): zašlé, s vybledlými pruhy."""
    mat, nt, bsdf = _new(name)
    coords, crevice, edge = _masks(nt)
    fade = noise(nt, coords, 4.0)
    color = mix(nt, math(nt, "MULTIPLY", fade, 0.6), base, tuple(c * 1.5 for c in base))
    _finish(nt, bsdf, color, crevice, edge, grime=0.4, roughness=0.9)
    return mat


def glass(name="RT_Glass", base=(0.03, 0.045, 0.06)):
    """Sklo (kopule, světlíky, prosklené stěny): tmavé, lesklé, odráží oblohu – samo nesvítí (v noci by
    celá kopule zářila jako placka)."""
    mat, nt, bsdf = _new(name)
    bsdf.inputs["Base Color"].default_value = (*base, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.08
    bsdf.inputs["Metallic"].default_value = 0.3
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
        elif mat.get("rt_glow_card"):
            # Světla ze hry (rozsvícená lampa): jen ve světelné vrstvě.
            mat.node_tree.nodes["RT_Switch"].outputs[0].default_value = 1.0 if on else 0.0
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
        "shingle": shingles("RT_Shingle", PALETTE["shingle"], tints=ROOF_TINTS),
        "slate": shingles("RT_Slate", PALETTE["slate"], scale=14.0),
        "cobble": ground("RT_Cobble", "cobble"),
        "foliage": foliage(),
        "foliage_light": foliage("RT_FoliageLight", base=(0.08, 0.10, 0.03), scale=8.0),
        "grass": ground("RT_Grass", "grass"),
        "lawn": ground("RT_Lawn", "grass", fade=True),
        "field": ground("RT_Field", "dry"),
        "hay": thatch(),
        "cloth_red": cloth("RT_ClothRed", PALETTE["cloth_red"]),
        "cloth_blue": cloth("RT_ClothBlue", PALETTE["cloth_blue"]),
        "brick": brick(),
        "corrugated": corrugated(),
        "iron": corrugated("RT_Iron", PALETTE["iron"]),
        "concrete": ground("RT_Concrete", "concrete"),
        "tar_roof": concrete("RT_TarRoof", base=(0.055, 0.05, 0.045)),
        "metal_bright": corrugated("RT_MetalBright", (0.32, 0.31, 0.29)),
        "rust_pipe": corrugated("RT_RustPipe", PALETTE["rust"]),
        "tank": tank(),
        "paint_green": cloth("RT_PaintGreen", (0.035, 0.08, 0.045)),
        "glass": glass(),
        "earth": ground("RT_Earth", "earth"),
        "window": glow("RT_Window", PALETTE["window"]),
        "fire": glow("RT_Fire", PALETTE["fire"], base=(0.03, 0.02, 0.015)),
    }
