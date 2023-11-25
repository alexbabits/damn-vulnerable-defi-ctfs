// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "./Utilities.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {ClimberTimelock} from "../src/climber/ClimberTimelock.sol";
import {ClimberVault} from "../src/climber/ClimberVault.sol";
import {ADMIN_ROLE, PROPOSER_ROLE, MAX_TARGETS, MIN_TARGETS, MAX_DELAY} from "../src/climber/ClimberConstants.sol";

import "../src/climber/ClimberAttack.sol";

contract ClimberTest is Test {
    uint256 internal constant VAULT_TOKEN_BALANCE = 10_000_000e18;

    Utilities internal utils;
    DamnValuableToken internal dvt;
    ClimberTimelock internal climberTimelock;
    ClimberVault internal climberImplementation;
    ERC1967Proxy internal climberVaultProxy;
    address[] internal users;
    address payable internal deployer;
    address payable internal proposer;
    address payable internal sweeper;
    address payable internal attacker;

    function setUp() public {

        utils = new Utilities();
        users = utils.createUsers(3);

        deployer = payable(users[0]);
        proposer = payable(users[1]);
        sweeper = payable(users[2]);
        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.deal(attacker, 0.1 ether);

        vm.startPrank(deployer); 

        // Deploy the vault behind a proxy using the UUPS pattern.
        // `ClimberVault::initialize(address,address,address)`
        climberImplementation = new ClimberVault();
        bytes memory data = abi.encodeWithSignature("initialize(address,address,address)", deployer, proposer, sweeper);
        climberVaultProxy = new ERC1967Proxy(address(climberImplementation), data);

        vm.stopPrank();

        assertEq(ClimberVault(address(climberVaultProxy)).getSweeper(), sweeper);
        assertGt(ClimberVault(address(climberVaultProxy)).getLastWithdrawalTimestamp(), 0);

        climberTimelock = ClimberTimelock(payable(ClimberVault(address(climberVaultProxy)).owner()));

        assertTrue(climberTimelock.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(climberTimelock.hasRole(ADMIN_ROLE, deployer));

        // Deploy token and transfer the 10 million DVT to the vault proxy.
        dvt = new DamnValuableToken();
        dvt.transfer(address(climberVaultProxy), VAULT_TOKEN_BALANCE);
    }

    function testExploit() public {
        vm.startPrank(attacker);

        console.log("Balance of climberVaultProxy before the exploit:", dvt.balanceOf(address(climberVaultProxy)) / 1e18);
        console.log("Balance of attacker before exploit:", dvt.balanceOf(attacker) / 1e18);

        ClimberAttack climberAttack = new ClimberAttack(ClimberVault(address(climberVaultProxy)), IERC20(address(dvt)));
        climberAttack.exploit();

        console.log("Balance of attacker after exploit:", dvt.balanceOf(attacker) / 1e18);
        console.log("Balance of climberVaultProxy after the exploit:", dvt.balanceOf(address(climberVaultProxy)) / 1e18);

        vm.stopPrank();

        validation();
    }

    function validation() internal {
        assertEq(dvt.balanceOf(attacker), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(climberVaultProxy)), 0);
        console.log(unicode"\n🎉🥳 Congratulations, you beat the level!!! 🥳🎉");
    }
}