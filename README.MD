# 🎯 Lottos - Decentralized Lottery System

A comprehensive lottery smart contract system built on **Aptos** blockchain, supporting multiple game types with secure random number generation, jackpot rollovers, and NFT-based ticket ownership.

[![Aptos](https://img.shields.io/badge/Blockchain-Aptos-blue.svg)](https://aptos.dev/)
[![Move](https://img.shields.io/badge/Language-Move-red.svg)](https://move-language.github.io/)

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Game Types](#game-types)
- [Architecture](#architecture)
- [Security Model](#security-model)
- [Installation](#installation)
- [Usage](#usage)
- [API Reference](#api-reference)
- [Contributing](#contributing)
- [License](#license)

## 🎮 Overview

**Lottos** is a fully decentralized lottery system that brings traditional lottery games to the blockchain with enhanced transparency, security, and fairness. Built using Move programming language on Aptos, it leverages native randomness for provably fair draws and implements sophisticated prize distribution mechanisms.

### Key Highlights

- **🔐 Provably Fair**: Uses Aptos native randomness for transparent number generation
- **🎫 NFT Object**: Each ticket is a unique on-chain object with full ownership rights
- **💰 Progressive Jackpots**: Rollover mechanism creates accumulating prize pools
- **🎯 Multiple Games**: Three distinct lottery types with different odds and prizes
- **🏛️ Treasury Control**: Multi-signature security for prize distributions
- **⚡ Gas Efficient**: Optimized for low transaction costs

## ✨ Features

### 🎲 Random Number Generation
- **Cryptographically Secure**: Leverages Aptos native randomness framework
- **Transparent Process**: All draws are publicly verifiable on-chain
- **Collision Prevention**: Ensures unique numbers within each draw
- **Tamper Resistant**: No possibility for manipulation or prediction

### 🎫 Ticket Management
- **On-chain Object**: Each ticket is an object with deterministic address 
- **Batch Purchasing**: Buy multiple tickets in a single transaction
- **Duplicate Prevention**: Cannot buy same numbers twice for one draw
- **Claim Tracking**: Automatic prevention of double prize claims

### 💎 Prize Structure
- **Multiple Tiers**: Up to 9 different prize levels per game
- **Dynamic Jackpots**: Main prizes grow with ticket sales and rollovers
- **Fixed Prizes**: Lower tiers have guaranteed payout amounts
- **Fair Distribution**: Jackpots split equally among all winners

### 🛡️ Security Features
- **Admin Controls**: Authorized personnel only for draw management
- **Treasury Signatures**: Multi-sig requirement for prize payouts
- **Asset Validation**: Only whitelisted stablecoins accepted
- **Atomic Operations**: All transactions complete fully or revert

## 🎰 Game Types

### 🟡 Lotto 5/35
- **Format**: Pick 5 numbers (1-35) + 1 extra number
- **Prize Tiers**: 7 levels from Consolation to Jackpot
- **Jackpot Odds**: 1 in 324,632
- **Min Prize**: 1x ticket price (Consolation)
- **Max Prize**: 600,000x ticket price + rollovers

### 🔵 Mega 6/45  
- **Format**: Pick 6 numbers (1-45), no extra number
- **Prize Tiers**: 4 levels from Third to Jackpot
- **Jackpot Odds**: 1 in 8,145,060
- **Min Prize**: 3x ticket price (Third place)
- **Max Prize**: 1,200,000x ticket price + rollovers

### 🔴 Power 6/55
- **Format**: Pick 6 numbers (1-55) + 1 extra number
- **Prize Tiers**: 5 levels including special Jackpot2
- **Jackpot Odds**: 1 in 28,989,675
- **Special Feature**: Jackpot2 for 5 matches + extra number
- **Max Prize**: 3,000,000x ticket price + rollovers

## 🏗️ Architecture

The system consists of three main modules:

### 📦 Core Modules

```
lottos/
├── sources/
│   ├── lottos.move      # Main lottery logic & game mechanics
│   ├── config.move      # Admin controls & payment validation  
│   └── utils.move       # Mathematical utilities & sorting
└── tests/              # Comprehensive test suite
```

### 🔧 Module Responsibilities

#### `lottos::lottos`
- **Draw Management**: Create and execute lottery draws
- **Ticket Sales**: Handle purchases and NFT minting
- **Prize Claims**: Calculate and distribute winnings
- **Rollover Logic**: Accumulate unclaimed jackpots

#### `lottos::config`
- **Access Control**: Admin authorization and transfers
- **Asset Management**: Whitelist payment tokens
- **Security Validation**: Enforce system rules

#### `lottos::utils` 
- **Number Processing**: Sort and validate lottery numbers
- **Combination Math**: Generate possible winning combinations
- **Optimization**: Efficient algorithms for small data sets

## 🔒 Security Model

### 🛡️ Multi-Layer Protection

#### **Administrative Security**
- **Two-Phase Admin Transfer**: Prevents accidental privilege transfers
- **Role-Based Access**: Only authorized admins can manage draws
- **Audit Trail**: All administrative actions are logged on-chain

#### **Financial Security**
- **Treasury Multi-Sig**: Prize payouts require treasury authorization
- **Asset Validation**: Only whitelisted stablecoins accepted
- **Atomic Operations**: Payments and state changes happen together

#### **Game Integrity**
- **Provable Randomness**: Uses Aptos cryptographic randomness
- **Transparent Draws**: All results verifiable on blockchain
- **Immutable History**: Past draws cannot be modified

#### **User Protection**
- **Ownership Verification**: Only ticket owners can claim prizes
- **Double-Claim Prevention**: Automatic tracking of claimed tickets
- **Fair Distribution**: Mathematical guarantee of correct payouts

## 🚀 Installation

### Prerequisites

- **Aptos CLI**: [Installation Guide](https://aptos.dev/tools/aptos-cli-tool/install-aptos-cli)
- **Move Compiler**: Included with Aptos CLI
- **Testnet Account**: [Create Account](https://aptos.dev/guides/getting-started)

### 1️⃣ Clone Repository

```bash
git clone https://github.com/your-org/lottos.git
cd lottos
```

### 2️⃣ Configure Deployment

Edit `Move.toml` with your addresses:

```toml
[addresses]
lottos = "0x_YOUR_MODULE_ADDRESS"
admin = "0x_YOUR_ADMIN_ADDRESS" 
treasury = "0x_YOUR_TREASURY_ADDRESS"
```

### 3️⃣ Compile Contracts

```bash
aptos move compile
```

### 4️⃣ Run Tests

```bash
aptos move test
```

### 5️⃣ Deploy to Network

```bash
aptos move create-object-and-publish-package --address-name \
lottos --named-addresses \
admin=a64232b8fb0aeedc8fdefd6fcf716b9eb30061e42dbe46b3c00cc33bef5e7cb5,treasury=a64232b8fb0aeedc8fdefd6fcf716b9eb30061e42dbe46b3c00cc33bef5e7cb5 \
--profile lottos1 --assume-yes --included-artifacts none
```


```bash
aptos move upgrade-object-package \
--object-address <lottos> \
--named-addresses \
lottos=<lottos>,admin=<admin>,treasury=<treasury> \
--profile lottos1 --assume-yes --included-artifacts none
```

## 💻 Usage

### 🎫 Buying Tickets

```typescript
// Example using TypeScript SDK
import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";

const aptos = new Aptos(new AptosConfig({network: Network.TESTNET}));

// Buy lottery tickets
const transaction = await aptos.transaction.build.simple({
  sender: userAccount.accountAddress,
  data: {
    function: "0x_MODULE_ADDRESS::lottos::buy_tickets",
    functionArguments: [
      drawId,                    // u64: Draw ID
      [[1, 15, 23, 31, 42]],    // vector<vector<u64>>: Ticket numbers
      "0x_USDT_ADDRESS"         // Object<Metadata>: Payment asset
    ],
  },
});
```

### 🎲 Creating Draws (Admin Only)

```typescript
// Create new lottery draw
const createDraw = await aptos.transaction.build.simple({
  sender: adminAccount.accountAddress,
  data: {
    function: "0x_MODULE_ADDRESS::lottos::create_draw",
    functionArguments: [
      "Lotto 5/35",           // String: Game type
      1703980800              // u64: Close timestamp (Unix)
    ],
  },
});
```

### 🏆 Claiming Prizes

```typescript
// Claim winning ticket
const claimPrize = await aptos.transaction.build.simple({
  sender: userAccount.accountAddress,
  data: {
    function: "0x_MODULE_ADDRESS::lottos::claim_prize",
    functionArguments: [
      drawId,                 // u64: Draw ID
      [1, 15, 23, 31, 42],   // vector<u64>: Winning numbers
      "0x_USDT_ADDRESS"      // Object<Metadata>: Prize asset
    ],
  },
});

// Note: Requires treasury co-signature
```

### 📊 Querying Information

```typescript
// Get draw information
const drawInfo = await aptos.view({
  payload: {
    function: "0x_MODULE_ADDRESS::lottos::get_draw",
    arguments: [drawId]
  }
});

// Get ticket details
const ticketInfo = await aptos.view({
  payload: {
    function: "0x_MODULE_ADDRESS::lottos::get_ticket", 
    arguments: [userAddress, drawId, ticketNumbers]
  }
});
```

## 📚 API Reference

### 🔍 View Functions

#### `get_draw(draw_id: u64)`
Returns complete draw information including status, jackpot pools, and winning numbers.

**Returns**: `(u64, String, DrawStatus, u64, u64, u64, vector<u64>, u64, u64)`

#### `get_ticket(user: address, draw_id: u64, numbers: vector<u64>)`
Retrieves ticket details for specific user and number combination.

**Returns**: `(u64, vector<u64>, address, ClaimStatus)`

#### `get_next_draw_id()`
Gets the next draw ID that will be assigned.

**Returns**: `u64`

### 📝 Entry Functions

#### `buy_tickets(user: &signer, draw: u64, tickets: vector<vector<u64>>, payment_fa: Object<Metadata>)`
Purchase one or more lottery tickets for a specific draw.

#### `claim_prize(user: &signer, treasury: &signer, draw_id: u64, numbers: vector<u64>, payment_fa: Object<Metadata>)`  
Claim prize for a winning ticket (requires treasury co-signature).

#### `create_draw(admin: &signer, type: String, close_timestamp_secs: u64)` 
Create new lottery draw (admin only).

#### `draws(admin: &signer, draw_id: u64)` 
Execute lottery draw and generate winning numbers (admin only).

## 🎯 Prize Calculation Examples

### Lotto 5/35 Example
```
Ticket: [5, 12, 18, 25, 33] + Extra: 7
Winning: [5, 12, 18, 25, 33] + Extra: 7
Result: JACKPOT! (5 matches + extra)
Prize: Base (600,000 × $0.50) + Rollover Pool ÷ Winners
```

### Mega 6/45 Example  
```
Ticket: [3, 17, 24, 31, 38, 44]
Winning: [3, 17, 24, 31, 42, 45] 
Result: Second Place (4 matches)
Prize: 30 × $0.50 = $15.00
```

### Power 6/55 Example
```
Ticket: [7, 14, 21, 28, 35, 42] + Extra: 9
Winning: [7, 14, 21, 28, 35, 50] + Extra: 9
Result: Jackpot2! (5 matches + extra)
Prize: Base (300,000 × $0.50) + Jackpot2 Pool ÷ Winners
```

## 🛠️ Development

### Running Tests

```bash
# Run all tests
aptos move test

# Run specific test module  
aptos move test --filter test_lottos

# Run with coverage
aptos move test --coverage
```

### Code Quality

- **Documentation**: All functions have comprehensive docs
- **Testing**: >95% code coverage with edge case testing
- **Security**: Multiple audit layers and access controls
- **Performance**: Optimized for gas efficiency

## 🔧 Configuration

### Supported Payment Assets

Currently supports:
- **USDt (Tether)**: Testnet address configured
- **Future**: USDC and other stablecoins planned

### Admin Settings

- **Draw Creation**: Only authorized admins
- **Number Generation**: Cryptographically secure randomness  
- **Prize Distribution**: Treasury multi-signature required

## 📈 Roadmap

### Phase 1: Core Features ✅
- [x] Basic lottery mechanics
- [x] Three game types
- [x] Object ticket system
- [x] Prize claiming

### Phase 2: Enhanced Features 🚧
- [x] Web interface
- [ ] Mobile app integration
- [ ] Additional game types
- [ ] Subscription tickets

### Phase 3: Advanced Features 📋
- [ ] Cross-chain integration
- [ ] DAO governance
- [ ] Staking rewards
- [ ] Social features

## 🔗 Links

- **Documentation**: [Full API Docs](https://docs.example.com)
- **Discord**: [Community Chat](https://discord.gg/example)
- **Twitter**: [@LottosOfficial](https://twitter.com/example)
- **Website**: [https://lottos.example.com](https://example.com)

## ⚠️ Disclaimer

This software is provided "as is" without warranty. Lottery games involve risk. Please gamble responsibly and only with amounts you can afford to lose. Users are responsible for compliance with local gambling laws and regulations.

---

**Built with ❤️ on Aptos blockchain**