// Cattle Herding NUI App

const app = new Vue({
    el: '#app',
    data: {
        isOpen: false,
        showScreen: false,
        currentScreen: null,
        
        // Cattle data
        cattleTypes: [
            {id: 'cow', name: 'Cow', model: 'A_C_Cow', buy_price: 45, sell_base: 60, description: 'Standard dairy cow'},
            {id: 'bull', name: 'Bull', model: 'A_C_Bull_01', buy_price: 70, sell_base: 90, description: 'Strong bull, harder to manage'},
            {id: 'ox', name: 'Ox', model: 'A_C_Ox_01', buy_price: 55, sell_base: 75, description: 'Work ox, steady and reliable'}
        ],
        
        // Buy locations
        buyLocations: [
            {name: 'Emerald Ranch'},
            {name: "McFarlane's Ranch"},
            {name: 'Valentine Stockyard'}
        ],
        
        // Selection state
        selectedType: 'cow',
        herdSize: 5,
        selectedLocation: 'Emerald Ranch',
        
        // Market data
        marketInfo: {},
        
        // Player stats
        playerStats: {},
        
        // Player level
        playerLevel: 1
    },
    
    computed: {
        totalCost() {
            const type = this.cattleTypes.find(t => t.id === this.selectedType);
            return type ? type.buy_price * this.herdSize : 0;
        }
    },
    
    methods: {
        open(screen, data) {
            this.currentScreen = screen;
            this.isOpen = true;
            
            // Apply data if provided
            if (data) {
                if (data.player_level) this.playerLevel = data.player_level;
                if (data.market_info) this.marketInfo = data.market_info;
                if (data.player_stats) this.playerStats = data.player_stats;
            }
            
            // Trigger show animation
            setTimeout(() => {
                this.showScreen = true;
            }, 50);
            
            // Request fresh data based on screen
            if (screen === 'market_prices') {
                this.requestPrices();
            } else if (screen === 'player_stats') {
                this.requestStats();
            }
        },
        
        close() {
            this.showScreen = false;
            
            setTimeout(() => {
                this.isOpen = false;
                this.currentScreen = null;
                
                // Send close event to Lua
                fetch(`https://Cattle-Herding/close`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({})
                });
            }, 300);
        },
        
        buyCattle() {
            const type = this.cattleTypes.find(t => t.id === this.selectedType);
            
            fetch(`https://Cattle-Herding/buyCattle`, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    type: type.model,
                    count: this.herdSize,
                    location: this.selectedLocation
                })
            });
        },
        
        requestPrices() {
            fetch(`https://Cattle-Herding/requestPrices`, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({})
            });
        },
        
        requestStats() {
            fetch(`https://Cattle-Herding/requestStats`, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({})
            });
        }
    },
    
    mounted() {
        // Listen for NUI messages
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            if (data.action === 'open') {
                this.open(data.screen, data.data);
            } else if (data.action === 'close') {
                this.close();
            } else if (data.action === 'updateMarketInfo') {
                this.marketInfo = data.data;
            } else if (data.action === 'updatePlayerStats') {
                this.playerStats = data.data;
            }
        });
        
        // ESC key to close
        window.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen) {
                this.close();
            }
        });
    }
});
