class_name ParticleFluid
extends RefCounted

# Position Based Fluids / double-density relaxation, with spatial hashing.
# Particles carry mass and momentum. Rendering is separate from simulation.
const H := 20.0
const REST_DENSITY := 3.8
const RADIUS := 3.5
const GRAVITY := Vector2(0, 1050)
var positions := PackedVector2Array()
var velocities := PackedVector2Array()
var viscosity := 0.18
var grid: Dictionary = {}
var pairs: Array[Vector2i] = []
var distances := PackedFloat32Array()
var directions := PackedVector2Array()
var density := PackedFloat32Array()
var near_density := PackedFloat32Array()

func reset(center: Vector2) -> void:
    positions.clear()
    velocities.clear()
    for y in range(18):
        for x in range(27):
            positions.append(center + Vector2((x - 13) * 9.1, 15 + y * 9.1))
            velocities.append(Vector2.ZERO)
    density.resize(positions.size())
    near_density.resize(positions.size())

func cell(p: Vector2) -> Vector2i:
    return Vector2i(floori(p.x / H), floori(p.y / H))

func build_pairs() -> void:
    grid.clear()
    pairs.clear()
    distances.clear()
    directions.clear()
    density.fill(0.0)
    near_density.fill(0.0)
    for i in positions.size():
        var key := cell(positions[i])
        if not grid.has(key):
            grid[key] = []
        grid[key].append(i)
    for i in positions.size():
        var key := cell(positions[i])
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                for j: int in grid.get(key + Vector2i(dx, dy), []):
                    if j <= i:
                        continue
                    var delta := positions[j] - positions[i]
                    var distance := delta.length()
                    if distance >= H or distance < 0.001:
                        continue
                    var q := 1.0 - distance / H
                    density[i] += q * q
                    density[j] += q * q
                    near_density[i] += q * q * q
                    near_density[j] += q * q * q
                    pairs.append(Vector2i(i, j))
                    distances.append(q)
                    directions.append(delta / distance)

func step(dt: float, center: Vector2, half_size: float, wall_velocity: Vector2) -> void:
    var previous := positions.duplicate()
    for i in positions.size():
        velocities[i] += GRAVITY * dt
        positions[i] += velocities[i] * dt
    build_pairs()
    # Symmetric pressure corrections conserve pair momentum.
    for k in pairs.size():
        var i := pairs[k].x
        var j := pairs[k].y
        var q := distances[k]
        var pressure := maxf(0.0, 540.0 * (density[i] + density[j] - 2.0 * REST_DENSITY))
        var near_pressure := 2400.0 * (near_density[i] + near_density[j])
        var displacement := directions[k] * (dt * dt * (pressure * q + near_pressure * q * q) * 0.5)
        positions[i] -= displacement
        positions[j] += displacement
    var lower := center - Vector2.ONE * (half_size - RADIUS)
    var upper := center + Vector2.ONE * (half_size - RADIUS)
    for i in positions.size():
        # A hard clamp alone collapses particles onto identical wall coordinates.
        # Such a 1D column has no lateral pressure direction and can support
        # itself vertically forever. Mirror boundary support supplies the missing
        # inward normal pressure from a virtual particle across each wall.
        # This is repulsive only, with no tangential force or wall adhesion.
        var boundary_correction := Vector2.ZERO
        for axis in 2:
            var wall_min := center[axis] - half_size
            var wall_max := center[axis] + half_size
            var left_q := clampf(1.0 - 2.0 * (positions[i][axis] - wall_min) / H, 0.0, 1.0)
            var right_q := clampf(1.0 - 2.0 * (wall_max - positions[i][axis]) / H, 0.0, 1.0)
            boundary_correction[axis] = 2400.0 * dt * dt * (left_q * left_q - right_q * right_q)
        positions[i] += boundary_correction
        positions[i] = positions[i].clamp(lower, upper)
        velocities[i] = (positions[i] - previous[i]) / dt
    # XSPH velocity diffusion gives continuously adjustable viscosity.
    # Accumulate from an immutable velocity snapshot to avoid ordering bias.
    var old_velocity := velocities.duplicate()
    var changes := PackedVector2Array()
    changes.resize(positions.size())
    for k in pairs.size():
        var i := pairs[k].x
        var j := pairs[k].y
        var q := distances[k]
        var weight := minf(0.12, viscosity * dt * 32.0 * q * q)
        var exchange := (old_velocity[j] - old_velocity[i]) * weight
        changes[i] += exchange
        changes[j] -= exchange
    for i in positions.size():
        velocities[i] += changes[i]
        # Collision response is relative to the moving walls, preserving slosh.
        var relative := velocities[i] - wall_velocity
        for axis in 2:
            if positions[i][axis] <= lower[axis] + 0.01 and relative[axis] < 0:
                relative[axis] *= -0.08
            elif positions[i][axis] >= upper[axis] - 0.01 and relative[axis] > 0:
                relative[axis] *= -0.08
        velocities[i] = (relative + wall_velocity).limit_length(1800.0)
