// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { YNXOrgRegistry } from "./YNXOrgRegistry.sol";

contract YNXSubjectRegistry {
    YNXOrgRegistry public immutable orgRegistry;

    mapping(address subject => string uri) public addressProfileURI;
    mapping(uint256 orgId => string uri) public orgProfileURI;

    event AddressProfileUpdated(address indexed subject, string uri);
    event OrgProfileUpdated(uint256 indexed orgId, string uri);

    error OrgNotFound();
    error OnlyOrgAdmin();

    constructor(YNXOrgRegistry orgRegistry_) {
        orgRegistry = orgRegistry_;
    }

    function setMyAddressProfileURI(string calldata uri) external {
        addressProfileURI[msg.sender] = uri;
        emit AddressProfileUpdated(msg.sender, uri);
    }

    function setOrgProfileURI(uint256 orgId, string calldata uri) external {
        (address admin,) = orgRegistry.orgs(orgId);
        if (admin == address(0)) revert OrgNotFound();
        if (msg.sender != admin) revert OnlyOrgAdmin();

        orgProfileURI[orgId] = uri;
        emit OrgProfileUpdated(orgId, uri);
    }
}

