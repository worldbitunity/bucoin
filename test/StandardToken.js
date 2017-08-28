'use strict';

var StandardTokenMock = artifacts.require('./helpers/StandardTokenMock.sol');

contract('StandardToken', function(accounts) {

    it('should return the correct totalSupply after construction', function() {
        return StandardTokenMock.new(accounts[0], 100).then(function (token) {
            return token.totalSupply();
        }).then(function (totalSupply) {
                assert.equal(totalSupply, 100);
        });
    });

    it('should return the correct allowance amount after approval', function() {
        var standerdToken;
        return StandardTokenMock.new(accounts[0], 100).then(function (token) {
            standerdToken = token;
            standerdToken.approve(accounts[1], 100);
        }).then(function () {
            return standerdToken.allowance(accounts[0], accounts[1]);
        }).then(function (allowance) {
            assert.equal(allowance.toNumber(), 100);
        });
    });

    it('should return correct balances after transfer', function() {
        var standerdToken;
        return StandardTokenMock.new(accounts[0], 100).then(function (token) {
            standerdToken = token;
            standerdToken.transfer(accounts[1], 50);
        }).then(function () {
            return standerdToken.balanceOf(accounts[0]);
        }).then(function (balance0) {
            assert.equal(balance0, 50);
            return standerdToken.balanceOf(accounts[1]);
        }).then(function (balance1) {
            assert.equal(balance1, 50);
        });
    });

    it('should return correct balances after transfering from another account', function() {
        var standerdToken;
        return StandardTokenMock.new(accounts[0], 100).then(function (token) {
            standerdToken = token;
            standerdToken.approve(accounts[1], 100);
        }).then(function () {
            standerdToken.transferFrom(accounts[0], accounts[2], 50, {from: accounts[1]});
        }).then(function () {
            return standerdToken.balanceOf(accounts[0]);
        }).then(function (balance0) {
            assert.equal(balance0, 50);
            return standerdToken.balanceOf(accounts[2]);
        }).then(function (balance1) {
            assert.equal(balance1, 50);
            return standerdToken.balanceOf(accounts[1]);
        }).then(function (balance2) {
            assert.equal(balance2, 0);
        });
    });

});