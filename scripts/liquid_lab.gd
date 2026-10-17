extends Node2D

const Fluid = preload("res://scripts/fluid.gd")
const HALF := 185.0
const FIXED_DT := 1.0 / 120.0
var fluid := Fluid.new()
var center := Vector2.ZERO
var target := Vector2.ZERO
var initial_center := Vector2.ZERO
var initial_positions := PackedVector2Array()
var particle_nodes: Array[Sprite2D] = []
var dragging := false
var drag_offset := Vector2.ZERO
var paused := false
var accumulator := 0.0
@onready var container: Node2D = $Container
@onready var particle_canvas: Node2D = $LiquidViewport/Particles
@onready var viscosity_label: Label = $Interface/ViscosityLabel
@onready var viscosity_slider: HSlider = $Interface/ViscositySlider
@onready var status: Label = $Interface/Status
var smoke := false
var frames := 0
var smoke_steps := 0
var max_speed := 0.0

func _ready() -> void:
    smoke = "--smoke-test" in OS.get_cmdline_user_args()
    RenderingServer.set_default_clear_color(Color("0b1220"))
    center = container.position
    initial_center = center
    target = center
    for child in particle_canvas.get_children():
        if child is Sprite2D:
            particle_nodes.append(child)
            initial_positions.append(child.position)
    restore_particles()
    _on_viscosity_changed(viscosity_slider.value)

func restore_particles() -> void:
    fluid.positions = initial_positions.duplicate()
    fluid.velocities.resize(initial_positions.size())
    fluid.velocities.fill(Vector2.ZERO)
    fluid.density.resize(initial_positions.size())
    fluid.near_density.resize(initial_positions.size())
    sync_scene()

func sync_scene() -> void:
    container.position = center
    for i in particle_nodes.size():
        particle_nodes[i].position = fluid.positions[i]

func _on_viscosity_changed(value: float) -> void:
    fluid.viscosity = value / 100.0
    viscosity_label.text = "Viscosity  ·  %d%%" % value

func _on_pause_pressed() -> void:
    paused = not paused

func reset_liquid() -> void:
    center = initial_center
    target = center
    dragging = false
    accumulator = 0
    restore_particles()

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
        sync_scene()
        return
    if dragging:
        target = (get_global_mouse_position() + drag_offset).clamp(Vector2(230, 290), Vector2(605, 530))
    if not paused:
        accumulator += minf(delta, 0.05)
        while accumulator >= FIXED_DT:
            simulate(FIXED_DT)
            accumulator -= FIXED_DT
    sync_scene()
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
