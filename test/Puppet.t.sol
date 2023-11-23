/*
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Attacker } from "../src/puppet/Attacker.sol";
import { Utilities } from "./Utilities.sol";
import { SigUtils } from "./SigUtils.sol";
import { DamnValuableToken } from "../src/DamnValuableToken.sol";
import { PuppetPool } from "../src/puppet/PuppetPool.sol";

interface UniswapV1Exchange {
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline) external payable returns (uint256);
    function balanceOf(address _owner) external view returns (uint256);
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);
    function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline) external returns (uint256);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256);
}

interface UniswapV1Factory {
    function initializeFactory(address template) external;
    function createExchange(address token) external returns (address);
}

contract PuppetTest is Test {
    Utilities util = new Utilities();
    SigUtils sigUtil;
    address deployer = makeAddr('deployer');
    address player;
    uint256 playerSk;
    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
    uint256 constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;

    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 25e18;

    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;

    DamnValuableToken token;
    UniswapV1Exchange internal uniswapV1ExchangeTemplate;
    UniswapV1Exchange internal uniswapExchange;
    UniswapV1Factory internal uniswapV1Factory;

    PuppetPool lendingPool;

    function setUp() public{
        (player, playerSk) = makeAddrAndKey('player');
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        
        token = new DamnValuableToken();
        sigUtil = new SigUtils(token.DOMAIN_SEPARATOR());

        uniswapV1Factory = UniswapV1Factory(deployCode("./build-uniswap-v1/UniswapV1Factory.json"));
        uniswapV1ExchangeTemplate = UniswapV1Exchange(deployCode("./build-uniswap-v1/UniswapV1Exchange.json"));

        uniswapV1Factory.initializeFactory(address(uniswapV1ExchangeTemplate));
        
        uniswapExchange = UniswapV1Exchange(uniswapV1Factory.createExchange(address(token)));

        lendingPool = new PuppetPool(address(token), address(uniswapExchange));

        token.approve(address(uniswapExchange), UNISWAP_INITIAL_TOKEN_RESERVE);

        uniswapExchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(0, UNISWAP_INITIAL_TOKEN_RESERVE, block.timestamp*2);

        assertEq(
            uniswapExchange.getTokenToEthInputPrice(1e18), 
            calculateTokenToEthInputPrice(1e18, UNISWAP_INITIAL_TOKEN_RESERVE, UNISWAP_INITIAL_ETH_RESERVE)
            );

        token.transfer(address(player), PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

        assertEq(lendingPool.calculateDepositRequired(1e18), 2e18);
        assertEq(lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE), 2*POOL_INITIAL_TOKEN_BALANCE);
    }

    function testExploit() public {

        // This setup can be done more gracefully with Foundry's `sign`?
        address attackerContract = computeCreateAddress(address(player), 0);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: address(player),
            spender: address(attackerContract),
            value: type(uint256).max,
            nonce: 0,
            deadline: type(uint256).max
        });

        bytes32 digest = sigUtil.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerSk, digest);

        vm.startPrank(player);

        new Attacker{value: PLAYER_INITIAL_ETH_BALANCE}
        (v, r, s, PLAYER_INITIAL_TOKEN_BALANCE, POOL_INITIAL_TOKEN_BALANCE, address(lendingPool), address(uniswapExchange), address(token));

        vm.stopPrank();
        validation();
    }

    function validation() public {
        // Must attack in 1 transaction (Deployment of attack contract is 1 tx, signing is not a tx!)
        assertEq(vm.getNonce(player), 1); 
        assertEq(token.balanceOf(address(lendingPool)), 0);
        assertGt(token.balanceOf(address(player)), POOL_INITIAL_TOKEN_BALANCE);
    }
    
    // Calculates how much ETH (in wei) Uniswap will pay for the given amount of tokens
    function calculateTokenToEthInputPrice(uint256 input_amount, uint256 input_reserve, uint256 output_reserve) pure internal returns (uint256) {
        uint256 input_amount_with_fee = input_amount * 997;
        uint256 numerator = input_amount_with_fee * output_reserve;
        uint256 denominator = (input_reserve * 1000) + input_amount_with_fee;
        return numerator / denominator;
    }
}
*/