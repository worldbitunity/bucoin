pragma solidity ^0.4.11;

import "./crowdsale/PricingStrategy.sol";
import "./crowdsale/Crowdsale.sol";

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
