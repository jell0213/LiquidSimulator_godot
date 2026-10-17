extends SceneTree
const Fluid = preload("res://scripts/fluid.gd")

func _initialize() -> void:
    for viscosity in [0.0, 1.0]:
        if not check_columns(viscosity) or not check_shake_and_rest(viscosity):
            quit(1)
            return
    print("WALL_RELEASE_TEST_OK: both walls, viscosity 0 and 1, shake then rest")
    quit(0)

func check_columns(viscosity: float) -> bool:
    var fluid := Fluid.new()
    fluid.viscosity = viscosity
    # Reproduce columns flattened by wall projection after a hard shake.
    for side in [-1.0, 1.0]:
        for i in 60:
            fluid.positions.append(Vector2(side * (185.0 - Fluid.RADIUS), -140 + i * 5.2))
            fluid.velocities.append(Vector2.ZERO)
    fluid.density.resize(fluid.positions.size())
    fluid.near_density.resize(fluid.positions.size())
    for frame in 600:
        fluid.step(1.0 / 120.0, Vector2.ZERO, 185, Vector2.ZERO)
    var elevated := 0
    var mean_y := 0.0
    for p in fluid.positions:
        if p.y < 100:
            elevated += 1
        mean_y += p.y / fluid.positions.size()
    print("WALL_RELEASE elevated=", elevated, " mean_y=", mean_y)
    if elevated > 6 or mean_y < 120:
        push_error("Unsupported wall columns must fall and form a bottom pool")
        return false
    return true

func check_shake_and_rest(viscosity: float) -> bool:
    var fluid := Fluid.new()
    fluid.reset(Vector2.ZERO)
    fluid.viscosity = viscosity
    var center := Vector2.ZERO
    for frame in 1200:
        var previous := center
        if frame < 240:
            center = Vector2(sin(frame / 120.0 * 9) * 110, sin(frame / 120.0 * 5) * 65)
        fluid.step(1.0 / 120.0, center, 185, (center - previous) * 120)
        for i in fluid.positions.size():
            var relative := fluid.positions[i] - center
            if not relative.is_finite() or not fluid.velocities[i].is_finite() or absf(relative.x) > 181.51 or absf(relative.y) > 181.51:
                push_error("Invalid or escaped particle during shake/rest")
                return false
    var high_wall_particles := 0
    var mean_y := 0.0
    for p in fluid.positions:
        var relative := p - center
        if absf(relative.x) > 165 and relative.y < 60:
            high_wall_particles += 1
        mean_y += relative.y / fluid.positions.size()
    print("SHAKE_REST viscosity=", viscosity, " high_wall_particles=", high_wall_particles, " mean_y=", mean_y)
    if high_wall_particles > 4 or mean_y < 110:
        push_error("Liquid must settle after the container stops")
        return false
    return true
