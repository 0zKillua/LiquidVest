
---

### **LiquidVest- Documentation: Decentralized Invoice Discounting Protocol**

#### **Introduction**

The Invoice Discounting Protocol is a decentralized finance (DeFi) solution designed to address liquidity needs for projects with vested assets. It enables grant or token holders to tokenize and sell their future receivables at a discount, offering investors a unique opportunity to purchase these receivables and earn a yield upon maturity. The protocol uses a time-based discount model, with optional fixed risk tiers to simplify risk assessments.

#### **Core Concepts**

The protocol leverages smart contracts on the blockchain to tokenize receivables, manage discount calculations, facilitate resale on a secondary market, and ensure secure transfer of funds. The system operates transparently, allowing issuers to set the risk tier, buyers to assess their investment, and both parties to benefit from decentralized liquidity.

---

### **Workflow Overview**

1. **Tokenization of Receivables**:
   - A project tokenizes its vested receivable, creating a digital asset (ERC-721 or ERC-1155 token) that represents the future payment.
   
2. **Primary Sale to Investors**:
   - The receivable is sold at a discounted rate, based on time left until vesting and an optional risk tier.
   
3. **Secondary Market Resale**:
   - Investors can resell their receivables for an early exit, with the discount dynamically adjusted based on time left and the risk tier initially assigned.
   
4. **Maturity and Payout**:
   - Upon vesting, the protocol transfers the face value of the receivable to the current holder of the token, completing the investment cycle.

---

### **Core Components and Functionality**

#### 1. **Receivable Token Contract (ERC-721 or ERC-1155)**

   - **Purpose**: Tokenizes future receivables as unique or batchable assets.
   - **Key Functions**:
     - `mintReceivable(address issuer, uint256 faceValue, uint256 vestingPeriod, uint8 riskTier)`: 
       - **Inputs**: Issuer’s address, face value of receivable, vesting period, and optional risk tier.
       - **Output**: New token representing the receivable.
     - `burnReceivable(uint256 tokenId)`: 
       - **Input**: Token ID of the matured receivable.
       - **Output**: Burnt token, signaling the completion of the investment.
   - **Risk Tier Options**:
     - `LOW`, `MEDIUM`, `HIGH`: Fixed discount rates associated with each tier, which determine the initial discounted sale price.

#### 2. **Discount Calculation Module**

   - **Purpose**: Calculates the sale price of the receivable, based on time remaining until vesting and the risk tier.
   - **Key Functions**:
     - `calculateDiscountedPrice(uint256 faceValue, uint256 timeRemaining, uint8 riskTier)`: 
       - **Inputs**: Face value of the receivable, time remaining, and risk tier.
       - **Output**: Discounted price for the receivable token.
   - **Formula**:
     - For primary sales, uses time-based discounting with fixed risk tier rates.
     - For secondary sales, recalculates discount based on updated time remaining.

#### 3. **Primary Market Contract**

   - **Purpose**: Facilitates the initial sale of receivables from issuers to investors.
   - **Key Functions**:
     - `listReceivable(uint256 tokenId, uint256 initialDiscountedPrice)`: 
       - **Input**: Token ID and calculated discounted price.
       - **Output**: Receivable is listed on the primary market.
     - `buyReceivable(uint256 tokenId)`: 
       - **Input**: Token ID.
       - **Output**: Transfer of ownership from issuer to investor, in exchange for payment.
   
#### 4. **Secondary Market Contract**

   - **Purpose**: Enables the resale of receivables by investors who want an early exit.
   - **Key Functions**:
     - `listForResale(uint256 tokenId, uint256 newDiscountedPrice)`: 
       - **Inputs**: Token ID and recalculated price based on time remaining.
       - **Output**: Receivable listed for resale on the secondary market.
     - `purchaseResale(uint256 tokenId)`: 
       - **Input**: Token ID.
       - **Output**: Transfer of token to new investor and payment to the seller.
   
#### 5. **Payout Contract**

   - **Purpose**: Manages the final payout upon vesting, ensuring that the current token holder receives the face value.
   - **Key Functions**:
     - `releaseFunds(uint256 tokenId)`: 
       - **Input**: Token ID of the receivable that has matured.
       - **Output**: Transfers face value to the current holder.
     - **Automated Maturity Check**:
       - Monitors token vesting dates and triggers the `releaseFunds` function automatically at maturity.

---

### **Detailed Process Flow**

1. **Token Minting**:
   - The issuer calls `mintReceivable`, specifying the receivable’s details and risk tier.
   - The token is minted, containing metadata about face value, vesting date, and tier.

2. **Discount Calculation**:
   - The protocol uses `calculateDiscountedPrice` to determine the initial sale price.
   - The formula applies a discount based on time to vesting, with optional adjustments based on risk tier (if applicable).

3. **Primary Market Sale**:
   - The receivable is listed on the primary market at the discounted price.
   - An investor can purchase it via `buyReceivable`, which transfers the token and updates ownership.

4. **Secondary Market Resale (Early Exit)**:
   - An investor wanting to exit early lists the token on the secondary market via `listForResale`.
   - The new price is recalculated, factoring in the reduced time left and initial risk tier.
   - A new investor can buy the token via `purchaseResale`, assuming ownership and payment of the adjusted price.

5. **Payout on Maturity**:
   - The protocol monitors vesting dates.
   - Upon maturity, `releaseFunds` transfers the face value to the current holder and burns the token, finalizing the investment.

---

### **Discount Calculation: Example**

The formula uses a time-based discount and optional risk tier, ensuring fair pricing. For example:

1. **Variables**:
   - Face Value: 1000
   - Total Vesting Period: 180 days
   - Time Remaining: 90 days
   - Base Discount Rate: 5%
   - Risk Tier: `MEDIUM` (additional 2%)

2. **Calculation**:
   - Effective Rate = Base + Risk = 5% + 2% = 7%
   - Price with Discount:
     \[
     P_{\text{discounted}} = 1000 \times \frac{1}{(1 + 0.07)^{\frac{90}{365}}} \approx 982
     \]

---

### **Benefits of Time-Based Discounting with Fixed Risk Tiers**

- **Transparency**: Investors can quickly assess expected returns based on time and optional risk tier.
- **Flexibility**: Investors have the option to sell early or hold until maturity, adding liquidity.
- **Simplicity**: A time-based approach with fixed tiers minimizes complexity while accommodating different risk appetites.

---

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
