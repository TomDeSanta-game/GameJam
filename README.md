# Parasite Ascension

## Knight Character

The Knight character has been implemented with basic movement, jumping, and attack capabilities using an AnimatedSprite2D with properly configured animations. The character has a parasitic robot feel with fast movement, low friction, and a dark color palette.

### How to Test

1. Open the project in Godot 4.x
2. Open and run the main scene at `Main/main.tscn`
3. Use the controls below to move the Knight around the level

### Controls

- A/D or Left/Right arrow keys: Move the Knight
- W or Space bar: Jump
- X key: Attack

### Technical Implementation

- The Knight script is located at `Entities/Scripts/Player/Knight.gd`
- The Knight scene is located at `Entities/Scenes/Player/Knight.tscn`
- The Knight character uses AnimatedSprite2D with multiple animation states
- Animation states include: Idle, Run, Jump, Fall, Attack, Death, and Hurt
- Custom input actions are defined for movement, jumping, and attacking
- The eye-dropper shader is applied to give the Knight a darker, parasitic appearance
- Movement parameters are tuned for a faster and more fluid parasitic robot feel:
  - Higher movement speed (500)
  - Lower friction (200)
  - Higher jump power (-500)
  - Moderate acceleration (1000)

## Project Structure

- **Main/main.tscn**: The main scene that loads the level and player
  - The Knight character is instantiated in this scene
- **Levels/level.tscn**: The level with platforms and spawn points
- **Entities/**: Contains all game entities
  - **Scenes/Player/Knight.tscn**: The Knight character scene
  - **Scripts/Player/Knight.gd**: The Knight character script

## LimboAI State Machine

The Knight character uses LimboAI's hierarchical state machine for behavior management. This provides a clean, modular approach to handling different states and transitions.

### State Machine Structure

- **idle**: The default state when not performing any action
- **walk**: Activated when the Knight is moving horizontally
- **jump**: Triggered when the Knight jumps
- **fall**: Triggered when the Knight is falling
- **attack**: Activated when the attack button is pressed

### State Machine Transitions

- **idle → walk**: When horizontal velocity becomes significant
- **idle → jump**: When jump button is pressed
- **idle → fall**: When not on floor and falling
- **walk → idle**: When horizontal velocity becomes negligible
- **walk → jump**: When jump button is pressed
- **walk → fall**: When not on floor and falling
- **jump → fall**: When vertical velocity becomes positive
- **jump → idle/walk**: When Knight lands on ground (based on velocity)
- **fall → idle/walk**: When Knight lands on ground (based on velocity)
- **Any State → attack**: When attack button is pressed
- **attack → idle/walk/jump/fall**: When attack animation completes (based on current conditions)

### Implementation Details

The state machine is implemented using Godot's LimboAI plugin:

1. Each state is created as a `LimboState` object
2. Transitions are defined using `add_transition` method of `LimboHSM`
3. State signals (`on_enter`, `on_update`, `on_exit`) are connected to handler functions
4. Handler functions use `match` statements to process state-specific logic
5. The AnimatedSprite2D plays the appropriate animation for each state

## Eye-Dropper Shader

The Knight character uses the eye-dropper shader to create a darker, parasitic appearance:

1. The shader replaces bright colors with a dark gray/black color
2. This creates a menacing, parasitic robot aesthetic
3. The shader is applied dynamically at runtime
4. The color replacement is configured using palette arrays

## Scene Organization

The project follows a clean scene hierarchy:

```
Main/ (Main scene)
├── Level (Level scene instance)
│   ├── PlayerSpawnPoint
│   ├── Ground
│   └── Platforms
└── Knight (Player character)
```

The Knight character is instantiated directly in the Main scene, not as part of the level. This approach:

1. Makes it easier to handle player persistence between levels
2. Provides more flexibility for camera control and player-specific UI elements
3. Separates level design from player implementation

## Customization

You can customize the Knight by:

1. Adjusting movement parameters in the Knight script
2. Adding new states to the LimboAI state machine
3. Creating additional transitions between states
4. Modifying the animation frames or speeds
5. Changing the input controls in the Project Settings
6. Adjusting the eye-dropper shader color palette

## Future Enhancements

- Add more attack patterns using the state machine
- Implement enemy interactions with their own state machines
- Add sound effects and particles
- Implement health and damage system
- Create additional levels and environmental hazards 