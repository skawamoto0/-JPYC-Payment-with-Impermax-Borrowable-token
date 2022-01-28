// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IErc20 {
    function decimals() external pure returns(uint8);
    function balanceOf(address) external view returns(uint256);
    function transfer(address, uint256) external returns(bool);
    function approve(address, uint256) external returns(bool);
    function transferFrom(address, address, uint256) external returns(bool);
}

interface IJpyc is IErc20 {
}

interface IImpermax is IErc20 {
    function exchangeRateLast() external view returns(uint256);
}

interface IImpermaxRouter {
    function mint(address, uint256, address, uint256) external returns(uint256);
}

contract JpycPaymentWithImpermax {
    address internal owner;
    address public jpyc;
    address public impermax;
    uint256 public limit;
    address public router;
    uint256 public tolerance;
    function initialize() public {
        require(owner == address(0));
        owner = msg.sender;
        jpyc = 0x6AE7Dfc73E0dDE2aa99ac063DcF7e8A63265108c;
        impermax = 0xDB36fA27166b011Be6a6aa17AAAf6B4117453274;
        limit = 100000;
        router = 0x7C79A1c2152665273ebD50e9E88d92A887a83BA0;
        tolerance = 100000000000000;
    }
    function update(address _jpyc, address _impermax, uint256 _limit, address _router, uint256 _tolerance) public {
        require(msg.sender == owner);
        jpyc = _jpyc;
        impermax = _impermax;
        limit = _limit;
        router = _router;
        tolerance = _tolerance;
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
        _convertAndTransfer(amountOfJpyc);
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
    function _convertAndTransfer(uint256 amountInJpyc) internal {
        IJpyc j = IJpyc(jpyc);
        IImpermax i = IImpermax(impermax);
        IImpermaxRouter r = IImpermaxRouter(router);
        uint256 balanceOld;
        uint256 amountOfImpermax;
        if(amountInJpyc > 0) {
            j.transferFrom(msg.sender, address(this), amountInJpyc);
            j.approve(router, amountInJpyc);
            balanceOld = i.balanceOf(address(this));
            r.mint(impermax, amountInJpyc, address(this), block.timestamp);
            require(i.balanceOf(address(this)) - balanceOld >= getJpycPriceInImpermax(amountInJpyc) * (1000000000000000000 - tolerance) / 1000000000000000000);
            amountOfImpermax = i.balanceOf(address(this));
            balanceOld = i.balanceOf(owner);
            i.transfer(owner, amountOfImpermax);
            require(i.balanceOf(owner) - balanceOld == amountOfImpermax);
        }
    }
}
