"""Scéna, kamera, světla, render vrstev (base / light / shadow) a práce s pixely pro grafiku Research Towns.

Projekce jako ve Factoriu: ortografická kamera z jihu pod 45°, model natažený v ose Y o √2 (dlaždice na zemi
pak vychází čtvercová) a 64 px na dlaždici. Parametry kamery a světel jsou v camera.toml.
"""

import math
import tomllib
from pathlib import Path

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
CONFIG = tomllib.loads((HERE / "camera.toml").read_text(encoding="utf-8"))
CAM = CONFIG["camera"]
PX = CAM["px_per_tile"]
SS = CAM["supersample"]
SCENE_NAME = "RT_Render"
COLLECTION = "RT_Model"


def fresh_scene():
    """Vytvoří (znovu) vlastní scénu a kolekci modelu; objekty jiných scén nemění."""
    old = bpy.data.scenes.get(SCENE_NAME)
    if old:
        for obj in list(old.collection.all_objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new(SCENE_NAME)
    collection = bpy.data.collections.get(COLLECTION) or bpy.data.collections.new(COLLECTION)
    if collection.name not in scene.collection.children:
        scene.collection.children.link(collection)
    return scene, collection


def root(collection):
    """Prázdný objekt, pod který se věší celý model: natažení osy Y o √2 (projekce Factoria)."""
    empty = bpy.data.objects.new("RT_Root", None)
    empty.scale = (1.0, math.sqrt(2.0), 1.0)
    collection.objects.link(empty)
    return empty


def frame(footprint, top, bottom=0.0, side=0.0):
    """Záběr kolem čtvercového půdorysu: (šířka, výška, posun středu nahoru) v dlaždicích.
    top = místo nad půdorysem pro výšku budov, bottom/side = okraje (stín). Posun středu je zároveň
    posun spritu ve hře: shift = {0, -posun}."""
    width = footprint + 2 * side
    height = footprint + top + bottom
    return width, height, (top - bottom) / 2.0


def use_gpu(scene):
    """Render na grafické kartě (OptiX, pak CUDA, HIP, oneAPI), jinak zůstane CPU."""
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA", "HIP", "ONEAPI"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
        except TypeError:
            continue
        devices = [d for d in prefs.devices if d.type == kind]
        if devices:
            for device in devices:
                device.use = True
            scene.cycles.device = "GPU"
            return kind
    return "CPU"


def setup_render(scene, width, height):
    """Cycles, průhledné pozadí, rozlišení podle velikosti záběru v dlaždicích (× supersampling)."""
    scene.render.engine = "CYCLES"
    scene.cycles.samples = CONFIG["render"]["samples"]
    use_gpu(scene)
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = int(round(width * PX * SS))
    scene.render.resolution_y = int(round(height * PX * SS))
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.get("RT_World") or bpy.data.worlds.new("RT_World")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    # Blender 5 zakládá nový svět bez uzlů – pozadí a výstup případně doplníme.
    background = next((n for n in nodes if n.type == "BACKGROUND"), None) or nodes.new("ShaderNodeBackground")
    output = next((n for n in nodes if n.type == "OUTPUT_WORLD"), None) or nodes.new("ShaderNodeOutputWorld")
    if not output.inputs["Surface"].is_linked:
        world.node_tree.links.new(background.outputs["Background"], output.inputs["Surface"])
    background.inputs["Color"].default_value = (*CONFIG["world"]["color"], 1.0)
    background.inputs["Strength"].default_value = CONFIG["world"]["strength"]
    scene.world = world


def setup_camera(scene, collection, width, height, center_up):
    """Ortho kamera pod 45° z jihu se záběrem width × height dlaždic, střed o center_up výš než střed entity
    (viz frame)."""
    elevation = math.radians(CAM["elevation_deg"])
    data = bpy.data.cameras.new("RT_Camera")
    data.type = "ORTHO"
    data.ortho_scale = max(width, height)
    data.sensor_fit = "AUTO"
    camera = bpy.data.objects.new("RT_Camera", data)
    camera.rotation_euler = (math.pi / 2 - elevation, 0.0, 0.0)
    up = (0.0, math.sin(elevation), math.cos(elevation))
    back = (0.0, -math.cos(elevation), math.sin(elevation))
    d, dist = center_up, 60.0
    camera.location = tuple(up[i] * d + back[i] * dist for i in range(3))
    collection.objects.link(camera)
    scene.camera = camera
    return camera


def setup_lights(collection):
    """Slunce a doplňkové světlo podle camera.toml."""
    lights = []
    for key in ("sun", "fill"):
        cfg = CONFIG[key]
        data = bpy.data.lights.new("RT_" + key, "SUN")
        data.energy = cfg["strength"]
        data.color = cfg["color"]
        if "angle_deg" in cfg:
            data.angle = math.radians(cfg["angle_deg"])
        data.use_shadow = key == "sun"
        light = bpy.data.objects.new("RT_" + key, data)
        light.rotation_euler = tuple(math.radians(a) for a in cfg["rotation_deg"])
        collection.objects.link(light)
        lights.append(light)
    return lights


def add_ground(collection, tiles_w, tiles_h):
    """Podložka zachytávající stín (shadow catcher), větší než půdorys kvůli dlouhým stínům."""
    mesh = bpy.data.meshes.new("RT_Ground")
    w, h = tiles_w * 2.0, tiles_h * 2.0 * math.sqrt(2.0)
    mesh.from_pydata([(-w, -h, 0), (w, -h, 0), (w, h, 0), (-w, h, 0)], [], [(0, 1, 2, 3)])
    ground = bpy.data.objects.new("RT_Ground", mesh)
    ground.is_shadow_catcher = True
    collection.objects.link(ground)
    return ground


def render(scene, path):
    """Vyrenderuje scénu do PNG a vrátí pixely (výška, šířka, 4; řádky shora dolů; sRGB)."""
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True, scene=scene.name)
    return load_pixels(path)


def load_pixels(path):
    """Načte PNG jako numpy pole (výška, šířka, 4) s řádky shora dolů (hodnoty sRGB)."""
    img = bpy.data.images.load(str(path), check_existing=False)
    w, h = img.size
    pixels = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    return pixels


def save_pixels(pixels, path):
    """Uloží numpy pole (výška, šířka, 4; řádky shora dolů; sRGB) jako PNG."""
    h, w = pixels.shape[:2]
    img = bpy.data.images.new("RT_tmp", width=w, height=h, alpha=True)
    img.pixels[:] = np.clip(pixels, 0.0, 1.0)[::-1].reshape(-1)
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def srgb_to_linear(c):
    """Převod sRGB (0–1) na lineární hodnoty."""
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    """Převod lineárních hodnot zpět na sRGB (0–1)."""
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def downsample(pixels, factor=SS):
    """Zmenší obraz průměrem bloků factor×factor v lineárním prostoru s premultiplikovanou alfou."""
    if factor == 1:
        return pixels
    h, w = pixels.shape[:2]
    alpha = pixels[..., 3:4]
    pre = np.concatenate([srgb_to_linear(pixels[..., :3]) * alpha, alpha], axis=-1)
    pre = pre.reshape(h // factor, factor, w // factor, factor, 4).mean(axis=(1, 3))
    a = pre[..., 3:4]
    rgb = np.where(a > 1e-6, pre[..., :3] / np.maximum(a, 1e-6), 0.0)
    return np.concatenate([linear_to_srgb(rgb), a], axis=-1)


def over(dst, src, x=0, y=0):
    """Složí vrstvu src přes dst na pozici (x, y) levého horního rohu (sRGB, nepremultiplikovaná alfa)."""
    out = dst.copy()
    h, w = src.shape[:2]
    region = out[y:y + h, x:x + w]
    a = src[: region.shape[0], : region.shape[1], 3:4]
    s = src[: region.shape[0], : region.shape[1]]
    region[..., :3] = s[..., :3] * a + region[..., :3] * (1.0 - a)
    region[..., 3:4] = a + region[..., 3:4] * (1.0 - a)
    return out


def luminance(pixels):
    """Průměrný jas (sRGB, Rec. 709) neprůhledných pixelů."""
    mask = pixels[..., 3] > 0.5
    rgb = pixels[mask][:, :3]
    return float((rgb @ np.array([0.2126, 0.7152, 0.0722])).mean()) if len(rgb) else 0.0


def render_layers(name, build, footprint, top, margin, set_glow):
    """Vyrenderuje model do tří vrstev: základ (svítidla zhasnutá), světla (jen emise, alfa z jasu – ve hře
    additive) a stín (model neviditelný pro kameru, podložka zachytí stín). build(collection, parent) postaví
    model a vrátí počet dílů; objekty RT_Plaza (nádvoří, dvorek) stín nevrhají – zakryly by podložku.
    set_glow(on) přepíná svítící materiály. Vrátí (base, light, shadow, center_up, díly)."""
    width, height, center_up = frame(footprint, top=top, bottom=margin, side=margin)
    scene, collection = fresh_scene()
    parent = root(collection)
    setup_render(scene, width, height)
    setup_camera(scene, collection, width, height, center_up)
    lights = setup_lights(collection)
    ground = add_ground(collection, width, height)
    parts = build(collection, parent)
    model = [o for o in collection.objects if o.type == "MESH" and o is not ground]
    renders = HERE / "renders"
    renders.mkdir(exist_ok=True)
    world_strength = scene.world.node_tree.nodes["Background"].inputs["Strength"]
    default_world = world_strength.default_value

    set_glow(False)
    ground.hide_render = True
    base = downsample(render(scene, renders / f"{name}-base-raw.png"))

    set_glow(True)
    for light in lights:
        light.hide_render = True
    world_strength.default_value = 0.0
    light_px = downsample(render(scene, renders / f"{name}-light-raw.png"))
    light_px[..., 3] = np.clip(light_px[..., :3].max(axis=-1) * 1.5, 0.0, 1.0) * light_px[..., 3]
    for light in lights:
        light.hide_render = False
    world_strength.default_value = default_world
    set_glow(False)

    ground.hide_render = False
    for obj in model:
        obj.visible_camera = False
        if obj.name.startswith("RT_Plaza"):
            obj.visible_shadow = False
    shadow_raw = downsample(render(scene, renders / f"{name}-shadow-raw.png"))
    shadow = np.zeros_like(shadow_raw)
    shadow[..., 3] = shadow_raw[..., 3]
    return base, light_px, shadow, center_up, parts
