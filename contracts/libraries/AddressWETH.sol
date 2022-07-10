// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library AddressWETH {
    function WETH() internal view returns (address addr) {
        assembly {
            switch chainid()
                case  1  { addr := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 }      // Ethereum Mainnet
                case  3  { addr := 0xc778417E063141139Fce010982780140Aa0cD5Ab }      // Ethereum Testnet Ropsten
                case  4  { addr := 0xc778417E063141139Fce010982780140Aa0cD5Ab }      // Ethereum Testnet Rinkeby
                case  5  { addr := 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6 }      // Ethereum Testnet Gorli
                case 42  { addr := 0xd0A1E359811322d97991E03f863a0C30C2cF029C }      // Ethereum Testnet Kovan
                case 56  { addr := 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c }      // BSC Mainnet
                case 65  { addr := 0x2219845942d28716c0f7c605765fabdca1a7d9e0 }      // okexchain-test
                case 66  { addr := 0x8f8526dbfd6e38e3d8307702ca8469bae6c56c15 }      // okexchain-mainnet
                case 128 { addr := 0x5545153ccfca01fbd7dd11c0b23ba694d9509a6f }      // HECO Mainnet
                case 256 { addr := 0xB49f19289857f4499781AaB9afd4A428C4BE9CA8 }      // HECO Testnet
                default  { addr := 0x0                                        }      // unknown
        }
    }
}