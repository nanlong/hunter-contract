// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library UniswapV2Library {
    using SafeMath for uint256;

    function getPairAmountOut(
        address tokenOut,
        address pair,
        uint256 fee,
        uint256 reserve0,
        uint256 reserve1
    ) internal view returns (uint256 amountOut) {
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        uint256 balance;
        uint256 amountIn;

        if (tokenOut == pairContract.token0()) {
            balance = IERC20(pairContract.token1()).balanceOf(pair);
            amountIn = balance.sub(reserve1);
            amountOut = getAmountOut(amountIn, reserve1, reserve0, fee);
        } else {
            balance = IERC20(pairContract.token0()).balanceOf(pair);
            amountIn = balance.sub(reserve0);
            amountOut = getAmountOut(amountIn, reserve0, reserve1, fee);
        }
    }

    function getPiarAmountOut(
        address pair,
        uint256 fee,
        uint256 reserve0,
        uint256 reserve1
    ) internal view returns (uint256 amount0Out, uint256 amount1Out) {
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        uint256 balance = IERC20(pairContract.token0()).balanceOf(pair);
        uint256 amountIn;

        if (balance == reserve0) {
            balance = IERC20(pairContract.token1()).balanceOf(pair);
            amountIn = balance.sub(reserve1);
            amount1Out = uint256(0);
            amount0Out = getAmountOut(amountIn, reserve1, reserve0, fee);
        } else {
            amountIn = balance.sub(reserve0);
            amount0Out = uint256(0);
            amount1Out = getAmountOut(amountIn, reserve0, reserve1, fee);
        }
    }

    function getSnapshots(address[] memory path)
        internal
        view
        returns (uint256[] memory reserves0, uint256[] memory reserves1)
    {
        reserves0 = new uint256[](path.length);
        reserves1 = new uint256[](path.length);

        for (uint256 i = 0; i < path.length; i++) {
            IUniswapV2Pair pair = IUniswapV2Pair(path[i]);
            (reserves0[i], reserves1[i], ) = pair.getReserves();
        }
    }

    function getLastAmountsOut(
        address tokenIn,
        uint256 amountIn,
        address[] memory path,
        uint256[] memory fees
    ) internal view returns (uint256 amountOut) {
        uint256[] memory amountOuts = UniswapV2Library.getAmountsOut(
            tokenIn,
            amountIn,
            path,
            fees
        );

        amountOut = amountOuts[amountOuts.length - 1];
    }

    function getAmountsOut(
        address tokenIn,
        uint256 amountIn,
        address[] memory path,
        uint256[] memory fees
    ) internal view returns (uint256[] memory amountOuts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        uint256 amountOut;
        address[] memory tokenIns = new address[](path.length);
        uint256[] memory amountIns = new uint256[](path.length);
        amountOuts = new uint256[](path.length);

        tokenIns[0] = tokenIn;
        amountIns[0] = amountIn;

        for (uint256 i; i < path.length; i++) {
            (
                address tokenOut,
                uint256 reserveIn,
                uint256 reserveOut
            ) = getReserves(tokenIns[i], path[i]);

            amountOut = getAmountOut(
                amountIns[i],
                reserveIn,
                reserveOut,
                fees[i]
            );

            if (i < path.length - 1) {
                tokenIns[i + 1] = tokenOut;
                amountIns[i + 1] = amountOut;
            }

            amountOuts[i] = amountOut;
        }
    }

    function getReserves(address tokenIn, address pair)
        internal
        view
        returns (
            address tokenOut,
            uint256 reserveIn,
            uint256 reserveOut
        )
    {
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);

        (address token0, address token1) = (
            pairContract.token0(),
            pairContract.token1()
        );
        (uint256 reserve0, uint256 reserve1, ) = pairContract.getReserves();
        (tokenOut, reserveIn, reserveOut) = tokenIn == token0
            ? (token1, reserve0, reserve1)
            : (token0, reserve1, reserve0);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn.mul(fee);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(100000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
}
