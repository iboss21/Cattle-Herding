# Cattle Herding - RedM Script

An immersive RedM (Red Dead Redemption 2 Multiplayer) mod that adds **controller-compatible cattle herding**, buying and selling mechanics, dynamic pricing, AI cowboys, rustlers, and a comprehensive experience system with a fully toggleable HUD and UI.

## Features

### 🐄 Immersive Cattle Herding
- Herd cattle across the map with realistic AI behavior
- Cattle follow you as you build your herd
- Maximum herd size increases with level (10 at start, up to 20 at level 10)
- Controller-compatible prompts for easy interaction

### 💰 Buying and Selling System
- Three cattle shop locations:
  - Valentine Livestock
  - Emerald Ranch Livestock
  - Blackwater Livestock
- Sell your herded cattle for profit
- Track your total sales and earnings

### 📈 Dynamic Pricing System
- Cattle prices fluctuate based on market conditions
- Prices update every 5 minutes with ±15% variation
- Different cattle types have different base values:
  - Cows: $50 base price
  - Bulls: $75 base price
  - Oxen: $60 base price
- Check current prices with `/cattleprices` command

### 🤠 AI Cowboys
- Friendly cowboys randomly spawn near your herd
- 10% chance when actively herding
- Cowboys can interact with you and your cattle
- Adds immersion to the herding experience

### 🔫 Rustlers
- Hostile rustlers may attack while you're herding
- 5% chance to spawn when you have cattle
- Defeat rustlers to earn bonus XP (+25 XP per rustler)
- Protect your herd from theft!

### 📊 Experience System
- Gain XP by herding cattle (+5 XP per cattle)
- Gain XP by selling cattle (+10 XP per cattle)
- Gain XP by defeating rustlers (+25 XP)
- 10 levels with increasing requirements
- Level bonuses:
  - Level 2: 5% better selling prices
  - Level 3: 10% better selling prices
  - Level 5: Maximum herd size increased to 15
  - Level 7: 15% better selling prices
  - Level 10: Maximum herd size increased to 20

### 🎮 Controller Support
- Fully compatible with game controllers
- Right Bumper (RB/R1): Herd nearby cattle
- Left Bumper (LB/L1): Open shop menu
- Context button (E/Cross): Interact with shops

### 📱 HUD and UI
- Real-time display of:
  - Current level
  - Current XP
  - Number of cattle in herd
  - Maximum herd capacity
- Fully toggleable HUD and UI
- Customizable HUD position

## Installation

1. Download or clone this repository
2. Place the `Cattle-Herding` folder in your RedM `resources` directory
3. Add `ensure Cattle-Herding` to your `server.cfg`
4. Restart your RedM server

## Configuration

All settings can be customized in `config.lua`:

- **HUD/UI Settings**: Enable/disable and position the HUD
- **Cattle Settings**: Configure cattle models and herding parameters
- **Shop Locations**: Customize shop positions and blips
- **Pricing**: Adjust base prices and price variation
- **AI Settings**: Configure spawn chances for cowboys and rustlers
- **XP System**: Modify level requirements and bonuses
- **Controller Settings**: Customize button mappings

## Commands

### Player Commands
- `/togglecattlehud` - Toggle the cattle herding HUD on/off
- `/togglecattleui` - Toggle the cattle UI on/off
- `/cattlestats` - View your cattle herding statistics
- `/cattleprices` - Check current cattle prices

### Admin Commands (Console Only)
- `setcattlexp <player_id> <xp>` - Set a player's XP
- `resetcattleprices` - Reset all cattle prices to base values

## How to Play

1. **Find Cattle**: Look for cows, bulls, and oxen around the map
2. **Herd Cattle**: Approach cattle and press RB/R1 (or use the prompt) to add them to your herd
3. **Build Your Herd**: Collect up to your maximum herd size
4. **Watch for Events**:
   - Friendly cowboys may appear to help
   - Rustlers may attack - defend your herd!
5. **Sell Your Herd**: Take your cattle to any livestock shop (marked on the map)
6. **Earn Money and XP**: Sell your cattle for profit and experience
7. **Level Up**: Gain better prices and larger herd capacity as you level up

## Tips

- Keep an eye on cattle prices - sell when prices are high!
- Higher levels give better selling prices
- Defeat rustlers for bonus XP
- Build larger herds as you level up for more profit per trip
- Use the HUD to track your progress

## Compatibility

- RedM (Red Dead Redemption 2 Multiplayer)
- Requires a RedM server
- Compatible with most RedM frameworks
- Controller and keyboard/mouse support

## Credits

- **Author**: iboss21
- **Version**: 1.0.0

## Support

For issues, suggestions, or contributions, please visit the GitHub repository.

## License

This project is open source and available for modification and redistribution.