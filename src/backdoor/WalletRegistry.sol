// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Safe } from "safe-contracts/contracts/Safe.sol";
import "safe-contracts/contracts/proxies/IProxyCreationCallback.sol";

contract WalletRegistry is IProxyCreationCallback, Ownable {
    uint256 private constant EXPECTED_OWNERS_COUNT = 1;
    uint256 private constant EXPECTED_THRESHOLD = 1;
    uint256 private constant PAYMENT_AMOUNT = 10 ether;

    address public immutable masterCopy;
    address public immutable walletFactory;
    IERC20 public immutable token;

    mapping(address => bool) public beneficiaries;

    // owner (Alice, Bob, Charlie, David) => wallet
    mapping(address => address) public wallets;

    error NotEnoughFunds();
    error CallerNotFactory();
    error FakeMasterCopy();
    error InvalidInitialization();
    error InvalidThreshold(uint256 threshold);
    error InvalidOwnersCount(uint256 count);
    error OwnerIsNotABeneficiary();
    error InvalidFallbackManager(address fallbackManager);

    constructor(address masterCopyAddress, address walletFactoryAddress, address tokenAddress, address[] memory initialBeneficiaries) {
        _initializeOwner(msg.sender);

        masterCopy = masterCopyAddress;
        walletFactory = walletFactoryAddress;
        token = IERC20(tokenAddress);
        // sets internal accounting for users to true in the mapping
        for (uint256 i = 0; i < initialBeneficiaries.length;) {
            unchecked {
                beneficiaries[initialBeneficiaries[i]] = true;
                ++i;
            }
        }
    }

    function addBeneficiary(address beneficiary) external onlyOwner {
        beneficiaries[beneficiary] = true;
    }

    // Function executed when user creates a Gnosis Safe wallet via `SafeProxyFactory::createProxyWithCallback`
    // sets the registry's address as the callback.
    function proxyCreated(SafeProxy proxy, address singleton, bytes calldata initializer, uint256) external override {
        if (token.balanceOf(address(this)) < PAYMENT_AMOUNT) { // fail early
            revert NotEnoughFunds();
        }

        address payable walletAddress = payable(proxy);

        // Ensure correct factory and master copy
        if (msg.sender != walletFactory) {
            revert CallerNotFactory();
        }
        
        // Ensure the masterCopy (Gnosis Safe) aka Safe, is not a fake.
        if (singleton != masterCopy) {
            revert FakeMasterCopy();
        }

        // Ensure initial calldata was a call to `Safe::setup`
        //@audit oopsie ;) 😘
        if (bytes4(initializer[:4]) != Safe.setup.selector) {
            revert InvalidInitialization();
        }

        // Ensure wallet initialization is the expected
        uint256 threshold = Safe(walletAddress).getThreshold();
        if (threshold != EXPECTED_THRESHOLD) {
            revert InvalidThreshold(threshold);
        }

        address[] memory owners = Safe(walletAddress).getOwners();
        if (owners.length != EXPECTED_OWNERS_COUNT) {
            revert InvalidOwnersCount(owners.length);
        }

        // Ensure the owner is a registered beneficiary
        address walletOwner;
        unchecked {
            walletOwner = owners[0];
        }
        if (!beneficiaries[walletOwner]) {
            revert OwnerIsNotABeneficiary();
        }

        address fallbackManager = _getFallbackManager(walletAddress);
        if (fallbackManager != address(0))
            revert InvalidFallbackManager(fallbackManager);

        // Remove owner as beneficiary
        beneficiaries[walletOwner] = false;

        // Register the wallet under the owner's address
        wallets[walletOwner] = walletAddress;

        // Pay tokens to the newly created wallet
        SafeTransferLib.safeTransfer(address(token), walletAddress, PAYMENT_AMOUNT);
    }

    // Retrieves the data from the fallback manager storage slot for SafeProxy's wallet address
    function _getFallbackManager(address payable wallet) private view returns (address) {
        return abi.decode(Safe(wallet).getStorageAt(uint256(keccak256("fallback_manager.handler.address")), 0x20), (address));
    }
}