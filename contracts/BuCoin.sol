pragma solidity ^0.4.11;

import "./ownership/Claimable.sol";
import "./ownership/Contactable.sol";
import "./ownership/HasNoEther.sol";
import "./token/FreezableToken.sol";

/**
 * @title BuCoin
 * @dev The BuCoin contract is Claimable, and provides ERC20 standard token.
 */
contract BuCoin is Claimable, Contactable, HasNoEther, FreezableToken {
    // @dev Constructor initial token info
    function BuCoin(){
        uint256 _decimals = 18;
        uint256 _supply = 210000000*(10**_decimals);

        _totalSupply = _supply;
        balances[msg.sender] = _supply;
        name = "BuCoin";
        symbol = "BUC";
        decimals = _decimals;
        contactInformation = "BuCoin contact information";
    }
}
