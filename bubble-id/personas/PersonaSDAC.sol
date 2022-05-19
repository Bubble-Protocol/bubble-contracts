// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../bubble-fs/sdacs/SDAC.sol";

abstract contract PersonaSDAC is SDAC {

    /**
     * @dev Returns the hash (id) of the bubble server that is storing the bubble controlled by
     * this sdac.  Allows the caller to identify which bubble server is used.  SDAC developers
     * may opt not to provide this so clients should not rely on it being set.
     */
    function getVaultHash() public virtual returns (bytes32);

}

