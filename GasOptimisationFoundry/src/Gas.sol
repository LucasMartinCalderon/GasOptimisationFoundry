// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./Ownable.sol";

contract Constants {
    uint256 public tradeFlag = 1;
    uint256 private basicFlag;
    uint256 public dividendFlag = 1;
}

contract GasContract is Ownable, Constants {
    address private contractOwner;
    bool private isReady;
    uint256 private immutable totalSupply; // cannot be updated
    uint256 private paymentCounter;
    mapping(address => uint256) public balances;
    uint256 private tradePercent = 12;
    uint256 private tradeMode;
    mapping(address => Payment[]) private payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;

    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    PaymentType constant defaultPayment = PaymentType.Unknown;

    History[] private paymentHistory; // when a payment was updated

    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        bool adminUpdated;
        string recipientName; // max 8 characters
        address recipient;
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }

    uint256 wasLastOdd = 1;
    mapping(address => uint256) private isOddWhitelistUser;

    struct ImportantStruct {
        uint256 amount;
        uint256 bigValue;
        uint8 valueA; // max 3 digits
        uint8 valueB; // max 3 digits
        bool paymentStatus;
        address sender;
    }

    mapping(address => ImportantStruct) private whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        if (checkForAdmin(senderOfTx)) {
            if (!checkForAdmin(senderOfTx)) {
                revert();
            }
            _;
        } else if (senderOfTx == contractOwner) {
            _;
        } else {
            revert();
        }
    }

    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        require(senderOfTx == sender);
        uint256 usersTier = whitelist[senderOfTx];
        require(usersTier > 0);
        require(usersTier < 4);
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) payable {
        unchecked {
            contractOwner = msg.sender;
            totalSupply = _totalSupply;

            for (uint256 ii; ii < administrators.length; ++ii) {
                if (_admins[ii] != address(0)) {
                    administrators[ii] = _admins[ii];
                    if (_admins[ii] == contractOwner) {
                        balances[contractOwner] = totalSupply;
                    } else {
                        balances[_admins[ii]];
                    }
                    if (_admins[ii] == contractOwner) {
                        emit supplyChanged(_admins[ii], totalSupply);
                    } else if (_admins[ii] != contractOwner) {
                        emit supplyChanged(_admins[ii], 0);
                    }
                }
            }
        }
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        unchecked {
            bool admin;
            for (uint256 ii; ii < administrators.length; ++ii) {
                if (administrators[ii] == _user) {
                    admin = true;
                }
            }
            return admin;
        }
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        return balances[_user];
    }

    function transfer(address _recipient, uint256 _amount, string calldata _name)
        public
        payable
        returns (bool status_)
    {
        unchecked {
            address senderOfTx = msg.sender;
            require(balances[senderOfTx] >= _amount);
            require(bytes(_name).length < 9);
            balances[senderOfTx] -= _amount;
            balances[_recipient] += _amount;
            emit Transfer(_recipient, _amount);
            Payment memory payment;
            payment.admin = address(0);
            payment.adminUpdated;
            payment.paymentType = PaymentType.BasicPayment;
            payment.recipient = _recipient;
            payment.amount = _amount;
            payment.recipientName = _name;
            payment.paymentID = ++paymentCounter;
            payments[senderOfTx].push(payment);
            bool[] memory status = new bool[](tradePercent);
            for (uint256 i; i < tradePercent; ++i) {
                status[i] = true;
            }
            return (status[0] == true);
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) public payable onlyAdminOrOwner {
        unchecked {
            require(_tier < 255);
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
                wasLastOdd;
                isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
            }
            emit AddedToWhitelist(_userAddrs, _tier);
        }
    }

    function whiteTransfer(address _recipient, uint256 _amount) public payable checkIfWhiteListed(msg.sender) {
        unchecked {
            address senderOfTx = msg.sender;
            whiteListStruct[senderOfTx] = ImportantStruct(_amount, 0, 0, 0, true, msg.sender);

            require(balances[senderOfTx] >= _amount);
            require(_amount > 3);
            balances[senderOfTx] -= _amount;
            balances[_recipient] += _amount;
            balances[senderOfTx] += whitelist[senderOfTx];
            balances[_recipient] -= whitelist[senderOfTx];

            emit WhiteListTransfer(_recipient);
        }
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }
}
