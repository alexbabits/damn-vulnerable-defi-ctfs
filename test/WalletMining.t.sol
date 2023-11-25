// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Imports
import "forge-std/Test.sol";

contract WalletMiningTest is Test {

    // State variables

    function setUp() public {
        // Setup initial conditions
    }

    function testExploit() public {
        // solve here
        validation();
    }

    function validation() internal {
        // conditions for success here
        console.log(unicode"\n🎉🥳 Congratulations, you beat the level!!! 🥳🎉");
    }
}