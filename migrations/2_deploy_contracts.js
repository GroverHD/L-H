var PreICO = artifacts.require("./PreICO.sol");
var DLH = artifacts.require("./DLH.sol");
var unix = Math.round(+new Date()/1000);

var wallet = '0x627306090abab3a6e1400e9345bc60c78a8bef57';
var priceUSD = 13692121690100
var minimumInvest = 5000; // in cents


module.exports = function(deployer) {
    deployer.deploy(DLH).then(function () {
        return deployer.deploy(PreICO, wallet, DLH.address, priceUSD, minimumInvest);
    }).then(function () {
        return DLH.deployed();
    }).then(function (DLHInstance) {
        return DLHInstance.transferOwnership(PreICO.address);
    })
};