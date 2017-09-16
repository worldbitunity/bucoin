pragma solidity ^0.4.11;

// @title SafeMath
// @dev Math operations with safety checks that throw on error
library SafeMath {
    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b > 0);
        uint256 c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control functions
 */
contract Ownable {
    address public owner;

    // @dev Constructor sets the original `owner` of the contract to the sender account.
    function Ownable() {
        owner = msg.sender;
    }

    // @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }


    // @dev Allows the current owner to transfer control of the contract to a newOwner.
    // @param newOwner The address to transfer ownership to.
    function transferOwnership(address newOwner) onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

}

/**
 * @title Contracts that should not own Ether
 * @dev This tries to block incoming ether to prevent accidental loss of Ether. Should Ether end up
 * in the contract, it will allow the owner to reclaim this ether.
 * @notice Ether can still be send to this contract by:
 * calling functions labeled `payable`
 * `selfdestruct(contract_address)`
 * mining directly to the contract address
*/
contract HasNoEther is Ownable {

    /**
    * @dev Constructor that rejects incoming Ether
    * @dev The `payable` flag is added so we can access `msg.value` without compiler warning. If we
    * leave out payable, then Solidity will allow inheriting contracts to implement a payable
    * constructor. By doing it this way we prevent a payable constructor from working. Alternatively
    * we could use assembly to access msg.value.
    */
    function HasNoEther() payable {
        require(msg.value == 0);
    }

    /**
     * @dev Disallows direct send by settings a default function without the `payable` flag.
     */
    function() external {
    }

    /**
     * @dev Transfer all Ether held by the contract to the owner.
     */
    function reclaimEther() external onlyOwner {
        assert(owner.send(this.balance));
    }
}


/**
 * @title Contactable token
 * @dev Allowing the owner to provide a string with their contact information.
 */
contract Contactable is Ownable{

    string public contactInformation;

    // @dev Allows the owner to set a string with their contact information.
    // @param info The contact information to attach to the contract.
    function setContactInformation(string info) onlyOwner{
        contactInformation = info;
    }
}


/**
 * @title Claimable
 * @dev the ownership of contract needs to be claimed.
 * This allows the new owner to accept the transfer.
 */
contract Claimable is Ownable {
    address public pendingOwner;

    // @dev Modifier throws if called by any account other than the pendingOwner.
    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner);
        _;
    }

    // @dev Allows the current owner to set the pendingOwner address.
    // @param newOwner The address to transfer ownership to.
    function transferOwnership(address newOwner) onlyOwner {
        pendingOwner = newOwner;
    }

    // @dev Allows the pendingOwner address to finalize the transfer.
    function claimOwnership() onlyPendingOwner {
        owner = pendingOwner;
        pendingOwner = 0x0;
    }
}

// @dev Abstract contract that allows an emergency stop mechanism.
contract Haltable is Ownable {
    bool public halted;

    modifier stopInEmergency {
        require(!halted);
        _;
    }

    modifier onlyInEmergency {
        require(halted);
        _;
    }

    // called by the owner on emergency, triggers stopped state
    function halt() external onlyOwner {
        halted = true;
    }

    // called by the owner on end of emergency, returns to normal state
    function unhalt() external onlyOwner onlyInEmergency {
        halted = false;
    }

}


// @dev Interface for defining crowdsale pricing.
contract PricingStrategy is Ownable, HasNoEther {
    using SafeMath for uint256;

    // @dev This contains all pre-sale addresses, and their prices (wei to mini tokens)
    mapping (address => uint256) public presales;

    // @dev How many mini tokens one wei cost for investor
    uint256 public pricePerWei;

    // @dev This is invoked once for every pre-sale address, set _pricePerWei
    //      to 0 to disable
    // @param _addr pre-sale investor address
    // @param _pricePerWei How many mini tokens one wei cost for pre-sale investor
    function setPreSaleAddress(address _addr, uint256 _pricePerWei) public onlyOwner {
        require(_addr != 0x0);
        require(_pricePerWei > 0);

        presales[_addr] = _pricePerWei;
    }

    // @dev Interface declaration.
    function isPricingStrategy() public constant returns (bool) {
        return true;
    }

    // @dev Pricing tells if this is a presale purchase or not.
    // @param purchaser Address of the purchaser
    // @return False by default, true if a presale purchaser
    function isPresalePurchase(address purchaser) public constant returns (bool) {
        require(purchaser != 0x0);

        if(presales[purchaser] > 0) {
            return true;
        }

        return false;
    }

    // When somebody tries to buy tokens for X eth, calculate how many tokens they get.
    // @param value - What is the value of the transaction send in as wei
    // @param msgSender - who is the investor of this transaction
    // @return Amount of tokens the investor receives
    function calculateTokenAmount(uint256 value, address msgSender) public constant returns (uint256 tokenAmount) {
        // This investor is coming through pre-sale
        if(presales[msgSender] > 0) {
            return value.mul(presales[msgSender]);
        }

        return value.mul(pricePerWei);
    }
}


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


/**
 * @title Standard ERC20 token
 * @dev Implementation of the ERC20Interface
 * @dev https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
    using SafeMath for uint256;

    // private
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    uint256 _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // @dev Get the total token supply
    function totalSupply() constant returns (uint256) {
        return _totalSupply;
    }

    // @dev Gets the balance of the specified address.
    // @param _owner The address to query the the balance of.
    // @return An uint256 representing the amount owned by the passed address.
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    // @dev transfer token for a specified address
    // @param _to The address to transfer to.
    // @param _value The amount to be transferred.
    function transfer(address _to, uint256 _value) returns (bool) {
        require(_to != 0x0 );
        require(_value > 0 );

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        Transfer(msg.sender, _to, _value);
        return true;
    }

    // @dev Transfer tokens from one address to another
    // @param _from address The address which you want to send tokens from
    // @param _to address The address which you want to transfer to
    // @param _value uint256 the amout of tokens to be transfered
    function transferFrom(address _from, address _to, uint256 _value) returns (bool) {
        require(_from != 0x0 );
        require(_to != 0x0 );
        require(_value > 0 );

        var _allowance = allowed[_from][msg.sender];

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);

        Transfer(_from, _to, _value);
        return true;
    }

    // @dev Aprove the passed address to spend the specified amount of tokens on behalf of msg.sender.
    // @param _spender The address which will spend the funds.
    // @param _value The amount of tokens to be spent.
    function approve(address _spender, uint256 _value) returns (bool) {
        require(_spender != 0x0 );
        // To change the approve amount you first have to reduce the addresses`
        // allowance to zero by calling `approve(_spender, 0)` if it is not
        // already 0 to mitigate the race condition described here:
        // https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;

        Approval(msg.sender, _spender, _value);
        return true;
    }

    // @dev Function to check the amount of tokens that an owner allowed to a spender.
    // @param _owner address The address which owns the funds.
    // @param _spender address The address which will spend the funds.
    // @return A uint256 specifing the amount of tokens still avaible for the spender.
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}

contract StandardToken is ERC20 {
    string public name;
    string public symbol;
    uint256 public decimals;

    function isToken() public constant returns (bool) {
        return true;
    }
}

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

/**
 * @title BuCoin
 * @dev The BuCoin contract is Claimable, and provides ERC20 standard token.
 */
contract BuCoin is Claimable, Contactable, HasNoEther, FreezableToken {
    // @dev Constructor initial token info
    function BuCoin(){
        uint256 _decimals = 18;
        uint256 _supply = 1000000000*(10**_decimals);

        _totalSupply = _supply;
        balances[msg.sender] = _supply;
        name = "BuCoin";
        symbol = "BUC";
        decimals = _decimals;
        contactInformation = "BuCoin contact information";
    }
}

contract BuCoinICO is Crowdsale {

    uint256 constant MAX_WEIs = 105000 * (10**18);
    uint256 constant MAX_TOKENS = 610000000 * (10**18);

    function BuCoinICO(address _token, uint256 _end, uint256 _minimumFundingGoal) Crowdsale(_token, now, _end, _minimumFundingGoal){
    }

    // Called from investInternal() to confirm if the current investment does not break our cap rule.
    function isBreakingCap(uint256 weiAmount, uint256 tokenAmount, uint256 weiRaisedTotal, uint256 tokensSoldTotal) private constant returns (bool limitBroken) {
        if (weiAmount == 0) {
            return false;
        }

        if (tokenAmount == 0) {
            return false;
        }

        if (weiRaisedTotal > MAX_WEIs) {
            return true;
        }

        if (tokensSoldTotal > MAX_TOKENS ) {
            return true;
        }

        return false;
    }

    // Check if the current crowdsale is full and we can no longer sell any tokens.
    function isCrowdsaleFull() public constant returns (bool) {
        if (weiRaised >= MAX_WEIs ) {
            return true;
        }

        if (tokensSold >= MAX_TOKENS ) {
            return true;
        }

        return false;
    }

    // Create new tokens or transfer issued tokens to the investor depending on the cap model.
    function assignTokens(address receiver, uint256 tokenAmount) private {
        require(receiver != 0x0);

        if(address(tokenLock) != 0x0) {
            token.transfer(address(tokenLock), tokenAmount);
            tokenLock.addInvestor(receiver, tokenAmount);
            return;
        }

        token.transfer(receiver, tokenAmount);
    }
}

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

/**
 * @title BuICOPricingStrategy
 *
 * @dev ico pricing strategy
 *
 */
contract BuICOPricingStrategy is PricingStrategy {
    // @dev token price, no matter wei to mini BUC, or ETH to BUC
    uint256 public constant TOKEN_PRICE = 5000;

    function BuICOPricingStrategy() {
        pricePerWei = TOKEN_PRICE;
    }
}

/**
 * @title BuPreICOPricingStrategy
 *
 * @dev pre-ico pricing strategy
 *
 */
contract BuPreICOPricingStrategy is PricingStrategy {
    // @dev token price, no matter wei to mini BUC, or ETH to BUC
    uint256 public constant TOKEN_PRICE = 5500;

    function BuPreICOPricingStrategy() {
        pricePerWei = TOKEN_PRICE;
    }
}

/**
 * @title BuPrivateRaiserPricingStrategy
 *
 * @dev private raiser pricing strategy
 *
 */
contract BuPrivateRaiserPricingStrategy is PricingStrategy {
    // @dev token price, no matter wei to mini BUC, or ETH to BUC
    uint256 public constant TOKEN_PRICE = 20000;

    function BuPrivateRaiserPricingStrategy() {
        pricePerWei = TOKEN_PRICE;
    }
}

/**
 * @title BuPrivateRaiserTokenLock
 *
 * @dev private raiser lock contract
 *
 */
contract BuPrivateRaiserTokenLock is TokenLock {

    uint256 public constant FREEZE_PERIOD = 6*30*24*60*60;
    uint256 public constant TOKEN_MAX_HOLD = 100000000;

    function BuPrivateRaiserTokenLock(address _owner, address _token) TokenLock(_owner, FREEZE_PERIOD, _token, TOKEN_MAX_HOLD) {
    }
}

/**
 * @title BuTeamMemberTokenLock
 *
 * @dev Team member lock contract
 *
 */
contract BuTeamMemberTokenLock is TokenLock {

    uint256 public constant FREEZE_PERIOD = 3*30*24*60*60;
    uint256 public constant TOKEN_MAX_HOLD = 30000000;

    function BuTeamMemberTokenLock(address _owner, address _token) TokenLock(_owner, FREEZE_PERIOD, _token, TOKEN_MAX_HOLD) {
    }
}
