pragma solidity ^0.4.11;

import "./crowdsale/TokenLock.sol";

/**
 * @title BuTeamMemberTokenLock
 *
 * @dev Team member lock contract
 *
 */
contract BuTeamMemberTokenLock is TokenLock {

    uint256 public constant FREEZE_PERIOD = 3*30*24*60*60;
    uint256 public constant TOKEN_MAX_HOLD = 10500000;

    function BuTeamMemberTokenLock(address _owner, address _token) TokenLock(_owner, FREEZE_PERIOD, _token, TOKEN_MAX_HOLD) {
    }
}
