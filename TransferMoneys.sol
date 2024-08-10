// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TransferMoneys{
    address payable public user = payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);

    // function payEither() public payable{

    // }
    function getBalance() public view returns(uint){
    return user.balance;
    }
    function sendEtherAccount()payable  public{
        user.transfer(msg.value);
    }
}