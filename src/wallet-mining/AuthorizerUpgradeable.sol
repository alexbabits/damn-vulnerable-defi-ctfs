// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";


/**
 * @title AuthorizerUpgradeable
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract AuthorizerUpgradeable is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => mapping(address => uint256)) private wards;

    event Rely(address indexed usr, address aim);

    // NOTE: Had to add `admin` arg for init and pass it into __Ownable_init.
    // NOTE: Make sure when calling `init` from test, you also pass in `deployer` or `admin` or `owner`.
    function init(address admin, address[] memory _wards, address[] memory _aims) external initializer {
        __Ownable_init(admin); 
        __UUPSUpgradeable_init();

        for (uint256 i = 0; i < _wards.length;) {
            _rely(_wards[i], _aims[i]);
            unchecked {
                i++;
            }
        }
    }

    function _rely(address usr, address aim) private {
        wards[usr][aim] = 1;
        emit Rely(usr, aim);
    }

    function can(address usr, address aim) external view returns (bool) {
        return wards[usr][aim] == 1;
    }

    // NOTE: Had to change this to just calling super on base contract.
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable override {
        // Your custom logic here (if any)
        super.upgradeToAndCall(newImplementation, data);
    }

    function _authorizeUpgrade(address imp) internal override onlyOwner {}
}