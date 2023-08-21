// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UsdcMock is ERC20 {
    constructor() ERC20("USDC Mock", "USDCMock") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
