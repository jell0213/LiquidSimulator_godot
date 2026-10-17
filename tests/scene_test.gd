extends SceneTree

func _initialize() -> void:
    call_deferred("verify_scene")

func verify_scene() -> void:
    var scene := preload("res://main.tscn").instantiate()
    var authored_count := count_nodes(scene)
    root.add_child(scene)
    scene.set_process(false)
    assert(count_nodes(scene) == authored_count, "Runtime must not create extra scene nodes")
    assert(scene.particle_nodes.size() == 486)
    var slider: HSlider = scene.get_node("Interface/ViscositySlider")
    slider.value = 73
    assert(is_equal_approx(scene.fluid.viscosity, 0.73))
    scene.get_node("Interface/PauseButton").pressed.emit()
    assert(scene.paused)
    scene.target += Vector2(60, 30)
    scene.simulate(1.0 / 120.0)
    scene.sync_scene()
    assert(scene.get_node("Container").position == scene.center)
    assert(scene.particle_nodes[0].position == scene.fluid.positions[0])
    scene.get_node("Interface/ResetButton").pressed.emit()
    assert(scene.center == scene.initial_center)
    assert(scene.fluid.positions == scene.initial_positions)
    assert(is_equal_approx(scene.fluid.viscosity, 0.73))
    print("SCENE_TEST_OK: authored nodes, 486 sprites, slider, pause, scene synchronization and reset")
    scene.free()
    quit()

func count_nodes(node: Node) -> int:
    var count := 1
    for child in node.get_children():
        count += count_nodes(child)
    return count
