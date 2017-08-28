var BuCoin = artifacts.require("./BuCoin.sol");

module.exports = function(deployer) {
  deployer.deploy(BuCoin);
};
