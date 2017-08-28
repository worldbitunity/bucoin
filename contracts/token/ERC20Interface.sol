pragma solidity ^0.4.11;

// @title ERC20Interface
// @dev ERC Token Standard #20 Interface
// @dev https://github.com/ethereum/EIPs/issues/20
contract ERC20Interface {

    // @dev Get the total token supply
    function totalSupply() constant returns (uint256 totalSupply);

    // @dev Get the account balance of another account with address _owner
    // @param _owner The address of request account
    function balanceOf(address _owner) constant returns (uint256 balance);

    // @dev Send _value amount of tokens to address _to
    // @param _to The address to transfer to.
    // @param _value The amount to be transferred.
    function transfer(address _to, uint256 _value) returns (bool success);

    // @dev Send _value amount of tokens from address _from to address _to
    // @param _from The address which you want to send tokens from.
    // @param _to The address which you want to transfer to.
    // @param _value The amount to be transferred.
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);

    // @dev Allow _spender to withdraw from your account, multiple times, up to the _value amount.
    // @param _spender The address which will spend the funds.
    // @param _value The amount of tokens to be spent.
    function approve(address _spender, uint256 _value) returns (bool success);

    // @dev Returns the amount which _spender is still allowed to withdraw from _owner
    // @param _owner address The address which owns the funds.
    // @param _spender address The address which will spend the funds.
    // @return A uint256 specifing the amount of tokens still avaible for the spender.
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);

    // @dev Triggered when tokens are transferred.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    // @dev Triggered whenever approve(address _spender, uint256 _value) is called.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}