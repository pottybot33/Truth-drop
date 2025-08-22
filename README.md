# Truthdrop - Journalism NFT Fund

A decentralized platform for funding and verifying independent journalists through NFTs on the Stacks blockchain.

## Overview

Truthdrop enables credible journalism by creating a transparent funding mechanism where:
- Journalists register as NFT holders with verification stakes
- Authorized verifiers confirm journalist credibility  
- Community members back journalists through funding campaigns
- Reputation scores track journalist activity and credibility

## Core Features

### Journalist Registration
- Register as a journalist by minting an NFT (requires verification stake)
- Provide name and bio information
- Stake STX tokens to demonstrate commitment

### Verification System
- Contract owner can authorize verifiers
- Verifiers validate journalist credentials
- Only verified journalists can create funding campaigns

### Funding Campaigns
- Verified journalists create funding campaigns with targets and deadlines
- Community members back campaigns with STX
- Platform fees support ecosystem development
- Real-time progress tracking

### Reputation System
- Credibility scores based on activity and articles published
- Activity tracking with recency bonuses
- Transparent metrics for backers to evaluate journalists

## Contract Functions

### Public Functions

#### `register-journalist`
```clarity
(register-journalist (name (string-ascii 64)) (bio (string-ascii 256)))
```
Register as a journalist, mint NFT, and stake verification amount.

#### `verify-journalist`  
```clarity
(verify-journalist (journalist-id uint))
```
Verify a journalist (authorized verifiers only).

#### `create-funding-campaign`
```clarity
(create-funding-campaign (journalist-id uint) (title (string-ascii 128)) (description (string-ascii 512)) (target-amount uint) (duration-blocks uint))
```
Create a funding campaign (verified journalists only).

#### `back-campaign`
```clarity
(back-campaign (campaign-id uint) (amount uint))
```
Fund a campaign with STX tokens.

#### `update-journalist-activity`
```clarity
(update-journalist-activity (journalist-id uint) (articles-count uint))
```
Update activity metrics (journalist owners only).

### Read-Only Functions

#### `get-journalist`
Get journalist information by ID.

#### `get-campaign`
Get campaign details by ID.

#### `get-journalist-reputation`
Get comprehensive reputation metrics.

#### `get-campaign-progress`
Get campaign funding progress and remaining time.

## Usage Example

1. **Register as journalist:**
   ```clarity
   (contract-call? .Truthdrop register-journalist "Jane Doe" "Investigative reporter covering tech policy")
   ```

2. **Get verified:**
   Authorized verifier calls:
   ```clarity
   (contract-call? .Truthdrop verify-journalist u1)
   ```

3. **Create funding campaign:**
   ```clarity
   (contract-call? .Truthdrop create-funding-campaign u1 "Tech Policy Investigation" "Deep dive into AI regulation" u10000000 u1000)
   ```

4. **Back the campaign:**
   ```clarity
   (contract-call? .Truthdrop back-campaign u1 u500000)
   ```

## Platform Economics

- **Verification Stake:** Default 1 STX (1,000,000 microSTX)
- **Platform Fee:** Default 5% (500 basis points)
- **Reputation System:** 0-100 credibility score + activity bonuses

## Development

### Prerequisites
- Clarinet CLI
- Node.js (for testing)

### Testing
```bash
npm install
npm test
```

### Deployment
```bash
clarinet deploy --testnet
```

## Contract Architecture

The contract manages three main entities:
- **Journalists:** NFT holders with verification stakes and reputation
- **Campaigns:** Time-bounded funding goals created by verified journalists  
- **Backers:** Community members who fund campaigns

All STX transfers are handled securely with proper error handling and the platform takes a configurable fee to sustain operations.
