// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPuzzleProxy {
    function pendingAdmin() external view returns (address);
    function admin() external view returns (address);
    function proposeNewAdmin(address _newAdmin) external;
    function approveNewAdmin(address _expectedAdmin) external;
}

interface IPuzzleWallet {
    function owner() external view returns (address);
    function maxBalance() external view returns (uint256);
    function whitelisted(address) external view returns (bool);
    function balances(address) external view returns (uint256);
    function init(uint256 _maxBalance) external;
    function setMaxBalance(uint256 _maxBalance) external;
    function addToWhitelist(address addr) external;
    function deposit() external payable;
    function execute(address to, uint256 value, bytes calldata data) external payable;
    function multicall(bytes[] calldata data) external payable;
}
