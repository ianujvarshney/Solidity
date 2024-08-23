// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TransferMoneys{
    address payable public user = payable(msg.sender);

    // function payEither() public payable{

    // }
    function getBalance() public view returns(uint){
    return user.balance;
    }
    function sendEtherAccount()payable  public{
        user.transfer(msg.value);
    }
}