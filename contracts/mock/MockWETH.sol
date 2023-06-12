// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract MockWETH is ERC20PresetMinterPauser {
    uint8 _decimals;

    receive() external payable {}

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20PresetMinterPauser(name, symbol) {
        _decimals = decimals_;
    }

    function burn(address account, uint256 amount) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "sender must be minter to burn");
        _burn(account, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function tokenSupplyOnL1() external pure returns (uint256) {
        return 0;
    }

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        require(balanceOf(msg.sender) >= wad, "");
        _mint(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
}
