pragma solidity ^0.4.11;

import "./crowdsale/PricingStrategy.sol";

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
