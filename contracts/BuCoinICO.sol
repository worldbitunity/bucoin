pragma solidity ^0.4.11;

import "./crowdsale/Crowdsale.sol";

contract BuCoinICO is Crowdsale {

    uint256 constant MAX_WEIs = 19180 * (10**18);
    uint256 constant MAX_TOKENS = 178500000 * (10**18);

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
