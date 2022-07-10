const Api = artifacts.require("Api");
const Hunter = artifacts.require("Hunter");

const toAmount = function (amount, decimals) {
  return amount.toString() + '0'.repeat(decimals)
}

module.exports = async function (deployer, network) {
  switch (network) {
    case 'Bsc':
      await deployer.deploy(Api);
      await deployer.deploy(Hunter);
      break;

    default:
      break;
  }
};
