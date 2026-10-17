extends SceneTree

const Fluid = preload("res://scripts/fluid.gd")

func energy(fluid: ParticleFluid) -> float:
    var average := Vector2.ZERO
    for velocity in fluid.velocities:
        average += velocity
    average /= fluid.velocities.size()
    var total := 0.0
    for velocity in fluid.velocities:
        total += velocity.distance_squared_to(average)
    return total

func _initialize() -> void:
    var thin := Fluid.new()
    var thick := Fluid.new()
    for fluid in [thin, thick]:
        fluid.reset(Vector2.ZERO)
        for i in fluid.velocities.size():
            fluid.velocities[i] = Vector2(100 if i % 2 == 0 else -100, 0)
    thin.viscosity = 0
    thick.viscosity = 1
    thin.step(1.0 / 120, Vector2.ZERO, 185, Vector2.ZERO)
    thick.step(1.0 / 120, Vector2.ZERO, 185, Vector2.ZERO)
    var thin_energy := energy(thin)
    var thick_energy := energy(thick)
    if thick_energy >= thin_energy * 0.95:
        push_error("Viscosity failed to damp relative particle motion")
        quit(1)
        return
    print("VISCOSITY_TEST_OK: relative energy thin=", thin_energy, " thick=", thick_energy)
    quit(0)
