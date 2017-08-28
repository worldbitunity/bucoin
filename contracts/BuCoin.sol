pragma solidity ^0.4.11;

import "./ownership/Claimable.sol";
import "./ownership/Contactable.sol";
import "./token/StandardToken.sol";

/**
 * @title BuCoin
 * @dev The BuCoin contract is Claimable, and provides ERC20 standard token.
 */
contract BuCoin is Claimable, Contactable, StandardToken {
    string public name;
    string public symbol;
    uint256 public decimals;

    // @dev Constructor initial token info
    function BuCoin(){
        uint256 _decimals = 18;
        uint256 _supply = 1000000000*(10**_decimals);

        balances[msg.sender] = _supply;
        _totalSupply = _supply;
        name = "BuCoin";
        symbol = "BUC";
        decimals = _decimals;
        contactInformation = "BuCoin contact information";
    }
}
