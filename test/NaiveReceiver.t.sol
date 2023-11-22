// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Utilities } from "./Utilities.sol";
import { FlashLoanReceiver } from "../src/naive-receiver/FlashLoanReceiver.sol";
import { NaiveReceiverLenderPool } from "../src/naive-receiver/NaiveReceiverLenderPool.sol";
import { Attacker } from "../src/naive-receiver/Attacker.sol";

contract NaiveReceiver is Test {

    uint256 internal constant ETHER_IN_POOL = 1_000e18;
    uint256 internal constant ETHER_IN_RECEIVER = 10e18;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    Utilities internal utils;
    NaiveReceiverLenderPool internal naiveReceiverLenderPool;
    FlashLoanReceiver internal flashLoanReceiver;

    function setUp() public {
        naiveReceiverLenderPool = new NaiveReceiverLenderPool();
        flashLoanReceiver = new FlashLoanReceiver(payable(naiveReceiverLenderPool));

        vm.deal(address(naiveReceiverLenderPool), ETHER_IN_POOL);
        vm.deal(address(flashLoanReceiver), ETHER_IN_RECEIVER);
        assertEq(address(naiveReceiverLenderPool).balance, ETHER_IN_POOL);
        assertEq(naiveReceiverLenderPool.flashFee(ETH, 0), 1e18);
        assertEq(address(flashLoanReceiver).balance, ETHER_IN_RECEIVER);
    }

    function testExploit() public {
        new Attacker(payable(naiveReceiverLenderPool), payable(flashLoanReceiver));
        validation();
    }

    function validation() internal {
        assertEq(address(flashLoanReceiver).balance, 0);
        assertEq(address(naiveReceiverLenderPool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
        console.log("Balance of FlashLoanReceiver.sol: ", address(flashLoanReceiver).balance);
        console.log("Balance of the pool: ", address(naiveReceiverLenderPool).balance / 1e18);
        console.log(unicode"\n🎉🥳 Congratulations, you beat the level!!! 🥳🎉");
    }
}