#!/usr/bin/env godot -s
extends SceneTree

func _init():
    # Create the main node
    var main_node = Node.new()
    main_node.name = "Main"
    
    # Set the script
    var main_script = load("res://Main/Main.gd")
    main_node.set_script(main_script)
    
    # Create scene
    var scene = PackedScene.new()
    
    # Add Level node
    var level_scene = load("res://Levels/level.tscn")
    var level_instance = level_scene.instantiate()
    level_instance.name = "Level"
    main_node.add_child(level_instance)
    level_instance.owner = main_node
    
    # Add Knight node
    var knight_scene = load("res://Entities/Scenes/Player/Knight.tscn")
    var knight_instance = knight_scene.instantiate()
    knight_instance.name = "Knight"
    knight_instance.position = Vector2(400, 250)
    main_node.add_child(knight_instance)
    knight_instance.owner = main_node
    
    # Add DirectPlayerRegistration node
    var reg_node = Node.new()
    reg_node.name = "DirectPlayerRegistration"
    var reg_script = load("res://ai/tasks/direct_player_registration.gd")
    reg_node.set_script(reg_script)
    reg_node.set("player_path", NodePath("../Knight"))
    reg_node.set("debug", true)
    main_node.add_child(reg_node)
    reg_node.owner = main_node
    
    # Pack the scene
    var result = scene.pack(main_node)
    if result == OK:
        print("Scene packed successfully")
        var error = ResourceSaver.save(scene, "res://Main/main.tscn")
        if error == OK:
            print("Scene saved successfully")
        else:
            print("Failed to save scene: ", error)
    else:
        print("Failed to pack scene: ", result)
    
    quit() 