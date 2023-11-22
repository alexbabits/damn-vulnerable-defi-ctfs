// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { DamnValuableToken } from "../src/DamnValuableToken.sol";
import { TrusterLenderPool } from "../src/truster/TrusterLenderPool.sol";
import { Attacker } from "../src/truster/Attacker.sol";

contract TrusterTest is Test {
    uint256 internal constant TOKENS_IN_POOL = 1_000_000e18;
    Attacker attacker;
    DamnValuableToken token;
    TrusterLenderPool pool;

    function setUp() public{
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);
        
        token.transfer(address(pool), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
    }

    function testExploit() public {
        attacker = new Attacker(address(pool), address(token));
        validation();
    }

    function validation() internal {
        assertEq(token.balanceOf(address(pool)), 0);
        assertEq(token.balanceOf(address(attacker)), TOKENS_IN_POOL);
        console.log("Balance of the attacker: ", token.balanceOf(address(attacker)) / 1e18);
        console.log("Balance of the pool: ", token.balanceOf(address(pool)) / 1e18);
        console.log(unicode"\n🎉🥳 Congratulations, you beat the level!!! 🥳🎉");
    }
}