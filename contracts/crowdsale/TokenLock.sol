pragma solidity ^0.4.11;

import "../token/FreezableToken.sol";
import "../ownership/Ownable.sol";
import "../math/SafeMath.sol";

/**
 * @dev Hold tokens for a group investor of investors until the unlock date.
 * @dev After the unlock date the investor can claim their tokens.
 *
 */
contract TokenLock is Ownable {
    using SafeMath for uint256;

    // @dev How many investors we have now
    uint256 public investorCount;

    // @dev How many tokens can this contact hold.
    uint256 public tokensMaxAllocatable;

    // @dev How many tokens investors have claimed so far
    uint256 public totalClaimed;

    // @dev How many tokens our internal book keeping tells us to have at the time of lock() when all investor data has been loaded
    uint256 public tokensAllocatedTotal;

    // @dev How much we have allocated to the investors invested
    mapping(address => uint256) public balances;

    // @dev How many tokens investors have claimed
    mapping(address => uint256) public claimed;

    // @dev When our claim freeze is over (UNIX timestamp)
    uint256 public freezeEndsAt;

    // @dev How long to freeze the token. (UNIX timestamp)
    uint256 public freezePeriod;

    // @dev When this was locked (UNIX timestamp)
    uint256 public lockedAt;

    FreezableToken public token;

    /** @dev What is our current state.
     *
     * Loading: Investor data is being loaded and contract not yet locked
     * Holding: Holding tokens for investors
     * Distributing: Freeze time is over, investors can claim their tokens
     */
    enum State{Unknown, Loading, Holding, Distributing}

    // @dev We allocated tokens for investor
    event Allocated(address investor, uint256 value);

    // @dev We distributed tokens to an investor
    event Distributed(address investors, uint256 count);

    event Locked();

    /**
     * @dev Create contract where lock up period is given days
     *
     * @param _owner Who can load investor data and lock
     * @param _freezePeriod UNIX timestamp how long the locks
     * @param _token Token contract address we are distributing
     * @param _tokensMaxAllocatable Total number of tokens this will hold - not including decimal multiplcation
     *
     */
    function TokenLock(address _owner, uint256 _freezePeriod, address _token, uint256 _tokensMaxAllocatable) {
        require(_owner != 0x0);
        require(_token != 0x0);
        require(_freezePeriod > 0);
        require(_tokensMaxAllocatable > 0);

        owner = _owner;
        token = FreezableToken(_token);
        freezePeriod = _freezePeriod;
        tokensMaxAllocatable = _tokensMaxAllocatable * (10**token.decimals());
    }

    // @dev Add investor
    function addInvestor(address investor, uint256 amount) public onlyOwner {
        require(lockedAt == 0); // Cannot add new investors after locked
        require(amount > 0); // No empty buys

        if(balances[investor] == 0) {
            investorCount++;
        }
        // allow set multi times investor
        balances[investor] = balances[investor].add(amount);
        tokensAllocatedTotal += amount;
        require(tokensAllocatedTotal <= tokensMaxAllocatable);

        Allocated(investor, amount);
    }

    // @dev Lock
    // @dev Checks are in place to prevent creating that is locked with incorrect token balances.
    function lock() onlyOwner returns (bool) {
        require(lockedAt == 0);
        require(tokensAllocatedTotal <= tokensMaxAllocatable);

        // Do not lock if the given tokens are not on this contract
        require(token.balanceOf(address(this)) >= tokensAllocatedTotal);

        lockedAt = now;
        freezeEndsAt = lockedAt + freezePeriod;

        if (token.balanceOf(address(this)) >= tokensAllocatedTotal) {
            token.transfer(owner, token.balanceOf(address(this)) - tokensAllocatedTotal );
        }
        Locked();

        return true;
    }

    // @dev In the case locking failed, then allow the owner to reclaim the tokens on the contract.
    function recoverFailedLock() onlyOwner {
        require(lockedAt == 0);

        // Transfer all tokens on this contract back to the owner
        token.transfer(owner, token.balanceOf(address(this)));
    }

    // @dev Get the current balance of tokens
    // @return uint256 How many tokens there are currently
    function getBalance() public constant returns (uint256) {
        return token.balanceOf(address(this));
    }

    // @dev Claim N bought tokens to the investor as the msg sender
    function claim() {
        require(lockedAt > 0);
        require(now >= freezeEndsAt);

        address investor = msg.sender;
        require(balances[investor] > 0);
        require(claimed[investor] == 0);

        uint256 amount = balances[investor];
        claimed[investor] = amount;
        totalClaimed += amount;

        token.transfer(investor, amount);
        Distributed(investor, amount);
    }

    // @dev Resolve the contract state
    function getState() public constant returns(State) {
        if(lockedAt == 0 || freezeEndsAt == 0 ) {
            return State.Loading;
        } else if(now > freezeEndsAt) {
            return State.Distributing;
        } else {
            return State.Holding;
        }
    }

}