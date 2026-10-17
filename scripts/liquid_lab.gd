extends Node2D

const Fluid = preload("res://scripts/fluid.gd")
const HALF := 185.0
const FIXED_DT := 1.0 / 120.0
var fluid := Fluid.new()
var center := Vector2(425, 415)
var target := center
var dragging := false
var drag_offset := Vector2.ZERO
var paused := false
var accumulator := 0.0
var viewport: SubViewport
var particle_canvas: Node2D
var blob: ImageTexture
var viscosity_label: Label
var status: Label
var smoke := false
var frames := 0
var smoke_steps := 0
var max_speed := 0.0

func _ready() -> void:
    smoke = "--smoke-test" in OS.get_cmdline_user_args()
    RenderingServer.set_default_clear_color(Color("0b1220"))
    fluid.reset(center)
    make_water()
    make_interface()

func make_water() -> void:
    var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in 64:
        for x in 64:
            var r := Vector2(x - 31.5, y - 31.5).length() / 31.5
            var alpha := pow(maxf(0.0, 1.0 - r * r), 2.0)
            image.set_pixel(x, y, Color(1, 1, 1, alpha))
    blob = ImageTexture.create_from_image(image)
    viewport = SubViewport.new()
    viewport.size = Vector2i(1180, 800)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    particle_canvas = Node2D.new()
    var additive := CanvasItemMaterial.new()
    additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    particle_canvas.material = additive
    viewport.add_child(particle_canvas)
    particle_canvas.draw.connect(draw_particles)
    var water := TextureRect.new()
    water.texture = viewport.get_texture()
    water.size = Vector2(1180, 800)
    water.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var shader_material := ShaderMaterial.new()
    shader_material.shader = preload("res://shaders/water.gdshader")
    water.material = shader_material
    add_child(water)

func draw_particles() -> void:
    for p in fluid.positions:
        particle_canvas.draw_texture_rect(blob, Rect2(p - Vector2.ONE * 14, Vector2.ONE * 28), false)

func label_at(text: String, position: Vector2, size: int, color := Color("dce9f4")) -> Label:
    var label := Label.new()
    label.text = text
    label.position = position
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    add_child(label)
    return label

func button_at(text: String, position: Vector2, callback: Callable, width := 140.0) -> Button:
    var button := Button.new()
    button.text = text
    button.position = position
    button.size = Vector2(width, 42)
    button.pressed.connect(callback)
    add_child(button)
    return button

func make_interface() -> void:
    label_at("T I D A L", Vector2(52, 30), 29)
    label_at("L I Q U I D   L A B", Vector2(54, 72), 12, Color("55c9d8"))
    label_at("A little world in motion.", Vector2(52, 122), 21)
    label_at("Grab the glass. Make a wave.", Vector2(52, 154), 15, Color("8498b0"))
    label_at("01  /  MATERIAL", Vector2(838, 214), 13, Color("55c9d8"))
    label_at("Liquid settings", Vector2(838, 246), 26)
    viscosity_label = label_at("Viscosity  ·  18%", Vector2(838, 310), 17)
    var slider := HSlider.new()
    slider.position = Vector2(838, 352)
    slider.size = Vector2(278, 24)
    slider.min_value = 0
    slider.max_value = 100
    slider.value = 18
    slider.value_changed.connect(func(value: float):
        fluid.viscosity = value / 100.0
        viscosity_label.text = "Viscosity  ·  %d%%" % value)
    add_child(slider)
    label_at("WATER", Vector2(838, 386), 11, Color("8498b0"))
    label_at("THICK SYRUP", Vector2(1024, 386), 11, Color("8498b0"))
    label_at("Low: lively splashes and rolling waves.\nHigh: slower flow and cohesive motion.", Vector2(838, 432), 14, Color("8498b0"))
    button_at("Pause / Play", Vector2(838, 514), func(): paused = not paused)
    button_at("Reset liquid", Vector2(992, 514), reset_liquid, 124)
    label_at("HOW TO PLAY", Vector2(838, 602), 12, Color("55c9d8"))
    label_at("Drag inside the square to move it.\nChange direction to create a surge.\nSpace  pause    ·    R  reset", Vector2(838, 634), 14, Color("8498b0"))
    status = label_at("486 PARTICLES  /  LIVE", Vector2(52, 744), 12, Color("55c9d8"))
    label_at("POSITION-BASED FLUID  ·  120 Hz", Vector2(803, 748), 12, Color("8498b0"))

func reset_liquid() -> void:
    center = Vector2(425, 415)
    target = center
    dragging = false
    accumulator = 0
    fluid.reset(center)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and Rect2(center - Vector2.ONE * HALF, Vector2.ONE * HALF * 2).has_point(get_global_mouse_position()):
            dragging = true
            drag_offset = center - get_global_mouse_position()
        elif not event.pressed:
            dragging = false
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_SPACE:
            paused = not paused
        if event.keycode == KEY_R:
            reset_liquid()

func _process(delta: float) -> void:
    if smoke:
        run_smoke()
        return
    if dragging:
        target = (get_global_mouse_position() + drag_offset).clamp(Vector2(230, 290), Vector2(605, 530))
    if not paused:
        accumulator += minf(delta, 0.05)
        while accumulator >= FIXED_DT:
            simulate(FIXED_DT)
            accumulator -= FIXED_DT
    particle_canvas.queue_redraw()
    queue_redraw()
    status.text = "486 PARTICLES  /  " + ("PAUSED" if paused else ("DRAGGING" if dragging else "LIVE"))

func simulate(dt: float) -> void:
    var old_center := center
    center = center.move_toward(target, 1100.0 * dt)
    fluid.step(dt, center, HALF, (center - old_center) / dt)

func run_smoke() -> void:
    # Fixed simulation steps independent of render speed; exercises wall motion
    # and both ends of the viscosity control, with finite/bounds assertions.
    for iteration in 4:
        var t := smoke_steps * FIXED_DT
        target = Vector2(425 + sin(t * 7.0) * 110, 415 + sin(t * 5.0) * 65)
        fluid.viscosity = 0.0 if smoke_steps < 240 else 1.0
        simulate(FIXED_DT)
        for i in fluid.positions.size():
            var p: Vector2 = fluid.positions[i]
            if not p.is_finite() or not fluid.velocities[i].is_finite() or absf(p.x - center.x) > HALF or absf(p.y - center.y) > HALF:
                push_error("Fluid smoke check failed: invalid or escaped particle")
                get_tree().quit(1)
                return
            max_speed = maxf(max_speed, fluid.velocities[i].length())
        smoke_steps += 1
    frames += 1
    if smoke_steps >= 720:
        if fluid.positions.size() != 486 or max_speed < 50:
            get_tree().quit(1)
            return
        print("FLUID_SMOKE_OK: 720 steps; 486 particles; moving walls; viscosity 0 and 1; finite and confined; max speed=", max_speed)
        get_tree().quit(0)

func _draw() -> void:
    # Quiet drafting grid, glass silhouette and a tactile grab handle.
    for x in range(40, 800, 32):
        for y in range(210, 710, 32):
            draw_circle(Vector2(x, y), 0.8, Color(0.3, 0.48, 0.62, 0.16))
    draw_line(Vector2(800, 210), Vector2(800, 710), Color("253548"), 1)
    var box := Rect2(center - Vector2.ONE * HALF, Vector2.ONE * HALF * 2)
    draw_style_box(glass_style(), box.grow(5))
    draw_rect(box.grow(8), Color(0.27, 0.8, 0.92, 0.08), false, 8)
    draw_rect(box, Color("82b7cd") if dragging else Color("46667e"), false, 2)
    draw_line(box.position + Vector2(12, 4), box.position + Vector2(88, 4), Color("b7deea"), 2)
    for i in 3:
        draw_line(center + Vector2(-12 + i * 12, -HALF - 17), center + Vector2(-12 + i * 12, -HALF - 13), Color("80a3b6"), 3)

func glass_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.16, 0.23, 0.3)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    return style
