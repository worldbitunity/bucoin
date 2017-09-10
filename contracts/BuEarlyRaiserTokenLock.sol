pragma solidity ^0.4.11;

import "./crowdsale/TokenLock.sol";

/**
 * @title BuEarlyRaiserTokenLock
 *
 * @dev early raiser lock contract
 *
 */
contract BuEarlyRaiserTokenLock is TokenLock {

    uint256 public constant FREEZE_PERIOD = 12*30*24*60*60;
    uint256 public constant TOKEN_MAX_HOLD = 100000000;

    function BuEarlyRaiserTokenLock(address _owner, address _token) TokenLock(_owner, FREEZE_PERIOD, _token, TOKEN_MAX_HOLD) {
    }
}
