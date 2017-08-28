'use strict';
var Claimable = artifacts.require('../contracts/ownership/Claimable.sol');

contract('Claimable', function(accounts) {

  it("transfer ownership to new address", function () {
      var newOwner = accounts[1];
      var claimable;

      return Claimable.new().then(function (token) {
          claimable = token;
          return claimable.owner();
      }).then(function (owner) {
          assert.isTrue(owner !== 0);
      }).then(function () {
        claimable.transferOwnership(newOwner);
      }).then(function () {
          return claimable.pendingOwner();
      }).then(function (pendingOwner) {
          assert.isTrue(pendingOwner === newOwner);
      }).then(function () {
          claimable.claimOwnership({from: newOwner});
      }).then(function () {
          return claimable.owner();
      }).then(function (owner) {
          assert.isTrue(owner === newOwner);
      });
  });
});
