pragma solidity ^0.4.11;

import "../math/SafeMath.sol";
import "./Haltable.sol";
import "./PricingStrategy.sol";
import "./TokenLock.sol";
import "../token/FreezableToken.sol";

/**
 * @dev Abstract base contract for token sales.
 *
 * Handle
 * - start and end dates
 * - accepting investments
 * - minimum funding goal and refund
 * - various statistics during the crowdfund
 * - different pricing strategies
 * - different investment policies (require server side customer id, allow only whitelisted addresses)
 *
 */
contract Crowdsale is Haltable {

    using SafeMath for uint256;

    // The token we are selling
    FreezableToken public token;

    // How we are going to price our offering
    PricingStrategy public pricingStrategy;

    // How we are offering our tokens
    TokenLock public tokenLock;

    /* if the funding goal is not reached, investors may withdraw their funds */
    uint256 public minimumWEIFundingGoal;

    /* the UNIX timestamp start date of the crowdsale */
    uint256 public startsAt;

    /* the UNIX timestamp end date of the crowdsale */
    uint256 public endsAt;

    /* the number of tokens already sold through this contract*/
    uint256 public tokensSold = 0;

    /* How many wei of funding we have raised */
    uint256 public weiRaised = 0;

    /* Calculate incoming funds from presale contracts and addresses */
    uint256 public presaleWeiRaised = 0;

    /* How many distinct addresses have invested */
    uint256 public investorCount = 0;

    /* How much wei we have returned back to the contract after a failed crowdfund. */
    uint256 public loadedRefund = 0;

    /* How much wei we have given back to investors.*/
    uint256 public weiRefunded = 0;

    /* Has this crowdsale been finalized */
    bool public finalized;

    /** How much ETH each address has invested to this crowdsale */
    mapping (address => uint256) public investedAmountOf;

    /** How much tokens this crowdsale has credited for each investor address */
    mapping (address => uint256) public tokenAmountOf;

    /** State machine
     *
     * - Preparing: All contract initialization calls and variables have not been set yet
     * - Prefunding: We have not passed start time yet
     * - Funding: Active crowdsale
     * - Success: Minimum funding goal reached
     * - Failure: Minimum funding goal not reached before ending time
     * - Finalized: The finalized has been called and succesfully executed
     * - Refunding: Refunds are loaded on the contract for reclaim.
     */
    enum State{PreFunding, Funding, Success, Failure, Finalized, Refunding}

    // A new investment was made
    event Invested(address investor, uint256 weiAmount, uint256 tokenAmount);

    // Refund was processed for a contributor
    event Refund(address investor, uint256 weiAmount);

    // Crowdsale end time has been changed
    event EndsAtChanged(uint256 newEndsAt);

    function Crowdsale(address _token, uint256 _start, uint256 _end, uint256 _minimumFundingGoal) {
        require(_token != 0x0);
        require(_start > 0);
        require(_end > 0);
        require(_start < _end);

        owner = msg.sender;
        token = FreezableToken(_token);
        startsAt = _start;
        endsAt = _end;
        minimumWEIFundingGoal = _minimumFundingGoal;
    }

    /**
     * Make an investment.
     *
     * Crowdsale must be running for one to invest.
     * We must have not pressed the emergency brake.
     *
     * @param receiver The Ethereum address who receives the tokens
     */
    function investInternal(address receiver) stopInEmergency private {
        require(receiver != 0x0);
        require(getState()==State.Funding);

        uint256 weiAmount = msg.value;

        // Account presale sales separately, so that they do not count against pricing tranches
        uint256 tokenAmount = pricingStrategy.calculateTokenAmount(weiAmount, msg.sender);
        require(tokenAmount > 0);

        if(investedAmountOf[receiver] == 0) {
            // A new investor
            investorCount++;
        }

        // Update investor
        investedAmountOf[receiver] = investedAmountOf[receiver].add(weiAmount);
        tokenAmountOf[receiver] = tokenAmountOf[receiver].add(tokenAmount);

        // Update totals
        weiRaised = weiRaised.add(weiAmount);
        tokensSold = tokensSold.add(tokenAmount);

        if(pricingStrategy.isPresalePurchase(receiver)) {
            presaleWeiRaised = presaleWeiRaised.add(weiAmount);
        }

        // Check that we did not bust the cap
        require(!isBreakingCap(weiAmount, tokenAmount, weiRaised, tokensSold));

        assignTokens(receiver, tokenAmount);

        // Pocket the money
        require(owner.send(weiAmount));

        // Tell us invest was success
        Invested(receiver, weiAmount, tokenAmount);
    }

    /**
     * Allow anonymous contributions to this crowdsale.
     */
    function invest(address addr) public payable {
        investInternal(addr);
    }

    /**
     * The basic entry point to participate the crowdsale process.
     *
     * Pay for funding, get invested tokens back in the sender address.
     */
    function buy() public payable {
        invest(msg.sender);
    }

    /**
     * Finalize a succcesful crowdsale.
     *
     * The owner can triggre a call the contract that provides post-crowdsale actions, like releasing the tokens.
     */
    function finalize() public inState(State.Success) onlyOwner stopInEmergency {
        // Already finalized
        require(!finalized);

        finalized = true;
        setPricingStrategyAndTokenLock(PricingStrategy(0x0), TokenLock(0x0));
    }

    /**
     * Allow crowdsale owner to close early or extend the crowdsale.
     *
     * This is useful e.g. for a manual soft cap implementation:
     * - after X amount is reached determine manual closing
     *
     * This may put the crowdsale to an invalid state,
     * but we trust owners know what they are doing.
     *
     */
    function setEndsAt(uint256 time) onlyOwner {
        require(now <= time);

        endsAt = time;
        EndsAtChanged(endsAt);
    }

    // @dev Get the current balance of tokens
    // @return uint256 How many tokens there are currently
    function getBalance() public constant returns (uint256) {
        return token.balanceOf(address(this));
    }

    // @div give back tokens to owner
    function withdrawTokens() public onlyOwner {
        token.transfer(owner, token.balanceOf(address(this)));
    }

    // Change PricingStrategy and TokenLock, must be pair
    // TokenLock can be null, meaning no lock, after token released, can be transfer anywhere or anytime
    function setPricingStrategyAndTokenLock(PricingStrategy _pricingStrategy, TokenLock _tokenLock) onlyOwner {
        if (address(tokenLock) != 0x0) {
            token.transfer(address(tokenLock), tokenLock.tokensAllocatedTotal());
            require(tokenLock.lock());
        }

        pricingStrategy = _pricingStrategy;
        tokenLock = _tokenLock;
    }

    /**
     * Allow load refunds back on the contract for the refunding.
     *
     * The team can transfer the funds back on the smart contract in the case the minimum goal was not reached..
     */
    function loadRefund() public payable inState(State.Failure) {
        require(msg.value > 0);
        loadedRefund = loadedRefund.add(msg.value);
    }

    /**
     * Investors can claim refund.
     */
    function refund() public inState(State.Refunding) {
        uint256 weiValue = investedAmountOf[msg.sender];
        require(weiValue > 0);

        investedAmountOf[msg.sender] = 0;
        weiRefunded = weiRefunded.add(weiValue);
        Refund(msg.sender, weiValue);

        require(msg.sender.send(weiValue));
    }

    /**
     * @return true if the crowdsale has raised enough money to be a successful.
     */
    function isMinimumGoalReached() public constant returns (bool reached) {
        return weiRaised >= minimumWEIFundingGoal;
    }

    /**
     * Crowdfund state machine management.
     *
     * We make it a function and do not assign the result to a variable, so there is no chance of the variable being stale.
     */
    function getState() public constant returns (State) {
        if(finalized) return State.Finalized;
        else if (block.timestamp < startsAt) return State.PreFunding;
        else if (block.timestamp <= endsAt && !isCrowdsaleFull()) return State.Funding;
        else if (isMinimumGoalReached()) return State.Success;
        else if (!isMinimumGoalReached() && weiRaised > 0 && loadedRefund >= weiRaised) return State.Refunding;
        else return State.Failure;
    }

    /** Interface marker. */
    function isCrowdsale() public constant returns (bool) {
        return true;
    }

    //
    // Modifiers
    //

    /** Modified allowing execution only if the crowdsale is currently running.  */
    modifier inState(State state) {
        require(getState() == state);
        _;
    }


    //
    // Abstract functions
    //

    /**
     * Check if the current invested breaks our cap rules.
     *
     *
     * The child contract must define their own cap setting rules.
     * We allow a lot of flexibility through different capping strategies (ETH, token count)
     * Called from invest().
     *
     * @param weiAmount The amount of wei the investor tries to invest in the current transaction
     * @param tokenAmount The amount of tokens we try to give to the investor in the current transaction
     * @param weiRaisedTotal What would be our total raised balance after this transaction
     * @param tokensSoldTotal What would be our total sold tokens count after this transaction
     *
     * @return true if taking this investment would break our cap rules
     */
    function isBreakingCap(uint256 weiAmount, uint256 tokenAmount, uint256 weiRaisedTotal, uint256 tokensSoldTotal) private constant returns (bool limitBroken);

    /**
     * Check if the current crowdsale is full and we can no longer sell any tokens.
     */
    function isCrowdsaleFull() public constant returns (bool);

    /**
     * Create new tokens or transfer issued tokens to the investor depending on the cap model.
     */
    function assignTokens(address receiver, uint256 tokenAmount) private;
}