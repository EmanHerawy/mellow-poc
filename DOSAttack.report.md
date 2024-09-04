# M-Deposit and Withdrawal Operations Reverting Due to Asset Debt in vault.sol

## Brief Overview

In the `vault.sol` contract, the `processWithdrawals(...)`, `deposit(...)`, and `emergencyWithdraw(...)` functions may revert unexpectedly if there is a debt in any of the underlying assets. This occurs because the `_calculateTvl(...)` function includes a check that compares `amounts[i]` with `negativeAmounts[i]`. If `amounts[i]` is less than `negativeAmounts[i]`, the transaction will revert with an `InvalidState` error.

## Vulnerability Details

The `processWithdrawals(...)`, `deposit(...)`, and `emergencyWithdraw(...)` functions internally call the `_calculateTvl(...)` function to compute the total value of each underlying asset across all TVL modules. However, if there is a debt associated with any of the underlying assets, the transaction will revert with an `InvalidState` error.

The root cause of this issue is the following conditional check in the `_calculateTvl(...)` function:

```solidity
if (amounts[i] < negativeAmounts[i]) revert InvalidState();
```

### How the Vulnerability Occurs

- **Debt in Underlying Assets:** When the `amounts[i]` (representing the available amount of an asset) is less than `negativeAmounts[i]` (representing the debt or negative balance), the `InvalidState` error is triggered, causing the transaction to revert.
- **Functions Affected:** Any call to `processWithdrawals(...)`, `deposit(...)`, or `emergencyWithdraw(...)` will fail under these conditions, resulting in unexpected reversion and operational disruption.
## Impact

Due to the dynamic nature of the TVL modules, it is possible for `amounts[i]` to become less than `negativeAmounts[i]` at any time. This scenario will cause all deposit, withdrawal, and emergency withdrawal operations to revert unexpectedly, effectively freezing these functions until the debt is resolved or the state is corrected.

## Recommendations

To prevent unexpected reversion and operational disruption, consider setting  `amounts[i]`=0 if it's less than `negativeAmounts[i]`

## References

- [Vault.sol Line 106](https://github.com/mellow-finance/mellow-lrt/blob/1c885ad9a2964ca88ad3e59c3a7411fc0059aa34/src/Vault.sol#L106)

