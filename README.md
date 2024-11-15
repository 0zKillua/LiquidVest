File structure: 
```
- src/
├── core/
│   ├── BaseReceivable.sol
│   ├── DiscountCalculator.sol
│   └── RiskManager.sol
├── market/
│   ├── PrimaryMarket.sol
│   ├── SecondaryMarket.sol
│   └── MarketRouter.sol
├── finance/
│   ├── PayoutManager.sol
│   ├── EscrowVault.sol
│   └── FeeController.sol
├── governance/
│   ├── ProtocolConfig.sol
│   └── AccessController.sol
├── interfaces/
│   ├── IBaseReceivable.sol
│   ├── IDiscountCalculator.sol
│   ├── IMarket.sol
│   ├── IPayout.sol
│   └── IRiskManager.sol
├── libraries/
│   ├── DiscountMath.sol
│   ├── TimeUtils.sol
│   └── SecurityUtils.sol
└── mocks/
    ├── MockERC20.sol
    └── MockOracle.sol
```
