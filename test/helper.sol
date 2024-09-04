// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@mellow/tests/mainnet/Constants.sol";
import "@mellow/tests/mainnet/unit/VaultTestCommon.t.sol";
// import console
// import it indirectly via Test.sol
import "forge-std/Test.sol";
// or directly import it
import "forge-std/console2.sol";

contract VaultTest is Vault {
    constructor(string memory name, string memory symbol, address admin) Vault(name, symbol, admin) {}

    function update(address from, address to, uint256 value) public {
        _update(from, to, value);
    }

    function mint(address account, uint256 value) public {
        _mint(account, value);
    }
}

contract Helper is VaultTestCommon {
    using SafeERC20 for IERC20;

    Vault public vault;
    address public user1 = address(bytes20(keccak256("user1")));
    address public user2 = address(bytes20(keccak256("user2")));

    function vaultDeployment(address _admin) internal {
        vm.startPrank(_admin);
        vault = new Vault("Mellow LRT Vault", "mLRT", _admin);
        vault.grantRole(vault.ADMIN_DELEGATE_ROLE(), admin);
        vault.grantRole(vault.OPERATOR(), operator);
        vm.stopPrank();
    }

    function tvlModuleDeployment(address _admin) internal {
        vm.startPrank(_admin);
        ERC20TvlModule erc20TvlModule = new ERC20TvlModule();
        DefaultBondTvlModule defaultBondTvlModule = new DefaultBondTvlModule();
        ManagedTvlModule managedTvlModule = new ManagedTvlModule();
        vault.addTvlModule(address(erc20TvlModule));
        vault.addTvlModule(address(defaultBondTvlModule));
        vault.addTvlModule(address(managedTvlModule));
        vm.stopPrank();
    }

    function addToken(address _admin) internal {
        vm.startPrank(_admin);
        vault.addToken(Constants.WSTETH);
        vault.addToken(Constants.RETH);
        vault.addToken(Constants.WETH);
        vm.stopPrank();
    }

    function setupOracle(address _admin) internal {
        vm.startPrank(_admin);
        VaultConfigurator configurator = VaultConfigurator(address(vault.configurator()));
        // oracles setup
        {
            ManagedRatiosOracle ratiosOracle = new ManagedRatiosOracle();

            uint128[] memory ratiosX96 = new uint128[](3);
            ratiosX96[0] = 2 ** 96;
            ratiosOracle.updateRatios(address(vault), true, ratiosX96);
            ratiosOracle.updateRatios(address(vault), false, ratiosX96);

            configurator.stageRatiosOracle(address(ratiosOracle));
            configurator.commitRatiosOracle();

            ChainlinkOracle chainlinkOracle = new ChainlinkOracle();
            chainlinkOracle.setBaseToken(address(vault), Constants.WSTETH);
            address[] memory tokens = new address[](3);
            tokens[0] = Constants.WSTETH;
            tokens[1] = Constants.RETH;
            tokens[2] = Constants.WETH;

            IChainlinkOracle.AggregatorData[] memory data = new IChainlinkOracle.AggregatorData[](3);
            data[0] = IChainlinkOracle.AggregatorData({
                aggregatorV3: address(new WStethRatiosAggregatorV3(Constants.WSTETH)),
                maxAge: 30 days
            });
            data[1] = IChainlinkOracle.AggregatorData({aggregatorV3: Constants.RETH_CHAINLINK_ORACLE, maxAge: 30 days});
            data[2] = IChainlinkOracle.AggregatorData({
                aggregatorV3: address(new ConstantAggregatorV3(1 ether)),
                maxAge: 30 days
            });
            chainlinkOracle.setChainlinkOracles(address(vault), tokens, data);

            configurator.stagePriceOracle(address(chainlinkOracle));
            configurator.commitPriceOracle();
        }

        configurator.stageMaximalTotalSupply(1000 ether);
        configurator.commitMaximalTotalSupply();
        vm.stopPrank();
    }

    function setupBondModule(address _admin, address moduleAddress, uint256 amount) internal {
        vm.startPrank(_admin);
        address[] memory bonds = new address[](1);
        bonds[0] = address(new DefaultBondMock(Constants.WSTETH));
        DefaultBondTvlModule defaultBondTvlModule = DefaultBondTvlModule(moduleAddress);
        defaultBondTvlModule.setParams(address(vault), bonds);
        deal(bonds[0], address(vault), amount);

        vm.stopPrank();
    }

    function setupModuleEr20(address _admin) internal {
        vm.startPrank(_admin);
        deal(Constants.WSTETH, address(vault), 1 ether);
        deal(Constants.RETH, address(vault), 10 ether);
        deal(Constants.WETH, address(vault), 100 ether);
        vm.stopPrank();
    }

    function _setupDepositPermissions(address _admin) internal {
        vm.startPrank(_admin);
        VaultConfigurator configurator = VaultConfigurator(address(vault.configurator()));
        uint8 depositRole = 14;
        IManagedValidator validator = IManagedValidator(configurator.validator());
        if (address(validator) == address(0)) {
            validator = new ManagedValidator(admin);
            configurator.stageValidator(address(validator));
            configurator.commitValidator();
        }
        validator.grantPublicRole(depositRole);
        validator.grantContractSignatureRole(address(vault), IVault.deposit.selector, depositRole);
    }

    function setTVLPositive(address _admin, ManagedTvlModule managedTvlModule) internal {
        vm.startPrank(_admin);
        ITvlModule.Data[] memory data = new ITvlModule.Data[](3);
        // 1001-10 = 991
        data[0] = ITvlModule.Data({
            token: Constants.WSTETH,
            underlyingToken: Constants.WSTETH,
            amount: 1 ether,
            underlyingAmount: 1 ether,
            isDebt: false
        });

        data[1] = ITvlModule.Data({
            token: Constants.RETH,
            underlyingToken: Constants.RETH,
            amount: 10 ether,
            underlyingAmount: 10 ether,
            isDebt: false
        });

        data[2] = ITvlModule.Data({
            token: Constants.WETH,
            underlyingToken: Constants.WETH,
            amount: 100 ether,
            underlyingAmount: 100 ether,
            isDebt: false
        });
        managedTvlModule.setParams(address(vault), data);

        vm.stopPrank();
    }

    function setZeroTVL(address _admin, ManagedTvlModule managedTvlModule) internal {
        vm.startPrank(_admin);
        ITvlModule.Data[] memory data = new ITvlModule.Data[](3);
        // 1001-10 = 991
        data[0] = ITvlModule.Data({
            token: Constants.WSTETH,
            underlyingToken: Constants.WSTETH,
            amount: 1 ether,
            underlyingAmount: 1 ether,
            isDebt: true
        });

        data[1] = ITvlModule.Data({
            token: Constants.RETH,
            underlyingToken: Constants.RETH,
            amount: 10 ether,
            underlyingAmount: 10 ether,
            isDebt: true
        });

        data[2] = ITvlModule.Data({
            token: Constants.WETH,
            underlyingToken: Constants.WETH,
            amount: 100 ether,
            underlyingAmount: 100 ether,
            isDebt: true
        });
        managedTvlModule.setParams(address(vault), data);
        deal(Constants.WSTETH, address(vault), 1 ether);
        deal(Constants.RETH, address(vault), 10 ether);
        deal(Constants.WETH, address(vault), 100 ether);
        vm.stopPrank();
    }

    function unlockDeposit(address _operator) internal {
        vm.startPrank(_operator);
        deal(Constants.WSTETH, _operator, 10 gwei);
        deal(Constants.RETH, _operator, 0 ether);
        deal(Constants.WETH, _operator, 0 ether);
        IERC20(Constants.WSTETH).safeIncreaseAllowance(address(vault), 10 gwei);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 10 gwei;
        vault.deposit(address(vault), amounts, 10 gwei, type(uint256).max, 0);

        assertEq(IERC20(Constants.WSTETH).balanceOf(address(vault)), 10 gwei);
        assertEq(IERC20(Constants.RETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(Constants.WETH).balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(address(vault)), 10 gwei);
        assertEq(vault.balanceOf(_operator), 0);

        vm.stopPrank();
    }

    function setTVLNegative(address _admin, ManagedTvlModule managedTvlModule) internal {
        vm.startPrank(_admin);
        ITvlModule.Data[] memory data = new ITvlModule.Data[](3);
        data[0] = ITvlModule.Data({
            token: Constants.WSTETH,
            underlyingToken: Constants.WSTETH,
            amount: 1001 ether,
            underlyingAmount: 1001 ether - 1 ether,
            isDebt: true
        });

        data[1] = ITvlModule.Data({
            token: Constants.RETH,
            underlyingToken: Constants.RETH,
            amount: 11 ether,
            underlyingAmount: 11 ether - 1 ether,
            isDebt: true
        });

        data[2] = ITvlModule.Data({
            token: Constants.WETH,
            underlyingToken: Constants.WETH,
            amount: 100 ether,
            underlyingAmount: 100 ether - 1 ether,
            isDebt: true
        });
        managedTvlModule.setParams(address(vault), data);
        vm.stopPrank();
    }

    function dealDeposit(
        address depositor,
        address to,
        address[] memory assets,
        uint256[] memory amounts,
        uint256 minAmount
    ) internal returns (uint256[] memory actualAmounts, uint256 lpAmount) {
        vm.startPrank(depositor);
        for (uint256 i = 0; i < assets.length; i++) {
            deal(assets[i], depositor, amounts[i]);
            IERC20(assets[i]).approve(address(vault), amounts[i]);
        }

        (actualAmounts, lpAmount) = vault.deposit(to, amounts, minAmount, type(uint256).max, 0);
        vm.stopPrank();
    }

    function registerWithdrawing(
        address depositor,
        uint256 amount,
        uint256[] memory minAmounts,
        uint256 deadline,
        uint256 requestDeadline,
        bool closePrevious
    ) internal {
        vm.startPrank(depositor);
        vault.registerWithdrawal(depositor, amount, minAmounts, deadline, requestDeadline, closePrevious);
        vm.stopPrank();
    }

    function processWithdrawals(address _operator, address depositor) internal {
        vm.startPrank(_operator);
        address[] memory users = new address[](1);
        users[0] = depositor;
        vault.processWithdrawals(users);
        {
            address[] memory withdrawers = vault.pendingWithdrawers();
            assertEq(withdrawers.length, 0);
        }
        vm.stopPrank();
    }

    function removeModuleAtIndex(address _admin, uint256 index) internal {
        vm.startPrank(_admin);
        address[] memory tvlModules = vault.tvlModules();
        vault.removeTvlModule(tvlModules[index]);
        vm.stopPrank();
    }
}
