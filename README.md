# 🐄 tlw_cattle_herding - Professional Cattle Ranching for RedM

<div align="center">

**The Land of Wolves**  
🌐 [www.wolves.land](https://www.wolves.land)

**Developer:** iBoss  
**Primary Framework:** [LXRCore](https://github.com/lxrcore)  
**Multi-Framework Support:** LXRCore, RSG-Core

[![Version](https://img.shields.io/badge/version-2.1.0-blue.svg)](https://github.com/iboss21/tlw_cattle_herding)
[![Framework](https://img.shields.io/badge/framework-LXRCore%20%7C%20RSG--Core-green.svg)](https://github.com/lxrcore)

</div>

---

A comprehensive, immersive cattle herding system for RedM featuring organic herd AI, dynamic market prices, XP progression, AI cowboys, rustler encounters, and a fully functional economy system.

## 📸 Screenshots

> **Note:** Screenshots should be captured in-game. See [screenshots/README.md](screenshots/README.md) for details on required screenshots.

<!-- Uncomment when screenshots are available
![Normal Herding](screenshots/normal_herding.png)
*Herding cattle peacefully across the frontier*

![Mission Failed](screenshots/mission_failed_notification.png)
*Safety feature: Mission fails when player kills own cattle*
-->

## ✨ Features

### 🎮 Core Gameplay
- **Organic Herd AI**: Cattle behave naturally with grazing, cohesion, panic states, and leader/follower dynamics
- **Position-Based Herding**: Control your herd through positioning and movement, not UI buttons
- **Buy & Sell System**: Purchase cattle at ranches, herd them to markets, and sell for profit
- **Dynamic Pricing**: Market prices fluctuate daily based on demand, location, time of day, and distance
- **Controller & Keyboard Support**: Full compatibility with both input methods
- **🆕 Safety Feature**: Mission fails if player kills their own cattle (prevents pelt/meat exploits)

### 📊 Progression System
- **20 Levels**: Earn XP by herding, selling cattle, and defeating rustlers
- **Level Benefits**: Unlock larger herds, better prices, reduced panic, and AI cowboys
- **Persistent Statistics**: Track deliveries, earnings, cattle saved/lost, and more
- **Price Bonuses**: Higher levels earn better sale prices (up to +25%)

### 🤖 AI Systems
- **AI Cowboys**: Hire helpers at level 8+ to assist with herding and defense
- **Rustler Encounters**: Random ambushes that can steal your cattle
- **Natural Behavior**: Cattle graze, wander, panic at gunfire, and maintain herd cohesion

### 🎯 Advanced Features
- **Straggler Management**: Track and recover cattle that wander too far
- **Panic System**: Realistic fear responses to threats with spread mechanics
- **Distance Tracking**: Earn bonuses for long-distance drives
- **Time Bonuses**: Night premium and fast delivery rewards
- **Survival Bonuses**: Perfect deliveries earn significant rewards

### 🎨 User Interface
- **Minimal HUD**: Clean overlay showing herd count, state, and stragglers
- **Western-Themed NUI**: Beautiful, immersive menus for buying and viewing stats
- **Toggle Options**: Hide/show HUD and UI elements as preferred
- **Debug Mode**: Visualization tools for testing and development

### 🛡️ Security
- **Server-Authoritative**: All payouts and validation happen server-side
- **Anti-Exploit**: Distance checking, rate limiting, entity validation
- **Token System**: Secure contract tracking prevents duplication exploits
- **Mission Failure**: Automatic detection of player killing their own cattle

## 📦 Installation

### Prerequisites
- RedM server
- **LXRCore** framework (primary) OR **RSG-Core** framework (supported)
- oxmysql resource

### Steps

1. **Download/Clone the Repository**
   ```bash
   cd resources
   git clone https://github.com/iboss21/Cattle-Herding.git tlw_cattle_herding
   ```

2. **Install Database**
   - Import `sql/install.sql` into your database
   - This creates the required tables with default market data

3. **Configure Framework**
   - Edit `config.lua` and set your framework:
   ```lua
   Config.Framework = 'LXRCore'  -- or 'RSG' for RSG-Core
   ```
   - The script will auto-detect if not configured

4. **Configure Locations and Settings**
   - Edit `config.lua` to customize locations, prices, and behavior
   - Adjust to your server's economy and balance preferences

5. **Add to server.cfg**
   ```cfg
   ensure oxmysql
   ensure lxr-core    # or rsg-core if using RSG-Core
   ensure tlw_cattle_herding
   ```

6. **Restart Server**
   ```bash
   restart tlw_cattle_herding
   ```

## 🎮 How to Play

### Starting Your First Herd

1. **Travel to a Buy Location**
   - Emerald Ranch
   - McFarlane's Ranch  
   - Valentine Stockyard

2. **Purchase Cattle**
   - Approach the buy marker
   - Hold E/Cross to buy cattle
   - Start with 5 cows to learn the basics

3. **Herd Your Cattle**
   - Position yourself **behind** the herd
   - Cattle will naturally move away from you
   - Use **Arrow Keys** to adjust speed and direction:
     - **Up Arrow**: Increase herd speed
     - **Down Arrow**: Decrease herd speed
     - **Left/Right Arrow**: Bias herd direction
   - Stay calm - galloping near cattle causes panic!

4. **Manage Stragglers**
   - Watch HUD for straggler warnings
   - Ride back to collect wandering cattle
   - Stragglers will try to return to herd automatically

5. **Deliver to Market**
   - Drive herd to any sell location:
     - Valentine Auction Yard (1.0x prices)
     - Blackwater Market (1.05x prices)
     - Saint Denis Market (1.2x prices - best but furthest)
   - Enter the sell radius with your herd
   - Hold E/Cross to sell and get paid

### Tips for Success

- **Position Matters**: Stay 8-10 meters behind the herd for optimal control
- **Go Slow**: Cattle move better at walking pace
- **Night Drives**: Earn 12% more but face higher rustler risk
- **Perfect Deliveries**: No losses = $150 bonus + 100 XP
- **Level Up**: Higher levels = better prices and easier herding
- **Hire Cowboys**: Level 8+ can hire AI helpers ($75 each)

## ⌨️ Commands

### Player Commands
- `/togglecattlehud` - Toggle the HUD overlay
- `/cattlemenu` - Open buy menu (when not herding)
- `/cattleprices` - View current market prices
- `/cattlestats` - View your ranching statistics

### Admin Commands
- `/cattle_setxp <player_id> <xp>` - Set player XP
- `/cattle_setdemand <location> <demand>` - Adjust market demand (0.5-2.0)
- `/cattle_debug` - Toggle debug visualization
- `/cattle_reset <player_id>` - Reset player data
- `/cattle_updateprices` - Force market price update

## ⚙️ Configuration

### Key Config Sections

#### Locations
```lua
Config.BuyRanches = {...}  -- Where to buy cattle
Config.SellYards = {...}   -- Where to sell cattle
```

#### Herd Behavior
```lua
Config.HerdBehavior = {
    cohesion_radius = 12.0,
    panic_duration_min = 12,
    straggler_threshold = 35.0,
    -- ... and many more tuning options
}
```

#### Pricing
```lua
Config.Pricing = {
    variance = {min = 0.80, max = 1.20},
    night_premium = 1.12,
    distance_bonus_per_km = 0.012,
}
```

#### XP System
```lua
Config.XP = {
    per_cattle_sold = 12,
    per_km_driven = 3,
    perfect_delivery = 120,
}
```

See `config.lua` for the complete list of options.

## 🎯 XP & Levels

### Level Benefits
- **Level 3**: Cattle panic 15% less
- **Level 5**: +5% sell prices
- **Level 7**: Cattle follow better
- **Level 8**: Unlock AI Cowboys
- **Level 10**: +10% prices, Max herd +5
- **Level 15**: +15% prices
- **Level 20**: Master Rancher - +20% prices, Max herd +10

### XP Sources
- **Per Cattle Sold**: 12 XP
- **Per KM Driven**: 3 XP  
- **Perfect Delivery**: 120 XP
- **Rustler Defeated**: 30 XP
- **Per Minute Active**: 1 XP

## 🐎 AI Cowboys

Unlock at Level 8 | Cost: $75 each | Max: 2

**What They Do:**
- Position themselves around the herd
- Push stragglers back to the group
- Fire warning shots at rustlers
- Defend you in combat

**How to Hire:**
- Must have active herd
- Use command or NUI menu
- Cowboys spawn immediately and follow herd

## 🔫 Rustlers

**Spawn Conditions:**
- Random chance every 2 minutes while herding
- Higher chance at night (1.8x)
- Higher chance with valuable herds
- Higher chance far from towns

**What They Do:**
- Attack you and your cattle
- Can steal cattle (25% chance per attempt)
- Scare herd causing panic
- Drop money when defeated

**Rewards:**
- 30 XP per rustler killed
- $8 per rustler
- 100 XP bonus if all defeated

## 🛠️ Troubleshooting

### Cattle Won't Spawn
- Check database connection
- Verify model names in config match game models
- Check server console for errors

### Prices Not Updating
- Ensure oxmysql is running
- Check database table `tlw_cattle_market` exists
- Use `/cattle_updateprices` to force update

### HUD Not Showing
- Press F7 or use `/togglecattlehud`
- Check `Config.HUD.enabled = true`

### Can't Sell Cattle
- Ensure herd is within sell radius
- Check cattle are alive
- Verify server events are working

## 📊 Performance

- **Optimized AI**: Updates at 400-1000ms intervals
- **Distance Culling**: Cattle beyond 200m don't tick
- **Entity Cleanup**: Automatic cleanup of old entities
- **Database Efficiency**: Batched updates, cached data

## 🔐 Security Features

- Server-side payout calculation
- Entity ownership verification
- Distance/speed exploit detection
- Rate limiting on purchases/sales
- Token-based contract validation
- SQL injection prevention
- **NEW:** Mission failure detection when player kills own cattle

## 🤝 Support

For issues, suggestions, or contributions:
- **Website:** [www.wolves.land](https://www.wolves.land)
- **GitHub Issues:** [Report a Bug](https://github.com/iboss21/tlw_cattle_herding/issues)
- **Pull Requests Welcome!**

## 📜 License

Open source - Free to use and modify for your RedM server.

## 🙏 Credits

- **Developer:** iBoss
- **Organization:** The Land of Wolves (www.wolves.land)
- **Primary Framework:** LXRCore (github.com/lxrcore)
- **Supported Frameworks:** RSG-Core
- **Inspiration:** Authentic Red Dead Redemption 2 cattle herding experience

## 🔄 Version History

### v2.1.0 (Current)
- **Multi-Framework Support:** LXRCore (primary) and RSG-Core
- **Safety Feature:** Mission fails if player kills their own cattle
- **Rebranded:** The Land of Wolves (www.wolves.land)
- **Enhanced Security:** Failed delivery tracking in database
- **Auto-Detection:** Automatically detects available framework
- **Code Review:** Improved detection logic to prevent false positives

### v2.0.0
- Complete rewrite with organic herd AI
- RSG-Core integration
- Dynamic pricing system
- XP progression (20 levels)
- AI Cowboys
- Rustler encounters
- Western-themed NUI
- Debug visualization
- Comprehensive configuration

---

**Enjoy your cattle ranching adventure!** 🤠🐄
