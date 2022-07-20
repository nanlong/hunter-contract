// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract Fetcher {
    using Address for address;

    struct Coin {
        address addr;
        string name;
        string symbol;
        uint8 decimals;
    }

    struct Pair {
        address factory;
        address addr;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        string symbol0;
        string symbol1;
        uint8 decimals0;
        uint8 decimals1;
    }

    function getCoins(address[] calldata tokenAddresses)
        public
        view
        returns (Coin[] memory tokens)
    {
        tokens = new Coin[](tokenAddresses.length);

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address addr = tokenAddresses[i];
            tokens[i] = getCoin(addr);
        }
    }

    function getPairsWithIndexes(address factory, uint256[] calldata indexes)
        public
        view
        returns (Pair[] memory pairs)
    {
        pairs = new Pair[](indexes.length);

        for (uint256 i = 0; i < indexes.length; i++) {
            address addr = IUniswapV2Factory(factory).allPairs(indexes[i]);
            pairs[i] = getPair(addr);
        }
    }

    function getPairPaginate(
        address factory,
        uint256 pageSize,
        uint256 pageNumber
    )
        public
        view
        returns (
            uint256 blockNumber,
            uint256 total,
            Pair[] memory pairs
        )
    {
        blockNumber = block.number;
        (total, pairs) = getPairPaginateWithLength(
            factory,
            IUniswapV2Factory(factory).allPairsLength(),
            pageSize,
            pageNumber
        );
    }

    function getPairPaginateWithLength(
        address factory,
        uint256 allPairsLength,
        uint256 pageSize,
        uint256 pageNumber
    ) public view returns (uint256 total, Pair[] memory pairs) {
        total = allPairsLength;

        uint256 count = pageNumber * pageSize > total
            ? (
                pageNumber * pageSize - total > pageSize
                    ? 0
                    : pageSize - (pageNumber * pageSize - total)
            )
            : pageSize;

        pairs = new Pair[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 index = (pageNumber - 1) * pageSize + i;
            address addr = IUniswapV2Factory(factory).allPairs(index);
            pairs[i] = getPair(addr);
        }
    }

    function getPairsWithCoins(
        address[] calldata factors,
        address token0,
        address token1
    ) public view returns (Pair[] memory pairs) {
        pairs = new Pair[](factors.length);

        for (uint256 i = 0; i < factors.length; i++) {
            address addr = IUniswapV2Factory(factors[i]).getPair(
                token0,
                token1
            );
            pairs[i] = getPair(addr);
        }
    }

    function getPairsWithAddresses(address[] calldata pairAddresses)
        public
        view
        returns (uint256 blockNumber, Pair[] memory pairs)
    {
        blockNumber = block.number;
        pairs = new Pair[](pairAddresses.length);

        for (uint256 i = 0; i < pairAddresses.length; i++) {
            address addr = pairAddresses[i];
            pairs[i] = getPair(addr);
        }
    }

    function getReserves(address[] calldata pairs)
        public
        view
        returns (
            uint256 blockNumber,
            uint256[] memory reserve0,
            uint256[] memory reserve1
        )
    {
        blockNumber = block.number;
        reserve0 = new uint256[](pairs.length);
        reserve1 = new uint256[](pairs.length);

        for (uint256 i = 0; i < pairs.length; i++) {
            (reserve0[i], reserve1[i], ) = IUniswapV2Pair(pairs[i])
                .getReserves();
        }
    }

    function getSafeReserves(address[] calldata pairs)
        public
        view
        returns (
            uint256 blockNumber,
            uint256[] memory reserve0,
            uint256[] memory reserve1
        )
    {
        blockNumber = block.number;
        reserve0 = new uint256[](pairs.length);
        reserve1 = new uint256[](pairs.length);

        for (uint256 i = 0; i < pairs.length; i++) {
            address token0 = IUniswapV2Pair(pairs[i]).token0();
            address token1 = IUniswapV2Pair(pairs[i]).token1();
            uint256 balance0 = IERC20(token0).balanceOf(pairs[i]);
            uint256 balance1 = IERC20(token1).balanceOf(pairs[i]);
            (uint256 r0, uint256 r1, ) = IUniswapV2Pair(pairs[i]).getReserves();
            (reserve0[i], reserve1[i]) = balance0 >= r0 && balance1 >= r1
                ? (r0, r1)
                : (0, 0);
        }
    }

    function getPair(address addr) private view returns (Pair memory pair) {
        pair.addr = addr;
        pair.factory = IUniswapV2Pair(pair.addr).factory();
        pair.token0 = IUniswapV2Pair(pair.addr).token0();
        pair.token1 = IUniswapV2Pair(pair.addr).token1();
        (pair.reserve0, pair.reserve1, ) = IUniswapV2Pair(pair.addr)
            .getReserves();
        pair.symbol0 = coin_symbol(pair.token0);
        pair.symbol1 = coin_symbol(pair.token1);
        pair.decimals0 = coin_decimals(pair.token0);
        pair.decimals1 = coin_decimals(pair.token1);
    }

    function getCoin(address addr) private view returns (Coin memory token) {
        token.addr = addr;
        token.name = coin_name(addr);
        token.symbol = coin_symbol(addr);
        token.decimals = coin_decimals(addr);
    }

    function coin_name(address token) public view returns (string memory) {
        return token.isContract() ? _coin_name(token) : "";
    }

    function coin_symbol(address token) public view returns (string memory) {
        return token.isContract() ? _coin_symbol(token) : "";
    }

    function coin_decimals(address token) public view returns (uint8) {
        return token.isContract() ? _coin_decimals(token) : 0;
    }

    function _coin_name(address token) private view returns (string memory) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("name()"))))
        );
        return success ? string(abi.encodePacked(data)) : "";
    }

    function _coin_symbol(address token) private view returns (string memory) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("symbol()"))))
        );
        return success ? string(abi.encodePacked(data)) : "";
    }

    function _coin_decimals(address token) private view returns (uint8) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("decimals()"))))
        );
        return success ? abi.decode(data, (uint8)) : 0;
    }
}
