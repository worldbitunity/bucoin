pragma solidity ^0.4.11;

import "./ownership/Claimable.sol";

/**
 * @title BuCoin
 * @dev The BuCoin contract is Claimable, and provides ERC20 standard token.
 */
contract BuCoin is Claimable {

    string public name;
    string public symbol;

    /**
     * @dev Constructor initial token info
     */
    function BuCoin(){
        uint256 _decimals = 18;
        uint256 _supply = 1000000000*(10**_decimals);

        balances[msg.sender] = _supply;
        totalSupply = _supply;
        decimals = _decimals;
        name = "BuCoin";
        symbol = "BUC";
        contactInformation = "BuCoin contact information";
    }
}
