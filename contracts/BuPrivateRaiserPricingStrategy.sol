pragma solidity ^0.4.11;

import "./crowdsale/PricingStrategy.sol";

/**
 * @title BuPrivateRaiserPricingStrategy
 *
 * @dev private raiser pricing strategy
 *
 */
contract BuPrivateRaiserPricingStrategy is PricingStrategy {
    // @dev token price, no matter wei to mini BUC, or ETH to BUC
    uint256 public constant TOKEN_PRICE = 9300;

    function BuPrivateRaiserPricingStrategy() {
        pricePerWei = TOKEN_PRICE;
    }
}
