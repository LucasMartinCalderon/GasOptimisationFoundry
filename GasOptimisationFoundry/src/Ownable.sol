// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

abstract contract Ownable {
    address private _owner;

    constructor() {
        _transferOwnership(_msgSender());
    }

    function _msgSender() private view returns (address) {
        return msg.sender;
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() private view returns (address) {
        return _owner;
    }

    function _checkOwner() private view {
        require(owner() == _msgSender());
    }

    function transferOwnership(address newOwner) private onlyOwner {
        require(newOwner != address(0));
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) private {
        _owner = newOwner;
    }
}
