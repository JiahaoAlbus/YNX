// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract YNXOrgRegistry {
    struct Org {
        address admin;
        string metadataURI;
    }

    uint256 public orgCount;
    mapping(uint256 orgId => Org) public orgs;

    mapping(uint256 orgId => mapping(bytes32 role => mapping(address account => bool))) private _roles;

    event OrgCreated(uint256 indexed orgId, address indexed admin, string metadataURI);
    event OrgAdminTransferred(uint256 indexed orgId, address indexed oldAdmin, address indexed newAdmin);
    event OrgMetadataUpdated(uint256 indexed orgId, string metadataURI);
    event OrgRoleUpdated(uint256 indexed orgId, bytes32 indexed role, address indexed account, bool enabled);

    error OrgNotFound();
    error OnlyOrgAdmin();
    error InvalidAdmin();

    modifier onlyOrgAdmin(uint256 orgId) {
        address admin = orgs[orgId].admin;
        if (admin == address(0)) revert OrgNotFound();
        if (msg.sender != admin) revert OnlyOrgAdmin();
        _;
    }

    function createOrg(address admin, string calldata metadataURI) external returns (uint256 orgId) {
        if (admin == address(0)) revert InvalidAdmin();
        orgId = ++orgCount;
        orgs[orgId] = Org({ admin: admin, metadataURI: metadataURI });
        emit OrgCreated(orgId, admin, metadataURI);
    }

    function setOrgMetadataURI(uint256 orgId, string calldata metadataURI) external onlyOrgAdmin(orgId) {
        orgs[orgId].metadataURI = metadataURI;
        emit OrgMetadataUpdated(orgId, metadataURI);
    }

    function transferOrgAdmin(uint256 orgId, address newAdmin) external onlyOrgAdmin(orgId) {
        if (newAdmin == address(0)) revert InvalidAdmin();
        address oldAdmin = orgs[orgId].admin;
        orgs[orgId].admin = newAdmin;
        emit OrgAdminTransferred(orgId, oldAdmin, newAdmin);
    }

    function setRole(uint256 orgId, bytes32 role, address account, bool enabled) external onlyOrgAdmin(orgId) {
        _roles[orgId][role][account] = enabled;
        emit OrgRoleUpdated(orgId, role, account, enabled);
    }

    function hasRole(uint256 orgId, bytes32 role, address account) external view returns (bool) {
        return _roles[orgId][role][account];
    }
}

