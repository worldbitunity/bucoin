pragma solidity ^0.4.11;

import "./ERC20.sol";

contract StandardToken is ERC20 {
    string public name;
    string public symbol;
    uint256 public decimals;

    function isToken() public constant returns (bool) {
        return true;
    }
}
