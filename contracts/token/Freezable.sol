pragma solidity ^0.4.11;

import "../ownership/Ownable.sol";

contract Freezable is Ownable {

    struct Freeze {
        address account;
        uint afterTime;
    }

    mapping (address => Freeze) frozens;

    event FrozenFunds(address _target, uint _timestamp);
    event UnFreezeFunds(address _target);

    // @dev freeze account's token
    // @param _target Target account which will be frozen.
    // @param _timestamp UNIX timestamp to unlock Freeze.
    // @return bool
    function freezeAccount(address _target, uint _timestamp) onlyOwner returns (bool) {
        require(frozens[_target].afterTime == 0);

        frozens[_target] = Freeze(_target, _timestamp);
        FrozenFunds(_target, _timestamp);
        return true;
    }

    // @dev unfreeze account's token
    // @param _target Target account which will be unfrozen.
    // @return bool
    function unfreezeAccount(address _target) onlyOwner returns (bool) {
        require(frozens[_target].afterTime > 0);

        delete frozens[_target];
        UnFreezeFunds(_target);
        return true;
    }
}
