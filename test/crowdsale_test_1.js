
var Token = artifacts.require("ITL");
var Crowdsale = artifacts.require("PreICO");

var account = web3.eth.accounts[0]

contract('Crowdsale' , function () {
    it("should send coin correctly", function () {
        return Crowdsale.deployed().then(function (instance) {
            return instance.manualTransfer(account, );
        }).then(function (owner) {
            assert.equal(owner, account, "10000 wasn't in the first account");
        });
    });
});