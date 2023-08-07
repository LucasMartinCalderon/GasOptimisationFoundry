// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract GasContract {
    address private contractOwner;
    uint256 private totalSupply; // cannot be updated
    mapping(address => uint256) public balances;
    mapping(address => uint256) public whitelist;
    mapping(address => ImportantStruct) private whiteListStruct;
    address[5] public administrators;

    event AddedToWhitelist(address userAddress, uint256 tier);
    event WhiteListTransfer(address indexed);

    struct ImportantStruct {
        uint256 amount;
        bool paymentStatus;
    }

    modifier onlyAdminOrOwner() {
        require(msg.sender == contractOwner);
        _;
    }

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint8 ii; ii < administrators.length;) {
            administrators[ii] = _admins[ii];
            if (_admins[ii] == contractOwner) {
                balances[contractOwner] = totalSupply;
            }
            unchecked {
                ii++;
            }
        }
    }

    function checkForAdmin(address _user) private view returns (bool admin_) {
        for (uint8 ii; ii < administrators.length;) {
            if (administrators[ii] == _user) {
                admin_ = true;
            }
            unchecked {
                ii++;
            }
        }
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        balance_ = balances[_user];
    }

    function transfer(address _recipient, uint256 _amount, string calldata _name) public {
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) public onlyAdminOrOwner {
        require(_tier < 255);
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(address _recipient, uint256 _amount) public {
        whiteListStruct[msg.sender] = ImportantStruct(_amount, true);
        require(balances[msg.sender] >= _amount && _amount > 3);
        balances[msg.sender] -= _amount + whitelist[msg.sender];
        balances[_recipient] += _amount - whitelist[msg.sender];

        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool _paymentStatus, uint256 _amount) {
        _paymentStatus = whiteListStruct[sender].paymentStatus;
        _amount = whiteListStruct[sender].amount;
    }
}
