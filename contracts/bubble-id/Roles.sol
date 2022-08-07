// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// @dev see proxy-roles.txt
library Roles {

    uint constant ALL_ROLES = 2**256 - 1;
    uint constant ADMIN_ROLE = 1<<255;
    uint constant ALL_NON_ADMIN_ROLES = 2**255 - 1;

}