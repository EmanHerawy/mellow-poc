// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@mellow/tests/mainnet/Constants.sol";
import "./helper.sol";
import "@mellow/tests/mainnet/unit/VaultTestCommon.t.sol";
// import console
// import it indirectly via Test.sol
import "forge-std/Test.sol";
// or directly import it
import "forge-std/console2.sol";

contract DivisionByZero is Helper {
    function test_division_by_zero_when_last_module_is_removed() public {
        vaultDeployment(admin);
        tvlModuleDeployment(admin);
        addToken(admin);
        setupOracle(admin);
        _setupDepositPermissions(admin);
        address[] memory tvlModules = vault.tvlModules(); // we should have 3

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
            console2.log("amounts[0]", amounts[0] / 1 ether);
            console2.log("amounts[1]", amounts[1] / 1 ether);
            console2.log("amounts[2]", amounts[2] / 1 ether);
        }

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
        // depositor can deposit normally
        {
            (uint256[] memory actualAmounts, uint256 lpAmount) =
                dealDeposit(depositor, depositor, tokensToDeposit, amountsToDeposit, 100);
            console2.log("lpAmount", lpAmount);
        }
        for (uint256 i = 0; i < tvlModules.length; i++) {
            console2.log("tvlModules", tvlModules[i]);
            // remove module
            removeModuleAtIndex(admin, 0);
        }

        // let's remove module and see what will happen , it should revert
        {
            // vm.expectRevert();
            vm.startPrank(depositor);
            for (uint256 i = 0; i < tokensToDeposit.length; i++) {
                deal(tokensToDeposit[i], depositor, amountsToDeposit[i]);
                IERC20(tokensToDeposit[i]).approve(address(vault), amountsToDeposit[i]);
            }
            vm.expectRevert();
            (uint256[] memory actualAmounts, uint256 lpAmount) =
                vault.deposit(depositor, amountsToDeposit, 1, type(uint256).max, 0);
            vm.stopPrank();
            console2.log("lpAmount", lpAmount);
        } // lp token amount will increase
    }

    function test_division_by_zero_when_zero_balance_because_of_debt() public {
        vaultDeployment(admin);
        tvlModuleDeployment(admin);
        addToken(admin);
        setupOracle(admin);
        _setupDepositPermissions(admin);
        address[] memory tvlModules = vault.tvlModules(); // we should have 3

        /*  erc20TvlModule 0
        defaultBondTvlModule 1 
        managedTvlModule 2 
         */

        // setupBondModule(admin, tvlModules[1], 100 ether);
        setTVLPositive(admin, ManagedTvlModule(tvlModules[2]));
        // setupModuleEr20(operator);
        {
            (address[] memory tokens, uint256[] memory amounts) = vault.underlyingTvl();
            assertEq(tokens.length, 3);
            assertEq(amounts.length, 3);
            assertEq(tokens[0], Constants.WSTETH);
            assertEq(tokens[1], Constants.RETH);
            assertEq(tokens[2], Constants.WETH);
            console2.log("amounts[0]", amounts[0] / 1 ether);
            console2.log("amounts[1]", amounts[1] / 1 ether);
            console2.log("amounts[2]", amounts[2] / 1 ether);
        }

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
        // depositor can deposit normally
        {
            (uint256[] memory actualAmounts, uint256 lpAmount) =
                dealDeposit(depositor, depositor, tokensToDeposit, amountsToDeposit, 100);
            console2.log("lpAmount", lpAmount);
        }

        // let's assume we have debt that eats any profit
        {
            setZeroTVL(admin, ManagedTvlModule(tvlModules[2]));

            vm.startPrank(depositor);
            for (uint256 i = 0; i < tokensToDeposit.length; i++) {
                deal(tokensToDeposit[i], depositor, amountsToDeposit[i]);
                IERC20(tokensToDeposit[i]).approve(address(vault), amountsToDeposit[i]);
            }
            vm.expectRevert();
            (uint256[] memory actualAmounts, uint256 lpAmount) =
                vault.deposit(depositor, amountsToDeposit, 1, type(uint256).max, 0);
            vm.stopPrank();
            console2.log("lpAmount", lpAmount);
        } // lp token amount will increase
    }
}
