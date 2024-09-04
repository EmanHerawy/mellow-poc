# M-Potential Division-by-Zero Vulnerability in `_processLpAmount(...)` Function

## Brief Overview

The `vault.sol` contract has a potential division-by-zero vulnerability in the `_processLpAmount(...)` function. This function calculates the `lpAmount` by multiplying the `depositValue` by the `totalSupply` and then dividing by `totalValue`. However, the function does not verify whether `totalValue` is zero before performing the division, potentially causing the transaction to revert unexpectedly without a meaningful error message.

## Vulnerability Details

Whenever the `deposit(...)` function is called, it invokes `_processLpAmount(...)` to compute the `lpAmount`, which represents the number of LP tokens to mint for the user. If the `totalSupply` is non-zero, `_processLpAmount(...)` calculates the `lpAmount` by multiplying the `depositValue` by `totalSupply` and dividing by `totalValue`.

However, `totalValue` may be zero under certain conditions, leading to a division-by-zero error. This is because `_processLpAmount(...)` does not check if `totalValue` is zero before performing the division.

### Scenarios where `totalValue` can be zero

1. **Debt Situation:** If `totalAmounts[i]` is zero due to debt, then `totalValue` will be zero.
2. **No TVL Modules:** If no TVL modules are added or all are removed, `totalAmounts[i]` will be zero, making `totalValue` zero.
3. If the result of the operation `FullMath.mulDivRoundingUp(totalAmounts[i], priceX96, Q96)` is zero, `totalValue` will also be zero.

### Code Analysis

The relevant code snippet is as follows:

```solidity
```solidity
 function deposit(
      ///
    )
    ///
    {
    ///
   (
            address[] memory tokens,
            uint256[] memory totalAmounts
        ) = underlyingTvl();    

        /// 
          uint256 totalValue = 0;
        actualAmounts = new uint256[](tokens.length);
        {
            IPriceOracle priceOracle = IPriceOracle(configurator.priceOracle());
            for (uint256 i = 0; i < tokens.length; i++) {
                uint256 priceX96 = priceOracle.priceX96(
                    address(this),
                    tokens[i]
                );
                totalValue += totalAmounts[i] == 0 // @audit it can be zero if totalAmounts[i] is zero, totalAmounts[i] is zero if no tvl modules or if balance is zero due to debt 
                    ? 0
                    : FullMath.mulDivRoundingUp(totalAmounts[i], priceX96, Q96);// @audit it can be zero if the result of this operation is zero 
                if (ratiosX96[i] == 0) continue;
                uint256 amount = FullMath.mulDiv(ratioX96, ratiosX96[i], Q96);
                IERC20(tokens[i]).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amount
                );
                actualAmounts[i] = amount;
                depositValue += FullMath.mulDiv(amount, priceX96, Q96);
            }
        }
        lpAmount = _processLpAmount(to, depositValue, totalValue, minLpAmount);
       ///

    }

    function _processLpAmount(
        ///
    ) private returns (uint256 lpAmount) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) {
           ///
        } else {
            lpAmount = FullMath.mulDiv(depositValue, totalSupply, totalValue); /// @audit if totalValue is zero, the transaction will be reverted and users will lose gas fees
            if (lpAmount < minLpAmount) revert InsufficientLpAmount();
            if (to == address(0)) revert AddressZero();
        }

       /// 
    }
       
```

## Impact Details

While no assets are lost directly, the transaction will revert, causing users to lose gas fees. Additionally, due to the dynamic nature of the vault's state, users cannot easily predict when `totalValue` will be zero, resulting in an unpredictable user experience.

## Recommendations

To mitigate this vulnerability, add a check to ensure `totalValue` is greater than zero before performing the division in `_processLpAmount(...)`. If `totalValue` is zero, provide a clear revert message, such as `TotalValueZero`, to indicate the reason for the failure.

## References

- [Vault.sol Line 352](https://github.com/mellow-finance/mellow-lrt/blob/1c885ad9a2964ca88ad3e59c3a7411fc0059aa34/src/Vault.sol#L352)
- [Vault.sol Line 329](https://github.com/mellow-finance/mellow-lrt/blob/1c885ad9a2964ca88ad3e59c3a7411fc0059aa34/src/Vault.sol#L329)

