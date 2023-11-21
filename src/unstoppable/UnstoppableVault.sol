// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";
import { SafeTransferLib, ERC4626, ERC20 } from "solmate/mixins/ERC4626.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { IERC3156FlashBorrower, IERC3156FlashLender } from "@openzeppelin/contracts/interfaces/IERC3156.sol";

/**
 * @title UnstoppableVault
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract UnstoppableVault is IERC3156FlashLender, ReentrancyGuard, Owned, ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint256 public constant FEE_FACTOR = 0.05 ether;
    uint64 public constant GRACE_PERIOD = 30 days;

    uint64 public immutable end = uint64(block.timestamp) + GRACE_PERIOD;

    address public feeRecipient;

    error InvalidAmount(uint256 amount);
    error InvalidBalance();
    error CallbackFailed();
    error UnsupportedCurrency();

    event FeeRecipientUpdated(address indexed newFeeRecipient);

    constructor(ERC20 _token, address _owner, address _feeRecipient)
        ERC4626(_token, "Oh Damn Valuable Token", "oDVT")
        Owned(_owner)
    {
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    /**
     * @inheritdoc IERC3156FlashLender
     */
    function maxFlashLoan(address _token) public view returns (uint256) {
        if (address(asset) != _token)
            return 0;

        return totalAssets();
    }

    /**
     * @inheritdoc IERC3156FlashLender
     */
    function flashFee(address _token, uint256 _amount) public view returns (uint256 fee) {
        if (address(asset) != _token)
            revert UnsupportedCurrency();

        if (block.timestamp < end && _amount < maxFlashLoan(_token)) {
            return 0;
        } else {
            return _amount.mulWadUp(FEE_FACTOR);
        }
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient != address(this)) {
            feeRecipient = _feeRecipient;
            emit FeeRecipientUpdated(_feeRecipient);
        }
    }

    /**
     * @inheritdoc ERC4626
     */
    function totalAssets() public view override returns (uint256) {
        assembly { // Better safe than sorry
            // If data from storage position 0 is 2...
            if eq(sload(0), 2) {
                // store function selector (Reentrant()) at 0x00.
                mstore(0x00, 0xed3ba6a6)
                // revert tx and return 4 bytes of data at position 28.
                revert(0x1c, 0x04)
            }
        }
        return asset.balanceOf(address(this));
    }

    /**
     * @inheritdoc IERC3156FlashLender
     */
    function flashLoan( IERC3156FlashBorrower receiver, address _token, uint256 amount, bytes calldata data) external returns (bool) {

        // amount must be non-zero, and token must match vault asset.
        if (amount == 0) revert InvalidAmount(0);
        if (address(asset) != _token) revert UnsupportedCurrency(); // enforce ERC3156 requirement

        // Balance before should match total assets.
        uint256 balanceBefore = totalAssets();

        // If total supply doesn't match total assets, revert.
        if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance(); // enforce ERC4626 requirement

        // calculate flash fee amount.
        uint256 fee = flashFee(_token, amount);

        // transfers loan amount from vault to the borrower (receiver). Actual disbursement of the flash loan.
        ERC20(_token).safeTransfer(address(receiver), amount);

        // `onFlashLoan` is automatically called at this point as the callback, since the receiver now has the funds.

        // The receivers callback of `onFlashLoan` must return magic keccak value for safety, otherwise revert
        // Ensures that the borrower's contract correctly processes the loan according to the ERC3156 standard.
        if (receiver.onFlashLoan(msg.sender, address(asset), amount, fee, data) != keccak256("IERC3156FlashBorrower.onFlashLoan"))
            revert CallbackFailed();

        // After borrower used funds as intended, pull back the loan amount and fee from the borrower. Vault gets amount + fee back.
        ERC20(_token).safeTransferFrom(address(receiver), address(this), amount + fee);

        // Sends the fee to the fee recipient
        ERC20(_token).safeTransfer(feeRecipient, fee);

        // flashloan successful
        return true;
    }

    /**
     * @inheritdoc ERC4626
     */
    function beforeWithdraw(uint256 assets, uint256 shares) internal override nonReentrant {}

    /**
     * @inheritdoc ERC4626
     */
    function afterDeposit(uint256 assets, uint256 shares) internal override nonReentrant {}
}
