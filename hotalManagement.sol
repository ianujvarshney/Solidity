// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Hotel{
    address payable public owner;
    enum stateuses {Vacant, Occupied}
    stateuses currentState;
    constructor(){
        owner = payable(msg.sender);
        currentState = stateuses.Vacant;
    } 
    modifier onlyVacant(){
        require(currentState == stateuses.Vacant, "Currently Occupied");
        _;
    }
    modifier sizelimit(uint _amount){
        require(msg.value >= _amount , "Not enought Ether provided");
        _;
    }
    function book() payable public onlyVacant sizelimit(2 ether){
        owner.transfer(msg.value);
        currentState = stateuses.Occupied;
    }
}