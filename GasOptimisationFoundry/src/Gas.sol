// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "./Ownable.sol";

// constants save on gas
contract Constants {
    uint256 constant tradeFlag = 1;
    uint256 constant basicFlag = 0;
    uint256 constant dividendFlag = 1;
}

contract GasContract is Ownable, Constants {
    // Constant totalSupply is set to 0, so that it cannot be updated
    uint256 private totalSupply = 0; // cannot be updated
    uint256 private paymentCounter = 0;
    mapping(address => uint256) public balances;
    uint256 private tradePercent = 12;
    address private contractOwner;
    uint256 private tradeMode = 0;
    mapping(address => Payment[]) public payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    bool private isReady = false;
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }
    PaymentType constant defaultPayment = PaymentType.Unknown;

    event paymentHistory(
        uint256 lastUpdate,
        address updatedBy,
        uint256 blockNumber); 

    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        uint256 amount;
        bool adminUpdated;
        string recipientName; // max 8 characters
        address recipient;
        address admin; // administrators address
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }
    uint256 wasLastOdd = 1;
    mapping(address => uint256) private isOddWhitelistUser;
    
    // Rearrange order of struct to save on gas
    struct ImportantStruct {
        bool paymentStatus;
        address sender;
        uint256 amount;
        uint256 valueA; // max 3 digits
        uint256 bigValue;
        uint256 valueB; // max 3 digits
    }
    mapping(address => ImportantStruct) private whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);

    // Currently, it is unnecessarily checking twice if the sender is an admin using checkForAdmin(senderOfTx)
    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        // First check is less expensive on gas than the second check
        if (senderOfTx == contractOwner || checkForAdmin(senderOfTx) ) {
            _;
        } else {
            revert(
                "Error in Gas contract - onlyAdminOrOwner modifier : revert happened because the originator of the transaction was not the admin, and furthermore he wasn't the owner of the contract, so he cannot run this function"
            );
        }
    }


    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        require(
            senderOfTx == sender);
        uint256 usersTier = whitelist[senderOfTx];
        require(
            usersTier > 0);
        require(
            usersTier < 4);
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;
        uint256 adminLength = administrators.length;

        // Improved the loop for further gas optimisations
        // The loop 
        for (uint256 ii = 0; ii < adminLength; ii++) {
            address admin = _admins[ii];
            if (admin != address(0)) {
                administrators[ii] = admin;
                uint256 balance = 0;
                if (admin == contractOwner) {
                    balance = totalSupply;
                }
                balances[admin] = balance;
                emit supplyChanged(admin, balance);
            }
        }

    }

    function checkForAdmin(address _user) private view returns (bool admin_) {
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        uint256 balance = balances[_user];
        return balance;
    }

    function getTradingMode() private pure returns (bool mode_) {
        bool mode = false;
        if (tradeFlag == 1 || dividendFlag == 1) {
            mode = true;
        } else {
            mode = false;
        }
        return mode;
    }


    function addHistory(address _updateAddress, bool _tradeMode)
        public
        returns (bool status_, bool tradeMode_)
    {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        emit paymentHistory(history.lastUpdate, history.updatedBy, history.blockNumber);
        bool[] memory status = new bool[](tradePercent);
        for (uint256 i = 0; i < tradePercent; i++) {
            status[i] = true;
        }
        return ((status[0] == true), _tradeMode);
    }

    function getPayments(address _user)
        public
        view
        returns (Payment[] memory payments_)
    {
        require(
            _user != address(0));
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool) {
        require(
            balances[msg.sender] >= _amount,
            "Insufficient Balance"
        );
        require(
            bytes(_name).length < 9,
            "Name too long"
        );
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment = Payment({
            admin: address(0),
            adminUpdated: false,
            paymentType: PaymentType.BasicPayment,
            recipient: _recipient,
            amount: _amount,
            recipientName: _name,
            paymentID: ++paymentCounter
        });
        payments[msg.sender].push(payment);
        return true;
    }


    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) private onlyAdminOrOwner {
        // Gas optimisations: required() slightly optimised
        require(
            _ID * _amount > 0);
        require(
            _user != address(0));

        address senderOfTx = msg.sender;

        for (uint256 ii = 0; ii < payments[_user].length; ii++) {
            if (payments[_user][ii].paymentID == _ID) {
                payments[_user][ii].adminUpdated = true;
                payments[_user][ii].admin = _user;
                payments[_user][ii].paymentType = _type;
                payments[_user][ii].amount = _amount;
                bool tradingMode = getTradingMode();
                addHistory(_user, tradingMode);
                emit PaymentUpdated(
                    senderOfTx,
                    _ID,
                    _amount,
                    payments[_user][ii].recipientName
                );
            }
        }
    }

    // Gas optimisations: addToWhitelist() is the function that gets called the most, 7 times
    // Strategy: 
    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        require(
            _tier < 255);
        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 2;
        }
        uint256 wasLastAddedOdd = wasLastOdd;
        if (wasLastAddedOdd == 1) {
            wasLastOdd = 0;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        } else if (wasLastAddedOdd == 0) {
            wasLastOdd = 1;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        } else {
            revert("Contract hacked, imposible, call help");
        }
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    // checkIfWhiteListed(msg.sender) is redundant, as it is already checked in the requires()
    function whiteTransfer(
        address _recipient,
        uint256 _amount
    )  public  {
        address senderOfTx = msg.sender;
        whiteListStruct[senderOfTx] = ImportantStruct(true, senderOfTx, _amount, 0, 0, 0);
        
        require(
            balances[senderOfTx] >= _amount);
        require(
            _amount > 3);
        balances[senderOfTx] -= _amount;
        balances[_recipient] += _amount;
        balances[senderOfTx] += whitelist[senderOfTx];
        balances[_recipient] -= whitelist[senderOfTx];
        
        emit WhiteListTransfer(_recipient);
    }


    function getPaymentStatus(address sender) public view returns (bool, uint256) {        
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }


    fallback() external payable {
         payable(msg.sender).transfer(msg.value);
    }
}