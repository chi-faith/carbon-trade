# Carbon Credit NFT Smart Contract

A secure and efficient smart contract implementation for managing carbon credits as non-fungible tokens (NFTs) on the Stacks blockchain. This contract enables the minting, trading, and retirement of carbon credits while maintaining a transparent and verifiable record of their authenticity and ownership.

## Features

- **Carbon Credit Management**
  - Mint new carbon credits with metadata
  - Transfer credits between users
  - Retire credits from circulation
  - Track credit expiration dates

- **Auction System**
  - List credits for auction
  - Place bids on listed credits
  - Finalize auctions with automatic transfers
  - Cancel auctions with no bids

- **Verification System**
  - Verify credit authenticity
  - Check credit metadata
  - Track ownership history
  - Monitor expiration status

## Technical Specifications

### Data Structures

- **Non-Fungible Token (NFT)**
  - Token type: `carbon-credit`
  - Identifier type: `uint`

- **Mappings**
  ```clarity
  balances: principal → uint
  expiration-dates: uint → uint
  auctions: uint → { seller, min-bid, highest-bid, highest-bidder }
  credit-metadata: uint → { issuer, project-id, vintage-year }
  ```

### Constants

```clarity
MAX_BATCH_SIZE: u50
CONTRACT_OWNER: tx-sender
```

### Error Codes

- `ERR_UNAUTHORIZED (u100)`: Unauthorized operation attempt
- `ERR_INSUFFICIENT_BALANCE (u101)`: Insufficient balance for operation
- `ERR_INVALID_TOKEN (u102)`: Invalid or non-existent token
- `ERR_EXPIRED_TOKEN (u103)`: Token has expired
- `ERR_AUCTION_NOT_FOUND (u104)`: Auction not found
- `ERR_INVALID_BID (u105)`: Invalid bid amount or bidder
- `ERR_AUCTION_CLOSED (u106)`: Auction is closed
- `ERR_INVALID_INPUT (u107)`: Invalid input parameters
- `ERR_INVALID_RECIPIENT (u108)`: Invalid recipient address

## Usage

### Minting Carbon Credits

```clarity
(mint-carbon-credit 
  recipient: principal
  amount: uint
  expiration: uint
  issuer: string-ascii
  project-id: string-ascii
  vintage-year: uint)
```

- Only contract owner can mint new credits
- Maximum batch size: 50 credits
- Expiration must be future block height
- Vintage year must be valid
- Strings limited to 50 characters

### Transferring Credits

```clarity
(transfer-carbon-credit
  sender: principal
  recipient: principal
  amount: uint)
```

- Sender must be tx-sender
- Credits must not be expired
- Sufficient balance required

### Auctioning Credits

**List for Auction:**
```clarity
(list-for-auction
  seller: principal
  token-id: uint
  min-bid: uint)
```

**Place Bid:**
```clarity
(bid-on-auction
  bidder: principal
  token-id: uint
  bid-amount: uint)
```

**Finalize Auction:**
```clarity
(finalize-auction token-id: uint)
```

### Verifying Credits

```clarity
(verify-credit token-id: uint)
```

Returns:
```clarity
{
  owner: principal,
  issuer: string-ascii,
  project-id: string-ascii,
  vintage-year: uint,
  expiration: uint,
  is-expired: bool,
  is-valid: bool
}
```

## Security Features

1. **Input Validation**
   - Principal address validation
   - String length and format checking
   - Numeric bounds checking
   - Balance overflow protection

2. **Access Control**
   - Contract owner privileges
   - Sender verification
   - Auction participant validation

3. **State Management**
   - Safe arithmetic operations
   - Proper error handling
   - Atomic transactions

## Testing

To run tests:
1. Install Clarinet
2. Navigate to the project directory
3. Run `clarinet test`

## Deployment

1. Configure network settings in `Clarinet.toml`
2. Update contract owner address
3. Deploy using Clarinet:
   ```bash
   clarinet deploy --network mainnet
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Submit pull request
