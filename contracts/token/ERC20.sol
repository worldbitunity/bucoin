pragma solidity ^0.4.11;

import '../math/SafeMath.sol';

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
