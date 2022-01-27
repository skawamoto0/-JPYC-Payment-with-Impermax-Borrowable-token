// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IErc20 {
    function decimals() external pure returns (uint8);
    function balanceOf(address a) external view returns (uint256);
    function transferFrom(address a, address b, uint256 c) external returns (bool);
}

interface IJpyc is IErc20 {
}

interface IImpermax is IErc20 {
    function exchangeRateLast() external view returns (uint256);
}

contract JpycPaymentWithImpermax {
    address internal owner;
    address public jpyc;
    address public impermax;
    uint256 public limit;
    function initialize() public {
        require(owner == address(0));
        owner = msg.sender;
        jpyc = 0x6AE7Dfc73E0dDE2aa99ac063DcF7e8A63265108c;
        impermax = 0xDB36fA27166b011Be6a6aa17AAAf6B4117453274;
        limit = 100000;
    }
    function update(address _jpyc, address _impermax, uint256 _limit) public {
        require(msg.sender == owner);
        jpyc = _jpyc;
        impermax = _impermax;
        limit = _limit;
    }
    function getJpycPriceInImpermax(uint256 amount) public view returns(uint256) {
        IJpyc j = IJpyc(jpyc);
        IImpermax i = IImpermax(impermax);
        return (amount * (10 ** i.decimals()) / i.exchangeRateLast()) * (10 ** j.decimals()) / (10 ** i.decimals());
    }
    function pay(uint256 amountInJpyc, uint256 amountOfImpermax) public {
        IJpyc j = IJpyc(jpyc);
        IImpermax i = IImpermax(impermax);
        uint256 amountOfJpyc;
        require(amountInJpyc <= limit * (10 ** j.decimals()));
        require(amountOfImpermax <= limit * (10 ** i.decimals()));
        unchecked {
            amountOfJpyc = amountInJpyc - (amountOfImpermax * i.exchangeRateLast() / (10 ** i.decimals())) * (10 ** j.decimals()) / (10 ** i.decimals());
        }
        if(amountOfImpermax >= getJpycPriceInImpermax(amountInJpyc)) {
            amountOfImpermax = getJpycPriceInImpermax(amountInJpyc);
            amountOfJpyc = 0;
        }
        _transfer(jpyc, amountOfJpyc);
        _transfer(impermax, amountOfImpermax);
    }
    function _transfer(address token, uint256 amount) internal {
        IErc20 e = IErc20(token);
        uint256 balanceOld;
        if(amount > 0) {
            require(e.balanceOf(msg.sender) >= amount);
            balanceOld = e.balanceOf(owner);
            e.transferFrom(msg.sender, owner, amount);
            require(e.balanceOf(owner) - balanceOld == amount);
        }
    }
}
