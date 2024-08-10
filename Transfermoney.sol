// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract TransferMoney{

    event transfer(address indexed _from, address indexed _to, uint _amount);

    function trans(address to, uint amount) public{
        emit transfer(msg.sender, to, amount);
    }
}