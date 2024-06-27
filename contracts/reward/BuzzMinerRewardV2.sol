pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interface/IBuzzMiningRigs.sol";

contract BuzzMinerRewardV2 is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    bool private initialized; // Flag of initialize data

    // minerId stop reward but can not withdraw
    struct StopReward {
        uint256 amount;
        uint256 startStopTime;
    }

    IERC20 public rewardToken;
    address public minerNFT;
    address public blockheadz;

    uint256 public startStakeTime;

    uint256 public curCycleReward;
    uint256 public curCycleStartTime;
    uint256 public duration;

    uint256 public cycleTimes;

    uint256 public rewardRate;
    uint256 public periodFinish;

    uint256 public lastUpdateTime;
    uint256 private rewardPerTokenStored;
    uint256 public halveQuota; // 50000 is halves
    uint256 public endCycle;

    mapping(address => uint256) private userRewardPerTokenPaid;

    // user can claim rewards
    mapping(address => uint256) private rewards;

    mapping(address => EnumerableSet.UintSet) private userBlockheadzIds;

    uint256 public totalPower; // orig *100
    mapping(address => uint256) public userPower; // orig *100

    // user all rewards (claim + unclaim)
    mapping(address => uint256) public claimedRewards;

    // amount for user by miner id
    mapping(address => mapping(uint256 => uint256)) public userStakeIds;

    // all amount of miner id
    mapping(uint256 => uint256) public allStakeIds;

    // all amount of miner id
    uint256 public claimStartTime;
    uint256 public claimInterval;

    // claim time of staker
    mapping(address => uint256) public lastClaimTime;

    // uint256 public fixedBonus; //  1000 *100
    // // claim time of staker
    // // 1: 5% extra bonus
    // // 2: 300 extra bonus fixedBonus
    // mapping(address => uint256) public extraBonusType;

    event SetRewardToken(address indexed rewardToken);
    event StakedNFTs(address indexed user, uint256[] ids, uint256[] amounts);
    event WithdrawNFTs(address indexed user, uint256[] ids, uint256[] amounts);

    event GetReward(address indexed user, uint256 reward, uint256 time);
    event StartNewEpoch(uint256 reward, uint256 duration);
    event SetCycleRewardConfig(uint256 reward, uint256 duration);
    event StakedBlockheadz(address indexed user, uint256[] ids);
    event UnStakedBlockheadz(address indexed user, uint256[] ids);
    event SetRewardConfig(
        uint256 halveQuota,
        uint256 endCycle,
        uint256 claimInterval
    );
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier checkNextEpoch() {
        if (block.timestamp >= periodFinish) {
            curCycleReward = (curCycleReward * halveQuota) / 100000;
            if (cycleTimes == endCycle) {
                curCycleReward = 0;
            }
            curCycleStartTime = block.timestamp;
            periodFinish = block.timestamp + (duration);
            cycleTimes++;
            lastUpdateTime = curCycleStartTime;
            rewardRate = curCycleReward / (duration);
            emit StartNewEpoch(curCycleReward, duration);
        }
        _;
    }

    function initialize(
        uint256 _initReward, // total reward for all cycle
        uint256 _duration, // every cycle duration
        uint256 _startStakeTime, // start time for first cycle
        uint256 _startRewardTime, // start time for first cycle
        uint256 _claimStartTime // start time for claim reward
    ) external {
        require(!initialized, "initialize: Already initialized!");
        _transferOwnership(0x1001d15D5da778fbd2f34F86b0d600A6B4a3540e);
        minerNFT = 0xD1b76c0f58c6d65E396F98cAea94Cd717c3a848e;
        blockheadz = 0x066466d7EAa56b60AAF0436dbDA6f92DB7BD2468;

        halveQuota = 50000;
        endCycle = 4;
        claimInterval = 1 days;
        curCycleReward = _initReward;
        startStakeTime = _startStakeTime;
        duration = _duration; // 4 weeks
        periodFinish = _startRewardTime;
        claimStartTime = _claimStartTime;

        initialized = true;
    }

    function rewardPerToken() private view returns (uint256) {
        if (totalPower == 0) {
            return rewardPerTokenStored;
        }
        // return
        //     rewardPerTokenStored +
        //     (((lastTimeRewardApplicable() - lastUpdateTime) *
        //         rewardRate *
        //         (1e18)) / totalPower);
        return
            rewardPerTokenStored +
            (
                ((lastTimeRewardApplicable() - lastUpdateTime) *
                    rewardRate *
                    (1e18))
            );
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function earned(address account) public view returns (uint256) {
        return
            (userPower[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) /
            1e18 +
            rewards[account];
    }

    // stake nft
    function stakeMiners(
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external updateReward(msg.sender) checkNextEpoch nonReentrant {
        require(block.timestamp >= startStakeTime, "not start");
        require(
            ids.length == amounts.length,
            "ids and amounts length not equal"
        );
        uint256 beforePower = userPower[msg.sender];
        totalPower -= beforePower;
        for (uint256 index = 0; index < ids.length; index++) {
            uint256 stakeId = ids[index];
            require(stakeId > 0, "0:minner id incorrect");
            require(stakeId < 4, "4:minner id incorrect");
            uint256 stakeAmount = amounts[index];
            require(stakeAmount > 0, "Cannot stake 0");
            userStakeIds[msg.sender][stakeId] += stakeAmount;
            allStakeIds[stakeId] += stakeAmount;
        }

        IERC1155(minerNFT).safeBatchTransferFrom(
            msg.sender,
            address(this),
            ids,
            amounts,
            "0x0"
        );
        uint256 finalPower = reCalculatePower();
        userPower[msg.sender] = finalPower;
        totalPower += finalPower;

        emit StakedNFTs(msg.sender, ids, amounts);
    }

    function withdrawMiners(
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external updateReward(msg.sender) checkNextEpoch nonReentrant {
        require(
            ids.length == amounts.length,
            "ids and amounts length not equal"
        );
        uint256 beforePower = userPower[msg.sender];
        totalPower -= beforePower;
        for (uint256 index = 0; index < ids.length; index++) {
            uint256 withdrawId = ids[index];
            uint256 withdrawAmount = amounts[index];
            require(withdrawAmount > 0, "Cannot withdraw 0");
            userStakeIds[msg.sender][withdrawId] -= withdrawAmount;
            allStakeIds[withdrawId] -= withdrawAmount;
        }

        uint256 finalPower = reCalculatePower();
        userPower[msg.sender] = finalPower;
        totalPower += finalPower;

        IERC1155(minerNFT).safeBatchTransferFrom(
            address(this),
            msg.sender,
            ids,
            amounts,
            "0x0"
        );

        emit WithdrawNFTs(msg.sender, ids, amounts);
    }

    function stakeBlockheadz(
        uint256[] calldata ids
    ) external updateReward(msg.sender) checkNextEpoch nonReentrant {
        require(block.timestamp >= startStakeTime, "not start");
        require(ids.length > 0, "ids is empty");

        uint256 beforePower = userPower[msg.sender];
        totalPower -= beforePower;

        for (uint i = 0; i < ids.length; i++) {
            IERC721(blockheadz).safeTransferFrom(
                msg.sender,
                address(this),
                ids[i]
            );
            require(userBlockheadzIds[msg.sender].add(ids[i]), "staked error");
        }
        uint256 finalPower = reCalculatePower();
        userPower[msg.sender] = finalPower;
        totalPower += finalPower;

        emit StakedBlockheadz(msg.sender, ids);
    }

    function unStakeBlockheadz(
        uint256[] calldata ids
    ) external updateReward(msg.sender) checkNextEpoch nonReentrant {
        uint256 beforePower = userPower[msg.sender];
        totalPower -= beforePower;

        for (uint i = 0; i < ids.length; i++) {
            IERC721(blockheadz).safeTransferFrom(
                address(this),
                msg.sender,
                ids[i]
            );
            require(userBlockheadzIds[msg.sender].remove(ids[i]), "not staked");
        }

        uint256 finalPower = reCalculatePower();
        userPower[msg.sender] = finalPower;
        totalPower += finalPower;
        emit UnStakedBlockheadz(msg.sender, ids);
    }

    function getReward()
        external
        updateReward(msg.sender)
        checkNextEpoch
        nonReentrant
    {
        require(block.timestamp >= claimStartTime, "not start getReward");
        require(rewardToken != IERC20(address(0)), "not set reward token");
        require(
            lastClaimTime[msg.sender] + claimInterval <= block.timestamp,
            "Insufficient cooling time"
        );
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            claimedRewards[msg.sender] += reward;
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);

            lastClaimTime[msg.sender] = block.timestamp;
            emit GetReward(msg.sender, reward, block.timestamp);
        }
    }

    function setRewardConfig(
        uint256 _halveQuota,
        uint256 _endCycle,
        uint256 _claimInterval
    ) external onlyOwner {
        halveQuota = _halveQuota;
        endCycle = _endCycle;
        claimInterval = _claimInterval;
        emit SetRewardConfig(_halveQuota, _endCycle, _claimInterval);
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = IERC20(_rewardToken);
        emit SetRewardToken(_rewardToken);
    }

    function setNextCycleReward(
        uint256 _curCycleReward,
        uint256 _duration
    ) external onlyOwner {
        curCycleReward = _curCycleReward; // next helf
        duration = _duration;
        emit SetCycleRewardConfig(_curCycleReward, _duration);
    }

    function userBlockheadzAmounts(
        address user
    ) external view returns (uint256) {
        return userBlockheadzIds[user].length();
    }

    function userStakeBlockheadzIds(
        address user
    ) external view returns (uint256[] memory) {
        return userBlockheadzIds[user].values();
    }

    // get practical power
    function reCalculatePower() private view returns (uint256) {
        uint256 _userPower = 0;
        for (uint256 stakeId = 1; stakeId <= 3; stakeId++) {
            uint256 stakeAmount = userStakeIds[msg.sender][stakeId];
            uint256 quality = IBuzzMiningRigs(minerNFT).minerQuality(stakeId) *
                100;
            _userPower += quality * stakeAmount;
        }
        uint256 blockHeadzAmount = userBlockheadzIds[msg.sender].length();
        if (_userPower == 0) {
            return blockHeadzAmount * 30000;
        } else {
            if (blockHeadzAmount == 0) {
                return _userPower;
            } else {
                uint256 floatBonus = (_userPower * (100 + 5)) / 100;
                uint256 fixedBonus = _userPower + 30000;
                if (floatBonus > fixedBonus) {
                    return floatBonus + (blockHeadzAmount - 1) * 30000;
                } else {
                    return fixedBonus + (blockHeadzAmount - 1) * 30000;
                }
            }
        }
    }

    function onERC1155Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*id*/,
        uint256 /*value*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function onERC1155BatchReceived(
        address /*operator*/,
        address /*from*/,
        uint256[] calldata /*ids*/,
        uint256[] calldata /*amounts*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }
}
