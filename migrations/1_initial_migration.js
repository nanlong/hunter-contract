const Fetcher = artifacts.require("Fetcher");
const Hunter = artifacts.require("Hunter");

const toAmount = function (amount, decimals) {
  return amount.toString() + '0'.repeat(decimals)
}

module.exports = async function (deployer, network) {
  switch (network) {
    case 'Bsc':
      // await deployer.deploy(Fetcher);
      await deployer.deploy(Hunter);
      break;

    default:
      break;
  }
};
