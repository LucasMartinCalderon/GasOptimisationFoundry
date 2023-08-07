// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

contract GasContract {
    uint256 private totalSupply = 0;
    uint256 private paymentCounter = 0;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public whitelist;
    mapping(address => uint256) private isOddWhitelistUser;
    mapping(address => Payment[]) private payments;
    mapping(address => ImportantStruct) private whiteListStruct;
    address[5] public administrators;
    address private owner;
    uint8 private constant tradePercent = 12;
    uint256 private constant wasLastOdd = 1;
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    //structs
    struct Payment {
        uint256 paymentID;
        uint256 amount;
        bytes8 recipientName;
        address recipient;
        address admin;
        PaymentType paymentType;
        bool adminUpdated;
    }

    struct ImportantStruct {
        uint256 amount;
        uint256 bigValue;
        address sender;
        uint16 valueA; // max 3 digits
        uint16 valueB; // max 3 digits
        bool paymentStatus;
    }

    //modifiers
    modifier onlyAdminOrOwner() {
        if (msg.sender == owner) {
            _;
        } else if (checkForAdmin(msg.sender)) {
            _;
        } else {
            revert(
                "the originator of the transaction was not the admin or owner"
            );
        }
    }

    modifier checkIfWhiteListed() {
        uint256 usersTier = whitelist[msg.sender];
        if (usersTier > 0 && usersTier < 4) {
            _;
        } else {
            revert("User is not whitelisted");
        }
    }

    //events
    event AddedToWhitelist(address userAddress, uint256 tier);
    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address indexed recipient, uint256 indexed amount);
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        owner = msg.sender;
        totalSupply = _totalSupply;
        balances[owner] = _totalSupply;
        emit supplyChanged(owner, totalSupply);

        for (uint256 i = 0; i < _admins.length; i++) {
            if (_admins[i] != address(0)) {
                administrators[i] = _admins[i];
                if (_admins[i] != owner) {
                    balances[_admins[i]] = 0;
                    emit supplyChanged(_admins[i], 0);
                }
            }
        }
    }

    function checkForAdmin(address _user) private view returns (bool) {
        bool admin = false;
        for (uint8 i = 0; i < administrators.length; i++) {
            if (administrators[i] == _user) {
                admin = true;
                break;
            }
        }
        return admin;
    }

    function balanceOf(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string memory _name
    ) public returns (bool status_) {
        require(
            balances[msg.sender] >= _amount,
            "Sender has insufficient Balance"
        );
        require(
            bytes(_name).length < 9,
            "Max length of recipient name is 8 char"
        );
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment;
        payment.admin = address(0);
        payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = bytes8(bytes(_name));
        payment.paymentID = ++paymentCounter;
        payments[msg.sender].push(payment);
        return (tradePercent > 1);
    }

    function addToWhitelist(
        address _userAddrs,
        uint256 _tier
    ) public onlyAdminOrOwner {
        require(_tier < 255, "Tier level should not be greater than 255");
        uint256 tier = _tier;
        if (_tier > 3) {
            tier = 3;
        } else if (_tier == 1) {
            tier = 1;
        } else if (_tier > 0 && _tier < 3) {
            tier = 2;
        }
        whitelist[_userAddrs] = tier;
        uint256 wasLastAddedOdd = wasLastOdd;
        if (wasLastAddedOdd == 1) {
            wasLastAddedOdd = 0;
        } else if (wasLastAddedOdd == 0) {
            wasLastAddedOdd = 1;
        } else {
            revert("Contract hacked");
        }
        isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed {
        whiteListStruct[msg.sender] = ImportantStruct(
            _amount,
            0,
            msg.sender,
            0,
            0,
            true
        );
        require(
            balances[msg.sender] >= _amount,
            "Sender has insufficient Balance"
        );
        require(_amount > 3, "Amount to send have to be bigger than 3");
        uint256 senderWhiteListValue = whitelist[msg.sender];
        balances[msg.sender] =
            balances[msg.sender] -
            _amount +
            senderWhiteListValue;
        balances[_recipient] =
            balances[_recipient] +
            _amount -
            senderWhiteListValue;
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(
        address sender
    ) external view returns (bool, uint256) {
        return (
            whiteListStruct[sender].paymentStatus,
            whiteListStruct[sender].amount
        );
    }
}
