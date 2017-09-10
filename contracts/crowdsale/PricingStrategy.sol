pragma solidity ^0.4.11;

import "../ownership/Ownable.sol";
import "../ownership/HasNoEther.sol";
import "../math/SafeMath.sol";
import "./Crowdsale.sol";

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