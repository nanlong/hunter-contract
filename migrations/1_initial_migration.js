const Fetcher = artifacts.require("Fetcher");
const Hunter = artifacts.require("Hunter");
const Hunter2 = artifacts.require("Hunter2");

const toAmount = function (amount, decimals) {
  return amount.toString() + '0'.repeat(decimals)
}

module.exports = async function (deployer, network) {
  switch (network) {
    case 'Bsc':
      // await deployer.deploy(Fetcher);
      await deployer.deploy(Hunter2);
      break;

    default:
      break;
  }
};
