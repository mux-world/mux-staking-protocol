// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IMlpRewardTracker.sol";

contract ArbDistributor is ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 constant ONE = 1e18;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public pol;
    address public arbToken;
    address public mlpToken;
    address public sMlpToken;
    uint256 public rewardRate;
    uint256 public polBalance;
    uint256 public lastUpdateTime;
    uint256 public cumulativeRewardPerToken;

    mapping(address => uint256) public claimableReward;
    mapping(address => uint256) public previousCumulatedRewardPerToken;
    mapping(address => bool) public isHandler;

    event Claim(address receiver, uint256 amount);
    event SetRewardRate(uint256 previousRewardRate, uint256 newRewardRate);

    modifier onlyHandler() {
        require(isHandler[msg.sender], "ArbDistributor::HANDLER");
        _;
    }

    // deposit mlp
    function initialize(
        string memory name_,
        string memory symbol_,
        address pol_,
        address arbToken_,
        address mlpToken_,
        address sMlpToken_
    ) external initializer {
        __Ownable_init();

        name = name_;
        symbol = symbol_;
        pol = pol_;
        arbToken = arbToken_;
        mlpToken = mlpToken_;
        sMlpToken = sMlpToken_;
    }

    function setRewardRate(uint256 newRewardRate) external onlyOwner {
        _updateRewards(address(0));
        emit SetRewardRate(rewardRate, newRewardRate);
        rewardRate = newRewardRate;
    }

    function setHandler(address handler_, bool enable_) external onlyOwner {
        isHandler[handler_] = enable_;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == pol) {
            return polBalance;
        } else {
            return IMlpRewardTracker(sMlpToken).depositBalances(account, mlpToken);
        }
    }

    function totalSupply() public view returns (uint256) {
        return IERC20Upgradeable(sMlpToken).totalSupply() + balanceOf(pol);
    }

    function updateRewards(address account) external nonReentrant {
        _updateRewards(account);
    }

    // Claim rewards for senior/junior. Should call RouterV1.updateRewards() first to collected all rewards.
    function claim(address _receiver) external nonReentrant returns (uint256) {
        _updateRewards(msg.sender);
        _claim(pol, pol); // claim for pol
        return _claim(msg.sender, _receiver);
    }

    /**
     * @dev Allows the handler to claim tokens for a specified account and transfer them to a specified receiver.
     * @param account The account to claim tokens for.
     * @param _receiver The address to transfer the claimed tokens to.
     * @return The amount of tokens claimed.
     */
    function claimFor(address account, address _receiver) external onlyHandler nonReentrant returns (uint256) {
        _updateRewards(account);
        _claim(pol, pol); // claim for pol
        return _claim(account, _receiver);
    }

    // Get claimable rewards for senior/junior. Should call RouterV1.updateRewards() first to collected all rewards.
    function claimable(address account) public returns (uint256) {
        _updateRewards(account);
        uint256 balance = balanceOf(account);
        if (balance == 0) {
            return claimableReward[account];
        }
        return
            claimableReward[account] +
            ((balance * (cumulativeRewardPerToken - previousCumulatedRewardPerToken[account])) / ONE);
    }

    /**
     * @dev Fake allowance always returns 0
     */
    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function _claim(address account, address receiver) private returns (uint256) {
        uint256 tokenAmount = claimableReward[account];
        claimableReward[account] = 0;
        if (tokenAmount > 0) {
            IERC20Upgradeable(arbToken).safeTransfer(receiver, tokenAmount);
            emit Claim(account, tokenAmount);
        }
        return tokenAmount;
    }

    function _updateRewards(address account) private {
        // update new rewards
        uint256 currentTime = block.timestamp;
        if (currentTime == lastUpdateTime) {
            return;
        }
        uint256 reward = ((currentTime - lastUpdateTime) * rewardRate);
        lastUpdateTime = currentTime;
        if (reward == 0) {
            return;
        }
        uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken;
        uint256 supply = totalSupply();
        if (supply > 0 && reward > 0) {
            nextCumulativeRewardPerToken = nextCumulativeRewardPerToken + ((reward * ONE) / supply);
            cumulativeRewardPerToken = nextCumulativeRewardPerToken;
        }
        if (nextCumulativeRewardPerToken == 0) {
            return;
        }
        _updateAccountReward(pol, nextCumulativeRewardPerToken); // always update rewards of POL
        if (account != address(0)) {
            _updateAccountReward(account, nextCumulativeRewardPerToken);
        }

        // update balanceOf pol
        polBalance = IERC20Upgradeable(mlpToken).balanceOf(pol);
    }

    function _updateAccountReward(address account, uint256 nextCumulativeRewardPerToken) internal {
        uint256 accountReward = (balanceOf(account) *
            (nextCumulativeRewardPerToken - previousCumulatedRewardPerToken[account])) / ONE;
        claimableReward[account] = claimableReward[account] + accountReward;
        previousCumulatedRewardPerToken[account] = nextCumulativeRewardPerToken;
    }
}
