// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "./Utilities.sol";
import "forge-std/Test.sol";

import { RegistryAttack } from "../src/backdoor/RegistryAttack.sol";
import { DamnValuableToken } from "../src/DamnValuableToken.sol";
import { WalletRegistry } from "../src/backdoor/WalletRegistry.sol";
import { Safe } from "safe-contracts/contracts/Safe.sol";
import { SafeProxyFactory } from "safe-contracts/contracts/proxies/SafeProxyFactory.sol";

contract Backdoor is Test {
    uint256 internal constant AMOUNT_TOKENS_DISTRIBUTED = 40e18;
    uint256 internal constant NUM_USERS = 4;

    Utilities internal utils;
    DamnValuableToken internal dvt;
    Safe internal masterCopy;
    SafeProxyFactory internal walletFactory;
    WalletRegistry internal walletRegistry;
    address[] internal users;
    address payable internal attacker;
    address internal alice;
    address internal bob;
    address internal charlie;
    address internal david;

    function setUp() public {
        // put users into array and instantiate attacker.
        utils = new Utilities();
        users = utils.createUsers(NUM_USERS);
        alice = users[0];
        bob = users[1];
        charlie = users[2];
        david = users[3];
        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));

        // Deploy needed contracts
        masterCopy = new Safe();
        walletFactory = new SafeProxyFactory();
        dvt = new DamnValuableToken();
        walletRegistry = new WalletRegistry(address(masterCopy), address(walletFactory), address(dvt), users);

        // Sanity check that users are registered as beneficiaries in walletRegistry
        for (uint256 i = 0; i < NUM_USERS; i++) {
            assertTrue(walletRegistry.beneficiaries(users[i]));
        }

        // Transfer 40 DVT to be distributed by the registry
        dvt.transfer(address(walletRegistry), AMOUNT_TOKENS_DISTRIBUTED);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        vm.startPrank(attacker);
        console.log("Balance of attacker before attack", dvt.balanceOf(attacker) / 1e18);
        RegistryAttack registryAttack = new RegistryAttack(address(masterCopy), address(walletFactory), address(dvt), address(walletRegistry)); 
        registryAttack.attack(users);
        console.log("Balance of attacker after attack", dvt.balanceOf(attacker) / 1e18);
        vm.stopPrank();
        validation();
    }

    function validation() internal {
        for (uint256 i = 0; i < NUM_USERS; i++) {
            address wallet = walletRegistry.wallets(users[i]);

            if (wallet == address(0)) {
                emit log("User did not register a wallet");
                fail();
            }
            // There are no beneficiarys (A,B,C,D) in the registry's mapping anymore
            // Meaning all 4 of the users should have created a proxy (even though we did and not them).
            assertTrue(!walletRegistry.beneficiaries(users[i]));
        }

        assertEq(dvt.balanceOf(attacker), AMOUNT_TOKENS_DISTRIBUTED);
        console.log(unicode"\n🎉🥳 Congratulations, you beat the level!!! 🥳🎉");
    }
}