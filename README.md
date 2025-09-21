# LendingCredit

LendingCredit is an address reputation system smart contract for lending protocol creditworthiness assessment built on the Stacks blockchain using Clarity.

## Overview

This smart contract provides a comprehensive credit scoring and reputation system for decentralized lending protocols. It tracks borrower behavior, loan history, repayment patterns, and calculates creditworthiness scores to help lenders make informed decisions.

## Features

- **Credit Profile Management**: Create and maintain credit profiles for borrowers
- **Dynamic Credit Scoring**: Credit scores range from 300-850 with automatic adjustments based on behavior
- **Loan Tracking**: Complete loan lifecycle management including active loans, repayments, and defaults
- **Authorized Lender System**: Role-based access control for lending protocol integration
- **Reputation Metrics**: Track total borrowed, repaid amounts, loan counts, and default history
- **Score Adjustment Logging**: Transparent audit trail of all credit score changes
- **Debt Ratio Calculations**: Automatic calculation of debt-to-repayment ratios
- **Creditworthiness Assessment**: Built-in creditworthiness evaluation (score >= 600)

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity 2.0
- **Contract Version**: 1.0.0
- **Epoch**: 2.5
- **Default Credit Score**: 500
- **Credit Score Range**: 300-850
- **Creditworthiness Threshold**: 600

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Stacks smart contract development toolchain
- Node.js (v18+)
- npm or yarn

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd LendingCredit
```

2. Navigate to the contract directory:
```bash
cd LendingCredit_contract
```

3. Install dependencies:
```bash
npm install
```

4. Run tests:
```bash
npm test
```

## Usage Examples

### Creating a Credit Profile

Users can create their own credit profile:

```clarity
(contract-call? .LendingCredit create-credit-profile)
```

### Recording a Loan (Authorized Lenders Only)

```clarity
(contract-call? .LendingCredit record-loan
  'SP1ABCDEFGHIJKLMNOPQRSTUVWXYZ
  u1000000
  u1050)  ;; amount: 1,000,000 microSTX, due at block 1050
```

### Recording a Repayment

```clarity
(contract-call? .LendingCredit record-repayment
  'SP1ABCDEFGHIJKLMNOPQRSTUVWXYZ
  u1      ;; loan-id
  u500000 ;; repayment amount
)
```

### Checking Credit Score

```clarity
(contract-call? .LendingCredit get-credit-score 'SP1ABCDEFGHIJKLMNOPQRSTUVWXYZ)
```

### Checking Creditworthiness

```clarity
(contract-call? .LendingCredit is-creditworthy 'SP1ABCDEFGHIJKLMNOPQRSTUVWXYZ)
```

## Contract Functions Documentation

### Public Functions

#### `create-credit-profile()`
Creates a new credit profile for the transaction sender with default score of 500.

**Returns**: `(response bool uint)`

#### `record-loan(borrower, amount, due-date)`
Records a new loan for a borrower (authorized lenders only).

**Parameters**:
- `borrower` (principal): The borrower's address
- `amount` (uint): Loan amount in microSTX
- `due-date` (uint): Block height when loan is due

**Returns**: `(response uint uint)` - Loan ID on success

#### `record-repayment(borrower, loan-id, amount)`
Records a loan repayment (authorized lenders only).

**Parameters**:
- `borrower` (principal): The borrower's address
- `loan-id` (uint): The loan identifier
- `amount` (uint): Repayment amount

**Returns**: `(response bool uint)`

#### `record-default(borrower, loan-id)`
Records a loan default (authorized lenders only).

**Parameters**:
- `borrower` (principal): The borrower's address
- `loan-id` (uint): The loan identifier

**Returns**: `(response bool uint)`

### Admin Functions

#### `add-authorized-lender(lender)`
Adds a new authorized lender (contract owner only).

#### `remove-authorized-lender(lender)`
Removes an authorized lender (contract owner only).

#### `toggle-contract-status()`
Enables/disables the contract (contract owner only).

### Read-Only Functions

#### `get-credit-profile(user)`
Returns complete credit profile for a user.

#### `get-credit-score(user)`
Returns just the credit score for a user.

#### `get-loan-details(borrower, loan-id)`
Returns details of a specific loan.

#### `is-creditworthy(user)`
Returns true if user's credit score >= 600.

#### `get-debt-ratio(user)`
Returns debt-to-repayment ratio as percentage * 100.

#### `is-authorized-lender(lender)`
Checks if an address is an authorized lender.

#### `get-contract-stats()`
Returns overall contract statistics.

## Data Structures

### Credit Profile
```clarity
{
  credit-score: uint,      ;; 300-850 range
  total-borrowed: uint,    ;; Total amount borrowed
  total-repaid: uint,      ;; Total amount repaid
  loans-count: uint,       ;; Number of loans taken
  defaults-count: uint,    ;; Number of defaults
  last-updated: uint,      ;; Last update block height
  is-active: bool          ;; Profile status
}
```

### Loan History
```clarity
{
  amount: uint,           ;; Loan amount
  repaid-amount: uint,    ;; Amount repaid so far
  due-date: uint,         ;; Due block height
  status: string-ascii,   ;; "active", "repaid", "defaulted"
  created-at: uint        ;; Creation block height
}
```

## Credit Score Adjustments

- **Loan Repayment**: +10 points (when fully repaid)
- **Loan Default**: -50 points
- **Score Bounds**: Automatically constrained to 300-850 range

## Error Codes

- `ERR-NOT-AUTHORIZED (100)`: Unauthorized access
- `ERR-INVALID-SCORE (101)`: Invalid credit score
- `ERR-USER-NOT-FOUND (102)`: User profile not found
- `ERR-ALREADY-EXISTS (103)`: Profile already exists
- `ERR-INVALID-AMOUNT (104)`: Invalid amount or date

## Deployment Guide

### Local Development

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy contract:
```clarity
::deploy_contract contracts/LendingCredit.clar
```

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deploy --testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deploy --mainnet
```

## Testing

Run the test suite:

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:report

# Watch mode for development
npm run test:watch
```

## Security Considerations

### Access Control
- Only contract owner can add/remove authorized lenders
- Only authorized lenders can record loans, repayments, and defaults
- Users can only create their own credit profiles

### Data Integrity
- Credit scores are automatically bounded to valid range (300-850)
- Loan amounts and dates are validated
- Repayment amounts cannot exceed loan principal
- Defaults can only be recorded after due date

### Audit Trail
- All credit score adjustments are logged with timestamps
- Loan history is immutable once recorded
- Score adjustment reasons are stored for transparency

### Best Practices
- Always verify user permissions before state changes
- Validate all input parameters
- Use appropriate error codes for different failure cases
- Maintain data consistency across related maps

## Integration

This contract is designed to integrate with lending protocols by:

1. **Authorization**: Add your lending protocol as an authorized lender
2. **Profile Creation**: Users create profiles before borrowing
3. **Loan Recording**: Record loans when originated
4. **Repayment Tracking**: Update repayments as they occur
5. **Credit Assessment**: Use credit scores and ratios for lending decisions

## License

This project is licensed under the ISC License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Support

For questions or issues, please open an issue in the repository or contact the development team.