'use strict';

var Contactable = artifacts.require("./helper/ContactableMock.sol");

contract('Contactable', function(accounts) {

  it("contract able to set contact information", function () {
      var contactable;

      return Contactable.new().then(function (token) {
          contactable = token;
          return contactable.contactInformation();
      }).then(function (info) {
          assert.equal(info, "info1");
      }).then(function () {
          contactable.setContactInformation("info2");
      }).then(function () {
          return contactable.contactInformation();
      }).then(function (info) {
          assert.equal(info, "info2");
      });
  });
});
