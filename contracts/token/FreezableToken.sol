pragma solidity ^0.4.11;

import "./StandardToken.sol";
import "../ownership/Ownable.sol";

/**
 * @dev FreezableToken
 *
 */
contract FreezableToken is StandardToken, Ownable {
    mapping (address => bool) public frozenAccounts;
    event FrozenFunds(address target, bool frozen);

    // @dev freeze account or unfreezen.
    function freezeAccount(address target, bool freeze) onlyOwner {
        frozenAccounts[target] = freeze;
        FrozenFunds(target, freeze);
    }

    // @dev Limit token transfer if _sender is frozen.
    modifier canTransfer(address _sender) {
        require(!frozenAccounts[_sender]);

        _;
    }

    function transfer(address _to, uint256 _value) canTransfer(msg.sender) returns (bool success) {
        // Call StandardToken.transfer()
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) canTransfer(_from) returns (bool success) {
        // Call StandardToken.transferForm()
        return super.transferFrom(_from, _to, _value);
    }
}
