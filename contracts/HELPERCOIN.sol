// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ERC20.sol";

error WaitPeriodNotElapsed();
error TransferLimitReached();
error RewardBalanceZero();
error InvalidLength();
error InvalidData();
error AlreadySet();
error NotEnoughFund();
error NotAuthorised();
error TransferNotAllowed();
error AddressZeroNotAllowed();
error RequiredTimeNotElapsed();
error AmountNotAuthorised();
error InvalidSlot();
error ProposalNotSucceeded();
error AlreadyVoted();

contract HELPERCOIN is ERC20 {
    uint256 public constant maxTotalSupply = 1000 * 10**6 * 10**18;
    uint256 private constant initialTotalSupply = 1 * 10**6 * 10**18;
    uint256 private constant minTotalSupplyForStopBurn = 50 * 10**6 * 10**18;
    uint256 public constant minBalanceForReward = 1 * 10**18;
    uint256 public constant denominator = 10000;

    uint256 public dailyRewardRate;
    uint256 public burnFee;
    uint256 public transferFee;

    address public immutable prime_holders_address;
    address public immutable development_address;
    address public immutable legal_and_backup_address;
    address public immutable marketing_address;
    address public immutable core_holders_address;
    address public caller;

    bool public shouldTakeSellFee = true;
    bool public shouldBurn = false;
    bool public shouldChargeTransfer = false;

    address[] private holdersArray;
    address[] private holdersArrayCore;

    mapping(address => HoldStruct) public holdersMap;
    mapping(address => HoldStructCore) public holdersMapCore;
    mapping(address => bool) public _isExemptFromFee;
    mapping(address => bool) public _isExemptFromReward;
    mapping(address => bool) public _isDex;

    SlotDaysInfo public slotDaysInfo;
    SlotDaysFeeInfo public slotDaysFeeInfo;
    SlotDaysFeeInfo public slotDaysFeeInfoDex;
    SlotDaysRewardInfo public slotDaysRewardInfo;

    WithdrawInfo public developmentWithdrawInfo;
    WithdrawInfo public legalAndBackupWithdrawInfo;
    WithdrawInfo public marketingWithdrawInfo;

    MultiSign public multiSignInfo;

    struct SlotDaysInfo {
        uint256 slot1Days;
        uint256 slot2Days;
        uint256 slot3Days;
        uint256 slot4Days;
        uint256 slot5Days;
        uint256 slot6Days;
    }

    struct SlotDaysFeeInfo {
        uint256 feeBeforeDaysSlot1;
        uint256 feeBeforeDaysSlot2;
        uint256 feeBeforeDaysSlot3;
        uint256 feeBeforeDaysSlot4;
        uint256 feeBeforeDaysSlot5;
        uint256 feeBeforeDaysSlot6;
    }

    struct SlotDaysRewardInfo {
        uint256 rewardAfterDaysSlot1;
        uint256 rewardAfterDaysSlot2;
        uint256 rewardAfterDaysSlot3;
        uint256 rewardAfterDaysSlot4;
        uint256 rewardAfterDaysSlot5;
        uint256 rewardAfterDaysSlot6;
    }

    struct HoldStruct {
        uint256 start_hold_timestamp;
        uint256 last_daily_reward_timestamp;
        uint256 interestPaid;
        uint256 daysRewarded;
        bool slot1Rewarded;
        bool slot2Rewarded;
        bool slot3Rewarded;
        bool slot4Rewarded;
        bool slot5Rewarded;
        bool slot6Rewarded;
    }

    struct HoldStructCore {
        bool isCoreHolder;
        uint256 last_transfer_timestamp;
        uint256 amount10percent;
        uint256 amount25percent;
        uint256 amount75percent;
        uint256 amountTotal;
    }

    struct RewardInfo {
        uint256 rewardAfterSlot1;
        uint256 rewardAfterSlot2;
        uint256 rewardAfterSlot3;
        uint256 rewardAfterSlot4;
        uint256 rewardAfterSlot5;
        uint256 rewardAfterSlot6;
    }

    struct RewardArrayInfo {
        address[] afterSlot1days;
        address[] afterSlot2days;
        address[] afterSlot3days;
        address[] afterSlot4days;
        address[] afterSlot5days;
        address[] afterSlot6days;
    }

    struct TotalHoldingAmountOfSlotsInfo {
        uint256 totalHoldingAmountAfterSlot1;
        uint256 totalHoldingAmountAfterSlot2;
        uint256 totalHoldingAmountAfterSlot3;
        uint256 totalHoldingAmountAfterSlot4;
        uint256 totalHoldingAmountAfterSlot5;
        uint256 totalHoldingAmountAfterSlot6;
    }

    struct WithdrawInfo {
        address WithdrawerAddress;
        uint256 allowedPercentage;
        uint256 lastWithdrawTime;
    }

    struct MultiSign {
        address callerToBeSet;
        address developmentWithdrawerToBeSet;
        address marketingWithdrawerToBeSet;
        address legalAndBackupWithdrawerToBeSet;
        address[] voters;
        mapping(address => bool) isVoter;
        mapping(address => bool) isVoted;
        uint256 voteCount;
        uint256 voteFavour;
        uint256 voteAgainst;
        uint256 voteNeeded;
        uint256 proposalCreationTime;
        bool isSucceeded;
    }

    event IsDexSet(address _address, bool _value);

    constructor(
        address _development_address,
        address _legal_and_backup_address,
        address _marketing_address,
        address _prime_holders_address,
        address _core_holders_address,
        address _development_withdrawer_address,
        address _legal_and_backup_withdrawer_address,
        address _marketing_withdrawer_address,
        address _caller,
        address[] memory _voters
    ) ERC20("HELPER COIN", "HLPR") {
        if (
            _development_address == address(0) ||
            _legal_and_backup_address == address(0) ||
            _marketing_address == address(0) ||
            _prime_holders_address == address(0) ||
            _core_holders_address == address(0) ||
            _development_withdrawer_address == address(0) ||
            _legal_and_backup_withdrawer_address == address(0) ||
            _marketing_withdrawer_address == address(0) ||
            _caller == address(0)
        ) {
            revert AddressZeroNotAllowed();
        }

        _mint(msg.sender, (75 * initialTotalSupply) / 100);
        _mint(_core_holders_address, (25 * initialTotalSupply) / 100);

        holdersArray.push(msg.sender);
        holdersMap[msg.sender].start_hold_timestamp = block.timestamp;
        _isExemptFromFee[msg.sender] = true;
        _isExemptFromReward[msg.sender] = true;

        development_address = _development_address;
        holdersArray.push(_development_address);
        holdersMap[_development_address].start_hold_timestamp = block.timestamp;
        _isExemptFromFee[_development_address] = true;
        _isExemptFromReward[_development_address] = true;

        legal_and_backup_address = _legal_and_backup_address;
        holdersArray.push(_legal_and_backup_address);
        holdersMap[_legal_and_backup_address].start_hold_timestamp = block.timestamp;
        _isExemptFromFee[_legal_and_backup_address] = true;
        _isExemptFromReward[_legal_and_backup_address] = true;

        marketing_address = _marketing_address;
        holdersArray.push(_marketing_address);
        holdersMap[_marketing_address].start_hold_timestamp = block.timestamp;
        _isExemptFromFee[_marketing_address] = true;
        _isExemptFromReward[_marketing_address] = true;

        prime_holders_address = _prime_holders_address;
        holdersArray.push(_prime_holders_address);
        holdersMap[_prime_holders_address].start_hold_timestamp = block.timestamp;
        _isExemptFromFee[_prime_holders_address] = true;
        _isExemptFromReward[_prime_holders_address] = true;

        core_holders_address = _core_holders_address;
        holdersArray.push(_core_holders_address);
        holdersMap[_core_holders_address].start_hold_timestamp = block.timestamp;
        _isExemptFromFee[_core_holders_address] = true;
        _isExemptFromReward[_core_holders_address] = true;

        slotDaysInfo = SlotDaysInfo(120 days, 240 days, 360 days, 480 days, 600 days, 720 days);
        // slotDaysInfo = SlotDaysInfo(3600, 7200, 10800, 14400, 18000, 21600);

        slotDaysFeeInfo = SlotDaysFeeInfo(3500, 3500, 3000, 2000, 1000, 500);

        slotDaysFeeInfoDex = SlotDaysFeeInfo(3200, 3200, 3000, 2000, 1000, 500);

        slotDaysRewardInfo = SlotDaysRewardInfo(500, 1000, 1500, 2000, 2250, 2750);

        developmentWithdrawInfo = WithdrawInfo(_development_withdrawer_address, 200, 0);
        // developmentWithdrawInfo = WithdrawInfo(_development_withdrawer_address, 200, 3600);
        _isExemptFromFee[_development_withdrawer_address] = true;
        _isExemptFromReward[_development_withdrawer_address] = true;

        legalAndBackupWithdrawInfo = WithdrawInfo(_legal_and_backup_withdrawer_address, 200, 0);
        // legalAndBackupWithdrawInfo = WithdrawInfo(_legal_and_backup_withdrawer_address, 200, 3600);
        _isExemptFromFee[_legal_and_backup_withdrawer_address] = true;
        _isExemptFromReward[_legal_and_backup_withdrawer_address] = true;

        marketingWithdrawInfo = WithdrawInfo(_marketing_withdrawer_address, 200, 0);
        // marketingWithdrawInfo = WithdrawInfo(_marketing_withdrawer_address, 200, 3600);
        _isExemptFromFee[_marketing_withdrawer_address] = true;
        _isExemptFromReward[_marketing_withdrawer_address] = true;

        dailyRewardRate = 30;
        burnFee = 100;
        transferFee = 100;

        caller = _caller;
        _isExemptFromFee[_caller] = true;
        _isExemptFromReward[_caller] = true;

        for (uint256 i = 0; i < _voters.length; i++) {
            if (_voters[i] == address(0)) {
                revert AddressZeroNotAllowed();
            }
            multiSignInfo.voters.push(_voters[i]);
            multiSignInfo.isVoter[_voters[i]] = true;
        }

        multiSignInfo.voteNeeded = (_voters.length * 3) / 5;
    }

    modifier onlyCaller() {
        if (msg.sender != caller) {
            revert NotAuthorised();
        }
        _;
    }

    modifier onlyWithdrawer(
        WithdrawInfo storage _withdrawInfo,
        address _to,
        uint256 _withdrawAmount,
        address _fundAddress
    ) {
        uint256 curFundBalance = _balances[_fundAddress];

        if (
            msg.sender != _withdrawInfo.WithdrawerAddress || _to == _withdrawInfo.WithdrawerAddress
        ) {
            revert NotAuthorised();
        }

        if (_withdrawInfo.lastWithdrawTime + 30 days > block.timestamp) {
            revert RequiredTimeNotElapsed();
        }
        if (_withdrawAmount > (curFundBalance * _withdrawInfo.allowedPercentage) / denominator) {
            revert AmountNotAuthorised();
        }

        _withdrawInfo.lastWithdrawTime = block.timestamp;
        _;
    }

    modifier onlyMultiSign() {
        if (!multiSignInfo.isVoter[msg.sender]) {
            revert NotAuthorised();
        }
        _;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (holdersMapCore[to].isCoreHolder) {
            revert TransferNotAllowed();
        }

        if (
            msg.sender == development_address ||
            msg.sender == legal_and_backup_address ||
            msg.sender == marketing_address ||
            msg.sender == prime_holders_address ||
            msg.sender == core_holders_address
        ) {
            revert NotAuthorised();
        }

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        if (holdersMapCore[from].isCoreHolder) {
            HoldStructCore memory _holdStructCore = holdersMapCore[from];
            uint256 daysFromLastTransfer = block.timestamp -
                _holdStructCore.last_transfer_timestamp;

            if (amount <= _holdStructCore.amount25percent) {
                holdersMapCore[from].amount25percent -= amount;
                holdersMapCore[from].last_transfer_timestamp = block.timestamp;
            } else if (amount <= _holdStructCore.amount10percent) {
                if (daysFromLastTransfer > 30 days) {
                    uint256 toBeRemovedFromAmount75percent;

                    if (_holdStructCore.amount25percent > 0) {
                        toBeRemovedFromAmount75percent = amount - _holdStructCore.amount25percent;
                        holdersMapCore[from].amount25percent = 0;
                    } else {
                        toBeRemovedFromAmount75percent = amount;
                    }

                    holdersMapCore[from].amount75percent -= toBeRemovedFromAmount75percent;
                    holdersMapCore[from].last_transfer_timestamp = block.timestamp;
                } else {
                    revert WaitPeriodNotElapsed();
                }
            } else {
                revert TransferLimitReached();
            }
        }

        HoldStruct memory _holdStruct = holdersMap[to];

        if (
            _holdStruct.start_hold_timestamp == 0 &&
            _holdStruct.last_daily_reward_timestamp == 0 &&
            amount > 0
        ) {
            holdersArray.push(to);
            holdersMap[to].start_hold_timestamp = block.timestamp;
            holdersMap[to].last_daily_reward_timestamp = block.timestamp;
        } else if (_balances[to] == 0 && amount > 0) {
            holdersMap[to].start_hold_timestamp = block.timestamp;
            holdersMap[to].last_daily_reward_timestamp = block.timestamp;
        }

        uint256 holdTime = block.timestamp - holdersMap[from].start_hold_timestamp;
        uint256 sell_fee;
        uint256 transfer_fee;
        uint256 burn_fee;

        if (!_isExemptFromFee[from]) {
            if (shouldTakeSellFee) {
                SlotDaysInfo memory _slotDaysInfo = slotDaysInfo;
                SlotDaysFeeInfo memory _slotDaysFeeInfo = slotDaysFeeInfo;

                if (_isDex[to]) {
                    _slotDaysFeeInfo = slotDaysFeeInfoDex;
                }
                if (holdTime < _slotDaysInfo.slot1Days) {
                    sell_fee = (amount * _slotDaysFeeInfo.feeBeforeDaysSlot1) / denominator;
                } else if (holdTime < _slotDaysInfo.slot2Days) {
                    sell_fee = (amount * _slotDaysFeeInfo.feeBeforeDaysSlot2) / denominator;
                } else if (holdTime < _slotDaysInfo.slot3Days) {
                    sell_fee = (amount * _slotDaysFeeInfo.feeBeforeDaysSlot3) / denominator;
                } else if (holdTime < _slotDaysInfo.slot4Days) {
                    sell_fee = (amount * _slotDaysFeeInfo.feeBeforeDaysSlot4) / denominator;
                } else if (holdTime < _slotDaysInfo.slot5Days) {
                    sell_fee = (amount * _slotDaysFeeInfo.feeBeforeDaysSlot5) / denominator;
                } else if (holdTime < _slotDaysInfo.slot6Days) {
                    sell_fee = (amount * _slotDaysFeeInfo.feeBeforeDaysSlot6) / denominator;
                } else {
                    sell_fee = 0;
                }
            }

            if (shouldBurn) {
                burn_fee = (amount * burnFee) / denominator;

                uint256 prevTotalSupply = _totalSupply;

                _totalSupply -= burn_fee;

                uint256 currentTotalSupply = _totalSupply;

                if (
                    prevTotalSupply > minTotalSupplyForStopBurn &&
                    currentTotalSupply <= minTotalSupplyForStopBurn
                ) {
                    shouldBurn = false;
                }
            }

            if (shouldChargeTransfer) {
                transfer_fee = (amount * transferFee) / denominator;
            }

            uint256 totalDistribution = sell_fee / 4;

            _balances[development_address] += totalDistribution;
            emit Transfer(from, development_address, totalDistribution);

            _balances[legal_and_backup_address] += (totalDistribution + transfer_fee);
            emit Transfer(from, legal_and_backup_address, totalDistribution + transfer_fee);

            _balances[marketing_address] += totalDistribution;
            emit Transfer(from, marketing_address, totalDistribution);

            _balances[prime_holders_address] += totalDistribution;
            emit Transfer(from, prime_holders_address, totalDistribution);
        }

        uint256 transferAmount = amount - sell_fee - transfer_fee - burn_fee;

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += transferAmount;
        }

        emit Transfer(from, to, transferAmount);

        _afterTokenTransfer(from, to, transferAmount);
    }

    /**
     * @dev this rewards the prime holders from the prime holders' balance.
     */
    function rewardPrimeHolders() external onlyCaller {
        uint256 _prime_holders_balance = _balances[prime_holders_address];

        if (_prime_holders_balance == 0) {
            revert RewardBalanceZero();
        }

        address[] memory _holdersArray = holdersArray;
        uint256 holdersArrayLength = _holdersArray.length;
        uint256 _numberDays;

        RewardArrayInfo memory reward_array_info;
        RewardInfo memory reward_info;
        HoldStruct memory _holderStruct;
        SlotDaysInfo memory _slotDaysInfo = slotDaysInfo;
        SlotDaysRewardInfo memory _slotDaysRewardInfo = slotDaysRewardInfo;
        TotalHoldingAmountOfSlotsInfo memory total_holding_amount_of_slots_info;
        uint256[] memory balanceInfo = new uint256[](holdersArrayLength);

        reward_info = RewardInfo(
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot1) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot2) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot3) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot4) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot5) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot6) / denominator
        );

        reward_array_info = RewardArrayInfo(
            new address[](holdersArrayLength),
            new address[](holdersArrayLength),
            new address[](holdersArrayLength),
            new address[](holdersArrayLength),
            new address[](holdersArrayLength),
            new address[](holdersArrayLength)
        );

        for (uint256 i; i < holdersArrayLength; i++) {
            balanceInfo[i] = _balances[_holdersArray[i]];
            if (_isExemptFromReward[_holdersArray[i]] || balanceInfo[i] < minBalanceForReward) {
                continue;
            }
            _holderStruct = holdersMap[_holdersArray[i]];
            _numberDays = block.timestamp - _holderStruct.start_hold_timestamp;

            if (_numberDays < _slotDaysInfo.slot1Days) {
                // Not distributing reward if the user hasn't even completed slot1 days
            } else if (_numberDays < _slotDaysInfo.slot2Days && !_holderStruct.slot1Rewarded) {
                reward_array_info.afterSlot1days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot1 += balanceInfo[i];
            } else if (_numberDays < _slotDaysInfo.slot3Days && !_holderStruct.slot2Rewarded) {
                reward_array_info.afterSlot2days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot2 += balanceInfo[i];
            } else if (_numberDays < _slotDaysInfo.slot4Days && !_holderStruct.slot3Rewarded) {
                reward_array_info.afterSlot3days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot3 += balanceInfo[i];
            } else if (_numberDays < _slotDaysInfo.slot5Days && !_holderStruct.slot4Rewarded) {
                reward_array_info.afterSlot4days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot4 += balanceInfo[i];
            } else if (_numberDays < _slotDaysInfo.slot6Days && !_holderStruct.slot5Rewarded) {
                reward_array_info.afterSlot5days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot5 += balanceInfo[i];
            } else if (_numberDays >= _slotDaysInfo.slot6Days && !_holderStruct.slot6Rewarded) {
                reward_array_info.afterSlot6days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot6 += balanceInfo[i];
            }
        }

        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot1 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot1;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot2 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot2;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot3 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot3;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot4 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot4;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot5 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot5;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot6 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot6;
        }

        for (uint256 i; i < holdersArrayLength; i++) {
            if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot1 != 0 &&
                reward_array_info.afterSlot1days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot1days[i]].slot1Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot1days[i],
                    ((reward_info.rewardAfterSlot1 * balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot1)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot2 != 0 &&
                reward_array_info.afterSlot2days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot2days[i]].slot2Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot2days[i],
                    ((reward_info.rewardAfterSlot2 * balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot2)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot3 != 0 &&
                reward_array_info.afterSlot3days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot3days[i]].slot3Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot3days[i],
                    ((reward_info.rewardAfterSlot3 * balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot3)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot4 != 0 &&
                reward_array_info.afterSlot4days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot4days[i]].slot4Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot4days[i],
                    ((reward_info.rewardAfterSlot4 * balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot4)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot5 != 0 &&
                reward_array_info.afterSlot5days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot5days[i]].slot5Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot5days[i],
                    ((reward_info.rewardAfterSlot5 * balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot5)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot6 != 0 &&
                reward_array_info.afterSlot6days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot6days[i]].slot6Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot6days[i],
                    ((reward_info.rewardAfterSlot6 * balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot6)
                );
            }
        }
    }

    /**
     * @dev this rewards the prime holders from the prime holders' balance with manual array inputs.
     */
    function rewardPrimeHoldersWithInput(
        address[][] calldata _rewardArrayInfo,
        uint256[] calldata _totalHoldingAmountOfSlotsInfo,
        uint256[] calldata _balanceInfo
    ) external onlyCaller {
        uint256 reqLen = _rewardArrayInfo[0].length;
        if (
            _totalHoldingAmountOfSlotsInfo.length != 6 ||
            _rewardArrayInfo.length != 6 ||
            _rewardArrayInfo[1].length != reqLen ||
            _rewardArrayInfo[2].length != reqLen ||
            _rewardArrayInfo[3].length != reqLen ||
            _rewardArrayInfo[4].length != reqLen ||
            _rewardArrayInfo[5].length != reqLen
        ) {
            revert InvalidLength();
        }

        uint256 _prime_holders_balance = _balances[prime_holders_address];

        if (_prime_holders_balance == 0) {
            revert RewardBalanceZero();
        }

        RewardArrayInfo memory reward_array_info;
        RewardInfo memory reward_info;
        SlotDaysRewardInfo memory _slotDaysRewardInfo = slotDaysRewardInfo;
        TotalHoldingAmountOfSlotsInfo memory total_holding_amount_of_slots_info;

        reward_info = RewardInfo(
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot1) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot2) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot3) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot4) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot5) / denominator,
            (_prime_holders_balance * _slotDaysRewardInfo.rewardAfterDaysSlot6) / denominator
        );

        reward_array_info = RewardArrayInfo(
            _rewardArrayInfo[0],
            _rewardArrayInfo[1],
            _rewardArrayInfo[2],
            _rewardArrayInfo[3],
            _rewardArrayInfo[4],
            _rewardArrayInfo[5]
        );

        total_holding_amount_of_slots_info = TotalHoldingAmountOfSlotsInfo(
            _totalHoldingAmountOfSlotsInfo[0],
            _totalHoldingAmountOfSlotsInfo[1],
            _totalHoldingAmountOfSlotsInfo[2],
            _totalHoldingAmountOfSlotsInfo[3],
            _totalHoldingAmountOfSlotsInfo[4],
            _totalHoldingAmountOfSlotsInfo[5]
        );

        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot1 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot1;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot2 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot2;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot3 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot3;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot4 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot4;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot5 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot5;
        }
        if (total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot6 != 0) {
            _balances[prime_holders_address] -= reward_info.rewardAfterSlot6;
        }

        for (uint256 i; i < reqLen; i++) {
            if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot1 != 0 &&
                reward_array_info.afterSlot1days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot1days[i]].slot1Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot1days[i],
                    ((reward_info.rewardAfterSlot1 * _balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot1)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot2 != 0 &&
                reward_array_info.afterSlot2days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot2days[i]].slot2Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot2days[i],
                    ((reward_info.rewardAfterSlot2 * _balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot2)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot3 != 0 &&
                reward_array_info.afterSlot3days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot3days[i]].slot3Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot3days[i],
                    ((reward_info.rewardAfterSlot3 * _balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot3)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot4 != 0 &&
                reward_array_info.afterSlot4days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot4days[i]].slot4Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot4days[i],
                    ((reward_info.rewardAfterSlot4 * _balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot4)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot5 != 0 &&
                reward_array_info.afterSlot5days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot5days[i]].slot5Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot5days[i],
                    ((reward_info.rewardAfterSlot5 * _balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot5)
                );
            } else if (
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot6 != 0 &&
                reward_array_info.afterSlot6days[i] != address(0)
            ) {
                holdersMap[reward_array_info.afterSlot6days[i]].slot6Rewarded = true;
                _distribute(
                    reward_array_info.afterSlot6days[i],
                    ((reward_info.rewardAfterSlot6 * _balanceInfo[i]) /
                        total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot6)
                );
            }
        }
    }

    function _distribute(address _to, uint256 _amount) private {
        // No need for zero address check as this check has already been done before calling this function
        _balances[_to] += _amount;
        emit Transfer(prime_holders_address, _to, _amount);
    }

    /**
     * @dev this rewards users on a daily basis by minting new tokens.
     */
    function rewardUsersDaily(uint256 _toBeDistributed) external onlyCaller {
        address[] memory _holdersArray = holdersArray;
        uint256 holdersArrayLength = _holdersArray.length;

        if (_toBeDistributed == 0) {
            _toBeDistributed = holdersArrayLength;
        }

        uint256 _dailyRewardRate = dailyRewardRate;

        uint256 _last_daily_reward_timestamp;

        uint256 _daily_reward_days;

        uint256 _daily_reward_amount;

        uint256 _numberDaysHold;

        uint256 _principalForReward;

        uint256 _curBalance;

        uint256 totalSupply = _totalSupply;

        SlotDaysInfo memory _slotDaysInfo = slotDaysInfo;
        HoldStruct memory _holdStruct;

        for (uint256 i; i < holdersArrayLength; i++) {
            _holdStruct = holdersMap[_holdersArray[i]];
            _numberDaysHold = block.timestamp - _holdStruct.start_hold_timestamp;
            _curBalance = _balances[_holdersArray[i]];

            _principalForReward = _curBalance >= _holdStruct.interestPaid
                ? (_curBalance - _holdStruct.interestPaid)
                : 0;

            _last_daily_reward_timestamp = _holdStruct.last_daily_reward_timestamp;

            _daily_reward_days = (block.timestamp - _last_daily_reward_timestamp) / (1 days);

            if (
                // _curBalance < minBalanceForReward ||
                _daily_reward_days == 0 ||
                _principalForReward == 0 ||
                _holdStruct.daysRewarded >= _slotDaysInfo.slot6Days ||
                _numberDaysHold > _slotDaysInfo.slot6Days ||
                _isExemptFromReward[_holdersArray[i]]
            ) {
                // whenever a holder's balance change from 0 to some value, we update his start_hold_timestamp and last_daily_reward_timestamp in _transfer function so no need to do it here again.
                continue;
            }

            _daily_reward_amount =
                (_principalForReward * _dailyRewardRate * _daily_reward_days) /
                denominator;

            if (totalSupply + _daily_reward_amount <= maxTotalSupply) {
                _totalSupply += _daily_reward_amount;

                holdersMap[_holdersArray[i]]
                    .last_daily_reward_timestamp = (_last_daily_reward_timestamp +
                    (_daily_reward_days * 1 days));

                holdersMap[_holdersArray[i]].interestPaid += _daily_reward_amount;
                holdersMap[_holdersArray[i]].daysRewarded += _daily_reward_days;

                _balances[_holdersArray[i]] += _daily_reward_amount;

                emit Transfer(address(0), _holdersArray[i], _daily_reward_amount);

                _toBeDistributed -= 1;

                if (_toBeDistributed == 0) {
                    break;
                }
            } else {
                shouldBurn = true;
                shouldChargeTransfer = true;
                break;
            }
        }
    }

    /**
     * @dev set an address a DEX.
     */
    function setIsDex(address _address, bool _value) external onlyCaller {
        if (_isDex[_address] == _value) {
            revert AlreadySet();
        }
        _isDex[_address] = _value;
        _isExemptFromFee[_address] = _value;
        _isExemptFromReward[_address] = _value;

        emit IsDexSet(_address, _value);
    }

    /**
     * @dev returns the holders array
     */
    function getHoldersArray() external view returns (address[] memory) {
        return holdersArray;
    }

    /**
     * @dev returns the core holders array
     */
    function getCoreHoldersArray() external view returns (address[] memory) {
        return holdersArrayCore;
    }

    /**
     * @dev returns the data for manual reward inputs for the rewardPrimeHoldersWithInput function
     */
    function filterUsers()
        external
        view
        returns (
            RewardArrayInfo memory,
            TotalHoldingAmountOfSlotsInfo memory,
            uint256[] memory
        )
    {
        uint256 _prime_holders_balance = _balances[prime_holders_address];

        if (_prime_holders_balance == 0) {
            revert RewardBalanceZero();
        }

        address[] memory _holdersArray = holdersArray;
        uint256 holdersArrayLength = holdersArray.length;
        uint256 _numberDays;

        RewardArrayInfo memory reward_array_info;
        HoldStruct memory _holderStruct;
        SlotDaysInfo memory _slotDaysInfo = slotDaysInfo;

        TotalHoldingAmountOfSlotsInfo memory total_holding_amount_of_slots_info;
        uint256[] memory balanceInfo = new uint256[](holdersArrayLength);

        reward_array_info = RewardArrayInfo(
            new address[](holdersArrayLength),
            new address[](holdersArrayLength),
            new address[](holdersArrayLength),
            new address[](holdersArrayLength),
            new address[](holdersArrayLength),
            new address[](holdersArrayLength)
        );

        for (uint256 i; i < holdersArrayLength; i++) {
            balanceInfo[i] = _balances[_holdersArray[i]];
            if (_isExemptFromReward[_holdersArray[i]] || balanceInfo[i] < minBalanceForReward) {
                continue;
            }
            _holderStruct = holdersMap[_holdersArray[i]];
            _numberDays = block.timestamp - _holderStruct.start_hold_timestamp;

            if (_numberDays < _slotDaysInfo.slot1Days) {
                // Not distributing reward if the user hasn't even completed slot1 days
            } else if (_numberDays < _slotDaysInfo.slot2Days && !_holderStruct.slot1Rewarded) {
                reward_array_info.afterSlot1days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot1 += balanceInfo[i];
            } else if (_numberDays < _slotDaysInfo.slot3Days && !_holderStruct.slot2Rewarded) {
                reward_array_info.afterSlot2days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot2 += balanceInfo[i];
            } else if (_numberDays < _slotDaysInfo.slot4Days && !_holderStruct.slot3Rewarded) {
                reward_array_info.afterSlot3days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot3 += balanceInfo[i];
            } else if (_numberDays < _slotDaysInfo.slot5Days && !_holderStruct.slot4Rewarded) {
                reward_array_info.afterSlot4days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot4 += balanceInfo[i];
            } else if (_numberDays < _slotDaysInfo.slot6Days && !_holderStruct.slot5Rewarded) {
                reward_array_info.afterSlot5days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot5 += balanceInfo[i];
            } else if (_numberDays >= _slotDaysInfo.slot6Days && !_holderStruct.slot6Rewarded) {
                reward_array_info.afterSlot6days[i] = _holdersArray[i];
                total_holding_amount_of_slots_info.totalHoldingAmountAfterSlot6 += balanceInfo[i];
            }
        }

        return (reward_array_info, total_holding_amount_of_slots_info, balanceInfo);
    }

    /**
     * @dev get Developement Balance.
     */
    function getDevelopmentBalance() external view returns (uint256) {
        return _balances[development_address];
    }

    /**
     * @dev get Marketing Balance.
     */
    function getMarketingBalance() external view returns (uint256) {
        return _balances[marketing_address];
    }

    /**
     * @dev get LegalAndBackup Balance.
     */
    function getLegalAndBackupBalance() external view returns (uint256) {
        return _balances[legal_and_backup_address];
    }

    /**
     * @dev get Prime Holders' Balance.
     */
    function getPrimeHoldersBalance() external view returns (uint256) {
        return _balances[prime_holders_address];
    }

    /**
     * @dev get Core Holders' Balance.
     */
    function getCoreHoldersBalance() external view returns (uint256) {
        return _balances[core_holders_address];
    }

    /**
     * @dev withdraw Developement balance with amount equal to _amount, recipient is the _to address.
     */
    function withdrawDevelopmentBalance(address _to, uint256 _amount)
        external
        onlyWithdrawer(developmentWithdrawInfo, _to, _amount, development_address)
    {
        _withdrawBalance(development_address, _to, _amount);
    }

    /**
     * @dev withdraw Marketing balance with amount equal to _amount, recipient is the _to address.
     */
    function withdrawMarketingBalance(address _to, uint256 _amount)
        external
        onlyWithdrawer(marketingWithdrawInfo, _to, _amount, marketing_address)
    {
        _withdrawBalance(marketing_address, _to, _amount);
    }

    /**
     * @dev withdraw LegalAndBackup balance with amount equal to _amount, recipient is the _to address.
     */
    function withdrawLegalAndBackupBalance(address _to, uint256 _amount)
        external
        onlyWithdrawer(legalAndBackupWithdrawInfo, _to, _amount, legal_and_backup_address)
    {
        _withdrawBalance(legal_and_backup_address, _to, _amount);
    }

    /**
     * @dev helper withdraw function for the above three functions.
     */
    function _withdrawBalance(
        address _from,
        address _to,
        uint256 _amount
    ) private {
        _transfer(_from, _to, _amount);
        _isExemptFromFee[_to] = true;
        _isExemptFromReward[_to] = true;
    }

    /**
     * @dev distribute Prime Holders' reward manually in case of block gas limit exceeds with amount equal to _amount, recipient is the _to address.
     */
    function distributePrimeHoldersRewardManually(
        address _to,
        uint256 _amount,
        uint256 _slotsRewarded
    ) external onlyCaller {
        if (_slotsRewarded < 1 && _slotsRewarded > 6) {
            revert InvalidSlot();
        }
        if (_to == address(0)) {
            revert AddressZeroNotAllowed();
        }

        if (_slotsRewarded == 1) {
            holdersMap[_to].slot1Rewarded = true;
        } else if (_slotsRewarded == 2) {
            holdersMap[_to].slot2Rewarded = true;
        } else if (_slotsRewarded == 3) {
            holdersMap[_to].slot3Rewarded = true;
        } else if (_slotsRewarded == 4) {
            holdersMap[_to].slot4Rewarded = true;
        } else if (_slotsRewarded == 5) {
            holdersMap[_to].slot5Rewarded = true;
        } else if (_slotsRewarded == 6) {
            holdersMap[_to].slot6Rewarded = true;
        }

        _transfer(prime_holders_address, _to, _amount);
    }

    /**
     * @dev this function is used for initial private sale, caller can send some amount of tokens from core holders fund to the address of initial core investors after than that address will be blocked to receive any other tokens
     */
    function preSale(address _to, uint256 _amount) external onlyCaller {
        if (holdersMapCore[_to].isCoreHolder || _balances[_to] > 0) {
            revert TransferNotAllowed();
        }

        if (_balances[core_holders_address] < _amount) {
            revert NotEnoughFund();
        }

        _transfer(core_holders_address, _to, _amount);
        _isExemptFromFee[_to] = true;
        _isExemptFromReward[_to] = true;

        holdersArrayCore.push(_to);

        if (holdersMapCore[_to].last_transfer_timestamp == 0) {
            holdersMapCore[_to].last_transfer_timestamp = block.timestamp;
        }

        holdersMapCore[_to].isCoreHolder = true;
        holdersMapCore[_to].amount10percent = (_amount * 10) / 100;
        holdersMapCore[_to].amount25percent = (_amount * 25) / 100;
        holdersMapCore[_to].amount75percent = (_amount * 75) / 100;
        holdersMapCore[_to].amountTotal = _amount;
    }

    /**
     * @dev This function is used to create a proposal to change 4 authorities addresses in case of compromisation of any of the 4 addresses. only voters in the multiSignInfo variable can call this function.
     */
    function setAuthProposalByMultiSign(
        address _caller,
        address _developmentWithdrawer,
        address _marketingWithdrawer,
        address _legalAndBackupWithdrawer
    ) public onlyMultiSign {
        if (block.timestamp < multiSignInfo.proposalCreationTime + 1 days) {
            revert RequiredTimeNotElapsed();
        }
        multiSignInfo.callerToBeSet = _caller;
        multiSignInfo.developmentWithdrawerToBeSet = _developmentWithdrawer;
        multiSignInfo.marketingWithdrawerToBeSet = _marketingWithdrawer;
        multiSignInfo.legalAndBackupWithdrawerToBeSet = _legalAndBackupWithdrawer;
        multiSignInfo.proposalCreationTime = block.timestamp;
    }

    /**
     * @dev This function is used to vote on the current proposal to change 4 authorities addresses in case of compromisation of any of the 4 addresses. only voters in the multiSignInfo variable can call this function. if input to the function is 1 then the vote counts in favour and if its 0 it count as against.
     */
    function voteOnCurrentProposalByMultiSign(uint256 _vote) public onlyMultiSign {
        if (_vote > 1 || _vote < 0) {
            revert InvalidData();
        }
        if (multiSignInfo.isVoted[msg.sender]) {
            revert AlreadyVoted();
        }

        multiSignInfo.isVoted[msg.sender] = true;
        multiSignInfo.voteCount += 1;

        if (_vote == 1) {
            multiSignInfo.voteFavour += 1;
        } else {
            multiSignInfo.voteAgainst += 1;
        }
    }

    /**
     * @dev This function is used to execute the current proposal if it has been successful to change 4 authorities addresses in case of compromisation of any of the 4 addresses. only voters in the multiSignInfo variable can call this function.
     */
    function executeCurrentProposalByMultiSign() public onlyMultiSign {
        if (multiSignInfo.voteFavour < multiSignInfo.voteNeeded) {
            revert ProposalNotSucceeded();
        }

        caller = multiSignInfo.callerToBeSet;
        developmentWithdrawInfo.WithdrawerAddress = multiSignInfo.developmentWithdrawerToBeSet;
        marketingWithdrawInfo.WithdrawerAddress = multiSignInfo.marketingWithdrawerToBeSet;
        legalAndBackupWithdrawInfo.WithdrawerAddress = multiSignInfo
            .legalAndBackupWithdrawerToBeSet;

        delete multiSignInfo;
    }
}
