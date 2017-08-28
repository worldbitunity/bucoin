'use strict';

var Ownable = artifacts.require('../contracts/ownership/Ownable.sol');

contract('Ownable', function(accounts) {
  it('should have a owner', function() {
    return Ownable.new().then(function (ownable) {
      assert.isTrue(ownable.owner() !== 0);
    });
  });

  it('transfer ownership to a new address', function() {
    var ownable;
    return Ownable.new().then(function (token) {
        ownable = token;
        ownable.transferOwnership(accounts[1]);
    }).then(function () {
        return ownable.owner();
    }).then(function (owner) {
        assert.isTrue(owner === accounts[1]);
    });
  });
});
