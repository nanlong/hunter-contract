// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

struct CallbackData {
    address tokenIn;
    uint256 amountIn;
    uint256 amountOut;
    address[] pairs;
    uint256[] amount0Outs;
    uint256[] amount1Outs;
}

contract Hunter is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private _permissionedPairAddress;

    receive() external payable {}

    /// @dev Redirect uniswap callback function
    /// The callback function on different DEX are not same, so use a fallback to redirect to uniswapV2Call
    fallback() external {
        (
            address sender,
            uint256 amount0,
            uint256 amount1,
            bytes memory data
        ) = abi.decode(msg.data[4:], (address, uint256, uint256, bytes));
        uniswapV2Call(sender, amount0, amount1, data);
    }

    function withdraw(address[] calldata tokens) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            uint256 balance = token.balanceOf(address(this));
            if (balance > 0) token.transfer(owner(), balance);
        }
    }

    function checkFlashArbitrage(
        uint256 amountIn,
        address tokenIn,
        address[] memory pairs,
        uint256[] memory pairsFee
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256[] memory reserve0,
            uint256[] memory reserve1
        )
    {
        CallbackData memory callbackData = genCallbackData(
            amountIn,
            tokenIn,
            pairs,
            pairsFee
        );

        reserve0 = new uint256[](pairs.length);
        reserve1 = new uint256[](pairs.length);

        for (uint256 i = 0; i < pairs.length; i++) {
            (reserve0[i], reserve1[i], ) = IUniswapV2Pair(pairs[i])
                .getReserves();
        }

        return (
            callbackData.amountIn,
            callbackData.amountOut,
            reserve0,
            reserve1
        );
    }

    function flashArbitrage(
        uint256 blockNumber,
        uint256 amountIn,
        address tokenIn,
        address[] memory pairs,
        uint256[] memory pairsFee
    ) external {
        require(block.number <= blockNumber, "0");
        CallbackData memory callbackData = genCallbackData(
            amountIn,
            tokenIn,
            pairs,
            pairsFee
        );
        require(callbackData.amountOut > callbackData.amountIn, "1");

        uint256 i = pairs.length - 1;

        _permissionedPairAddress = pairs[i];

        IUniswapV2Pair(pairs[i]).swap(
            callbackData.amount0Outs[i],
            callbackData.amount1Outs[i],
            address(this),
            abi.encode(callbackData)
        );

        _permissionedPairAddress = address(0);
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes memory data
    ) public {
        require(
            msg.sender == _permissionedPairAddress && sender == address(this),
            "2"
        );
        require(amount0 > 0 || amount1 > 0);

        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        IERC20(callbackData.tokenIn).safeTransfer(
            callbackData.pairs[0],
            callbackData.amountIn
        );

        for (uint256 i = 0; i < callbackData.pairs.length - 1; i++) {
            IUniswapV2Pair(callbackData.pairs[i]).swap(
                callbackData.amount0Outs[i],
                callbackData.amount1Outs[i],
                callbackData.pairs[i + 1],
                new bytes(0)
            );
        }
    }

    function genCallbackData(
        uint256 amountIn,
        address tokenIn,
        address[] memory pairs,
        uint256[] memory pairsFee
    ) internal view returns (CallbackData memory callbackData) {
        uint256[] memory pairsAmountOut = new uint256[](pairs.length);
        address[] memory pairsTokenOut = new address[](pairs.length);

        callbackData.amountIn = amountIn;
        callbackData.tokenIn = tokenIn;
        callbackData.pairs = pairs;
        callbackData.amount0Outs = new uint256[](pairs.length);
        callbackData.amount1Outs = new uint256[](pairs.length);

        for (uint256 i = 0; i < pairs.length; i++) {
            (address token0, address token1) = (
                IUniswapV2Pair(pairs[i]).token0(),
                IUniswapV2Pair(pairs[i]).token1()
            );
            (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairs[i])
                .getReserves();

            (tokenIn, amountIn) = i == 0
                ? (tokenIn, amountIn)
                : (pairsTokenOut[i - 1], pairsAmountOut[i - 1]);

            (pairsTokenOut[i], pairsAmountOut[i]) = tokenIn == token0
                ? (
                    token1,
                    getAmountOut(amountIn, reserve0, reserve1, pairsFee[i])
                )
                : (
                    token0,
                    getAmountOut(amountIn, reserve1, reserve0, pairsFee[i])
                );

            if (i == pairs.length - 1) {
                callbackData.amountOut = pairsAmountOut[i];
            }

            (
                callbackData.amount0Outs[i],
                callbackData.amount1Outs[i]
            ) = pairsTokenOut[i] == token0
                ? (pairsAmountOut[i], uint256(0))
                : (uint256(0), pairsAmountOut[i]);
        }
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "Hunter: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "Hunter: INSUFFICIENT_LIQUIDITY"
        );
        uint256 d = 10000;
        uint256 amountInWithFee = amountIn.mul(fee);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(d).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
}
